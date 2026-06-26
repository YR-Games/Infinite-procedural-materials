class_name PreambleBuilder extends RefCounted

# ---------------------------------------------------------------------------
# Builds the shader text that sits above void fragment(){}.
# This is everything that depends only on *which* resource types are in use,
# not on their parameter values:
#   - shader_type / render_mode header
#   - helper functions from FunctionLibrary (in topo-sorted order)
#   - generator function bodies
#   - modifier function bodies
#   - blend-mode function bodies
#
# Called by ShaderCache only on a preamble cache miss.
# ---------------------------------------------------------------------------

static func build(
		used_generators: Array[String],
		used_modifiers: Array[String],
		used_blend_modes: Array[String],
		cache: ShaderCache
) -> String:
	var code := PackedStringArray()

	# ---- 1. Shader header ----
	code.append("shader_type spatial;")
	code.append("render_mode blend_mix, depth_draw_opaque;")
	code.append("")

	# ---- 2. Helper functions (pre-sorted by ShaderCache.warm_up_library) ----
	#
	# We only emit functions that are actually needed by the active resources,
	# so we first collect the required names transitively.
	var needed := _collect_needed_function_names(
			used_generators, used_modifiers, used_blend_modes)

	var graph := cache.get_function_graph()
	for fname in cache.get_sorted_functions():
		if fname not in needed:
			continue
		var block: String = graph[fname]["code"]
		code.append(block.strip_edges() + "\n")
		code.append("")

	# ---- 3. Generator bodies ----
	for gen_name in used_generators:
		var data: GeneratorData = GeneratorLibrary.get_generator_data(gen_name)
		if data:
			code.append(data.function.strip_edges() + "\n")
			code.append("")

	# ---- 4. Modifier bodies ----
	for mod_name in used_modifiers:
		var data: ModifierData = ModifierLibrary.get_modifier_data(mod_name)
		if data:
			code.append(data.function.strip_edges() + "\n")
			code.append("")

	# ---- 5. Blend-mode bodies ----
	for blend_name in used_blend_modes:
		var blend_data: MixModeData = MixLibrary.get_blend_mode(blend_name)
		if blend_data:
			code.append(blend_data.function.strip_edges() + "\n")
			code.append("")

	return "\n".join(code)


# ---------------------------------------------------------------------------
# Collect every FunctionLibrary name needed by the active resource set.
# Only called from build(); result is used to prune the emitted helper list.
# ---------------------------------------------------------------------------
static func _collect_needed_function_names(
		used_generators: Array[String],
		used_modifiers: Array[String],
		used_blend_modes: Array[String]
) -> PackedStringArray:
	var needed := PackedStringArray()

	# Seed from generators
	for gen_name in used_generators:
		var data: GeneratorData = GeneratorLibrary.get_generator_data(gen_name)
		if data:
			for fname in data.required_functions:
				if fname not in needed:
					needed.append(fname)

	# Seed from modifiers
	for mod_name in used_modifiers:
		var data: ModifierData = ModifierLibrary.get_modifier_data(mod_name)
		if data:
			for fname in data.required_functions:
				if fname not in needed:
					needed.append(fname)

	# Seed from blend modes
	for blend_name in used_blend_modes:
		var blend_data: MixModeData = MixLibrary.get_blend_mode(blend_name)
		if blend_data:
			for fname in blend_data.required_functions:
				if fname not in needed:
					needed.append(fname)

	# Transitively resolve through FunctionLibrary
	var queue := needed.duplicate()
	while not queue.is_empty():
		var fname = queue[queue.size() - 1]
		queue.remove_at(queue.size() - 1)
		var func_res: FunctionData = FunctionLibrary.get_function(fname)
		if not func_res:
			push_error("PreambleBuilder: function '%s' not found in FunctionLibrary" % fname)
			continue
		for dep in func_res.required_functions:
			if dep not in needed:
				needed.append(dep)
				queue.append(dep)

	return needed


# ---------------------------------------------------------------------------
# Build the canonical preamble key cheaply — called on EVERY change to decide
# whether the preamble cache is still valid, without rebuilding the string.
# The key is just the sorted, joined names of all active resource types.
# ---------------------------------------------------------------------------
static func make_preamble_key(
		used_generators: Array[String],
		used_modifiers: Array[String],
		used_blend_modes: Array[String]
) -> String:
	var parts := PackedStringArray()
	var gens := used_generators.duplicate()
	gens.sort()
	var mods := used_modifiers.duplicate()
	mods.sort()
	var blends := used_blend_modes.duplicate()
	blends.sort()
	parts.append("G:" + ",".join(gens))
	parts.append("M:" + ",".join(mods))
	parts.append("B:" + ",".join(blends))
	return "|".join(parts)
