class_name ProjectGeneratorPicker
extends PopupPanel

signal generator_selected(generator_name: StringName)

@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/CancelButton


func _ready() -> void:
	cancel_button.pressed.connect(_on_cancel)
	popup_hide.connect(queue_free)
	_fill_grid()


func _fill_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	
	var item_scene = preload("res://PTE_V3_R/UI/generator_picker_item.tscn")
	for gen_name in GeneratorLibrary.get_all_names():
		var item = item_scene.instantiate() as GeneratorPickerItem
		item.generator_name = gen_name
		item.selected.connect(_on_item_selected)
		grid_container.add_child(item)


func _on_item_selected(gen_name: StringName) -> void:
	generator_selected.emit(gen_name)
	hide()


func _on_cancel() -> void:
	hide()
