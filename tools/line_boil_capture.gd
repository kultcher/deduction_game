## Records the line-boil portrait (ui/line_boil.gd) for review, as numbered PNG frames.
## Needs a real renderer (the headless dummy draws nothing):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/line_boil_capture.gd -- \
##       <out_dir> [conversation|compare] [preset] [id] [seconds]
## then: ffmpeg -framerate 30 -i <out_dir>/f%04d.png -pix_fmt yuv420p boil.mp4
##
## conversation: the real conversation view. The boil rests, flares at 2.5 s as an expression
##   change would (harsh), settles, and from 7 s shows the plain portrait for comparison.
## compare: three portraits side by side: the plain portrait, the two layers held still,
##   and the two layers boiling (flaring at 2.5 s).
## Deterministic: the clock advances 1/30 s a frame whatever the machine. No simulation.
extends SceneTree

const LineBoil = preload("res://ui/line_boil.gd")
const ConversationView = preload("res://ui/day_conversation_view.gd")
const VNPortraits = preload("res://ui/vn_portraits.gd")
const SIZE = Vector2i(1600, 900)
const FPS = 30.0
const FLARE_AT = 2.5
const PLAIN_AT = 7.0
const LINE = "Thou wert at the mill the second night? Then thou saw'st what I saw, and said nothing of it."

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://line_boil_frames"
	var mode: String = args[1] if args.size() > 1 else "conversation"
	LineBoil.preset_name = args[2] if args.size() > 2 else LineBoil.DEFAULT_PRESET
	var id: String = args[3] if args.size() > 3 else "edda"
	var seconds: float = float(args[4]) if args.size() > 4 else 9.0
	if not LineBoil.has_layers(id, "neutral"):
		push_error("no line-boil layers for %s; run tools/make_line_boil_layers.py" % id)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	LineBoil.enabled = true
	var warp = LineBoil.warp_texture()
	if warp.get_image() == null:
		await warp.changed

	var step: Callable
	if mode == "compare":
		step = _build_compare(id)
	else:
		step = _build_conversation(id)
	for _i in range(3):
		await process_frame
	var frames = int(seconds * FPS)
	for f in range(frames):
		step.call(f / FPS)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/f%04d.png" % [out_dir, f])
	print("saved %d frames (%s, %s preset) to %s" % [frames, mode, LineBoil.preset_name, out_dir])
	quit()

func _build_conversation(id: String) -> Callable:
	var view = ConversationView.new()
	root.add_child(view)
	view.set_process(false)
	view.set_location("mill")
	view.begin(id, id.capitalize())
	view.consume([{"k": "speech", "speaker": id, "text": LINE}])
	var label = _label()
	var state = {"flared": false, "plain": false}
	return func(t: float) -> void:
		if t >= FLARE_AT and not state.flared:
			state.flared = true
			view.line_boil.flare("harsh")
		if t >= PLAIN_AT and not state.plain:
			state.plain = true
			LineBoil.enabled = false
			view.portrait.texture = view._expression_texture(id, "neutral")
			view.line_boil.apply([view.portrait])
		view._process(1.0 / FPS)
		label.text = "plain portrait" if state.plain else "line boil (%s)   boil %.2f" % [LineBoil.preset_name, view.line_boil.boil]

func _build_compare(id: String) -> Callable:
	var back = ColorRect.new()
	back.color = Color(0.78, 0.76, 0.72)
	back.size = Vector2(SIZE)
	root.add_child(back)
	var col = SIZE.x / 3.0
	var plain = _portrait(VNPortraits.texture(id, "neutral"), 0, col)
	var still = _portrait(LineBoil.base_texture(id, "neutral"), 1, col)
	var boiling = _portrait(LineBoil.base_texture(id, "neutral"), 2, col)
	var held = LineBoil.new()
	held.boil = 0.0
	held.apply([still])
	held._sync()
	var live = LineBoil.new()
	live.apply([boiling])
	var label = _label()
	var flared = [false]
	return func(t: float) -> void:
		if t >= FLARE_AT and not flared[0]:
			flared[0] = true
			live.flare("harsh")
		live.advance(1.0 / FPS)
		label.text = "plain portrait  |  two layers, held  |  line boil (%s)   boil %.2f" % [LineBoil.preset_name, live.boil]

func _portrait(texture: Texture2D, i: int, col: float) -> TextureRect:
	var r = TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.position = Vector2(col * i + 8, 44)
	r.size = Vector2(col - 16, SIZE.y - 52)
	root.add_child(r)
	return r

func _label() -> Label:
	var label = Label.new()
	label.position = Vector2(16, 8)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	root.add_child(label)
	return label
