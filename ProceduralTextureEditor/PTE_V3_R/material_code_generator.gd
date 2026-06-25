class_name MaterialCodeGenerator extends RefCounted

## Recursively collects all helper functions, topologically sorts them,
## and assembles a complete Godot spatial shader.
func generate_shader_code() -> String:
	var code := PackedStringArray()

	# ---------- 1. Collect used resource names ----------
	var used_generators: Array[String] = []
	var used_modifiers: Array[String] = []
	var used_blend_modes: Array[String] = []

	for channel in ["albedo", "normal"]:
		var layers = EditorMaterial.get_layers_in_order(channel)
		for layer in layers:
			var gen_id = layer.get("generator_id", "")
			if gen_id != "":
				var gen = EditorMaterial.get_generator(gen_id)
				var gen_name = gen.get("generator_name", "")
				if gen_name != "" and gen_name not in used_generators:
					used_generators.append(gen_name)

			var blend = layer.get("blend_mode", "normal")
			if blend not in used_blend_modes:
				used_blend_modes.append(blend)

			for mod in EditorMaterial.get_modifiers_in_order(channel, layer.get("id", "")):
				var mod_name = mod.get("modifier_name", "")
				if mod_name != "" and mod_name not in used_modifiers:
					used_modifiers.append(mod_name)

	# ---------- 2. Gather all required function names from the used resources ----------
	var needed_names := PackedStringArray()

	# From generators
	for gen_name in used_generators:
		var data = GeneratorLibrary.get_generator_data(gen_name)
		if data:
			for fname in data.required_functions:
				if fname not in needed_names:
					needed_names.append(fname)

	# From modifiers
	for mod_name in used_modifiers:
		var data = ModifierLibrary.get_modifier_data(mod_name)
		if data:
			for fname in data.required_functions:
				if fname not in needed_names:
					needed_names.append(fname)

	# From blend modes
	for blend_name in used_blend_modes:
		var blend_data = MixLibrary.get_blend_mode(blend_name)
		if blend_data:
			for fname in blend_data.required_functions:
				if fname not in needed_names:
					needed_names.append(fname)

	# ---------- 3. Recursively resolve all dependencies from FunctionLibrary ----------
	var function_resources := {}  # name -> FunctionData
	var queue := needed_names.duplicate()

	while not queue.is_empty():
		var fname = queue[queue.size() - 1]
		queue.remove_at(queue.size() - 1)
		if function_resources.has(fname):
			continue

		var func_res: FunctionData = FunctionLibrary.get_function(fname)
		if not func_res:
			push_error("Function '%s' not found in FunctionLibrary" % fname)
			continue

		function_resources[fname] = func_res
		# Enqueue any functions this one depends on
		for dep in func_res.required_functions:
			if not function_resources.has(dep) and dep not in queue:
				queue.append(dep)

	# ---------- 4. Build graph for topological sort ----------
	var graph := {}
	for fname in function_resources:
		var res = function_resources[fname]
		graph[fname] = {
			"code": res.code,
			"requires": res.required_functions
		}

	var sorted := _topological_sort(graph)

	# ---------- 5. Assemble shader header ----------
	code.append("shader_type spatial;")
	code.append("render_mode blend_mix, depth_draw_opaque;")
	code.append("")

	# ---------- 6. Output all helper functions in correct order ----------
	for fname in sorted:
		var dep = graph[fname]
		var block: String = dep["code"]
		block = block.strip_edges() + "\n"
		code.append(block)
		code.append("")   # blank line

	# ---------- 7. Output main functions (generators, modifiers, blends) ----------
	for gen_name in used_generators:
		var data = GeneratorLibrary.get_generator_data(gen_name)
		if data:
			code.append(data.function.strip_edges() + "\n")
			code.append("")

	for mod_name in used_modifiers:
		var data = ModifierLibrary.get_modifier_data(mod_name)
		if data:
			code.append(data.function.strip_edges() + "\n")
			code.append("")

	for blend_name in used_blend_modes:
		var blend_data = MixLibrary.get_blend_mode(blend_name)
		if blend_data:
			code.append(blend_data.function.strip_edges() + "\n")
			code.append("")

	# ---------- 8. Fragment function (unchanged logic) ----------
	code.append("void fragment() {")
	code.append("\tvec2 uv = UV;")
	code.append("")

	# Process each channel
	for channel in ["albedo", "normal"]:
		var layers = EditorMaterial.get_layers_in_order(channel)
		if layers.is_empty():
			continue

		var base_var = "base_" + channel
		if channel == "normal":
			code.append("\tvec4 %s = vec4(0.5, 0.5, 1.0, 1.0); // default normal" % base_var)
		else:
			code.append("\tvec4 %s = vec4(0.0);" % base_var)

		for layer in layers:
			var gen_id = layer.get("generator_id", "")
			var blend_mode = layer.get("blend_mode", "normal")
			var gen_instance = EditorMaterial.get_generator(gen_id)
			var gen_name = gen_instance.get("generator_name", "")
			var gen_params = gen_instance.get("parameters", {})

			if gen_name == "":
				continue

			var gen_data = GeneratorLibrary.get_generator_data(gen_name)
			if not gen_data:
				continue

			# Build argument list from generator parameters
			var args := PackedStringArray(["uv"])
			for param_name in gen_data.parameters:
				var param_def: abstractParameterDef = gen_data.parameters[param_name]
				var val = gen_params.get(param_name, param_def.get_default_value())

				var var_name = "gen_%s_%s" % [layer.get("id", "layer"),param_name]

				var declaration = param_def.generate_glsl_declaration(val,var_name)

				if declaration.strip_edges() != "":
					code.append("\t" + declaration.replace("\n", "\n\t"))
					args.append(param_def.value_to_glsl(val, var_name))
				else:
					args.append(param_def.value_to_glsl(val))
					
			var call_str = "%s(%s)" % [gen_data.function_name, ", ".join(args)]
			var current_val = "gen_val_" + str(layer.get("id", "gen"))
			code.append("\t%s %s = %s;" % [gen_data.return_type, current_val, call_str])

			# Apply modifiers in order
			var mod_order = EditorMaterial.get_modifier_order(channel, layer.get("id", ""))
			var current_type = gen_data.return_type
			for mod_id in mod_order:
				var mod = EditorMaterial.get_modifier(channel, layer.get("id", ""), mod_id)
				var mod_name = mod.get("modifier_name", "")
				var mod_params = mod.get("parameters", {})
				var mod_data = ModifierLibrary.get_modifier_data(mod_name)
				if not mod_data:
					continue

				var mod_args := PackedStringArray([current_val])

				for param_name in mod_data.parameters:
					var param_def: abstractParameterDef = mod_data.parameters[param_name]
					var val = mod_params.get(param_name, param_def.get_default_value())

					var var_name = "mod_%s_%s" % [mod_id,param_name]

					var declaration = param_def.generate_glsl_declaration(val,var_name)

					if declaration.strip_edges() != "":
						code.append("\t" + declaration.replace("\n", "\n\t"))
						mod_args.append(param_def.value_to_glsl(val, var_name))
					else:
						mod_args.append(param_def.value_to_glsl(val))
				var mod_call = "%s(%s)" % [mod_data.function_name, ", ".join(mod_args)]
				var new_val = "mod_" + str(mod_id)
				code.append("\t%s %s = %s;" % [mod_data.return_type, new_val, mod_call])
				current_val = new_val
				current_type = mod_data.return_type

			# Convert final value to vec4 for blending
			var layer_color_var = "layer_" + str(layer.get("id", "layer"))
			if current_type == "vec4":
				code.append("\tvec4 %s = %s;" % [layer_color_var, current_val])
			elif current_type == "vec3":
				code.append("\tvec4 %s = vec4(%s, 1.0);" % [layer_color_var, current_val])
			else:
				code.append("\tvec4 %s = vec4(vec3(%s), 1.0);" % [layer_color_var, current_val])


			# Blend with base + opacity
			var blend_data = MixLibrary.get_blend_mode(blend_mode)
			var opacity: float = layer.get("opacity", 1.0)

			if blend_data:
				var blended_var = "blended_" + str(layer.get("id", "layer"))

				var blend_call = "%s(%s, %s)" % [blend_data.function_name,base_var,layer_color_var]

				code.append("\tvec4 %s = %s;" % [blended_var,blend_call])

				code.append("\t%s = mix(%s, %s, %s.a * %.6f);" % [base_var,base_var,blended_var,layer_color_var,opacity])

			else:
				code.append(
					"\t%s = mix(%s, %s, %s.a * %.6f);" % [
						base_var,
						base_var,
						layer_color_var,
						layer_color_var,
						opacity
					]
				)

		# Write outputs
		if channel == "albedo":
			code.append("\tALBEDO = %s.rgb;" % base_var)
			code.append("\tALPHA = %s.a;" % base_var)
		elif channel == "normal":
			code.append("\tNORMAL_MAP = %s.rgb * 2.0 - 1.0;" % base_var)
		code.append("")

	code.append("}")
	return "\n".join(code)


# ---------- Helper: topological sort ----------
# ---------- Helper: topological sort (Kahn's algorithm) ----------
func _topological_sort(deps: Dictionary) -> PackedStringArray:
	# deps: { name: { "code": "...", "requires": PackedStringArray } }
	var indegree := {}
	var dependents := {}   # name -> Array of names that require this name
	var all_nodes := deps.keys()

	# Initialize
	for name in all_nodes:
		indegree[name] = deps[name]["requires"].size()
		dependents[name] = []

	# Who depends on whom
	for name in all_nodes:
		for req in deps[name]["requires"]:
			if dependents.has(req):
				dependents[req].append(name)

	# Start with nodes that have no prerequisites
	var queue := []
	for name in all_nodes:
		if indegree[name] == 0:
			queue.append(name)

	var sorted := PackedStringArray()
	while not queue.is_empty():
		var name = queue[0]
		queue.remove_at(0)
		sorted.append(name)

		for dependent in dependents[name]:
			indegree[dependent] -= 1
			if indegree[dependent] == 0:
				queue.append(dependent)

	if sorted.size() != all_nodes.size():
		push_error("Circular dependency detected – generated order may be incomplete")
		# Return whatever we could sort
	return sorted
