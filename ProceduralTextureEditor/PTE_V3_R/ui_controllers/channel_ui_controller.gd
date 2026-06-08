class_name ChannelUIController
extends VBoxContainer

var channel_name: StringName
var layers_container: VBoxContainer

func setup(channel_name: StringName) -> void:
	self.channel_name = channel_name
	var channel_path = [channel_name]
	
	# Контейнер для списка слоёв
	layers_container = VBoxContainer.new()
	add_child(layers_container)
	
	var add_layer_btn = Button.new()
	add_layer_btn.text = "Добавить слой"
	add_layer_btn.pressed.connect(_on_add_layer.bind(channel_path))
	add_child(add_layer_btn)
	
	_refresh_layers(channel_path)

func _refresh_layers(channel_path: Array[StringName]):
	# Очистить старые контроллеры слоёв
	for child in layers_container.get_children():
		child.queue_free()
	
	var layers = EditorMaterial.editorMaterialData .get(channel_path[0], {}).get("layers", [])
	for i in range(layers.size()):
		var layer_control = LayerUIController.new()
		layer_control.setup(channel_path, i)
		layers_container.add_child(layer_control)

func _on_add_layer(channel_path: Array[StringName]):
	var new_layer = {
		"имя": "Новый слой",
		"генератор": {"имя генератора": "default", "параметры": {}},
		"режим смешивания": 0,
		"модификаторы": []
	}
	var channel =EditorMaterial.editorMaterialData.get(channel_path[0], {})
	if not channel.has("layers"):
		channel["layers"] = []
	channel["layers"].append(new_layer)
	_refresh_layers(channel_path)
