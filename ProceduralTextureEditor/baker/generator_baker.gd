extends Control

## Кеш для обработки параметров.
var material_data: Dictionary
@export var generator_data: GeneratorData
var _material: ShaderMaterial
@onready var _add_to_node: VBoxContainer = $ScrollContainer/VBoxContainer
var l: Label

var step: int = 0


func _ready() -> void:
	bake_shader(Vector2i(512,512),"res://baker/","test.png")

func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % 30 == 0:
		step += 1
		evalute()


func bake_shader(size: Vector2i, save_path: String, filename: String) -> void:
	_material = ShaderMaterial.new()
	_material.shader = generator_data.preview_shader

	var im: TextureRect = TextureRect.new()
	im.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	im.size_flags_vertical = Control.SIZE_EXPAND_FILL
	im.texture = CanvasTexture.new()
	im.material = _material
	im.custom_minimum_size = Vector2(512, 512)
	l = Label.new()
	l.text = "Параметры: " + str(generator_data.parameters)
	var split_cont := SplitContainer.new()
	split_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(l)
	vb.add_child(im)
	#split_cont.add_child(vb)
	_add_to_node.add_child(vb)

var final_counter: int
func evalute()->void:
	if final_counter >= generator_data.parameters.size():
		set_physics_process(false)
	if step == 1:
		for i in generator_data.parameters:
			i.default_value = i.min_value
	else:
		for i in generator_data.parameters:
			if i.default_value < i.max_value:
				# Вариант 1 i.default_value += i.step - резервный
				# Вариант 2
				i.default_value += max((i.max_value-i.min_value)/10, i.step)
			else:
				final_counter+=1
				i.default_value = i.min_value
	l.text = "Параметры: " + str(generator_data.parameters)

	for param_def in generator_data.parameters:
		_material.set_shader_parameter(param_def.param_name, param_def.default_value)

	await RenderingServer.frame_post_draw
