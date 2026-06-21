class_name intParameterDef
extends abstractParameterDef

@export var default_value: int = 1

@export var min_value: int = 0
@export var max_value: int = 1
@export var step: int = 1

func get_default_value() -> Variant:
	return default_value

func generate_glsl_declaration(value, var_name):
	return ""

func value_to_glsl(value: Variant, var_name = "") -> String:
	return str(int(value))

enum EditorType {
	SLIDER,
	SPINBOX
}

@export var editor_type: EditorType
