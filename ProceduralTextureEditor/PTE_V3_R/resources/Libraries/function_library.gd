class_name FunctionLibrary extends RefCounted

static var Functions: Dictionary = {
	"sphereGrid": preload("res://PTE_V3_R/FunctionLibraryFolder/sphereGrid.tres"),
	"cellTiling": preload("res://PTE_V3_R/FunctionLibraryFolder/cellTiling.tres"),
	"cfbm": preload("res://PTE_V3_R/FunctionLibraryFolder/cfbm.tres"),
	"fbm": preload("res://PTE_V3_R/FunctionLibraryFolder/fbm.tres"),
	"mod289_2d": preload("res://PTE_V3_R/FunctionLibraryFolder/mod289_2d.tres"),
	"mod289_3d": preload("res://PTE_V3_R/FunctionLibraryFolder/mod289_3d.tres"),
	"permute_3d": preload("res://PTE_V3_R/FunctionLibraryFolder/permute_3d.tres"),
	"snoise": preload("res://PTE_V3_R/FunctionLibraryFolder/snoise.tres"),
	"brand": preload("res://PTE_V3_R/FunctionLibraryFolder/brand.tres"),

}

static func get_function(name: StringName) -> FunctionData:
	return Functions.get(name)

static func get_all_names() -> PackedStringArray:
	var names = PackedStringArray()
	for key in Functions:
		names.append(key)
	return names
