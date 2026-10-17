## Headless smoke test of the UI: builds the scene, plays some commands, opens the case
## view, links and files a deduction through the panel.
##   godot --headless --path . --script res://tools/test_ui.gd
extends SceneTree

const C = preload("res://sim/content.gd")
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
	# Mouse-driven play: map clicks and the action panel.
	scene.seed_box.value = 22111
	scene._new_case()
	await process_frame
	g = scene.g
	_check(scene.actions.get_child_count() > 0 and "where will you go" in scene.action_title.text, "day panel offers actions before moving")
	var t = null
	for n in g.w.living():
		if not n.at_home() and n.busy_with == "":
			t = n
			break
	scene._on_map_clicked("npc", t.id)
	await process_frame
	_check(g.state == "talk" and g.talk_with == t, "clicking a person walks over and starts talking")
	_check(scene.map.zoom_block == g.w.loc_block(g.loc), "the map zooms to your block")
	var labels: Array = scene.actions.get_children().filter(func(c): return c is Button).map(func(b): return b.text)
	_check(labels.any(func(x): return x.begins_with("Ask about")) and labels.has("Ask about their gift"), "talk panel has the ask buttons (%s)" % str(labels))
	scene._run("bye")
	scene._run("wait")
	await process_frame
	# Coloured log: speech lines carry the speaker's colour.
	var col = scene._colourize("%s: \"Hello there.\"" % t.name)
	_check(C.npc_color(t.id).to_html(false) in col, "speech is coloured by speaker")
	# Multi-select filters: any vs all (after a day of play, so the board has content).
	for i in range(12):
		match g.state:
			"day":
				scene._run("go tavern" if not g.moved else "wait")
			"meeting":
				scene._run("done" if g.town_quiet else "wait")
			"nomination":
				scene._run("vote no")
			"approach":
				scene._run("decline")
			"night":
				scene._run("sleep")
	cv = scene.case_view
	cv.set_game(g)
	var ids: Array = g.w.npcs.map(func(n): return n.id)
	cv.sel_people[ids[0]] = true
	cv.sel_people[ids[1]] = true
	cv._refresh_cards()
	var both = cv.card_list.count()
	cv.sel_people.erase(ids[1])
	cv._refresh_cards()
	var one = cv.card_list.count()
	cv.sel_people[ids[1]] = true
	cv.sel_kinds["sighting"] = true
	cv.match_opt.select(1)
	cv._refresh_cards()
	var all_n = cv.card_list.count()
	cv.match_opt.select(0)
	cv._refresh_cards()
	var any_n = cv.card_list.count()
	print("filters: one person %d, two people %d; +sightings: all %d, any %d" % [one, both, all_n, any_n])
	_check(both >= one and any_n >= all_n, "multi-select filters: OR within a list; 'all' narrows across lists")
	# Debug overlay: shows NPCs' private view, and marks identification unscored.
	scene.debug_check.button_pressed = true
	await process_frame
	_check(g.debug_overlay and g.prediction_spoiled, "debug overlay spoils identification credit")
	_check("Credited by others" in scene.side_profile.text, "profile shows credibility across the town")
	var shown = 0
	for c in g.board:
		if g.debug_card_text(c) != "":
			shown += 1
	print("debug: %d of %d cards have an influence readout" % [shown, g.board.size()])
	_check(shown > 0, "some cards show their influence")
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
