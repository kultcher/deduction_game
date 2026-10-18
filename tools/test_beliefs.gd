## Acceptance tests for credibility and belief revision (the evidence ledger).
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
	quit()

## A fresh case: listener L (good) and four others.
func _setup(sd: int) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd)
	var w = g.w
	var L = w.living_good()[0]
	var others: Array = w.npcs.filter(func(x): return x != L)
	return {"g": g, "w": w, "L": L, "A": others[0], "B": others[1], "C": others[2], "D": others[3]}

func _seer(night: int, x: String, y: String) -> Dictionary:
	return {"day": night, "role": "seer", "data": {"pair": [x, y], "yes": true}, "text": "seer test"}

func _verdict(night: int, who: String, role: String) -> Dictionary:
	return {"day": night, "role": "gravedigger", "data": {"executed": who, "role": role}, "text": "verdict test"}

func _watch(night: int, block: String, seen: Array) -> Dictionary:
	return {"day": night, "role": "nightwatch", "data": {"block": block, "seen": seen}, "text": "watch test"}

## The player convinces L that src's reading on that night was misled (poisoned).
func _doubt(t: Dictionary, src: String, night: int) -> void:
	Mind.ledger_hear(t["w"], t["L"], "arg:test-misled:%s:%d" % [src, night],
		[["disc:%s:%d" % [src, night], 0.9, false, "test: misled", ""]], 1.0, [], {"kind": "arg"})

func _h(t: Dictionary, id: String) -> float:
	return t["L"].honesty.get(id, 1.0)

# 1. Discrediting B's report lets A's claims recover.
func _test_recovery() -> void:
	var t = _setup(5101)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, t["A"], _seer(1, t["C"].id, t["D"].id), 0.5)
	var h0 = _h(t, t["A"].id)
	var s0 = Mind.susp(L, t["C"].id)
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.5)
	var h1 = _h(t, t["A"].id)
	var s1 = Mind.susp(L, t["C"].id)
	_doubt(t, t["B"].id, 2)
	var h2 = _h(t, t["A"].id)
	var s2 = Mind.susp(L, t["C"].id)
	print("1. A's credibility %.2f -> %.2f (B: A was the Poisoner) -> %.2f (B's report doubted); A's reading on C: %.2f -> %.2f -> %.2f" % [h0, h1, h2, s0, s1, s2])
	_check(h1 < h0 and h2 > h1 and s1 < s0 and s2 > s1, "discrediting B's report lets A's claims recover")

