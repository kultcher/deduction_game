## Regression suite for post-Phase-4.1 audit cleanup items.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Caches = preload("res://workshop/caches.gd")
const TraceSolver = preload("res://workshop/trace_solver.gd")
const GhostJuror = preload("res://workshop/ghost_juror.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Roles = preload("res://workshop/role_constraints.gd")
const Jury = preload("res://workshop/jury.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_test_warden_credit_leak_free_and_sigil_reweigh()
	_test_case_against_skips_non_incriminating_sightings()
	_test_live_role_constraints_non_strict_nightwatch()
	_test_shared_ledger_zero_weight_reading_guard()
	_test_dowser_bluff_can_report_two_plus()
	_test_caches_clear_all_and_constance_inquiry_gate()
	_test_jury_persuasion_tail_helper()
	print("Audit cleanup suite: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_warden_credit_leak_free_and_sigil_reweigh() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4242, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var warden = goods[0]
	var protectee = goods[1]
	var third = goods[2]
	warden.role = "warden"
	w.day = 1

	# Unannounced private ward on someone else must NOT leak into Warden's credit calculation.
	w.player_ward = third.id
	warden.warden_saves.clear()
	w._warden_credit(warden, protectee.id)
	_check(warden.warden_saves.has("1") and is_equal_approx(warden.warden_saves["1"].belief, 1.0), "private ward on another villager does not omnisciently discount Warden save belief")

	# Next day, showing a scorched sigil on third's door revokes the Warden's mistaken save belief.
	w.player_ward = ""
	w.day = 2
	var sigil_n: int = g.add_card({
		"kind": "scorched_sigil", "source": "evidence", "subject": [third.id], "target": third.id,
		"loc": "home_" + third.id, "block": third.home_block, "night": 1, "day": 1, "phase": C.NIGHT,
		"private": true, "text": "Scorched sigil on %s's door on night 1." % third.name,
	})
	g._show_ward_context(g.board[sigil_n - 1], [warden])
	_check(not warden.warden_saves.has("1"), "showing a scorched sigil on another villager's door revokes Warden save credit for that night")

	# Showing an un-scorched ward card when a public Veteran also exists drops belief below 0.5.
	w.day = 2
	warden.warden_saves.clear()
	w.public_claims.append({"who": goods[3].id, "role": "veteran", "day": 2})
	w._warden_credit(warden, protectee.id)
	_check(warden.warden_saves.has("2") and is_equal_approx(warden.warden_saves["2"].belief, 0.5), "Warden starts with 0.5 save belief alongside one living Veteran claim")
	var ward_n: int = g.add_card({
		"kind": "ward", "source": "player", "subject": [third.id], "target": third.id,
		"loc": "home_" + third.id, "block": third.home_block, "night": 2, "day": 2, "phase": C.NIGHT,
		"private": true, "text": "Night 2: you spent your ward on %s's door." % third.name,
	})
	g._show_ward_context(g.board[ward_n - 1], [warden])
	_check(not warden.warden_saves.has("2"), "showing a ward card to the Warden adds the ward alternative and drops 0.5 belief below threshold")


func _test_case_against_skips_non_incriminating_sightings() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 7)
	var w = g.w
	var listener = w.living_good()[0]
	var walker = w.living_good()[1]
	var victim = w.living_good()[2]
	walker.home_block = "square"
	victim.home_block = "docks"
	victim.alive = false
	victim.death_day = 1
	victim.death_cause = "demon"
	w.day = 1
	w.public_event("demon_death", [victim.id], "town")
	w.day = 2
	w.scenes[victim.id] = {"day": 1, "block": "docks", "loc": "wharf"}

	# Off-murder-block night sighting ("hill" while walker lives on "square" and victim died on "docks")
	# has LR < 1.0 in LiveActivity even when another card raises walker's suspicion.
	var other = w.living_good()[3]
	var dowse_entry: Dictionary = {"day": 1, "phase": C.MORNING, "role": "dowser", "data": {"group": [walker.id, other.id], "count": 1}, "shared": true, "text": "1 evil in pair"}
	Mind.apply_info(w, listener, other, dowse_entry, 1.0)
	var wcard_off = preload("res://workshop/live_evidence.gd").normalize_card({
		"kind": "sighting", "source": other.id, "subject": [walker.id],
		"block": "hill", "day": 1, "phase": C.NIGHT, "text": "A witnessed outing off murder block"
	})
	var effs: Array = []
	Mind._eff(effs, walker.id, 0.04, "saw out off murder block", "saw them out on Chapel Hill at night")
	Mind.ledger_hear(w, listener, "heard:sight_off_block", effs, 1.0, [other.id, 1, "report"], {"kind": "tell", "workshop_card": wcard_off})
	Mind.recompute_beliefs(w, listener, " (test off-block sighting)")
	var reasons_off: Array = MindMeeting.case_against(w, listener, walker.id)
	_check(not reasons_off.any(func(r): return r.get("channel", "") == "movement_out"), "case_against does not cite an off-murder-block night sighting in shared attribution")

	# Same sighting ON the murder block ("docks") IS cited when walker has no credible walking claim.
	var wcard_on = preload("res://workshop/live_evidence.gd").normalize_card({
		"kind": "sighting", "source": other.id, "subject": [walker.id],
		"block": "docks", "day": 1, "phase": C.NIGHT, "text": "A witnessed outing on murder block"
	})
	Mind.ledger_hear(w, listener, "heard:sight_on_block", effs, 1.0, [other.id, 1, "report"], {"kind": "tell", "workshop_card": wcard_on})
	Mind.recompute_beliefs(w, listener, " (test murder-block sighting)")
	var reasons_on: Array = MindMeeting.case_against(w, listener, walker.id)
	_check(reasons_on.any(func(r): return r.get("channel", "") == "movement_out"), "case_against cites a murder-block night sighting when walker has no credible walking claim")


func _test_live_role_constraints_non_strict_nightwatch() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id.to_upper(), "home": "hill" if id == "a" else ("market" if id == "b" else "square")})
	var view = {
		"people": people,
		"cards": [],
		"evil_count": 2,
		"alignment_epoch": "Original alignment",
		"live_activity": true,
		"timeline": {"events": [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}]},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]},
	}
	# Night Watch b claims seeing a on market, while player saw a on docks (two non-home blocks for hill resident a).
	# If b is lying/poisoned and a is actually a Minion (not Demon), live bluffs=true fitting must NOT rule out the world via forced_lamp.
	var false_watch = {"id": "nw1", "fact_id": "nw1", "kind": "report", "source": "b", "role": "nightwatch", "night": 1, "data": {"block": "market", "seen": ["a"]}, "observed_at": {"day": 1, "phase": "night"}}
	var real_sight = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": 1, "block": "docks", "data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	var universe: Array = preload("res://workshop/solver.gd").universe(view)
	var fit_live: PackedFloat64Array = Roles.fits_weights(view, universe, [false_watch, real_sight], {}, {}, true)
	var minion_a_idx: int = -1
	for i in range(universe.size()):
		var uw: Dictionary = universe[i]
		if (int(uw.evil) & 1) != 0 and int(uw.get("demon", -1)) != 0:
			minion_a_idx = i
			break
	_check(minion_a_idx >= 0 and fit_live[minion_a_idx] > 0.0, "live RoleConstraints (bluffs=true) does not prune Minion worlds via forced_lamp from a fallible Night Watch report")


