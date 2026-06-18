class_name abstract_parameter_def
extends Resource

func value_to_glsl(value: Variant) -> String:
	return str(value)   # base – override in subclasses
