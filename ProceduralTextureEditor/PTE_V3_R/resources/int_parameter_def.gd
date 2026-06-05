class_name int_parameter_def
extends abstract_parameter_def

@export var default_value: int = 1

@export var min_value: int = 0
@export var max_value: int = 1
@export var step: int = 1

#func _to_string() -> String:
#	return "{"+param_name +" val="+ str(default_value) + ", ("+ str(min_value) + ", " +str(max_value)+"), "+str(step)+"}"
