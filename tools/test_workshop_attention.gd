## Presented observations are compulsory; Insight still limits links and rivals.
extends SceneTree
const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Game = preload("res://game/game.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var session = Session.new(692)
	var view: Dictionary = session.scenario.public_view
	var value = Solver.empty_case()
	value.cards = ["survey", "rumor", "dowse", "watch1", "watch2"]
	value.lines = [
		{"id": "readings_a", "label": "Readings A", "relation": "supports", "cards": ["survey", "rumor"], "positions": {}, "answers": {}},
		{"id": "readings_b", "label": "Readings B", "relation": "supports", "cards": ["dowse"], "positions": {}, "answers": {}},
		{"id": "movement", "label": "Movement", "relation": "supports", "cards": ["watch1", "watch2"], "positions": {}, "answers": {}, "test_factor": {"target": "constance", "log2_ratio": 1.0}}]
	var listener = session.baseline[3].duplicate(true)
	listener.reasoning_mode = "bounded"
	listener.insight = 0.1
	listener.knowledge["presented_reports"] = ["watch1", "watch2"]
	listener.knowledge["own_reports"] = ["survey", "rumor", "dowse"]
	listener.knowledge["attention_reports"] = listener.knowledge.own_reports.duplicate()
	var attention = Jury.Reasoner.prepare(view, value, listener)
	check(["watch1", "watch2"].all(func(id): return id in attention.considered), "low Insight always reads both submitted observations")
	check(attention.considered.size() == 4 and not attention.ignored.is_empty(), "private and background cards compete for the remaining slots")
	check("movement" in attention.ignored_lines and attention.case.test_factors.is_empty(), "reading a card does not grant an unattended reasoning connection")
	var explanation = Jury.Support.explain(view, value, listener)
	check(not explanation.accepted.any(func(id): return id in attention.ignored), "explanation search cannot silently restore ignored private reports")
	var eval_listener = Jury._eval_listener(listener, listener.knowledge.own_reports, {}, attention)
	check(eval_listener.knowledge.own_reports.all(func(id): return id in attention.considered), "ignored background reports cannot bypass attention through the evidence prior")
	listener.knowledge.presented_reports = value.cards.duplicate()
	attention = Jury.Reasoner.prepare(view, value, listener)
	check(value.cards.all(func(id): return id in attention.considered), "a submission larger than the card budget is still read in full")
	check(attention.limits.support == 12 and attention.limits.rivals == 3 and attention.ignored_lines.size() == 1, "guaranteed cards do not increase link or candidate budgets")
	# Counter-evidence linked to challenge a kept card is never dropped out of attention.
	var challenged_case = value.duplicate(true)
	challenged_case.reading_challenges = {"survey": {"mode": "lying", "supports": ["dowse"]}}
	var unfocused = listener.duplicate(true)
	unfocused.knowledge.erase("presented_reports")
	unfocused.knowledge.own_reports = []
	unfocused.knowledge.attention_reports = []
	challenged_case.cards = ["survey", "rumor", "watch1", "watch2", "lamp1", "dowse"]
	challenged_case.lines = []
	var paired_att = Jury.Reasoner.prepare(view, challenged_case, unfocused)
	check("survey" in paired_att.considered and "dowse" in paired_att.considered, "a card linked to challenge a kept report is retained alongside it")
	_live()
	print("Presented attention: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _live() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	var listener = g.w.living_good()[0]
	listener.traits.insight = 0.1
	listener.workshop_state.reasoning_mode = "bounded"
	var target = g.w.npcs.filter(func(p): return p != listener)[0]
	var alibi = g.add_card({"kind": "alibi", "source": target.id, "subject": [target.id], "day": 1, "phase": 3, "text": "Home at night"})
	var sight = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id], "day": 1, "phase": 3, "block": "market", "text": "Seen out"})
	var number = g.file_deduction({"type": "suspicious", "a": target.id}, [alibi, sight])
	var required = [Evidence.normalize_card(g.board[alibi - 1]).id, Evidence.normalize_card(g.board[sight - 1]).id]
	var result = g._evaluate_deduction(listener, g.board[number - 1], 1.0, false)
	check(result.get("workshop", false) and listener.workshop_state.active, "a real crowded listener uses the shared presentation route")
	check(required.all(func(id): return id in listener.workshop_state.reasoning.considered), "the applied belief refresh includes the presented roots")
	var response: Dictionary = g._workshop_responses[listener.id + ":good"].assessment
	check(required.all(func(id): return id in response.reasoning.considered), "the scoped reply also includes the presented roots")
	check(g._workshop_plans[listener.id + ":good"].prepared.listener.knowledge.presented_reports.size() == required.size() and required.all(func(id): return id in g._workshop_plans[listener.id + ":good"].prepared.listener.knowledge.presented_reports), "focus travels through the ownership snapshot explicitly")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
