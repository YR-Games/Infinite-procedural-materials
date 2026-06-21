class_name PaletteParameterControl
extends ParameterControl

var colors: Array[Color] = []
var param_def: PaletteParameterDef

@onready var label: Label = $VBoxContainer/Label
@onready var gradient_preview: TextureRect = $VBoxContainer/GradientPreview
@onready var add_button: Button = $VBoxContainer/HBoxContainer/AddButton
@onready var remove_button: Button = $VBoxContainer/HBoxContainer/RemoveButton
@onready var colors_container: HBoxContainer = $VBoxContainer/ColorsContainer


func setup(def: PaletteParameterDef, parameter_name: String) -> void:
	param_def = def
	label.text = parameter_name

	_setup_ui()
	_update_from_data()


func _setup_ui() -> void:
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)

	var tex := GradientTexture2D.new()
	tex.width = 256
	tex.height = 24
	gradient_preview.texture = tex


func _update_from_data() -> void:
	var val = get_data_value()

	if val is Array:
		colors = val.duplicate()
	else:
		colors = param_def.default_colors.duplicate()

	_rebuild_color_buttons()
	_refresh_preview()


func _rebuild_color_buttons() -> void:
	for child in colors_container.get_children():
		child.queue_free()

	for i in colors.size():
		var picker := ColorPickerButton.new()

		picker.custom_minimum_size = Vector2(32, 32)
		picker.color = colors[i]

		picker.color_changed.connect(
			_on_color_changed.bind(i)
		)

		colors_container.add_child(picker)

	add_button.disabled = colors.size() >= param_def.max_colors
	remove_button.disabled = colors.size() <= 2


func _refresh_preview() -> void:
	var grad := Gradient.new()

	var count := colors.size()

	if count == 0:
		return

	if count == 1:
		grad.add_point(0.0, colors[0])
	else:
		for i in count:
			var offset := float(i) / float(count - 1)
			grad.add_point(offset, colors[i])

	var tex := gradient_preview.texture as GradientTexture2D
	tex.gradient = grad

	gradient_preview.queue_redraw()


func _emit_change() -> void:
	_on_ui_changed(colors.duplicate())


func _on_color_changed(color: Color, index: int) -> void:
	if index < 0 or index >= colors.size():
		return

	colors[index] = color

	_refresh_preview()
	_emit_change()


func _on_add_pressed() -> void:
	if colors.size() >= param_def.max_colors:
		return

	var new_color := Color.WHITE

	if not colors.is_empty():
		new_color = colors[colors.size() - 1]

	colors.append(new_color)

	_rebuild_color_buttons()
	_refresh_preview()
	_emit_change()


func _on_remove_pressed() -> void:
	if colors.size() <= 2:
		return

	colors.remove_at(colors.size() - 1)

	_rebuild_color_buttons()
	_refresh_preview()
	_emit_change()
