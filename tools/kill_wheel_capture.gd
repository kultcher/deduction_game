## Records the night kill wheel (ui/fx/kill_wheel.gd) and the execution mark
## (ui/fx/execution_mark.gd) as PNG frames: a kill, the no-kill fakeout, then an execution.
## Needs a real renderer:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --script res://tools/kill_wheel_capture.gd -- <out_dir> [reduced]
## then: ffmpeg -framerate 30 -i <out_dir>/f%04d.png -pix_fmt yuv420p kill_wheel.mp4
## Deterministic: 1/30 s a frame. No simulation.
extends SceneTree

const KillWheel = preload("res://ui/fx/kill_wheel.gd")
const ExecutionMark = preload("res://ui/fx/execution_mark.gd")
const PortraitFx = preload("res://ui/portrait_fx.gd")
const UITheme = preload("res://ui/theme.gd")
const C = preload("res://sim/content.gd")
const SIZE = Vector2i(1920, 1080)
const FPS = 30.0
const TOWN = ["agnes", "bart", "constance", "dorian", "edda", "fenwick", "greta", "kiran", "lian", "odette"]

var out_dir: String
var f: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _frame() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/f%04d.png" % [out_dir, f])
	f += 1

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://kill_wheel_frames"
	var reduced = args.size() > 1 and args[1] == "reduced"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	var back = ColorRect.new()
	back.color = Color(0.07, 0.06, 0.08)
	back.size = Vector2(SIZE)
	root.add_child(back)
	var people: Array = []
	for id in TOWN:
		people.append({"id": id, "name": id.capitalize(), "color": C.npc_color(id)})
	var wheel = KillWheel.new()
	wheel.size = Vector2(SIZE.y * 0.9, SIZE.y * 0.9)
	wheel.position = (Vector2(SIZE) - wheel.size) / 2.0
	wheel.reduced_motion = reduced
	root.add_child(wheel)
	wheel.set_process(false)   # after entering the tree: a node with _process re-enables it on ready
	for _i in range(3):
		await process_frame
	for step in [{"people": people, "victim": "greta", "kill": true}, {"people": people, "victim": "kiran", "kill": false}]:
		wheel.play(step)
		var frames = int((wheel.ends_at() + 0.6) * FPS)
		for i in range(frames):
			wheel.advance(1.0 / FPS)
			await _frame()
	wheel.visible = false

	# The execution: a portrait card greys and is struck through.
	var face = TextureRect.new()
	face.texture = PortraitFx.square(UITheme.tex("art/portraits/dorian", 0.25))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.material = PortraitFx.material(true)
	face.size = Vector2(360, 360)
	face.position = (Vector2(SIZE) - face.size) / 2.0
	root.add_child(face)
	for i in range(int(0.4 * FPS)):
		await _frame()
	var m = ExecutionMark.play(face, reduced)
	m.set_process(false)
	for i in range(int((m.ends_at() + 0.8) * FPS)):
		m.advance(1.0 / FPS)
		await _frame()
	print("frames: ", f)
	quit(0)
