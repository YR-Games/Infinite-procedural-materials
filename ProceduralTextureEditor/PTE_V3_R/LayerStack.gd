class_name LayerStack
extends VBoxContainer

# The data model this stack manages (must be a CompositeLayerData)
var composite_data: CompositeLayerData:
	set(val):
		composite_data = val
		if is_inside_tree():
			rebuild()

# The currently selected layer in this stack
var selected_layer: LayerUIBase = null

# Signals
signal layer_added(layer_ui: LayerUIBase)
signal layer_removed(layer_ui: LayerUIBase)
signal selection_changed(layer_ui: LayerUIBase)

func _ready() -> void:
	if composite_data:
		rebuild()

# Rebuild UI from composite_data.layers
func rebuild() -> void:
	clear()
	if not composite_data:
		return
	for layer_data in composite_data.layers:
		var ui = _create_layer_ui(layer_data)
		add_child(ui)
		ui.parent_stack = self

# Clear all layer rows
func clear() -> void:
	for child in get_children():
		if child is LayerUIBase:
			child.queue_free()

# Factory: create appropriate LayerUI subclass for the given data
func _create_layer_ui(data: AbstractLayerData) -> LayerUIBase:
	match data.get_script().get_global_name():
	#	"GeneratorLayerData":
#	return preload("res://layer_uis/generator_layer_ui.tscn").instantiate()
		#"BumpLayerData":
		#	return preload("res://layer_uis/bump_layer_ui.tscn").instantiate()
		#"ColorRampLayerData":
		#	return preload("res://layer_uis/color_ramp_layer_ui.tscn").instantiate()
		#"RemapLayerData":
		#	return preload("res://layer_uis/remap_layer_ui.tscn").instantiate()
		#"CompositeLayerData":
		#	return preload("res://layer_uis/composite_layer_ui.tscn").instantiate()
		_:
			push_error("Unknown layer data type: ", data.get_script().get_global_name())
			return LayerUIBase.new()

	var ui = LayerUIBase.new()
	ui.layer_data = data
	return ui

# Selection
func select_layer(layer_ui: LayerUIBase) -> void:
	if selected_layer and selected_layer != layer_ui:
		selected_layer.set_selected(false)
	selected_layer = layer_ui
	selected_layer.set_selected(true)
	selection_changed.emit(selected_layer)

# Add a new layer of given type
func add_layer(type_script: Script) -> void:
	var data: AbstractLayerData = type_script.new()
	# Set default name/opacity etc.
	data.enabled = true
	data.opacity = 1.0
	if data.uses_blend_mode:
		data.blend_mode = AbstractLayerData.BlendMode.NORMAL
	composite_data.layers.append(data)
	var ui = _create_layer_ui(data)
	add_child(ui)
	ui.parent_stack = self
	move_child(ui, get_child_count()-1)  # to bottom (bottom of stack is top of list)
	layer_added.emit(ui)
	select_layer(ui)

# Remove the selected layer
func remove_selected_layer() -> void:
	if not selected_layer:
		return
	var idx = composite_data.layers.find(selected_layer.layer_data)
	if idx != -1:
		composite_data.layers.remove_at(idx)
	layer_removed.emit(selected_layer)
	selected_layer.queue_free()
	selected_layer = null

# Move layer from one index to another (for drag-drop)
func move_layer(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return
	var layer_data = composite_data.layers[from_index]
	composite_data.layers.remove_at(from_index)
	composite_data.layers.insert(to_index, layer_data)
	# Reorder UI children accordingly
	var child = get_child(from_index)
	move_child(child, to_index)

# --- Drag & Drop handling (reorder within this stack) ---
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("layer_ui"):
		# Allow drop if source is a LayerUIBase (even from another stack)
		return data["layer_ui"] is LayerUIBase
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var dragged_ui: LayerUIBase = data["layer_ui"]
	var source_stack: LayerStack = data["source_stack"]
	var source_data = dragged_ui.layer_data

	# Remove from source
	source_stack.composite_data.layers.erase(source_data)
	dragged_ui.queue_free()
	if source_stack.selected_layer == dragged_ui:
		source_stack.selected_layer = null

	# Calculate insertion index in this stack
	var insert_index = _get_insertion_index(at_position)

	# Insert data
	composite_data.layers.insert(insert_index, source_data)

	# Rebuild or just insert UI? Better rebuild whole stack or carefully insert.
	# For simplicity, rebuild the entire stack.
	rebuild()
	# Restore selection on the moved layer
	for child in get_children():
		if child is LayerUIBase and child.layer_data == source_data:
			select_layer(child)
			break

# Find index where a dragged item would be inserted based on mouse y
func _get_insertion_index(at_position: Vector2) -> int:
	var local_pos = get_local_mouse_position().y
	var count = get_child_count()
	for i in range(count):
		var child = get_child(i)
		if child is Control:
			var mid_y = child.position.y + child.size.y * 0.5
			if local_pos < mid_y:
				return i
	return count
