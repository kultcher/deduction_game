## BACKLOG "A Delusional teller's false reading is charged twice by the judge" (Codex on
## #183; Michael, Nov 17). In play a world where the teller is the Delusional holder no
## longer checks their reading's content in the role check, as for an evil teller: the
## false-report likelihood already prices it. "They were Delusional" then stands next to
## "they lied" on equal terms, weighed by how likely each is, not one hundred times weaker.
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

func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	return {"people": people, "cards": [], "day": 2, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": [], "deaths": {}, "death_ticks": {}, "executions": {}},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional"]}}

func _reading() -> Dictionary:
	# a's Archivist reading: "one of c and d is the Poisoner".
	return {"id": "arch", "fact_id": "arch", "kind": "report", "source": "a", "role": "archivist", "night": 1,
		"data": {"pair": ["c", "d"], "role": "poisoner"}, "observed_at": {"day": 1, "phase": "night"}}

func _assess(view: Dictionary, card: Dictionary, challenge: Dictionary, listener: Dictionary) -> Dictionary:
	view.cards = [card]
	var value = Solver.empty_case()
	value.conclusion.at = view.alignment_epoch
	value.cards = [card.id]
	value.reading_challenges = {card.id: challenge}
	var r: Dictionary = Challenges.assess(view, value, listener, [card])
	return r.results[0] if not r.results.is_empty() else {}

func _init() -> void:
	var view: Dictionary = _view()
	var card: Dictionary = _reading()
	view.cards = [card]
	# World: f the Demon, g the Poisoner; c and d good, so the reading is false.
	var world: Dictionary = {"evil": (1 << 5) | (1 << 6), "demon": 5, "marked": -1, "modifier": "delusional", "holders": 1 << 0}
	check(Solver.Roles.fit_weight(view, world, [card], {}, {}, true) > 0.0, "a Delusional Archivist's false reading leaves the world standing (in play)")
	var bystander: Dictionary = world.duplicate(true)
	bystander.holders = 1 << 1
	check(Solver.Roles.fit_weight(view, bystander, [card], {}, {}, true) == 0.0, "a Delusional bystander doesn't excuse a healthy Archivist")
	var co: Dictionary = card.duplicate(true)
	co["content_only"] = true
	check(Solver.Roles.fit_weight(view, world, [co], {}, {}, true) == 0.0, "the content-only mask still judges the reading's content")
	# The town's view: a listener who knows c and d are good, so the reading is wrong.
	var listener = Ghost.profile(view.people)
	listener.knowledge = {"good": ["c", "d"], "evil": []}
	var lying: Dictionary = _assess(view.duplicate(true), card, {"mode": "lying", "supports": []}, listener)
	var deluded: Dictionary = _assess(view.duplicate(true), card, {"mode": "delusional", "supports": [], "group": ["arch"]}, listener)
	var lie_a: float = float(lying.get("agreement", 0.0))
	var del_a: float = float(deluded.get("agreement", 0.0))
	var lie_share: float = float(lying.get("graded", {}).get("cause", 0.0))
	var del_share: float = float(deluded.get("graded", {}).get("cause", 0.0))
	print("wrong Archivist reading explained: by a lie %.3f, by a Delusional reader %.3f" % [lie_share, del_share])
	# Before the fix: 0.984 and 0.002 (the Delusional world took a 1%% error on top of q).
	check(del_share > 0.05, "'they were Delusional' is a live explanation of a wrong reading (%.3f)" % del_share)
	check(lie_share < 0.95, "'they lied' no longer takes nearly all of it (%.3f)" % lie_share)
	check(lie_share + del_share <= 1.0 + 1e-6, "the explanations share one wrongness")
	print("delusional reading: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
