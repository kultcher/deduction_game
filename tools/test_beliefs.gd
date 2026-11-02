## Acceptance tests for shared-model credibility, source_doubt, and belief revision.
##   godot --headless --path . --script res://tools/test_beliefs.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")

var fails = 0

func _init() -> void:
	_test_recovery()
	_test_independent_evidence()
	_test_poison_not_honesty()
	_test_stable_recompute()
	_test_other_source()
	_test_mutual_accusation()
	_test_chained_deduction()
	_test_weak_restatement()
	_test_poison_argument_undone()
	_test_own_reading_poisoned()
	_test_sightings_not_poisoned()
	_test_double_claim_shifts()
	_test_own_gift()
	_test_known_good_claimant()
	print("FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _setup(sd: int) -> Dictionary:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_logs"
	g.new_case(sd)
	var w = g.w
	w.day = 3
	for p in w.npcs:
		for m in [p, p.shadow]:
			if m == null:
				continue
			m.info_log = []
			m.known_claims = {}
			m.beliefs = []
			m.ledger = {}
			for id in m.suspicion:
				m.suspicion[id] = 0.1
			Mind.refresh_beliefs(w, m, " (clean)")
	var L = w.living_good()[0]
	var others: Array = w.npcs.filter(func(x): return x != L)
	return {"g": g, "w": w, "L": L, "A": others[0], "B": others[1], "C": others[2], "D": others[3]}

func _seer(night: int, x: String, y: String) -> Dictionary:
	return {"day": night, "role": "seer", "data": {"pair": [x, y], "yes": true}, "text": "seer test"}

func _hang(w, who, day: int) -> void:
	who.alive = false
	who.death_day = day
	who.death_cause = "executed"
	w.public_event("execution", [who.id], "town")
	w.executions.append({"day": day, "id": who.id, "nominator": "player", "yes": [], "no": [], "player_yes": true, "player_nominated": true})

func _verdict(night: int, who: String, role: String) -> Dictionary:
	return {"day": night, "role": "gravedigger", "data": {"executed": who, "role": role}, "text": "verdict test"}

func _watch(night: int, block: String, seen: Array) -> Dictionary:
	return {"day": night, "role": "nightwatch", "data": {"block": block, "seen": seen}, "text": "watch test"}

func _doubt(t: Dictionary, src: String, night: int) -> void:
	Mind.ledger_hear(t["w"], t["L"], "arg:test-misled:%s:%d" % [src, night], [], 1.0, [],
		{"kind": "arg", "conclusion": {"type": "misled", "a": src, "night": night}})

func _h(t: Dictionary, id: String) -> float:
	var L = t["L"]
	var r_sd: float = Mind.reliability(L, id, -1, "report")
	var s_pen: float = clampf(0.8 * maxf(0.0, Mind.susp(L, id) - 0.1), 0.0, 0.7) if not Mind.demon_victim(t["w"], id) else 0.0
	return minf(r_sd, 1.0 - s_pen)

func _test_recovery() -> void:
	var t = _setup(5101)
	var w = t["w"]
	var L = t["L"]
	_hang(w, t["A"], 2)
	Mind.apply_info(w, L, t["A"], _seer(1, t["C"].id, t["D"].id), 0.5)
	var h0 = Mind.reliability(L, t["A"].id, 1)
	var s0 = Mind.susp(L, t["C"].id)
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.8)
	var h1 = Mind.reliability(L, t["A"].id, 1)
	var s1 = Mind.susp(L, t["C"].id)
	_doubt(t, t["B"].id, 2)
	var h2 = Mind.reliability(L, t["A"].id, 1)
	var s2 = Mind.susp(L, t["C"].id)
	_check(h1 < h0 and h2 > h1 and s1 < s0 and s2 > s1, "discrediting B's report lets A's claims recover")

