extends SubViewport


@export var generator_data: GeneratorData

@onready var preview_rect: ColorRect = $ColorRect

var _material: ShaderMaterial

func _ready() -> void:
	_material = ShaderMaterial.new()
	preview_rect.material = _material
	bake_shader(Vector2i(1024,1024),"res://baker/","test.png")

func bake_shader(size: Vector2i, save_path: String, filename: String) -> void:
	_material.shader = generator_data.preview_shader
	
	for param_def in generator_data.parameters:
		_material.set_shader_parameter(param_def.param_name, param_def.default_value)

	self.size = size
	await RenderingServer.frame_post_draw
	var rendered_texture: Texture2D = self.get_texture()
	var image: Image = rendered_texture.get_image()
	
	var error = image.save_png(save_path+filename)
	if error != OK:
		push_error("Failed to save baked texture to: " + save_path)
