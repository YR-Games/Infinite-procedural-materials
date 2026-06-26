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


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Bakes [param project_path] to a PNG at [param output_path].
## [param size] controls the output resolution (default 1024×1024).
## Returns an Error code: OK on success, or a specific ERR_* constant on failure.
## This function is async — always await it.
func bake(
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
