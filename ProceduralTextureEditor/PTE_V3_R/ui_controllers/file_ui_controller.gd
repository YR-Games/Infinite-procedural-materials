extends PopupMenu

@onready var file_popup_menu: PopupMenu = self

@onready var open_project_dialog: FileDialog = $"../OpenProjectDialog"
@onready var save_project_dialog: FileDialog = $"../SaveProjectDialog"
@onready var export_dialog: FileDialog = $"../ExportDialog"


func _ready() -> void:

	#open_project_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	#save_project_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE

	open_project_dialog.filters = PackedStringArray(["*.pte ; Procedural Texture Editor Project"])

	save_project_dialog.filters = PackedStringArray(["*.pte ; Procedural Texture Editor Project"])

	export_dialog.filters = PackedStringArray(["*.gdshader ; Godot Shader"])

	file_popup_menu.id_pressed.connect(_on_file_menu_id_pressed)

	open_project_dialog.file_selected.connect(_on_open_project_selected)

	save_project_dialog.file_selected.connect(_on_save_project_selected)

	export_dialog.file_selected.connect(_on_export_file_selected)


func _on_file_menu_id_pressed(id: int) -> void:

	match id:
		0:
			_new_project()
		1:
			open_project_dialog.popup_centered()
		2:
			save_project_dialog.popup_centered()
		3:
			export_dialog.popup_centered()
			
func _new_project() -> void:

	EditorMaterial.clear_project()
	
func _on_save_project_selected(path:String) -> void:

	if not path.ends_with(".pte"):
		path += ".pte"

	EditorMaterial.save_project(path)
	
func _on_open_project_selected(path:String) -> void:

	EditorMaterial.load_project(path)
	
func _on_export_file_selected(path: String) -> void:

	var generator = MaterialCodeGenerator.new()
	var shader_code = generator.generate_shader_code()

	var file = FileAccess.open(path, FileAccess.WRITE)

	if not file:
		push_error("Cannot open file for writing: " + path)
		return

	file.store_string(shader_code)
	file.close()

	print("Shader exported to ", path)
