## Two people claiming one gift (BACKLOG, "A double claim of a unique gift raises both
## claimants"; Michael, Nov 16). Under connections the claims are read together as a built-in
## pairing, with the other cards naming a claimant as context: the claims raise both
## claimants, and a card that implicates or clears one moves the doubt between them.
## Any deal works (a good listener and four others), so no fixture search. The game is
## kept in the returned dictionary: the workshop refresh reaches it through the world.
##   godot --headless --path . --script res://tools/test_double_claim.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

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
	var gift: String = "seer" if L.role != "seer" else "hearthwitch"
	return {"g": g, "w": w, "L": L, "X": others[0].id, "Y": others[1].id, "Z": others[2].id, "D": others[3], "gift": gift}

func _susp(t: Dictionary) -> Array:
	return [Mind.susp(t.L, t.X), Mind.susp(t.L, t.Y)]

## A Dowser reading told to the listener: `count` evil between `who` and the listener.
func _dowse(t: Dictionary, who: String, count: int) -> void:
	Mind.apply_info(t.w, t.L, t.D, {"day": 1, "phase": 0, "role": "dowser", "data": {"group": [who, t.L.id], "count": count}, "text": "dowser test"}, 0.8)

func _init() -> void:
	# 1. One claim alone, then a rival claim: both claimants rise.
	var t: Dictionary = _setup(5512)
	var s0: Array = _susp(t)
	Mind.hear_claim(t.w, t.L, t.X, t.gift, 0.5, "public")
	var s1: Array = _susp(t)
	Mind.hear_claim(t.w, t.L, t.Y, t.gift, 0.5, "public")
	var s2: Array = _susp(t)
	print("claimants before %.3f / %.3f, after one claim %.3f / %.3f, after both %.3f / %.3f" % [s0[0], s0[1], s1[0], s1[1], s2[0], s2[1]])
	check(s2[0] > s1[0] + 0.05 and s2[1] > s1[1] + 0.05, "a rival claim of the same gift raises both claimants")
	check(s2[0] > s0[0] and s2[1] > s0[1], "both claimants end above where they started")
	# 2. A reading that implicates Y (one evil between Y and the good listener): the doubt
	# moves off X.
	_dowse(t, t.Y, 1)
	var s3: Array = _susp(t)
	print("after a reading implicating the second claimant: %.3f / %.3f" % [s3[0], s3[1]])
	check(s3[1] > s3[0], "the implicated claimant ends more suspected than the other")
	check(s3[0] < s2[0] - 0.05, "implicating one claimant lowers the other (the likelier liar is found)")
	# 3. The same reading without the rival claim: X isn't lowered by it, so the drop in 2
	# comes from the pairing.
	var u: Dictionary = _setup(5512)
	Mind.hear_claim(u.w, u.L, u.X, u.gift, 0.5, "public")
	var c1: Array = _susp(u)
	_dowse(u, u.Y, 1)
	var c2: Array = _susp(u)
	print("one claim only, before and after the reading on Y: %.3f -> %.3f" % [c1[0], c2[0]])
	check(s2[0] - s3[0] > c1[0] - c2[0], "the reading moves the first claimant further when a rival claimed the same gift")
	# 4. A reading that clears X (no evil between X and the listener): the doubt moves to Y.
	var v: Dictionary = _setup(5512)
	Mind.hear_claim(v.w, v.L, v.X, v.gift, 0.5, "public")
	Mind.hear_claim(v.w, v.L, v.Y, v.gift, 0.5, "public")
	var d1: Array = _susp(v)
	_dowse(v, v.X, 0)
	var d2: Array = _susp(v)
	print("after a reading clearing the first claimant: %.3f / %.3f (from %.3f / %.3f)" % [d2[0], d2[1], d1[0], d1[1]])
	check(d2[0] < d1[0] and d2[1] > d1[1], "clearing one claimant raises the other")
	# 5. Two claims of different gifts make no pairing: each claimant moves as with one claim.
	var x: Dictionary = _setup(5512)
	Mind.hear_claim(x.w, x.L, x.X, x.gift, 0.5, "public")
	var e1: float = Mind.susp(x.L, x.X)
	Mind.hear_claim(x.w, x.L, x.Y, "archivist" if x.gift != "archivist" and x.L.role != "archivist" else "clerk", 0.5, "public")
	var e2: float = Mind.susp(x.L, x.X)
	check(absf(e2 - e1) < 0.05, "a claim of a different gift doesn't raise the first claimant (%.3f -> %.3f)" % [e1, e2])
	# 6. Both claimants also share a reading of the gift (Codex, #198): a claimant's reading
	# declares the gift too, so the clash must still count, not vanish into the context.
	var y: Dictionary = _setup(5512)
	var r0: Array = _susp(y)
	var gift_reading := func(teller: String, night: int) -> Dictionary:
		return {"day": night, "phase": 0, "role": y.gift, "data": {"pair": [y.Z, y.D.id], "yes": false}, "text": "%s reading test" % y.gift}
	for who in [y.X, y.Y]:
		Mind.hear_claim(y.w, y.L, who, y.gift, 0.5, "public")
	Mind.apply_info(y.w, y.L, y.w.by_id[y.X], gift_reading.call(y.X, 1), 0.5)
	Mind.apply_info(y.w, y.L, y.w.by_id[y.Y], gift_reading.call(y.Y, 2), 0.5)
	var r1: Array = _susp(y)
	print("both claim and each shares a reading of the gift: %.3f / %.3f (from %.3f / %.3f)" % [r1[0], r1[1], r0[0], r0[1]])
	var pair_lean: Dictionary = {}
	for it in y.g._workshop_evaluations.get(y.L.id + ":good", {}).get("proposal", {}).get("connections", {}).get("items", []):
		if str(it.key) == "claims:" + y.gift:
			pair_lean = it.lean
	print("the pairing adds %+.2f / %+.2f log-odds" % [float(pair_lean.get(y.X, 0.0)), float(pair_lean.get(y.Y, 0.0))])
	check(float(pair_lean.get(y.X, 0.0)) > 0.3 and float(pair_lean.get(y.Y, 0.0)) > 0.3, "the clash still counts when each claimant has also shared a reading of the gift: the pairing raises both")
	print("Double claim: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
