class_name ModifierLibrary extends RefCounted

static var Modifiers := {
	&"ColorRamp":preload("res://PTE_V3_R/ModifierDataFolder/ColorRampData.tres")
}


static func get_modifier_data(name:StringName) -> ModifierData:
	return Modifiers.get(name)
	
static func get_all_names() -> PackedStringArray:

	var result := PackedStringArray()

	for name in Modifiers.keys():
		result.append(name)

	return result
