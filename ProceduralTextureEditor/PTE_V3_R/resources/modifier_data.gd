class_name ModifierData extends Resource

@export var function_name: String = ""
@export var input_type: String = "float"
@export var return_type: String = "vec4"
@export var required_functions: PackedStringArray = []
@export_multiline var function: String = ""
@export var parameters: Dictionary[String, abstract_parameter_def]
