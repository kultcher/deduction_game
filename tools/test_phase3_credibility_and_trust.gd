## Phase 3 regression suite:
## - 3.1 Proof-safe & retraction-safe dawn-committed delta directional confidence
## - 3.2 Per-card source reliability (zero rumor dilution & zero rumor laundering)
##       + context-aware repeat-reading grouping in Jury._headline
## - 3.3 Non-circular Credibility.dawn abstention gate + tiered claim weights
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")
const Credibility = preload("res://game/credibility.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Jury = preload("res://workshop/jury.gd")

var checks: int = 0
var fails: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: " + label)
	else:
		print("PASS: " + label)


func _init() -> void:
	_test_3_1_delta_confidence_and_proof_retraction_overrides()
	_test_3_2_per_card_source_trust_non_dilution_and_non_laundering()
	_test_3_2_headline_context_aware_repeat_grouping()
	_test_3_3_non_circular_credibility_dawn_and_tiered_weights()
	print("Phase 3 credibility & trust: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _test_3_1_delta_confidence_and_proof_retraction_overrides() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var goods: Array = g.w.living_good()
	var high_conf = goods[0]
	var low_conf = goods[1]
	var seer_src = goods[2]
	var clear_src = goods[3]
	var suspect = goods[4]
	var other = goods[5]

	for listener in [high_conf, low_conf]:
		listener.role = "warden"
		listener.info_log = []
		listener.applied_info = 0
		listener.ledger.clear()
		listener.workshop_state.clear()
		listener.workshop_state["enabled"] = true
		listener.traits.insight = 0.85
		for id in listener.suspicion:
			listener.suspicion[id] = Tuning.Setup.INITIAL_SUSPICION_BASE
		for id in listener.npc_trust:
			listener.npc_trust[id] = 0.85
	high_conf.traits.confidence = 0.95
	low_conf.traits.confidence = 0.10

	# Day 1: present an accusing Dowser report against `suspect` to both listeners.
	var c_evil: int = g.add_card({
		"kind": "info", "source": seer_src.id, "role": "dowser",
		"day": 1, "phase": 0, "data": {"group": [suspect.id], "count": 1},
		"text": "%s dowser 1/1 on %s" % [seer_src.id, suspect.id],
	})
	var ded_evil: int = g.file_deduction({"type": "evil", "a": suspect.id}, [c_evil])
	g._evaluate_deduction(high_conf, g.board[ded_evil - 1], 1.0, false)
	g._evaluate_deduction(low_conf, g.board[ded_evil - 1], 1.0, false)
	var d1_req_hi: float = float(high_conf.workshop_state.requested.get(suspect.id, 0.0))
	var d1_req_lo: float = float(low_conf.workshop_state.requested.get(suspect.id, 0.0))
	_check(d1_req_hi > 0.10 and is_equal_approx(d1_req_hi, d1_req_lo),
		"Day 1 fresh evidence lands equally on high- and low-Confidence listeners before dawn commitment (%.4f vs %.4f)" % [d1_req_hi, d1_req_lo])

	# Simulate Night 1 dawn freeze (same logic as Game._resolve_night).
	for listener in [high_conf, low_conf]:
		listener.workshop_state["committed_lean"] = Mind.suspicion_view(listener).duplicate(true)
		listener.workshop_state["committed_requested"] = listener.workshop_state.get("requested", {}).duplicate(true)
	g.w.day = 2

	# Day 2: introduce competing clearing Dowser report on `suspect` from a second source.
	var c_clear: int = g.add_card({
		"kind": "info", "source": clear_src.id, "role": "dowser",
		"day": 2, "phase": 0, "data": {"group": [suspect.id], "count": 0},
		"text": "%s dowser 0/1 on %s" % [clear_src.id, suspect.id],
	})
	var ded_clear: int = g.file_deduction({"type": "good", "a": suspect.id}, [c_clear])
	g._evaluate_deduction(high_conf, g.board[ded_clear - 1], 1.0, false)
	g._evaluate_deduction(low_conf, g.board[ded_clear - 1], 1.0, false)
	var d2_req_hi: float = float(high_conf.workshop_state.requested.get(suspect.id, 0.0))
	var d2_req_lo: float = float(low_conf.workshop_state.requested.get(suspect.id, 0.0))
	_check(d2_req_hi > d2_req_lo + 0.01,
		"Day 2 contrary evidence damps delta on high-Confidence listener (%.4f vs %.4f)" % [d2_req_hi, d2_req_lo])

	# Sole-case retraction override: retracting both presentations snaps requested to 0.0 with zero phantom residue!
	g.workshop_retract(ded_evil, high_conf.id)
	g.workshop_retract(ded_clear, high_conf.id)
	_check(is_zero_approx(float(high_conf.workshop_state.get("requested", {}).get(suspect.id, 0.0))),
		"withdrawing all supporting presentations snaps requested to exact 0.0 despite prior committed_requested")

	# Hard public proof override: Martyr proof clears stubborn high-Confidence listener immediately to 0.0 suspicion.
	g._evaluate_deduction(high_conf, g.board[ded_evil - 1], 1.0, false)
	high_conf.workshop_state["committed_lean"] = Mind.suspicion_view(high_conf).duplicate(true)
	high_conf.workshop_state["committed_requested"] = high_conf.workshop_state.get("requested", {}).duplicate(true)
	g.w.public_log.append({"day": 2, "kind": "martyr", "subjects": [suspect.id, other.id], "by": other.id})
	Mind.recompute_beliefs(g.w, high_conf, "public Martyr proof")
	_check(is_zero_approx(float(high_conf.suspicion.get(suspect.id, 1.0))),
		"public Martyr proof overrides high-Confidence committed_requested and clears target to 0.0")


func _test_3_2_per_card_source_trust_non_dilution_and_non_laundering() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(92974, 7)
	var goods: Array = g.w.living_good()
	var seer = goods[0]
	var rumor_teller = goods[1]
	var suspect = goods[2]
	var partner = goods[3]
	var extra = goods[4]

	seer.role = "seer"
	seer.info_log = [{"day": 1, "role": "seer", "data": {"pair": [suspect.id, partner.id], "yes": true}, "true": true, "shared": false, "text": "own seer yes"}]
	seer.applied_info = 0
	seer.ledger.clear()
	seer.workshop_state.clear()
	seer.workshop_state["enabled"] = true
	seer.npc_trust[rumor_teller.id] = 0.15
	Mind.update_from_own_info(g.w)
	var base_req: float = float(seer.workshop_state.requested.get(suspect.id, 0.0))
	_check(base_req > 0.0, "firsthand Seer YES reading produces positive requested shift (%.4f)" % base_req)

	# Rumor non-dilution: hearing a 0.15-trust rumor implicating `suspect` must NEVER weaken `seer`'s firsthand belief!
	var rumor_entry = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [suspect.id, extra.id], "count": 1}, "text": "untrusted dowser rumor"}
	Mind.apply_info(g.w, seer, rumor_teller, rumor_entry, 0.5)
	var after_rumor_req: float = float(seer.workshop_state.requested.get(suspect.id, 0.0))
	_check(after_rumor_req >= base_req - 0.0001,
		"adding a 0.15-trust corroborating rumor never dilutes a 1.0-trust firsthand reading (%.4f -> %.4f)" % [base_req, after_rumor_req])

	# Rumor non-laundering: compare a 0.10-trust source vs a 0.95-trust source on the same heard reading.
	var listener_lo = goods[4]
	var listener_hi = goods[5] if goods.size() > 5 else g.w.npcs.filter(func(p): return p not in [seer, rumor_teller, suspect, partner, listener_lo])[0]
	for l in [listener_lo, listener_hi]:
		l.alignment = "good"
		l.role = "warden"
		l.info_log = []
		l.applied_info = 0
		l.ledger.clear()
		l.workshop_state.clear()
		l.workshop_state["enabled"] = true
		l.traits.insight = 0.8
	listener_lo.npc_trust[rumor_teller.id] = 0.10
	listener_hi.npc_trust[rumor_teller.id] = 0.95
	var single_rumor = {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [suspect.id], "count": 1}, "text": "single dowser"}
	Mind.apply_info(g.w, listener_lo, rumor_teller, single_rumor, 0.5)
	Mind.apply_info(g.w, listener_hi, rumor_teller, single_rumor, 0.5)
	var lo_req: float = float(listener_lo.workshop_state.requested.get(suspect.id, 0.0))
	var hi_req: float = float(listener_hi.workshop_state.requested.get(suspect.id, 0.0))
	_check(hi_req > lo_req + 0.04,
		"per-card npc_trust scales heard report strength monotonically without laundering low-trust rumors (lo %.4f vs hi %.4f)" % [lo_req, hi_req])


