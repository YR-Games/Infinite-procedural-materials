# ColorizeNeuron.gd
class_name ColorizeNeuron extends Neuron

func _init():
	# Начальные значения из шейдера
	params = [
		Vector3(0.5, 0.5, 0.5),   # a
		Vector3(0.5, 0.5, 0.5),   # b
		Vector3(1.0, 1.0, 1.0),   # c
		Vector3(0.0, 0.33, 0.67)  # d
	]
	intermediate_results = []


func loss(mat1, mat2) -> float:
	var sum = 0.0
	for y in range(mat1.size()):
		for x in range(mat1[y].size()):
			var diff = mat1[y][x] - mat2[y][x]
			sum += diff.dot(diff)
	return sum / (mat1.size() * mat1[0].size())   # simpler count

func execute(...args: Array) -> Array:
	var input = args[0] as Array   # Array[Array[float]]
	var height = input.size()
	var width = input[0].size() if height > 0 else 0
	intermediate_results.clear()
	intermediate_results.resize(height)

	var a = params[0] as Vector3
	var b = params[1] as Vector3
	var c = params[2] as Vector3
	var d = params[3] as Vector3

	for y in range(height):
		var row = []
		row.resize(width)
		for x in range(width):
			var t = input[y][x] as float
			row[x] = _colorize(t, a, b, c, d)
		intermediate_results[y] = row

	return intermediate_results

func tune(...args: Array) -> Array:
	var target = args[0] as Array
	var input_t = args[1] as Array
	var lr = args[2] if args.size() > 2 else 0.01
	var eps = args[3] if args.size() > 3 else 0.001

	# Вычисляем текущий результат с текущими параметрами
	var current = execute([input_t])

	# Функция потерь (MSE) 

	var original_loss = loss(current, target)
	var gradients = []
	gradients.resize(params.size())

	# Численное дифференцирование для каждого параметра (вектора)
	for i in range(params.size()):
		var param = params[i] as Vector3
		var grad_vec = Vector3()

		for comp in range(3):
			var old = param[comp]
			param[comp] = old + eps
			params[i] = param
			var new_current = execute([input_t])
			var new_loss = loss(new_current, target)
			grad_vec[comp] = (new_loss - original_loss) / eps
			param[comp] = old   # восстанавливаем

		params[i] = param
		gradients[i] = grad_vec

	# Обновление параметров
	for i in range(params.size()):
		params[i] = params[i] - lr * gradients[i]

	# Пересчитываем результат с обновлёнными параметрами
	execute([input_t])
	return params