func _test_independent_evidence() -> void:
	var t = _setup(5102)
	var w = t["w"]
	var L = t["L"]
	var vic = w.npcs.filter(func(p): return p not in [L, t["A"], t["B"], t["C"], t["D"]])[0]
	vic.home_block = "docks"
	t["A"].home_block = "square"
	w.day = 1
	w._kill(vic)
	w.day = 3
	_hang(w, t["A"], 2)
	Mind.apply_info(w, L, t["A"], _seer(1, t["C"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.8)
	Mind.apply_info(w, L, t["D"], _watch(1, "docks", [t["A"].id]), 0.8)
	_doubt(t, t["B"].id, 2)
	_check(Mind.susp(L, t["A"].id) > 0.12, "independent murder-block watch evidence against A keeps suspicion elevated")

func _test_poison_not_honesty() -> void:
	var t = _setup(5103)
	var w = t["w"]
	var L = t["L"]
	_hang(w, t["A"], 2)
	Mind.apply_info(w, L, t["B"], _seer(1, t["C"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.5)
	_doubt(t, t["B"].id, 2)
	var hb = Mind.reliability(L, t["B"].id, -1, "report")
	var r1 = Mind.reliability(L, t["B"].id, 1)
	var r2 = Mind.reliability(L, t["B"].id, 2)
	_check(hb >= 0.999 and r1 >= 0.999 and r2 < 0.5, "a poisoned reading doesn't damage B's honesty or their other readings")

func _test_stable_recompute() -> void:
	var t = _setup(5104)
	var w = t["w"]
	var L = t["L"]
	_hang(w, t["D"], 2)
	Mind.apply_info(w, L, t["A"], _seer(1, t["B"].id, t["C"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _seer(1, t["A"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["C"], _verdict(2, t["D"].id, "poisoner"), 0.5)
	_doubt(t, t["C"].id, 2)
	var before = _snapshot(t)
	for i in range(10):
		Mind.refresh_beliefs(w, L, "")
	var after = _snapshot(t)
	_check(before == after, "recomputing with no new evidence changes nothing")

func _test_other_source() -> void:
	var t = _setup(5205)
	var w = t["w"]
	var L = t["L"]
	var vic = w.npcs.filter(func(p): return p not in [L, t["A"], t["B"], t["C"], t["D"]])[0]
	vic.home_block = "docks"
	t["A"].home_block = "square"
	w.day = 2
	w._kill(vic)
	w.day = 3
	Mind.apply_info(w, L, t["A"], _seer(1, t["C"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _watch(2, "docks", [t["A"].id]), 0.8)
	var s1 = Mind.susp(L, t["A"].id)
	_doubt(t, t["B"].id, 2)
	var s2 = Mind.susp(L, t["A"].id)
	_check(s1 > 0.12 and s2 < s1, "doubting a Night Watch report retracts the suspicion it added")

func _test_mutual_accusation() -> void:
	var t = _setup(5106)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, t["A"], _seer(1, t["B"].id, t["C"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _seer(1, t["A"].id, t["D"].id), 0.5)
	var first = _snapshot(t)
	for i in range(20):
		Mind.refresh_beliefs(w, L, "")
	var last = _snapshot(t)
	_check(first == last, "mutual accusation is stable and bounded across repeated refreshes")

func _argue(t: Dictionary, eid: String, base: float, supports: Array, conclusion: Dictionary = {}) -> void:
	Mind.ledger_hear(t["w"], t["L"], eid, [], base * (0.5 + t["L"].trust), [],
		{"kind": "arg", "base": base, "supports": supports, "conclusion": conclusion})

func _eff(t: Dictionary, eid: String) -> float:
	return t["L"].ledger[eid]["eff"] if t["L"].ledger.has(eid) else 0.0

func _test_chained_deduction() -> void:
	var t = _setup(5107)
	var g = t["g"]
	var w = t["w"]
	var L = t["L"]
	g._workshop_native_submission = true
	g._workshop_native_social = true
	var kb = g.add_card(Mind.info_fact(w, t["B"], _seer(1, t["A"].id, t["C"].id)))
	var d1 = g.file_deduction({"type": "evil", "a": t["A"].id}, [kb])
	Argue.evaluate(w, L, g.board[d1 - 1], g.board, 1.0)
	var d2 = g.file_deduction({"type": "demon", "a": t["A"].id}, [d1])
	Argue.evaluate(w, L, g.board[d2 - 1], g.board, 1.0)
	g._workshop_native_submission = false
	g._workshop_native_social = false
	Mind.refresh_beliefs(w, L, " (chained deduction setup)")
	var e1 = "arg:" + Argue.conclusion_key({"type": "evil", "a": t["A"].id})
	var e2 = "arg:" + Argue.conclusion_key({"type": "demon", "a": t["A"].id})
	var a1 = _eff(t, e1)
	var a2 = _eff(t, e2)
	_doubt(t, t["B"].id, 1)
	var b1 = _eff(t, e1)
	var b2 = _eff(t, e2)
	_check(a2 > 0.0 and b1 < a1 and b2 < a2 * 0.7, "a deduction built on another weakens when the original evidence is discredited")

func _test_weak_restatement() -> void:
	var t = _setup(5108)
	var eid = "arg:test-evil-A"
	_argue(t, eid, 0.5, [[t["B"].id, 1, "reading"]], {"type": "evil", "a": t["A"].id})
	var strong = _eff(t, eid)
	_doubt(t, t["B"].id, 1)
	var discredited = _eff(t, eid)
	_argue(t, eid, 0.05, [["", -1, "evidence"]], {"type": "evil", "a": t["A"].id})
	var after = _eff(t, eid)
	_check(discredited < strong and after < strong * 0.5, "a weak restatement doesn't restore the discredited argument's strength")

func _test_poison_argument_undone() -> void:
	var t = _setup(5109)
	var w = t["w"]
	var L = t["L"]
	var B = t["B"].id
	var Cc = t["C"].id
	_hang(w, t["A"], 2)
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.8)
	var r0 = Mind.reliability(L, t["A"].id, 1)
	_argue(t, "arg:test-B-misled", 0.8, [[Cc, 1, "reading"]], {"type": "misled", "a": B, "night": 2})
	var r1 = Mind.reliability(L, t["A"].id, 1)
	_doubt(t, Cc, 1)
	var r2 = Mind.reliability(L, t["A"].id, 1)
	_check(r1 > r0 and r2 <= r1, "poison argument on B lifts A's reliability until C's support is doubted")

func _test_own_reading_poisoned() -> void:
	var t = _setup(5110)
	var w = t["w"]
	var L = t["L"]
	L.role = "seer"
	Mind.apply_info(w, L, L, _seer(1, t["C"].id, t["D"].id), 1.0)
	var s0 = Mind.susp(L, t["C"].id)
	_doubt(t, L.id, 1)
	var s1 = Mind.susp(L, t["C"].id)
	_check(s0 > 0.12 and s1 < s0 and Mind.reliability(L, L.id, 1) < 0.5, "own poisoned reading stops implicating people")

func _test_sightings_not_poisoned() -> void:
	var t = _setup(5111)
	var w = t["w"]
	var L = t["L"]
	var B = t["B"].id
	Mind.ledger_hear(w, L, "heard:test-sighting", [], 0.5, [B, 1, "report"])
	var before = _eff(t, "heard:test-sighting")
	_doubt(t, B, 1)
	var after = _eff(t, "heard:test-sighting")
	_check(absf(after - before) < 0.001, "poison doubt doesn't touch ordinary testimony")

func _other_role(t: Dictionary) -> String:
	for r in ["seer", "hearthwitch", "archivist", "clerk", "gravedigger"]:
		if r != t["L"].role:
			return r
	return "warden"

func _test_double_claim_shifts() -> void:
	var t = _setup(5112)
	var w = t["w"]
	var L = t["L"]
	var r = _other_role(t)
	var X = t["A"].id
	var Y = t["B"].id
	var sx0 = Mind.susp(L, X)
	var sy0 = Mind.susp(L, Y)
	Mind.hear_claim(w, L, X, r, 0.5, "public")
	Mind.hear_claim(w, L, Y, r, 0.5, "public")
	var dx1 = Mind.susp(L, X) - sx0
	var dy1 = Mind.susp(L, Y) - sy0
	Mind.apply_info(w, L, t["D"], _seer(1, Y, L.id), 0.8)
	_check(dx1 > 0.0 and dy1 > 0.0 and Mind.susp(L, Y) > Mind.susp(L, X), "a double claim raises suspicion on both claimants and shifts toward the one implicated by readings")

func _test_own_gift() -> void:
	var t = _setup(5113)
	var w = t["w"]
	var L = t["L"]
	var X = t["A"].id
	var s0 = Mind.susp(L, X)
	Mind.hear_claim(w, L, X, L.role, 0.5, "public")
	var s1 = Mind.susp(L, X)
	_check(s1 - s0 >= 0.4 and Mind.reliability(L, X, -1, "report") <= 0.1, "claiming the listener's own gift marks the claimant a liar in source_doubt and shared suspicion")

func _test_known_good_claimant() -> void:
	var t = _setup(5114)
	var w = t["w"]
	var L = t["L"]
	var r = _other_role(t)
	var X = t["A"].id
	var Y = t["B"]
	Mind.hear_claim(w, L, Y.id, r, 0.5, "public")
	Mind.hear_claim(w, L, X, r, 0.5, "public")
	var alive_s = Mind.susp(L, X)
	Y.alive = false
	Y.death_cause = "demon"
	w.public_event("demon_death", [Y.id], "town")
	Mind.ledger_hear(w, L, "demon_death:" + Y.id, [], 1.0, [], {"kind": "demon_death", "victim": Y.id})
	var dead_s = Mind.susp(L, X)
	_check(dead_s > alive_s, "a demon victim's claim counts more against a rival")

func _snapshot(t: Dictionary) -> String:
	var L = t["L"]
	var parts: Array = []
	for id in [t["A"].id, t["B"].id, t["C"].id, t["D"].id]:
		parts.append("%s:%.4f:%.4f" % [id, Mind.susp(L, id), _h(t, id)])
	return " ".join(PackedStringArray(parts))

func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		fails += 1
