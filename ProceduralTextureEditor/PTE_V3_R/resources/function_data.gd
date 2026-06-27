class_name FunctionData extends Resource

## Имя должно совпадать с именем функции в блоке кода.
@export var function_name: String = ""
## Блок кода на GLSL.
@export_multiline var code: String = ""
## Имена зависимостей ShaderFunctionResource.
@export var required_functions: PackedStringArray = []
