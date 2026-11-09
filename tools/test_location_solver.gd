## The day log and the location solver (docs/demon_types_plan.md, "Whereabouts"): watches
## make one hidden receipt per day; listeners hear the roster only through a cited log; the
## solver sorts people into fits / unknown / ruled out.
##   godot --headless --path . --script res://tools/test_location_solver.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const DayPresence = preload("res://workshop/day_presence.gd")
const LocationSolver = preload("res://workshop/location_solver.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const CaseView = preload("res://ui/case_view.gd")
const UITheme = preload("res://ui/theme.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _logs(g) -> Array:
	return g.profile_receipts.filter(func(c): return c.get("kind", "") == "watch_log")


func _run() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	g.start_day() if g.has_method("start_day") else null
	g.command("go smithy")
	_check(g.watched.size() == 1 and _logs(g).size() == 1, "a watch makes the day's log")
	var log0: Dictionary = _logs(g)[0] if not _logs(g).is_empty() else {}
	_check(log0.get("watches", []).size() == 1 and int(log0.get("day", -1)) == g.w.day, "the log holds the day's watch")
	_check(not g.board.any(func(c): return c.get("kind", "") == "watch_log"), "the log is hidden: no board card")

	# The Demonologist's own view: the raw record and the log card.
	var pview: Dictionary = WorkshopCanvas.view(g)
	var logs_in_view: Array = pview.get("cards", []).filter(func(c): return c.get("kind", "") == "watch_log")
	_check(logs_in_view.size() == 1 and logs_in_view[0].data.watches.size() == 1, "the canvas view carries the log as one card")
	_check(DayPresence.watches(pview, pview.cards).size() == 1, "the view's watches and its log count once")

	# A listener hears nothing of it uncited.
	var n = g.w.living_good()[0]
	var lview: Dictionary = Assess.prepare(WorkshopBridge.capture(g, [], n.id)).get("view", {})
	_check(lview.get("watched", []).is_empty(), "a listener's view has no free watch record")
	_check(DayPresence.watches(lview, lview.get("cards", [])).is_empty(), "nor a log they weren't shown")
	var cited: Dictionary = Assess.prepare(WorkshopBridge.capture(g, [int(log0.get("n", 0))], n.id)).get("view", {})
	_check(DayPresence.watches(cited, cited.get("cards", [])).size() == 1, "citing the log hands the listener the roster")

	# The solver: who was at the smithy this day.
	var day: int = g.w.day
	var roster: Array = log0.watches[0].at.get("smithy", [])
	var res: Dictionary = LocationSolver.evaluate(pview, {"kind": "place", "day": day, "loc": "smithy"})
	var morning: String = log0.watches[0].phase
	var ph: int = DayPresence.phase_index(morning)
	_check(roster.all(func(pid): return pid in res.fits), "everyone seen at the smithy fits (%d)" % roster.size())
	var row_ok: bool = true
	for r in res.rows:
		if r.id in roster:
			row_ok = row_ok and r.cells[ph].state == "seen"
		elif r.alive:
			row_ok = row_ok and r.cells[ph].state in ["seen", "work", "absent"]
	_check(row_ok, "the watched phase shows everyone as seen, at work elsewhere or off the block")
	_check(res.log_ids.size() == 1 and res.log_ids[0] == logs_in_view[0].id, "the answer cites the day's log")

	# A second watch the same day grows the log (a new, larger receipt).
	g.command("wait")
	g.command("go wharf")
	_check(_logs(g).size() == 2 and LocationSolver.day_log(WorkshopCanvas.view(g).cards, day).data.watches.size() == 2, "a second watch makes a fuller log, and the solver takes the latest")

	# Ruled out: someone at work elsewhere all day, with every free phase watched off-block, is
	# rare in play; check the rule itself on a hand view.
	var hv: Dictionary = {"day": 1, "people": [
		{"id": "a", "name": "A", "home": "hill", "alive": true, "work": "smithy", "work_phases": [0, 1, 2]},
		{"id": "b", "name": "B", "home": "hill", "alive": true, "work": "mill", "work_phases": [0, 1, 2]},
		{"id": "v", "name": "V", "home": "docks", "alive": false, "work": "wharf", "work_phases": [0, 1]}],
		"cards": [], "timeline": {"events": [{"kind": "demon_death", "subjects": ["v"], "at": {"day": 1, "phase": "night"}}], "deaths": {"v": 1}},
		"watched": []}
	var kq: Dictionary = {"kind": "kill", "day": 1, "victim": "v"}
	_check(LocationSolver.questions(hv) == [kq], "a demon death offers the kill question")
	var kr: Dictionary = LocationSolver.evaluate(hv, kq)
	_check(kr.places == ["wharf"] and kr.unknown_haunts == 2, "the victim's places: the workplace, two haunts unknown")
	_check(kr.ruled_out == ["a", "b"], "workers elsewhere all day are ruled out for a hex at the wharf")
	hv.people[1].work = "wharf"
	_check(LocationSolver.evaluate(hv, kq).fits == ["b"], "a coworker at the victim's workplace fits")

	# The workshop node cites the log in one card.
	var board = CanvasModel.new(WorkshopCanvas.view(g))
	var nid: String = board.add_whereabouts({"kind": "place", "day": day, "loc": "smithy"})
	_check(nid != "" and board.nodes[nid].kind == "whereabouts", "a Whereabouts node joins the canvas")
	if nid != "":
		_check(board._evidence([nid]) == board.nodes[nid].log_ids + board.nodes[nid].report_ids, "it cites the log and the reports, nothing else")
		var root: String = board.selected
		for k in board.nodes:
			if board.nodes[k].kind == "premise":
				root = k
		board.nodes[root].conclusion = {"type": "evil", "target": g.w.living()[1].id, "at": board.view.alignment_epoch}
		board.connect_cards(nid, root)
		var compiled: Dictionary = board.compile(root)
		_check(board.nodes[nid].log_ids.all(func(cid): return cid in compiled.cards), "a case built on it carries the log")
		var Ghost = preload("res://workshop/ghost_juror.gd")
		var ghost: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, compiled))
		_check(ghost.get("ready", false), "the case evaluates (%s)" % str(ghost.get("issues", [])))
		var filed: int = WorkshopCanvas.file(g, compiled)
		_check(filed > 0, "and files")
		var hearer = g.w.living_good()[2]
		g._evaluate_deduction(hearer, g.board[filed - 1], 1.0, false)
		var Shared = preload("res://workshop/shared_ledger.gd")
		var plan: Dictionary = Shared.prepare(WorkshopBridge.capture(g, [], hearer.id), hearer.workshop_state.get("presentations", {}), hearer.ledger, hearer.workshop_state.get("withdrawn", {}), [])
		var hv2: Dictionary = plan.get("prepared", {}).get("view", {})
		_check(DayPresence.watches(hv2, hv2.get("cards", [])).size() == 2, "a listener who heard the case keeps the day's roster")
		var session = preload("res://workshop/session.gd").new()
		session.scenario = {"public_view": board.view}
		var copy = CanvasModel.new(board.view)
		var r_err: String = copy.restore(board.export_data(), session)
		_check(r_err == "" and copy.nodes.has(nid), "the canvas restores with the node (%s)" % r_err)

	await _test_ui()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The panel in the Case Board, and committing from it. `--screenshot PATH` saves the panel.
