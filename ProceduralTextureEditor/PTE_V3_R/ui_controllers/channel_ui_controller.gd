class_name ChannelUIController
extends PanelContainer

var channel_name: StringName

@onready var channel_label: Label = $VBoxContainer/ChannelNameLabel
@onready var layers_container: VBoxContainer = $VBoxContainer/ChannelsScrollContainer/LayersContainer
@onready var add_layer_button: Button = $VBoxContainer/AddLayerButton


func setup(p_channel_name: StringName) -> void:
	channel_name = p_channel_name

	if is_inside_tree():
		_refresh()


func _ready() -> void:
	add_layer_button.pressed.connect(_on_add_layer)

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
	controller.setup(channel_name,layer_data[&"id"])


func _generate_layer_id() -> String:
	return "layer_%d_%d" % [Time.get_ticks_usec(),randi()]
