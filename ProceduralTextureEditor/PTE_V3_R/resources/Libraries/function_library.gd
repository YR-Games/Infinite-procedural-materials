# FunctionLibrary.gd
class_name FunctionLibrary extends RefCounted

static var Functions: Dictionary = _load_all_from_folder("res://PTE_V3_R/FunctionLibraryFolder/")

static func _load_all_from_folder(folder_path: String) -> Dictionary:
	var result = {}
	var dir = DirAccess.open(folder_path)
	if not dir:
		push_error("Could not open folder: ", folder_path)
		return result

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext = file_name.get_extension().to_lower()
			if ext in ["tres", "res", "tscn", "scn"]:   # add other extensions if needed
				var full_path = folder_path.path_join(file_name)
				var resource = load(full_path)
				if resource:
					# Use the file name (without extension) as the dictionary key
					var key = file_name.get_basename()
					result[key] = resource
				else:
					push_warning("Failed to load: ", full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

static func get_function(name: StringName) -> FunctionData:
	return Functions.get(name)

static func get_all_names() -> PackedStringArray:
	var names = PackedStringArray()
	for key in Functions:
		names.append(key)
	return names
