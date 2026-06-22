class_name EditorMaterial
extends RefCounted



static var editorMaterialData := {
	&"generators": {},

	&"channels": {
		&"albedo": {
			&"layers": {},
			&"layer_order": []
		},

		&"normal": {
			&"layers": {},
			&"layer_order": []
		}
	}
}


static func get_value(path:Array[StringName]) -> Variant:
	var current = editorMaterialData

	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null

	return current

static func set_value(path:Array[StringName], value:Variant) -> void:
	var current = editorMaterialData

	for i in range(path.size() - 1):
		current = current[path[i]]

	current[path[-1]] = value
	SignalBus.material_value_changed.emit()

static func add_generator(id:StringName,generator_name:StringName,parameters:Dictionary):
	editorMaterialData["generators"][id] = {
		&"generator_name": generator_name,
		&"parameters": parameters
	}
	SignalBus.material_value_changed.emit()

static func remove_generator(id:StringName):
	editorMaterialData["generators"].erase(id)
	SignalBus.material_value_changed.emit()

static func get_generator(id:StringName) -> Dictionary:
	return editorMaterialData["generators"].get(id,{})

static func get_generators() -> Dictionary:
	return editorMaterialData["generators"]

static func get_generator_ids() -> Array[StringName]:

	var result:Array[StringName] = []

	for id in editorMaterialData["generators"]:
		result.append(id)

	return result



	
	
	# ---------------------- Слои ----------------------

static func get_channel(channel:StringName) -> Dictionary:
	return editorMaterialData[&"channels"].get(channel, {})

static func get_channel_layers(channel:StringName) -> Dictionary:
	var channel_data := get_channel(channel)

	if channel_data.is_empty():
		return {}

	return channel_data[&"layers"]

static func get_channel_layer_order(channel:StringName) -> Array:
	var channel_data := get_channel(channel)

	if channel_data.is_empty():
		return []

	return channel_data[&"layer_order"]

static func add_layer(channel:StringName,layer_id:StringName) -> Dictionary:
	var channel_data := get_channel(channel)
	if channel_data.is_empty():
		return {}
	var layer := {
		&"id": layer_id,
		&"name": "Layer",
		&"generator_id": StringName(),
		&"blend_mode": &"normal",
		&"modifiers": {},
		&"modifier_order": []
	}
	
	channel_data[&"layers"][layer_id] = layer
	channel_data[&"layer_order"].append(layer_id)
	SignalBus.material_value_changed.emit()
	
	return layer


static func get_layer(channel:StringName, layer_id:StringName) -> Dictionary:
	return get_channel_layers(channel).get(layer_id, {})


static func get_layers(channel:StringName) -> Dictionary:
	return get_channel_layers(channel)


static func remove_layer(channel:StringName, layer_id:StringName) -> void:

	var layers := get_channel_layers(channel)
	var order := get_channel_layer_order(channel)

	layers.erase(layer_id)
	order.erase(layer_id)

	SignalBus.material_value_changed.emit()


static func get_layer_order(channel:StringName) -> Array:
	return get_channel_layer_order(channel)


static func get_layers_in_order(channel:StringName) -> Array[Dictionary]:

	var result:Array[Dictionary] = []

	var layers := get_channel_layers(channel)

	for layer_id in get_channel_layer_order(channel):
		var layer:Dictionary = layers.get(layer_id, {})

		if not layer.is_empty():
			result.append(layer)

	return result


static func move_layer(channel:StringName,from_index:int,to_index:int) -> void:
	var order := get_channel_layer_order(channel)

	if from_index < 0 or from_index >= order.size():
		return

	if to_index < 0 or to_index >= order.size():
		return

	var layer_id = order[from_index]

	order.remove_at(from_index)
	order.insert(to_index, layer_id)

	SignalBus.material_value_changed.emit()

# ---------------------- Модификаторы ----------------------

static func add_modifier(channel:StringName,layer_id:StringName,modifier_name:StringName,parameters:Dictionary) -> Dictionary:

	var layer := get_layer(channel, layer_id)

	if layer.is_empty():
		return {}

	var modifier_id := StringName("mod_%d_%d" % [Time.get_ticks_usec(),randi()])

	var modifier := {
		&"id": modifier_id,
		&"modifier_name": modifier_name,
		&"parameters": parameters
	}

	layer[&"modifiers"][modifier_id] = modifier
	layer[&"modifier_order"].append(modifier_id)

	SignalBus.material_value_changed.emit()

	return modifier


static func remove_modifier(channel:StringName,layer_id:StringName,modifier_id:StringName) -> void:

	var layer := get_layer(channel, layer_id)

	if layer.is_empty():
		return

	layer[&"modifiers"].erase(modifier_id)
	layer[&"modifier_order"].erase(modifier_id)


static func get_modifier(channel:StringName,layer_id:StringName,modifier_id:StringName) -> Dictionary:

	var layer := get_layer(channel, layer_id)

	if layer.is_empty():
		return {}

	return layer[&"modifiers"].get(modifier_id,{})
	
static func get_modifiers(channel:StringName,layer_id:StringName) -> Dictionary:

	var layer := get_layer(channel, layer_id)

	if layer.is_empty():
		return {}

	return layer[&"modifiers"]

static func get_modifier_order(channel:StringName,layer_id:StringName) -> Array:
	var layer := get_layer(channel, layer_id)
	if layer.is_empty():
		return []

	return layer[&"modifier_order"]
	
static func get_modifiers_in_order(channel:StringName,layer_id:StringName) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	var layer := get_layer(channel, layer_id)
	if layer.is_empty():
		return result

	for modifier_id in layer[&"modifier_order"]:
		var modifier:Dictionary = layer[&"modifiers"].get(modifier_id,{})

		if not modifier.is_empty():
			result.append(modifier)

	return result

static func move_modifier(channel:StringName,layer_id:StringName,from_index:int,to_index:int) -> void:
	var layer := get_layer(channel, layer_id)
	if layer.is_empty():
		return

	var order:Array = layer[&"modifier_order"]

	if from_index < 0 or from_index >= order.size():
		return

	if to_index < 0 or to_index >= order.size():
		return

	var modifier_id = order[from_index]

	order.remove_at(from_index)
	order.insert(to_index, modifier_id)

	SignalBus.material_value_changed.emit()
