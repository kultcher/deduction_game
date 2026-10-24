## Block answers narrow a Surveyor hypothesis without becoming new evidence.
extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Graph = preload("res://workshop/case_graph.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/workshop_checkpoint_v5.json"))
	var core: Dictionary = data.examples.filter(func(e): return e.name == "core")[0]
	var view: Dictionary = core.view
	var card: Dictionary = view.cards.filter(func(c): return c.get("role", "") == "surveyor")[0]
	card.data.count = 2
	var value: Dictionary = Solver.empty_case()
	value.cards = [card.id]
	value.conclusion = core.case.conclusion.duplicate(true)
	var block: String = view.people[0].home
	var plain = CaseEval.evaluate(view, value)
	value.answers[card.id] = {"positive": [], "blocks": [block]}
	check(Solver.validate_answers(view, value).is_empty(), "a known block can fill an unresolved Surveyor slot")
	var answered = CaseEval.evaluate(view, value)
	check(plain.people == answered.people and plain.posterior == answered.posterior, "a block answer never adds alignment evidence")
	check(answered.theory_fit > 0 and answered.theory_fit < 1, "a block answer tests the fit of the supplied hypothesis")
	var unconditioned = Solver.report_table(view, card)
	var conditioned = Solver.report_table(view, card, [], [block])
	check(conditioned != unconditioned, "report-table caching includes block answers")
	check(Solver.solve(view, [card], {}, value.answers).worlds.size() < Solver.solve(view, [card]).worlds.size(), "the conditional logical solve narrows the Surveyor explanation")
	for answer in [
		{"positive": [], "blocks": ["unknown"]},
		{"positive": [], "blocks": [block, block]},
		{"positive": [view.people[0].id], "blocks": [block]},
		{"positive": [], "blocks": ["square", "market", "docks", "hill", "square"]}]:
		value.answers[card.id] = answer
		check(not Solver.validate_answers(view, value).is_empty(), "invalid or overlapping block slots receive explicit feedback")
	var other: Dictionary = view.cards.filter(func(c): return c.get("role", "") == "dowser")[0]
	value.cards = [other.id]
	value.answers = {other.id: {"positive": [], "blocks": [block]}}
	check(not Solver.validate_answers(view, value).is_empty(), "non-Surveyor answers cannot introduce block slots")
	value.cards = [card.id]
	value.answers = {}
	value.lines = [
		{"id": "a", "label": "First", "cards": [card.id], "answers": {card.id: {"positive": [], "blocks": ["square"]}}},
		{"id": "b", "label": "Second", "cards": [card.id], "answers": {card.id: {"positive": [], "blocks": ["market"]}}}]
	check(not Graph.compile_case(view, value).graph_errors.is_empty(), "supporting lines cannot silently overwrite different block answers")
	print("Surveyor answers: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
