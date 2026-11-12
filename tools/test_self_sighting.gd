## A good NPC's sighting of themselves on a night they know they spent at home is evidence
## about whoever told it (Project doc belief-model-direction, Nov 12; Reasoner.direct_checks).
##   - A plain sighting is kept in the weighing, not rejected; a Medium's relay and a Night
##     Watch list are still set aside (Reasoner.direct_checks says why).
##   - In real games: the framed NPC holds it against an evil sighter; a Sleepwalker seen by an
##     honest sighter stays well short of certain (Tuning.Workshop.SLEEPWALK_SELF_DOUBT); an
##     evil Medium's invented relay doesn't clear them.
extends SceneTree

const Game = preload("res://game/game.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Mind = preload("res://sim/mind.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	# direct_checks on a constructed case.
	var view: Dictionary = {"cards": [
		{"id": "seen", "kind": "sighting", "source": "c", "subject": "a", "subjects": ["a"], "night": 1, "block": "hill"},
		{"id": "relayed", "kind": "sighting", "source": "d", "subject": "a", "subjects": ["a"], "night": 1, "block": "hill",
			"relay_source": "m", "relay_observed_at": {"day": 2, "phase": "night"}},
		{"id": "nw", "kind": "report", "role": "nightwatch", "source": "e", "night": 1, "data": {"block": "hill", "seen": ["a"]}}]}
	var case_data: Dictionary = {"cards": ["seen", "relayed", "nw"], "conclusion": {"type": "evil", "target": "c", "at": "Original alignment"},
		"positions": {}, "answers": {}, "temporal_positions": []}
	var knowledge: Dictionary = {"self": "a", "good": ["a"], "own_outings": {"1": false}, "own_reports": []}
	var res: Dictionary = Reasoner.direct_checks(view, case_data, knowledge)
	check(not "seen" in res.rejected, "a sighting of me on a night I was home is kept")
	check("nw" in res.rejected, "a Night Watch's list naming me on a night I was home is still set aside (SourceDoubt voids it)")
	check("relayed" in res.rejected, "a Medium's relay naming me on that night is still set aside")
	check(res.objections.size() == 3, "all three still raise an objection for dialogue (%d)" % res.objections.size())
	knowledge.own_outings["1"] = true
	check(Reasoner.direct_checks(view, case_data, knowledge).objections.is_empty(), "no objection when I really was out")

	# Real games (passive play to a meeting), each a case found in the Nov 12 survey.
	_game_case(100034, 2, "odette", "constance", func(p): return p >= 0.6, "framed Odette holds Constance's fake sighting against her")
	_game_case(100031, 2, "edda", "constance", func(p): return p < 0.5, "the Sleepwalker Edda, seen by the honest Constance, is far from sure she lied")
	_game_case(100020, 3, "constance", "hollis", func(p): return p >= 0.8, "the evil Medium Hollis's invented relay doesn't clear him for Constance")
	print("Self-sighting: %d checks, %d failures" % [checks, fails])
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
