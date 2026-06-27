class_name MaterialCodeGenerator extends RefCounted

# ---------------------------------------------------------------------------
# One ShaderCache instance lives for the lifetime of this generator.
# If you make MaterialCodeGenerator a singleton/autoload, so does the cache.
# ---------------------------------------------------------------------------
var _cache := ShaderCache.new()

func _init() -> void:
	# Topo-sort runs exactly once here.
	_cache.warm_up_library()

	# Connect to the two relevant signals so the cache knows what to invalidate.
	# "layer_structure_changed" fires when layers are added/removed or a
	# generator/modifier *type* is swapped — preamble may differ.
	# "material_value_changed" fires for parameter/opacity/order edits —
	# only the fragment needs rebuilding.
	#
	# If your SignalBus only has material_value_changed today you can route
	# both through it by checking a dirty-flag set before emitting, but having
	# two distinct signals is cleaner.
	SignalBus.layer_structure_changed.connect(_on_structure_changed)
	SignalBus.material_value_changed.connect(_on_value_changed)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_structure_changed() -> void:
	# The set of used resource types may have changed → preamble is stale.
	_cache.invalidate_preamble()
	# Fragment is also stale (new layer may have appeared / disappeared).
	_cache.invalidate_fragment()


func _on_value_changed() -> void:
	# Parameter / opacity / order change — preamble bodies are unchanged.
	_cache.invalidate_fragment()


# ---------------------------------------------------------------------------
# Main entry point — called by the preview renderer.
# ---------------------------------------------------------------------------
func generate_shader_code(material_data: Dictionary = EditorMaterial.editorMaterialData) -> String:
	# Collect active resource names (cheap — no string building).
	var used_generators: Array[String] = []
	var used_modifiers: Array[String] = []
	var used_blend_modes: Array[String] = []
	_collect_used_resources(used_generators, used_modifiers, used_blend_modes, material_data)

	var preamble_key := PreambleBuilder.make_preamble_key(
			used_generators, used_modifiers, used_blend_modes)

	return _cache.get_shader(
		preamble_key,
		func() -> String:
			return PreambleBuilder.build(
					used_generators, used_modifiers, used_blend_modes, _cache),
		func() -> String:
			return _build_fragment(material_data)
	)


# ---------------------------------------------------------------------------
# Resource collection — identical logic to the original, extracted so it can
# be called cheaply before deciding what to rebuild.
# ---------------------------------------------------------------------------
func _collect_used_resources(
		out_generators: Array[String],
		out_modifiers: Array[String],
		out_blend_modes: Array[String],
		material_data: Dictionary
) -> void:
	for channel in ["albedo", "normal"]:
		for layer in EditorMaterial.get_layers_in_order(channel, material_data):
			var gen_id: StringName = layer.get("generator_id", "")
			if gen_id != "":
				var gen := EditorMaterial.get_generator(gen_id, material_data)
				var gen_name: String = gen.get("generator_name", "")
				if gen_name != "" and gen_name not in out_generators:
					out_generators.append(gen_name)

			var blend: String = layer.get("blend_mode", "normal")
			if blend not in out_blend_modes:
				out_blend_modes.append(blend)

			for mod in EditorMaterial.get_modifiers_in_order(channel, layer.get("id", ""), material_data):
				var mod_name: String = mod.get("modifier_name", "")
				if mod_name != "" and mod_name not in out_modifiers:
					out_modifiers.append(mod_name)


# ---------------------------------------------------------------------------
# Fragment builder — called by the cache only when _fragment_dirty is true.
# Logic is identical to the original generate_shader_code() fragment section;
# nothing has been changed here except it now lives in its own function.
# ---------------------------------------------------------------------------

const _NORMAL_FROM_HEIGHT_GLSL := """vec3 normalFromHeight(vec2 uv, float offset, float mlp) {
\tvec2 nuv = vec2(uv.x + offset, uv.y);
\tvec3 fa = vec3(nuv.x, 0.0, height(nuv) * mlp);
\tnuv = vec2(uv.x, uv.y - offset);
\tvec3 fc = vec3(0.0, nuv.y, height(nuv) * mlp);
\tnuv = vec2(uv.x - offset, uv.y);
\tvec3 fb = vec3(nuv.x, 0.0, height(nuv) * mlp);
\tnuv = vec2(uv.x, uv.y + offset);
\tvec3 fd = vec3(0.0, nuv.y, height(nuv) * mlp);
\treturn 0.5 + normalize(cross(fa - fb * vec3(1., 0., 1.), fc - fd * vec3(0., 1., 1.))) * vec3(1., -1., 1.);
}"""

