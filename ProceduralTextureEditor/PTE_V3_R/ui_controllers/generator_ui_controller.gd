class_name GeneratorUIController extends PanelContainer

@export var generator_data: GeneratorData:
	set(value):
		generator_data = value
		_refresh_ui()
@onready var name_line: Label = $VBoxContainer/GeneratorName
@onready var preview_rect: ColorRect = $VBoxContainer/PreviewContainer/Preview
@onready var parameters_container: VBoxContainer = $VBoxContainer/ParameterScroll/ParameterList

var normal_style = preload("res://PTE_V3_R/styles/normal_style_box.tres")
var highlight_style = preload("res://PTE_V3_R/styles/selected_style_box.tres")

var _material: ShaderMaterial
var param_controls: Dictionary[String, ParameterControl] = {}
var generator_path: MaterialPath
var generator_id: StringName


var is_selected := false:
	set(value):
		is_selected = value
		_update_style()

func _update_style() -> void:
	var style = highlight_style if is_selected else normal_style
	add_theme_stylebox_override("panel", style)

func set_selected(selected: bool) -> void:
	is_selected = selected

func _ready() -> void:
	add_theme_stylebox_override("panel", normal_style)
	_material = ShaderMaterial.new()
	preview_rect.material = _material
	if generator_data:
		_refresh_ui()


func setup(generator_name:StringName, id: StringName) -> void:
	generator_id = id
	generator_path = MaterialPath.new([&"generators",generator_id])

	name_line.text = generator_name
	var gen_data := GeneratorLibrary.get_generator_data(generator_name)

	if gen_data:
		generator_data = gen_data
		
func _refresh_ui() -> void:
	if not is_inside_tree() or not generator_data:
		return
	
	_material.shader = generator_data.preview_shader
	_clear_parameter_ui()
	param_controls.clear()
	
	for param_name in generator_data.parameters:
		var def: abstractParameterDef = generator_data.parameters[param_name]
		var control = ParameterControlFactory.create(def)
		if control == null:
			continue
		parameters_container.add_child(control)
		control.setup(def, param_name)
		var param_path := generator_path.child(&"parameters").child(param_name)
		control.bind(param_path)

		control.value_changed.connect(_on_parameter_changed.bind(param_name))
		param_controls[param_name] = control
		var value = param_path.get_value()

		if value == null:
			value = def.default_value

		_material.set_shader_parameter(param_name,value)
	


func _clear_parameter_ui() -> void:
	for child in parameters_container.get_children():
		child.queue_free()



func _on_parameter_changed(new_value, param_name: String) -> void:
	_material.set_shader_parameter(param_name, new_value)
