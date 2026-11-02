## Acceptance and regression suite for Legacy Purge Phase 3:
##   1. Game.workshop_effects, set_workshop_effects, UI Debug toggles, --native, and recompute_beliefs removed.
##   2. Gravedigger report with no matching public execution on that night is ready, impossible for a good reader, and catches the lying claimant.
##   3. Unprepared refreshes keep the NPC's last good shared suspicion vector (plus outside adjustments) and log the fallback issue.
##   4. Multi-day shared-mode play reaches Day 4 across fixed seeds with 0 fallbacks and idempotent refresh_beliefs.
##
##   godot --headless --path . --script res://tools/test_legacy_purge_phase3.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const LiveCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const LiveCaseWorkshop = preload("res://ui/live_case_workshop.gd")
const WorkshopComparison = preload("res://ui/workshop_comparison.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _close_dict(a: Dictionary, b: Dictionary, eps: float = 0.000001) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or absf(float(a[k]) - float(b[k])) > eps:
			return false
	return true


func _clean_game(seed_val: int, size: int = 7):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_val, size)
	for p in g.w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.applied_info = 0
			m.known_claims = {}
			m.beliefs = []
			m.hearsay = []
			m.ledger = {}
			m.resentments = []
			m.settled_execution_rapport = {}
			m.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
			if not m.is_evil():
				Mind.refresh_beliefs(g.w, m, " (clean)")
	return g


