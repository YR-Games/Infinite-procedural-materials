class_name ChannelListUIController
extends HBoxContainer


var channels: Array[ChannelUIController] = []



func _ready() -> void:
	add_channel(&"albedo")
	add_channel(&"normal")
	add_channel(&"roughness")
	add_channel(&"metallic")

func add_channel(channel_name: StringName) -> void:

	var controller_scene = preload("res://PTE_V3_R/UI/channel_ui.tscn")

	var controller := controller_scene.instantiate() as ChannelUIController
	add_child(controller)
	controller.setup(channel_name)
	channels.append(controller)
