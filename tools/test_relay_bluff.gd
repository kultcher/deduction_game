## A held Medium relay doesn't prove its relayer is a good Medium (Project doc
## belief-model-direction, Nov 12; RoleConstraints, bluffs). In play an evil relayer may have
## invented the relay, so a world with them evil stays possible and the relay is their bluff.
## Before this, a relay cleared an evil Medium bluffer outright (43 of 47 listener readings
## under 2% in a 60-game survey).
extends SceneTree

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
	_game_case(100059, 4, "merrin", "bart", func(p): return p >= 0.5, "the evil Bart's relays don't clear him for Merrin")
	_game_case(100019, 5, "isolde", "fenwick", func(p): return p >= 0.5, "the evil Fenwick's relays don't clear him for Isolde")
	_game_case(100039, 3, "nisha", "merrin", func(p): return p < 0.2, "the genuine Medium Merrin's relay still reads as good for Nisha")
	_game_case(100020, 3, "constance", "hollis", func(p): return p >= 0.8, "Hollis's invented relay of Constance, seen out while she was home, counts against him")
	print("Relay bluff: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _game_case(seed_v: int, day: int, listener: String, teller: String, ok: Callable, label: String) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, 7)
	var guard := 0
	while g.state != "over" and guard < 400 and not (g.state == "meeting" and g.w.day >= day):
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	var n = g.w.by_id.get(listener)
	if g.state != "meeting" or n == null or not n.alive:
		check(false, "%s (seed %d did not reach the day-%d meeting with %s alive)" % [label, seed_v, day, listener])
		return
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	var p: float = float(g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {}).get(teller, {}).get("posterior", -1.0))
	check(ok.call(p), "%s (%.2f)" % [label, p])
