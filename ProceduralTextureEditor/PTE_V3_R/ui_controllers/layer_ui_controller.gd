class_name LayerUIController
extends PanelContainer

var channel_name: StringName
var layer_id: StringName
var layer_path: MaterialPath
var _preview_material: ShaderMaterial


static var pending_generator_layer: LayerUIController = null
static var _generator_selection_handler_connected := false

var modifier_controllers : Array[ModifierUIController] = []
var current_modifier : ModifierUIController = null

@onready var name_edit: LineEdit = $VBoxContainer/Header/LayerName
@onready var generator_selector: Button = $VBoxContainer/SelectGeneratorButton
@onready var blend_mode_selector: OptionButton = $VBoxContainer/BlendModeOption
@onready var modifiers_container: VBoxContainer = $VBoxContainer/ModifiersContainer
@onready var add_modifier_button: Button = $VBoxContainer/AddModifierButton
@onready var generator_name_label: Label = $VBoxContainer/LabelGeneratorName
@onready var preview_rect: ColorRect = $VBoxContainer/Preview
@onready var opacity_slider: HSlider = $VBoxContainer/OpacitySlider

@onready var generator_list: GeneratorListUIController = get_node("/root/EditorUI/MenuAndUI/UI/EditorPreviewSplit/GeneratorsChannelsSplit/Generators")

var normal_style = preload("res://PTE_V3_R/styles/normal_style_box.tres")
var highlight_style = preload("res://PTE_V3_R/styles/selected_style_box.tres")
var owner_channel: ChannelUIController


var is_selected := false:
	set(value):
		is_selected = value
		_update_style()

func setup(p_channel_name: StringName, p_layer_id: StringName, p_owner_channel: ChannelUIController) -> void:
	channel_name = p_channel_name
	layer_id = p_layer_id
	layer_path = MaterialPath.new([&"channels", channel_name, &"layers", layer_id])
	owner_channel = p_owner_channel

	if is_inside_tree():
		_refresh()


func _ready() -> void:
	opacity_slider.value_changed.connect(_on_opacity_changed)
	add_theme_stylebox_override("panel",normal_style)
	name_edit.text_changed.connect(_on_name_changed)
	blend_mode_selector.item_selected.connect(_on_blend_mode_selected)
	add_modifier_button.pressed.connect(_on_add_modifier_button_pressed)
	generator_selector.pressed.connect(_on_select_generator_button_pressed)

	_fill_blend_modes()

	if layer_path:
		_refresh()


# ---------------------- Назначение генератора слою ----------------------
func _on_select_generator_button_pressed() -> void:
	# Делаем этот слой ожидающим выбор генератора
	pending_generator_layer = self
	# Подключаем глобальный обработчик один раз
	if not _generator_selection_handler_connected:
		generator_list.generator_selected.connect(_static_on_generator_selected)
		_generator_selection_handler_connected = true
	# Визуальная обратная связь (опционально)
	generator_selector.text = "Selecting..."


static func _static_on_generator_selected(generator_id: StringName) -> void:
	if pending_generator_layer:
		pending_generator_layer._assign_generator(generator_id)
		pending_generator_layer = null


func _assign_generator(generator_id: StringName) -> void:
	layer_path.child(&"generator_id").set_value(generator_id)
	_refresh_generator_preview()
	_refresh_generator_list()           # обновляем выделение в общем списке
	generator_selector.text = "Select Generator"   # возвращаем надпись


# ---------------------- Обновление интерфейса ----------------------
func _refresh() -> void:
	var layer_data: Dictionary = layer_path.get_value()
	if layer_data.is_empty():
		return
	name_edit.text = layer_data[&"name"]
	_refresh_generator_list()
	_refresh_generator_preview()
	_refresh_blend_mode()
	_refresh_modifiers()
	opacity_slider.value = layer_data.get(&"opacity", 1.0)

func _refresh_generator_preview() -> void:
	if not preview_rect:
		return

	if not _preview_material:
		_preview_material = ShaderMaterial.new()
		preview_rect.material = _preview_material

	var gen_id: StringName = layer_path.child(&"generator_id").get_value()
	if gen_id.is_empty():
		generator_name_label.text = "No Generator"
		_preview_material.shader = null
		return

	var gen_dict: Dictionary = EditorMaterial.get_generator(gen_id)
	if gen_dict.is_empty():
		generator_name_label.text = "Missing Generator"
		_preview_material.shader = null
		return

	var gen_name: StringName = gen_dict.get("generator_name", "Unknown")
	generator_name_label.text = gen_name

	var gen_data: GeneratorData = GeneratorLibrary.get_generator_data(gen_name)
	if not gen_data or not gen_data.preview_shader:
		_preview_material.shader = null
		return

	_preview_material.shader = gen_data.preview_shader

	var saved_params: Dictionary = gen_dict.get("parameters", {})
	for param_name in saved_params:
		var value = saved_params[param_name]
		_preview_material.set_shader_parameter(param_name, value)


