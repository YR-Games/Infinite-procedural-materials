class_name LayerUIBase
extends PanelContainer

# Reference to the layer data this row represents
var layer_data: AbstractLayerData:
	set(val):
		layer_data = val
		if is_inside_tree():
			_refresh()

# Called by LayerStack to set parent stack (used for drag-drop)
var parent_stack: LayerStack = null

# Selection style
var normal_style = preload("res://PTE_V3_R/styles/normal_style_box.tres")
var selected_style = preload("res://PTE_V3_R/styles/selected_style_box.tres")

var _is_selected := false
signal selected

@onready var header: HBoxContainer = $VBoxContainer/Header
@onready var name_label: LineEdit = $VBoxContainer/Header/LayerName
@onready var visibility_button: Button = $VBoxContainer/Header/LayerName
@onready var blend_mode_option: OptionButton = $VBoxContainer/MixOptions/BlendModeOption
@onready var opacity_slider: HSlider = $VBoxContainer/MixOptions/OpacitySlider
@onready var extra_controls: VBoxContainer = $VBoxContainer/Controls

func _ready() -> void:
	add_theme_stylebox_override("panel", normal_style)
	visibility_button.toggled.connect(_on_visibility_toggled)
	blend_mode_option.item_selected.connect(_on_blend_mode_changed)
	opacity_slider.value_changed.connect(_on_opacity_changed)

	if layer_data:
		_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return

	name_label.text = _get_display_name()

	# Visibility
	visibility_button.button_pressed = layer_data.enabled

	# Blend / opacity controls: show only if the layer type uses them
	var uses_blend = layer_data.uses_blend_mode
	blend_mode_option.visible = uses_blend
	opacity_slider.visible = uses_blend
	if uses_blend:
		# Populate blend modes (Photoshop-style)
		blend_mode_option.clear()
		for mode in AbstractLayerData.BlendMode.keys():
			blend_mode_option.add_item(mode.capitalize())
		blend_mode_option.select(layer_data.blend_mode)
		opacity_slider.value = layer_data.opacity

	# Let subclasses add their own controls (e.g. generator picker, gradient)
	_clear_extra_controls()
	_setup_extra_controls()

	# Propagate to nested composite (if any) – subclasses can override
	_refresh_children()

func _clear_extra_controls() -> void:
	for child in extra_controls.get_children():
		child.queue_free()

# Override in subclasses to add type‑specific UI
func _setup_extra_controls() -> void:
	pass

# Override to give a nice name (e.g. "Bump Layer", generator name)
func _get_display_name() -> String:
	return "Layer"

# Optional: refresh child layers for CompositeLayerUI
func _refresh_children() -> void:
	pass

func set_selected(s: bool) -> void:
	_is_selected = s
	add_theme_stylebox_override("panel", selected_style if s else normal_style)
	if s:
		selected.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Single click -> select
			if parent_stack:
				parent_stack.select_layer(self)
			accept_event()

func _get_drag_data(at_position: Vector2) -> Variant:
	# Start drag: return a dict with the dragged layer and its stack
	if parent_stack:
		set_drag_preview(_make_drag_preview())
		return {"layer_ui": self, "source_stack": parent_stack}
	return null

func _make_drag_preview() -> Control:
	var copy = duplicate()
	copy.modulate.a = 0.7
	return copy

# --- Data change callbacks ---
func _on_visibility_toggled(visible: bool) -> void:
	layer_data.enabled = visible

func _on_blend_mode_changed(index: int) -> void:
	layer_data.blend_mode = index as AbstractLayerData.BlendMode

func _on_opacity_changed(value: float) -> void:
	layer_data.opacity = value
