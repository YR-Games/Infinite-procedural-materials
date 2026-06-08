# modifier_ui_controller.gd
class_name ModifierUIController
extends HBoxContainer

var modifier_key: StringName  # например &"remap"
var params_container: VBoxContainer

func setup(modifier_dict: Dictionary, data_path: Array[StringName]) -> void:
	# modifier_dict - тот самый словарь модификатора из слоя
	modifier_key = modifier_dict.get("ключ функции", "")
	var param_defs = ModifierRegistry.get_parameter_defs(modifier_key)
	
	for param_name in param_defs:
		var def = param_defs[param_name]
		var control = _create_control_for_def(def, param_name)
		var full_path = data_path.duplicate()
		full_path.append("параметры")
		full_path.append(param_name)
		control.set_data_path(full_path)
		params_container.add_child(control)
