# project_thumbnail.gd
extends TextureButton

signal selected(project_name: String)

var project_name: String
var project_data: Dictionary

@onready var thumbnail = $VBoxContainer/Thumbnail
@onready var name_label = $VBoxContainer/ProjectName
@onready var info_label = $VBoxContainer/Info

func _ready():
	print("DEBUG: Thumbnail _ready() called")
	pressed.connect(_on_pressed)
	
	# If data was set before _ready, call setup now
	if project_data:
		print("DEBUG: Calling setup from _ready with data: ", project_data)
		setup(project_data)



func setup(data: Dictionary):
	project_data = data
	project_name = data["name"]
	
	if name_label:
		name_label.text = project_name
	
	if info_label:
		info_label.text = "%d layers" % data["layer_count"]
	
	# Load thumbnail
	if data["has_thumbnail"]:
		var img = Image.load_from_file(data["thumbnail_path"])
		if img:
			var tex = ImageTexture.create_from_image(img)
			texture_normal = tex  # For TextureButton
	else:
		var img = Image.create(128, 128, false, Image.FORMAT_RGB8)
		img.fill(Color(0.2, 0.2, 0.2))
		var tex = ImageTexture.create_from_image(img)
		texture_normal = tex  # For TextureButton

func _on_pressed():
	print("DEBUG: Thumbnail pressed for project: ", project_name)
	selected.emit(project_name)

func set_selected(value: bool):
	if value:
		modulate = Color(0.7, 0.7, 1.0, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
