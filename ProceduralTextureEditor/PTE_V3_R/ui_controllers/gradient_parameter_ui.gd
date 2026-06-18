class_name GradientParameterControl
extends ParameterControl

var gradient: Gradient
var param_def: GradientParameterDef

@onready var label: Label = $HBoxContainer/Label
@onready var gradient_preview: TextureRect = $HBoxContainer/GradientPreview
@onready var edit_button: Button = $HBoxContainer/EditButton

func setup(def: GradientParameterDef, parameter_name: String) -> void:
	param_def = def
	label.text = parameter_name
	_setup_ui()
	_update_from_data()

func _setup_ui() -> void:
	edit_button.pressed.connect(_on_edit_pressed)
	var tex = GradientTexture2D.new()
	tex.width = 256
	tex.height = 24
	gradient_preview.texture = tex
	gradient_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH

func _update_from_data() -> void:
	var val = get_data_value()
	if val is Gradient:
		gradient = val.duplicate()
	else:
		gradient = param_def.default_value.duplicate()
	_refresh_preview()

func _refresh_preview() -> void:
	var tex := gradient_preview.texture as GradientTexture2D
	tex.gradient = gradient
	gradient_preview.queue_redraw()

func _on_edit_pressed() -> void:
	var popup = preload("res://PTE_V3_R/UI/gradient_editor_popup.tscn").instantiate() as GradientEditorPopup
	popup.gradient = gradient.duplicate()
	popup.editing_finished.connect(_on_gradient_edited)
	get_tree().root.add_child(popup)
	popup.popup_centered()

func _on_gradient_edited(new_gradient: Gradient) -> void:
	gradient = new_gradient
	_on_ui_changed(gradient)
	_refresh_preview()
