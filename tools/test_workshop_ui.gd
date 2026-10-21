## Exercises actual UI signals, slot persistence, file replay and the main-menu entry.
extends SceneTree
const Workshop = preload("res://ui/case_workshop.tscn")
var fails = 0
var checks = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = Workshop.instantiate()
	root.add_child(scene)
	await process_frame
	scene._load_example(3)
	var slot = scene.find_child("Answer_dowse_1", true, false)
	slot.select(4)
	slot.item_selected.emit(4)
	await process_frame
	check(scene.session.case_data.answers.dowse.slots[1] == "lian", "an actual answer signal records the chosen slot")
	check(scene.find_child("Answer_dowse_0", true, false).selected == 0, "earlier unanswered slot stays unknown")
	check(scene.find_child("Answer_dowse_1", true, false).selected == 4, "chosen slot survives the UI rebuild")
	# Repeating a person produces visible feedback rather than silently fixing the case.
	slot = scene.find_child("Answer_dowse_0", true, false)
	slot.select(4)
	slot.item_selected.emit(4)
	await process_frame
	check(not scene.analysis.errors.is_empty(), "duplicate answers are permitted with a specific visible validation error")
	scene._load_example(3)
	scene._present()
	scene.remember.button_pressed = true
	scene.venue.select(1)
	scene._present()
	check(scene.session.last_results.all(func(r): return is_zero_approx(r.suspicion_delta)), "UI remembered-mode repetition adds no suspicion")
	var path = "user://workshop-ui-test.json"
	scene._save(path)
	var expected = scene.session.last_results.duplicate(true)
	scene.session.generate(101)
	scene._open(path)
	check(scene.session.last_results == expected, "save/open controls restore the actual experiment")
	check(scene.remember.button_pressed and scene.venue.selected == 1, "open restores discussion mode and venue")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame
	var main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var original_world = main.g.w
	var original_day: int = main.g.w.day
	main._on_more(4)
	await process_frame
	check(is_instance_valid(main.workshop_win) and main.workshop_win.visible, "More > Case Workshop opens the standalone experiment")
	check(main.g.w == original_world and main.g.w.day == original_day, "opening Workshop preserves the running game's world")
	main.workshop_win.hide()
	main._on_more(4)
	check(main.workshop_win.get_child_count() == 1, "reopening reuses the Workshop and preserves its experiment")
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
