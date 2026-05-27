@abstract class_name Neuron extends Node

## Абстрактный суперкласс нейрона сети.
##
## Представляет собой одну функцию процедурноё текстуры (ПТ).

## Список ссылок на следующие нейроны.
#var next_neurons: Array[Neuron]

## Список параметров-весов функции-нейрона.
var params: Array

## Матрица промежуточных результатов по пикселям. Результаты выполнения этого нейрона.
var intermediate_results: Array[Array]

## 
var epsilon = 0.0001

static func fract(x: float) -> float:
	return x - int(x)

static func _random(st: Vector2) -> float:
	var p3 = Vector3(st.x, st.y, st.x) * 0.1031
	p3 = Vector3(fract(p3.x), fract(p3.y), fract(p3.z))
	
	var yzx_plus = Vector3(p3.y, p3.z, p3.x) + Vector3(33.33, 33.33, 33.33)
	var dot_val = p3.dot(yzx_plus)
	
	p3 += Vector3(dot_val, dot_val, dot_val)
	return fract((p3.x + p3.y) * p3.z)

static func _colorize(t: float, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> Vector3:
	var phase = c * t + d; return a + b * Vector3(cos(phase.x), cos(phase.y), cos(phase.z))

## Функция, выполняющая нейрон-функцию ПТ.
@abstract func execute(...args: Array) -> Array

## Функция исправления.
@abstract func tune(...args: Array) -> Array
