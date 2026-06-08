class_name GeneratorListUIController
extends PanelContainer

var panels: Array[GeneratorUIController] = []
var current: GeneratorUIController = null

@onready var add_generator_button: Button = $VBoxContainer/AddGeneratorButton
@onready var generators_container: VBoxContainer = $VBoxContainer/ScrollContainer/GeneratorsContainer

func _ready() -> void:
	# Собираем уже существующие панели (если они были добавлены в сцене)
	for child in get_children():
		if child is GeneratorUIController:
			panels.append(child)
			child.gui_input.connect(_on_panel_gui_input.bind(child))
	
	add_generator_button.pressed.connect(_on_add_generator_button_pressed)


func _on_add_generator_button_pressed() -> void:
	var picker_scene = preload("res://PTE_V3_R/UI/generator_picker.tscn")
	var picker = picker_scene.instantiate() as GeneratorPicker
	add_child(picker)
	picker.generator_selected.connect(_on_generator_selected)
	picker.popup_centered()


func _on_generator_selected(gen_name: StringName) -> void:
	add_generator(gen_name)


# ---------------------- Добавление нового генератора ----------------------
func add_generator(generator_type_name: StringName) -> void:
	var gen_data = GeneratorLibrary.get_generator_data(generator_type_name)
	if not gen_data:
		push_error("Генератор '%s' не найден в библиотеке" % generator_type_name)
		return
	
	# 1. Создаём словарь параметров со значениями по умолчанию
	var default_params = {}
	for param_name in gen_data.parameters:
		var param_def = gen_data.parameters[param_name]
		default_params[param_name] = param_def.default_value
	
	# 2. Генерируем уникальный идентификатор и добавляем запись в центральное хранилище
	var id = _generate_unique_id()
	var generator_entry = {
		&"имя генератора": generator_type_name,
		&"параметры": default_params
	}
	EditorMaterial.editorMaterialData["generators"][id] = generator_entry
	
	var controller_scene = preload("res://PTE_V3_R/UI/generator_ui.tscn")
	var controller = controller_scene.instantiate()
	var path: Array[StringName] = [&"generators", StringName(id)]
	generators_container.add_child(controller)
	panels.append(controller)
	controller.setup(generator_type_name, path)
	

	
	# 4. Выделяем новую панель
	select(controller)
	
	# 5. (Опционально) сохраняем изменения
	# EditorMaterial.save_to_file()


# Генерация уникального строкового ключа
func _generate_unique_id() -> String:
	return "gen_%d_%d" % [Time.get_ticks_usec(), randi()]


# ---------------------- Управление выделением и удалением ----------------------
func _on_panel_gui_input(event: InputEvent, panel: GeneratorUIController) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select(panel)

func select(panel: GeneratorUIController) -> void:
	if current == panel:
		return
	if current:
		current.set_selected(false)
	current = panel
	if current:
		current.set_selected(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_delete") and current:
		_remove_panel(current)

func _remove_panel(panel: GeneratorUIController) -> void:
	# Получаем путь к данным генератора (например, ["generators", "gen_123"])
	var data_path = panel.data_path
	if data_path.size() >= 2 and data_path[0] == "generators":
		var id = data_path[1]
		EditorMaterial.editorMaterialData["generators"].erase(id)
	
	if current == panel:
		current = null
	panel.queue_free()
	panels.erase(panel)
