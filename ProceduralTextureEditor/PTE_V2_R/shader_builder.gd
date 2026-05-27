class_name ShaderBuilder

# Builds the fragment shader from an array of LayerData (top → bottom visual order)
static func build(layers: Array[LayerData]) -> String:
	# Determine layer order for compositing: bottom‑most layer is the last element
	# (because layers[0] is top visually). We’ll reverse for compositing.
	var bottom_to_top = layers.duplicate()
	bottom_to_top.reverse()

	# Collect used mix modes and function IDs
	var used_mix = []
	var used_funcs = []
	for layer in layers:
		if layer.active:
			if not layer.mix_mode in used_mix:
				used_mix.append(layer.mix_mode)
			if not layer.func_id in used_funcs:
				used_funcs.append(layer.func_id)

	# --- Build shader header ---
	var code = "shader_type canvas_item;\n"
	code += "\n"

	# --- Insert mix mode functions ---
	for mix_id in used_mix:
		code += MixDB.get_code(mix_id) + "\n"

	# --- Insert procedural functions ---
	for func_id in used_funcs:
		code += FuncDB.functions[func_id]["code"] + "\n"

	# --- Declare uniforms for each layer ---
	var layer_uniforms = []  # array of dicts with per‑layer uniform info
	for i in layers.size():
		var layer = layers[i]
		if not layer.active:
			layer_uniforms.append(null)
			continue
		var func_def = FuncDB.functions[layer.func_id]
		var u_info = {"mix_opacity": "layer_%d_opacity" % i}
		code += "uniform float %s : hint_range(0.0, 1.0) = %.4f;\n" % [u_info["mix_opacity"], layer.opacity]
		for p in func_def["params"]:
			var uname = "layer_%d_%s" % [i, p["name"]]
			u_info[p["name"]] = uname
			var default_val = p["default"]
			# Use layer’s stored param if available, else default
			if layer.func_params.has(p["name"]):
				var val = layer.func_params[p["name"]]
				default_val = _value_to_shader_string(val, p["type"])
			match p["type"]:
				"float":
					code += "uniform float %s : hint_range(0.0, 100.0) = %s;\n" % [uname, default_val]
				"vec3":
					code += "uniform vec3 %s = %s;\n" % [uname, default_val]
				# add other types as needed
		layer_uniforms.append(u_info)

	code += "\n"

	# --- Fragment shader ---
	code += "void fragment() {\n"
	code += "\tvec2 uv = UV;\n"
	code += "\tvec3 color = vec3(0.0);   // initial background (black)\n"

	# Composite bottom to top
	for i in range(bottom_to_top.size()):
		var layer = bottom_to_top[i]
		if not layer.active:
			continue
		# Find its index in original layers array
		var orig_idx = layers.find(layer)
		var u_info = layer_uniforms[orig_idx]
		# Build function call string with uniform names
		var func_def = FuncDB.functions[layer.func_id]
		var call = func_def["call"]
		for p in func_def["params"]:
			call = call.replace("{" + p["name"] + "}", u_info[p["name"]])
		# ---- FIX: use unique variable name ----
		var var_name = "layer_color_%d" % orig_idx
		code += "\tvec3 %s = %s;\n" % [var_name, call]
		# Apply mix mode
		var mix_name = MixDB.get_mix_mode_name(layer.mix_mode).to_lower()
		var mix_func = "mix_" + mix_name
		code += "\tcolor = %s(color, %s, %s);\n" % [mix_func, var_name, u_info["mix_opacity"]]

	code += "\tCOLOR = vec4(color, 1.0);\n"
	code += "}"

	return code

# Helper: convert a GDScript value to a shader literal string
static func _value_to_shader_string(value, type: String) -> String:
	match type:
		"float":
			return str(value)
		"vec3":
			if value is Color:
				return "vec3(%.4f, %.4f, %.4f)" % [value.r, value.g, value.b]
			else:
				return str(value)
		_:
			return str(value)
