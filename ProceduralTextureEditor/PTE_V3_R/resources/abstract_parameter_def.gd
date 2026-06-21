class_name abstractParameterDef
extends Resource

func get_default_value() -> Variant:
	return null

func generate_glsl_declaration(value: Variant,var_name: String) -> String:
	return ""

func value_to_glsl(value: Variant,var_name: String = "") -> String:
	return str(value)
