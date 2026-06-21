class_name floatParameterDef
extends abstractParameterDef

@export var default_value: float = 1.0

@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var step: float = 0.01


func get_default_value() -> Variant:
	return default_value

func generate_glsl_declaration(value, var_name):
	return ""

func value_to_glsl(value, var_name = ""):
	var v := float(value)

	if is_nan(v):
		v = 0.0
	elif is_inf(v):
		v = sign(v) * 1e10

	return "%.6f" % v

enum EditorType {
	SLIDER,
	SPINBOX
}

@export var editor_type: EditorType
