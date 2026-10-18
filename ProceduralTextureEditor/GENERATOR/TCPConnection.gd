class_name TCPConnection
## Обхект подключения к генератору, предоставляющий доступ к настройкам
## и самому подключению.
##
## [br][color=yellow]Autor[/color] [url]https://github.com/Yaros1113[/url] [color=green](YR Games)[/color]

static var _generator_host := "127.0.0.1"
static var _generator_port := 12345
## Задержка между попытками переподключения.
static var _reconnect_delay := 1.0
static var _reconnect_timer: float = 0.0

static var _stream: StreamPeerTCP = null

## Интерфейс меню отлаочных настроек.
static var _debug_ui: ConfirmationDialog = preload("res://PTE_V3_R/UI/debug_ui.tscn").instantiate()
static var is_in_tree: bool = false


## Показывает окно настроек.
static func show()->void:
	# Подключаем окно, если его ещё нет.
	if not is_in_tree:
		GConnector.add_child(_debug_ui)
		_debug_ui.confirmed.connect(_save)
		is_in_tree = true

	_debug_ui.show()


## Отправляет запрос на Генератор.
static func put_data(bytes)->Error:
	return _stream.put_data(bytes)


## Получает данные от Генератора.
static func get_data()->Array:
	if _stream.get_available_bytes() > 0:
		return _stream.get_data(_stream.get_available_bytes())
	return [Error.ERR_INVALID_DATA]


## Проверяет статус, возвращает лож, если нет стабильного соединения.
static func check_status(delta: float)->bool:
	if _stream == null:
		if _reconnect_timer > 0:
			_reconnect_timer -= delta
			if _reconnect_timer <= 0:
				connect_to_generator()
		return false

	_stream.poll()
	var status := _stream.get_status()
	#print_rich(status)???
	match status:
		StreamPeerTCP.STATUS_CONNECTED:
			return true

		StreamPeerTCP.STATUS_ERROR:
			print_rich("[color=red][GConnector] Connection error, reconnecting...")
			disconnect_generator(true)

		StreamPeerTCP.STATUS_NONE, StreamPeerTCP.STATUS_CONNECTING:
			pass # Ничего не делаем, ждём

	return false


## Разрывает соединение с Генератором.
static func disconnect_generator(try_reconnect: bool = false) -> void:
	## Закрывает соединение и сбрасывает состояние.
	if _stream != null:
		_stream.disconnect_from_host()
		_stream = null
	# Очищаем очередь, чтобы не накапливать старые сообщения
	# (можно оставить, если нужно повторить после переподключения)???
	#send_queue.clear()
	#pending_requests.clear()
	print_rich("[color=light red][GConnector] Disconnected")

	if try_reconnect:
		_reconnect_timer = _reconnect_delay


## Устанавливает TCP-соединение с Генератором.
static func connect_to_generator() -> void:
	# Локальный запуск генератора.
	if not is_process_running_windows(generator_pid):
		start_generator()
		await GConnector.get_tree().create_timer(5.0).timeout

	if _stream != null:
		_stream.disconnect_from_host()
		_stream = null
	
	_stream = StreamPeerTCP.new()
	var err = _stream.connect_to_host(_generator_host, _generator_port)
	if err != OK:
		print_rich("[color=red][GConnector] Connection error: ", err)
		_reconnect_timer = _reconnect_delay
	else:
		print_rich("[color=yellow][GConnector] Connecting...")

#region Локальный запуск Генератора.
static var generator_pid: int
static func is_process_running_windows(pid: int) -> bool:
	var output: Array = []
	# Запуск команды tasklist с параметром /FI для фильтрации по PID
	var exit_code = OS.execute("cmd.exe", ["/c", "tasklist /FI \"PID eq " + str(pid) + "\""], output)
	
	if exit_code == 0 and output.size() > 0:
		# Если процесс найден, в выводе будет его имя, а не фраза "No tasks are running"
		if not "No tasks are running" in output[0]:
			return true
	return false

## Запускает Python проект Генератора в фоне
static func start_generator() -> void:
	var project_dir := ProjectSettings.globalize_path("res://")
	
	# Проверяем ОС
	var python_path: String
	var script_path := project_dir + "GENERATOR/main.py"
	
	if OS.get_name() == "Windows":
		python_path = project_dir + "GENERATOR/.env/Scripts/python.exe"
	else:
		python_path = project_dir + "GENERATOR/.env/bin/python"
	
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		print_rich("[color=red]Ошибка: файл скрипта не найден по пути: ", script_path)
		return
	file.close()
	
	var pid := OS.create_process(python_path, [script_path])
	if pid == -1:
		print_rich("[color=red]Ошибка запуска Python скрипта")
	else:
		print_rich("[color=green]Генератор запущен с PID: ", pid)
		generator_pid = pid

#endregion


## Сохраняет настройки и инициирует переподключение.
static func _save()->void:
	var container: VBoxContainer = _debug_ui.get_child(0)
	var ip: LineEdit = container.get_child(1).get_child(2)
	var port: LineEdit = container.get_child(2).get_child(2)

	_generator_host = ip.text
	_generator_port = port.text.to_int()

	connect_to_generator()
