extends Button

@onready var window: Window = $Window

func _ready() -> void:
	window.hide()

func _on_pressed() -> void:
	window.show()
