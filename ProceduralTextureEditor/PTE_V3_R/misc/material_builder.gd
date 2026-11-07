class_name MaterialBuilder
extends RefCounted


var _data := {&"generators": {}, &"channels": {}}


## Layer handle returned by layer()/generator_layer(); every setter returns self.
class LayerRef extends RefCounted:
	var id: StringName
	var _layer: Dictionary

	func _init(p_layer: Dictionary) -> void:
		_layer = p_layer
		id = p_layer[&"id"]

	func named(layer_name: String) -> LayerRef:
		_layer[&"name"] = layer_name
		return self

	func blend(mode: StringName) -> LayerRef:
		_layer[&"blend_mode"] = mode
		return self

	func opacity(value: float) -> LayerRef:
		_layer[&"opacity"] = value
		return self

	func modifier(modifier_name: StringName, parameters: Dictionary = {}) -> LayerRef:
		var mod_id := EditorMaterial.make_id("mod", _layer[&"modifiers"])
		_layer[&"modifiers"][mod_id] = EditorMaterial.make_modifier_dict(mod_id, modifier_name, parameters)
		_layer[&"modifier_order"].append(mod_id)
		return self


## Adds a generator, returns its id.
func generator(generator_name: StringName, parameters: Dictionary = {}) -> StringName:
	var id := EditorMaterial.make_id("gen", _data[&"generators"])
	_data[&"generators"][id] = EditorMaterial.make_generator_dict(generator_name, parameters)
	return id


## Adds a layer to `channel` using an existing generator id.
func layer(channel: StringName, generator_id: StringName = StringName()) -> LayerRef:
	var channels: Dictionary = _data[&"channels"]
	if not channels.has(channel):
		channels[channel] = {&"layers": {}, &"layer_order": []}

	var layers: Dictionary = channels[channel][&"layers"]
	var layer_id := EditorMaterial.make_id("%s_layer" % channel, layers)
	var layer_dict := EditorMaterial.make_layer_dict(layer_id, generator_id)

	layers[layer_id] = layer_dict
	channels[channel][&"layer_order"].append(layer_id)
	return LayerRef.new(layer_dict)


## Adds a generator and a layer that uses it.
func generator_layer(channel: StringName, generator_name: StringName, parameters: Dictionary = {}) -> LayerRef:
	return layer(channel, generator(generator_name, parameters))


## Returns the built project data (a deep copy).
func build() -> Dictionary:
	return _data.duplicate(true)


## replace = false: merge into the open project (IDs are de-duplicated).
## replace = true:  replace the open project.
func apply(replace := false) -> bool:
	if replace:
		return EditorMaterial.load_project_from_dict(build())
	return EditorMaterial.merge_project_from_dict(build())
