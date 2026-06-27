class_name MaterialListUIController
extends ScrollContainer

var counter: int = 0
@onready var materials_container: VBoxContainer = $Materials

# ---------------------- Добавление материала ----------------------

func add_material(material_data: String, similarity: float, new_f: bool) -> void:
	if new_f:
		counter = 0
	counter += 1

	var controller_scene = preload("res://PTE_V3_R/UI/material_ui.tscn")
	var controller: MaterialUIController = controller_scene.instantiate()
	materials_container.add_child(controller)
	controller.setup(material_data,similarity,counter)
