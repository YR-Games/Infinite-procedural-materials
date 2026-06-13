class_name ParameterControl
extends Control

signal value_changed(new_value)

var binding: MaterialPath


func bind(path: MaterialPath) -> void:
	binding = path
	_update_from_data()


func get_data_value():
	if binding == null:
		return null

	return binding.get_value()


func set_data_value(value):
	if binding == null:
		return

	binding.set_value(value)


func _update_from_data():
	pass


func _on_ui_changed(new_value):
	set_data_value(new_value)
	value_changed.emit(new_value)
