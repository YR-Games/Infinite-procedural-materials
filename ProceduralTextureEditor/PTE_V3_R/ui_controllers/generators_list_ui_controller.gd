class_name GeneratorListUIController
extends PanelContainer

var panels: Array[GeneratorUIController] = []
var current: GeneratorUIController = null

@onready var add_generator_button: Button = $VBoxContainer/AddGeneratorButton
@onready var generators_container: VBoxContainer = $VBoxContainer/ScrollContainer/GeneratorsContainer

signal generator_selected(generator_id: StringName)

func _ready() -> void:
	add_generator_button.pressed.connect(_on_add_generator_button_pressed)
	SignalBus.project_loaded.connect(_refresh)

func _on_add_generator_button_pressed() -> void:
	var picker_scene = preload("res://PTE_V3_R/UI/generator_picker.tscn")
	var picker = picker_scene.instantiate() as GeneratorPicker
	add_child(picker)
	picker.generator_selected.connect(_on_generator_selected)
	picker.popup_centered()


func _on_generator_selected(gen_name: StringName) -> void:
	add_generator(gen_name)

func _refresh() -> void:

	for child in generators_container.get_children():
		child.queue_free()

	panels.clear()
	current = null

	var controller_scene = preload("res://PTE_V3_R/UI/generator_ui.tscn")
	for generator_id in EditorMaterial.get_generator_ids():
		var generator := EditorMaterial.get_generator(generator_id)

		var generator_name : StringName = generator.get("generator_name",StringName())

		if generator_name.is_empty():
			continue

		var controller : GeneratorUIController = controller_scene.instantiate()
		generators_container.add_child(controller)
		controller.setup(generator_name,generator_id)
		controller.gui_input.connect(_on_panel_gui_input.bind(controller))

		panels.append(controller)

# ---------------------- Добавление генератора ----------------------

func add_generator(generator_type_name: StringName) -> void:

	var gen_data := GeneratorLibrary.get_generator_data(generator_type_name)

	if not gen_data:
		push_error("Генератор '%s' не найден в библиотеке" % generator_type_name)
		return

	var default_params := {}

	for param_name in gen_data.parameters:
		var param_def = gen_data.parameters[param_name]
		default_params[param_name] = param_def.default_value

	var id := StringName(_generate_unique_id())

	EditorMaterial.add_generator(id,generator_type_name,default_params)

	var controller_scene = preload("res://PTE_V3_R/UI/generator_ui.tscn")
	var controller: GeneratorUIController = controller_scene.instantiate()
	generators_container.add_child(controller)
	controller.setup(generator_type_name,id)
	controller.gui_input.connect(_on_panel_gui_input.bind(controller))
	panels.append(controller)


func _generate_unique_id() -> String:
	return "gen_%d_%d" % [Time.get_ticks_usec(),randi()]


# ---------------------- Выделение ----------------------

func _on_panel_gui_input(event: InputEvent,panel: GeneratorUIController) -> void:

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		SelectionManager.select(panel)
		generator_selected.emit(panel.generator_id)



# ---------------------- Удаление ----------------------

func _unhandled_input(event: InputEvent) -> void:

	if (event.is_action_pressed("ui_text_delete")and current):
		_remove_panel(current)


func _remove_panel(panel: GeneratorUIController) -> void:

	EditorMaterial.remove_generator(panel.generator_id)

	if current == panel:
		current = null

	panels.erase(panel)
	panel.queue_free()
