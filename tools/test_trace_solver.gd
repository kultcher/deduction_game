## Automated test suite for TraceSolver combinatorics/pigeonhole math,
## pure-location trace generation, CanvasModel `trace_chain` bundling/restore,
## PortraitBadge grayscale desaturation, and TraceSolverPanel UI integration.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const TraceSolver = preload("res://workshop/trace_solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const TraceSolverPanel = preload("res://ui/trace_solver_panel.gd")
const CaseView = preload("res://ui/case_view.gd")
const UITheme = preload("res://ui/theme.gd")

var checks: int = 0
var fails: int = 0


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		push_error("FAIL: " + msg)


func _game(seed_val: int = 3101, size: int = 7):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_val, size)
	return g


func _init() -> void:
	_test_pure_location_trace_generation()
	_test_matrix_rows_scion_divider_and_portrait_states()
	_test_trace_chain_canvas_node_compile_and_restore()
	await _test_trace_solver_panel_and_case_view_ui()
	if fails == 0:
		print("test_trace_solver: ALL %d CHECKS PASSED" % checks)
		quit(0)
	else:
		printerr("test_trace_solver: %d/%d FAILED" % [fails, checks])
		quit(1)


func _test_pure_location_trace_generation() -> void:
	_check(is_zero_approx(Tuning.Setup.TRACE_QUARTER_BASE_WEIGHT) and is_zero_approx(Tuning.Setup.TRACE_CONNECTION_BASE_WEIGHT), "quarter and connection trace base weights are 0.0")
	var all_locations_only: bool = true
	var total_rolled: int = 0
	for sd in range(3200, 3260):
		var g = _game(sd, 10 if sd % 2 == 0 else 7)
		var w = g.w
		var victims: Array = w.living_good().slice(0, 2)
		for step in range(victims.size()):
			w.day = step + 1
			w._kill(victims[step])
			for tr in w.scenes["scene_" + victims[step].id]["traces"]:
				total_rolled += 1
				if tr.get("trace_family", "") != "locations":
					all_locations_only = false
	_check(total_rolled >= 120 and all_locations_only, "100% of generated crime-scene traces across 60 seeds are locations tokens/scents")


