class_name MaterialCodeGenerator extends RefCounted

# ---------------------------------------------------------------------------
# One ShaderCache instance lives for the lifetime of this generator.
# If you make MaterialCodeGenerator a singleton/autoload, so does the cache.
# ---------------------------------------------------------------------------
var _cache := ShaderCache.new()

# ---------------------------------------------------------------------------
# Parameter matching
# Generator / modifier arguments are matched to the GLSL function signature
# BY NAME, so the order of the `parameters` dictionary can never mis-wire them.
# ---------------------------------------------------------------------------

# Property on GeneratorData / ModifierData that holds the GLSL source of the
# function (GeneratorData calls it `function`). If ModifierData uses another
# name, add it to this list.
const _GLSL_SOURCE_PROPS := ["function"]

# function_name -> PackedStringArray of argument names after the first one
# (uv / input value), or null when the signature can't be matched to the
# parameter keys. Filled lazily, reported once per function.
var _param_order_cache := {}

# Last identifier of one GLSL argument declaration: "in float scale", "float x[4]".
var _arg_name_rx := RegEx.create_from_string("(\\w+)\\s*(?:\\[[^\\]]*\\])?\\s*$")

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
func generate_shader_code(
		material_data: Dictionary = EditorMaterial.editorMaterialData,
		shader_type: String = "spatial"
) -> String:
	var used_generators: Array[String] = []
	var used_modifiers: Array[String] = []
	var used_blend_modes: Array[String] = []
	_collect_used_resources(used_generators, used_modifiers, used_blend_modes, material_data)

	var preamble_key := PreambleBuilder.make_preamble_key(
			used_generators, used_modifiers, used_blend_modes, shader_type)  # <-- +shader_type

	return _cache.get_shader(
		preamble_key+shader_type,
		func() -> String:
			return PreambleBuilder.build(
					used_generators, used_modifiers, used_blend_modes, _cache, shader_type),  # <-- +shader_type
		func() -> String:
			return _build_fragment(material_data, shader_type)  # <-- +shader_type
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
	for channel in ["albedo", "normal", "roughness", "metallic"]:
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

# _build_fragment — add shader_type parameter, branch on output variable names
func _build_fragment(material_data: Dictionary, shader_type: String = "spatial") -> String:
	var is_canvas := shader_type == "canvas_item"
	var code := PackedStringArray()

	# --- Channels that generate a helper function above fragment() ---
	# Normal, roughness, and metallic all become float-returning functions
	# so the same height()/normalFromHeight() pattern applies to all three.
	var normal_layers    := EditorMaterial.get_layers_in_order("normal",    material_data)
	var roughness_layers := EditorMaterial.get_layers_in_order("roughness", material_data)
	var metallic_layers  := EditorMaterial.get_layers_in_order("metallic",  material_data)

	if not normal_layers.is_empty():
		_append_scalar_function(code, "height",    "normal",    normal_layers,    material_data)
		code.append(_NORMAL_FROM_HEIGHT_GLSL)
		code.append("")

	if not roughness_layers.is_empty():
		_append_scalar_function(code, "roughness", "roughness", roughness_layers, material_data)

	if not metallic_layers.is_empty():
		_append_scalar_function(code, "metallic",  "metallic",  metallic_layers,  material_data)


	# --- Fragment entry point ---
	code.append("void fragment() {")
	code.append("\tvec2 uv = UV;")
	code.append("")

	# Albedo / COLOR
	var albedo_layers := EditorMaterial.get_layers_in_order("albedo", material_data)
	if not albedo_layers.is_empty():
		code.append("\tvec4 base_albedo = vec4(1.0);")
		_append_channel_body(code, "albedo", albedo_layers, "base_albedo", material_data)
		if is_canvas:
			code.append("\tCOLOR = base_albedo;")
		else:
			code.append("\tALBEDO = base_albedo.rgb;")
			code.append("\tALPHA = base_albedo.a;")
		code.append("")

	# Normal — assign only in spatial
	if not normal_layers.is_empty():
		if not is_canvas:
			code.append("\tNORMAL_MAP = normalFromHeight(uv, 0.001, 0.1);")
			code.append("")

	# Roughness — assign only in spatial
	if not roughness_layers.is_empty():
		if not is_canvas:
			code.append("\tROUGHNESS = roughness(uv);")
			code.append("")

	# Metallic — assign only in spatial
	if not metallic_layers.is_empty():
		if not is_canvas:
			code.append("\tMETALLIC = metallic(uv);")
			code.append("")

	code.append("}")
	return "\n".join(code)

# Appends the layer iteration lines into `code`.
# `base_var` is the name of the vec4 accumulator already declared by the caller.
# Indentation prefix is always one tab (works for both a function body and fragment body).

func _append_scalar_function(
		code: PackedStringArray,
		func_name: String,
		channel: String,
		layers: Array[Dictionary],
		material_data: Dictionary
) -> void:
	code.append("float %s(vec2 uv) {" % func_name)
	code.append("\tvec4 base = vec4(0.0);")
	code.append("")
	_append_channel_body(code, channel, layers, "base", material_data)
	code.append("\treturn base.r;")
	code.append("}")
	code.append("")

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

		# Arguments are emitted in GLSL signature order, values looked up by name.
		var args := PackedStringArray(["uv"])
		if not _append_params(code, args, gen_data, gen_params, "gen_%s" % layer.get("id", "layer")):
			continue

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
			if not _append_params(code, mod_args, mod_data, mod_params, "mod_%s" % mod_id):
				continue

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


# ---------------------------------------------------------------------------
# Name-based parameter wiring (shared by generators and modifiers)
# ---------------------------------------------------------------------------

# Emits the declarations for one generator/modifier and appends its arguments
# to `args` in the order the GLSL function expects them. Values are looked up
# by parameter name, so the order of `data.parameters` doesn't matter.
# Returns false if the parameters can't be matched to the GLSL signature;
# the caller should then skip that generator/modifier.
func _append_params(
		code: PackedStringArray,
		args: PackedStringArray,
		data,
		values: Dictionary,
		prefix: String
) -> bool:
	var order = _param_order(data)
	if order == null:
		return false

	for param_name in order:
		var param_def: abstractParameterDef = data.parameters[param_name]
		var val = values.get(param_name, param_def.get_default_value())
		var var_name: String = "%s_%s" % [prefix, param_name]
		var declaration: String = param_def.generate_glsl_declaration(val, var_name)
		if declaration.strip_edges() != "":
			code.append("\t" + declaration.replace("\n", "\n\t"))
			args.append(param_def.value_to_glsl(val, var_name))
		else:
			args.append(param_def.value_to_glsl(val))
	return true


# Argument names for `data.function_name` in GLSL signature order, excluding the
# first argument. Returns null if a GLSL argument has no matching key in
# `data.parameters`. Result is cached, and problems are reported once.
func _param_order(data) -> Variant:
	var fn: String = data.function_name
	if _param_order_cache.has(fn):
		return _param_order_cache[fn]

	var order := PackedStringArray()
	var parsed = _parse_glsl_signature(fn, _get_glsl_source(data))

	if parsed == null:
		# No GLSL source (or no matching signature): fall back to dictionary order.
		push_warning("MaterialCodeGenerator: can't read the GLSL signature of '%s', using parameter dictionary order. Check _GLSL_SOURCE_PROPS." % fn)
		for key in data.parameters:
			order.append(str(key))
	else:
		order = parsed

		var missing := PackedStringArray()
		for param_name in order:
			if not data.parameters.has(param_name):
				missing.append(param_name)
		if not missing.is_empty():
			push_error("MaterialCodeGenerator: GLSL function '%s' takes argument(s) [%s] that have no matching key in its parameters. Keys are: %s" % [
					fn, ", ".join(missing), str(data.parameters.keys())])
			_param_order_cache[fn] = null
			return null

		# Parameters the editor shows but the GLSL function never receives.
		for key in data.parameters:
			if str(key) not in order:
				push_warning("MaterialCodeGenerator: parameter '%s' is not an argument of GLSL function '%s' and has no effect." % [str(key), fn])

	_param_order_cache[fn] = order
	return order


func _get_glsl_source(data) -> String:
	for prop in _GLSL_SOURCE_PROPS:
		var src = data.get(prop)
		if src is String and src != "":
			return src
	return ""


# Reads the argument names of `func_name` out of its GLSL definition, skipping
# the first argument. Returns null if the definition isn't found in `source`.
func _parse_glsl_signature(func_name: String, source: String) -> Variant:
	if source == "":
		return null

	var sig_rx := RegEx.create_from_string(
			"\\b\\w+\\s+%s\\s*\\(([^)]*)\\)\\s*\\{" % func_name)
	var m := sig_rx.search(source)
	if m == null:
		return null

	var names := PackedStringArray()
	var arg_list := m.get_string(1).split(",")
	for i in range(1, arg_list.size()):
		var arg_match := _arg_name_rx.search(arg_list[i])
		if arg_match:
			names.append(arg_match.get_string(1))
	return names
