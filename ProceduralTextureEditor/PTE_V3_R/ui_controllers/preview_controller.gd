# shader_preview_controller.gd
class_name ShaderPreviewController
extends PanelContainer

@onready var sub_viewport: SubViewport = $SubViewport
@onready var mesh_instance: MeshInstance3D = $SubViewport/MeshInstance3D

var shader_material: ShaderMaterial
var update_timer: Timer

func _ready() -> void:
	# Create a ShaderMaterial and assign it to the mesh
	shader_material = ShaderMaterial.new()
	mesh_instance.material_override = shader_material

	# Connect to the global material change signal
	SignalBus.material_value_changed.connect(_on_material_changed)

	# Add a timer to debounce rapid updates
	update_timer = Timer.new()
	update_timer.wait_time = 0.1
	update_timer.one_shot = true
	update_timer.timeout.connect(_update_preview)
	add_child(update_timer)

	# Initial preview
	_update_preview()

func _on_material_changed(_path: Array[StringName], _value: Variant) -> void:
	# Restart the debounce timer every time something changes
	update_timer.start()

func _update_preview() -> void:
	var generator = MaterialCodeGenerator.new()
	var code = generator.generate_shader_code()

	var shader = Shader.new()
	shader.code = code

	shader_material.shader = shader
