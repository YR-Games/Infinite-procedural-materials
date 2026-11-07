class_name GeneratorListUIController
extends PanelContainer

const GENERATOR_SCENE := preload("res://PTE_V3_R/UI/generator_ui.tscn")
const PICKER_SCENE := preload("res://PTE_V3_R/UI/generator_picker.tscn")

var panels: Array[GeneratorUIController] = []
var current: GeneratorUIController = null

@onready var add_generator_button: Button = $VBoxContainer/AddGeneratorButton
@onready var generators_container: VBoxContainer = $VBoxContainer/ScrollContainer/GeneratorsContainer

signal generator_selected(generator_id: StringName)


func _ready() -> void:
	add_generator_button.pressed.connect(_on_add_generator_button_pressed)
	SignalBus.project_loaded.connect(_refresh)
	# Generators created/removed by scripts show up automatically.
	SignalBus.generator_structure_changed.connect(_sync)


func _on_add_generator_button_pressed() -> void:
	var picker := PICKER_SCENE.instantiate() as GeneratorPicker
	add_child(picker)
	picker.generator_selected.connect(add_generator)
	picker.popup_centered()


## Full rebuild (project loaded).
func _refresh() -> void:
	for panel in panels.duplicate():
		_drop(panel)
	_sync()


## Incremental sync: UI follows EditorMaterial.
func _sync() -> void:
	var wanted := EditorMaterial.get_generator_ids()

	for panel in panels.duplicate():
		if not wanted.has(panel.generator_id):
			_drop(panel)

	var index := 0
	for generator_id in wanted:
		var panel := get_panel(generator_id)
		if panel == null:
			panel = _spawn(generator_id)
		if panel == null:
			continue  # generator without a name -> no UI
		generators_container.move_child(panel, index)
		index += 1


func get_panel(generator_id: StringName) -> GeneratorUIController:
	for panel in panels:
		if panel.generator_id == generator_id:
			return panel
	return null


func _spawn(generator_id: StringName) -> GeneratorUIController:
	var generator := EditorMaterial.get_generator(generator_id)
	var generator_name: StringName = generator.get(&"generator_name", StringName())
	if generator_name.is_empty():
		return null

	var panel := GENERATOR_SCENE.instantiate() as GeneratorUIController
	generators_container.add_child(panel)
	panel.setup(generator_name, generator_id)
	panel.gui_input.connect(_on_panel_gui_input.bind(panel))
	panels.append(panel)
	return panel


func _drop(panel: GeneratorUIController) -> void:
	panels.erase(panel)
	if current == panel:
		current = null
	generators_container.remove_child(panel)
	panel.queue_free()


# ---------------------- Actions ----------------------

## Creates a generator with library defaults. Returns its id ("" if unknown type).
func add_generator(generator_type_name: StringName) -> StringName:
	if GeneratorLibrary.get_generator_data(generator_type_name) == null:
		push_error("Генератор '%s' не найден в библиотеке" % generator_type_name)
		return StringName()
	return EditorMaterial.create_generator(generator_type_name)  # signal -> _sync() creates the UI


func _on_panel_gui_input(event: InputEvent, panel: GeneratorUIController) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.select(panel)
		generator_selected.emit(panel.generator_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_delete") and current:
		_remove_panel(current)


func _remove_panel(panel: GeneratorUIController) -> void:
	EditorMaterial.remove_generator(panel.generator_id)  # -> _sync() drops the UI
