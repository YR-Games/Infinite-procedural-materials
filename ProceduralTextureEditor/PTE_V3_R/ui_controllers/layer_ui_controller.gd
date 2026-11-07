class_name LayerUIController
extends PanelContainer

const MODIFIER_SCENE := preload("res://PTE_V3_R/UI/base_modifier_ui.tscn")

var channel_name: StringName
var layer_id: StringName
var layer_path: MaterialPath
var owner_channel: ChannelUIController
var _preview_material: ShaderMaterial

# Ожидание выбора генератора (один слой за раз)
static var pending_generator_layer: LayerUIController = null

var modifier_controllers: Array[ModifierUIController] = []
var current_modifier: ModifierUIController = null

@onready var name_edit: LineEdit = $VBoxContainer/Header/LayerName
@onready var generator_selector: Button = $VBoxContainer/SelectGeneratorButton
@onready var blend_mode_selector: OptionButton = $VBoxContainer/BlendModeOption
@onready var modifiers_container: VBoxContainer = $VBoxContainer/ModifiersContainer
@onready var add_modifier_button: Button = $VBoxContainer/AddModifierButton
@onready var generator_name_label: Label = $VBoxContainer/LabelGeneratorName
@onready var preview_rect: ColorRect = $VBoxContainer/Preview
@onready var opacity_slider: HSlider = $VBoxContainer/OpacitySlider

@onready var generator_list: GeneratorListUIController = get_node_or_null("/root/EditorUI/MenuAndUI/UI/EditorPreviewSplit/GeneratorsChannelsSplit/Generators")

var normal_style = preload("res://style/styles/normal_style_box.tres")
var highlight_style = preload("res://style/styles/selected_style_box.tres")

var is_selected := false:
	set(value):
		is_selected = value
		_update_style()


func setup(p_channel_name: StringName, p_layer_id: StringName, p_owner_channel: ChannelUIController = null) -> void:
	channel_name = p_channel_name
	layer_id = p_layer_id
	layer_path = MaterialPath.new([&"channels", channel_name, &"layers", layer_id])
	owner_channel = p_owner_channel

	if is_inside_tree():
		_refresh()


func _ready() -> void:
	add_theme_stylebox_override("panel", normal_style)
	opacity_slider.value_changed.connect(_on_opacity_changed)
	name_edit.text_changed.connect(_on_name_changed)
	blend_mode_selector.item_selected.connect(_on_blend_mode_selected)
	add_modifier_button.pressed.connect(_on_add_modifier_button_pressed)
	generator_selector.pressed.connect(_on_select_generator_button_pressed)

	# UI follows data: scripts (or anything else) may change the material at any time.
	SignalBus.layer_structure_changed.connect(_refresh)       # modifiers added/removed/reordered, generator relinked
	SignalBus.material_value_changed.connect(_refresh_light)  # parameter / property values

	_fill_blend_modes()

	if layer_path:
		_refresh()


# ---------------------- Refresh ----------------------

func _layer_exists() -> bool:
	return layer_path != null and not EditorMaterial.get_layer(channel_name, layer_id).is_empty()


## Full sync (structure changed).
func _refresh() -> void:
	if not is_inside_tree() or not _layer_exists():
		return
	_refresh_fields()
	_refresh_generator_preview()
	_sync_modifiers()


## Cheap sync (values changed): no structural work.
func _refresh_light() -> void:
	if not is_inside_tree() or not _layer_exists():
		return
	_refresh_fields()
	_refresh_generator_preview()


func _refresh_fields() -> void:
	var layer := EditorMaterial.get_layer(channel_name, layer_id)

	var layer_name: String = layer.get(&"name", "Layer")
	if name_edit.text != layer_name and not name_edit.has_focus():
		name_edit.text = layer_name

	opacity_slider.set_value_no_signal(layer.get(&"opacity", 1.0))
	_refresh_blend_mode()


# ---------------------- Generator assignment ----------------------

func _on_select_generator_button_pressed() -> void:
	if generator_list == null:
		return
	pending_generator_layer = self
	if not generator_list.generator_selected.is_connected(_static_on_generator_selected):
		generator_list.generator_selected.connect(_static_on_generator_selected)
	generator_selector.text = "Выберите текстуру..."


static func _static_on_generator_selected(generator_id: StringName) -> void:
	if is_instance_valid(pending_generator_layer):
		pending_generator_layer.assign_generator(generator_id)
	pending_generator_layer = null


func assign_generator(generator_id: StringName) -> void:
	EditorMaterial.set_layer_property(channel_name, layer_id, &"generator_id", generator_id)
	_refresh_generator_preview()
	_select_generator_in_list(generator_id)
	generator_selector.text = "Выбрать базовую текстуру"


func _select_generator_in_list(generator_id: StringName) -> void:
	if generator_list == null:
		return
	var panel := generator_list.get_panel(generator_id)
	if panel:
		SelectionManager.select(panel)


