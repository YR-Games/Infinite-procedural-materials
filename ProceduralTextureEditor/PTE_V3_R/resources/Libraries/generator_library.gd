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

static func get_generator_data(name: StringName) -> GeneratorData:
	return Generators.get(name)

static func get_all_names() -> PackedStringArray:
	var names = PackedStringArray()
	for key in Generators.keys():
		names.append(key)
	return names

#сгенерированные нейросетью шаблоны функций сохранения/загрузки
# Сохранить Generators в файл (например, user://generators.cfg)
static func save_to_file(path: String = "user://generators.cfg") -> void:
	var config = ConfigFile.new()
	for name in Generators:
		# Сохраняем путь к ресурсу .tres, а не сам ресурс
		config.set_value(name, "resource_path", Generators[name].resource_path)
	config.save(path)

# Загрузить обратно
static func load_from_file(path: String = "user://generators.cfg") -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	for name in config.get_sections():
		var res_path = config.get_value(name, "resource_path")
		if ResourceLoader.exists(res_path):
			Generators[name] = load(res_path)  # или preload, но load гибче