func _test_shared_ledger_zero_weight_reading_guard() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(4, 7)
	var listener = g.w.living_good()[0]
	var speaker = g.w.living_good()[1]
	var t1 = g.w.living_good()[2]
	var t2 = g.w.living_good()[3]
	listener.ledger.clear()
	listener.workshop_state = {"enabled": true}
	var card = {
		"kind": "info", "source": speaker.id, "role": "seer", "day": 1, "phase": C.NIGHT,
		"data": {"pair": [t1.id, t2.id], "yes": true}, "subject": [t1.id, t2.id], "text": "seer yes",
	}
	var norm: Dictionary = preload("res://workshop/live_evidence.gd").normalize_card(card)
	Mind.ledger_hear(g.w, listener, "info:%s:1:seer" % speaker.id, [[t1.id, 0.4, 0, "seer", "seer"]], 0.0, [speaker.id, 1, "reading"], {
		"kind": "reading", "workshop_receipts": {norm.id: norm},
	})
	var input: Dictionary = Bridge.capture(g, [], listener.id, "private", listener)
	var plan: Dictionary = Shared.prepare(input, {}, listener.ledger)
	_check(plan.ready and is_zero_approx(float(plan.prepared.listener.reading_reliability.get(norm.id, 1.0))), "zero-weight reading: ledger entry yields 0.0 reading_reliability instead of 0.5 floor")

	# And under Codex's _card_route_trust rule, a zero-weight reading: entry must not shadow a live player case route.
	listener.npc_trust[speaker.id] = 0.20
	listener.credibility = 0.90
	var rt: Dictionary = Shared._card_route_trust(norm, {}, ["reading:info:%s:1:seer" % speaker.id, "case:1"], listener.ledger, listener.id, listener.npc_trust, listener.credibility)
	_check(bool(rt.get("via_player_only", false)) and is_equal_approx(float(rt.get("trust", 0.0)), 0.55), "zero-weight reading: owner does not shadow a live player case route in _card_route_trust")