func _test_matrix_rows_scion_divider_and_portrait_states() -> void:
	var g = _game(3102, 7)
	var w = g.w
	var v1 = w.npcs[0]
	var v2 = w.npcs[1]
	var hung_p = w.npcs[2]
	var full_match = w.npcs[3]
	var gray_match = w.npcs[4]
	var gray_pigeonhole_out = w.npcs[5]
	var gray_unresolved = w.npcs[6]

	# Configure workplaces and true haunts
	full_match.work = "bakery"
	full_match.haunts = ["chapel", "mill"]
	gray_match.work = "bakery"
	gray_match.haunts = ["well", "graveyard"]
	gray_pigeonhole_out.work = "smithy"
	gray_pigeonhole_out.haunts = ["well", "mill"]
	gray_unresolved.work = "smithy"
	gray_unresolved.haunts = ["bakery", "graveyard"]
	hung_p.work = "tavern"
	hung_p.haunts = ["wharf", "mill"]

	g.profile_receipts.clear()
	g._profile_card_keys.clear()
	g._profile_fact_keys.clear()
	g._home_cards()

	# Reveal both haunts for full_match (3/3 -> full color), 0 haunts for gray_match (1/3 -> grayscale + green check!),
	# 1 non-matching haunt ("well") for gray_pigeonhole_out (2/3 -> only 1 unknown slot left!), and 0 haunts for gray_unresolved (1/3 -> ?).
	for hl in full_match.haunts:
		g.add_profile_receipt({"kind": "haunt", "subject": [full_match.id], "source": "town", "loc": hl, "locs": [hl], "block": w.loc_block(hl), "day": 1, "phase": 0, "text": "%s visits %s" % [full_match.id, hl]})
	g.add_profile_receipt({"kind": "haunt", "subject": [gray_pigeonhole_out.id], "source": "town", "loc": "well", "locs": ["well"], "block": w.loc_block("well"), "day": 1, "phase": 0, "text": "%s visits well" % gray_pigeonhole_out.id})

	# Night 1 murder (1 trace -> matrix should start at max_rows == 1)
	w.day = 1
	v1.alive = false
	w.public_event("demon_death", [v1.id], "town")
	var t1_n: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": v1.id, "scene": "scene_" + v1.id, "scene_block": v1.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing",
		"text": "At %s's scene: a grease-darkened brass farthing (the Bakery or the Tavern)." % v1.name,
	})
	var view1: Dictionary = WorkshopCanvas.view(g)
	var mat1: Dictionary = TraceSolver.build_matrix(view1)
	_check(mat1.max_rows == 1 and mat1.columns.size() == 1, "single-trace nights build a 1-row matrix")

	# Day 2 Evening execution of hung_p (6 NPCs alive before hanging >= 5 -> potential Scion handoff!)
	w.day = 2
	hung_p.alive = false
	w.public_event("execution", [hung_p.id], "town")

	# Night 2 murder with TWO traces (expands matrix to max_rows == 2, and sits right after Day 2 hanging!)
	v2.alive = false
	w.public_event("demon_death", [v2.id], "town")
	var t2a_n: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 2, "phase": C.EVENING, "crime_night": 2,
		"victim": v2.id, "scene": "scene_" + v2.id, "scene_block": v2.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 2,
		"locs": ["bakery", "chapel"], "item_label": "a stamped wafer-iron brass pin",
		"text": "At %s's scene: a stamped wafer-iron brass pin (the Bakery or the Chapel)." % v2.name,
	})
	var t2b_n: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 2, "phase": C.EVENING, "crime_night": 2,
		"victim": v2.id, "scene": "scene_" + v2.id, "scene_block": v2.home_block,
		"trace_family": "locations", "trace_subtype": "scent", "trace_slot": 1, "scene_trace_count": 2,
		"locs": ["chapel", "wharf", "graveyard"], "item_label": "tarred rope and church-incense",
		"text": "At %s's scene: scent of tarred rope and church-incense (the Chapel, the Wharf, or the Graveyard)." % v2.name,
	})

	var view2: Dictionary = WorkshopCanvas.view(g)
	var mat2: Dictionary = TraceSolver.build_matrix(view2)
	_check(mat2.max_rows == 2 and mat2.columns.size() == 2, "two-trace scene expands matrix to 2 rows across 2 night columns")
	_check(mat2.scion_dividers.size() == 1 and int(mat2.scion_dividers[0].exec_day) == 2 and mat2.scion_dividers[0].executed_id == hung_p.id, "Scion handoff divider appears between Night 1 and Night 2 after Day 2 hanging with >= 5 alive")

	# Select Night 1 {bakery, tavern} + Night 2 Row 1 {chapel, wharf, graveyard} (DISJOINT sets for gray_pigeonhole_out, while bakery+chapel vs bakery+tavern hits Bakery!)
	# Wait: first test Night 1 {bakery, tavern} + Night 2 Row 0 {bakery, chapel}:
	var t1_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t1_n - 1]).id
	var t2a_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t2a_n - 1]).id
	var t2b_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t2b_n - 1]).id

	var ev_both_bakery: Dictionary = TraceSolver.evaluate_selection(view2, {1: t1_id, 2: t2a_id})
	var by_id_1: Dictionary = {}
	for e in ev_both_bakery.all_entries:
		by_id_1[e.id] = e
	_check(not by_id_1.has(v1.id) and not by_id_1.has(v2.id) and ev_both_bakery.excluded_victims.size() == 2, "Demon murder victims are excluded from suspect strip")
	_check(by_id_1[full_match.id].full_profile and not by_id_1[full_match.id].grayscale and by_id_1[full_match.id].fit == "matches", "3/3 known suspect matching all selected traces is Full Color + Green Check")
	_check(by_id_1[gray_match.id].grayscale and by_id_1[gray_match.id].fit == "matches", "1/3 known suspect whose workplace hits all selected traces is Grayscale + Green Check")
	_check(by_id_1[gray_unresolved.id].grayscale and by_id_1[gray_unresolved.id].fit == "unknown", "1/3 known suspect who could still bridge both traces via unknown haunts is Grayscale + Question Mark")
	_check(by_id_1[hung_p.id].executed and by_id_1[hung_p.id].fit == "contradicts", "executed person is ruled out for a single-killer chain spanning a post-execution murder night")

	# Select only pre-execution Night 1 {bakery, tavern}: hung_p works at Tavern -> matches pre-execution Night 1!
	var ev_pre_only: Dictionary = TraceSolver.evaluate_selection(view2, {1: t1_id})
	var hung_pre: Dictionary = ev_pre_only.all_entries.filter(func(e): return e.id == hung_p.id)[0]
	_check(hung_pre.executed and hung_pre.fit == "matches", "selecting only pre-execution nights lets player check if the executed suspect matched earlier traces")

	# Now select DISJOINT traces Night 1 {bakery, tavern} + Night 2 Row 1 {chapel, wharf, graveyard}:
	# gray_pigeonhole_out has work="smithy" and 1 known haunt="well" (2/3 known -> ONLY 1 unknown haunt left!),
	# and {bakery, tavern} intersect {chapel, wharf, graveyard} == empty -> ruled out by pigeonhole even while grayscale!
	var ev_disjoint: Dictionary = TraceSolver.evaluate_selection(view2, {1: t1_id, 2: t2b_id})
	var ph_entry: Dictionary = ev_disjoint.all_entries.filter(func(e): return e.id == gray_pigeonhole_out.id)[0]
	_check(ph_entry.grayscale and ph_entry.known_count == 2 and ph_entry.fit == "contradicts", "2/3 known suspect missing two disjoint traces is ruled out (Red X) by pigeonhole math")


