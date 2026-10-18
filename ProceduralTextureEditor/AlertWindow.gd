extends AcceptDialog

func _ready() -> void:
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	title = "Внимание!"
	#canceled.connect(hide)
	#confirmed.connect(hide)

func alert(alert_text: String)->void:
	dialog_text = alert_text
	show()
