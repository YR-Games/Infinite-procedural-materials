extends Control


@onready var file_popup_menu: PopupMenu = $MenuAndUI/MenuTopBar/MarginContainer/HBoxContainer/MenuBar/File
@onready var export_dialog: FileDialog = $FileDialog

func _ready() -> void:
	file_popup_menu.id_pressed.connect(_on_file_menu_id_pressed)
	export_dialog.file_selected.connect(_on_export_file_selected)


func _on_file_menu_id_pressed(id: int) -> void:
	if id == 0:
		export_dialog.popup_centered()

func _on_export_file_selected(path: String) -> void:
	var generator = MaterialCodeGenerator.new()
	var shader_code = generator.generate_shader_code()
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Cannot open file for writing: ", path)
		return
	file.store_string(shader_code)
	file.close()
	# Optional: notify user
	print("Shader exported to ", path)
