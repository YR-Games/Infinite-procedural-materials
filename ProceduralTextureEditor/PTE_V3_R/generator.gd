class_name Generator extends PanelContainer

@export var generator_data: GeneratorData:
	set(value):
		generator_data = value
		_refresh_ui()

var normal_style = preload("res://PTE_V3_R/styles/normal_style_box.tres")
var highlight_style = preload("res://PTE_V3_R/styles/selected_style_box.tres")
@onready var name_line: Label = $VBoxContainer/GeneratorName
@onready var preview_rect: ColorRect = $VBoxContainer/PreviewContainer/Preview
@onready var parameter_list: VBoxContainer = $VBoxContainer/ParameterScroll/ParameterList



var _material: ShaderMaterial
var _param_controls: Dictionary = {}   # param_name -> Control

func _ready() -> void:
	add_theme_stylebox_override("panel", normal_style)
	_material = ShaderMaterial.new()
	preview_rect.material = _material
	if generator_data:
		_refresh_ui()

var is_selected := false:
	set(value):
		is_selected = value
		_update_style()

func _update_style() -> void:
	var style = highlight_style if is_selected else normal_style
	add_theme_stylebox_override("panel", style)

func set_selected(selected: bool) -> void:
	is_selected = selected


func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	# Update name
	name_line.text = generator_data.generator_name

	# Update shader and reset material
	_material.shader = generator_data.preview_shader
	_clear_parameter_ui()
	_param_controls.clear()

	# Set default uniforms from data
	for param_def in generator_data.parameters:
		_material.set_shader_parameter(param_def.param_name, param_def.default_value)

	# Build UI for each parameter
	for param_def in generator_data.parameters:
		var control = _create_control_for_param(param_def)
		if control:
			parameter_list.add_child(control)
			_param_controls[param_def.param_name] = control
			_connect_control(control, param_def)

	# Force first preview update
	_update_preview()

func _clear_parameter_ui() -> void:
	for child in parameter_list.get_children():
		child.queue_free()



func _create_control_for_param(def: abstract_parameter_def) -> Control:
	# For flexibility, use a pre‑made scene or build in code.
	# Here we build a simple HBoxContainer with a Label and a value control.
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = def.display_name if not def.display_name.is_empty() else def.param_name.capitalize()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	#print(def.get_script().get_global_name())
	match def.get_script().get_global_name():
		"float_parameter_def", "int_parameter_def":
			var slider = HSlider.new()
			slider.min_value = def.min_value
			slider.max_value = def.max_value
			slider.step = def.step
			slider.value = float(def.default_value)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(slider)
			return hbox
			
			"""ParameterDef.Type.COLOR:
			var picker = ColorPickerButton.new()
			picker.color = def.default_value
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(picker)
			return hbox
			ParameterDef.Type.BOOL:
			var check = CheckBox.new()
			check.button_pressed = bool(def.default_value)
			hbox.add_child(check)
			return hbox
			ParameterDef.Type.VECTOR2:
			# Two spinboxes…
			var vbox = VBoxContainer.new()
			var xspin = SpinBox.new(); xspin.min_value = def.min_value; xspin.max_value = def.max_value
			var yspin = SpinBox.new(); yspin.min_value = def.min_value; yspin.max_value = def.max_value
			xspin.value = def.default_value.x; yspin.value = def.default_value.y
			vbox.add_child(xspin); vbox.add_child(yspin)
			hbox.add_child(vbox)
			return hbox"""
		# VECTOR3 would be similar
	return null

func _connect_control(control: Control, def: abstract_parameter_def) -> void:
	# Find the actual input child inside the HBox
	var input = control.get_child(1) if control is HBoxContainer and control.get_child_count() > 1 else control
	match def.get_script().get_global_name():
		"float_parameter_def", "int_parameter_def":
			input.value_changed.connect(_on_float_changed.bind(def.param_name))
			"""
			ParameterDef.Type.COLOR:
			input.color_changed.connect(_on_color_changed.bind(def.param_name))
			ParameterDef.Type.BOOL:
			input.toggled.connect(_on_bool_changed.bind(def.param_name))
			ParameterDef.Type.VECTOR2:
			# Connect both spinboxes; we'll need a helper to rebuild Vector2
			var xspin = input.get_child(0)
			var yspin = input.get_child(1)
			xspin.value_changed.connect(_on_vec2_changed.bind(def.param_name, 0))
			yspin.value_changed.connect(_on_vec2_changed.bind(def.param_name, 1))
			"""
# --- Callbacks: update material uniform instantly ---
func _on_float_changed(value: float, param: String) -> void:
	_material.set_shader_parameter(param, value)

func _on_color_changed(color: Color, param: String) -> void:
	_material.set_shader_parameter(param, color)

func _on_bool_changed(toggled: bool, param: String) -> void:
	_material.set_shader_parameter(param, toggled)

func _on_vec2_changed(value: float, param: String, axis: int) -> void:
	var vec = _material.get_shader_parameter(param) as Vector2
	vec[axis] = value
	_material.set_shader_parameter(param, vec)

func _update_preview() -> void:
	pass
