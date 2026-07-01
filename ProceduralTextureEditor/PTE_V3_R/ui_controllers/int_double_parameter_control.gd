class_name IntDoubleParameterControl
extends ParameterControl

@onready var parameter_label: Label = $VBoxContainer/ParamNameLabel
@onready var spinbox: SpinBox = $VBoxContainer/HBoxContainer/SpinBox
@onready var slider: HSlider = $VBoxContainer/HBoxContainer/Slider
@onready var min_val_label: Label = $VBoxContainer/HBoxContainer/minVal
@onready var max_val_label: Label = $VBoxContainer/HBoxContainer/maxVal

var param_def: intParameterDef


func setup(def: intParameterDef, parameter_name: String) -> void:
	param_def = def
	parameter_label.text = parameter_name
	_setup_ui()
	_update_from_data()


func _setup_ui() -> void:
	spinbox.min_value = param_def.min_value
	spinbox.max_value = param_def.max_value
	spinbox.step = param_def.step
	spinbox.value_changed.connect(_on_spinbox_changed)
	
	slider.min_value = param_def.min_value
	slider.max_value = param_def.max_value
	slider.step = param_def.step
	slider.value_changed.connect(_on_spinbox_changed)

	min_val_label.text = str(param_def.min_value)
	max_val_label.text = str(param_def.max_value)
	
func _update_from_data() -> void:
	var val = get_data_value()

	if val == null:
		val = param_def.default_value

	spinbox.value = int(val)
	slider.value = int(val)

func _on_spinbox_changed(new_val: float) -> void:
	var int_val = int(round(new_val))
	spinbox.value = int_val
	slider.value = int_val
	_on_ui_changed(int_val)
