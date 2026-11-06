## Meeting plan M4, the bot's reading of the board (tools/analyst.gd):
##   - Exclusion cards (an empty vigil, a complete vigil list) bear on a claimed walker the
##     vigil should have seen, and only on them; --pre-m4 turns that off.
##   - The Demon guess reads P(Demon): it sums to about 1 over the town.
## The play policy itself (press, vigils, nominations) is exercised by the autoplay sweeps.
##   godot --headless --path . --script res://tools/test_bot_m4.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Analyst = preload("res://tools/analyst.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_exclusion()
	_test_demon_posterior()
	print("Bot M4: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_exclusion() -> void:
	var claim_walker: Dictionary = {"id": "c1", "kind": "claim", "source": "ann", "subject": "ann", "role": "lamplighter"}
	var claim_still: Dictionary = {"id": "c2", "kind": "claim", "source": "bob", "subject": "bob", "role": "seer"}
	var empty_vigil: Dictionary = {"id": "v1", "kind": "coverage", "block": "square", "excluded": ["cat"]}
	var vigil_list: Dictionary = {"id": "v2", "kind": "sighting", "complete": true, "block": "square", "subjects": ["dan"], "excluded": []}
	var view: Dictionary = {"cards": [claim_walker, claim_still, empty_vigil, vigil_list]}
	_check(Analyst._bears_on(view, empty_vigil, "ann"), "an empty vigil bears on a claimed walker")
	_check(Analyst._bears_on(view, vigil_list, "ann"), "a complete vigil list that leaves them out bears on a claimed walker")
	_check(not Analyst._bears_on(view, empty_vigil, "bob"), "it doesn't bear on someone whose claim doesn't walk")
	_check(not Analyst._bears_on(view, empty_vigil, "cat"), "or on someone the vigil excludes")
	_check(not Analyst._bears_on(view, empty_vigil, "ann", false), "the pre-M4 policy leaves exclusion cards out")
	_check(Analyst._bears_on(view, vigil_list, "dan", false), "a vigil still bears on the people it saw")


func _test_demon_posterior() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(1001, 7)
	var guard: int = 0
	while g.state != "over" and g.w.day < 2 and guard < 200:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	var state: Dictionary = Analyst.new_state(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var evil_p: Dictionary = Analyst.belief(g, state, rng)
	_check(not state.accepted.is_empty(), "the juror accepts some of the board by Day 2 (%d cards)" % state.accepted.size())
	var total: float = 0.0
	var bounded: bool = true
	for n in g.w.npcs:
		var p: float = Analyst.demon_posterior(g, state, n.id)
		bounded = bounded and p >= 0.0 and p <= float(evil_p.get(n.id, 1.0)) + 1e-6
		total += p
	_check(bounded, "P(Demon) is never above P(evil)")
	_check(absf(total - 1.0) < 0.05, "P(Demon) sums to about 1 over the town (%.3f)" % total)
