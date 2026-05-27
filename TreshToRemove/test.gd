extends Node2D

var result: ImageTexture
var reference: ImageTexture


func _ready() -> void:
	result = $"Результат".texture
	reference = $"Эталон".texture


## Здесь будет основной цикл выполнения нейросети.
func _process(_delta: float) -> void:
	pass
