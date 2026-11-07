class_name EditorMaterial
extends RefCounted


const DEFAULT_CHANNELS: Array[StringName] = [&"albedo"]

const EMPTY_PROJECT := {
	&"generators": {},
	&"channels": {
		&"albedo": {&"layers": {}, &"layer_order": []},
	},
}

static var editorMaterialData: Dictionary = EMPTY_PROJECT.duplicate(true)

static var _batch_depth := 0
static var _dirty_layers := false
static var _dirty_generators := false


# ====================== Signals / batching ======================

static func begin_batch() -> void:
	_batch_depth += 1


static func end_batch() -> void:
	_batch_depth = maxi(0, _batch_depth - 1)
	if _batch_depth == 0:
		_flush()


static func batch(edit: Callable) -> void:
	begin_batch()
	edit.call()
	end_batch()


static func _notify(layers := false, generators := false) -> void:
	_dirty_layers = _dirty_layers or layers
	_dirty_generators = _dirty_generators or generators
	if _batch_depth == 0:
		_flush()


static func _flush() -> void:
	var layers := _dirty_layers
	var generators := _dirty_generators
	_dirty_layers = false
	_dirty_generators = false
	if generators:
		SignalBus.generator_structure_changed.emit()
	if layers:
		SignalBus.layer_structure_changed.emit()
	SignalBus.material_value_changed.emit()


# ====================== IDs and schema helpers ======================

static func make_id(prefix: String, existing: Dictionary = {}) -> StringName:
	var id := StringName()
	while id.is_empty() or existing.has(id):
		id = StringName("%s_%d_%d" % [prefix, int(Time.get_unix_time_from_system()), randi()])
	return id


static func _new_channel() -> Dictionary:
	return {&"layers": {}, &"layer_order": []}


