class_name ModifierUIController
extends PanelContainer

var channel_name: StringName
var layer_id: StringName
var modifier_id: StringName
var modifier_path: MaterialPath
var param_controls: Dictionary[String, ParameterControl] = {}

@onready var modifier_name_label: Label = $VBoxContainer/ModifierName
@onready var params_container: VBoxContainer = $VBoxContainer/ParameterScroll/ParameterList

var normal_style = preload("res://PTE_V3_R/styles/normal_style_box.tres")
var highlight_style = preload("res://PTE_V3_R/styles/selected_style_box.tres")
var parent_layer:LayerUIController

var is_selected := false:
	set(value):
		is_selected = value
		_update_style()


func setup(p_channel_name:StringName,p_layer_id:StringName,p_modifier_id:StringName) -> void:
	
	channel_name = p_channel_name
	layer_id = p_layer_id
	modifier_id = p_modifier_id

	modifier_path = MaterialPath.new([&"channels",channel_name,&"layers",layer_id,&"modifiers",modifier_id])

	if is_inside_tree():
		_refresh_ui()


func _update_style() -> void:
	var style = (highlight_style if is_selected else normal_style)
	add_theme_stylebox_override("panel", style)

func set_selected(selected: bool) -> void:
	is_selected = selected

func _ready() -> void:
	parent_layer =get_parent().get_parent().get_parent()
	add_theme_stylebox_override("panel",normal_style)

	if modifier_path:
		_refresh_ui()


func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	var modifier:Dictionary = modifier_path.get_value()
	if modifier.is_empty():
		return
		
	modifier_name_label.text = String(modifier[&"modifier_name"])

	_clear_parameter_ui()
	param_controls.clear()
	var modifier_data:ModifierData = (ModifierLibrary.get_modifier_data(modifier[&"modifier_name"]))

	if modifier_data == null:
		return

	for param_name in modifier_data.parameters:

		var def:abstractParameterDef = (modifier_data.parameters[param_name])
		var control := ParameterControlFactory.create(def)
		if control == null:
			continue

		params_container.add_child(control)
		control.setup(def, param_name)
		var param_path := (modifier_path.child(&"parameters").child(param_name))
		control.bind(param_path)
		param_controls[param_name] = control


func _clear_parameter_ui() -> void:
	for child in params_container.get_children():
		child.queue_free()

func _get_drag_data(at_position):

	var preview := duplicate()
	set_drag_preview(preview)

	return {
		"type": "modifier",
		"modifier_id": modifier_id
	}
	
func _can_drop_data(at_position,data) -> bool:
	return (data is Dictionary and data.get("type") == "modifier")
	
	
func _drop_data(at_position,data) -> void:
	var source_id : StringName = data["modifier_id"]

	if source_id == modifier_id:
		return

	var order = EditorMaterial.get_modifier_order(channel_name,layer_id)
	var from_index = order.find(source_id)
	var to_index = order.find(modifier_id)

	EditorMaterial.move_modifier(channel_name,layer_id,from_index,to_index)

	parent_layer._refresh_modifiers()
	

func delete_self():
	parent_layer._remove_modifier(self)
