## Records the paper-puppet test (ui/paper_puppet.gd) in the conversation view, as PNG frames.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/paper_puppet_capture.gd -- \
##       <out_dir> [stepped|smooth|still] [seconds] [scene]
## She talks from 1 s to 4 s and from 5.5 s to 7.5 s. Deterministic: 1/30 s a frame. No simulation.
extends SceneTree

const ConversationView = preload("res://ui/day_conversation_view.gd")
const DEFAULT_SCENE = "res://ui/paper_puppet/edda_puppet.tscn"
const SIZE = Vector2i(1600, 900)
const FPS = 30.0
const RENDER_SCALE = 0.6
const LINE = "Thou wert at the mill the second night? Then thou saw'st what I saw, and said nothing of it."
const TALK = [[1.0, 4.0], [5.5, 7.5]]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://paper_puppet_frames"
	var mode: String = args[1] if args.size() > 1 else "stepped"
	var seconds: float = float(args[2]) if args.size() > 2 else 9.0
	var scene: String = args[3] if args.size() > 3 else DEFAULT_SCENE
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	var view = ConversationView.new()
	root.add_child(view)
	view.set_process(false)
	view.set_location("mill")
	view.begin("edda", "Edda")
	view.consume([{"k": "speech", "speaker": "edda", "text": LINE}])
	# The puppet draws into its own transparent viewport, shown where the portrait goes.
	var vp = SubViewport.new()
	vp.size = Vector2i(Vector2(1024, 1536) * RENDER_SCALE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var puppet = load(scene).instantiate()
	puppet.scale = Vector2.ONE * RENDER_SCALE
	puppet.set_process(false)
	vp.add_child(puppet)
	puppet.stepped = mode == "stepped"
	view.portrait.texture = vp.get_texture()
	var label = Label.new()
	label.position = Vector2(16, 8)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	root.add_child(label)
	for _i in range(3):
		await process_frame
	var frames = int(seconds * FPS)
	for f in range(frames):
		var t = f / FPS
		puppet.talking = TALK.any(func(w): return t >= w[0] and t < w[1])
		if mode != "still":
			puppet.advance(1.0 / FPS)
		view._process(1.0 / FPS)
		label.text = "paper puppet (%s)%s" % [mode, "   talking" if puppet.talking else ""]
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/f%04d.png" % [out_dir, f])
	print("saved %d frames (%s) to %s" % [frames, mode, out_dir])
	quit()
