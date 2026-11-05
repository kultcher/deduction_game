## GPU assertions, run explicitly with a real renderer (not the headless dummy).
extends SceneTree

const Player = preload("res://ui/portrait_ink_player.gd")
const Assets = preload("res://ui/portrait_ink_assets.gd")
const SIZE = Vector2i(512, 768)

func _initialize() -> void:
	call_deferred("_run")

func _snapshot(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _run() -> void:
	var viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rect = TextureRect.new()
	rect.size = Vector2(SIZE)
	rect.texture = load(Assets.entry("edda", "neutral").source)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewport.add_child(rect)
	var original = await _snapshot(viewport)
	var player = Player.new()
	player.apply(rect)
	var first = await _snapshot(viewport)
	player.advance(0.5)
	var second = await _snapshot(viewport)
	var alpha_changes = 0
	var protected_changes = 0
	var moving_pixels = 0
	var face: Vector4 = Assets.entry("edda", "neutral").face
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var a = original.get_pixel(x, y)
			var b = first.get_pixel(x, y)
			var c = second.get_pixel(x, y)
			if absf(a.a - b.a) > 0.004 or absf(a.a - c.a) > 0.004:
				alpha_changes += 1
			var p = (Vector2(x + 0.5, y + 0.5) / Vector2(SIZE) - Vector2(face.x, face.y)) / Vector2(face.z, face.w)
			if p.length() < 0.9 and (not _same(a, b) or not _same(a, c)):
				protected_changes += 1
			if not _same(b, c): moving_pixels += 1
	assert(alpha_changes == 0, "Animated ink must preserve original silhouette alpha")
	assert(protected_changes == 0, "Protected facial features must match original RGB")
	assert(moving_pixels > 50, "Ink must actually move outside the protected face")
	player.configure({"amount": 0.0})
	var disabled = await _snapshot(viewport)
	var bypass_changes = 0
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			if not _same(original.get_pixel(x, y), disabled.get_pixel(x, y)):
				bypass_changes += 1
	assert(bypass_changes == 0, "Zero added ink must reproduce the original artwork")
	print("GPU ink checks passed: alpha unchanged; protected face unchanged; %d moving pixels; exact bypass within 1/255" % moving_pixels)
	viewport.queue_free()
	await process_frame
	quit()

func _same(a: Color, b: Color) -> bool:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a))) <= 0.004
