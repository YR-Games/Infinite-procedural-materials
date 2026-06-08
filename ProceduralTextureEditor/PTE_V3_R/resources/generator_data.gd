class_name GeneratorData extends Resource


@export var preview_shader: Shader
## Set of function definitions
@export var dependencies: Dictionary
## GLSL function snippet to be inserted during code assembly
@export_multiline var function: String = ""

@export var parameters: Dictionary[String,abstract_parameter_def]
