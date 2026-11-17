## BACKLOG "Challenge a Warden's particular failed protection claim" (built Nov 4, #81, in
## the report table; this suite pins it). A Warden's report "on night N I guarded X" where
## the Demon killed X that night: a healthy guard holds, so the report is never a true,
## healthy reading. What remains is a lie (an evil Warden: Michael, Oct 27, a good Warden
## wouldn't fabricate this) or a failed gift (poisoned or Delusional). The Warden's walk to
## the door is the movement model's and stands apart. Neither a challenge nor the failure
## proves poisoning or alignment.
extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _view(killed: bool) -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var events: Array = [{"kind": "demon_death", "subjects": ["d"], "at": {"day": 2, "phase": "night"}}] if killed else []
	return {"people": people, "cards": [], "day": 3, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": events, "deaths": {"d": 3} if killed else {}, "death_ticks": {"d": 11} if killed else {}, "executions": {}},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional"]}}

func _guard(target: String) -> Dictionary:
	return {"id": "guard", "fact_id": "guard", "kind": "report", "source": "a", "role": "warden", "night": 2, "block": "square",
		"data": {"target": target}, "observed_at": {"day": 2, "phase": "night"}}

func _challenge(view: Dictionary, guard: Dictionary, mode: String) -> Dictionary:
	view.cards = [guard]
	var listener = Ghost.profile(view.people)
	listener.knowledge = {"good": [], "evil": []}
	var value = Solver.empty_case()
	value.conclusion.at = view.alignment_epoch
	value.cards = [guard.id]
	value.reading_challenges = {guard.id: {"mode": mode, "supports": []}}
	var r: Dictionary = Challenges.assess(view, value, listener, [guard])
	return r.results[0] if not r.results.is_empty() else {}

func _init() -> void:
	var know := {"good": [], "evil": []}
	var guard: Dictionary = _guard("d")
	var alive: Dictionary = _view(false)
	var killed: Dictionary = _view(true)
	check(not Solver.solve(alive, [guard], {}, {}, know).worlds.is_empty(), "a guard report fits a healthy Warden when the guarded person lived")
	check(Solver.solve(killed, [guard], {}, {}, know).worlds.is_empty(), "the guarded person killed that night: never a true, healthy guard")
	check(not Solver.solve(killed, [_guard("e")], {}, {}, know).worlds.is_empty(), "someone else's death that night says nothing about this guard")
	# The challenge, against that night's death.
	var lying: Dictionary = _challenge(killed.duplicate(true), guard, "lying")
	var impaired: Dictionary = _challenge(killed.duplicate(true), guard, "impaired")
	check(lying.get("supported", false) and impaired.get("supported", false), "both a lie and a failed gift are supported against that night's death")
	check(float(impaired.get("multiplier", 1.0)) < 1.0, "a failed gift discounts the guard report")
	check(float(lying.get("agreement", 0.0)) > float(impaired.get("agreement", 0.0)), "a neutral listener lays most of it on a lie (a poisoned good Warden reads as a liar, as intended)")
	check(float(impaired.get("agreement", 1.0)) < 0.5, "a failed-gift challenge doesn't prove poisoning")
	var healthy: Dictionary = _challenge(alive.duplicate(true), guard, "impaired")
	check(not healthy.get("supported", true) or float(healthy.get("multiplier", 1.0)) == 1.0, "with the guarded person alive, a failed-gift challenge has nothing to stand on")
	print("warden challenge: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
