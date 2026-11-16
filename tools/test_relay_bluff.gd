## A held Medium relay doesn't prove its relayer is a good Medium (Project doc
## belief-model-direction, Nov 12; RoleConstraints, bluffs). In play an evil relayer may have
## invented the relay, so a world with them evil stays possible and the relay is their bluff.
## Before this, a relay cleared an evil Medium bluffer outright (43 of 47 listener readings
## under 2% in a 60-game survey).
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	# Real games, each a kind of case found in the Nov 12 survey (then seeds 100059, 100019,
	# 100042 and 100020); searched for, so play changes don't break them (fixture_seeds.gd).
	var evil_relayer = func(t): return t.is_evil()
	var first: Dictionary = Seeds.relay(4, evil_relayer)
	_found_case(first, func(p): return p >= 0.5, "an evil relayer's relays don't clear them")
	if not first.is_empty():
		_found_case(Seeds.relay(5, evil_relayer, false, int(first.seed) + 1), func(p): return p >= 0.5, "nor in another game, later on")
	_found_case(Seeds.relay(3, func(t): return not t.is_evil() and t.role == "medium"), func(p): return p < 0.2, "a genuine Medium's relay still reads as good")
	_found_case(Seeds.relay(3, evil_relayer, true), func(p): return p >= 0.8, "an invented relay of the listener, seen out while they were home, counts against its relayer")
	print("Relay bluff: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _found_case(found: Dictionary, ok: Callable, label: String) -> void:
	if found.is_empty():
		check(false, "%s (no seed searched has the case)" % label)
		return
	var g = found.g
	var listener: String = str(found.listener)
	var teller: String = str(found.teller)
	label += " (seed %d: %s on %s)" % [int(found.seed), listener, teller]
	var n = g.w.by_id.get(listener)
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	var p: float = float(g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {}).get(teller, {}).get("posterior", -1.0))
	check(ok.call(p), "%s (%.2f)" % [label, p])
