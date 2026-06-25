class_name ChannelUIController
extends PanelContainer

var channel_name: StringName

var layer_controllers : Array[LayerUIController] = []
var current_layer : LayerUIController = null

@onready var channel_label: Label = $VBoxContainer/ChannelNameLabel
@onready var layers_container: VBoxContainer = $VBoxContainer/ChannelsScrollContainer/LayersContainer
@onready var add_layer_button: Button = $VBoxContainer/AddLayerButton


func setup(p_channel_name: StringName) -> void:
	channel_name = p_channel_name

	if is_inside_tree():
		_refresh()


func _ready() -> void:
	add_layer_button.pressed.connect(_on_add_layer)
	SignalBus.project_loaded.connect(_refresh)
	if channel_name != StringName():
		_refresh()


func _refresh() -> void:

	channel_label.text = String(channel_name)

	for child in layers_container.get_children():
		child.queue_free()

	for layer_data in EditorMaterial.get_layers_in_order(channel_name):
		_create_layer_ui(layer_data)


func _on_add_layer() -> void:
	print("channel_name =", channel_name)
	var layer_id := StringName(_generate_layer_id())
	var layer_data := EditorMaterial.add_layer(channel_name,layer_id)
	_create_layer_ui(layer_data)


func _create_layer_ui(layer_data: Dictionary) -> void:
	var controller_scene = preload("res://PTE_V3_R/UI/layer_ui.tscn")
	var controller := controller_scene.instantiate() as LayerUIController
	layers_container.add_child(controller)
	controller.setup(channel_name,layer_data[&"id"],self)

	controller.gui_input.connect(_on_layer_gui_input.bind(controller))

	layer_controllers.append(controller)

func _on_layer_gui_input(event: InputEvent,controller: LayerUIController) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.select(controller)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_delete") and current_layer:
		_remove_layer(current_layer)

func _remove_layer(layer_controller: LayerUIController) -> void:

	EditorMaterial.remove_layer(channel_name,layer_controller.layer_id)

	layer_controllers.erase(layer_controller)

	if current_layer == layer_controller:
		current_layer = null

	layer_controller.queue_free()


func _generate_layer_id() -> String:
	return "layer_%d_%d" % [Time.get_ticks_usec(),randi()]