func _refresh_generator_list() -> void:
	var all_generators_dict: Dictionary = EditorMaterial.get_generators()
	var generators_array: Array[Dictionary] = []
	for gen_id in all_generators_dict:
		var gen = all_generators_dict[gen_id]
		generators_array.append({
			"id": gen_id,
			"type": gen.get("generator_name", "")
		})



	var current_gen_id: StringName = layer_path.child(&"generator_id").get_value()
	if not current_gen_id.is_empty():
		_select_generator_in_list(current_gen_id)


func _select_generator_in_list(generator_id: StringName) -> void:
	for panel in generator_list.panels:
		if panel.generator_id == generator_id:
			SelectionManager.select(panel)
			break



func _fill_blend_modes() -> void:
	blend_mode_selector.clear()
	for mode_name in MixLibrary.MixModes.keys():
		blend_mode_selector.add_item(mode_name)


func _refresh_blend_mode() -> void:
	var current_mode: StringName = layer_path.child(&"blend_mode").get_value()
	for i in range(blend_mode_selector.item_count):
		if blend_mode_selector.get_item_text(i) == String(current_mode):
			blend_mode_selector.select(i)
			return


func _on_blend_mode_selected(index: int) -> void:
	var mode_name := StringName(blend_mode_selector.get_item_text(index))
	layer_path.child(&"blend_mode").set_value(mode_name)

func _on_opacity_changed(value: float) -> void:
	layer_path.child(&"opacity").set_value(value)


func _refresh_modifiers() -> void:
	for child in modifiers_container.get_children():
		child.queue_free()
	for modifier_data in EditorMaterial.get_modifiers_in_order(channel_name, layer_id):
		_create_modifier_ui(modifier_data)


func _create_modifier_ui(modifier_data: Dictionary) -> void:
	var scene = preload("res://PTE_V3_R/UI/base_modifier_ui.tscn")
	var controller = scene.instantiate() as ModifierUIController
	modifiers_container.add_child(controller)
	controller.setup(channel_name, layer_id, modifier_data[&"id"])
	
	controller.gui_input.connect(_on_modifier_gui_input.bind(controller))
	modifier_controllers.append(controller)

func _on_modifier_gui_input(
	event,
	controller
) -> void:

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		SelectionManager.select(controller)



func _unhandled_input(event):
	if event.is_action_pressed("ui_text_delete") \
	and current_modifier:
		_remove_modifier(current_modifier)

func _remove_modifier(controller: ModifierUIController) -> void:

	EditorMaterial.remove_modifier(channel_name,layer_id,controller.modifier_id)
	modifier_controllers.erase(controller)

	if current_modifier == controller:
		current_modifier = null

	controller.queue_free()

func _on_add_modifier_button_pressed() -> void:
	var names: PackedStringArray = ModifierLibrary.get_all_names()
	if names.is_empty():
		push_warning("ModifierLibrary не содержит модификаторов")
		return

	var popup := PopupMenu.new()
	popup.name = "ModifierTypePopup"
	add_child(popup)

	for i in range(names.size()):
		popup.add_item(names[i], i)

	popup.id_pressed.connect(_on_modifier_type_selected.bind(names, popup))
	popup.popup_hide.connect(popup.queue_free)
	popup.popup_centered()


func _on_modifier_type_selected(id: int, names: PackedStringArray, popup: PopupMenu) -> void:
	var type_name: StringName = names[id]
	_on_add_modifier(type_name)
	popup.queue_free()

func _update_style() -> void:

	var style = (highlight_style if is_selected else normal_style)

	add_theme_stylebox_override("panel", style)

func set_selected(selected: bool) -> void:
	is_selected = selected

func _get_drag_data(at_position):
	var preview := duplicate()
	set_drag_preview(preview)

	return {
		"type": "layer",
		"layer_id": layer_id,
		"channel": channel_name
	}

func _can_drop_data(at_position,data) -> bool:
	return (
		data is Dictionary and data.get("type") == "layer" and data.get("channel") == channel_name
	)

func _drop_data(at_position,data) -> void:
	var source_id : StringName = data["layer_id"]
	if source_id == layer_id:
		return
	var order = EditorMaterial.get_layer_order(channel_name)
	var from_index = order.find(source_id)
	var to_index = order.find(layer_id)

	EditorMaterial.move_layer(channel_name,from_index,to_index)

	owner_channel._refresh()

func _on_add_modifier(modifier_type_name: StringName) -> void:
	var modifier_data := EditorMaterial.add_modifier(channel_name, layer_id, modifier_type_name, {})
	if not modifier_data:
		push_error("Модификатор '%s' не найден в библиотеке" % modifier_type_name)
		return
	_create_modifier_ui(modifier_data)


func _on_name_changed(new_text: String) -> void:
	layer_path.child(&"name").set_value(new_text)
	
	
func delete_self():
	owner_channel._remove_layer(self)
