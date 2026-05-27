# RandomNeuron.gd
class_name RandomNeuron extends Neuron

var uv: Vector2 = Vector2(0, 0)
var result: float
var refenence: float
var loss: float = 1000000000


var pixeles: int = 8

func _init():
	params = [
		1.,
		1.,
		1.,
		1.,
		]          # нет параметров
	intermediate_results = []
	epsilon = 0.0001
	
	result = random(uv)
	refenence = _random(uv)

'''
func _ready() -> void:
	print("\n Результат: ", tune())
'''


var depiction1:Image = Image.create_empty(pixeles, pixeles, false, Image.FORMAT_RGB8)
var depiction2:Image = Image.create_empty(pixeles, pixeles, false, Image.FORMAT_RGB8)
var depiction3:Image = Image.create_empty(pixeles, pixeles, false, Image.FORMAT_RGB8)

func _physics_process(delta: float) -> void:
	#print("Поиск рараметров для пикселя: ", uv)
	refenence = _random(uv)

	if abs(result-refenence) > epsilon:
		var l: float
		var r = randf()
		var back: Array = params
		if r > 0.75:
			params[0] += randf()-0.5
		elif r > 0.5:
			params[1] += randf()-0.5
		elif r > 0.25:
			params[2] += randf()-0.5
		else:
			params[3] += randf()-0.5
		
		result = random(uv)
	
		var ll: float = l
		l = abs(result-refenence)
		
		if l > ll + epsilon:
			params = back
		else:
			l = abs(result-refenence)
			if l < loss:
				loss = l
				print("Минимальное значение потерь: ", loss)
		
		var f = false
		if loss <= epsilon:
			for x in range(uv.x):
				if f:
					break
				for y in range(uv.y):
					if abs(_random(Vector2(x,y))-random(Vector2(x,y))) > epsilon*2:
						uv.x = 0
						uv.y = 0
						#print("\n Найдена критичная ошибка, начинаем с начала\n")
						result = random(uv)
						f = true
						break
			if !f:
				print("   Результат: ", params, "\n")
				print()
				if uv.x +1 > pixeles-1:
					uv.x = 0
					if uv.y +1 <= pixeles-1:
						uv.y += 1
					else:
						for i in range(pixeles):
							for j in range(pixeles):
								var n = random(Vector2(i, j))
								depiction3.set_pixel(i, j, Color(n, n, n))
						print("\nСохранено финальное изображение: ")
						$"ФинальныйРезультат".texture = ImageTexture.create_from_image(depiction3)
						get_tree().quit()
				else:
					uv.x += 1

				refenence = _random(uv)
				depiction2.set_pixel(int(uv.x), int(uv.y), Color(refenence, refenence, refenence))
				loss = 1000000000
			#get_tree().quit()
		#print("\n Результат: ", tune(t, _random(t)))
		
		depiction1.set_pixel(int(uv.x), int(uv.y), Color(result, result, result))
		
		$"Результат".texture = ImageTexture.create_from_image(depiction1)
		$"Эталон".texture = ImageTexture.create_from_image(depiction2)



func tune(...args: Array) -> Array:
	loss = abs(result-refenence)
	uv = Vector2(0, 0)
	refenence = _random(uv)
	result = random(uv)
	
	var i: int = 0
	var j: int = 1
	while i < pixeles:
		while j < pixeles:
			loss = 1000000000
			#print("Поиск рараметров для пикселя: ", uv)
			refenence = _random(uv)
			if j > 1:
				print(i, " ", j)
			depiction2.set_pixel(i, j, Color(refenence, refenence, refenence))

			while loss > epsilon:
				var l: float
				var r = randf()
				var back: Array = params
				if r > 0.75:
					params[0] += (randf()-0.5)/10
				elif r > 0.5:
					params[1] += (randf()-0.5)/10
				elif r > 0.25:
					params[2] += (randf()-0.5)/10
				else:
					params[3] += (randf()-0.5)/10
				
				result = random(Vector2(i, j))
				
				var ll: float = l
				l = abs(result-refenence)
				
				if l > ll + epsilon:
					params = back
					continue
				
				if l < loss:
					loss = l
					#print("Минимальное значение потерь: ", loss)

			var f = false
			for x in range(i+1):
				if f:
					break
				for y in range(j+1):
					if abs(_random(Vector2(x,y))-random(Vector2(x,y))) > epsilon:
						i = 0
						j = 0
						#print("\n Найдена критичная ошибка, начинаем с начала\n")
						f = true
						break
			if !f:
				#print("   Результат: ", params, "\n")
				#print()
				j += 1
		i += 1
	
	$"Эталон".texture = ImageTexture.create_from_image(depiction2)

	for x in range(pixeles):
		for y in range(pixeles):
			var n = random(Vector2(x, y))
			depiction3.set_pixel(x, y, Color(n, n, n))
	print("\nСохранено финальное изображение")
	$"Результат".texture = ImageTexture.create_from_image(depiction3)

	return params

func fract_1(f: float)->float:
	return f+0


func execute(...args: Array) -> Array:
	var input = args[0] as Array   # ожидается Array[Array[Vector2]]
	var height = input.size()
	var width = input[0].size() if height > 0 else 0
	intermediate_results.clear()
	intermediate_results.resize(height)

	for y in range(height):
		var row = []
		row.resize(width)
		for x in range(width):
			var st = input[y][x] as Vector2
			row[x] = _random(st)
		intermediate_results[y] = row

	return intermediate_results


func random(st: Vector2) -> float:
	var p3 = Vector3(st.x, st.y, st.x) * params[0]
	p3 = Vector3(fract(p3.x), fract(p3.y), fract(p3.z))
	
	var yzx_plus = Vector3(p3.y, p3.z, p3.x) + Vector3(params[1], params[2], params[3])
	var dot_val = p3.dot(yzx_plus)
	
	p3 += Vector3(dot_val, dot_val, dot_val)
	return fract((p3.x + p3.y) * p3.z)
