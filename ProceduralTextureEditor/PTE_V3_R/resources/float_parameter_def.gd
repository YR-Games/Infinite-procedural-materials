class_name float_parameter_def
extends abstract_parameter_def

@export var default_value: float = 1.0

@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var step: float = 0.01

func value_to_glsl(value: Variant) -> String:
	var f = float(value)
	# Ensure decimal point to avoid integer type inference in GLSL
	if f == floor(f) and not is_inf(f) and not is_nan(f):
		return "%.1f" % f
	return str(f)
