class_name MixLibrary extends RefCounted

static var MixModes: Dictionary = {
	"normal": preload("res://PTE_V3_R/MixModeDataFolder/normal_blend.tres"),
	"multiply": preload("res://PTE_V3_R/MixModeDataFolder/multiply_blend.tres"),
	#"screen": preload("res://BlendModes/screen_blend.tres"),
	#"overlay": preload("res://BlendModes/overlay_blend.tres"),
	#"normal_map_blend": preload("res://BlendModes/normal_map_blend.tres")
}

static func get_blend_mode(name: StringName) -> MixModeData:
	return MixModes.get(name)

static func get_all_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for key in MixModes:
		names.append(key)
	return names
