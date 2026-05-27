# save_manager.gd (add as autoload in Project Settings)
extends Node

const SAVE_DIR = "user://saved_shaders/"
const THUMBNAIL_SIZE = 128

func _ready():
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

# Save a shader project with thumbnail
func save_project(layers: Array[LayerData], preview_rect: Control, project_name: String = "") -> bool:
	if project_name == "":
		project_name = "shader_%d" % Time.get_unix_time_from_system()
	
	var save_path = SAVE_DIR + project_name + ".json"
	var thumbnail_path = SAVE_DIR + project_name + ".png"
	
	# Save thumbnail
	var img = await _capture_thumbnail(preview_rect)
	if img:
		img.save_png(thumbnail_path)
	
	# Save layer data
	var data = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"layers": _serialize_layers(layers)
	}
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		return true
	
	return false

# In save_manager.gd, add this method to save to a custom path:
func save_to_custom_path(layers: Array[LayerData], json_path: String, thumbnail_image: Image = null) -> bool:
	var data = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"layers": _serialize_layers(layers)
	}
	
	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		
		# Save thumbnail if provided
		if thumbnail_image:
			var thumbnail_path = json_path.trim_suffix(".json") + ".png"
			thumbnail_image.save_png(thumbnail_path)
		
		return true
	
	return false

# Load a shader project
func load_project(project_name: String) -> Array:
	var load_path = SAVE_DIR + project_name + ".json"
	
	if not FileAccess.file_exists(load_path):
		return []
	
	var file = FileAccess.open(load_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			return _deserialize_layers(json.data)
	
	return []

# Get all saved projects with thumbnails
func get_saved_projects() -> Array:
	var projects = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".json"):
				var project_name = file_name.trim_suffix(".json")
				var thumbnail_path = SAVE_DIR + project_name + ".png"
				var json_path = SAVE_DIR + file_name
				
				var info = {
					"name": project_name,
					"has_thumbnail": FileAccess.file_exists(thumbnail_path),
					"thumbnail_path": thumbnail_path,
					"json_path": json_path,
					"timestamp": 0,
					"layer_count": 0
				}
				
				# Read metadata
				var file = FileAccess.open(json_path, FileAccess.READ)
				if file:
					var json = JSON.new()
					if json.parse(file.get_as_text()) == OK:
						info["timestamp"] = json.data.get("timestamp", 0)
						info["layer_count"] = json.data.get("layers", []).size()
					file.close()
				
				projects.append(info)
			
			file_name = dir.get_next()
	
	# Sort by timestamp (newest first)
	projects.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	return projects

# Delete a saved project
func delete_project(project_name: String) -> bool:
	var json_path = SAVE_DIR + project_name + ".json"
	var thumbnail_path = SAVE_DIR + project_name + ".png"
	
	var success = true
	if FileAccess.file_exists(json_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			success = success and dir.remove(project_name + ".json")
			if FileAccess.file_exists(thumbnail_path):
				success = success and dir.remove(project_name + ".png")
	
	return success

# Serialize layers to dictionary
func _serialize_layers(layers: Array[LayerData]) -> Array:
	var serialized = []
	for layer in layers:
		var layer_dict = {
			"name": layer.layer_name,
			"active": layer.active,
			"mix_mode": layer.mix_mode,
			"func_id": layer.func_id,
			"opacity": layer.opacity,
			"func_params": _serialize_params(layer.func_params)
		}
		serialized.append(layer_dict)
	return serialized

# Serialize function parameters (handle Color objects)
func _serialize_params(params: Dictionary) -> Dictionary:
	var result = {}
	for key in params:
		var value = params[key]
		if value is Color:
			result[key] = {
				"type": "Color",
				"r": value.r,
				"g": value.g,
				"b": value.b,
				"a": value.a
			}
		else:
			result[key] = value
	return result

# Deserialize layers from dictionary
func _deserialize_layers(data: Dictionary) -> Array:
	var layers = []
	if not data.has("layers"):
		return layers
	
	for layer_dict in data["layers"]:
		var layer = LayerData.new()
		layer.layer_name = layer_dict.get("name", "Layer")
		layer.active = layer_dict.get("active", true)
		layer.mix_mode = layer_dict.get("mix_mode", MixDB.MixId.NORMAL)
		layer.func_id = layer_dict.get("func_id", FuncDB.FuncId.SOLIDCOLOR)
		layer.opacity = layer_dict.get("opacity", 1.0)
		layer.func_params = _deserialize_params(layer_dict.get("func_params", {}))
		layers.append(layer)
	
	return layers

# Deserialize function parameters
func _deserialize_params(params: Dictionary) -> Dictionary:
	var result = {}
	for key in params:
		var value = params[key]
		if typeof(value) == TYPE_DICTIONARY and value.has("type") and value["type"] == "Color":
			result[key] = Color(value["r"], value["g"], value["b"], value["a"])
		else:
			result[key] = value
	return result

# Capture thumbnail from preview
func _capture_thumbnail(preview_rect: Control) -> Image:
	# Wait for rendering
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	
	# Get the viewport texture and capture the preview area
	var viewport = preview_rect.get_viewport()
	var texture = viewport.get_texture()
	
	if texture:
		var img = texture.get_image()
		var rect = preview_rect.get_global_rect()
		
		# Adjust for viewport scaling
		var scale_factor = viewport.size / viewport.get_visible_rect().size
		rect.position *= scale_factor
		rect.size *= scale_factor
		
		# Crop to preview area
		var cropped = img.get_region(Rect2i(rect.position, rect.size))
		
		# Resize to thumbnail
		cropped.resize(THUMBNAIL_SIZE, THUMBNAIL_SIZE, Image.INTERPOLATE_LANCZOS)
		return cropped
	
	return null
