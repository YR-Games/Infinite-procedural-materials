class_name ChannelUIController
extends PanelContainer

@onready var channel_label: Label = $VBoxContainer/ChannelNameLabel
@onready var layers_container: VBoxContainer = $VBoxContainer/ChannelsScrollContainer/LayersContainer
@onready var add_layer_button: Button = $VBoxContainer/AddLayerButton

func _ready() -> void:
	add_layer_button.pressed.connect(_on_add_layer)

func _on_add_layer():
	var controller_scene = preload("res://PTE_V3_R/UI/layer_ui.tscn")
	var layer_control = controller_scene.instantiate()
	layers_container.add_child(layer_control)
