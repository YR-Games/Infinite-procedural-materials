class_name MaterialPath
extends RefCounted

var path:Array[StringName]

func _init(p:Array[StringName]):
	path = p

func child(key:StringName) -> MaterialPath:
	var new_path:Array[StringName] = path.duplicate()
	new_path.append(key)
	return MaterialPath.new(new_path)

func get_value() -> Variant:
	return EditorMaterial.get_value(path)

func set_value(value:Variant) -> void:
	EditorMaterial.set_value(path, value)
