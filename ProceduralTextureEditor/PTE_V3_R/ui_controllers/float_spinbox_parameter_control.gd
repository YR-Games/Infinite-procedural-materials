class_name FloatSpinBoxParameterControl
extends ParameterControl

@onready var parameter_label: Label = $HBoxContainer/Label
@onready var spinbox: SpinBox = $HBoxContainer/SpinBox

var param_def: floatParameterDef


func setup(def: floatParameterDef, parameter_name: String) -> void:
	param_def = def
	parameter_label.text = parameter_name
	_setup_ui()
	_update_from_data()


func _setup_ui() -> void:
	spinbox.min_value = param_def.min_value
	spinbox.max_value = param_def.max_value
	spinbox.step = param_def.step
	spinbox.value_changed.connect(_on_spinbox_changed)
	

func _update_from_data() -> void:
	var val = get_data_value()

	if val == null:
		val = param_def.default_value

	spinbox.value = float(val)


func _on_spinbox_changed(new_val: float) -> void:
	_on_ui_changed(new_val)
