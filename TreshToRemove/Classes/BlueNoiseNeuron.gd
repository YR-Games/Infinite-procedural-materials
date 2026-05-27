# BlueNoiseNeuron.gd
class_name BlueNoiseNeuron extends Neuron

func _init():
	params = []
	intermediate_results = []


func execute(...args: Array) -> Array:
	var input = args[0] as Array
	var height = input.size()
	var width = input[0].size() if height > 0 else 0
	intermediate_results.clear()
	intermediate_results.resize(height)

	for y in range(height):
		var row = []
		row.resize(width)
		for x in range(width):
			var st = input[y][x] as Vector2
			row[x] = _bn(st)
		intermediate_results[y] = row

	return intermediate_results

func tune(...args: Array) -> Array:
	return params

# Функция bn, использующая _random
static func _bn(st: Vector2) -> float:
	var i = Vector2(floor(st.x), floor(st.y))
	var f = Vector2(fract(st.x), fract(st.y))
	var u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0)

	var a = _random(i + Vector2(0.0, 0.0))
	var b = _random(i + Vector2(1.0, 0.0))
	var c = _random(i + Vector2(0.0, 1.0))
	var d = _random(i + Vector2(1.0, 1.0))

	var x = lerp(a, b, u.x)
	var y = lerp(c, d, u.x)
	return lerp(x, y, u.y)
