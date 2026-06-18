class_name FunctionData extends Resource

## Must match the GLSL function name exactly.
@export var function_name: String = ""
## The complete GLSL code block (including any #defines).
@export_multiline var code: String = ""
## Names of other ShaderFunctionResources (from the same library) that this function calls.
@export var required_functions: PackedStringArray = []
