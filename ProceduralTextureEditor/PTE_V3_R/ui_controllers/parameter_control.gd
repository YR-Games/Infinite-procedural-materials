class_name ParameterControl
extends Control

signal value_changed(new_value)

# Ссылка на данные в глобальном словаре (путь к значению)
var data_path: Array[StringName] = []

func set_data_path(path: Array[StringName]) -> void:
	data_path = path
	_update_from_data()

# Загрузить текущее значение из глобального синглтона по пути
func _get_data_value():
	var current = EditorMaterial.editorMaterialData 
	for key in data_path:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return null
	return current

# Установить значение в синглтоне
func _set_data_value(new_value):
	var current = EditorMaterial.editorMaterialData
	for i in range(data_path.size() - 1):
		current = current[data_path[i]]
	current[data_path[-1]] = new_value

# Должен быть переопределён в наследниках
func _update_from_data():
	pass

func _on_ui_changed(new_value):
	_set_data_value(new_value)
	value_changed.emit(new_value)
