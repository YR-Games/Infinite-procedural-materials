class_name EditorMaterial
extends RefCounted

signal value_changed(path:Array[StringName], value:Variant)

static var editorMaterialData: Dictionary = {
	"generators": {},
	"albedo": {
		"layers": []
	},
}

static func get_value(path:Array[StringName]) -> Variant:
	var current = editorMaterialData

	for key in path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null

	return current

static func add_generator(
	id:StringName,
	generator_name:StringName,
	parameters:Dictionary
):
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
