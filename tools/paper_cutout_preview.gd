## Renders portraits plain and with ui/paper_cutout.gdshader, side by side over a dimmed
## town backdrop like the conversation view's, and saves a PNG. Needs a real renderer:
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/paper_cutout_preview.gd -- out.png nisha jory
extends SceneTree

const SHADER = preload("res://ui/paper_cutout.gdshader")
const SIZE = Vector2i(1700, 1000)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://paper_cutout_preview.png"
	var ids: Array = Array(args.slice(1)).filter(func(a): return not "=" in a) if args.size() > 1 else ["nisha", "jory"]
	# Optional shader overrides: name=value (floats) or name=x,y (vec2).
	var overrides = {}
	for a in args.slice(1):
		if "=" in a:
			var kv = a.split("=")
			var parts = kv[1].split(",")
			overrides[kv[0]] = Vector2(float(parts[0]), float(parts[1])) if parts.size() == 2 else float(kv[1])
	root.size = SIZE
	var ui = Control.new()
	ui.size = Vector2(SIZE)
	root.add_child(ui)
	# Stand-in for the blurred, dimmed scene behind a conversation.
	var back = TextureRect.new()
	back.texture = load("res://assets/art/blocks/square.png")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.modulate = Color(0.5, 0.47, 0.44)
	ui.add_child(back)

	# Paper fibre: a fine cellular noise stretched along one axis reads as pulp, not sand.
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	var grain = NoiseTexture2D.new()
	grain.width = 512
	grain.height = 512
	grain.seamless = true
	grain.noise = noise
	await grain.changed
	var wob_noise = FastNoiseLite.new()
	wob_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wob_noise.frequency = 0.02
	wob_noise.fractal_octaves = 2
	var wobble = NoiseTexture2D.new()
	wobble.width = 512
	wobble.height = 512
	wobble.seamless = true
	wobble.noise = wob_noise
	await wobble.changed
	var material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("grain_tex", grain)
	material.set_shader_parameter("wobble_tex", wobble)
	for k in overrides:
		material.set_shader_parameter(k, overrides[k])

	var col_w: float = SIZE.x / float(ids.size() * 2)
	var i = 0
	for id in ids:
		var tex: Texture2D = load("res://assets/art/portraits_vn_cast/%s-vn-v1.png" % id)
		for shaded in [false, true]:
			var r = TextureRect.new()
			r.texture = tex
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.position = Vector2(col_w * i + 10, 40)
			r.size = Vector2(col_w - 20, SIZE.y - 60)
			if shaded:
				r.material = material
			ui.add_child(r)
			var label = Label.new()
			label.text = "%s — %s" % [id.capitalize(), "paper cutout" if shaded else "current"]
			label.position = Vector2(col_w * i + 20, 8)
			label.add_theme_font_size_override("font_size", 22)
			ui.add_child(label)
			i += 1
	for _f in range(4):
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