func _test_3_2_headline_context_aware_repeat_grouping() -> void:
	var view: Dictionary = {
		"people": [{"id": "a"}, {"id": "b"}, {"id": "s1"}, {"id": "s2"}],
		"timeline": {"executions": {}},
	}
	var listener: Dictionary = {
		"id": "l", "trust": 0.8, "player_credibility": 0.8,
		"npc_trust": {"s1": 0.9, "s2": 0.9},
		"knowledge": {"own_reports": []},
	}
	var eval_listener: Dictionary = {
		"id": "l", "reading_reliability": {"c1": 0.95, "c2": 0.95, "c3": 0.95},
		"knowledge": {"own_reports": []},
	}
	var c1: Dictionary = {"id": "c1", "kind": "report", "source": "s1", "role": "seer", "night": 1,
		"observed_at": {"day": 1, "phase": "night"}, "data": {"pair": ["a", "b"], "yes": true}}
	var c2_same_seer: Dictionary = {"id": "c2", "kind": "report", "source": "s1", "role": "seer", "night": 2,
		"observed_at": {"day": 2, "phase": "night"}, "data": {"pair": ["b", "a"], "yes": true}}
	var c3_second_seer: Dictionary = {"id": "c3", "kind": "report", "source": "s2", "role": "seer", "night": 2,
		"observed_at": {"day": 2, "phase": "night"}, "data": {"pair": ["a", "b"], "yes": true}}

	var h_single: float = Jury._headline(view, [c1], "a", 0.25, listener, eval_listener, false)
	var h_repeat: float = Jury._headline(view, [c1, c2_same_seer], "a", 0.25, listener, eval_listener, false)
	var h_two_sources: float = Jury._headline(view, [c1, c3_second_seer], "a", 0.25, listener, eval_listener, false)
	_check(h_repeat > h_single and (h_repeat - h_single) < 0.35 * (h_two_sources - h_single),
		"same-Seer same-epoch repeat gets only diminishing confirmation bump while two distinct claimants combine fully (%.4f, %.4f, %.4f)" % [h_single, h_repeat, h_two_sources])

	# Across a Day 2 execution (potential Scion promotion), Night 1 and Night 2 checks belong to distinct epochs!
	var view_exec: Dictionary = view.duplicate(true)
	view_exec.timeline.executions = {2: "x"}
	var h_post_exec: float = Jury._headline(view_exec, [c1, c2_same_seer], "a", 0.25, listener, eval_listener, false)
	_check(h_post_exec > h_repeat + 0.02,
		"checks separated by a public execution land in distinct scion_epochs and are not collapsed as stale repeats (%.4f vs %.4f)" % [h_post_exec, h_repeat])


