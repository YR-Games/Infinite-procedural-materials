class_name ModifierData extends Resource

@export var dependencies: Dictionary
## GLSL function snippet to be inserted during code assembly
@export_multiline var function: String = ""

@export var parameters: Dictionary[String,abstract_parameter_def]
