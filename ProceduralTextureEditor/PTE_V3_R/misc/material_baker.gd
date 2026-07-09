class_name ImageBaker extends Node

## Renders a .pte project file to a PNG image by running its generated shader
## through an offscreen SubViewport.
##
## Must be added to the scene tree before calling bake().
## The node manages its own SubViewport / ColorRect children internally.
##
## Usage:
##   var baker := ImageBaker.new()
##   add_child(baker)
##   var err := await baker.bake("user://my_project.pte", "user://output.png", Vector2i(1024, 1024))
##   if err != OK:
##       push_error("Bake failed")

# Emitted when a bake completes successfully.
signal bake_completed(output_path: String)
# Emitted when a bake fails at any stage.
signal bake_failed(reason: String)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

## Default output resolution when none is supplied to bake().
const DEFAULT_SIZE := Vector2i(518, 518)

# ---------------------------------------------------------------------------
# Internal scene tree — built once in _ready(), reused across bake() calls.
# ---------------------------------------------------------------------------

var _viewport: SubViewport
var _color_rect: ColorRect
var _shader_material: ShaderMaterial

# Prevents two concurrent bake() calls from sharing the viewport.
var _bake_lock := false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_viewport_tree()


func _build_viewport_tree() -> void:
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.render_target_clear_mode  = SubViewport.CLEAR_MODE_ONCE
	# Transparent background so the shader's ALPHA output is preserved.
	_viewport.transparent_bg = true
	add_child(_viewport)

	_color_rect = ColorRect.new()
	# Anchors handled manually via size; we set this to match viewport size on each bake.
	_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_color_rect)

	_shader_material = ShaderMaterial.new()
	_color_rect.material = _shader_material
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Bakes [param project_path] to a PNG at [param output_path].
## [param size] controls the output resolution (default 1024×1024).
## Returns an Error code: OK on success, or a specific ERR_* constant on failure.
## This function is async — always await it.
func _bake(
		project_path: String,
		output_path: String,
		size: Vector2i = DEFAULT_SIZE
) -> Error:
	# --- Guard: no concurrent bakes ---
	if _bake_lock:
		var msg := "ImageBaker: bake() called while another bake is in progress."
		push_error(msg)
		bake_failed.emit(msg)
		return ERR_BUSY

	_bake_lock = true
	var result := await _run_bake(project_path, output_path, size)
	_bake_lock = false
	return result


var current_material: String
var current_material_data: Dictionary
var step: int = 0
var final_counter: int = 0
var params_count: int = 0
const MAX_BRUT_FORCE_STEP_COUNT = 22

func bake(material: String, anyway: bool = false)->Array:
	if material != current_material:
		current_material = material
		current_material_data = EditorMaterial.parce_json_string_to_dict(material)
		if not anyway:
			step = 0
			params_count = (
				EditorMaterial.get_generators_params_count(current_material_data)
				+ EditorMaterial.get_modifers_params_count(current_material_data)
			) * 6
			final_counter = -params_count

	if not anyway and not evalute():
		return [Image.new(), ""]

	var generator := MaterialCodeGenerator.new()
	var code := generator.generate_shader_code(current_material_data,"canvas_item")

	var shader := Shader.new()
	shader.code = code
	_shader_material.shader = shader
	_color_rect.material = _shader_material

	await RenderingServer.frame_post_draw

	return [_viewport.get_texture().get_image(), EditorMaterial.get_material_json_string(current_material_data)]


