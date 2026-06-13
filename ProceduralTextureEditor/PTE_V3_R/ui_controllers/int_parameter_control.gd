class_name IntParameterControl
extends ParameterControl

@onready var parameter_label: Label = $HBoxContainer/Label
@onready var slider: Slider = $HBoxContainer/HSlider
var param_def: int_parameter_def



func setup(def: int_parameter_def, parameter_name: String) -> void:
	param_def = def
	parameter_label.text = parameter_name
	_setup_ui()
	_update_from_data()

func _setup_ui() -> void:
	slider.min_value = float(param_def.min_value)
	slider.max_value = float(param_def.max_value)
	slider.step = float(param_def.step)
	slider.value_changed.connect(_on_spinbox_changed)

func _update_from_data() -> void:

	var val = get_data_value()

	if val == null:
		val = param_def.default_value

	slider.value = int(val)

func _on_spinbox_changed(new_val: float) -> void:
	var int_val = int(round(new_val))
	_on_ui_changed(int_val)
