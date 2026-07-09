class_name MaterialUIController extends PanelContainer

var material_data: Dictionary
var shader_code: String

@onready var name_line: Label = $HBoxContainer/VBoxContainer/MaterialName
@onready var preview_rect: ColorRect = $HBoxContainer/VBoxContainer/PreviewContainer/Preview
@onready var similarity_label: Label = $HBoxContainer/HBoxContainer/Sim
@onready var complexity_label: Label = $HBoxContainer/HBoxContainer/Complexity
@onready var size_label: Label = $HBoxContainer/HBoxContainer/Size
@onready var apply_button: Button = $HBoxContainer/HBoxContainer/Button

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


func setup(_material_data: String, similarity: float, id: int) -> void:
	material_data = EditorMaterial.parce_json_string_to_dict(_material_data)

	var generator := MaterialCodeGenerator.new()
	shader_code = generator.generate_shader_code(material_data)

	name_line.text = material_data.get(&"name", "Material %d"%id)
	similarity_label.text = "Степень сходства: %f.4" % similarity
	var comp = material_data.get(&"complexity", -1)
	complexity_label.text = "Вычислительная сложность: "+get_complexity() if comp == -1 else str(comp)
	var sz = material_data.get(&"size", -1)
	size_label.text = "Вес: %s Кб" % (get_material_size() if sz == -1 else str(sz))

	#var image := await GConnector._generate_render(_material_data, true)
	#preview_rect.texture = ImageTexture.create_from_image(image)
	var _shader_material := ShaderMaterial.new()
	generator._cache.invalidate_fragment()
	var code := generator.generate_shader_code(material_data,"canvas_item")

	var shader := Shader.new()
	shader.code = code
	_shader_material.shader = shader
	preview_rect.material = _shader_material


func get_complexity()->String:
	return str(
		material_data.get(&"channels", {}).size()*2
		+ EditorMaterial.get_modifers_count(material_data)*2
		+ EditorMaterial.get_generators_params_count(material_data)
		+ material_data.get(&"generators", {}).size()*3
	)

## Один символ = 4 байта.
func get_material_size()->String:
	return str(
		len(shader_code) / 256  # Количество символов в строковом представлении шейдера * 256 = Кб
	)


func _on_button_pressed() -> void:
	if EditorMaterial.load_project_from_dict(material_data):
		get_parent().get_parent().get_parent().get_parent().get_parent().clear()
