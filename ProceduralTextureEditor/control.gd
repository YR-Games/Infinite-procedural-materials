extends Control

@onready var layer_container = $HSplit/Left/VBox/LayerList/ScrollContainer/LayerContainer
@onready var preview_rect = $HSplit/Right/Panel/PreviewRect
@onready var code_popup = $CodePopup
@onready var code_text = $CodePopup/Panel/CodeText
@onready var add_button = $HSplit/Left/VBox/AddButton
@onready var show_code_button = $HSplit/Left/VBox/ShowCodeButton
@onready var error_label = $HSplit/Left/VBox/ErrorLabel

var layers : Array[Layer] = []
var current_material : ShaderMaterial
var _compilation_pending : bool = false

func _ready():
	# Setup preview material
	current_material = ShaderMaterial.new()
	preview_rect.material = current_material
	preview_rect.size = Vector2(400,400)

	# Connect UI buttons
	add_button.pressed.connect(_add_layer)
	show_code_button.pressed.connect(_show_code_popup)

	# Add initial example layers
	_add_layer()
	_add_layer()
	# Configure first layer as solid red, second as blue gradient
	if layers.size() >= 1:
		layers[0].function_id = "solid"
		layers[0].parameters["color"] = Color.RED
	if layers.size() >= 2:
		layers[1].function_id = "linear_gradient"
		layers[1].parameters["start"] = Vector2(0,0)
		layers[1].parameters["end"] = Vector2(1,0)
		layers[1].parameters["color_a"] = Color.BLUE
		layers[1].parameters["color_b"] = Color.YELLOW
		layers[1].blend_mode = ShaderAssembler.BlendMode.ADD
	rebuild_layer_ui()
	_compile_shader()

# ------------------------------------------------------------
# Layer management
# ------------------------------------------------------------
func _add_layer():
	var new_layer = Layer.new()
	new_layer.enabled = true
	new_layer.function_id = "solid"
	new_layer.parameters = {"color": Color.WHITE}
	new_layer.blend_mode = ShaderAssembler.BlendMode.NORMAL
	layers.append(new_layer)
	rebuild_layer_ui()
	_compile_shader()

func remove_layer(index: int):
	if index >= 0 and index < layers.size():
		layers.remove_at(index)
		rebuild_layer_ui()
		_compile_shader()

func move_layer_up(index: int):
	if index > 0 and index < layers.size():
		var layer = layers.pop_at(index)
		layers.insert(index-1, layer)
		rebuild_layer_ui()
		_compile_shader()

func move_layer_down(index: int):
	if index >= 0 and index < layers.size()-1:
		var layer = layers.pop_at(index)
		layers.insert(index+1, layer)
		rebuild_layer_ui()
		_compile_shader()

# ------------------------------------------------------------
# UI building
# ------------------------------------------------------------
func rebuild_layer_ui():
	# Clear container
	for child in layer_container.get_children():
		child.queue_free()

	for i in range(layers.size()):
		var layer = layers[i]
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vbox = VBoxContainer.new()
		card.add_child(vbox)

		# Top row: enable checkbox, function selector, blend mode, remove button, move buttons
		var hbox_top = HBoxContainer.new()
		var enable_cb = CheckBox.new()
		enable_cb.button_pressed = layer.enabled
		enable_cb.toggled.connect(func(pressed): layer.enabled = pressed; _compile_shader())
		hbox_top.add_child(enable_cb)

		var func_option = OptionButton.new()
		for id in FunctionRegistry.get_ids():
			func_option.add_item(FunctionRegistry.get_display_name(id), func_option.get_item_count())
			if id == layer.function_id:
				func_option.select(func_option.get_item_count()-1)
		func_option.item_selected.connect(func(idx): _on_function_changed(i, idx))
		hbox_top.add_child(func_option)

		var blend_option = OptionButton.new()
		for b in ShaderAssembler.BlendMode.values():
			blend_option.add_item(ShaderAssembler.BlendMode.keys()[b], b)
		blend_option.select(layer.blend_mode)
		blend_option.item_selected.connect(func(idx): layer.blend_mode = idx; _compile_shader())
		hbox_top.add_child(blend_option)

		var remove_btn = Button.new(text="X")
		remove_btn.pressed.connect(func(): remove_layer(i))
		hbox_top.add_child(remove_btn)

		var up_btn = Button.new(text="↑")
		up_btn.pressed.connect(func(): move_layer_up(i))
		hbox_top.add_child(up_btn)

		var down_btn = Button.new(text="↓")
		down_btn.pressed.connect(func(): move_layer_down(i))
		hbox_top.add_child(down_btn)

		vbox.add_child(hbox_top)

		# Parameters area (dynamic)
		var param_container = VBoxContainer.new()
		param_container.name = "ParamContainer"
		vbox.add_child(param_container)
		_refresh_param_ui(i, param_container)

		layer_container.add_child(card)

