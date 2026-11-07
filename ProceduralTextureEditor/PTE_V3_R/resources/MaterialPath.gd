class_name MaterialPath
extends RefCounted

## Адрес значения внутри EditorMaterial.editorMaterialData.
## e.g. MaterialPath.new([&"generators", id]).child(&"parameters").child(&"scale")

var path: Array[StringName]


func _init(p: Array[StringName] = []) -> void:
	path = p


func child(key: StringName) -> MaterialPath:
	var new_path: Array[StringName] = path.duplicate()
	new_path.append(key)
	return MaterialPath.new(new_path)


func get_value() -> Variant:
	return EditorMaterial.get_value(path)


## возвращает `default` если пути не существует.
func get_value_or(default: Variant) -> Variant:
	var value = EditorMaterial.get_value(path)
	return default if value == null else value


func has_value() -> bool:
	return EditorMaterial.get_value(path) != null


## возвращает false если родителя пути нет.
func set_value(value: Variant) -> bool:
	return EditorMaterial.set_value(path, value)
