class_name MaterialUIController extends PanelContainer

## При установке всегда вызывать [method _refresh_ui]!
var material_data: Dictionary

@onready var name_line: Label = $VBoxContainer/MaterialName
@onready var preview_rect: ColorRect = $VBoxContainer/PreviewContainer/Preview
@onready var similarity_label: Label = $VBoxContainer/HBoxContainer/Sim
@onready var complexity_label: Label = $VBoxContainer/HBoxContainer/Complexity
@onready var size_label: Label = $VBoxContainer/HBoxContainer/Size
@onready var apply_button: Button = $VBoxContainer/HBoxContainer/Button

var normal_style = preload("res://PTE_V3_R/styles/normal_style_box.tres")
var highlight_style = preload("res://PTE_V3_R/styles/selected_style_box.tres")

var _material: ShaderMaterial


var is_selected := false:
	set(value):
		is_selected = value
		_update_style()

func _update_style() -> void:
	var style = highlight_style if is_selected else normal_style
	add_theme_stylebox_override("panel", style)

func _ready() -> void:
	add_theme_stylebox_override("panel", normal_style)
	_material = ShaderMaterial.new()
	preview_rect.material = _material


func setup(_material_data: Dictionary, id: int) -> void:
	material_data = _material_data
	name_line.text = material_data.get(&"name", "Material %d"%id)
	similarity_label.text = material_data.get(&"similarity", 0.5)
	var comp = material_data.get(&"complexity", -1)
	complexity_label.text = get_complexity() if comp == -1 else str(comp)
	var sz = material_data.get(&"size", -1)
	similarity_label.text = get_material_size() if sz == -1 else str(sz)
	_material.shader = material_data.preview_shader #??? Получить шейдер из запекателя!!


func get_complexity()->String:
	return str(material_data.get(&"channels", 0)*2 + material_data.get(&"generators", 0))

## Один символ = 4 байта.
func get_material_size()->String:
	return str(
		##??? Количество символов в строковом представлении шейдера * 256 = кб
	)
