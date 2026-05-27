class_name BumpLayerData extends AbstractLayerData

# Prevent changing blend_mode in the inspector
func _validate_property(property: Dictionary) -> void:
	if property.name == "blend_mode":
		property.usage = PROPERTY_USAGE_READ_ONLY

# Force the correct blend mode when the object is created
func _init() -> void:
	blend_mode = BlendMode.NORMAL_MAP_BLEND

@export var height_scale: float = 1.0
