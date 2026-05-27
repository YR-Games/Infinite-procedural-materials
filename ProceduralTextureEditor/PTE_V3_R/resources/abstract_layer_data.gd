class_name AbstractLayerData extends Resource

enum BlendMode {
	NORMAL,
	MULTIPLY,
	SCREEN,
	OVERLAY,
	NORMAL_MAP_BLEND
}

@export var enabled: bool = true
@export_range(0.0, 1.0) var opacity: float = 1.0
@export var blend_mode: BlendMode = BlendMode.NORMAL
