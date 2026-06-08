class_name ParameterControlFactory
extends RefCounted

## Creates a UI control (HBoxContainer with label + input) for the given parameter definition.
## Returns null if the parameter type is unsupported.
static func create_control(param_def: abstract_parameter_def, param_name: String) -> Control:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = param_def.display_name if not param_def.display_name.is_empty() else param_name.capitalize()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var type_name = param_def.get_script().get_global_name()
	match type_name:
		"float_parameter_def", "int_parameter_def":
			var slider = HSlider.new()
			slider.min_value = param_def.min_value
			slider.max_value = param_def.max_value
			slider.step = param_def.step
			slider.value = float(param_def.default_value)
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(slider)
			return hbox

		"color_parameter_def":
			var picker = ColorPickerButton.new()
			picker.color = param_def.default_value
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(picker)
			return hbox

		"bool_parameter_def":
			var check = CheckBox.new()
			check.button_pressed = bool(param_def.default_value)
			hbox.add_child(check)
			return hbox

		"vector2_parameter_def":
			var vbox = VBoxContainer.new()
			var xspin = SpinBox.new()
			var yspin = SpinBox.new()
			xspin.min_value = param_def.min_value
			xspin.max_value = param_def.max_value
			yspin.min_value = param_def.min_value
			yspin.max_value = param_def.max_value
			xspin.value = param_def.default_value.x
			yspin.value = param_def.default_value.y
			vbox.add_child(xspin)
			vbox.add_child(yspin)
			hbox.add_child(vbox)
			return hbox

		"vector3_parameter_def":
			var vbox = VBoxContainer.new()
			var xspin = SpinBox.new()
			var yspin = SpinBox.new()
			var zspin = SpinBox.new()
			xspin.min_value = param_def.min_value
			xspin.max_value = param_def.max_value
			yspin.min_value = param_def.min_value
			yspin.max_value = param_def.max_value
			zspin.min_value = param_def.min_value
			zspin.max_value = param_def.max_value
			xspin.value = param_def.default_value.x
			yspin.value = param_def.default_value.y
			zspin.value = param_def.default_value.z
			vbox.add_child(xspin)
			vbox.add_child(yspin)
			vbox.add_child(zspin)
			hbox.add_child(vbox)
			return hbox

	return null
