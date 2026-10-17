## Headless smoke test of the UI: builds the scene, plays some commands, opens the case
## view, links and files a deduction through the panel.
##   godot --headless --path . --script res://tools/test_ui.gd
extends SceneTree
var fails = 0

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
	print("case view visible: ", cv.visible, " cards listed: ", cv.card_list.count(), " timeline cells: ", cv.grid.get_child_count())
	if cv.card_list.count() >= 2:
		cv.card_list.select_index(0)
		cv.card_list.select_index(1)
		cv._stage(cv.card_list.selected_metas())
		cv.filter_edit.text = "zzz"
		cv._refresh_cards()
		print("working set survives filtering: ", cv.selected_cards().size() == 2)
		cv.filter_edit.text = ""
		cv._refresh_cards()
		cv._on_link()
		await process_frame
		print("link result: ", cv.result_text.text.substr(0, 120))
		var opts = cv.result_box.get_children().filter(func(c): return c is Button)
		if opts.size() > 0:
			opts[0].emit_signal("pressed")
		else:
			cv.b_who.select(1)
			cv._builder_changed()
		await process_frame
		print("builder: ", cv.b_because.text, " | ", cv.b_preview.text)
		cv._on_file()
		await process_frame
		print("error: ", cv.b_error.text)
		cv.card_list.select_index(0)
		cv._hide_selected(true)
		print("after hide: cards listed ", cv.card_list.count())
		cv.hidden_check.button_pressed = true
		print("show hidden: cards listed ", cv.card_list.count())
		cv._input(_esc())
		print("escape closes: ", not cv.visible)
		print("after file: ", cv.result_text.text.substr(0, 140))
	cv.prof_opt.select(1)
	cv._refresh_profile()
	cv.note_edit.text = "seems shifty"
	cv._on_save_profile()
	print("profile note saved: ", g.notes.values())
	scene.side_filter.text = "square"
	scene._refresh_side()
	print("sidebar square cards: ", scene.side_list.count())
	# The theory shortcut and banner work independently of the board filters.
	scene.seed_box.value = 4242
	scene._new_case()
	g = scene.g
	cv = scene.case_view
	_check("not recorded" in scene.theory_label.text, "console reminds the player to record a theory")
	cv.prof_opt.select(0)
	cv._refresh_profile()
	var id = cv.prof_opt.get_item_metadata(0)
	for i in range(cv.guess_opt.item_count):
		if cv.guess_opt.get_item_metadata(i) == "demon":
			cv.guess_opt.select(i)
	cv._on_save_profile()
	_check(g.guesses[id]["guess"] == "demon" and g.w.by_id[id].name in scene.theory_label.text, "profile guess updates the persistent banner")
	scene._open_theory()
	_check(cv.visible and cv.prof_opt.get_item_metadata(cv.prof_opt.selected) == id, "Record theory opens the saved candidate's profile")
	g.capture_prediction("before_night")
	g.w._finish("evil", "UI test")
	scene._run("look")
	_check(cv.guess_opt.disabled and not cv.conf_spin.editable and "Final theory" in cv.theory_label.text, "post-case theory controls are frozen")
	print("UI OK")
	quit(1 if fails > 0 else 0)

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _esc() -> InputEventKey:
	var e = InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_ESCAPE
	return e
