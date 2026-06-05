class_name MixLibrary extends RefCounted
"""
enum BlendMode {
	NORMAL,
	MULTIPLY,
	SCREEN,
	OVERLAY,
	NORMAL_MAP_BLEND
}
"""
#подумать как реализовывать сборку кода и чем должен быть mix()
static var MixModes:Dictionary = {
	"normal":"mix()"
	}
