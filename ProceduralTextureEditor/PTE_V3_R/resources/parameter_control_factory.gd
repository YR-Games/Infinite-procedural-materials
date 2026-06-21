class_name ParameterControlFactory

static var float_slider_scene = preload(
"res://PTE_V3_R/UI/float_parameter_slider_ui.tscn"
)
static var float_spinbox_scene = preload(
"res://PTE_V3_R/UI/float_parameter_spinbox_ui.tscn"
)

static var int_slider_scene = preload(
"res://PTE_V3_R/UI/int_parameter_ui.tscn"
)

static var int_spinbox_scene = preload(
"res://PTE_V3_R/UI/int_parameter_ui.tscn"
)

static var palette_scene = preload(
"res://PTE_V3_R/UI/palette_parameter_ui.tscn"
)

static func create(def) -> ParameterControl:

	if def is floatParameterDef:

		match def.editor_type:

			floatParameterDef.EditorType.SLIDER:
				return float_slider_scene.instantiate()

			floatParameterDef.EditorType.SPINBOX:
				return float_spinbox_scene.instantiate()

	if def is intParameterDef:

		match def.editor_type:

			intParameterDef.EditorType.SLIDER:
				return int_slider_scene.instantiate()

			intParameterDef.EditorType.SPINBOX:
				return int_spinbox_scene.instantiate()

	if def is PaletteParameterDef:
		return palette_scene.instantiate()

	return null
