## Withheld readings, the cost (docs/design/withheld_readings.md §4; Michael, Nov 28): a
## claimant that holds back an owed reading when asked looks a little more suspicious to whoever
## saw the refusal. A fixed cost, alignment-blind: 1.15 for a deferral, 1.6 for a deflection,
## growing 1.25-fold a day while the reading is out; one cost per reading, at the listener's
## distrust of the claimant; lifted for a deferral once the reading is shared, kept for a
## deflection. Also checks who sees a refusal (game/workshop_bridge.gd's withheld_seen).
##   godot --headless --path . --script res://tools/test_withheld_cost.gd
extends SceneTree

const Connections = preload("res://workshop/connections.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Game = preload("res://game/game.gd")
const Ownership = preload("res://game/workshop_ownership.gd")
const MindWithheld = preload("res://sim/mind_withheld.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _r(kind: String, day: int, night: int = 1, shared_day: int = -1, claimant: String = "s") -> Dictionary:
	return {"claimant": claimant, "role": "seer", "night": night, "day": day, "kind": kind, "shared_day": shared_day}

## The claimant's chance from even odds after the cost.
func _from_even(refusals: Array, day: int, trust: float = 0.5) -> float:
	var listener: Dictionary = {"id": "a", "npc_trust": {"s": trust, "t": trust}, "withheld": refusals}
	var lean: Dictionary = Connections.withheld(listener, day, ["s", "t", "u"]).lean
	return Connections.chance(float(lean.get("s", 0.0)))

func _init() -> void:
	var defer0: float = _from_even([_r("deferred", 2)], 2)
	var deflect0: float = _from_even([_r("deflected", 2)], 2)
	var deflect3: float = _from_even([_r("deflected", 2)], 4)
	var deflect5: float = _from_even([_r("deflected", 1)], 5)
	print("from even: deferral %.3f, deflection %.3f, deflection on its third day %.3f, on its fifth %.3f" % [defer0, deflect0, deflect3, deflect5])
	check(absf(defer0 - 1.15 / 2.15) < 1e-9, "a deferral, at typical trust, takes even odds to 1.15:1 (%.3f)" % defer0)
	check(absf(deflect0 - 1.6 / 2.6) < 1e-9, "a deflection takes them to 1.6:1 (%.3f)" % deflect0)
	check(absf(deflect3 - 0.676) < 0.002, "on the third day outstanding a deflection reaches about 68%% (%.3f)" % deflect3)
	check(absf(deflect5 - 0.759) < 0.002, "on the fifth, about 76%% (%.3f)" % deflect5)
	# No stacking: asked five times over the same reading, it counts once, at the strongest kind
	# seen, aged from the first refusal.
	var many: Array = [_r("deferred", 2), _r("deferred", 3), _r("deflected", 3), _r("deferred", 4), _r("deflected", 4)]
	check(absf(_from_even(many, 4) - _from_even([_r("deflected", 2)], 4)) < 1e-12, "five refusals of one reading count as one deflection from its first day")
	# A different reading (another night) is another cost.
	check(_from_even([_r("deferred", 2, 1), _r("deferred", 2, 2)], 2) > defer0 + 0.01, "two withheld readings cost more than one")
	# Trust: full trust cancels it; none doubles it on the log-odds scale.
	check(absf(_from_even([_r("deflected", 2)], 2, 1.0) - 0.5) < 1e-12, "a listener that fully trusts the claimant takes no cost")
	check(absf(_from_even([_r("deflected", 2)], 2, 0.0) - 1.6 * 1.6 / (1.6 * 1.6 + 1.0)) < 1e-9, "one that doesn't trust it at all counts it twice over")
	# Sharing: a deferral's cost is lifted, a deflection's stays where it stood that day.
	check(absf(_from_even([_r("deferred", 2, 1, 3)], 5) - 0.5) < 1e-12, "a deferral's cost is lifted once the reading is shared")
	check(absf(_from_even([_r("deflected", 2, 1, 3)], 5) - _from_even([_r("deflected", 2)], 3)) < 1e-12, "a deflection's stays, frozen on the day it was shared")
	# Never on the listener itself, nor on someone outside the question.
	var own: Dictionary = Connections.withheld({"id": "s", "npc_trust": {}, "withheld": [_r("deflected", 2)]}, 3, ["s", "t"])
	check(own.lean.is_empty(), "a listener's own refusal costs it nothing in its own eyes")
	check(Connections.withheld({"id": "a", "npc_trust": {}, "withheld": [_r("deflected", 2, 1, -1, "x")]}, 3, ["s", "t"]).lean.is_empty(), "nor does anyone the baseline settles")
	# Who saw it: the asker of a private refusal, everyone for one at the meeting.
	var w: Dictionary = {"withheld_refusals": [
		{"asker": "a", "claimant": "s", "claim": {"day": 1, "role": "seer"}, "tick": 9, "day": 2, "venue": "private", "kind": "deferred", "reason": "friend", "known_to": ["a"]},
		{"asker": "player", "claimant": "t", "claim": {"day": 1, "role": "seer"}, "tick": 10, "day": 2, "venue": "meeting", "kind": "deflected", "reason": "", "known_to": ["public"], "shared_at": 13}]}
	var seen_a: Array = Bridge.withheld_seen(w, {"id": "a"})
	var seen_b: Array = Bridge.withheld_seen(w, {"id": "b"})
	var seen_s: Array = Bridge.withheld_seen(w, {"id": "s"})
	check(seen_a.size() == 2 and seen_b.size() == 1 and seen_b[0].claimant == "t", "a private refusal is seen by its asker alone, one at the meeting by everyone")
	check(seen_s.size() == 1 and seen_s[0].claimant == "t", "the claimant doesn't count its own refusal")
	check(int(seen_a.filter(func(r): return r.claimant == "t")[0].shared_day) == 3, "the day the reading came out is read from its tick")
	_in_play()
	print("Withheld cost: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## In play: a good NPC's belief refresh picks up a refusal it saw, and only one it saw.
func _in_play() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(1, 10)
	g.w.day = 2
	var good: Array = g.w.living_good()
	var a = good[0]
	var b = good[1]
	var s = g.w.living().filter(func(m): return m != a and m != b)[0]
	Ownership.refresh(g, a)
	Ownership.refresh(g, b)
	var a0: float = float(a.suspicion.get(s.id, 0.0))
	var b0: float = float(b.suspicion.get(s.id, 0.0))
	g.w.withheld_refusals.append({"asker": a.id, "claimant": s.id, "claim": {"day": 1, "role": "seer"}, "tick": 9, "day": 2,
		"venue": "private", "kind": "deflected", "reason": "", "known_to": [a.id]})
	Ownership.refresh(g, a)
	Ownership.refresh(g, b)
	var a1: float = float(a.suspicion.get(s.id, 0.0))
	var b1: float = float(b.suspicion.get(s.id, 0.0))
	print("in play: %s's suspicion of %s %.3f -> %.3f after a private deflection; %s (not asked) %.3f -> %.3f" % [a.name, s.name, a0, a1, b.name, b0, b1])
	check(a1 > a0 + 0.01, "the asker's refresh raises its suspicion of a claimant that deflected it")
	check(absf(b1 - b0) < 1e-9, "a listener that didn't see the private refusal is unmoved")
	# Recording a refusal refreshes whoever saw it, so the cost lands at once (Codex on #592).
	var c = g.w.living().filter(func(m): return m != a and m != b and m != s)[0]
	var a2: float = float(a.suspicion.get(c.id, 0.0))
	var b2: float = float(b.suspicion.get(c.id, 0.0))
	MindWithheld.record_refusal(g.w, a.id, c, {"day": 1, "role": "seer"}, "private", "deflected", "")
	check(float(a.suspicion.get(c.id, 0.0)) > a2 + 0.01 and absf(float(b.suspicion.get(c.id, 0.0)) - b2) < 1e-9,
		"recording a private refusal moves its asker at once, and no one else (%.3f -> %.3f)" % [a2, float(a.suspicion.get(c.id, 0.0))])
	# A refusal before the town, then the reading told to one listener in private: shared for
	# that listener alone (Codex on #592).
	g.w.withheld_refusals.clear()
	MindWithheld.record_refusal(g.w, "player", c, {"day": 1, "role": "seer"}, "meeting", "deferred", "friend")
	MindWithheld.note_shared(g.w, c, {"role": "seer", "day": 1}, b.id)
	var for_b: Array = Bridge.withheld_seen(g.w, b)
	var for_a: Array = Bridge.withheld_seen(g.w, a)
	check(for_b.size() == 1 and int(for_b[0].shared_day) == g.w.day and for_a.size() == 1 and int(for_a[0].shared_day) == -1,
		"a publicly refused reading told to one listener is shared for it alone (%s / %s)" % [for_b, for_a])
