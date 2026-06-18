class_name GradientEditorPopup
extends PopupPanel

signal editing_finished(gradient: Gradient)

var gradient: Gradient:
	set(value):
		gradient = value
		if is_node_ready():
			_rebuild_stops_list()

var stop_containers: Array[HBoxContainer] = []

@onready var stops_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/StopsList
@onready var add_stop_button: Button = $MarginContainer/VBoxContainer/AddStopButton
@onready var ok_button: Button = $MarginContainer/VBoxContainer/OkButton
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/CancelButton

func _ready() -> void:
	add_stop_button.pressed.connect(_add_stop)
	ok_button.pressed.connect(_on_ok)
	cancel_button.pressed.connect(_on_cancel)
	_rebuild_stops_list()

func _rebuild_stops_list() -> void:
	for c in stops_list.get_children():
		c.queue_free()
	stop_containers.clear()
	for i in range(gradient.get_point_count()):
		var point_data = {
			"offset": gradient.get_offset(i),
			"color": gradient.get_color(i)
		}
		_create_stop_ui(point_data, i)

func _create_stop_ui(point_data: Dictionary, index: int) -> void:
	var container = HBoxContainer.new()
	var offset_slider = HSlider.new()
	offset_slider.min_value = 0.0
	offset_slider.max_value = 1.0
	offset_slider.step = 0.01
	offset_slider.value = point_data.offset
	offset_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offset_slider.value_changed.connect(_on_stop_offset_changed.bind(index))

	var color_button = ColorPickerButton.new()
	color_button.color = point_data.color
	color_button.color_changed.connect(_on_stop_color_changed.bind(index))

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_remove_stop.bind(index))

	container.add_child(offset_slider)
	container.add_child(color_button)
	container.add_child(delete_button)
	stops_list.add_child(container)
	stop_containers.append(container)

func _add_stop() -> void:
	gradient.add_point(0.5, Color.WHITE)
	_rebuild_stops_list()

func _remove_stop(index: int) -> void:
	if gradient.get_point_count() <= 2:
		return
	gradient.remove_point(index)
	_rebuild_stops_list()

func _on_stop_offset_changed(value: float, index: int) -> void:
	if index < gradient.get_point_count():
		gradient.set_offset(index, value)

func _on_stop_color_changed(color: Color, index: int) -> void:
	if index < gradient.get_point_count():
		gradient.set_color(index, color)

func _on_ok() -> void:
	editing_finished.emit(gradient)
	queue_free()

func _on_cancel() -> void:
	queue_free()
