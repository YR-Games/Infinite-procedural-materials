# load_dialog.gd
extends Window

signal project_selected(project_name: String)

@onready var project_grid = $VBoxContainer/ScrollContainer/ProjectGrid
@onready var cancel_btn = $VBoxContainer/buttonsContainer/Button
@onready var load_btn = $VBoxContainer/buttonsContainer/Button2

var selected_project: String = ""
var thumbnail_button_scene = preload("res://PTE_V2_R/project_thumbnail.tscn")

func _ready():
	
	cancel_btn.pressed.connect(_on_cancel)
	load_btn.pressed.connect(_on_load)
	close_requested.connect(_on_cancel)
	
	refresh_projects()

func refresh_projects():
	# Clear existing items

	for child in project_grid.get_children():
		child.queue_free()
	
	# Populate with saved projects
	var projects = SaveManager.get_saved_projects()

	if projects.is_empty():

		var label = Label.new()
		label.text = "No saved projects found"
		project_grid.add_child(label)
		return

	for project in projects:
		print("DEBUG: Creating thumbnail for: ", project["name"])
		var thumb = thumbnail_button_scene.instantiate()
		
		# Set data BEFORE adding to tree so _ready can use it
		thumb.project_data = project
		
		# Now add to tree - this triggers _ready
		project_grid.add_child(thumb)
		
		# Connect signal
		thumb.selected.connect(_on_project_selected)
		
		print("DEBUG: Thumbnail added for: ", project["name"])

func _on_project_selected(project_name: String):
	selected_project = project_name
	
	# Deselect others
	for child in project_grid.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child.project_name == project_name)

func _on_load():
	if selected_project != "":
		project_selected.emit(selected_project)
		hide()

func _on_cancel():
	hide()
