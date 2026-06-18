# FunctionLibrary.gd
class_name FunctionLibrary extends RefCounted

static var Functions: Dictionary = {
	"sphereGrid": preload("res://PTE_V3_R/FunctionLibraryFolder/sphereGrid.tres"),
	"cellTiling": preload("res://PTE_V3_R/FunctionLibraryFolder/cellTiling.tres"),
	"cfbm": preload("res://PTE_V3_R/FunctionLibraryFolder/cfbm.tres"),
}

static func get_function(name: StringName) -> FunctionData:
	return Functions.get(name)

static func get_all_names() -> PackedStringArray:
	var names = PackedStringArray()
	for key in Functions:
		names.append(key)
	return names
