## Records the end-of-game card reveal (ui/reveal/reveal_card.gd) as PNG frames: Odette with a
## fakeout (the Seer card tears, the Poisoner beneath), then Edda (Gravedigger, then her
## burden tag). Needs a real renderer:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/reveal_card_capture.gd -- <out_dir> [reduced]
## then: ffmpeg -framerate 30 -i <out_dir>/f%04d.png -pix_fmt yuv420p reveal.mp4
## Deterministic: 1/30 s a frame. No simulation.
extends SceneTree

const RevealCard = preload("res://ui/reveal/reveal_card.gd")
const VNPortraits = preload("res://ui/vn_portraits.gd")
const SIZE = Vector2i(1920, 1080)
const FPS = 30.0
const SCRIPT = ["seer", "dowser", "clerk", "gravedigger", "medium", "nightwatch", "magistrate", "lamplighter", "poisoner", "brute", "demon"]
const STEPS = [
	{"id": "odette", "name": "Odette", "role": "poisoner", "evil": true, "fakeout_role": "seer", "guess": "You guessed: Minion", "guess_correct": true},
	{"id": "edda", "name": "Edda", "role": "gravedigger", "evil": false, "burden": "…and Delusional", "guess": "You guessed: Gravedigger", "guess_correct": true, "dead": true},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://reveal_card_frames"
	var reduced = args.size() > 1 and args[1] == "reduced"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	var back = ColorRect.new()
	back.color = Color(0.16, 0.12, 0.09)
	back.size = Vector2(SIZE)
	root.add_child(back)
	var sheet = Panel.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.89, 0.77)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.position = Vector2(60, 70)
	sheet.size = Vector2(1800, 880)
	root.add_child(sheet)
	var card = RevealCard.new()
	card.position = Vector2(95, 110)
	card.size = Vector2(1730, 800)
	card.reduced_motion = reduced
	root.add_child(card)
	card.set_process(false)   # after entering the tree: a node with _process re-enables it on ready
	for _i in range(3):
		await process_frame
	var f = 0
	for s in STEPS:
		var step = s.duplicate()
		step.portrait = VNPortraits.texture(s.id, "neutral")
		step.roles = SCRIPT
		card.play(step)
		var frames = int((card.ends_at() + 0.8) * FPS)
		for i in range(frames):
			card.advance(1.0 / FPS)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/f%04d.png" % [out_dir, f])
			f += 1
	print("saved %d frames to %s" % [f, out_dir])
	quit()
