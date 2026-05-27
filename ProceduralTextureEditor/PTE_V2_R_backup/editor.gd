extends Control

@onready var layer_list: VBoxContainer = $HSplit/Left/VBox/LayerList/ScrollContainer/LayerContainer
@onready var final_preview: ColorRect = $HSplit/Right/Panel/PreviewRect
@onready var add_button = $HSplit/Left/VBox/AddButton
@onready var show_code_button = $HSplit/Left/VBox/ShowCodeButton
@onready var code_popup = $CodePopup
@onready var code_popup_text = $CodePopup/Panel/CodeText
@onready var save_button = $HSplit/Left/VBox/HBoxContainer/SaveButton
@onready var load_button = $HSplit/Left/VBox/HBoxContainer/LoadButton
@onready var load_dialog = $LoadDialog
@onready var save_dialog = $SaveFileDialog


var layers: Array[LayerData] = []

func _ready():
	add_button.pressed.connect(add_layer)
	show_code_button.pressed.connect(_show_code_popup)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	

	#save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	#save_dialog.access = FileDialog.ACCESS_USERDATA
	save_dialog.add_filter("*.json", "Shader Project")
	save_dialog.file_selected.connect(_on_save_file_selected)
	
	if load_dialog:
		load_dialog.project_selected.connect(_on_project_selected_to_load)
	
	add_layer()

func add_layer():
	var layer = LayerData.new()
	layers.append(layer)    # visual order: top (index 0) → bottom (last index)
	var layer_ctrl = load("res://PTE_V2_R/layer.tscn").instantiate()
	layer_ctrl.layer_data = layer
	layer_ctrl.modified.connect(_on_layer_modified)
	layer_list.add_child(layer_ctrl)
	_rebuild_all()
	
	layer_ctrl.move_up_requested.connect(_on_move_up.bind(layer_ctrl))
	layer_ctrl.move_down_requested.connect(_on_move_down.bind(layer_ctrl))
	
func _on_layer_modified():
	_rebuild_all()

func _rebuild_all():
	# --- Final composite preview ---
	var shader_code = ShaderBuilder.build(layers)
	var final_shader = Shader.new()
	final_shader.code = shader_code
	_ensure_shader_material(final_preview)
	final_preview.material.shader = final_shader

	# --- Per‑layer previews ---
	var children = layer_list.get_children()
	for i in children.size():
		var layer_ctrl = children[i]
		var layer_data = layer_ctrl.layer_data
		if layer_data and layer_data.active:
			var partial_code = ShaderBuilder.build(layers.slice(0, i+1))
			var partial_shader = Shader.new()
			partial_shader.code = partial_code
			_ensure_shader_material(layer_ctrl.preview_rect)
			layer_ctrl.preview_rect.material.shader = partial_shader
		else:
			if layer_ctrl.preview_rect.material:
				layer_ctrl.preview_rect.material.shader = null

	if code_popup and code_popup.visible:
		code_popup_text.text = shader_code

func _ensure_shader_material(rect: ColorRect):
	if not rect.material or not rect.material is ShaderMaterial:
		rect.material = ShaderMaterial.new()

# --- Reorder handlers ---
func _on_move_up(layer_ctrl: Control):
	var idx = layer_list.get_children().find(layer_ctrl)
	if idx <= 0:
		return

	# Swap layers array elements manually
	var tmp = layers[idx]
	layers[idx] = layers[idx - 1]
	layers[idx - 1] = tmp

	# Move the node in the container
	layer_list.move_child(layer_ctrl, idx - 1)
	_rebuild_all()

func _on_move_down(layer_ctrl: Control):
	var child_count = layer_list.get_child_count()
	var idx = layer_list.get_children().find(layer_ctrl)
	if idx < 0 or idx >= child_count - 1:
		return

	# Manual swap
	var tmp = layers[idx]
	layers[idx] = layers[idx + 1]
	layers[idx + 1] = tmp

	layer_list.move_child(layer_ctrl, idx + 1)
	_rebuild_all()

func _on_save_pressed():
	save_dialog.popup_centered_ratio(0.6)

func _on_save_file_selected(path: String):
	# Ignore the user's chosen path - always save to user://saved_shaders/
	# This ensures the load dialog can find the projects
	var project_name = path.get_file().trim_suffix(".json")
	
	# Use SaveManager to save to the standard location
	SaveManager.save_project(layers, final_preview, project_name)
	print("Saved project: ", project_name)


func _on_load_pressed():
	if load_dialog:
		load_dialog.refresh_projects()  # Refresh the list before showing
		load_dialog.popup_centered_ratio(0.6)

func _on_project_selected_to_load(project_name: String):
	# Load the project using SaveManager
	var loaded_layers = SaveManager.load_project(project_name)
	
	if loaded_layers.is_empty():
		print("No layers found in project: ", project_name)
		return
	
	# Clear existing layers
	_clear_all_layers()
	
	# Add loaded layers
	for layer_data in loaded_layers:
		_add_layer_from_data(layer_data)
	
	# Rebuild the shader
	_rebuild_all()
	print("Loaded project: ", project_name)

func _clear_all_layers():
	for child in layer_list.get_children():
		child.queue_free()
	layers.clear()

func _add_layer_from_data(layer_data: LayerData):
	layers.append(layer_data)
	var layer_ctrl = load("res://PTE_V2_R/layer.tscn").instantiate()
	layer_ctrl.layer_data = layer_data
	layer_ctrl.modified.connect(_on_layer_modified)
	layer_list.add_child(layer_ctrl)
	layer_ctrl.move_up_requested.connect(_on_move_up.bind(layer_ctrl))
	layer_ctrl.move_down_requested.connect(_on_move_down.bind(layer_ctrl))

func _save_thumbnail(path: String):
	# Wait for the shader to render
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	
	var viewport = final_preview.get_viewport()
	var texture = viewport.get_texture()
	
	if texture:
		var img = texture.get_image()
		var rect = final_preview.get_global_rect()
		
		# Adjust for viewport scaling if needed
		var viewport_size = Vector2(viewport.size)  # Convert Vector2i to Vector2
		var scale_factor = viewport.get_visible_rect().size / viewport_size if viewport_size != Vector2.ZERO else Vector2.ONE
		rect.position *= scale_factor
		rect.size *= scale_factor
		
		# Ensure coordinates are within image bounds
		var img_size = Vector2(img.get_size())
		rect.position.x = clampi(rect.position.x, 0, img_size.x)
		rect.position.y = clampi(rect.position.y, 0, img_size.y)
		rect.size.x = mini(rect.size.x, img_size.x - rect.position.x)
		rect.size.y = mini(rect.size.y, img_size.y - rect.position.y)
		
		if rect.size.x > 0 and rect.size.y > 0:
			var cropped = img.get_region(Rect2i(rect.position, rect.size))
			cropped.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			cropped.save_png(path)
			print("Thumbnail saved: ", path)

func _show_code_popup():
	code_popup.popup_centered_ratio(0.7)
	code_popup_text.text = ShaderBuilder.build(layers)
