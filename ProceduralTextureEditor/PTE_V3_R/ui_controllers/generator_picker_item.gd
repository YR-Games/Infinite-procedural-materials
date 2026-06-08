class_name GeneratorPickerItem
extends PanelContainer

signal selected(generator_name: StringName)

@export var generator_name: StringName = "":
	set(value):
		generator_name = value
		_update_ui()

var _preview_material: ShaderMaterial

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var preview_rect: ColorRect = $VBoxContainer/ColorRect


func _ready() -> void:
	_preview_material = ShaderMaterial.new()
	preview_rect.material = _preview_material
	_update_ui()
	gui_input.connect(_on_gui_input)


func _update_ui() -> void:
	if not is_inside_tree():
		return
	name_label.text = generator_name
	var gen_data = GeneratorLibrary.get_generator_data(generator_name)
	if gen_data and gen_data.preview_shader:
		_preview_material.shader = gen_data.preview_shader
	else:
		preview_rect.color = Color.GRAY


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(generator_name)
