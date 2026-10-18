## Скрипт, обеспечивающий связь с Генератором и его работу в фоне.
##
## Автозагружаемый менеджер взаимодействия с Генератором.
## Обрабатывает подключение, отправку запросов, таймауты и приём ответов.
##
## [br][color=yellow]Autor[/color] [url]https://github.com/Yaros1113[/url] [color=green](YR Games)[/color]

extends Node #GConnector

var interface: Window
var baker: ImageBaker

var maaterial_add_queue: Array[Callable]
var material_adding_finished: bool = true

#region TCP Functions

## Задержка перед повторной отправкой запроса.
static var TIMEOUT_SECONDS := 10.0
## Максимальное число попыток отправить запрос.
static var MAX_RETRIES := 3

var send_queue: Array = []                # очередь сообщений на отправку
var recv_buffer: String = ""              # буфер для накопления входящих данных
var pending_requests: Dictionary = {}     # id -> {callback, retries, timer_start, original_msg}


func _ready() -> void:
	interface = get_node(^"/root/EditorUI/MenuAndUI/MenuTopBar/MarginContainer/HBoxContainer/Найти материал по изображжению 🔎/Window")
	baker = get_node(^"/root/EditorUI/Node")

	#set_physics_process(false)
	#set_process_input(false)

	# Запускаем генератор
	TCPConnection.start_generator()
	# Даём время на запуск Python
	await get_tree().create_timer(4.0).timeout
	
	TCPConnection.connect_to_generator()
	# Отправляем тестовое сообщение через 2 секунды (для проверки соединения)
	await get_tree().create_timer(2.0).timeout
	test_connection()

func test_connection() -> void:
	## Отправляет тестовое сообщение "ping" для проверки работоспособности.
	print_rich("[GConnector] Sending test ping")
	var msg = {"type": "ping", "id": "test_ping", "data": {"message": "Hello from Godot"}}
	send_message(msg)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_mode"):
		TCPConnection.show()
		#??? Должен предлагать ввести код доступа, после успешного подтверждения открывать меню с настройками подключения
	elif event.is_action_pressed("ui_select"):
		AlertWindow.alert("Абыбабы\nттутутуу!", true if randf() > 0.5 else false)


func _process(delta: float) -> void:
	# 1. Обработка переподключения
	if not TCPConnection.check_status(delta):
		return

	# 2. Обработка активных запросов
	# Отправка сообщений из очереди #??? вынести в отдельные функции, как _receive_messages
	while send_queue.size() > 0:
		var msg = send_queue.pop_front()
		var json_str = JSON.stringify(msg) + "\n"
		print_rich("[color=cyan][GConnector] Sending: ", json_str.strip_edges().substr(0, 100))
		var bytes = json_str.to_utf8_buffer()
		var err := TCPConnection.put_data(bytes)
		if err != OK:
			print_rich("[color=red][GConnector] Send error: ", err)
			send_queue.push_front(msg)  # возвращаем в очередь
			#TCPConnection.disconnect_generator(true)??? Не нужно переподключать. Просто добавить проверку, что если попыток больше чем send_queue.length*3 -> выход! 
			return
		else:
			print_rich("[color=light green][GConnector] Message sent successfully")

	# Проверка очереди задач на добавление материалов
	if material_adding_finished:
		if not maaterial_add_queue.is_empty():
			maaterial_add_queue.pop_back().call()
		elif interface.get_parent().get_parent().get_child(3).visible:
			interface.get_parent().get_parent().get_child(3).hide()
	elif not interface.get_parent().get_parent().get_child(3).visible:
		interface.get_parent().get_parent().get_child(3).show()
		interface.get_parent().get_parent().get_child(3).text = "Индексация материала⚙️\nНе закрывайте Редактор!"

	# Приём данных
	_receive_messages()

	# 3. Проверка таймаутов для ожидающих запросов
	var now = Time.get_ticks_msec() / 1000.0
	for id in pending_requests.keys():
		var req = pending_requests[id]
		if now - req.timer_start > TIMEOUT_SECONDS:
			if req.retries < MAX_RETRIES:
				print_rich("[color=yellow][GConnector] Request timeout, retrying: ", id)
				req.retries += 1
				req.timer_start = now
				send_message(req.original_msg)
			else:
				print_rich("[color=red][GConnector] Request failed after max retries: ", id)
				if req.callback:
					req.callback.call(FAILED, null)
				pending_requests.erase(id)


func _receive_messages() -> void:
	## Читает доступные данные и разбирает сообщения.
	var data := TCPConnection.get_data()
	if data[0] == OK:
		var text = data[1].get_string_from_utf8()
		print_rich("[GConnector] Received raw data: ", text.substr(0, 150))
		recv_buffer += text
		while recv_buffer.find("\n") != -1:
			var line := recv_buffer.substr(0, recv_buffer.find("\n"))
			recv_buffer = recv_buffer.substr(recv_buffer.find("\n") + 1)
			line = line.strip_edges()
			if line != "":
				var msg = JSON.parse_string(line)
				if msg != null:
					_handle_message(msg)
				else:
					print_rich("[color=red][GConnector] Failed to parse JSON: ", line)