# 2. Independent evidence against A keeps them partly discounted.
func _test_independent_evidence() -> void:
	var t = _setup(5102)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, t["A"], _seer(1, t["C"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.5)
	Mind.apply_info(w, L, t["D"], _watch(1, t["A"].home_block, [t["A"].id]), 0.5)  # D saw A out at night
	_doubt(t, t["B"].id, 2)
	var h = _h(t, t["A"].id)
	print("2. With D's sighting still standing, A's credibility is %.2f" % h)
	_check(h < 1.0, "independent evidence against A keeps them partly discounted")

# 3. Poisoning B's reading doesn't damage B's honesty.
func _test_poison_not_honesty() -> void:
	var t = _setup(5103)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, t["B"], _seer(1, t["C"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.5)
	_doubt(t, t["B"].id, 2)
	var hb = _h(t, t["B"].id)
	var r1 = Mind.reliability(L, t["B"].id, 1)
	var r2 = Mind.reliability(L, t["B"].id, 2)
	print("3. B's credibility %.2f; B's night-1 reading %.2f, night-2 reading %.2f" % [hb, r1, r2])
	_check(hb >= 0.999 and r1 >= 0.999 and r2 < 0.5, "a poisoned reading doesn't damage B's honesty or their other readings")

# 4. Repeated reevaluation with no new evidence doesn't keep hardening beliefs.
func _test_stable_recompute() -> void:
	var t = _setup(5104)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, t["A"], _seer(1, t["B"].id, t["C"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _seer(1, t["A"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["C"], _verdict(2, t["D"].id, "poisoner"), 0.5)
	_doubt(t, t["C"].id, 2)
	var before = _snapshot(t)
	for i in range(10):
		Mind.recompute_beliefs(w, L, "")
	var after = _snapshot(t)
	print("4. after 10 recomputes: %s" % ("identical" if before == after else "changed: %s -> %s" % [before, after]))
	_check(before == after, "recomputing with no new evidence changes nothing")

# 5. The same chain works when the evidence against A comes from another source.
func _test_other_source() -> void:
	var t = _setup(5205)  # (re-seeded when the roster changed; the old seed's new setup masked the effect)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, t["A"], _seer(1, t["C"].id, t["D"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _watch(2, t["A"].home_block, [t["A"].id]), 0.5)  # a Night Watch, not a Gravedigger
	var h1 = _h(t, t["A"].id)
	_doubt(t, t["B"].id, 2)
	var h2 = _h(t, t["A"].id)
	print("5. Night Watch evidence: A's credibility %.2f -> %.2f once that watch is doubted" % [h1, h2])
	_check(h1 < 1.0 and h2 > h1, "the chain works with evidence from another role")

# 6. A and B accusing each other stays stable and doesn't amplify.
func _test_mutual_accusation() -> void:
	var t = _setup(5106)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, t["A"], _seer(1, t["B"].id, t["C"].id), 0.5)
	Mind.apply_info(w, L, t["B"], _seer(1, t["A"].id, t["D"].id), 0.5)
	var first = _snapshot(t)
	for i in range(20):
		Mind.recompute_beliefs(w, L, "")
	var last = _snapshot(t)
	print("6. mutual accusation: A %.2f, B %.2f; after 20 recomputes %s" % [_h(t, t["A"].id), _h(t, t["B"].id), "unchanged" if first == last else "changed"])
	_check(first == last and _h(t, t["A"].id) >= 0.5 and _h(t, t["B"].id) >= 0.5, "mutual accusation is stable and bounded")

## An argument the listener accepts, resting on the given supports ([source, night, kind]).
func _argue(t: Dictionary, eid: String, effects: Array, base: float, supports: Array) -> void:
	Mind.ledger_hear(t["w"], t["L"], eid, effects, base * (0.5 + t["L"].trust), [],
		{"kind": "arg", "base": base, "supports": supports})

func _eff(t: Dictionary, eid: String) -> float:
	return t["L"].ledger[eid]["eff"] if t["L"].ledger.has(eid) else 0.0

# 7. A deduction built on another deduction weakens when the original evidence is discredited.
#    (Through the real filing and evaluation path.)
func _test_chained_deduction() -> void:
	var t = _setup(5107)
	var g = t["g"]
	var w = t["w"]
	var L = t["L"]
	var kb = g.add_card(Mind.info_fact(w, t["B"], _seer(1, t["A"].id, t["C"].id)))
	var d1 = g.file_deduction({"type": "evil", "a": t["A"].id}, [kb])
	Argue.evaluate(w, L, g.board[d1 - 1], g.board, 1.0)
	var d2 = g.file_deduction({"type": "demon", "a": t["A"].id}, [d1])
	Argue.evaluate(w, L, g.board[d2 - 1], g.board, 1.0)
	var e1 = "arg:" + Argue.conclusion_key({"type": "evil", "a": t["A"].id})
	var e2 = "arg:" + Argue.conclusion_key({"type": "demon", "a": t["A"].id})
	var a1 = _eff(t, e1)
	var a2 = _eff(t, e2)
	_doubt(t, t["B"].id, 1)
	var b1 = _eff(t, e1)
	var b2 = _eff(t, e2)
	print("7. 'A is evil' %.3f -> %.3f; 'A is the demon' (built on it) %.3f -> %.3f once B's reading is doubted" % [a1, b1, a2, b2])
	_check(a2 > 0.0 and b1 < a1 and b2 < a2 * 0.7, "a deduction built on another weakens when the original evidence is discredited")

# 8. Restating a conclusion with weaker evidence can't restore its old strength.
func _test_weak_restatement() -> void:
	var t = _setup(5108)
	var A = t["A"].id
	var eid = "arg:test-evil-A"
	var effs = [[A, 0.45, true, "test", ""]]
	_argue(t, eid, effs, 0.5, [[t["B"].id, 1, "reading"]])  # strong, rests on B's reading
	var strong = _eff(t, eid)
	_doubt(t, t["B"].id, 1)
	var discredited = _eff(t, eid)
	_argue(t, eid, effs, 0.05, [["", -1, "evidence"]])      # weak restatement, other support
	var after = _eff(t, eid)
	print("8. strong %.3f -> discredited %.3f -> after a weak restatement %.3f" % [strong, discredited, after])
	_check(after < strong * 0.5, "a weak restatement doesn't restore the discredited argument's strength")

# 9. B says A was evil; C's evidence says B was poisoned; then C's evidence is discredited:
#    A's credibility should fall again.
func _test_poison_argument_undone() -> void:
	var t = _setup(5109)
	var w = t["w"]
	var L = t["L"]
	var B = t["B"].id
	var Cc = t["C"].id
	Mind.apply_info(w, L, t["B"], _verdict(2, t["A"].id, "poisoner"), 0.5)
	var h0 = _h(t, t["A"].id)
	_argue(t, "arg:test-B-misled", [["disc:%s:2" % B, 0.9, false, "test", ""]], 0.8, [[Cc, 1, "reading"]])
	var h1 = _h(t, t["A"].id)
	_doubt(t, Cc, 1)
	var h2 = _h(t, t["A"].id)
	print("9. A's credibility %.2f (B's verdict) -> %.2f (C shows B was poisoned) -> %.2f (C's reading doubted)" % [h0, h1, h2])
	_check(h1 > h0 and h2 < h1 - 0.05, "undoing the poison argument undoes its effect on A")

# 10. Accepting that your own reading was poisoned restores the people it implicated.
func _test_own_reading_poisoned() -> void:
	var t = _setup(5110)
	var w = t["w"]
	var L = t["L"]
	Mind.apply_info(w, L, L, _seer(1, t["C"].id, t["D"].id), 1.0)
	var h0 = _h(t, t["C"].id)
	_doubt(t, L.id, 1)
	var h1 = _h(t, t["C"].id)
	print("10. C's credibility %.2f under my own reading -> %.2f once I accept my reading was poisoned (my reading now %.2f)" % [h0, h1, Mind.reliability(L, L.id, 1)])
	_check(h0 < 1.0 and h1 > h0 and Mind.reliability(L, L.id, 1) < 0.5, "own poisoned reading stops implicating people")

# 11. "B's gift failed that night" doesn't discount B's ordinary eyewitness report.
func _test_sightings_not_poisoned() -> void:
	var t = _setup(5111)
	var w = t["w"]
	var L = t["L"]
	var B = t["B"].id
	Mind.ledger_hear(w, L, "heard:test-sighting", [[t["A"].id, 0.3, true, "B saw A out", ""]], 0.5, [B, 1, "report"])
	var before = _eff(t, "heard:test-sighting")
	_doubt(t, B, 1)
	var after = _eff(t, "heard:test-sighting")
	print("11. B's sighting of A: influence %.3f -> %.3f after B's night-1 reading is doubted" % [before, after])
	_check(absf(after - before) < 0.001, "poison doubt doesn't touch ordinary testimony")

## A role that isn't the listener's own (so their own record doesn't interfere).
func _other_role(t: Dictionary) -> String:
	for r in ["seer", "hearthwitch", "archivist", "clerk", "gravedigger"]:
		if r != t["L"].role:
			return r
	return "warden"

# 12. Two people claim one gift: the suspicion splits by credence, and shifts when one
#     claimant's credibility falls.
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
	# Evidence against Y (someone reports seeing them out) lowers Y's credibility.
	Mind.apply_info(w, L, t["C"], _watch(1, t["B"].home_block, [Y]), 0.5)
	Mind.apply_info(w, L, t["D"], _seer(1, Y, L.id), 0.5)
	var cx = Mind.claim_credence(L, X, r)
	var cy = Mind.claim_credence(L, Y, r)
	print("12. double claim: +%.2f / +%.2f each; after evidence against Y, credence X %.2f vs Y %.2f" % [dx1, dy1, cx, cy])
	_check(dx1 > 0.0 and dy1 > 0.0 and cy < cx, "a double claim resolves by credence, and shifts with credibility")

# 13. Someone claims the listener's own gift: the listener knows they're lying.
func _test_own_gift() -> void:
	var t = _setup(5113)
	var w = t["w"]
	var L = t["L"]
	var X = t["A"].id
	var s0 = Mind.susp(L, X)
	Mind.hear_claim(w, L, X, L.role, 0.5, "public")
	var s1 = Mind.susp(L, X)
	print("13. %s (the real %s) hears %s claim it: suspicion %.2f -> %.2f, credibility %.2f" % [L.name, L.role, t["A"].name, s0, s1, _h(t, X)])
	_check(s1 - s0 >= 0.5 and _h(t, X) <= 0.6, "claiming the listener's own gift marks the claimant a liar")

# 14. The claim of someone the demon killed is believed: a rival claim weighs more heavily.
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
	Mind.recompute_beliefs(w, L, "")
	var dead_s = Mind.susp(L, X)
	print("14. rival of a living claimant: %.2f; once that claimant is killed by the demon: %.2f" % [alive_s, dead_s])
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