func _refresh_param_ui(layer_index: int, container: VBoxContainer):
	# Clear old
	for child in container.get_children():
		child.queue_free()

	var layer = layers[layer_index]
	var params_def = FunctionRegistry.get_parameters(layer.function_id)
	for p in params_def:
		var hbox = HBoxContainer.new()
		var label = Label.new(text=p.name.capitalize() + ":")
		label.custom_minimum_size.x = 80
		hbox.add_child(label)

		var control = _create_param_control(p, layer.parameters.get(p.name, p.default))
		control.name = p.name
		# Connect value changed to update layer.parameters and recompile only if needed
		_connect_param_signal(control, layer, p.name)
		hbox.add_child(control)
		container.add_child(hbox)

func _create_param_control(param_def: Dictionary, initial_value) -> Control:
	var type = param_def.type
	match type:
		"float":
			var spin = SpinBox.new()
			spin.step = 0.01
			if param_def.has("range"):
				spin.min_value = param_def.range[0]
				spin.max_value = param_def.range[1]
			else:
				spin.min_value = -1000
				spin.max_value = 1000
			spin.value = initial_value
			return spin
		"vec2":
			var container = HBoxContainer.new()
			var x_spin = SpinBox.new()
			var y_spin = SpinBox.new()
			x_spin.step = 0.01
			y_spin.step = 0.01
			x_spin.value = initial_value.x
			y_spin.value = initial_value.y
			container.add_child(x_spin)
			container.add_child(y_spin)
			# We'll store both in a custom wrapper; but for simplicity return a reference to both.
			# Actually we need a single control that returns Vector2. Use a VBoxContainer and provide custom signal.
			# Simpler: use a LineEdit with parsing? Let's use a custom node or two spinboxes with a group.
			# For brevity, we'll store metadata and use a dictionary.
			var wrapper = Control.new()
			wrapper.set_meta("x_spin", x_spin)
			wrapper.set_meta("y_spin", y_spin)
			return wrapper
		"color":
			var color_btn = ColorPickerButton.new()
			color_btn.color = initial_value
			return color_btn
		"sampler2D":
			var tex_btn = Button.new(text="Load Texture")
			tex_btn.set_meta("path", initial_value)
			return tex_btn
		_:
			return LineEdit.new()

func _connect_param_signal(control: Control, layer: Layer, param_name: String):
	var type = typeof(control)
	if control is SpinBox:
		control.value_changed.connect(func(val): layer.parameters[param_name] = val; _parameter_changed())
	elif control is ColorPickerButton:
		control.color_changed.connect(func(col): layer.parameters[param_name] = col; _parameter_changed())
	elif control.get_meta("x_spin") != null:
		var x_spin = control.get_meta("x_spin")
		var y_spin = control.get_meta("y_spin")
		var update = func(_v): layer.parameters[param_name] = Vector2(x_spin.value, y_spin.value); _parameter_changed()
		x_spin.value_changed.connect(update)
		y_spin.value_changed.connect(update)
	elif control is Button and control.text == "Load Texture":
		control.pressed.connect(func():
			var file_dialog = FileDialog.new()
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.add_filter("*.png,*.jpg,*.webp ; Images")
			add_child(file_dialog)
			file_dialog.file_selected.connect(func(path):
				var tex = load(path)
				if tex:
					layer.parameters[param_name] = tex
					_parameter_changed()
				file_dialog.queue_free()
			)
			file_dialog.popup_centered()
		)

func _parameter_changed():
	# Only update uniform values (no recompilation) if the shader is already compiled and the uniform exists.
	if current_material.shader:
		_update_all_uniforms()
	else:
		_compile_shader()

func _update_all_uniforms():
	# Called after recompilation or after parameter changes that don't affect struct
	for i in range(layers.size()):
		var layer = layers[i]
		if not layer.enabled:
			continue
		var prefix = "layer%d_" % i
		for param_name in layer.parameters:
			var uniform_name = prefix + param_name
			var value = layer.parameters[param_name]
			# Convert Godot types to shader-compatible
			if value is Color:
				value = Vector3(value.r, value.g, value.b)
			elif value is Texture2D:
				# For sampler2D we need to set the texture
				current_material.set_shader_parameter(uniform_name, value)
				continue
			current_material.set_shader_parameter(uniform_name, value)

func _on_function_changed(layer_index: int, option_idx: int):
	var new_id = FunctionRegistry.get_ids()[option_idx]
	var layer = layers[layer_index]
	layer.function_id = new_id
	# Reset parameters to defaults
	var new_params_def = FunctionRegistry.get_parameters(new_id)
	var new_params = {}
	for p in new_params_def:
		new_params[p.name] = p.default
	layer.parameters = new_params
	rebuild_layer_ui()  # rebuilds params for this layer
	_compile_shader()

# ------------------------------------------------------------
# Shader compilation
# ------------------------------------------------------------
func _compile_shader():
	if _compilation_pending:
		return
	_compilation_pending = true
	await get_tree().process_frame
	_compilation_pending = false

	var code = ShaderAssembler.generate_shader(layers)
	var shader = Shader.new()
	var error = shader.set_code(code)
	if error != OK:
		error_label.text = "Shader compilation error! Check code view."
		printerr("Shader compilation failed:\n", code)
		# Optionally display the code in popup anyway
	else:
		error_label.text = ""
		current_material.shader = shader
		_update_all_uniforms()
	# Store latest code for popup
	code_text.text = code

func _show_code_popup():
	code_popup.popup_centered_ratio(0.7)
