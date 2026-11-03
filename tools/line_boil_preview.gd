## Records ui/line_boil.gdshader on the stand-in layers from tools/make_line_boil_layers.py:
## idle boil, a flare into "harsh" and a settle back. Writes numbered PNG frames.
## xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/line_boil_preview.gd -- out_dir jory nisha
## then: ffmpeg -framerate 30 -i out_dir/f%04d.png -pix_fmt yuv420p boil.mp4
extends SceneTree

const SHADER = preload("res://ui/line_boil.gdshader")
const SIZE = Vector2i(1600, 1000)
const FPS = 30.0
const LENGTH = 9.0
const REST = 0.15
# (time, expression, flare to, settle level)
const BEATS = [[0.0, "neutral", REST, REST], [2.5, "harsh", 1.0, 0.3], [6.5, "neutral", 0.55, REST]]
const FADE = 0.25
const DECAY = 0.45

var rigs = []   # {name, rects: {expr: TextureRect}, label}

func _initialize() -> void:
	call_deferred("_run")

func _beat_at(t: float) -> Array:
	var i = 0
	for k in range(BEATS.size()):
		if t >= BEATS[k][0]:
			i = k
	return [i, BEATS[i]]

func _boil_at(t: float) -> float:
	var beat = _beat_at(t)[1]
	var since = t - beat[0]
	return beat[3] + (beat[2] - beat[3]) * exp(-since / DECAY)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://line_boil_frames"
	var ids: Array = Array(args.slice(1)) if args.size() > 1 else ["jory", "nisha"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	var ui = Control.new()
	ui.size = Vector2(SIZE)
	root.add_child(ui)
	var back = TextureRect.new()
	back.texture = load("res://assets/art/blocks/square.png")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.modulate = Color(0.5, 0.47, 0.44)
	ui.add_child(back)

	var wn = FastNoiseLite.new()
	wn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wn.frequency = 0.012
	wn.fractal_octaves = 2
	var warp = NoiseTexture2D.new()
	warp.width = 512
	warp.height = 512
	warp.seamless = true
	warp.noise = wn
	await warp.changed

	var col_w: float = SIZE.x / float(ids.size())
	for c in range(ids.size()):
		var id: String = ids[c]
		var rig = {"name": id.capitalize(), "rects": {}}
		for expr in ["neutral", "harsh"]:
			var dir = "res://assets/art/line_boil_poc/%s/%s" % [id, expr]
			var m = ShaderMaterial.new()
			m.shader = SHADER
			m.set_shader_parameter("lines_a", load(dir + "-lines-a.png"))
			m.set_shader_parameter("lines_b", load(dir + "-lines-b.png"))
			m.set_shader_parameter("lines_c", load(dir + "-lines-c.png"))
			m.set_shader_parameter("warp_tex", warp)
			var r = TextureRect.new()
			r.texture = load(dir + "-base.png")
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.position = Vector2(col_w * c + 10, 50)
			r.size = Vector2(col_w - 20, SIZE.y - 60)
			r.material = m
			ui.add_child(r)
			rig.rects[expr] = r
		var label = Label.new()
		label.position = Vector2(col_w * c + 24, 10)
		label.add_theme_font_size_override("font_size", 22)
		ui.add_child(label)
		rig.label = label
		rigs.append(rig)

	var frames = int(LENGTH * FPS)
	for f in range(frames):
		var t = f / FPS
		var found = _beat_at(t)
		var i: int = found[0]
		var beat = found[1]
		var prev_expr: String = BEATS[i - 1][1] if i > 0 else beat[1]
		var fade = clamp((t - beat[0]) / FADE, 0.0, 1.0) if i > 0 else 1.0
		var boil = _boil_at(t)
		for rig in rigs:
			for expr in rig.rects:
				var r: TextureRect = rig.rects[expr]
				var a = 0.0
				if expr == beat[1]:
					a = fade
				elif expr == prev_expr:
					a = 1.0 - fade
				r.modulate.a = a
				r.visible = a > 0.0
				r.material.set_shader_parameter("boil", boil)
				r.material.set_shader_parameter("clock", t)
			rig.label.text = "%s — %s   boil %.2f" % [rig.name, beat[1], boil]
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/f%04d.png" % [out_dir, f])
	print("saved %d frames to %s" % [frames, out_dir])
	quit()
