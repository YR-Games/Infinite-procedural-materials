class_name EditorSelectionManager extends Node

static var current:Object = null

func select(item) -> void:

	if current == item:
		return

	if current and current.has_method("set_selected"):
		current.set_selected(false)

	current = item

	if current and current.has_method("set_selected"):
		current.set_selected(true)
		
func delete_current() -> void:

	if current == null:
		return

	if current.has_method("delete_self"):
		current.delete_self()

	current = null

func _input(event):

	if event.is_action_pressed("ui_text_delete"):
		delete_current()
