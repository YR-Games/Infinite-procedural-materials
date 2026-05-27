extends Node

# Функция для получения векторов a, b, c, d, e и frequency из изображения
func extract_palette_vectors(input_image: Image) -> Dictionary:
	var unique_colors = {}
	
	# Считываем пиксели и добавляем уникальные цвета
	for y in range(input_image.get_height()):
		for x in range(input_image.get_width()):
			var color = input_image.get_pixel(x, y)
			unique_colors[color] = true

	# Преобразуем уникальные цвета в массив
	var colors_array = unique_colors.keys()
	
	# Если меньше 5 уникальных цветов, возвращаем нулевые векторы
	if colors_array.size() < 5:
		return {"a": Vector3(0, 0, 0), "b": Vector3(0, 0, 0), "c": Vector3(0, 0, 0), "d": Vector3(0, 0, 0), "e": Vector3(0, 0, 0), "frequency": 1.0}

	# Вычисляем базовый цвет (средний цвет)
	var total_color = Vector3(0, 0, 0)
	for color in colors_array:
		total_color += Vector3(color.r, color.g, color.b)
	var a = total_color / colors_array.size()

	# Инициализируем минимальный и максимальный цвета
	var min_color = Vector3(1, 1, 1)
	var max_color = Vector3(0, 0, 0)
	
	for color in colors_array:
		var vec_color = Vector3(color.r, color.g, color.b)
		min_color.x = min(min_color.x, vec_color.x)
		min_color.y = min(min_color.y, vec_color.y)
		min_color.z = min(min_color.z, vec_color.z)
		
		max_color.x = max(max_color.x, vec_color.x)
		max_color.y = max(max_color.y, vec_color.y)
		max_color.z = max(max_color.z, vec_color.z)

	var b = max_color - min_color  # Амплитуда

	# Используем количество уникальных цветов для c
	var c = Vector3(colors_array.size() / 10.0, colors_array.size() / 10.0, colors_array.size() / 10.0)

	# Используем первый уникальный цвет для d
	var d = Vector3(colors_array[0].r, colors_array[0].g, colors_array[0].b)

	# Используем второй уникальный цвет для e
	var e = Vector3(colors_array[1].r, colors_array[1].g, colors_array[1].b)

	# Устанавливаем частоту
	var frequency = 3.0  # Настройте частоту по вашему усмотрению

	# Возвращаем векторы в словаре
	return {"a": a, "b": b, "c": c, "d": d, "e": e, "frequency": frequency}

# Пример использования
func _ready():
	var img = load("res://GrassRostok.jpg") # Замените на путь к вашему изображению

	# Проверяем, удалось ли загрузить изображение
	if img is Image:
		var palette_vectors = extract_palette_vectors(img)
		

		print("Цвет палитры:", palette_vectors)
	else:
		print("Не удалось загрузить изображение.")