func _build_fragment(material_data: Dictionary) -> String:
	var code := PackedStringArray()

	# --- Normal channel: emit as a height() function above fragment ---
	var normal_layers := EditorMaterial.get_layers_in_order("normal", material_data)
	if not normal_layers.is_empty():
		code.append("float height(vec2 uv) {")
		code.append("\tvec4 base_normal = vec4(0.0);")
		code.append("")
		_append_channel_body(code, "normal", normal_layers, "base_normal", material_data)
		code.append("\treturn base_normal.r;")
		code.append("}")
		code.append("")
		code.append(_NORMAL_FROM_HEIGHT_GLSL)
		code.append("")

	# --- Fragment entry point ---
	code.append("void fragment() {")
	code.append("\tvec2 uv = UV;")
	code.append("")

	# Albedo channel — inline as before
	var albedo_layers := EditorMaterial.get_layers_in_order("albedo", material_data)
	if not albedo_layers.is_empty():
		code.append("\tvec4 base_albedo = vec4(0.0);")
		_append_channel_body(code, "albedo", albedo_layers, "base_albedo", material_data)
		code.append("\tALBEDO = base_albedo.rgb;")
		code.append("\tALPHA = base_albedo.a;")
		code.append("")

	# Normal channel — delegate entirely to the generated functions
	if not normal_layers.is_empty():
		code.append("\tNORMAL_MAP = normalFromHeight(uv, 0.001, 0.1);")
		code.append("")

	code.append("}")
	return "\n".join(code)
	
# Appends the layer iteration lines into `code`.
# `base_var` is the name of the vec4 accumulator already declared by the caller.
# Indentation prefix is always one tab (works for both a function body and fragment body).
func _append_channel_body(
		code: PackedStringArray,
		channel: String,
		layers: Array[Dictionary],
		base_var: String,
		material_data: Dictionary
) -> void:
	for layer in layers:
		var gen_id: StringName       = layer.get("generator_id", "")
		var blend_mode: String       = layer.get("blend_mode", "normal")
		var gen_instance             := EditorMaterial.get_generator(gen_id, material_data)
		var gen_name: String         = gen_instance.get("generator_name", "")
		var gen_params: Dictionary   = gen_instance.get("parameters", {})

		if gen_name == "":
			continue
		var gen_data: GeneratorData = GeneratorLibrary.get_generator_data(gen_name)
		if not gen_data:
			continue

		var args := PackedStringArray(["uv"])
		for param_name in gen_data.parameters:
			var param_def: abstractParameterDef = gen_data.parameters[param_name]
			var val = gen_params.get(param_name, param_def.get_default_value())
			var var_name: String = "gen_%s_%s" % [layer.get("id", "layer"), param_name]
			var declaration: String = param_def.generate_glsl_declaration(val, var_name)
			if declaration.strip_edges() != "":
				code.append("\t" + declaration.replace("\n", "\n\t"))
				args.append(param_def.value_to_glsl(val, var_name))
			else:
				args.append(param_def.value_to_glsl(val))

		var current_val: String  = "gen_val_" + str(layer.get("id", "gen"))
		var current_type: String = gen_data.return_type
		code.append("\t%s %s = %s(%s);" % [
				current_type, current_val, gen_data.function_name, ", ".join(args)])

		for mod_id in EditorMaterial.get_modifier_order(channel, layer.get("id", ""), material_data):
			var mod := EditorMaterial.get_modifier(channel, layer.get("id", ""), mod_id, material_data)
			var mod_name: String  = mod.get("modifier_name", "")
			var mod_params: Dictionary = mod.get("parameters", {})
			var mod_data: ModifierData = ModifierLibrary.get_modifier_data(mod_name)
			if not mod_data:
				continue

			var mod_args := PackedStringArray([current_val])
			for param_name in mod_data.parameters:
				var param_def: abstractParameterDef = mod_data.parameters[param_name]
				var val = mod_params.get(param_name, param_def.get_default_value())
				var var_name: String = "mod_%s_%s" % [mod_id, param_name]
				var declaration: String = param_def.generate_glsl_declaration(val, var_name)
				if declaration.strip_edges() != "":
					code.append("\t" + declaration.replace("\n", "\n\t"))
					mod_args.append(param_def.value_to_glsl(val, var_name))
				else:
					mod_args.append(param_def.value_to_glsl(val))

			var new_val: String = "mod_" + str(mod_id)
			code.append("\t%s %s = %s(%s);" % [
					mod_data.return_type, new_val, mod_data.function_name, ", ".join(mod_args)])
			current_val  = new_val
			current_type = mod_data.return_type

		var layer_color_var: String = "layer_" + str(layer.get("id", "layer"))
		match current_type:
			"vec4": code.append("\tvec4 %s = %s;" % [layer_color_var, current_val])
			"vec3": code.append("\tvec4 %s = vec4(%s, 1.0);" % [layer_color_var, current_val])
			_:      code.append("\tvec4 %s = vec4(vec3(%s), 1.0);" % [layer_color_var, current_val])

		var blend_data: MixModeData = MixLibrary.get_blend_mode(blend_mode)
		var opacity: float          = layer.get("opacity", 1.0)
		if blend_data:
			var blended_var: String = "blended_" + str(layer.get("id", "layer"))
			code.append("\tvec4 %s = %s(%s, %s);" % [
					blended_var, blend_data.function_name, base_var, layer_color_var])
			code.append("\t%s = mix(%s, %s, %s.a * %.6f);" % [
					base_var, base_var, blended_var, layer_color_var, opacity])
		else:
			code.append("\t%s = mix(%s, %s, %s.a * %.6f);" % [
					base_var, base_var, layer_color_var, layer_color_var, opacity])
