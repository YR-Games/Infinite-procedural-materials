extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ter_mesh = preload("res://experimental/plank.tres")
	var preview = MeshInstance3D.new()
	preview.mesh = ter_mesh
	self.add_child(preview)
	var shader_material := ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;

void fragment()
{
	ALBEDO = vec3(UV, 0.0);
}
"""
	shader_material.shader = shader
	preview.material_override=shader_material


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
