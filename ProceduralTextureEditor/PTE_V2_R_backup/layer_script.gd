extends Control

signal modified
signal move_up_requested
signal move_down_requested

@export var layer_data: LayerData:
	set(val):
		layer_data = val
		_refresh_ui()

@onready var name_edit: LineEdit = $HSplitContainer/LayerOptionsContainer/VBoxContainer/HBoxContainer/LayerName
@onready var active_check = $HSplitContainer/LayerOptionsContainer/VBoxContainer/HBoxContainer/Enabled
@onready var mix_option = $HSplitContainer/LayerOptionsContainer/VBoxContainer/HBoxContainer/BlendModes
@onready var func_option = $HSplitContainer/LayerOptionsContainer/VBoxContainer/FunctionSelector
@onready var opacity_slider = $HSplitContainer/LayerOptionsContainer/VBoxContainer/OpacitySlider
@onready var preview_rect = $HSplitContainer/PreviewContainer/Preview
@onready var uniforms: VBoxContainer = $HSplitContainer/LayerOptionsContainer/VBoxContainer/uniforms
@onready var btn_up: Button = $HSplitContainer/LayerOptionsContainer/VBoxContainer/HBoxContainer/move_up
@onready var btn_down: Button = $HSplitContainer/LayerOptionsContainer/VBoxContainer/HBoxContainer/move_down

func _ready():
	# Fill dropdowns
	for id in MixDB.get_ids():
		mix_option.add_item(MixDB.get_mix_mode_name(id), id)
	for id in FuncDB.get_ids():
		func_option.add_item(FuncDB.get_function_name(id), id)

	# Connect signals
	btn_up.pressed.connect(func(): move_up_requested.emit())
	btn_down.pressed.connect(func(): move_down_requested.emit())
	name_edit.text_changed.connect(_on_name_changed)
	active_check.toggled.connect(_on_active_toggled)
	mix_option.item_selected.connect(_on_mix_selected)
	func_option.item_selected.connect(_on_func_selected)
	opacity_slider.value_changed.connect(_on_opacity_changed)

	if layer_data:
		_refresh_ui()

func _refresh_ui():
	if not layer_data or not is_inside_tree():
		return
	name_edit.text = layer_data.layer_name
	active_check.button_pressed = layer_data.active
	mix_option.select(mix_option.get_item_index(layer_data.mix_mode))
	func_option.select(func_option.get_item_index(layer_data.func_id))
	opacity_slider.value = layer_data.opacity
	_update_uniforms()   # <--- added

func _on_name_changed(txt): layer_data.layer_name = txt; modified.emit()
func _on_active_toggled(active): layer_data.active = active; modified.emit()
func _on_mix_selected(idx): layer_data.mix_mode = mix_option.get_item_id(idx); modified.emit()
func _on_func_selected(idx):
	layer_data.func_id = func_option.get_item_id(idx)
	modified.emit()
	_update_uniforms()   # <--- added

func _on_opacity_changed(val): layer_data.opacity = val; modified.emit()


func _update_uniforms():
	# Clear previous controls
	for child in uniforms.get_children():
		child.queue_free()

	if not layer_data:
		return

	var func_id = layer_data.func_id
	if not FuncDB.functions.has(func_id):
		return

	var func_def = FuncDB.functions[func_id]
	for param in func_def["params"]:
		var param_name = param["name"]
		var type = param["type"]
		var default_str = param["default"]

		# Determine current value (stored override or parsed default)
		var current_val
		if layer_data.func_params.has(param_name):
			current_val = layer_data.func_params[param_name]
		else:
			current_val = _parse_default(default_str, type)

		# Container for label + control
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = param_name.capitalize() + ": "
		hbox.add_child(label)

		# Create the appropriate control
		var ctrl: Control
		if type == "float":
			var slider = HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 100.0
			slider.step = 0.01
			slider.value = float(current_val) if typeof(current_val) != TYPE_FLOAT else current_val
			slider.value_changed.connect(func(v): _on_param_changed(param_name, v))
			ctrl = slider
		elif type == "vec3":
			var picker = ColorPickerButton.new()
			if current_val is Color:
				picker.color = current_val
			else:
				picker.color = Color.WHITE   # fallback
			picker.color_changed.connect(func(c): _on_param_changed(param_name, c))
			ctrl = picker
		else:
			continue   # unsupported type, skip

		hbox.add_child(ctrl)
		uniforms.add_child(hbox)

func _on_param_changed(param_name: String, value):
	layer_data.func_params[param_name] = value
	modified.emit()

# --- Helper parsing of FuncDB default strings ---
func _parse_default(s: String, type: String):
	match type:
		"float":
			return float(s)
		"vec3":
			return _parse_vec3_default(s)
		_:
			return null

func _parse_vec3_default(s: String) -> Color:
	# Handles: "vec3(r, g, b)" or "vec3(v)" (uniform vec3 constructor)
	var regex = RegEx.new()
	regex.compile("vec3\\((.+)\\)")
	var result = regex.search(s)
	if not result:
		return Color.WHITE

	var inner = result.get_string(1).strip_edges()
	var parts = inner.split(",")
	if parts.size() == 1:
		var v = float(parts[0])
		return Color(v, v, v)
	elif parts.size() >= 3:
		return Color(float(parts[0]), float(parts[1]), float(parts[2]))
	return Color.WHITE
