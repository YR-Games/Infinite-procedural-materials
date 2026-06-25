extends Window

@onready var path_to_reference: LineEdit = $VBoxContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var fd_open_button: Button = $VBoxContainer/VBoxContainer/HBoxContainer/Button
@onready var file_dialog: FileDialog = $VBoxContainer/VBoxContainer/HBoxContainer/Button/FileDialog
@onready var reference_miniature: TextureRect = $VBoxContainer/VBoxContainer/HBoxContainer/TextureRect
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var finded_materials_block: VBoxContainer = $VBoxContainer/FindedMaterials
@onready var materials_container: VBoxContainer = $VBoxContainer/FindedMaterials/ScrollContainer/Materials


var reference_path: String
var reference

func _ready() -> void:
	finded_materials_block.hide()
	progress_bar.hide()

func _on_close_requested() -> void:
	hide()


func _on_button_pressed() -> void:
	if reference:#??? для тестов
		GConnector.send_current_material()
		reference = false
	else:
		GConnector.request_find_material(Image.load_from_file("res://textures/cgt1.jpg"))
		reference = true
	file_dialog.show()


func _on_file_dialog_file_selected(path: String) -> void:
	set_path(path)

func _on_line_edit_text_changed(new_text: String) -> void:
	set_path(new_text)

func set_path(path: String)->void:
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			reference_path = path
			path_to_reference.text = path
			reference_miniature.texture = ImageTexture.create_from_image(img)
