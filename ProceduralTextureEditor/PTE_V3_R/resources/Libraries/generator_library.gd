class_name GeneratorLibrary extends RefCounted

#Подгружать ресурсы через preload .tres
#хранить через store var, load var. спросить нейронку про сейв лоад словаря
static var Generators:Dictionary = _load_all_from_folder("res://PTE_V3_R/GeneratorDataFolder/")

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
			if ext in ["tres", "res", "tscn", "scn"]:
				var full_path = folder_path.path_join(file_name)
				var resource = load(full_path)
				if resource:
					# Проверяем, что ресурс является GeneratorData
					if resource is GeneratorData:
						var key = resource.function_name
						# Если function_name пуст, используем имя файла как запасной вариант
						if key.is_empty():
							push_warning("GeneratorData resource has empty function_name: ", full_path)
							key = file_name.get_basename()
						# Предупреждение о дублирующихся ключах (последний загруженный перезапишет предыдущий)
						if result.has(key):
							push_warning("Duplicate function_name '%s' found in file %s, overwriting previous" % [key, full_path])
						result[key] = resource
					else:
						push_warning("Resource is not GeneratorData: ", full_path)
				else:
					push_warning("Failed to load: ", full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

static func get_generator_data(name: StringName) -> GeneratorData:
	return Generators.get(name)

static func get_all_names() -> PackedStringArray:
	var names = PackedStringArray()
	for key in Generators.keys():
		names.append(key)
	return names