func _init() -> void:
	_test_switch_debug_and_recompute_removed()
	_test_gravedigger_missing_execution_ready_and_catches_liar()
	_test_unready_refresh_keeps_last_good_vector_and_logs()
	_test_multi_day_shared_play_zero_fallbacks()
	print("Legacy Purge Phase 3: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_switch_debug_and_recompute_removed() -> void:
	var game_props: Array = Game.get_script_property_list().map(func(p): return str(p.name))
	var game_methods: Array = Game.get_script_method_list().map(func(m): return str(m.name))
	_check("workshop_effects" not in game_props and "set_workshop_effects" not in game_methods,
		"Game.workshop_effects and Game.set_workshop_effects are deleted")

	var mind_methods: Array = Mind.get_script_method_list().map(func(m): return str(m.name))
	var meeting_methods: Array = MindMeeting.get_script_method_list().map(func(m): return str(m.name))
	_check("recompute_beliefs" not in mind_methods and "_recompute_beliefs" not in mind_methods and "refresh_beliefs" in mind_methods,
		"Mind.recompute_beliefs renamed to Mind.refresh_beliefs")
	_check("recompute_beliefs" not in meeting_methods and "refresh_beliefs" in meeting_methods,
		"MindMeeting.recompute_beliefs renamed to MindMeeting.refresh_beliefs")

	_check(not LiveCaseWorkshop.DebugItem.has("EFFECTS"),
		"LiveCaseWorkshop Debug menu no longer exposes EFFECTS toggle")
	var comp_props: Array = WorkshopComparison.get_script_property_list().map(func(p): return str(p.name))
	_check("effects_toggle" not in comp_props,
		"WorkshopComparison inspector no longer exposes effects_toggle")

	var autoplay_src: String = FileAccess.get_file_as_string("res://tools/autoplay.gd")
	_check(not ("--native" in autoplay_src) and not ("set_workshop_effects" in autoplay_src),
		"tools/autoplay.gd drops --native mode and set_workshop_effects")


func _test_gravedigger_missing_execution_ready_and_catches_liar() -> void:
	var g = _clean_game(692, 7)
	var goods: Array = g.w.living_good()
	var listener = goods[0]
	var faker = goods[1]
	var innocent = goods[2]
	listener.role = "warden"
	Mind.refresh_beliefs(g.w, listener, " (warden role)")

	# No execution occurred on Day 1: faker claims a Night 1 Gravedigger reading on innocent anyway.
	g.shared_fallbacks.clear()
	var bogus_entry = {"day": 1, "phase": 3, "role": "gravedigger", "data": {"executed": innocent.id, "role": "poisoner"}, "text": "dug up %s as Poisoner" % innocent.name}
	Mind.apply_info(g.w, listener, faker, bogus_entry, 0.8)

	_check(g.shared_fallbacks.is_empty() and listener.workshop_state.get("active", false) and listener.workshop_state.get("issues", []).is_empty(),
		"Gravedigger report with no matching public execution refreshes cleanly with 0 fallbacks")
	_check(is_equal_approx(float(listener.workshop_state.get("source_doubt", {}).get(faker.id + ":*", 0.0)), 1.0),
		"SourceDoubt marks claimant of unexecuted Gravedigger report as caught liar (source:* = 1.0)")
	_check(float(listener.workshop_state.get("requested", {}).get(faker.id, 0.0)) > 0.25,
		"Shared world model convicts bogus Gravedigger claimant since no good reader can invent a hanging (got %.3f)" % float(listener.workshop_state.get("requested", {}).get(faker.id, 0.0)))
	_check(float(listener.workshop_state.get("requested", {}).get(innocent.id, 0.0)) <= 0.05,
		"Bogus Gravedigger report without execution does not convict its named subject (got %.3f)" % float(listener.workshop_state.get("requested", {}).get(innocent.id, 0.0)))

	var reasons: Array = Mind.case_against(g.w, listener, faker.id)
	_check(not reasons.is_empty() and "no such hanging" in str(reasons[0].get("why", "")),
		"ReasonAttribution cites bogus Gravedigger report with no matching hanging (%s)" % str(reasons))

	var card_num: int = g.add_card({"kind": "info", "source": faker.id, "role": "gravedigger", "day": 1, "phase": 3, "data": bogus_entry.data, "text": bogus_entry.text})
	var fact_id: String = LiveCanvas.Evidence.normalize_card(g.board[card_num - 1]).id
	var board_accuse_subject = CanvasModel.new(LiveCanvas.view(g))
	board_accuse_subject.nodes[board_accuse_subject.selected].conclusion.target = innocent.id
	board_accuse_subject.connect_cards("e:" + fact_id, board_accuse_subject.selected)
	var val_subj = board_accuse_subject.compile(board_accuse_subject.selected)
	_check(LiveCanvas.status(g, val_subj).ready,
		"Live canvas case citing Gravedigger report without execution is ready")
	var ghost_subj = Ghost.live(LiveCanvas.snapshot(g, val_subj))
	_check(ghost_subj.ready and ghost_subj.proposal.assessment.compatible == 0,
		"Ghost juror finds 0 compatible worlds when accepting an unexecuted Gravedigger report as true")

	var board_accuse_liar = CanvasModel.new(LiveCanvas.view(g))
	board_accuse_liar.nodes[board_accuse_liar.selected].conclusion.target = faker.id
	board_accuse_liar.connect_cards("e:" + fact_id, board_accuse_liar.selected)
	var filed_liar: int = LiveCanvas.file(g, board_accuse_liar.compile(board_accuse_liar.selected))
	var fresh_listener = goods[3]
	var resp: Dictionary = g._evaluate_deduction(fresh_listener, g.board[filed_liar - 1], 1.0, false)
	_check(resp.get("workshop", false) and float(fresh_listener.workshop_state.get("requested", {}).get(faker.id, 0.0)) > 0.25,
		"Presenting bogus Gravedigger report against its claimant succeeds via shared presentation")


func _test_unready_refresh_keeps_last_good_vector_and_logs() -> void:
	var g = _clean_game(692, 7)
	var goods: Array = g.w.living_good()
	var listener = goods[0]
	var src = goods[1]
	var target_a = goods[2]
	var target_b = goods[3]

	var dowse = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [target_a.id, target_b.id], "count": 2}, "text": "both read as evil"}
	Mind.apply_info(g.w, listener, src, dowse, 0.8)
	_check(listener.workshop_state.get("active", false) and float(listener.workshop_state.get("requested", {}).get(target_a.id, 0.0)) > 0.15,
		"Initial supported Dowser refresh produces non-trivial shared suspicion vector")

	var last_good_susp: Dictionary = listener.suspicion.duplicate(true)
	var last_good_req: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
	var last_good_act: Dictionary = listener.workshop_state.get("action", {}).duplicate(true)

	# Inject malformed bare curse public event (missing vote/execution) to force Shared.prepare unready.
	g.shared_fallbacks.clear()
	g.w.public_log.append({"day": 1, "kind": "curse", "subjects": [target_a.id], "by": "town"})
	Mind.refresh_beliefs(g.w, listener, " (forced unready refresh)")

	_check(listener.workshop_state.get("active", false) and _close_dict(listener.suspicion, last_good_susp),
		"Unready refresh keeps the NPC's last good shared suspicion vector intact")
	_check(_close_dict(listener.workshop_state.get("requested", {}), last_good_req) and listener.workshop_state.get("action", {}) == last_good_act,
		"Unready refresh preserves last good requested vector and action scores")
	_check(not g.shared_fallbacks.is_empty() and not listener.workshop_state.get("issues", []).is_empty(),
		"Unready refresh logs the issue in g.shared_fallbacks and workshop_state.issues")

	# Outside adjustments while unready are preserved cleanly once the chronology issue clears.
	Mind.adjust(g.w, listener, target_a.id, 0.07, "outside test bump", "", false)
	_check(is_equal_approx(listener.suspicion[target_a.id], last_good_susp[target_a.id] + 0.07),
		"Mind.adjust updates outside and total cleanly while holding last good shared vector")
	g.w.public_log.clear()
	Mind.refresh_beliefs(g.w, listener, " (recovered refresh)")
	_check(listener.workshop_state.get("issues", []).is_empty() and is_equal_approx(float(listener.workshop_state.get("outside", {}).get(target_a.id, 0.0)), 0.17),
		"Recovering from an unready refresh retracts the kept vector once with zero baseline drift")


func _test_multi_day_shared_play_zero_fallbacks() -> void:
	var all_clean: bool = true
	for sd in [37291, 42, 54875, 900]:
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(sd, 7)
		var guard: int = 0
		while g.state != "over" and g.w.day < 4 and guard < 120:
			guard += 1
			if g.state == "approach":
				g.command("decline")
			elif g.state == "day":
				g.command("wait")
			elif g.state == "meeting":
				g.command("pass")
			elif g.state == "nomination":
				g.command("vote no")
			elif g.state == "night":
				g.command("sleep")
			else:
				break
		if not g.shared_fallbacks.is_empty():
			all_clean = false
		for p in g.w.living_good():
			if not p.workshop_state.get("active", false):
				all_clean = false
			var snap_before: Dictionary = p.suspicion.duplicate(true)
			Mind.refresh_beliefs(g.w, p, " (idempotence check)")
			if not _close_dict(snap_before, p.suspicion):
				all_clean = false
	_check(all_clean, "4 multi-day 7-NPC seeds reach Day 4 with 0 fallbacks, active shared state, and idempotent refresh_beliefs")
