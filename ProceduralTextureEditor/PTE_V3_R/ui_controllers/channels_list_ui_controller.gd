class_name ChannelListUIController
extends HBoxContainer


var channels: Array[ChannelUIController] = []



func _ready() -> void:
	add_channel("Albedo")
	add_channel("Normal")


# ---------------------- Добавление нового генератора ----------------------
func add_channel(channel_name: StringName) -> void:

	#var generator_entry = {
	#	&"имя генератора": generator_type_name,
	#	&"параметры": default_params
	#}
	#EditorMaterial.editorMaterialData["generators"][id] = generator_entry
	
	var controller_scene = preload("res://PTE_V3_R/UI/channel_ui.tscn")
	var controller = controller_scene.instantiate()
	#var path: Array[StringName] = [&"generators", StringName(id)]
	self.add_child(controller)
	channels.append(controller)
	#controller.setup(generator_type_name, path)
	
