class_name WSUtill
#??? Мёртв?

static var _ws := WebSocketPeer.new()
static var _url := "ws://127.0.0.1:8765"   # configurable
static var _shared_folder := "user://shared/"   # should be an absolute system path in production
static var _request_counter := 0


static func on_material_request_received(parameters: Dictionary, request_id: String):
	# Apply parameters to EditorMaterial
	for path_str in parameters.keys():
		var path = _str_to_material_path(path_str)
		if path:
			path.set_value(parameters[path_str])
	# Bake
	var img = await bake_material_async()
	var file_path = save_image_to_shared(img, request_id)
	# Send response back
	send_message("variation_done", {"request_id": request_id, "image_path": file_path})


static func connect_to_host(url: String = _url) -> int:
	_ws.close()
	var err = _ws.connect_to_url(url)
	if err == OK:
		set_process(true)
	return err

func disconnect_host():
	_ws.close()
	set_process(false)

func _process(_delta):
	_ws.poll()
	var state = _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		print("connected")
		while _ws.get_available_packet_count():
			var packet = _ws.get_packet()
			_handle_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		print("disconnected")
		set_process(false)

func send_message(action: String, payload: Dictionary = {}):
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_error("WebSocket not connected")
		return
	var msg := {"action": action}
	msg.merge(payload)
	_ws.put_packet(msg.to_json().to_utf8_buffer())

# ---------- Message handlers ----------
func _handle_message(raw: String):
	var json = JSON.new()
	var err = json.parse(raw)
	if err != OK:
		push_error("Invalid JSON from generator: ", raw)
		return
	var data = json.get_data()

	match data.get("action"):
		"request_variation":
			var params = data.get("parameters", {})
			var req_id = data.get("request_id", "")
			material_request_received.emit(params, req_id)
		"material_found":
			material_found.emit(data.get("material_json", {}))
		"error":
			push_error("Generator error: ", data.get("message", "unknown"))
		_:
			push_warning("Unknown action: ", data.get("action"))

# ---------- File helpers ----------
func save_image_to_shared(image: Image, request_id: String) -> String:
	var dir = DirAccess.open(_shared_folder)
	if not dir:
		dir.make_dir_recursive(_shared_folder)
	var path = _shared_folder.path_join("request_%s.png" % request_id)
	image.save_png(path)
	return path

func send_current_material():
	var data = EditorMaterial.editorMaterialData.duplicate(true)   # deep copy
	send_message("send_material", {"material_json": data})

func request_find_material(image_path: String):
	send_message("find_material", {"image_path": image_path})

func get_new_request_id() -> String:
	_request_counter += 1
	return str(_request_counter)
