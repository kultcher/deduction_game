## Helpers for judging one frozen evidence set's consequences (Jury._consequences_eval):
## scoping a case to its attended cards, its claim arguments, and the reply stance.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const Reasoner = preload("res://workshop/reasoner.gd")

static func _prepared(view: Dictionary, attention: Dictionary, scoped: Dictionary, listener: Dictionary) -> Dictionary:
	var result = attention.duplicate(true)
	result.case = scoped
	result.considered = scoped.cards.duplicate()
	result.private_checks = Reasoner.direct_checks(view, scoped, listener.knowledge)
	return result

static func _scope(view: Dictionary, value: Dictionary, ids: Array) -> Dictionary:
	var result = Graph.compile_case(view, value)
	result.cards = result.cards.filter(func(id): return id in ids)
	result.test_factors = result.test_factors.filter(func(f): return f.routes.any(func(route): return route.all(func(id): return id in result.cards)))
	for factor in result.test_factors:
		factor.routes = factor.routes.filter(func(route): return route.all(func(id): return id in result.cards))
	result.quoted_cards = result.quoted_cards.filter(func(id): return id in result.cards)
	return result

static func _arguments(view: Dictionary, value: Dictionary) -> Array:
	if value.has("arguments"):
		return value.arguments
	# List-lab cases have one level of lines. Preserve the same claim semantics.
	var result: Array = [{"id": "root", "label": "%s is %s" % [Solver.person_name(view, value.conclusion.target), value.conclusion.type], "parents": [], "case": value, "inputs": []}]
	for line in value.get("lines", []):
		if line.relation != "supports":
			continue
		result[0].inputs.append({"id": line.id, "cards": Graph.roots(value, line.cards)})
		if not line.has("conclusion"):
			continue
		var scoped = value.duplicate(true)
		scoped.cards = Graph.roots(value, line.cards)
		scoped.lines = [line]
		scoped.conclusion = line.conclusion.duplicate(true)
		result.append({"id": line.id, "label": line.label, "parents": ["root"], "case": scoped, "inputs": []})
	return result

static func _stance(agreement: float) -> String:
	return "accept" if agreement >= Tuning.Workshop.STANCE_ACCEPT else ("partial" if agreement >= Tuning.Workshop.STANCE_PARTIAL else "reject")