func _test_trace_chain_canvas_node_compile_and_restore() -> void:
	var g = _game(3105, 7)
	for sd in range(3105, 3150):
		g = _game(sd, 7)
		if not g.w.npcs.any(func(p): return p.id == "constance"):
			break
	var w = g.w
	var v1 = w.living_good()[0]
	var suspect = w.living_good()[1]
	var cleared_p = w.living_good()[2]
	var walker = w.living_good()[3]
	suspect.work = "bakery"
	suspect.haunts = ["chapel", "mill"]
	cleared_p.work = "smithy"
	cleared_p.haunts = ["well", "graveyard"]
	walker.work = "wharf"
	walker.haunts = ["well", "graveyard"]

	g.profile_receipts.clear()
	g._profile_card_keys.clear()
	g._profile_fact_keys.clear()
	g._home_cards()
	for p in [cleared_p, walker]:
		for hl in p.haunts:
			g.add_profile_receipt({"kind": "haunt", "subject": [p.id], "source": "town", "loc": hl, "locs": [hl], "block": w.loc_block(hl), "day": 1, "phase": 0, "text": "Haunt"})

	w.day = 1
	v1.alive = false
	w.public_event("demon_death", [v1.id], "town")
	g.add_card({"kind": "death", "source": "player", "subject": [v1.id], "day": 1, "phase": C.NIGHT, "night": 1, "block": v1.home_block, "text": "Death"})
	var t1_n: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": v1.id, "scene": "scene_" + v1.id, "scene_block": v1.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 2,
		"locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing",
		"text": "Trace 1: farthing.",
	})
	var t2_n: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": v1.id, "scene": "scene_" + v1.id, "scene_block": v1.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 1, "scene_trace_count": 2,
		"locs": ["chapel", "wharf"], "item_label": "a salt-dulled alms-box copper piece",
		"text": "Trace 2: copper piece.",
	})
	var vig_n: int = g.add_card({"kind": "sighting", "source": "player", "subject": [walker.id], "day": 1, "phase": C.NIGHT, "block": v1.home_block, "text": "Saw walker on kill block"})

	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var root_id: String = model.selected
	model.nodes[root_id].conclusion = {"type": "evil", "target": suspect.id, "at": view.alignment_epoch}
	var t1_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t1_n - 1]).id
	var t2_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t2_n - 1]).id
	var vig_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[vig_n - 1]).id

	var tc_id: String = model.add_trace_chain({1: t1_id})
	_check(tc_id != "" and model.nodes.has(tc_id) and model.nodes[tc_id].kind == "trace_chain", "CanvasModel adds bundled trace_chain node")
	_check(t2_id in model.nodes[tc_id].sibling_trace_ids, "trace_chain bundles sister trace from 2-trace scene so walker sightings unlock full subtraction")
	model.connect_cards(tc_id, root_id)
	model.connect_cards("e:" + vig_id, root_id)
	var compiled: Dictionary = model.compile(root_id)
	_check(t1_id in compiled.cards and t2_id in compiled.cards and not model.nodes[tc_id].receipt_ids.is_empty(), "compiled premise includes selected trace, sister scene trace, and discovered location receipts from one node")

	var ghost: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, compiled))
	_check(ghost.ready and ghost.proposal.effects[suspect.id].requested > ghost.proposal.effects[cleared_p.id].requested, "bundled trace_chain + walker sighting evaluates cleanly in CaseEval and favors matching suspect")
	var filed: int = WorkshopCanvas.file(g, compiled)
	_check(filed > 0, "case built with bundled trace_chain node files cleanly")

	# Export & restore without constance in cast
	var session = preload("res://workshop/session.gd").new()
	session.scenario = {"public_view": view}
	var copy = CanvasModel.new(view)
	var r_err: String = copy.restore(model.export_data(), session)
	_check(r_err == "" and copy.nodes.has(tc_id), "CanvasModel.restore validates trace_chain nodes cleanly")
	model.remove_trace_chain(tc_id)
	_check(not model.nodes.has(tc_id), "remove_trace_chain deletes node and cleans links")


