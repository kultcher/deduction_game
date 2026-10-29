## Slice 3 tests: additive passer second trace, post-shuffle slot symmetry,
## joint (T1, T2) / (T2, T1) scene evaluation (explained walker subtraction vs. ambiguous walker),
## 1-of-2 partial trace cherry-pick dampening, and live two-trace Workshop summary & latency.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")

var checks = 0
var fails = 0

func _init() -> void:
	_test_two_trace_search_and_non_duplication()
	_test_joint_walker_subtraction_vs_ambiguous_walker()
	_test_partial_one_of_two_cherry_pick_guard()
	_test_live_two_trace_summary_and_latency()
	print("Two-trace scenes (Slice 3): %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)

func _game(sd: int = 2101, count: int = 7):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, count)
	return g

func _view_7p() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id.to_upper(), "home": "square", "alive": id != "g"})
	return {
		"people": people,
		"cards": [],
		"evil_count": 2,
		"alignment_epoch": "Original alignment",
		"live_activity": true,
		"timeline": {
			"executions": {},
			"deaths": {"g": 2},
			"death_ticks": {"g": 7},
			"events": [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}],
		},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]},
	}

func _profile_cards_for(pid: String, work_loc: String, h1: String, h2: String) -> Array:
	return [
		{"id": "w_" + pid, "kind": "context", "source": "town", "context_kind": "work", "subject": pid, "data": {"loc": work_loc}},
		{"id": "h1_" + pid, "kind": "context", "source": "town", "context_kind": "haunt", "subject": pid, "data": {"locs": [h1]}},
		{"id": "h2_" + pid, "kind": "context", "source": "town", "context_kind": "haunt", "subject": pid, "data": {"locs": [h2]}},
	]

func _test_two_trace_search_and_non_duplication() -> void:
	var found_two = false
	var distinct_slots = true
	for sd in range(2200, 2260):
		var g = _game(sd, 7)
		var w = g.w
		var victim = w.living_good()[0]
		var passer = w.living_good()[1]
		w.day = 1
		w.night_walkers = [{"id": passer.id, "block": victim.home_block, "path": [victim.home_block], "why": "keeping watch"}]
		w._kill(victim)
		var sid: String = "scene_" + victim.id
		if w.scenes[sid]["traces"].size() == 2:
			found_two = true
			g.loc = sid
			g._search()
			var tcards: Array = g.board.filter(func(c): return c.kind == "trace" and c.get("scene", "") == sid)
			if tcards.size() != 2 or tcards[0].trace_slot != 0 or tcards[1].trace_slot != 1 or tcards[0].scene_trace_count != 2 or tcards[0].trace_key == tcards[1].trace_key:
				distinct_slots = false
	_check(found_two and distinct_slots, "searching a two-trace cottage mints two distinct board trace cards with slots 0 and 1 and scene_trace_count=2")

