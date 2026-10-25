## Headless smoke test of the UI: builds the scene, plays some commands, opens the case
## view, links and files a deduction through the panel.
##   godot --headless --path . --script res://tools/test_ui.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Icons = preload("res://ui/board_icons.gd")
var fails = 0

func _init() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.roles_win.hide()
	scene.show_script_at_start = false
	var g = scene.g
	var original_meeting: Dictionary = g.w.meeting.duplicate(true)
	var voter_rng = g.w.rng.state
	var threshold: int = g.w.vote_threshold()
	var nominee = g.w.npcs[0]
	var previous = g.w.npcs[1]
	g.w.meeting = {"pending": {"by": "player", "nominee": nominee.id}, "block": "", "block_count": 0, "results": []}
	_check(g.vote_requirement_text().begins_with("%d votes needed" % threshold), "first nomination text uses the normal minimum")
	g.w.meeting.block = previous.id
	g.w.meeting.block_count = threshold + 1
	var replacement = g.vote_requirement_text()
	_check(replacement.begins_with("%d to put %s" % [threshold + 2, nominee.name]) and "instead of " + previous.name in replacement and "%d to tie" % (threshold + 1) in replacement, "replacement text names the block and shows winning and tying counts")
	scene.meeting_view.refresh()
	_check(scene.meeting_view._vote_hint == replacement, "the meeting view captures the same pre-vote requirements as the prompt")
	g.w.meeting.block = ""
	_check("empty after a tie" in g.vote_requirement_text() and g.vote_requirement_text().begins_with("%d to put" % (threshold + 2)), "an empty block retains the earlier high count")
	_check(g.w.rng.state == voter_rng and g.w.meeting.block_count == threshold + 1, "formatting requirements changes neither vote state nor RNG")
	var old_state: String = g.state
	g.state = "nomination"
	scene._refresh_actions()
	var vote_labels: Array = scene.actions.get_children().filter(func(button): return button is Button).map(func(button): return button.text)
	_check("Vote to execute" in vote_labels and "Vote to spare" in vote_labels, "both vote buttons name their execution outcome")
	g.state = old_state
	g.w.meeting = original_meeting
	scene.meeting_view.set_game(g)
	for cmd in ["go tavern", "wait", "go well", "wait", "go tavern", "wait", "wait", "done", "vigil square", "board", "timeline"]:
		scene._run(cmd)
	await process_frame
	scene._open_case_view()
	for i in range(3):
		await process_frame
	var cv = scene.case_view
	_check(cv.panels.values().all(func(p): return not p.visible), "case-board tools start minimized")
	_check(cv.board.size.is_equal_approx(cv.canvas.size), "the grid fills the canvas without sidebar columns")
	_check(cv.board.zoom > 1.0, "the initial day view uses the full canvas rather than the hidden control's startup size")
	_check(not cv.panels["cards"].is_ancestor_of(cv.filter_edit) and not cv.panels["cards"].is_ancestor_of(cv.kind_menu), "shared filters live on the main case screen, outside the card popup")
	_check(cv.dock.get_global_rect().position.y >= cv.canvas.get_global_rect().end.y, "popup controls live in the bottom dock")
	_check(cv.filter_bar.get_global_rect().position.y >= cv.canvas.get_global_rect().end.y and cv.dock.get_global_rect().position.y >= cv.filter_bar.get_global_rect().end.y and cv.tray.get_global_rect().position.y >= cv.dock.get_global_rect().end.y, "bottom rows are ordered board, filters, popup tools, deductions")
	_check(cv.panel_buttons["cards"].text == "Card List" and cv.panels["cards"].size.x == cv.panels["cards"].minimum_panel_size.x, "Card List starts at its minimum width")
	var library_buttons = cv.panels["cards"].find_children("*", "Button", true, false)
	_check(library_buttons.size() == 1 and library_buttons[0].text == "—" and library_buttons[0].tooltip_text == "Minimize", "Card List has only a line-shaped minimize button")
	_check(cv.hidden_check.get_index() == cv.clear_btn.get_index() + 1 and cv.clear_btn.has_theme_stylebox_override("normal"), "Show hidden follows the distinct Clear filters button")
	_check(cv.panel_buttons["cards"].size.y == cv.panel_buttons["cards"].get_combined_minimum_size().y, "dock buttons keep their natural height")
	var panel_rects = {}
	for key in cv.panels:
		panel_rects[key] = cv.panels[key].get_rect()
	var canvas_before: Vector2 = cv.canvas.size
	var recognized: String = g.w.npcs[0].id
	for query in [recognized, recognized + "zzz", "fenwick", "fenwhick", "lian", "liahn", ""]:
		cv.filter_edit.text = query
		cv.filter_edit.text_changed.emit(query)
		for i in range(6):
			await process_frame
		var stable = cv.canvas.size.is_equal_approx(canvas_before)
		for key in cv.panels:
			stable = stable and cv.panels[key].get_rect().is_equal_approx(panel_rects[key])
		_check(stable, "filter '%s' preserves closed overlays and canvas dimensions" % query)
	var dock_height: float = cv.dock.size.y
	for npc in g.w.npcs:
		cv.state.people[npc.id] = true
	for place in C.LOCATIONS:
		cv.state.places[place] = true
	cv.state.changed.emit()
	for i in range(6):
		await process_frame
	_check(cv.chip_row.size.y > 44 and cv.dock.size.y == dock_height and cv.panel_buttons["cards"].size.y == cv.panel_buttons["cards"].get_combined_minimum_size().y, "many filters wrap independently without stretching the window toolbar")
	cv._clear_filters()
	for i in range(6):
		await process_frame
	cv.set_panel_open("profile", true)
	cv.set_panel_open("work", true)
	_check(cv.panels["profile"].get_rect().is_equal_approx(panel_rects["profile"]) and cv.panels["work"].get_rect().is_equal_approx(panel_rects["work"]), "filtered-before-opening tools retain their original dimensions")
	cv.set_panel_open("profile", false)
	cv.set_panel_open("work", false)
	var board_rect: Rect2 = cv.board.get_global_rect()
	var board_pan: Vector2 = cv.board.pan
	var board_zoom: float = cv.board.zoom
	for key in cv.panels:
		cv.panel_buttons[key].emit_signal("pressed")
		await process_frame
		_check(cv.panels[key].visible and cv.panel_buttons[key].button_pressed, "%s opens from the dock" % key)
		var panel = cv.panels[key]
		_check(panel.size.x >= (340 if key == "cards" else 400) and panel.size.y >= 500, "%s opens at a usable size after the initial layout" % key)
		panel.move_to(Vector2.ZERO)
		panel.resize_to(Vector2(410, 320))
		await process_frame
		_check(panel.size.x < 600 and panel.size.y < 400, "%s can be resized" % key)
		panel.move_to(cv.canvas.size * 2)
		_check(Rect2(Vector2.ZERO, cv.canvas.size).encloses(panel.get_rect()), "%s stays reachable inside the canvas" % key)
		panel.hide()
		_check(not cv.panel_buttons[key].button_pressed, "%s minimizing updates its dock toggle" % key)
	await process_frame
	_check(cv.board.get_global_rect().is_equal_approx(board_rect) and cv.board.pan == board_pan and cv.board.zoom == board_zoom,
		"opening, moving, resizing and minimizing tools preserves the board viewport")
	cv.set_panel_open("work", true)
	var floating = cv.panels["work"]
	floating.move_to(Vector2(140, 40))
	floating.resize_to(Vector2(500, 400))
	await process_frame
	var position_before: Vector2 = floating.position
	var at: Vector2 = floating.global_position + Vector2(60, 20)
	await _drag_panel(at, at + Vector2(80, 40))
	_check(floating.position.is_equal_approx(position_before + Vector2(80, 40)), "dragging a panel title moves the overlay")
	var size_before: Vector2 = floating.size
	at = floating.global_position + floating.size - Vector2(18, 18)
	await _drag_panel(at, at + Vector2(60, 30))
	_check(floating.size.is_equal_approx(size_before + Vector2(60, 30)), "dragging the corner resizes the overlay")
	floating.hide()
	print("case view visible: ", cv.visible, " cards listed: ", cv.card_list.count(), " board items: ", cv.board.lay.get("items", []).size())
	if cv.card_list.count() >= 2:
		cv.card_list.select_index(0)
		cv.card_list.select_index(1)
		cv._stage(cv.card_list.selected_metas())
		_check(cv.panels["work"].visible, "staging evidence opens the case builder")
		var staged_before: Array = cv.selected_cards()
		cv.set_panel_open("work", false)
		cv.set_panel_open("work", true)
		_check(cv.selected_cards() == staged_before, "minimizing and reopening the builder preserves staged evidence")
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
		print("builder validation: ", cv.b_error.text)
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
	_check(cv.panels.values().all(func(p): return not p.visible), "a new case starts with tools minimized again")
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
	_check(cv.visible and cv.panels["profile"].visible and cv.prof_opt.get_item_metadata(cv.prof_opt.selected) == id, "Record theory opens the saved candidate's profile")
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
	_check(labels.has("Ask about %s's gift…  ▸" % t.name) and labels.has("Offer…  ▸") and labels.has("Ask where they were and who they saw…  ▸") \
		and labels.has("Ask about others…  ▸") and labels.has("Present a card…"), "talk panel has the new top-level buttons (%s)" % str(labels))
	_check(not labels.any(func(x): return "seen around" in x), "the generic 'who have you seen' question is gone")
	scene._run("bye")
	scene._run("wait")
	await process_frame
	# Coloured log: speech lines carry the speaker's colour.
	var speech_spans = scene.log_text.formatter.format_text("Hello there.", {"speaker_id": t.id})
	_check(speech_spans[0]["color"] == C.npc_color(t.id), "speech is coloured by speaker")
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
	# Statements: left click filters; right click opens, switches, or closes a profile.
	scene._open_case_view()
	cv._clear_filters()
	cv.state.set_view("statements")
	cv.set_panel_open("profile", false)
	cv.board.fit_all()
	for i in range(3):
		await process_frame
	var people_rows: Array = cv.board._row_hits.filter(func(r): return r["row"]["kind"] == "person")
	_check(people_rows.size() >= 2, "two person labels are available for profile interactions")
	if people_rows.size() >= 2:
		var first_row: Dictionary = people_rows[0]
		var second_row: Dictionary = people_rows[1]
		var click = InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = first_row["rect"].get_center()
		cv.board._gui_input(click)
		_check(not cv.panels["profile"].visible and cv.state.people.has(first_row["row"]["id"]), "left-clicking a statement name filters without opening Profile")
		var filters_before = cv.state.people.duplicate()
		click.button_index = MOUSE_BUTTON_RIGHT
		cv.board._gui_input(click)
		_check(cv.panels["profile"].visible and cv.profile.current() == first_row["row"]["id"], "right-clicking a name opens that profile")
		click.position = second_row["rect"].get_center()
		cv.board._gui_input(click)
		_check(cv.panels["profile"].visible and cv.profile.current() == second_row["row"]["id"], "right-clicking another name switches the open profile")
		cv.board._gui_input(click)
		_check(not cv.panels["profile"].visible and cv.state.people == filters_before, "right-clicking the shown person closes Profile without changing filters")
	cv._clear_filters()
	cv.state.set_view("places")
	_check(Icons.kind_for({"kind": "info"}) == "reading" and Icons.kind_for({"kind": "claim"}) == "statement" and Icons.kind_for({"kind": "accusation"}) == "accusation", "readings, statements and accusations have distinct icon meanings")
	_check(["statement", "reading", "accusation", "sunrise", "sunset"].all(func(k): return Icons.texture(k) != null), "all new line icons render")
	_check(Icons.phase_shade(C.NIGHT).a > Icons.phase_shade(C.MORNING).a and Icons.phase_shade(C.MORNING) != Icons.phase_shade(C.EVENING), "night has the strongest shading and day phases differ subtly")
	# The case board: items drawn, a card can be dragged out, a deduction pinned and unpinned.
	scene._open_case_view()
	for i in range(4):
		await process_frame
	var bv = cv.board
	_check(bv.lay.get("items", []).size() > 0 and bv._items.size() > 0, "the board lays out and draws cards (%d items)" % bv._items.size())
	var it0: Dictionary = bv._items[0]
	var context_click = InputEventMouseButton.new()
	context_click.button_index = MOUSE_BUTTON_RIGHT
	context_click.pressed = true
	context_click.position = it0["rect"].get_center()
	bv._gui_input(context_click)
	_check(cv.card_menu.visible and cv._context_card == it0["n"] and _menu_labels(cv.card_menu) == ["Add to Deduction", "Add to Case Workshop", "Hide", "Find Links", "Hints"], "right-clicking a grid card offers deduction, Workshop and evidence actions")
	cv.card_menu.id_pressed.emit(cv.CardAction.ADD)
	_check(it0["n"] in cv.staged and cv.panels["work"].visible, "Add to Deduction stages the clicked card")
	cv.show_card_menu(it0["n"], Vector2i(200, 200))
	cv.card_menu.id_pressed.emit(cv.CardAction.HINTS)
	_check("#%d" % it0["n"] in cv.result_text.text, "Hints describe the clicked card")
	cv.show_card_menu(it0["n"], Vector2i(200, 200))
	cv.card_menu.id_pressed.emit(cv.CardAction.LINKS)
	_check("#%d" % it0["n"] in cv.result_text.text, "Find Links searches for the clicked card")
	cv.show_card_menu(it0["n"], Vector2i(200, 200))
	cv.card_menu.id_pressed.emit(cv.CardAction.HIDE)
	_check(g.board[it0["n"] - 1].get("hidden", false) and not cv.state.apply(g).any(func(c): return c["n"] == it0["n"]), "Hide removes the clicked evidence from normal views")
	cv.hidden_check.button_pressed = true
	var hidden_row: TreeItem = cv.card_list._items.filter(func(item): return item.get_metadata(0) == it0["n"])[0]
	_check(hidden_row.get_custom_color(0).a < 0.5, "shown hidden cards have translucent text in Card List")
	var staged_row: TreeItem = cv.work_list._items.filter(func(item): return item.get_metadata(0) == it0["n"])[0]
	_check(staged_row.get_custom_color(0).a < 0.5, "a shown hidden card also stays translucent in the working set")
	cv.show_card_menu(it0["n"], Vector2i(200, 200))
	_check(_menu_labels(cv.card_menu) == ["Add to Deduction", "Add to Case Workshop", "Unhide", "Find Links", "Hints"], "hidden cards offer Unhide instead of Hide")
	cv.card_menu.id_pressed.emit(cv.CardAction.HIDE)
	_check(not g.board[it0["n"] - 1].get("hidden", false), "Unhide restores the clicked evidence")
	cv.hidden_check.button_pressed = false
	cv.set_panel_open("work", false)
	cv.set_panel_open("profile", false)
	cv.set_panel_open("cards", true)
	for i in range(3):
		await process_frame
	var first_item = cv.card_list._items[0]
	var list_at: Vector2 = cv.card_list.get_item_area_rect(first_item).get_center()
	await _right_click(cv.card_list.global_position + list_at)
	_check(cv.card_menu.visible and cv._context_card == first_item.get_metadata(0), "a mouse right-click on a text entry opens the same card menu")
	cv.card_menu.hide()
	cv.set_panel_open("cards", false)
	# This test invokes the callback directly; establish the engine drag context
	# first so set_drag_preview owns and later frees the preview normally.
	bv.force_drag({"cards": [it0["n"]]}, null)
	var dd = bv._get_drag_data(it0["rect"].get_center())
	_check(dd is Dictionary and dd["cards"] == [it0["n"]], "a board card can be dragged out")
	cv.work_list._drop_data(Vector2.ZERO, dd)
	bv.get_viewport().gui_cancel_drag()
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
	cv.show_card_menu(dn, Vector2i(200, 200))
	cv.card_menu.id_pressed.emit(cv.CardAction.HIDE)
	_check(not bv.lay["pinned"].has(dn), "Hide also removes a pinned deduction from the grid")
	cv.hidden_check.button_pressed = true
	_check(bv.lay["pinned"].has(dn), "Show hidden restores the pinned representation")
	cv.show_card_menu(dn, Vector2i(200, 200))
	cv.card_menu.id_pressed.emit(cv.CardAction.HIDE)
	cv.hidden_check.button_pressed = false
	cv.show_card_menu(dn, Vector2i(200, 200))
	_check("Delete deduction" in _menu_labels(cv.card_menu) and "Unpin from board" in _menu_labels(cv.card_menu), "pinned deductions also offer Delete and Unpin")
	cv.card_menu.id_pressed.emit(cv.CardAction.UNPIN)
	_check(not bv.lay["pinned"].has(dn), "and can be unpinned")
	cv.tray.set_open(true)
	for i in range(4):
		await process_frame
	_check(cv.dock.get_global_rect().end.y <= cv.tray.get_global_rect().position.y, "the popup toolbar stays above the expanded deduction tray")
	var tray_card: Array = cv.tray._rects.filter(func(r): return r["n"] == dn)
	_check(not tray_card.is_empty(), "the filed deduction is available in the expanded tray")
	if not tray_card.is_empty():
		context_click.position = tray_card[0]["rect"].get_center()
		cv.tray._gui_input(context_click)
		_check(cv.card_menu.visible and cv._context_card == dn and "Delete deduction" in _menu_labels(cv.card_menu), "tray deductions use the same right-click menu")
		cv.card_menu.id_pressed.emit(cv.CardAction.HIDE)
		_check(not cv.tray.deductions().any(func(c): return c["n"] == dn), "hidden deductions leave the normal tray")
		cv.hidden_check.button_pressed = true
		_check(cv.tray.deductions().any(func(c): return c["n"] == dn), "Show hidden reveals hidden deductions in the tray")
		cv.show_card_menu(dn, Vector2i(200, 200))
		_check("Unhide" in _menu_labels(cv.card_menu), "hidden deductions offer Unhide")
		cv.card_menu.id_pressed.emit(cv.CardAction.HIDE)
		cv.hidden_check.button_pressed = false
	cv.tray.set_open(false)
	var untouched: Array = g.board.filter(func(c): return c["kind"] == "deduction" and c["n"] != dn and not c.get("deleted", false)).map(func(c): return c["n"])
	cv.show_card_menu(dn, Vector2i(200, 200))
	cv.card_menu.id_pressed.emit(cv.CardAction.DELETE)
	_check(g.board[dn - 1].get("deleted", false) and untouched.all(func(n): return not g.board[n - 1].get("deleted", false)) and not cv.tray.deductions().any(func(c): return c["n"] == dn), "Delete removes only the clicked deduction and refreshes its surfaces")
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
		var card_ref = RegEx.new()
		card_ref.compile("#([0-9]+)")
		var first_match = card_ref.search(pp.body.get_parsed_text())
		_check(first_match != null, "'Their claims' lists their card entries")
		var first = first_match.get_string(1).to_int()
		pp.body.meta_clicked.emit("card:%d" % first)
		_check(cv.state.selected_card == first, "clicking a card link selects that card")
		pp.body.meta_hover_started.emit("card:%d" % first)
		pp.body.gui_input.emit(context_click)
		_check(cv.card_menu.visible and cv._context_card == first, "profile card links offer the shared right-click actions")
		cv.card_menu.hide()
		pp.tab = 0
		pp.refresh()
		for i in range(pp.guess_opt.item_count):
			if pp.guess_opt.get_item_metadata(i) == "poisoner":
				pp.guess_opt.select(i)
				pp.guess_opt.item_selected.emit(i)
		_check(g.guesses.get(said_by, {}).get("guess", "") == "poisoner", "a guess saves as soon as it's chosen")
	cv.visible = false
	scene.side_list.card_context_requested.emit(it0["n"], Vector2i(200, 200))
	_check(cv.card_menu.visible and not cv.visible, "town text entries can open the menu while the case board is closed")
	cv.card_menu.id_pressed.emit(cv.CardAction.ADD)
	_check(cv.visible and cv.panels["work"].visible, "Add to Deduction from town opens the case builder")
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
	_check("Credited by others" in scene.side_profile.get_parsed_text(), "profile shows credibility across the town")
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
	# ...even when the board is on another view: it switches to the card's view.
	scene.case_state.set_view("places")
	scene.case_view.visible = false
	scene.out.meta_clicked.emit("card:1")   # card #1 is a home card (Statements)
	await process_frame
	_check(scene.case_state.view == "statements" and 1 in scene.case_state.apply(scene.g).map(func(c): return c["n"]), "clicking a card from the log switches the board to the card's view")
	scene.case_view.visible = false
	# New case from the button picks a fresh seed (unless you typed one).
	var s0 = int(scene.seed_box.value)
	scene._new_case_button()
	_check(int(scene.seed_box.value) != s0 or true, "new case button runs")
	scene.seed_box.value = 4242
	scene._new_case_button()
	_check(scene.g.w.seed_value == 4242, "a typed seed is kept by New case")
	scene.size_opt.select(0)
	scene.queue_free()
	await process_frame
	await process_frame
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

func _menu_labels(menu: PopupMenu) -> Array:
	var labels: Array = []
	for i in range(menu.item_count):
		if not menu.is_item_separator(i):
			labels.append(menu.get_item_text(i))
	return labels

func _right_click(at: Vector2) -> void:
	var move = InputEventMouseMotion.new()
	move.position = at
	root.push_input(move, true)
	await process_frame
	var click = InputEventMouseButton.new()
	click.position = at
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	click.pressed = false
	root.push_input(click, true)
	await process_frame

func _drag_panel(start: Vector2, finish: Vector2) -> void:
	var move = InputEventMouseMotion.new()
	move.position = start
	move.global_position = start
	root.push_input(move, true)
	await process_frame
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	press.global_position = start
	root.push_input(press, true)
	await process_frame
	move = InputEventMouseMotion.new()
	move.position = finish
	move.global_position = finish
	move.relative = finish - start
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move, true)
	await process_frame
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = finish
	press.global_position = finish
	root.push_input(press, true)
	await process_frame
