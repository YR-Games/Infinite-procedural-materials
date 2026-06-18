class_name ParameterControlFactory

static var float_scene = preload(
"res://PTE_V3_R/UI/float_parameter_ui.tscn"
)

static var int_scene = preload(
"res://PTE_V3_R/UI/int_parameter_ui.tscn"
)

static var gradient_scene = preload(
"res://PTE_V3_R/UI/gradient_parameter_ui.tscn"
)

static func create(def) -> ParameterControl:

	if def is float_parameter_def:
		return float_scene.instantiate()

	if def is int_parameter_def:
		return int_scene.instantiate()
	if def is GradientParameterDef:
		return gradient_scene.instantiate()
	return null
