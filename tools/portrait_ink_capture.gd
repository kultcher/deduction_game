## Real-renderer visual checkpoint. No simulation is loaded.
## godot --path . --script res://tools/portrait_ink_capture.gd -- output_dir [frames]
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://portrait_ink_review"
	var count = int(args[1]) if args.size() > 1 else 1
	var reading = args.size() > 2 and args[2] == "reading"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1600, 1000)
	if args.size() > 3 and args[3] == "small": root.size = Vector2i(1280, 720)
	var lab = load("res://ui/line_boil_lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	for _i in range(4): await process_frame
	lab.reset_clock()
	lab.set_reading(reading)
	for f in range(count):
		if f > 0: lab._process(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/f%04d.png" % [out_dir, f])
	lab.set_reading(true)
	lab.conversation.reveal_all()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/conversation.png")
	lab.set_reading(false)
	lab.controls.show_protection.button_pressed = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/protection.png")
	lab.controls.show_protection.button_pressed = false
	lab.legacy = true
	lab._update_portraits()
	for _i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/legacy.png")
	lab.queue_free()
	await process_frame
	print("Saved portrait ink checkpoint to ", out_dir)
	quit()