func _test_3_3_non_circular_credibility_dawn_and_tiered_weights() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(97930, 10)
	var goods: Array = g.w.living_good()
	var uninformed = goods[0]
	var suspect = goods[1]
	var innocent = goods[2]
	var witness = goods[3]

	# Clear uninformed listener's private gifts so they genuinely hold zero independent evidence on `suspect`.
	uninformed.role = "warden"
	uninformed.info_log = []
	uninformed.applied_info = 0
	uninformed.ledger.clear()
	uninformed.workshop_state.clear()
	uninformed.workshop_state["enabled"] = true
	Mind.recompute_beliefs(g.w, uninformed, "clean uninformed baseline")

	# 1) Detective Penalty check: player records an accusation on `suspect` before `uninformed` knows anything.
	uninformed.credibility = 0.5
	Credibility.record(uninformed, "evil", suspect.id, 1, Tuning.Trust.CRED_WEIGHT_FORMAL)
	Credibility.dawn(g)
	_check(is_equal_approx(uninformed.credibility, 0.5),
		"uninformed villager abstains at Dawn with zero Detective Penalty (credibility stays %.3f)" % uninformed.credibility)

	# 2) Self-validation circularity check: player presents a cherry-picked case to `uninformed`;
	# `uninformed` still has zero *independent* evidence, so Dawn must NOT self-validate the player's own case!
	var cherry: int = g.add_card({
		"kind": "info", "source": witness.id, "role": "dowser",
		"day": 1, "phase": 0, "data": {"group": [innocent.id], "count": 1},
		"text": "cherry-picked report",
	})
	var ded_cherry: int = g.file_deduction({"type": "evil", "a": innocent.id}, [cherry])
	g._evaluate_deduction(uninformed, g.board[ded_cherry - 1], 1.0, false)
	Credibility.dawn(g)
	_check(is_equal_approx(uninformed.credibility, 0.5),
		"player-presented case never circularly self-validates at Dawn without independent corroboration (credibility %.3f)" % uninformed.credibility)

	# 3) Independent corroboration vindicates the player: `uninformed` independently hears `witness`'s reading!
	uninformed.claim_record = {}
	uninformed.credibility = 0.5
	Credibility.record(uninformed, "evil", innocent.id, 1, Tuning.Trust.CRED_WEIGHT_FORMAL)
	Mind.apply_info(g.w, uninformed, witness, {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [innocent.id], "count": 1}, "text": "independent dowser"}, 0.5)
	Credibility.dawn(g)
	_check(uninformed.credibility > 0.52,
		"independent corroboration moves posterior past CRED_CORROBORATION_MIN and raises Credibility at Dawn (%.3f)" % uninformed.credibility)

	# 4) Tiered claim weights: 1.0 formal deduction/nomination outweighs 0.35 casual statement,
	# and a same-direction 0.35 statement never downgrades an existing 1.0 formal claim!
	var victim = goods[4]
	g.w.public_event("demon_death", [victim.id], "town")
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "day": 1, "phase": C.NIGHT, "night": 1, "block": victim.home_block, "text": "Death"})
	Mind.recompute_beliefs(g.w, uninformed, "public demon death")

	uninformed.claim_record = {}
	uninformed.credibility = 0.5
	Credibility.record(uninformed, "evil", innocent.id, 1, Tuning.Trust.CRED_WEIGHT_FORMAL)
	Credibility.record(uninformed, "evil", innocent.id, 1, Tuning.Trust.CRED_WEIGHT_STATEMENT)
	_check(is_equal_approx(float(uninformed.claim_record[innocent.id].weight), Tuning.Trust.CRED_WEIGHT_FORMAL),
		"same-direction casual statement never downgrades existing formal 1.0 claim weight")

	var c_equal_test: float
	uninformed.claim_record = {
		innocent.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_FORMAL},
		victim.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_FORMAL},
	}
	uninformed.credibility = 0.5
	Credibility.dawn(g)
	c_equal_test = uninformed.credibility

	uninformed.claim_record = {
		innocent.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_FORMAL},
		victim.id: {"type": "evil", "day": 1, "weight": Tuning.Trust.CRED_WEIGHT_STATEMENT},
	}
	uninformed.credibility = 0.5
	Credibility.dawn(g)
	_check(uninformed.credibility > c_equal_test + 0.03,
		"0.35 casual statement mistake docks Credibility substantially less than a 1.0 formal claim mistake (%.3f vs %.3f)" % [uninformed.credibility, c_equal_test])
