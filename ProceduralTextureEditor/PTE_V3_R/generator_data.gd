class_name GeneratorData extends Resource

## Unique identifier (e.g. "voronoi", "gradient_noise")
@export var generator_id: String = ""
## Display name
@export var generator_name: String = "Generator"
## Compiled shader for live preview (creates a ShaderMaterial)
@export var preview_shader: Shader
## GLSL function snippet to be inserted during code assembly
@export_multiline var function_snippet: String = ""
## Parameters the user can edit – see ParameterDef below
@export var parameters: Array[abstract_parameter_def] = []
