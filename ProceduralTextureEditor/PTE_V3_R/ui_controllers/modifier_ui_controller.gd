class_name ModifierUIController
extends PanelContainer

var channel_name: StringName
var layer_id: StringName
var modifier_id: StringName
var modifier_path: MaterialPath
var param_controls: Dictionary[String, ParameterControl] = {}

@onready var modifier_name_label: Label = $VBoxContainer/ModifierName
@onready var params_container: VBoxContainer = $VBoxContainer/ParameterScroll/ParameterList


func setup(p_channel_name:StringName,p_layer_id:StringName,p_modifier_id:StringName) -> void:

	channel_name = p_channel_name
	layer_id = p_layer_id
	modifier_id = p_modifier_id

	modifier_path = MaterialPath.new([&"channels",channel_name,&"layers",layer_id,&"modifiers",modifier_id])

	if is_inside_tree():
		_refresh_ui()


func _ready() -> void:

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

		var def:abstract_parameter_def = (modifier_data.parameters[param_name])
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
