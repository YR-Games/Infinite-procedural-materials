class_name LayerUIController
extends PanelContainer
var layer_index: int
var layer_data_path: Array[StringName]

@onready var name_edit: LineEdit = $VBoxContainer/Header/LayerName
@onready var generator_selector: OptionButton = $VBoxContainer/GeneratorOption
@onready var blend_mode_selector: OptionButton = $VBoxContainer/BlendModeOption
@onready var modifiers_container: VBoxContainer = $VBoxContainer/ModifiersContainer
@onready var add_modifier_button: Button = $VBoxContainer/Button


func _ready() -> void:
	add_modifier_button.pressed.connect(_on_add_modifier)

func _on_add_modifier():
	#должно быть со своим popup меню как у генераторов
	var modifier_scene = preload("res://PTE_V3_R/UI/base_modifier_ui.tscn")
	var modifier_control = modifier_scene.instantiate()
	modifiers_container.add_child(modifier_control)