func _test_dowser_bluff_can_report_two_plus() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var w = g.w
	w.day = 2
	var evil_actor = w.demon()
	var goods: Array = w.living_good()
	# Place evil_actor and 4 good villagers (including scapegoat) on the same block, and move any minion elsewhere.
	var blk: String = "market"
	for m in w.living():
		m.loc = "wharf" # docks
	evil_actor.loc = "tavern" # market
	for i in range(4):
		goods[i].loc = "tavern"
	var scapegoat_id: String = goods[0].id
	var dw = C.role_def("dowser")
	var saw_one: bool = false
	var saw_two: bool = false
	for trial in range(80):
		evil_actor.dowsed_day = -1
		var res: Dictionary = dw.generate_bluff_reading(w, evil_actor, {}, scapegoat_id, null, [])
		var cnt: int = int(res.get("entry", {}).get("data", {}).get("count", -1))
		if cnt == 1:
			saw_one = true
		elif cnt == 2:
			saw_two = true
	_check(saw_one and saw_two, "Dowser bluff in a 4+ all-Good crowd can report both 1 and 2 evil")


func _test_caches_clear_all_and_constance_inquiry_gate() -> void:
	TraceSolver._compiled_cache["dummy"] = {"digest": "dummy"}
	GhostJuror._live_cache[12345] = {"result": {}}
	Caches.clear_all()
	_check(TraceSolver._compiled_cache.is_empty() and GhostJuror._live_cache.is_empty(), "Caches.clear_all empties TraceSolver._compiled_cache and GhostJuror._live_cache")

	# Constance Day 1 Afternoon with 1 prior question still uses private_reveal_early; after 2 prior questions uses private_reveal.
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(42, 10)
	var constance = g.w.by_id.get("constance")
	if constance != null:
		constance.alignment = "good"
		constance.role = "surveyor"
		constance.claimed_role = ""
		constance.claim_public = false
		constance.max_tier = 0
		constance.trust = 0.95
		constance.traits["privacy"] = 0.0
		constance.dialogue_memory = {}
		g.w.day = 1
		g.w.phase = C.AFTERNOON
		constance.pressed_today = 1 # 1 prior question asked before this gift question
		var r_early: Dictionary = Mind.answer_gift(g.w, constance)
		var txt_early: String = str(r_early["lines"][0].get("text", ""))
		_check("orderly beginning" in txt_early, "Constance on Day 1 Afternoon with <2 prior questions uses private_reveal_early (%s)" % txt_early)

		constance.claimed_role = ""
		constance.max_tier = 0
		constance.dialogue_memory = {}
		constance.pressed_today = 2 # 2 prior questions asked before this gift question
		var r_proper: Dictionary = Mind.answer_gift(g.w, constance)
		var txt_proper: String = str(r_proper["lines"][0].get("text", ""))
		_check("conducted this inquiry properly" in txt_proper, "Constance after 2 prior questions uses standard private_reveal (%s)" % txt_proper)


func _test_jury_persuasion_tail_helper() -> void:
	for kind in ["", "movement", "trace", "movement and trace"]:
		var sample: String = "I checked another explanation and it also fits: Odette, Bram evil; Kira Marked." + Jury.accept_persuasion_tail(kind)
		var stripped: String = Jury.strip_accept_persuasion_tail(sample)
		_check(not ("Even so," in stripped) and stripped.begins_with("I checked another explanation"), "Jury.strip_accept_persuasion_tail cleanly removes persuasion tail (%s)" % (kind if kind != "" else "plain"))
