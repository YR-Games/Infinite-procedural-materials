extends GridMap


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in 1024:
		for j in 1024:
			set_cell_item(Vector3(j,0,i),0,0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