func send_message(msg: Dictionary, callback: Callable = Callable()) -> void:
	## Добавляет сообщение в очередь отправки.
	## Если указан id и callback, запоминает запрос для отслеживания таймаута.
	var id = msg.get("id", "")
	if id != "" and callback != Callable():
		pending_requests[id] = {
			"callback": callback,
			"retries": 0,
			"timer_start": Time.get_ticks_msec() / 1000.0,
			"original_msg": msg.duplicate()
		}
	send_queue.append(msg)
	print_rich("[color=light blue][GConnector] Message queued: ", [msg.type, id])


func _handle_message(msg: Dictionary) -> void:
	## Обрабатывает входящее сообщение от Генератора.
	var msg_type = msg.get("type")
	var msg_id = msg.get("id")
	var data = msg.get("data", {})
	print_rich("[GConnector] Received message: ", msg_type, " id: ", msg_id)

	match msg_type:
		"add_material_ack":
			# Пока ничего полезного не делает, заглушка н абудущее.
			if pending_requests.has(msg_id):
				var req = pending_requests[msg_id]
				var callback = req.callback
				pending_requests.erase(msg_id)
				if callback != Callable():
					callback.call(OK, data)

		"render_request":
			var material: String = data.get("material", "")
			var finished = data.get("finished", false)
			if finished:
				var complete_msg = {
					"type": "add_material_complete",
					"data": {"material": material}
				}
				send_message(complete_msg)
				print_rich("[color=cyan][GConnector] Sent add_material_complete for material: ", material.substr(0, 100))
				if not maaterial_add_queue.is_empty():
					maaterial_add_queue.pop_back().call()
				else:
					material_adding_finished = true
				
			else:
				var baked: Array = await baker.bake(material, false)
				var image:Image = baked[0]
				if image and not image.is_empty():
					var img_base64 := _image_to_base64(image)
					var response = {
						"type": "render_response",
						"id": msg_id,
						"data": {
							"material": material,
							"material_params": baked[1],
							"image": img_base64,
						}
					}
					send_message(response)
					print_rich("[color=cyan][GConnector] Sent %d render_response for material" % baker.step)
				else:
					var response = {
						"type": "renders_is_ower",
						"id": msg_id,
					}
					send_message(response)
					print_rich("[color=cyan][GConnector] Sent renders_is_ower for material: ", material.substr(0, 100))

		"search_ack":
			interface.update_progress_bar(1)
			# Пока ничего полезного не делает, заглушка на будущее.
			if pending_requests.has(msg_id):
				var req = pending_requests[msg_id]
				var callback = req.callback
				pending_requests.erase(msg_id)
				if callback != Callable():
					callback.call(OK, data)

		"search_progress":
			var progress := data.get("progress", 0.0) as float
			interface.update_progress_bar(progress)
			print_rich("[color=cyan][GConnector] Search progress: ", progress)

		"search_result":
			var material: String = data.get("material", "")
			var similarity: float = data.get("similarity", 0.5)
			interface.add_material(material, similarity)
			print_rich("[color=cyan][GConnector] Materials list updated, similarity: ", similarity)

		"search_done":
			interface.update_progress_bar(100, true)
			print_rich("[color=light green][GConnector] Search completed")

		"add_material_stop":
			var reason = data.get("reason", "")
			print_rich("[color=light yellow][GConnector] Add material stopped: ", reason)

		"add_material_complete":
			print_rich("[color=light green][GConnector] Add material complete received")

		"ping":
			interface.get_parent().get_parent().get_child(3).hide()
			interface.get_parent().show()
			print_rich("[GConnector] Ping response: ", data)

		_:
			print_rich("[color=light red][GConnector] Unhandled message type: ", msg_type)


## Генерирует изображение для материала.
func _generate_render(material: String, anyway: bool = false) -> Image:
	#var img = Image.create(518, 518, false, Image.FORMAT_RGBA8)
	#img.fill(Color(randf(), randf(), randf(), 1.0))
	var img: Image = (await baker.bake(material, anyway))[0]
	return img


## Кодирует изображение в base64 (PNG).
func _image_to_base64(image: Image) -> String:
	if image.get_size() != Vector2i(518, 518):
		image.resize(518, 518)
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)

	#var png_data := image.save_png_to_buffer()
	#return Marshalls.raw_to_base64(png_data)
	var raw_data := image.get_data()
	return Marshalls.raw_to_base64(raw_data)


# ---------- Публичные методы ----------

func add_material(material_data: String, callback: Callable = Callable()) -> void:
	print_rich("[color=yellow][b][GConnector] Material add task is added to queue")
	maaterial_add_queue.append(_add_material.bind(material_data, callback))

func _add_material(material_data: String, callback: Callable = Callable()) -> void:
	## Отправляет запрос на добавление материала.
	print_rich("[color=yellow][b][GConnector] Start execute material add task")
	var msg = {
		"type": "add_material",
		"id": str(randi()),
		"data": {"material": material_data}
	}
	send_message(msg, callback)
	material_adding_finished = false


func search_by_image(image: Image, callback: Callable = Callable()) -> void:
	## Отправляет запрос на поиск по изображению.
	var msg = {
		"type": "search_request",
		"id": str(randi()),
		"data": {"image": _image_to_base64(image)}
	}
	send_message(msg, callback)
	interface.update_progress_bar()
