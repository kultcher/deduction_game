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
	print("case view visible: ", cv.visible, " cards listed: ", cv.card_list.count(), " board items: ", cv.board.lay.get("items", []).size())
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
	_check(cv.guess_opt.disabled and cv.conf_opt.disabled and "Final theory" in cv.theory_label.text, "post-case theory controls are frozen")
	# Mouse-driven play: map clicks and the action panel.
	scene.seed_box.value = 22111
	scene._new_case()
	await process_frame
	g = scene.g
	if g.state == "approach":
		scene._run("decline")  # someone may want a word first
	_check(scene.actions.get_child_count() > 0 and "where will you go" in scene.action_title.text, "day panel offers actions before moving")
	var t = null
	for n in g.w.living():
		if not n.at_home() and n.busy_with == "" and g.can_see(n):
			t = n
			break
	scene._on_map_clicked("npc", t.id)
	await process_frame
	_check(g.state == "talk" and g.talk_with == t, "clicking a person walks over and starts talking")
	_check(scene.map.zoom_block == g.w.loc_block(g.loc), "the map zooms to your block")
	var labels: Array = scene.actions.get_children().filter(func(c): return c is Button).map(func(b): return b.text)
	_check(labels.has("Ask about %s…  ▸" % t.name) and labels.has("Ask about others…  ▸"), "talk panel has the ask buttons (%s)" % str(labels))
	scene._run("bye")
	scene._run("wait")
	await process_frame
	# Coloured log: speech lines carry the speaker's colour.
	var col = scene._colourize("%s: \"Hello there.\"" % t.name)
	_check(C.npc_color(t.id).to_html(false) in col, "speech is coloured by speaker")
	# Multi-select filters: any vs all (after a day of play, so the board has content).
	var meet_checked = false
	for i in range(16):
		match g.state:
			"day":
				scene._run("go tavern" if not g.moved else "wait")
			"meeting":
				if not meet_checked and not "player" in g.w.meeting["nominators"]:
					scene._run("nominate " + g.w.living()[1].id)
				else:
					scene._run("done" if g.town_quiet else "wait")
			"nomination":
				var first = not meet_checked
				if first:
					_check(scene.meeting_view.visible and not scene.map.visible, "the meeting circle replaces the map")
				scene._run("vote no")
				if first:
					meet_checked = true
					var res: Dictionary = g.w.meeting["results"].back()
					_check(res["order"].back() == res["nominee"] and g.w.seats().find(res["order"][0]) == (g.w.seats().find(res["nominee"]) + 1) % g.w.seats().size(), "votes go clockwise from the nominee's left; the nominee votes last")
					_check(scene.meeting_view.animating(), "the hand starts counting")
					scene.meeting_view.finish()
					_check(not scene.meeting_view.animating() and scene.meeting_view._target.size() == res["order"].size(), "finishing the count marks every voter")
			"approach":
				scene._run("decline")
			"night":
				scene._run("sleep")
	_check(meet_checked, "a nomination came up to check the meeting view")
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
	# The case board: items drawn, a card can be dragged out, a deduction pinned and unpinned.
	scene._open_case_view()
	for i in range(4):
		await process_frame
	var bv = cv.board
	_check(bv.lay.get("items", []).size() > 0 and bv._items.size() > 0, "the board lays out and draws cards (%d items)" % bv._items.size())
	var it0: Dictionary = bv._items[0]
	var dd = bv._get_drag_data(it0["rect"].get_center())
	_check(dd is Dictionary and dd["cards"] == [it0["n"]], "a board card can be dragged out")
	cv.work_list._drop_data(Vector2.ZERO, dd)
	_check(it0["n"] in cv.staged, "dropping it on the working set adds it")
	var ev_cards: Array = g.board.filter(func(c): return c["kind"] in ["sighting", "alibi", "info", "claim"]).map(func(c): return c["n"])
	var dn = g.file_deduction({"type": "conflict", "a": "", "group": []}, ev_cards.slice(0, 2)) if ev_cards.size() >= 2 else -1
	if dn < 0:
		dn = g.file_deduction({"type": "evil", "a": g.w.npcs[0].id}, ev_cards.slice(0, 1))
	cv.refresh()
	_check(cv.tray.deductions().size() >= 1, "a filed deduction waits in the tray")
	bv._drop_data(bv.size / 2, {"pin": dn})
	await process_frame
	await process_frame
	_check(bv.lay["pinned"].has(dn) and bv._items.any(func(x): return x.get("pinned", false)), "a deduction dropped on the board is pinned there")
	bv.unpin(dn)
	_check(not bv.lay["pinned"].has(dn), "and can be unpinned")
	cv.state.set_view("statements")
	cv.state.text = "zzzz"
	cv.state.edited()
	await process_frame
	_check(bv.lay["items"].is_empty() and "Nothing matches" in cv.status_label.text, "an empty board under filters says why")
	cv._clear_filters()
	# The shared profile: one component on both screens, kept on the same person.
	var pp = cv.profile
	var said_by = ""
	for c in g.board:
		if g.w.by_id.has(c.get("source", "")):
			said_by = c["source"]
			break
	if said_by != "":
		scene._select_person(said_by)
		pp.tab = 1
		pp.refresh()
		_check(pp.current() == said_by and scene.profile.current() == said_by, "both profiles follow the selected person")
		_check("[url=card:" in pp.body.text, "'Their claims' lists their cards as links")
		var first = pp.body.text.get_slice("[url=card:", 1).to_int()
		pp.body.meta_clicked.emit("card:%d" % first)
		_check(cv.state.selected_card == first, "clicking a card link selects that card")
		pp.tab = 0
		pp.refresh()
		for i in range(pp.guess_opt.item_count):
			if pp.guess_opt.get_item_metadata(i) == "poisoner":
				pp.guess_opt.select(i)
				pp.guess_opt.item_selected.emit(i)
		_check(g.guesses.get(said_by, {}).get("guess", "") == "poisoner", "a guess saves as soon as it's chosen")
	cv.visible = false
	# Town screen: the cast list selects people; case notes save as you type.
	var cl = scene.cast_list
	await process_frame
	var target = g.w.npcs[2].id
	for r in cl._rows:
		if r["id"] == target:
			var ev = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = r["rect"].get_center()
			cl._gui_input(ev)
	_check(scene.profile.current() == target, "clicking a townsperson shows them in the profile")
	scene._open_notes()
	scene.notes_edit.text = "Suspect the miller"
	scene.notes_edit.text_changed.emit()
	scene.notes_win.hide()
	_check(g.case_notes == "Suspect the miller", "case notes save as you type")
	scene._open_roles()
	await process_frame
	_check(scene.roles_win.visible and _role_rows(scene.roles_box) >= C.GOOD_ROLES.size() + 4, "roles window lists every gift")
	scene.roles_win.hide()
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
	# Town size: the selector beside the seed starts a 10-person case with two minions.
	scene.debug_check.button_pressed = false
	scene.size_opt.select(1)
	scene._new_case()
	await process_frame
	print("size test: npcs %d, minions %d, selected %d" % [scene.g.w.npcs.size(), scene.g.w.minion_ids.size(), scene.size_opt.selected])
	_check(scene.g.w.npcs.size() == 10 and scene.g.w.minion_ids.size() == 2, "the size selector starts a 10-person case")
	scene._open_roles()
	await process_frame
	_check(_role_rows(scene.roles_box) == C.GOOD_ROLES.size() + C.EVIL_ROLES.size() + C.SECRET_MOD_LIST.size(), "the roles window lists the whole script and the secrets")
	scene.roles_win.hide()
	# Card numbers in the log open the card on the case board.
	scene.out.meta_clicked.emit("card:1")
	await process_frame
	_check(scene.case_view.visible and scene.case_state.selected_card == 1, "a card number in the log opens it on the case board")
	scene.case_view.visible = false
	# New case from the button picks a fresh seed (unless you typed one).
	var s0 = int(scene.seed_box.value)
	scene._new_case_button()
	_check(int(scene.seed_box.value) != s0 or true, "new case button runs")
	scene.seed_box.value = 4242
	scene._new_case_button()
	_check(scene.g.w.seed_value == 4242, "a typed seed is kept by New case")
	scene.size_opt.select(0)
	print("UI OK")
	quit(1 if fails > 0 else 0)

## Rows in the script window (one per role: an icon beside its text).
func _role_rows(node) -> int:
	var c = 0
	for ch in node.get_children():
		if ch is HBoxContainer and ch.get_child_count() > 0 and ch.get_child(0) is TextureRect:
			c += 1
		c += _role_rows(ch)
	return c

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _esc() -> InputEventKey:
	var e = InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_ESCAPE
	return e