func _test_joint_walker_subtraction_vs_ambiguous_walker() -> void:
	var view: Dictionary = _view_7p()
	# T1 = {bakery, tavern}, T2 = {smithy, wharf}.
	# Candidate A (idx 0) fits T1 only (bakery, chapel, mill).
	# Candidate B (idx 1) fits T2 only (smithy, chapel, mill).
	# Walker C (idx 2, sighted on square on night 1) fits T2 only in Case 1, and BOTH T1 & T2 in Case 2!
	var t1 = {"id": "t1", "kind": "trace", "source": "evidence", "night": 1, "subject": "", "data": {"family": "locations", "locs": ["bakery", "tavern"], "scene": "scene_g", "scene_block": "square", "victim": "g", "slot": 0, "scene_trace_count": 2}}
	var t2 = {"id": "t2", "kind": "trace", "source": "evidence", "night": 1, "subject": "", "data": {"family": "locations", "locs": ["smithy", "wharf"], "scene": "scene_g", "scene_block": "square", "victim": "g", "slot": 1, "scene_trace_count": 2}}
	var sight_c = {"id": "sc", "fact_id": "sc", "kind": "sighting", "source": "player", "subject": "c", "subjects": ["c"], "night": 1, "block": "square", "data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	var base_cards: Array = [t1, t2, sight_c] + _profile_cards_for("a", "bakery", "chapel", "mill") + _profile_cards_for("b", "smithy", "chapel", "mill")
	# Case 1: Sighted walker C fits T2 ONLY (wharf, graveyard, well) -> C accounts for T2, so Demon A (fits T1) beats Demon B (fits T2)!
	var cards_explained: Array = base_cards + _profile_cards_for("c", "wharf", "graveyard", "well")
	var factor_explained: Dictionary = Activity.factors(view, cards_explained, {})[0]
	var world_demon_a = {"evil": (1 << 0) | (1 << 3), "demon": 0}
	var world_demon_b = {"evil": (1 << 1) | (1 << 3), "demon": 1}
	var score_a1: float = Activity.score(world_demon_a, factor_explained)
	var score_b1: float = Activity.score(world_demon_b, factor_explained)
	_check(score_a1 > score_b1 * 1.45, "when sighted walker C fits only T2, joint assignment favors T1-matching Demon A over T2-matching Demon B")
	# Case 2: Sighted walker C fits BOTH T1 and T2 (bakery, wharf, well) -> exact symmetry between Demon A and Demon B!
	var cards_ambig: Array = base_cards + _profile_cards_for("c", "bakery", "wharf", "well")
	var factor_ambig: Dictionary = Activity.factors(view, cards_ambig, {})[0]
	var score_a2: float = Activity.score(world_demon_a, factor_ambig)
	var score_b2: float = Activity.score(world_demon_b, factor_ambig)
	_check(is_equal_approx(score_a2, score_b2), "when sighted walker C fits both T1 and T2, joint assignment stays completely symmetric between A and B")

func _test_partial_one_of_two_cherry_pick_guard() -> void:
	var view: Dictionary = _view_7p()
	var cards_profiles: Array = _profile_cards_for("a", "bakery", "chapel", "mill") + _profile_cards_for("b", "graveyard", "chapel", "mill")
	var t_single = {"id": "ts", "kind": "trace", "source": "evidence", "night": 1, "subject": "", "data": {"family": "locations", "locs": ["bakery", "tavern"], "scene": "scene_g", "scene_block": "square", "victim": "g", "slot": 0, "scene_trace_count": 1}}
	var t_half = t_single.duplicate(true)
	t_half.id = "th"
	t_half.data.scene_trace_count = 2
	var world_a = {"evil": (1 << 0) | (1 << 3), "demon": 0}
	var world_b = {"evil": (1 << 1) | (1 << 3), "demon": 1}
	var f_single: Dictionary = Activity.factors(view, [t_single] + cards_profiles, {})[0]
	var f_half: Dictionary = Activity.factors(view, [t_half] + cards_profiles, {})[0]
	var ratio_single: float = Activity.score(world_a, f_single) / Activity.score(world_b, f_single)
	var ratio_half: float = Activity.score(world_a, f_half) / Activity.score(world_b, f_half)
	_check(is_equal_approx(ratio_single, 3.0) and ratio_half < ratio_single and ratio_half > 1.5, "citing only 1 of 2 traces from a two-trace scene dampens 3:1 discrimination until the sister trace is accounted for")

func _test_live_two_trace_summary_and_latency() -> void:
	var g = _game(2404, 10)
	var w = g.w
	var victim = w.living_good()[0]
	var a = w.npcs.filter(func(p): return p != victim)[0]
	var b = w.npcs.filter(func(p): return p not in [victim, a])[0]
	var walker = w.npcs.filter(func(p): return p not in [victim, a, b])[0]
	var speaker = w.npcs.filter(func(p): return p not in [victim, a, b, walker])[0]
	a.work = "bakery"
	a.haunts = ["chapel", "mill"]
	b.work = "graveyard"
	b.haunts = ["chapel", "mill"]
	walker.work = "wharf"
	walker.haunts = ["well", "chapel"]
	g.profile_receipts.clear()
	g._profile_card_keys.clear()
	g._profile_fact_keys.clear()
	g._home_cards()
	w.day = 1
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "day": 1, "phase": C.NIGHT, "night": 1, "block": victim.home_block, "text": "%s was killed on night 1." % victim.name})
	w.public_event("demon_death", [victim.id], "town")
	var t1_n: int = g.add_card({"kind": "trace", "subject": [], "block": victim.home_block, "source": "evidence", "day": 1, "phase": C.EVENING, "scene": "scene_" + victim.id, "scene_block": victim.home_block, "victim": victim.id, "victim_block": victim.home_block, "crime_night": 1, "trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 2, "trace_key": "locations:bakery:tavern", "locs": ["bakery", "tavern"], "item_label": "a grease-darkened brass farthing", "text": "At %s's scene: a grease-darkened brass farthing (the bakery or the Drowned Lamb tavern)." % victim.name})
	var t2_n: int = g.add_card({"kind": "trace", "subject": [], "block": victim.home_block, "source": "evidence", "day": 1, "phase": C.EVENING, "scene": "scene_" + victim.id, "scene_block": victim.home_block, "victim": victim.id, "victim_block": victim.home_block, "crime_night": 1, "trace_family": "locations", "trace_subtype": "token", "trace_slot": 1, "scene_trace_count": 2, "trace_key": "locations:smithy:wharf", "locs": ["smithy", "wharf"], "item_label": "a verdigris-stained copper boat-rivet", "text": "At %s's scene: a verdigris-stained copper boat-rivet (the smithy or the wharf)." % victim.name})
	var vig_n: int = g.add_card({"kind": "sighting", "source": "player", "subject": [walker.id], "day": 1, "phase": C.NIGHT, "block": victim.home_block, "text": "You saw %s on %s on night 1." % [walker.name, C.block_name(victim.home_block)]})
	for p in [b, walker]:
		for hl in p.haunts:
			g.known_haunts[p.id] = g.known_haunts.get(p.id, []) + [hl]
			g.add_profile_receipt({"kind": "haunt", "subject": [p.id], "source": speaker.id, "loc": hl, "locs": [hl], "block": w.loc_block(hl), "day": 1, "phase": 0, "text": "Haunt"})
	var view: Dictionary = WorkshopCanvas.view(g)
	var board = CanvasModel.new(view)
	var root_id: String = board.selected
	board.nodes[root_id].conclusion = {"type": "suspicious", "target": a.id, "at": view.alignment_epoch}
	for n_card in [t1_n, t2_n, vig_n]:
		var cid: String = "e:" + WorkshopCanvas.Evidence.normalize_card(g.board[n_card - 1]).id
		board.connect_cards(cid, root_id)
	for p in [a, b, walker]:
		var pnode: String = board.add_profile_info(p.id, ["home_work", "haunts"])
		board.connect_cards(pnode, root_id)
	var compiled: Dictionary = board.compile(root_id)
	var tsum: Dictionary = WorkshopCanvas.trace_summary(g, compiled)
	_check(b.name in tsum.contradicted and a.name in tsum.compatible, "two-trace summary marks candidate contradicted on both traces while keeping single-prong match compatible")
	_check(tsum.get("pairings", []).any(func(s): return walker.name in s and "accounts for trace 2" in s), "two-trace summary identifies when a sighted walker accounts for one trace")
	var t0_ms: int = Time.get_ticks_msec()
	var ghost: Dictionary = Ghost.live(WorkshopCanvas.snapshot(g, compiled))
	var elapsed_ms: int = Time.get_ticks_msec() - t0_ms
	_check(ghost.ready and elapsed_ms < 2500, "10-person joint two-trace Ghost evaluation completes cleanly within interactive budget (%d ms)" % elapsed_ms)
