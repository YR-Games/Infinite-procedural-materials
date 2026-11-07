extends Node #BF

const MAX_DEPTH := 5       # максимум слоёв в одной комбинации
const MAX_TRYS := 1000     # предохранитель от бесконечного перебора
const TARGET_CHANNEL := &"albedo"   # канал, в который кладутся слои комбинации

var all_generators: PackedStringArray = GeneratorLibrary.get_all_names()
var in_process: bool = false
var step: int = 0

var _indices: PackedInt32Array = PackedInt32Array([0])   # индексы генераторов по слоям
var _exhausted: bool = false


func start() -> bool:
	if not in_process:
		AlertWindow.alert("Начат перебор материалов!", false)
		in_process = true
		return true
	AlertWindow.alert("Перебор материалов остановлен!\nДождитесь окончания индексации.", false)
	in_process = false
	return false


func _physics_process(_delta: float) -> void:
	if not (in_process and GConnector.material_adding_finished):
		return

	# Условия остановки
	if step >= MAX_TRYS:
		_finish("Сборка закончена: достигнут предел попыток!")
		return
	if _exhausted:
		_finish("Сборка закончена: перебраны все комбинации!")
		return

	# 1) Применяем текущую комбинацию
	_apply_combination()

	# 2) Отправляем материал на сборку
	GConnector.add_material(EditorMaterial.get_material_json_string())
	step += 1

	# 3) Готовим следующую комбинацию (одометр)
	_advance_combination()


func _finish(message: String) -> void:
	in_process = false
	AlertWindow.alert(message, false)


# ---------- перебор комбинаций ----------

## Собирает материал текущей комбинации и заменяет им проект.
## Ни от каких UI-нодов не зависит: интерфейс сам обновится по сигналам.
func _apply_combination() -> void:
	var builder := MaterialBuilder.new()
	for gen_index in _indices:
		builder.generator_layer(TARGET_CHANNEL, StringName(all_generators[gen_index]))
	builder.apply(true)


## Инкремент «одометра» комбинаций:
##   [0] → [1] → … → [N-1] → [0,0] → [0,1] → … → [N-1,N-1] → [0,0,0] → …
## Когда всё исчерпано до MAX_DEPTH, выставляет _exhausted.
func _advance_combination() -> void:
	var i := _indices.size() - 1
	while i >= 0:
		_indices[i] += 1
		if _indices[i] < all_generators.size():
			return
		_indices[i] = 0
		i -= 1

	# Все комбинации текущей глубины исчерпаны — увеличиваем глубину
	if _indices.size() >= MAX_DEPTH:
		_exhausted = true
		return
	_indices.append(0)