static func _copy_default(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


static func generator_defaults(generator_name: StringName) -> Dictionary:
	var result := {}
	var data := GeneratorLibrary.get_generator_data(generator_name)
	if data == null:
		return result
	for param_name in data.parameters:
		result[param_name] = _copy_default(data.parameters[param_name].default_value)
	return result


static func modifier_defaults(modifier_name: StringName) -> Dictionary:
	var result := {}
	var data := ModifierLibrary.get_modifier_data(modifier_name)
	if data == null:
		return result
	for param_name in data.parameters:
		result[param_name] = _copy_default(data.parameters[param_name].default_value)
	return result


static func make_generator_dict(generator_name: StringName, parameters: Dictionary = {}) -> Dictionary:
	var params := generator_defaults(generator_name)
	params.merge(parameters.duplicate(true), true)
	return {&"generator_name": generator_name, &"parameters": params}


static func make_layer_dict(layer_id: StringName, generator_id: StringName = StringName(), props: Dictionary = {}) -> Dictionary:
	var layer := {
		&"id": layer_id,
		&"name": "Layer",
		&"generator_id": generator_id,
		&"blend_mode": &"addBlend",
		&"opacity": 1.0,
		&"modifiers": {},
		&"modifier_order": [],
	}
	for key in props:
		layer[StringName(key)] = props[key]
	return layer


static func make_modifier_dict(modifier_id: StringName, modifier_name: StringName, parameters: Dictionary = {}) -> Dictionary:
	var params := modifier_defaults(modifier_name)
	params.merge(parameters.duplicate(true), true)
	return {&"id": modifier_id, &"modifier_name": modifier_name, &"parameters": params}


# ====================== Project I/O ======================

static func save_project(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	var material_project: String = get_material_json_string()
	GConnector.add_material(material_project)

	file.store_string(material_project)
	file.close()
	return true


static func get_material_json_string(material_data: Dictionary = editorMaterialData) -> String:
	return JSON.stringify(JSON.from_native(material_data), "\t")


static func clear_project() -> void:
	editorMaterialData = EMPTY_PROJECT.duplicate(true)
	SignalBus.project_loaded.emit()
	SignalBus.material_value_changed.emit()


static func load_project(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return load_project_from_dict(parse_json_string_to_dict(file.get_as_text()))


static func load_project_from_dict(project: Dictionary) -> bool:
	if project.is_empty():
		return false

	editorMaterialData = _normalized(project)
	SignalBus.project_loaded.emit()
	SignalBus.material_value_changed.emit()
	return true


static func _normalized(project: Dictionary) -> Dictionary:
	if not project.has(&"generators"):
		project[&"generators"] = {}
	if not project.has(&"channels"):
		project[&"channels"] = {}
	for channel in DEFAULT_CHANNELS:
		if not project[&"channels"].has(channel):
			project[&"channels"][channel] = _new_channel()
	return project


static func merge_project_from_dict(project: Dictionary) -> bool:
	var incoming_generators: Dictionary = project.get(&"generators", {})
	var incoming_channels: Dictionary = project.get(&"channels", {})

	if incoming_generators.is_empty() and incoming_channels.is_empty():
		return false

	begin_batch()

	var generator_id_map := {}
	var generators := get_generators()

	for old_id in incoming_generators:
		var new_id: StringName = old_id
		if generators.has(new_id):
			new_id = make_id("gen", generators)
		generators[new_id] = incoming_generators[old_id].duplicate(true)
		generator_id_map[old_id] = new_id

	var channels: Dictionary = editorMaterialData[&"channels"]

	for channel in incoming_channels:
		var incoming_channel: Dictionary = incoming_channels[channel]
		if not channels.has(channel):
			channels[channel] = _new_channel()

		var layers: Dictionary = channels[channel][&"layers"]
		var order: Array = channels[channel][&"layer_order"]
		var incoming_layers: Dictionary = incoming_channel.get(&"layers", {})

		var incoming_ids: Array = incoming_channel.get(&"layer_order", []).duplicate()
		for layer_id in incoming_layers:
			if not incoming_ids.has(layer_id):
				incoming_ids.append(layer_id)

		for old_layer_id in incoming_ids:
			if not incoming_layers.has(old_layer_id):
				continue

			var layer: Dictionary = incoming_layers[old_layer_id].duplicate(true)
			var new_layer_id: StringName = old_layer_id
			if layers.has(new_layer_id):
				new_layer_id = make_id("%s_layer" % channel, layers)
			layer[&"id"] = new_layer_id

			var gen_id: StringName = layer.get(&"generator_id", StringName())
			if generator_id_map.has(gen_id):
				layer[&"generator_id"] = generator_id_map[gen_id]

			layers[new_layer_id] = layer
			order.append(new_layer_id)

	_notify(true, true)
	end_batch()
	return true


static func parse_json_string_to_dict(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Invalid project file")
		return {}
	return JSON.to_native(json.data)


## Deprecated alias (old misspelling).
static func parce_json_string_to_dict(text: String) -> Dictionary:
	return parse_json_string_to_dict(text)


# ====================== Generic path access ======================

static func get_value(path: Array[StringName]) -> Variant:
	var current = editorMaterialData
	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null
	return current


static func set_value(path: Array[StringName], value: Variant) -> bool:
	var current = editorMaterialData
	for i in range(path.size() - 1):
		if not (current is Dictionary and current.has(path[i])):
			push_error("set_value: invalid path %s" % [path])
			return false
		current = current[path[i]]

	current[path[-1]] = value
	_notify()
	return true


# ====================== Generators ======================

## Создаёт генератор с дефолтными параметрами (переопределяются с помощью `parameters`).
## Возвращает ID нового генератора
static func create_generator(generator_name: StringName, parameters: Dictionary = {}) -> StringName:
	var id := make_id("gen", get_generators())
	get_generators()[id] = make_generator_dict(generator_name, parameters)
	_notify(false, true)
	return id


## Добавляет генератор с указанным ID.
static func add_generator(id: StringName, generator_name: StringName, parameters: Dictionary) -> void:
	get_generators()[id] = {
		&"generator_name": generator_name,
		&"parameters": parameters,
	}
	_notify(false, true)


## Удаляет генератор и отсоединяет от слоёв.
static func remove_generator(id: StringName) -> void:
	get_generators().erase(id)
	for channel in editorMaterialData[&"channels"]:
		for layer in get_channel_layers(channel).values():
			if layer.get(&"generator_id", StringName()) == id:
				layer[&"generator_id"] = StringName()
	_notify(true, true)


static func set_generator_param(id: StringName, param: StringName, value: Variant) -> bool:
	var generator := get_generator(id)
	if generator.is_empty():
		return false
	generator[&"parameters"][param] = value
	_notify()
	return true


static func get_generator(id: StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return material_data[&"generators"].get(id, {})


static func get_generators(material_data: Dictionary = editorMaterialData) -> Dictionary:
	return material_data[&"generators"]


static func get_generator_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in editorMaterialData[&"generators"]:
		result.append(id)
	return result


# ====================== Channels / layers ======================

static func get_channel(channel: StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return material_data[&"channels"].get(channel, {})


static func get_channel_layers(channel: StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	var channel_data := get_channel(channel, material_data)
	return {} if channel_data.is_empty() else channel_data[&"layers"]


static func get_channel_layer_order(channel: StringName, material_data: Dictionary = editorMaterialData) -> Array:
	var channel_data := get_channel(channel, material_data)
	return [] if channel_data.is_empty() else channel_data[&"layer_order"]


## добавляет layer с указанием ID вручную.
static func add_layer(channel: StringName, layer_id: StringName, generator_id: StringName = StringName(), props: Dictionary = {}) -> Dictionary:
	var channel_data := get_channel(channel)
	if channel_data.is_empty():
		return {}

	var layer := make_layer_dict(layer_id, generator_id, props)
	channel_data[&"layers"][layer_id] = layer
	channel_data[&"layer_order"].append(layer_id)
	_notify(true)
	return layer


## Создаёт слой с id генератора. в `props` может быть указан name, blend_mode, opacity.
static func create_layer(channel: StringName, generator_id: StringName = StringName(), props: Dictionary = {}) -> Dictionary:
	var layers := get_channel_layers(channel)
	if get_channel(channel).is_empty():
		push_error("Unknown channel: %s" % channel)
		return {}
	return add_layer(channel, make_id("%s_layer" % channel, layers), generator_id, props)


## Создаёт генератор и слой использующий его. Возвращает словарь слоя (в случае ошибки пустой словарь).
static func add_layer_with_generator(
	channel: StringName,
	generator_name: StringName,
	parameters: Dictionary = {},
	props: Dictionary = {}
) -> Dictionary:
	if get_channel(channel).is_empty():
		push_error("Unknown channel: %s" % channel)
		return {}

	begin_batch()
	var generator_id := create_generator(generator_name, parameters)
	var layer := create_layer(channel, generator_id, props)
	end_batch()
	return layer


static func set_layer_property(channel: StringName, layer_id: StringName, key: StringName, value: Variant) -> bool:
	var layer := get_layer(channel, layer_id)
	if layer.is_empty():
		return false
	layer[key] = value
	_notify()
	return true


static func get_layer(channel: StringName, layer_id: StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return get_channel_layers(channel, material_data).get(layer_id, {})


static func get_layers(channel: StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	return get_channel_layers(channel, material_data)


static func remove_layer(channel: StringName, layer_id: StringName) -> void:
	get_channel_layers(channel).erase(layer_id)
	get_channel_layer_order(channel).erase(layer_id)
	_notify(true)


static func clear_channel(channel: StringName) -> void:
	var channel_data := get_channel(channel)
	if channel_data.is_empty():
		return
	channel_data[&"layers"].clear()
	channel_data[&"layer_order"].clear()
	_notify(true)


static func get_layer_order(channel: StringName, material_data: Dictionary = editorMaterialData) -> Array:
	return get_channel_layer_order(channel, material_data)


static func get_layers_in_order(channel: StringName, material_data: Dictionary = editorMaterialData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var layers := get_channel_layers(channel, material_data)
	for layer_id in get_channel_layer_order(channel, material_data):
		var layer: Dictionary = layers.get(layer_id, {})
		if not layer.is_empty():
			result.append(layer)
	return result


static func move_layer(channel: StringName, from_index: int, to_index: int) -> void:
	if _move_in_order(get_channel_layer_order(channel), from_index, to_index):
		_notify(true)


static func _move_in_order(order: Array, from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= order.size():
		return false
	if to_index < 0 or to_index >= order.size():
		return false
	var id = order[from_index]
	order.remove_at(from_index)
	order.insert(to_index, id)
	return true


# ====================== Modifiers ======================

## Добавляет модификатор с дефолтными параметрами (переопределяется с помощью `parameters`).
static func add_modifier(channel: StringName, layer_id: StringName, modifier_name: StringName, parameters: Dictionary = {}) -> Dictionary:
	var layer := get_layer(channel, layer_id)
	if layer.is_empty():
		return {}

	var modifier_id := make_id("mod", layer[&"modifiers"])
	var modifier := make_modifier_dict(modifier_id, modifier_name, parameters)

	layer[&"modifiers"][modifier_id] = modifier
	layer[&"modifier_order"].append(modifier_id)
	_notify(true)
	return modifier


static func remove_modifier(channel: StringName, layer_id: StringName, modifier_id: StringName) -> void:
	var layer := get_layer(channel, layer_id)
	if layer.is_empty():
		return
	layer[&"modifiers"].erase(modifier_id)
	layer[&"modifier_order"].erase(modifier_id)
	_notify(true)


static func set_modifier_param(channel: StringName, layer_id: StringName, modifier_id: StringName, param: StringName, value: Variant) -> bool:
	var modifier := get_modifier(channel, layer_id, modifier_id)
	if modifier.is_empty():
		return false
	modifier[&"parameters"][param] = value
	_notify()
	return true


static func get_modifier(channel: StringName, layer_id: StringName, modifier_id: StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	var layer := get_layer(channel, layer_id, material_data)
	return {} if layer.is_empty() else layer[&"modifiers"].get(modifier_id, {})


static func get_modifiers(channel: StringName, layer_id: StringName, material_data: Dictionary = editorMaterialData) -> Dictionary:
	var layer := get_layer(channel, layer_id, material_data)
	return {} if layer.is_empty() else layer[&"modifiers"]


static func get_modifier_order(channel: StringName, layer_id: StringName, material_data: Dictionary = editorMaterialData) -> Array:
	var layer := get_layer(channel, layer_id, material_data)
	return [] if layer.is_empty() else layer[&"modifier_order"]


static func get_modifiers_in_order(channel: StringName, layer_id: StringName, material_data: Dictionary = editorMaterialData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var layer := get_layer(channel, layer_id, material_data)
	if layer.is_empty():
		return result

	for modifier_id in layer[&"modifier_order"]:
		var modifier: Dictionary = layer[&"modifiers"].get(modifier_id, {})
		if not modifier.is_empty():
			result.append(modifier)
	return result


static func move_modifier(channel: StringName, layer_id: StringName, from_index: int, to_index: int) -> void:
	var layer := get_layer(channel, layer_id)
	if layer.is_empty():
		return
	if _move_in_order(layer[&"modifier_order"], from_index, to_index):
		_notify(true)


# ====================== Statistics ======================


static func _all_modifiers(material_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for channel in material_data.get(&"channels", {}):
		for layer in get_channel_layers(channel, material_data).values():
			for modifier in layer.get(&"modifiers", {}).values():
				result.append(modifier)
	return result


static func get_modifers_count(material_data: Dictionary) -> int:
	return _all_modifiers(material_data).size()


static func get_generators_params_count(material_data: Dictionary) -> int:
	var count := 0
	for generator in get_generators(material_data).values():
		count += generator.get(&"parameters", {}).size()
	return count


static func get_modifers_params_count(material_data: Dictionary) -> int:
	var count := 0
	for modifier in _all_modifiers(material_data):
		if modifier.get(&"modifier_name") != &"ColorRamp":
			count += modifier.get(&"parameters", {}).size()
	return count
