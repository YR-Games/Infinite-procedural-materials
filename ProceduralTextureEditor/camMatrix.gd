extends Sprite2D

var shader_material: ShaderMaterial

func _ready():
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://Shaders/ray/ray_test.gdshader")
	self.material = shader_material

func _process(delta):
	var camera_matrix = get_viewport().get_camera_3d().get_camera_transform().affine_inverse()
	shader_material.set_shader_parameter("cam", camera_matrix)