func _test_trace_solver_panel_and_case_view_ui() -> void:
	var g = _game(3108, 7)
	var v1 = g.w.living_good()[0]
	g.w.day = 1
	v1.alive = false
	g.w.public_event("demon_death", [v1.id], "town")
	var t_num: int = g.add_card({
		"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": v1.id, "scene": "scene_" + v1.id, "scene_block": v1.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing",
		"text": "Trace: farthing.",
	})
	var t_id: String = WorkshopCanvas.Evidence.normalize_card(g.board[t_num - 1]).id

	var cv = CaseView.new()
	cv.workshop_execute = func(_cmd, _prog): pass
	root.add_child(cv)
	cv.build(UITheme.serif())
	await process_frame
	cv.set_game(g)
	await process_frame

	_check(cv.panels.has("traces") and cv.panel_buttons.has("traces") and cv.trace_solver != null, "CaseView registers Trace Solver dock button and BoardPanel")
	cv.set_panel_open("traces", true)
	_check(cv.panels["traces"].visible and cv.trace_solver.commit_btn.disabled, "Trace Solver opens with Commit disabled before toggling a trace")
	cv.trace_solver.toggle_trace(1, t_id)
	_check(not cv.trace_solver.commit_btn.disabled and cv.trace_solver.selected_by_night.get(1, "") == t_id, "toggling Night 1 trace enables Commit button")
	_check("selection" in cv.trace_solver.legend_label.text and "passer" in cv.trace_solver.intro_label.text, "panel explains that fit depends on selected traces and a trace may be a passer's")
	cv.trace_solver.toggle_trace(1, t_id)
	_check(cv.trace_solver.selected_by_night.is_empty() and cv.trace_solver.commit_btn.disabled, "toggling a selected trace again leaves its night empty")
	cv.trace_solver.toggle_trace(1, t_id)
	cv.trace_solver._on_commit()
	await process_frame
	var editor = cv.workshop.editor
	var has_tc: bool = editor.board.nodes.values().any(func(n): return n.kind == "trace_chain")
	_check(has_tc and t_num in cv.selected_cards(), "committing from Trace Solver opens Workshop, creates trace_chain node, and marks trace card staged on Case Board")
	var tc_key: String = editor.board.nodes.keys().filter(func(k): return editor.board.nodes[k].kind == "trace_chain")[0]
	editor.remove_node(tc_key)
	_check(not editor.board.nodes.has(tc_key), "LiveCaseWorkshop removes trace_chain node cleanly")
	editor._undo_remove()
	_check(editor.board.nodes.has(tc_key), "LiveCaseWorkshop undo restores removed trace_chain node")

	cv.queue_free()
	await process_frame
