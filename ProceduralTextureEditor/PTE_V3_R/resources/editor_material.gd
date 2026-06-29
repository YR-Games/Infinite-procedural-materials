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
		},
		
		&"roughness": {
			&"layers": {},
			&"layer_order": []
		},

		&"metallic": {
			&"layers": {},
			&"layer_order": []
		}
	}
}

static func save_project(path:String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return false

	var material_project: String = get_material_json_string()
	GConnector.add_material(material_project)

	file.store_string(material_project)
	file.close()

	return true

static func get_material_json_string()->String:
	var json_data = JSON.from_native(editorMaterialData)
	return JSON.stringify(json_data, "\t")

static func clear_project() -> void:
	editorMaterialData = {
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
	SignalBus.project_loaded.emit()
	SignalBus.material_value_changed.emit()

static func load_project(path:String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return load_project_from_dict(
		parce_json_string_to_dict(file.get_as_text())
	)

static func load_project_from_dict(project: Dictionary)->bool:
	clear_project()

	if project:
		editorMaterialData = project

		SignalBus.project_loaded.emit()
		SignalBus.material_value_changed.emit()

		return true

	return false


static func parce_json_string_to_dict(text: String)->Dictionary:
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Invalid project file")
		return {}

	return JSON.to_native(json.data)


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

static func get_generator(id:StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return material_data["generators"].get(id,{})

static func get_generators(material_data: Dictionary = editorMaterialData) -> Dictionary:
	return material_data["generators"]

static func get_generator_ids() -> Array[StringName]:

	var result:Array[StringName] = []

	for id in editorMaterialData["generators"]:
		result.append(id)

	return result



	
	
	# ---------------------- Слои ----------------------

static func get_channel(channel:StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return material_data[&"channels"].get(channel, {})

static func get_channel_layers(channel:StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	var channel_data := get_channel(channel, material_data)

	if channel_data.is_empty():
		return {}

	return channel_data[&"layers"]

static func get_channel_layer_order(channel:StringName, material_data: Dictionary = editorMaterialData) -> Array:
	var channel_data := get_channel(channel, material_data)

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
		&"opacity": 1.0,
		&"modifiers": {},
		&"modifier_order": []
	}
	
	channel_data[&"layers"][layer_id] = layer
	channel_data[&"layer_order"].append(layer_id)
	SignalBus.layer_structure_changed.emit()
	
	return layer


static func get_layer(channel:StringName, layer_id:StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return get_channel_layers(channel, material_data).get(layer_id, {})


static func get_layers(channel:StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return get_channel_layers(channel, material_data)


static func remove_layer(channel:StringName, layer_id:StringName) -> void:

	var layers := get_channel_layers(channel)
	var order := get_channel_layer_order(channel)

	layers.erase(layer_id)
	order.erase(layer_id)

	SignalBus.layer_structure_changed.emit()


static func get_layer_order(channel:StringName) -> Array:
	return get_channel_layer_order(channel)


static func get_layers_in_order(channel:StringName, material_data: Dictionary = editorMaterialData) -> Array[Dictionary]:

	var result:Array[Dictionary] = []

	var layers := get_channel_layers(channel, material_data)

	for layer_id in get_channel_layer_order(channel, material_data):
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


static func get_modifier(
	channel:StringName,
	layer_id:StringName,
	modifier_id:StringName,
	material_data: Dictionary = editorMaterialData
) -> Dictionary:

	var layer := get_layer(channel, layer_id, material_data)

	if layer.is_empty():
		return {}

	return layer[&"modifiers"].get(modifier_id,{})
	
static func get_modifiers(channel:StringName,layer_id:StringName) -> Dictionary:

	var layer := get_layer(channel, layer_id)

	if layer.is_empty():
		return {}

	return layer[&"modifiers"]

static func get_modifier_order(channel:StringName,layer_id:StringName, material_data: Dictionary = editorMaterialData) -> Array:
	var layer := get_layer(channel, layer_id, material_data)
	if layer.is_empty():
		return []

	return layer[&"modifier_order"]
	
static func get_modifiers_in_order(
	channel:StringName,
	layer_id:StringName,
	material_data: Dictionary = editorMaterialData
) -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	var layer := get_layer(channel, layer_id, material_data)
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


static func get_modifers_count(material_data: Dictionary)->int:
	var count: int = 0
	for i: StringName in material_data.get(&"channels"):
		for j: StringName in material_data.get(&"channels").get(i).get(&"layers"):
			count += material_data.get(&"channels").get(i).get(&"layers").get(j).get(&"modifiers").size()
	return count


static func get_generators_params_count(material_data: Dictionary)->int:
	var count: int = 0
	for g: StringName in get_generators(material_data):
		count += material_data[&"generators"][g].get(&"parameters").size()
	return count


static func get_modifers_params_count(material_data: Dictionary)->int:
	var count: int = 0
	for i: StringName in material_data.get(&"channels"):
		for j: StringName in material_data.get(&"channels").get(i).get(&"layers"):
			var d: Dictionary = material_data.get(&"channels").get(i).get(&"layers").get(j).get(&"modifiers")
			if d.get(&"modifier_name") != &"ColorRamp":
				count += d.get(&"parameters", {}).size()
	return count