func _refresh_generator_preview() -> void:
	if not preview_rect:
		return

	if not _preview_material:
		_preview_material = ShaderMaterial.new()
		preview_rect.material = _preview_material

	var layer := EditorMaterial.get_layer(channel_name, layer_id)
	var gen_id: StringName = layer.get(&"generator_id", StringName())
	if gen_id.is_empty():
		generator_name_label.text = "Базовая текстура не выбрана"
		_preview_material.shader = null
		return

	var gen_dict := EditorMaterial.get_generator(gen_id)
	if gen_dict.is_empty():
		generator_name_label.text = "Missing Generator"
		_preview_material.shader = null
		return

	var gen_name: StringName = gen_dict.get(&"generator_name", &"Unknown")
	generator_name_label.text = gen_name

	var gen_data: GeneratorData = GeneratorLibrary.get_generator_data(gen_name)
	if not gen_data or not gen_data.preview_shader:
		_preview_material.shader = null
		return

	_preview_material.shader = gen_data.preview_shader

	var saved_params: Dictionary = gen_dict.get(&"parameters", {})
	for param_name in saved_params:
		_preview_material.set_shader_parameter(param_name, saved_params[param_name])


# ---------------------- Blend mode / opacity / name ----------------------

func _fill_blend_modes() -> void:
	blend_mode_selector.clear()
	for mode_name in MixLibrary.MixModes.keys():
		blend_mode_selector.add_item(mode_name)


func _refresh_blend_mode() -> void:
	var current_mode: StringName = EditorMaterial.get_layer(channel_name, layer_id).get(&"blend_mode", &"")
	for i in range(blend_mode_selector.item_count):
		if blend_mode_selector.get_item_text(i) == String(current_mode):
			blend_mode_selector.select(i)
			return


func _on_blend_mode_selected(index: int) -> void:
	EditorMaterial.set_layer_property(channel_name, layer_id, &"blend_mode", StringName(blend_mode_selector.get_item_text(index)))


func _on_opacity_changed(value: float) -> void:
	EditorMaterial.set_layer_property(channel_name, layer_id, &"opacity", value)


func _on_name_changed(new_text: String) -> void:
	EditorMaterial.set_layer_property(channel_name, layer_id, &"name", new_text)


# ---------------------- Modifiers ----------------------

## Incremental sync with EditorMaterial: add / remove / reorder.
func _sync_modifiers() -> void:
	var wanted := EditorMaterial.get_modifier_order(channel_name, layer_id)

	for controller in modifier_controllers.duplicate():
		if not wanted.has(controller.modifier_id):
			_drop_modifier(controller)

	var index := 0
	for modifier_id in wanted:
		var controller := get_modifier_controller(modifier_id)
		if controller == null:
			if EditorMaterial.get_modifier(channel_name, layer_id, modifier_id).is_empty():
				continue
			controller = _spawn_modifier(modifier_id)
		modifiers_container.move_child(controller, index)
		index += 1


func get_modifier_controller(modifier_id: StringName) -> ModifierUIController:
	for controller in modifier_controllers:
		if controller.modifier_id == modifier_id:
			return controller
	return null


func _spawn_modifier(modifier_id: StringName) -> ModifierUIController:
	var controller := MODIFIER_SCENE.instantiate() as ModifierUIController
	modifiers_container.add_child(controller)
	controller.setup(channel_name, layer_id, modifier_id)
	controller.gui_input.connect(_on_modifier_gui_input.bind(controller))
	modifier_controllers.append(controller)
	return controller


func _drop_modifier(controller: ModifierUIController) -> void:
	modifier_controllers.erase(controller)
	if current_modifier == controller:
		current_modifier = null
	modifiers_container.remove_child(controller)
	controller.queue_free()


func _on_modifier_gui_input(event: InputEvent, controller: ModifierUIController) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.select(controller)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_delete") and current_modifier:
		_remove_modifier(current_modifier)


func _remove_modifier(controller: ModifierUIController) -> void:
	EditorMaterial.remove_modifier(channel_name, layer_id, controller.modifier_id)  # -> _sync_modifiers()


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
	_on_add_modifier(StringName(names[id]))
	popup.queue_free()


func _on_add_modifier(modifier_type_name: StringName) -> void:
	# Default parameters are filled in by EditorMaterial; the signal creates the UI.
	var modifier := EditorMaterial.add_modifier(channel_name, layer_id, modifier_type_name)
	if modifier.is_empty():
		push_error("Не удалось добавить модификатор '%s'" % modifier_type_name)


# ---------------------- Style / selection ----------------------

func _update_style() -> void:
	add_theme_stylebox_override("panel", highlight_style if is_selected else normal_style)


func set_selected(selected: bool) -> void:
	is_selected = selected


# ---------------------- Drag & drop (layers) ----------------------

func _get_drag_data(_at_position):
	set_drag_preview(duplicate())
	return {
		"type": "layer",
		"layer_id": layer_id,
		"channel": channel_name,
	}


func _can_drop_data(_at_position, data) -> bool:
	return data is Dictionary and data.get("type") == "layer" and data.get("channel") == channel_name


func _drop_data(_at_position, data) -> void:
	var source_id: StringName = data["layer_id"]
	if source_id == layer_id:
		return

	var order := EditorMaterial.get_layer_order(channel_name)
	# move_layer emits layer_structure_changed -> ChannelUIController._sync() reorders the UI
	EditorMaterial.move_layer(channel_name, order.find(source_id), order.find(layer_id))


func delete_self() -> void:
	EditorMaterial.remove_layer(channel_name, layer_id)
