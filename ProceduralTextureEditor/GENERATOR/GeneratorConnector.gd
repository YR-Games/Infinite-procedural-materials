## Скрипт, обеспечивающий связь с Генератором и его работу в фоне.
##
## [br][color=yellow]Autor[/color] [url]https://github.com/Yaros1113[/url] [color=green](YR Games)[/color]

extends Node #GConnector

signal material_request_received(parameters: Dictionary, request_id: String)
signal material_found(material_json: Dictionary)


func _ready() -> void:
	set_physics_process(false)
	set_process_input(false)

	#start_generator()

	# Установка соединения.
	material_request_received.connect(_on_material_request_received)
	connect_to_host()


## Запускает Python проект Генератора в фоне.
func start_generator() -> void:
	var project_dir := ProjectSettings.globalize_path("res://")

	# Формируем реальные пути
	var python_path := project_dir + "GENERATOR/.env/Scripts/python.exe"
	var script_path := project_dir + "GENERATOR/main.py"

	# Проверяем, существует ли файл
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		print("Ошибка: файл скрипта не найден по пути: ", script_path)
		return
	file.close()

	# Запускаем процесс
	var pid := OS.create_process(python_path, [script_path])
	if pid == -1:
		print("Ошибка запуска Python скрипта")
	else:
		print("Генератор запущен с PID: ", pid)


#region WSUtill:

static var _ws := WebSocketPeer.new()
static var _url := "ws://127.0.0.1:8765"   # configurable
static var _shared_folder := "user://shared/"   # should be an absolute system path in production
static var _request_counter := 0


#region Функции обработки соединения:
func connect_to_host(url: String = _url) -> int:
	_ws.close()
	var err := _ws.connect_to_url(url)
	if err == OK:
		print_rich("[color=green]Соединение с Python Генератором процедурных материалов установлено![/color]")
		set_process(true)
	else:
		print_rich("[color=red]Ошибка установки соединения с Python Генератором процедурных материалов: %d![/color]" % err)
	return err

func disconnect_host() -> void:
	_ws.close()
	set_process(false)
	print_rich("[color=yellow]Разорвано соединение с Python Генератором процедурных материалов![/color]")

func _process(_delta: float) -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count():
			var packet := _ws.get_packet()
			_handle_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED and Engine.get_process_frames() % 512 == 0:
		print("WebSocketPeer disconnected")

#endregion

#region Функции обработки сигналов:
static func _on_material_request_received(parameters: Dictionary, request_id: String) -> void:
	# Apply parameters to EditorMaterial
	'''for path_str in parameters.keys():
		var path := _str_to_material_path(path_str)
		if path:
			path.set_value(parameters[path_str])
	# Bake
	var img := await bake_material_async()
	var file_path := save_image_to_shared(img, request_id)
	# Send response back
	send_message("variation_done", {"request_id": request_id, "image_path": file_path})'''

#endregion

#region Message handlers
func send_message(type: String, payload: Dictionary = {}) -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_error("WebSocket not connected")
		connect_to_host()
		return

	var msg := {
		"type": type,
		"payload": payload
	}

	_ws.send_text(JSON.stringify(msg))

	print_rich("[color=cyan]SEND > ", type)


func _handle_message(raw: String) -> void:

	print_rich("[color=cyan]RECV > ", raw)

	var json := JSON.new()

	if json.parse(raw) != OK:
		push_error("Invalid JSON")
		return

	var data: Dictionary = json.data

	var type: String = data.get("type", "")
	var payload: Dictionary = data.get("payload", {})

	match type:

		"material_add_accepted":
			print("Generator accepted material") #???

		"render_request":

			print("Render requested") #???
			var img = Image.load_from_file("res://textures/cgt1.jpg")
			img.resize(518, 518)

			send_message(
				"render_result",
				{
					"image": image_to_base64(img)
				}
			)

		"render_accepted": #???

			print(
				"Cluster:",
				payload.get("cluster_id")
			)

		"material_add_completed": #???

			print(
				"Material completed"
			)

		"material_search_started": #???

			print("Search started")

		"search_progress": #???

			print(
				payload.get("checked"),
				"/",
				payload.get("total")
			)

		"material_match_found": #???

			print(
				"Found:",
				payload.get("similarity")
			)

		"material_search_completed": #???

			print(
				"Search completed"
			)

		"error": #???

			push_error(
				payload.get("message")
			)

		_:
			push_warning(
				"Unknown type: " + type
			)

# Отправка Материала при сохранении.??? Материалы не подключены
func send_current_material() -> void:

	send_message(
		"material_add_request",
		{
			"material": {}
		}
	)

func request_find_material(image: Image) -> void:
	image.resize(518, 518)

	send_message(
		"material_search_request",
		{
			"image": image_to_base64(image)
		}
	)

func get_new_request_id() -> String:
	_request_counter += 1
	return str(_request_counter)


func image_to_base64(image: Image) -> String:
	var buffer := image.save_png_to_buffer()
	return Marshalls.raw_to_base64(buffer)

## ??? Лишнее скорее всего
func base64_to_image(data: String) -> Image:
	var image := Image.new()

	var bytes := Marshalls.base64_to_raw(data)

	image.load_png_from_buffer(bytes)

	return image

#endregion

#endregion
