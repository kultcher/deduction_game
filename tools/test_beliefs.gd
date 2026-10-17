## Acceptance tests for credibility and belief revision (the evidence ledger).
##   godot --headless --path . --script res://tools/test_beliefs.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

var fails = 0

func _init() -> void:
	_test_recovery()
	_test_independent_evidence()
	_test_poison_not_honesty()
	_test_stable_recompute()
	_test_other_source()
	_test_mutual_accusation()
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
	var t = _setup(5105)
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
