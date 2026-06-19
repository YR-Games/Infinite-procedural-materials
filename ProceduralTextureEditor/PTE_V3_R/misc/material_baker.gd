# bake_material.gd (can be a static method in GeneratorComm or a separate class)
static func bake_current_material(size: Vector2i = Vector2i(512,512)) -> Image:
	# 1. Generate shader code from current EditorMaterial state
	var code_gen = MaterialCodeGenerator.new()
	var shader_code = code_gen.generate_shader_code()

	# 2. Create a temporary ShaderMaterial
	var shader = Shader.new()
	shader.code = shader_code
	var mat = ShaderMaterial.new()
	mat.shader = shader

	# 3. Set up a Viewport + ColorRect to render
	var viewport = Viewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	Engine.get_main_loop().root.add_child(viewport)   # add to scene tree temporarily

	var rect = ColorRect.new()
	rect.size = size
	rect.material = mat
	viewport.add_child(rect)

	# 4. Wait one frame for rendering (must be called from a coroutine or with await)
	# This static method cannot await, so we'll make it async later.
	# For synchronous use, we'd need a different approach.
	return await _bake_async(viewport)
