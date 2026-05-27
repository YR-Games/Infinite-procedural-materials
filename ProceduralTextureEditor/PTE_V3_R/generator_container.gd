# Container script
extends VBoxContainer

var panels: Array[Generator] = []
var current: Generator = null

func _ready():
	for child in get_children():
		if child is Generator:
			panels.append(child)
			child.gui_input.connect(_on_panel_gui_input.bind(child))

func _on_panel_gui_input(event: InputEvent, panel: Generator):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select(panel)

func select(panel: Generator):
	if current == panel: return
	if current: current.set_selected(false)
	current = panel
	if current: current.set_selected(true)

func _unhandled_input(event):
	if event.is_action_pressed("ui_text_delete") and current:
		_remove_panel(current)

func _remove_panel(panel: Generator):
	if current == panel:
		current = null
	panel.queue_free()
	panels.erase(panel)
