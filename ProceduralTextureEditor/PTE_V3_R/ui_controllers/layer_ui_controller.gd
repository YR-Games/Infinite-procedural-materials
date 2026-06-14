class_name LayerUIController
extends PanelContainer

var channel_name: StringName
var layer_id: StringName
var layer_path: MaterialPath

@onready var name_edit: LineEdit = $VBoxContainer/Header/LayerName
@onready var generator_selector: Button = $VBoxContainer/SelectGeneratorButton
@onready var blend_mode_selector: OptionButton = $VBoxContainer/BlendModeOption
@onready var modifiers_container: VBoxContainer = $VBoxContainer/ModifiersContainer
@onready var add_modifier_button: Button = $VBoxContainer/AddModifierButton


func setup(p_channel_name:StringName,p_layer_id:StringName) -> void:

	channel_name = p_channel_name
	layer_id = p_layer_id

	layer_path = MaterialPath.new([&"channels",channel_name,&"layers",layer_id])

	if is_inside_tree():
		_refresh()


func _ready() -> void:
	name_edit.text_changed.connect(_on_name_changed)
	blend_mode_selector.item_selected.connect(_on_blend_mode_selected)
	add_modifier_button.pressed.connect(_on_add_modifier)
	generator_selector.pressed.connect(_on_generator_button_pressed)
	_fill_blend_modes()

	if layer_path:
		_refresh()
		
		
func _refresh() -> void:
	var layer_data:Dictionary = layer_path.get_value()
	if layer_data.is_empty():
		return
	name_edit.text = layer_data[&"name"]
	_refresh_generator_button()
	_refresh_blend_mode()
	_refresh_modifiers()
	

func _fill_blend_modes() -> void:
	blend_mode_selector.clear()
	for mode_name in MixLibrary.MixModes.keys():
		blend_mode_selector.add_item(mode_name)
	
	
func _refresh_blend_mode() -> void:
	var current_mode:StringName = (layer_path.child(&"blend_mode").get_value())

	for i in range(blend_mode_selector.item_count):
		if blend_mode_selector.get_item_text(i) == String(current_mode):
			blend_mode_selector.select(i)
			return
	
	
func _on_blend_mode_selected(index:int) -> void:
	var mode_name := StringName(blend_mode_selector.get_item_text(index))
	layer_path.child(&"blend_mode").set_value(mode_name)
	
	
func _refresh_generator_button() -> void:
	var generator_id:StringName = layer_path.child(&"generator_id").get_value()

	if generator_id.is_empty():
		generator_selector.text = "Select Generator"
		return

	var generator = EditorMaterial.get_generator(generator_id)

	if generator.is_empty():
		generator_selector.text = "Missing Generator"
		return

	generator_selector.text = "%s (%s)" % [generator_id,generator[&"generator_name"]]
	
	
func _on_generator_button_pressed() -> void:
	var picker_scene = preload("res://PTE_V3_R/UI/project_generator_picker.tscn")
	var picker = picker_scene.instantiate()
	add_child(picker)
	picker.generator_selected.connect(_on_generator_selected)
	picker.popup_centered()
	

func _refresh_modifiers() -> void:
	for child in modifiers_container.get_children():
		child.queue_free()

	for modifier_data in EditorMaterial.get_modifiers_in_order(channel_name,layer_id):
		_create_modifier_ui(modifier_data)


func _on_generator_selected(generator_id:StringName) -> void:
	layer_path.child(&"generator_id").set_value(generator_id)
	_refresh_generator_button()
	
	
func _create_modifier_ui(modifier_data:Dictionary) -> void:
	var scene = preload("res://PTE_V3_R/UI/base_modifier_ui.tscn")
	var controller = scene.instantiate() as ModifierUIController
	modifiers_container.add_child(controller)
	controller.setup(channel_name,layer_id,modifier_data[&"id"])
	
func _on_add_modifier() -> void:
	var modifier_name := "ColorRamp"
	var modifier_data := EditorMaterial.add_modifier(channel_name,layer_id,modifier_name,{})

	_create_modifier_ui(modifier_data)
	
	
func _on_name_changed(new_text:String) -> void:
	layer_path.child(&"name").set_value(new_text)
