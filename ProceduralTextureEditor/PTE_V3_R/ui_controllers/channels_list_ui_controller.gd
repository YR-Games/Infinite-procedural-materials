class_name ChannelListUIController
extends HBoxContainer


var channels: Array[ChannelUIController] = []



func _ready() -> void:
	add_channel(&"albedo")


func add_channel(channel_name: StringName) -> void:

	var controller_scene = preload("res://PTE_V3_R/UI/channel_ui.tscn")

	var controller := controller_scene.instantiate() as ChannelUIController
	add_child(controller)
	controller.setup(channel_name)
	channels.append(controller)

func add_layer(gen: String) -> void:
	if not channels.is_empty():
		channels[0].add_layer(gen)


func clear_all()->void:
	channels[0].remove_all_layers()
