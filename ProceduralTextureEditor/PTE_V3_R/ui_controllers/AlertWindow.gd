extends AcceptDialog

## Число секунд, после которого сообщения удаляются.[br][br]
## [color=yellow]Временная метка увеличивается на 1 с каждым физическим кадром движка![/color]
const _CLEAR_TIMER = 10 * 60
## Пул сообщений.
var _message_pool: Array[_Message]

func _ready() -> void:
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	title = &"Внимание!"

func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % _CLEAR_TIMER == 0:
		_clear_pool()


## Вызывает всплывающее окно с переданным сообщением [param alert_text].
## Стилизация пока не поддерживается.[br][br]
## - [param append]: если [code]true[/code], то отобразит пул сообщений,
## иначе покажет одиночное уведомление.
func alert(alert_text: String, append: bool = false)->void:
	size = Vector2i(100, 100)
	if append:
		_message_pool.append(_Message.new(alert_text))
		_clear_pool()
	else:
		dialog_text = alert_text
	show()


func _clear_pool()->void:
	var b: Array[_Message]
	for i in _message_pool:
		if i.is_expired():
			continue
		b.append(i)
	_message_pool = b

	var i: int = 0
	dialog_text = ""
	while i < _message_pool.size():
		dialog_text += "[%d] - %s\n" % [i+1, _message_pool[i]]
		i += 1

class _Message:
	var msg: String
	var init_time: int
	func _init(message: String) -> void:
		msg = message
		init_time = Engine.get_physics_frames()
	func is_expired()->bool:
		return true if init_time+_CLEAR_TIMER < Engine.get_physics_frames() else false
	func _to_string() -> String:
		return msg
