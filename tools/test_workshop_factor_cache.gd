## Compiling a case must not extend the movement model's shared cache entries.
extends SceneTree
const Eval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Movement = preload("res://workshop/movement_model.gd")
const History = preload("res://workshop/live_history.gd")

func _init() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d"]:
		people.append({"id": id, "name": id, "home": "square"})
	var sighting = {"id": "sighting", "kind": "sighting", "source": "player", "subject": "b", "subjects": ["b"], "night": 1, "block": "market", "observed_at": {"day": 1, "phase": "night"}}
	var view = {"people": people, "cards": [sighting], "evil_count": 1, "alignment_epoch": "Original alignment", "live_activity": true,
		"world_options": {"modifiers": ["marked"], "identities": true},
		"timeline": History.from_events([{"kind": "demon_death", "subjects": ["a"], "at": {"day": 1, "phase": "night"}}])}
	var value = Solver.empty_case()
	value.cards = [sighting.id]
	value.conclusion = {"type": "evil", "target": "a", "at": view.alignment_epoch}
	var shared: Array = Movement.factors(view, [sighting], value)
	var before = shared.duplicate(true)
	var first = Eval.evaluate(view, value)
	var okay = true
	for target in ["b", "c", "d", "a"]:
		value.conclusion.target = target
		var cc = Eval.compile(view, [sighting], value)
		okay = okay and cc.factors.size() == before.size() + 1 and shared == before
	value.conclusion.target = "a"
	Eval._compiled.clear()
	var again = Eval.evaluate(view, value)
	okay = okay and first.people == again.people and first.posterior == again.posterior
	print("Factor cache: immutable movement factors and identical probabilities across five compiled questions: ", "PASS" if okay else "FAIL")
	if not okay:
		push_error("FAIL: public evidence must never accumulate in cached movement factors")
	quit(0 if okay else 1)
