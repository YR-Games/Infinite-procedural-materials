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

static func add_generator(id:StringName,generator_name:StringName,parameters:Dictionary):
	editorMaterialData["generators"][id] = {
		&"generator_name": generator_name,
		&"parameters": parameters
	}

static func remove_generator(id:StringName):
	editorMaterialData["generators"].erase(id)


static func set_value(path:Array[StringName], value:Variant) -> void:
	var current = editorMaterialData

	for i in range(path.size() - 1):
		current = current[path[i]]

	current[path[-1]] = value
	SignalBus.material_value_changed.emit(path, value)
	
	
	# ---------------------- Слои ----------------------

static func add_layer(channel:StringName,layer_id:StringName) -> Dictionary:
	print("channel =", channel)
	print(editorMaterialData[&"channels"].keys())
	var layer := {
		&"id": layer_id,
		&"name": "Layer",
		&"generator_id": StringName(),
		&"blend_mode": &"normal",
		&"modifiers": {},
		&"modifier_order": []
	}
	
	editorMaterialData[&"channels"][channel][&"layers"][layer_id] = layer
	editorMaterialData[&"channels"][channel][&"layer_order"].append(layer_id)

	return layer


static func get_generator(id:StringName) -> Dictionary:
	return editorMaterialData["generators"].get(id,{})

static func get_generators() -> Dictionary:
	return editorMaterialData["generators"]

static func get_generator_ids() -> Array[StringName]:

	var result:Array[StringName] = []

	for id in editorMaterialData["generators"]:
		result.append(id)

	return result

static func remove_layer(channel:StringName,layer_id:StringName) -> void:

	var channel_data:Dictionary = editorMaterialData["channels"][channel]

	channel_data["layers"].erase(layer_id)
	channel_data["layer_order"].erase(layer_id)


static func get_layer(channel:StringName,layer_id:StringName) -> Dictionary:

	return editorMaterialData["channels"][channel]["layers"].get(layer_id,{})


static func get_layers(channel:StringName) -> Dictionary:
	return editorMaterialData["channels"][channel]["layers"]


static func get_layer_order(channel:StringName) -> Array:
	return editorMaterialData["channels"][channel]["layer_order"]


static func get_layers_in_order(channel:StringName) -> Array[Dictionary]:

	var result:Array[Dictionary] = []

	var channel_data:Dictionary = editorMaterialData["channels"][channel]

	for layer_id in channel_data["layer_order"]:
		var layer:Dictionary = channel_data["layers"].get(layer_id)

		if not layer.is_empty():
			result.append(layer)

	return result


static func move_layer(channel:StringName,from_index:int,to_index:int) -> void:

	var order:Array = editorMaterialData["channels"][channel]["layer_order"]

	if from_index < 0 or from_index >= order.size():
		return

	if to_index < 0 or to_index >= order.size():
		return

	var layer_id = order[from_index]

	order.remove_at(from_index)
	order.insert(to_index, layer_id)


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
