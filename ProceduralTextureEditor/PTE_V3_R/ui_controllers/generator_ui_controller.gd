class_name GeneratorUIController extends PanelContainer

@export var generator_data: GeneratorData:
	set(value):
		generator_data = value
		_refresh_ui()

var normal_style = preload("res://PTE_V3_R/styles/normal_style_box.tres")
var highlight_style = preload("res://PTE_V3_R/styles/selected_style_box.tres")

@onready var name_line: Label = $VBoxContainer/GeneratorName
@onready var preview_rect: ColorRect = $VBoxContainer/PreviewContainer/Preview
@onready var parameters_container: VBoxContainer = $VBoxContainer/ParameterScroll/ParameterList

var _material: ShaderMaterial
var param_controls: Dictionary[String, ParameterControl] = {}
var data_path: Array[StringName]

var is_selected := false:
	set(value):
		is_selected = value
		_update_style()

func _ready() -> void:
	add_theme_stylebox_override("panel", normal_style)
	_material = ShaderMaterial.new()
	preview_rect.material = _material
	if generator_data:
		_refresh_ui()

func _update_style() -> void:
	var style = highlight_style if is_selected else normal_style
	add_theme_stylebox_override("panel", style)

func set_selected(selected: bool) -> void:
	is_selected = selected

func setup(generator_name: StringName, path: Array[StringName]) -> void:
	data_path = path
	name_line.text = generator_name
	var gen_data: GeneratorData = GeneratorLibrary.get_generator_data(generator_name)
	if not gen_data:
		return
	generator_data = gen_data

func _refresh_ui() -> void:
	if not is_inside_tree() or not generator_data:
		return
	
	_material.shader = generator_data.preview_shader
	_clear_parameter_ui()
	param_controls.clear()
	
	for param_name in generator_data.parameters:
		var def: abstract_parameter_def = generator_data.parameters[param_name]
		var control: ParameterControl
		
		if def is float_parameter_def:
			var c = FloatParameterControl.new()
			c.setup(def, param_name)
			control = c
		elif def is int_parameter_def:
			var c = IntParameterControl.new()
			c.setup(def, param_name)
			control = c
		else:
			continue
		
		var full_path = data_path.duplicate()
		full_path.append("параметры")
		full_path.append(param_name)
		control.set_data_path(full_path)
		control.value_changed.connect(_on_parameter_changed.bind(param_name))
		
		parameters_container.add_child(control)
		param_controls[param_name] = control
	
	_load_initial_shader_values()

func _clear_parameter_ui() -> void:
	for child in parameters_container.get_children():
		child.queue_free()

func _load_initial_shader_values() -> void:
	for param_name in generator_data.parameters:
		var def = generator_data.parameters[param_name]
		var value = def.default_value
		var full_path = data_path.duplicate()
		full_path.append("параметры")
		full_path.append(param_name)
		var existing = _get_value_at_path(full_path)
		if existing != null:
			value = existing
		_material.set_shader_parameter(param_name, value)

func _get_value_at_path(path: Array[StringName]):
	var current = EditorMaterial.editorMaterialData
	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null
	return current

func _on_parameter_changed(new_value, param_name: String) -> void:
	_material.set_shader_parameter(param_name, new_value)
