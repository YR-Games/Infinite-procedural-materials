class_name ChannelUIController
extends PanelContainer

const LAYER_SCENE := preload("res://PTE_V3_R/UI/layer_ui.tscn")

var channel_name: StringName

var layer_controllers: Array[LayerUIController] = []
var current_layer: LayerUIController = null

@onready var channel_label: Label = $VBoxContainer/ChannelNameLabel
@onready var layers_container: VBoxContainer = $VBoxContainer/ChannelsScrollContainer/LayersContainer
@onready var add_layer_button: Button = $VBoxContainer/AddLayerButton


func setup(p_channel_name: StringName) -> void:
	channel_name = p_channel_name
	if is_inside_tree():
		_refresh()


func _ready() -> void:
	add_layer_button.pressed.connect(on_add_layer)
	SignalBus.project_loaded.connect(_refresh)
	# Layers created/removed/reordered by scripts show up automatically.
	SignalBus.layer_structure_changed.connect(_sync)
	if channel_name != StringName():
		_refresh()


## полная перестройка.
func _refresh() -> void:
	channel_label.text = String(channel_name)
	for controller in layer_controllers.duplicate():
		_drop(controller)
	_sync()


## Постепенная синхронизация со структурой данных.
func _sync() -> void:
	if channel_name == StringName() or not is_inside_tree():
		return

	var wanted := EditorMaterial.get_layer_order(channel_name)

	for controller in layer_controllers.duplicate():
		if not wanted.has(controller.layer_id):
			_drop(controller)

	var index := 0
	for layer_id in wanted:
		var controller := get_controller(layer_id)
		if controller == null:
			controller = _spawn(layer_id)
		layers_container.move_child(controller, index)
		index += 1


func get_controller(layer_id: StringName) -> LayerUIController:
	for controller in layer_controllers:
		if controller.layer_id == layer_id:
			return controller
	return null


func _spawn(layer_id: StringName) -> LayerUIController:
	var controller := LAYER_SCENE.instantiate() as LayerUIController
	layers_container.add_child(controller)
	controller.setup(channel_name, layer_id, self)
	controller.gui_input.connect(_on_layer_gui_input.bind(controller))
	layer_controllers.append(controller)
	return controller


func _drop(controller: LayerUIController) -> void:
	layer_controllers.erase(controller)
	if current_layer == controller:
		current_layer = null
	layers_container.remove_child(controller) 
	controller.queue_free()


# ---------------------- Actions (UI only calls the data layer) ----------------------

func on_add_layer() -> void:
	EditorMaterial.create_layer(channel_name)


func add_layer(gen: String) -> void:
	var layer_data := EditorMaterial.create_layer(channel_name)
	var controller := get_controller(layer_data[&"id"])
	if controller:
		controller.assign_generator(gen)


func _remove_layer(layer_controller: LayerUIController) -> void:
	EditorMaterial.remove_layer(channel_name, layer_controller.layer_id)


func remove_all_layers() -> void:
	EditorMaterial.clear_channel(channel_name)


func _on_layer_gui_input(event: InputEvent, controller: LayerUIController) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.select(controller)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_delete") and current_layer:
		_remove_layer(current_layer)
