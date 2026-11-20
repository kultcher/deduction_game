## The main menu's entry to the live Workshop. (Its answer-slot checks moved to
## test_workshop_canvas on the live Workshop when the fixture scene was retired, Nov 20.)
extends SceneTree
var fails = 0
var checks = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var original_world = main.g.w
	var original_day: int = main.g.w.day
	main._on_more(4)
	await process_frame
	check(main.case_view.visible and not main.case_view.workshop.is_collapsed(), "More > Case Workshop opens the case board with the Workshop sheet out")
	check(main.g.w == original_world and main.g.w.day == original_day, "opening Workshop preserves the running game's world")
	var editor = main.case_view.workshop.editor
	main.case_view.workshop.collapse()
	main._on_more(4)
	check(main.case_view.workshop.editor == editor, "reopening reuses the Workshop and preserves its draft")
	main.queue_free()
	await process_frame
	print("Workshop UI: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(okay: bool, label: String) -> void:
	checks += 1
	if okay:
		print("PASS: " + label)
	else:
		fails += 1
		push_error("FAIL: " + label)
