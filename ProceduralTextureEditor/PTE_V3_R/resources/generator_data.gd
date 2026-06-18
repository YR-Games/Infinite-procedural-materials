class_name GeneratorData extends Resource

@export var function_name: String = ""
@export var return_type: String = "float"
@export var preview_shader: Shader
@export var required_functions: PackedStringArray = []   # names in FunctionLibrary
@export_multiline var function: String = ""
@export var parameters: Dictionary[String, abstract_parameter_def]
