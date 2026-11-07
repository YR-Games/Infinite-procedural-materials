class_name ModifierUIController
extends PanelContainer

var channel_name: StringName
var layer_id: StringName
var modifier_id: StringName
var modifier_path: MaterialPath
var param_controls: Dictionary[String, ParameterControl] = {}

@onready var modifier_name_label: Label = $VBoxContainer/ModifierName
@onready var params_container: VBoxContainer = $VBoxContainer/ParameterScroll/ParameterList

var normal_style = preload("res://style/styles/normal_style_box.tres")
var highlight_style = preload("res://style/styles/selected_style_box.tres")

var is_selected := false:
	set(value):
		is_selected = value
		_update_style()


func setup(p_channel_name: StringName, p_layer_id: StringName, p_modifier_id: StringName) -> void:
	channel_name = p_channel_name
	layer_id = p_layer_id
	modifier_id = p_modifier_id
	modifier_path = MaterialPath.new([&"channels", channel_name, &"layers", layer_id, &"modifiers", modifier_id])

	if is_inside_tree():
		_refresh_ui()


func _ready() -> void:
	add_theme_stylebox_override("panel", normal_style)
	if modifier_path:
		_refresh_ui()


func _update_style() -> void:
	add_theme_stylebox_override("panel", highlight_style if is_selected else normal_style)


func set_selected(selected: bool) -> void:
	is_selected = selected


func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	var modifier := EditorMaterial.get_modifier(channel_name, layer_id, modifier_id)
	if modifier.is_empty():
		return

	modifier_name_label.text = String(modifier[&"modifier_name"])

	_clear_parameter_ui()
	param_controls.clear()

	var modifier_data: ModifierData = ModifierLibrary.get_modifier_data(modifier[&"modifier_name"])
	if modifier_data == null:
		return

	var params_path := modifier_path.child(&"parameters")
	for param_name in modifier_data.parameters:
		var def: abstractParameterDef = modifier_data.parameters[param_name]
		var control := ParameterControlFactory.create(def)
		if control == null:
			continue

		params_container.add_child(control)
		control.setup(def, param_name)
		control.bind(params_path.child(param_name))
		param_controls[param_name] = control


func _clear_parameter_ui() -> void:
	for child in params_container.get_children():
		params_container.remove_child(child)
		child.queue_free()


# ---------------------- Drag & drop (modifiers) ----------------------

func _get_drag_data(_at_position):
	set_drag_preview(duplicate())
	return {
		"type": "modifier",
		"modifier_id": modifier_id,
		"layer_id": layer_id,
	}


func _can_drop_data(_at_position, data) -> bool:
	# only within the same layer
	return data is Dictionary and data.get("type") == "modifier" and data.get("layer_id") == layer_id


func _drop_data(_at_position, data) -> void:
	var source_id: StringName = data["modifier_id"]
	if source_id == modifier_id:
		return

	var order := EditorMaterial.get_modifier_order(channel_name, layer_id)
	# move_modifier emits layer_structure_changed -> LayerUIController._sync_modifiers() reorders the UI
	EditorMaterial.move_modifier(channel_name, layer_id, order.find(source_id), order.find(modifier_id))


func delete_self() -> void:
	EditorMaterial.remove_modifier(channel_name, layer_id, modifier_id)
