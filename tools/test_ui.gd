## Headless smoke test of the UI: builds the scene, plays some commands, opens the case
## view, links and files a deduction through the panel.
##   godot --headless --path . --script res://tools/test_ui.gd
extends SceneTree

func _init() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var g = scene.g
	for cmd in ["go tavern", "wait", "go well", "wait", "go tavern", "wait", "wait", "done", "vigil square", "board", "timeline"]:
		scene._run(cmd)
	await process_frame
	scene._open_case_view()
	await process_frame
	var cv = scene.case_view
	print("case view visible: ", cv.visible, " cards listed: ", cv.card_list.item_count, " timeline cells: ", cv.grid.get_child_count())
	if cv.card_list.item_count >= 2:
		cv.card_list.select(0, false)
		cv.card_list.select(1, false)
		cv._on_link()
		await process_frame
		print("link result: ", cv.result_text.text.substr(0, 120))
		cv._on_conclude_form()
		await process_frame
		var buttons = cv.result_box.get_children().filter(func(c): return c is Button)
		buttons[buttons.size() - 1].emit_signal("pressed")
		await process_frame
		print("after file: ", cv.result_text.text.substr(0, 140))
	cv.prof_opt.select(1)
	cv._refresh_profile()
	cv.note_edit.text = "seems shifty"
	cv._on_save_profile()
	print("profile note saved: ", g.notes.values())
	scene.side_filter.text = "square"
	scene._refresh_side()
	print("sidebar square cards: ", scene.side_list.item_count)
	print("UI OK")
	quit()
