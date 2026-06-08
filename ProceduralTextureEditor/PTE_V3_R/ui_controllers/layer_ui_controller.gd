class_name LayerUIController
extends VBoxContainer

var layer_index: int
var layer_data_path: Array[StringName]

var name_edit: LineEdit
var generator_selector: OptionButton
var blend_mode_selector: OptionButton
var modifiers_list: VBoxContainer

func setup(channel_path: Array[StringName], index: int) -> void:
	layer_index = index
	layer_data_path = channel_path.duplicate()
	layer_data_path.append("layers")
	layer_data_path.append(str(index))
	
	# Загрузка текущих данных
	var layer_dict = _get_layer_dict()
	
	# Поле имени
	name_edit = LineEdit.new()
	name_edit.text = layer_dict.get("имя", "Слой")
	name_edit.text_changed.connect(_on_name_changed)
	add_child(name_edit)
	
	# Выбор генератора
	generator_selector = OptionButton.new()
	for gen_name in GeneratorLibrary.get_all_names():
		generator_selector.add_item(gen_name)
	generator_selector.select(generator_selector.get_item_index(layer_dict.get("генератор", {}).get("имя генератора", "")))
	generator_selector.item_selected.connect(_on_generator_selected)
	add_child(generator_selector)
	
	# Режим смешивания
	blend_mode_selector = OptionButton.new()
	blend_mode_selector.add_item("Normal")
	blend_mode_selector.add_item("Add")
	blend_mode_selector.add_item("Multiply")
	# ... заполнить из enum
	blend_mode_selector.select(layer_dict.get("режим смешивания", 0))
	blend_mode_selector.item_selected.connect(_on_blend_mode_changed)
	add_child(blend_mode_selector)
	
	# Контейнер параметров генератора (динамический)
	var gen_params_container = VBoxContainer.new()
	add_child(gen_params_container)
	_rebuild_generator_ui(gen_params_container)
	
	# Модификаторы
	modifiers_list = VBoxContainer.new()
	add_child(modifiers_list)
	_rebuild_modifiers_ui()
	
	# Кнопка добавления модификатора
	var add_mod_btn = Button.new()
	add_mod_btn.text = "Добавить модификатор"
	add_mod_btn.pressed.connect(_on_add_modifier)
	add_child(add_mod_btn)

func _get_layer_dict() -> Dictionary:
	var current = EditorMaterial.editorMaterialData 
	for key in layer_data_path:
		current = current[key]
	return current

func _on_name_changed(new_name: String):
	var layer = _get_layer_dict()
	layer["имя"] = new_name
	EditorMaterial.editorMaterialData._update()  # оповестить систему

func _on_generator_selected(idx: int):
	var gen_name = generator_selector.get_item_text(idx)
	var layer = _get_layer_dict()
	if not layer.has("генератор"):
		layer["генератор"] = {}
	layer["генератор"]["имя генератора"] = gen_name
	# Сбросить параметры до значений по умолчанию
	var gen_data = GeneratorLibrary.get_generator_data(gen_name)
	var new_params = {}
	for pname in gen_data.parameters:
		new_params[pname] = gen_data.parameters[pname].default_value
	layer["генератор"]["параметры"] = new_params
	# Перестроить UI параметров
	_rebuild_generator_ui()
