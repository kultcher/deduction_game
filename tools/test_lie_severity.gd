## BACKLOG "Lie severity" (Michael, Nov 17): a false gift report weighs more than a
## whereabouts lie, unless the lie puts them near the crime. A good person's own "I was
## home" is no longer certain (Tuning.Workshop.GOOD_OWN_ALIBI_OUT), so being caught out is
## evidence, not proof; the kill scene still counts through the scene reasoning. A neutral
## juror, seven people, two evil, one killed on the Square on the first night.
extends SceneTree
const History = preload("res://workshop/live_history.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": {"a": "hill", "g": "square"}.get(id, "market")})
	return {"people": people, "cards": [], "evil_count": 2, "day": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": History.from_events([{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1, "phase": "night"}}]),
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional", "sleepwalker", "lovers"]}}
func _p(view: Dictionary, cards: Array) -> float:
	view.cards = cards
	var c = Solver.empty_case()
	c.conclusion = {"type": "evil", "target": "a", "at": view.alignment_epoch}
	c.cards = cards.map(func(x): return x.id)
	return float(CaseEval.evaluate(view, c, CaseEval.neutral_listener(view)).get("posterior", -1))
var checks = 0
var fails = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init():
	var own = {"id": "own", "fact_id": "own", "kind": "alibi", "source": "a", "subject": "a", "subjects": ["a"], "night": 1, "block": "hill", "data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	var away = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": 1, "block": "docks", "data": {}, "role": "", "hearing_weight": 1.0, "observed_at": {"day": 1, "phase": "night"}}
	var scene = away.duplicate(true); scene.id = "s2"; scene.fact_id = "s2"; scene.block = "square"
	# a's Gravedigger reading for a day nobody was hanged: impossible as told.
	var gd = {"id": "gd", "fact_id": "gd", "kind": "report", "source": "a", "role": "gravedigger", "night": 1, "data": {"executed": "e", "role": "clerk"}, "observed_at": {"day": 1, "phase": "night"}}
	var prior: float = _p(_view(), [])
	var lie_away: float = _p(_view(), [own, away])
	var lie_scene: float = _p(_view(), [own, scene])
	var false_reading: float = _p(_view(), [gd])
	print("P(a evil): prior %.3f, caught 'home' away from the kill %.3f, at the kill scene %.3f, impossible reading %.3f" % [prior, lie_away, lie_scene, false_reading])
	# Before Nov 17 both caught lies were 1.000: proof.
	check(lie_away > prior and lie_away < 0.8, "a caught 'home' lie away from the kill is evidence, not proof (%.3f)" % lie_away)
	check(lie_scene > lie_away + 0.2, "the same lie at the kill scene weighs much more (%.3f against %.3f)" % [lie_scene, lie_away])
	check(false_reading > lie_scene, "an impossible gift reading weighs more than either (%.3f)" % false_reading)
	print("lie severity: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
