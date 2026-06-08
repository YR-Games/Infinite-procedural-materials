class_name GeneratorLibrary extends RefCounted

#Подгружать ресурсы через preload .tres
#хранить через store var, load var. спросить нейронку про сейв лоад словаря
static var Generators:Dictionary = {
	"CellNoise":preload("res://PTE_V3_R/GeneratorDataFolder/CellNoiseData.tres")
}


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