func _test_ui() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	g.start_day() if g.has_method("start_day") else null
	g.command("go tavern")
	g.command("wait")
	g.command("go smithy")
	var cv = CaseView.new()
	cv.workshop_execute = func(_cmd, _prog): pass
	root.add_child(cv)
	cv.build(UITheme.serif())
	await process_frame
	cv.set_game(g)
	cv.size = Vector2(1600, 900)
	for i in range(3):
		await process_frame
	_check(cv.panels.has("whereabouts") and cv.panel_buttons.has("whereabouts") and cv.location_solver != null, "the Case Board has a Whereabouts panel and dock button")
	cv.set_panel_open("whereabouts", true)
	var panel = cv.location_solver
	panel.set_question({"kind": "place", "day": g.w.day, "loc": "tavern"})
	_check(not panel.commit_btn.disabled and panel.last_result.rows.size() == g.w.npcs.size(), "a watched day enables Commit, a row per person")
	_check(panel.place_pick.visible and panel.day_pick.visible, "a place question shows the place and day pickers")
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var si: int = args.find("--screenshot")
	if si >= 0 and si + 1 < args.size():
		for i in range(3):
			await process_frame
		root.get_texture().get_image().save_png(args[si + 1])
	panel.commit_requested.emit(panel.question.duplicate(true))
	await process_frame
	var editor = cv.workshop.editor
	var keys: Array = editor.board.nodes.keys().filter(func(k): return editor.board.nodes[k].kind == "whereabouts")
	_check(keys.size() == 1, "committing adds a Whereabouts card to the Workshop")
	if keys.size() == 1:
		editor.remove_node(keys[0])
		_check(not editor.board.nodes.has(keys[0]), "the Workshop removes it")
		editor._undo_remove()
		_check(editor.board.nodes.has(keys[0]), "and undo restores it")
	cv.queue_free()
	await process_frame