## Подставляет следующие параметры для обрабатываемого материала.
func evalute()->bool:
	if final_counter >= params_count:
		
		return false
	else:
		print_rich("[color=white][b]iterating parameters progress: %d/%d" % [final_counter, params_count])

	step += 1
	
	for channel in current_material_data.get(&"channels"):
		for layer: StringName in EditorMaterial.get_layers(channel, current_material_data):
			var gen_id: StringName = EditorMaterial.get_layer(channel, layer, current_material_data).get("generator_id", "")
			var gen_instance := EditorMaterial.get_generator(gen_id, current_material_data)
			var gen_name: String = gen_instance.get("generator_name", "")
			var gen_params: Dictionary = gen_instance.get("parameters", {})

			if gen_name == "":
				continue
			var gen_data: GeneratorData = GeneratorLibrary.get_generator_data(gen_name)
			if not gen_data:
				continue

			for param_name in gen_data.parameters:
				var param_def: abstractParameterDef = gen_data.parameters[param_name]
				if not param_def is PaletteParameterDef and randf() > 0.5:
					if step == 1 or gen_params[param_name] >= param_def.get_max():
						gen_params[param_name] = param_def.get_min()
						final_counter+=1
					else:
						# Вариант 1 i.default_value += i.step - резервный
						# Вариант 2
						gen_params[param_name] += max(
							(param_def.get_max()-param_def.get_min())/MAX_BRUT_FORCE_STEP_COUNT,
							param_def.get_step(),
						)

			for mod_id in EditorMaterial.get_modifier_order(channel, layer, current_material_data):
				var mod := EditorMaterial.get_modifier(channel, layer, mod_id, current_material_data)
				var mod_name: String  = mod.get("modifier_name", "")
				var mod_params: Dictionary = mod.get("parameters", {})
				var mod_data: ModifierData = ModifierLibrary.get_modifier_data(mod_name)
				if not mod_data:
					continue

				for param_name in mod_data.parameters:
					var param_def: abstractParameterDef = mod_data.parameters[param_name]
					if not param_def is PaletteParameterDef and randf() > 0.5:
						if step == 1 or mod_params[param_name] >= param_def.get_max():
							mod_params[param_name] = param_def.get_min()
							final_counter+=1
						else:
							# Вариант 1 i.default_value += i.step - резервный
							# Вариант 2
							mod_params[param_name] += max(
								(param_def.get_max()-param_def.get_min())/MAX_BRUT_FORCE_STEP_COUNT,
								param_def.get_step(),
							)

			if EditorMaterial.get_layer_order(channel)[0] != layer:
				EditorMaterial.get_layer(channel, layer, current_material_data)[&"opacity"] = randf_range(0.2, 1.0)
			else:
				EditorMaterial.get_layer(channel, layer, current_material_data)[&"opacity"] = randf_range(0.8, 1.0)

	return true


# ---------------------------------------------------------------------------
# Internal bake pipeline
# ---------------------------------------------------------------------------

func _run_bake(
		project_path: String,
		output_path: String,
		size: Vector2i
) -> Error:

	# --- 1. Save current project state so we can restore it after baking ---
	# We write to a temp path rather than caching the dictionary directly,
	# because EditorMaterial.load_project() clears and rebuilds all state.
	const TEMP_SAVE_PATH := "user://__baker_temp_restore.pte"
	var had_existing_project := not EditorMaterial.get_generators().is_empty()
	if had_existing_project:
		if not EditorMaterial.save_project(TEMP_SAVE_PATH):
			push_warning("ImageBaker: could not save current project for restoration.")
			had_existing_project = false

	# --- 2. Load the requested project ---
	if not EditorMaterial.load_project(project_path):
		var msg := "ImageBaker: failed to load project '%s'" % project_path
		push_error(msg)
		bake_failed.emit(msg)
		_restore_project(had_existing_project, TEMP_SAVE_PATH)
		return ERR_FILE_CANT_READ

	# --- 3. Generate shader code ---
	var generator := MaterialCodeGenerator.new()
	var shader_code: String = generator.generate_shader_code()

	if shader_code.strip_edges().is_empty():
		var msg := "ImageBaker: shader code generation produced empty output."
		push_error(msg)
		bake_failed.emit(msg)
		_restore_project(had_existing_project, TEMP_SAVE_PATH)
		return ERR_INVALID_DATA

	# --- 4. Compile and apply the shader ---
	var shader := Shader.new()
	shader.code = shader_code
	_shader_material.shader = shader
	_color_rect.material = _shader_material

	# --- 5. Size the viewport ---
	_viewport.size = size
	_color_rect.size = Vector2(size)

	# --- 6. Trigger exactly one render and wait for the GPU ---
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw

	# --- 7. Read back the rendered image ---
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		var msg := "ImageBaker: viewport returned a null or empty image."
		push_error(msg)
		bake_failed.emit(msg)
		_restore_project(had_existing_project, TEMP_SAVE_PATH)
		return ERR_BUG

	# --- 8. Save to disk ---
	var save_err := image.save_png(output_path)
	if save_err != OK:
		var msg := "ImageBaker: image.save_png('%s') failed with error %d" % [output_path, save_err]
		push_error(msg)
		bake_failed.emit(msg)
		_restore_project(had_existing_project, TEMP_SAVE_PATH)
		return save_err

	# --- 9. Restore previous project state ---
	_restore_project(had_existing_project, TEMP_SAVE_PATH)

	bake_completed.emit(output_path)
	return OK


func _restore_project(should_restore: bool, temp_path: String) -> void:
	if not should_restore:
		EditorMaterial.clear_project()
		return

	if not EditorMaterial.load_project(temp_path):
		push_warning("ImageBaker: could not restore previous project from '%s'" % temp_path)

	# Clean up the temp file — failure here is non-fatal.
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
