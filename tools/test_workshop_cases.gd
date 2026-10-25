## Slice 1/2 behavioral regressions: provenance, shared support, conflicts and convergence.
extends SceneTree
const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const Jury = preload("res://workshop/jury.gd")
const Support = preload("res://workshop/support_model.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var s = Session.new(692)
	var view: Dictionary = s.scenario.public_view
	var listener: Dictionary = s.baseline[3].duplicate(true)
	for id in listener.suspicion:
		listener.suspicion[id] = 0.0 if id == listener.id else 0.1
	var c = Solver.empty_case()
	c.cards = ["survey", "rumor"]
	c.conclusion.target = "hollis"
	var two = Jury.evaluate(view, c, listener.duplicate(true))
	c.cards.append("dowse")
	var three = Jury.evaluate(view, c, listener.duplicate(true))
	print("Hollis: two reports %.3f -> %.3f, three reports %.3f -> %.3f; suspicion change %.6f -> %.6f" % [two.case_eval.prior, two.case_eval.posterior, three.case_eval.prior, three.case_eval.posterior, two.suspicion_delta, three.suspicion_delta])
	# CaseEval weighs one world model, so Merrin's shared reading is one factor however
	# many routes use it: repeating it adds nothing.
	var repeated_rumor = c.duplicate(true)
	repeated_rumor.cards.append("rumor")
	check(is_equal_approx(Jury.evaluate(view, repeated_rumor, listener.duplicate(true)).case_eval.posterior, three.case_eval.posterior), "shared Merrin assumption is counted once across Surveyor/Rumormonger and Rumormonger/Dowser")
	check(three.strength > two.strength, "the extra Dowser route genuinely strengthens Hollis's case")
	listener.reading_reliability[Solver.semantic_key(Solver.card_by_id(view, "survey"))] = 0.0
	var no_survey = Jury.evaluate(view, c, listener.duplicate(true))
	print("no survey: %.3f -> %.3f strength %.4f vs %.4f" % [no_survey.case_eval.prior, no_survey.case_eval.posterior, no_survey.strength, three.strength])
	# CaseEval: for this listener (every source 30% likely evil by the base rate) the
	# Surveyor adds little to Rumormonger + Dowser, so only the surviving route is checked.
	check(no_survey.strength > 0, "doubting Bart's reading preserves the independent Dowser route")
	listener.reading_reliability[Solver.semantic_key(Solver.card_by_id(view, "rumor"))] = 0.0
	var no_rumor = Jury.evaluate(view, c, listener.duplicate(true))
	check(is_zero_approx(no_rumor.support_model.forced_mass), "doubting the shared Rumormonger reading breaks both proof routes")
	listener = s.baseline[3].duplicate(true)
	for id in listener.suspicion:
		listener.suspicion[id] = 0.0 if id == listener.id else 0.1
	c.cards = ["survey", "rumor", "dowse", "watch1", "watch2", "warden_claim"]
	c.conclusion.target = "constance"
	c.lines = [line("readings", ["survey", "rumor", "dowse"]), line("nisha", ["warden_claim"]), line("movement", ["watch1", "watch2"])]
	var neutral = Jury.evaluate(view, c, listener.duplicate(true))
	c.lines[1].test_factor = {"target": "nisha", "log2_ratio": -2.0}
	var supporting = Jury.evaluate(view, c, listener.duplicate(true))
	check(supporting.strength > neutral.strength and supporting.shared_assessment.compatible == neutral.shared_assessment.compatible, "a supplied factor favoring Nisha good strengthens Constance evil without eliminating a logical world")
	c.lines[1].test_factor.log2_ratio = 0.0
	var equal = Jury.evaluate(view, c, listener.duplicate(true))
	check(is_equal_approx(equal.strength, neutral.strength), "a factor equally expected in both alternatives adds no preference")
	c.lines[1].test_factor.log2_ratio = 2.0
	var contrary = Jury.evaluate(view, c, listener.duplicate(true))
	check(contrary.strength < neutral.strength, "contrary soft evidence can weaken the accusation")
	c.lines[1].test_factor.log2_ratio = -2.0
	var no_connection = c.duplicate(true)
	no_connection.lines[0].cards = ["survey"]
	no_connection.cards.erase("rumor")
	no_connection.cards.erase("dowse")
	var weak = Jury.evaluate(view, no_connection, listener.duplicate(true))
	no_connection.lines[1].test_factor.log2_ratio = 0.0
	var weak_neutral = Jury.evaluate(view, no_connection, listener.duplicate(true))
	check(supporting.strength - neutral.strength > weak.strength - weak_neutral.strength, "removing the connecting readings weakens the indirect Nisha-to-Constance inference")
	var duplicate = c.lines[1].duplicate(true)
	duplicate.id = "copy"
	duplicate.label = "same evidence in another group"
	c.lines.append(duplicate)
	check(is_equal_approx(Jury.evaluate(view, c, listener.duplicate(true)).strength, supporting.strength), "duplicating a line and intermediate wrapper cannot multiply its factor")
	c.lines.reverse()
	c.cards.reverse()
	check(is_equal_approx(Jury.evaluate(view, c, listener.duplicate(true)).strength, supporting.strength), "line and evidence order do not change combined support")
	c.lines = [line("one", ["survey"]), line("two", ["rumor", "dowse"])]
	c.lines[0].positions = {"nisha": "marked"}
	c.lines[1].positions = {"nisha": "evil"}
	check(Solver.analyze(view, c).status == "conflicting", "incompatible supporting-line assumptions are exposed")
	c.lines[1].relation = "alternative"
	check(Solver.analyze(view, c).status != "conflicting", "an alternative explanation is checked separately instead of merged into simultaneous premises")
	c.lines[1].relation = "supports"
	c.lines[1].positions = {"nisha": "good"}
	check(Solver.analyze(view, c).status != "conflicting", "good and Marked assumptions are compatible across lines")
	c.lines[0].answers = {"dowse": {"positive": ["merrin"]}}
	check(not Graph.compile_case(view, c).answers.has("dowse"), "an answer to a card outside its line cannot leak into another line")
	var reasons = Solver.empty_case()
	reasons.cards = ["watch1"]
	reasons.lines = [line("observed", ["watch1"]), line("excuse", ["watch1"])]
	reasons.lines[1].relation = "alternative"
	reasons.lines[1].reasons = {"constance:1": "gift"}
	reasons.lines[1].citations = {"constance:1": "gift_claim"}
	check(Graph.compile_case(view, reasons).citations.is_empty(), "an alternative line's gift explanation does not leak into the combined case")
	reasons.lines[1].relation = "supports"
	reasons.lines[0].reasons = {"constance:1": "evil"}
	check(Solver.analyze(view, reasons).status == "conflicting", "incompatible outing explanations across supporting lines are exposed")
	var observations = Solver.empty_case()
	observations.cards = ["survey", "rumor", "dowse", "watch1", "vigil1"]
	observations.lines = [line("one", ["watch1"]), line("two", ["vigil1"])]
	for item in observations.lines:
		item.test_factor = {"target": "constance", "log2_ratio": 2.0}
	var grouped = Graph.compile_case(view, observations)
	check(grouped.test_factors.size() == 1 and grouped.test_factors[0].routes.size() == 2, "two witnesses to one outing supply two corroborating routes to one factor")
	var remembered = listener.duplicate(true)
	Jury.evaluate(view, observations, remembered)
	observations.lines[0].label = "renamed line"
	check(Jury.evaluate(view, observations, remembered).repeated, "renaming a reasoning line does not create a novel argument")
	observations.lines[1].test_factor.log2_ratio = 3.0
	check(Solver.analyze(view, observations).status == "conflicting", "conflicting factors for the same incident are exposed instead of multiplied")
	c = Solver.empty_case()
	c.cards = ["watch1", "alibi1", "survey"]
	c.conclusion.type = "conflict"
	c.conflict_scope = ["watch1", "alibi1"]
	var conflict = Solver.analyze(view, c)
	check(conflict.entailment == "forced" and conflict.conflicts == [["watch1", "alibi1"]], "conflict scope identifies the minimal alibi/sighting conflict and excludes unrelated cards")
	var more = c.duplicate(true)
	more.cards.append("vigil1")
	more.conflict_scope.append("vigil1")
	check(Solver.analyze(view, more).conflicts.size() == 2, "separate minimal conflicts are found when either witness contradicts the alibi")
	var heard = Jury.evaluate(view, c, listener)
	check(heard.suspicion_delta == 0.0 and listener.ledger[c.id].has("report_acceptance"), "conflict stores report-level doubt without assigning alignment guilt")
	check(heard.support_model.report_acceptance.get("alibi1", 0.0) < Support.source_quality(listener, "constance"), "a contradictory alibi loses accuracy weight while the listener retains their own sighting")
	var unresolved = heard.support_model.report_acceptance.duplicate()
	c.challenges = {"watch1": ["watch1", "alibi1"]}
	check(Jury.evaluate(view, c, listener).support_model.report_acceptance == unresolved, "merely choosing which report to question grants no evidence bonus")
	c.derived = [{"id": "question", "supports": ["watch1", "alibi1"], "text": "Which report is wrong?"}]
	c.cards.append("question")
	check(Jury.evaluate(view, c, listener).support_model.report_acceptance == unresolved, "derived conflict question reuses the original evidence without multiplying doubt")
	c.conflict_scope = ["survey"]
	check(Solver.analyze(view, c).entailment == "unsupported", "an unrelated selected report is not falsely declared conflicting")
	c = Solver.empty_case()
	c.cards = ["lamp1"]
	c.conclusion = {"type": "suspicious", "target": "agnes", "at": view.alignment_epoch}
	c.reasons = {"agnes:1": "gift"}
	c.citations = {"agnes:1": "claim_lamplighter"}
	check(not Graph.valid_citation(view, c, "agnes", 1).is_empty(), "Agnes's implicit Lamplighter claim is independently citable")
	var claim_only = Solver.empty_case()
	claim_only.cards = ["claim_lamplighter"]
	check(Solver.selected(view, claim_only).size() == 1 and Solver.selected(view, claim_only)[0].kind == "claim", "citing the associated role claim does not accept the reading")
	c.citations["agnes:1"] = "gift_claim"
	check(Graph.valid_citation(view, c, "agnes", 1).is_empty(), "a wrong-person gift claim does not explain Agnes's outing")
	var future = view.duplicate(true)
	Solver.card_by_id(future, "claim_lamplighter").applies.from = 2
	c.citations["agnes:1"] = "claim_lamplighter"
	check(Graph.valid_citation(future, c, "agnes", 1).is_empty(), "a claim outside its asserted time interval grants no discount")
	var nonwalker = view.duplicate(true)
	Solver.card_by_id(nonwalker, "claim_lamplighter").role = "seer"
	check(Graph.valid_citation(nonwalker, c, "agnes", 1).is_empty(), "a Seer claim does not explain walking: night information is distinct from a walking gift")
	for card in view.cards:
		check(card.has("fact_id") and card.has("reported_at") and card.has("learned_at") and card.has("provenance"), "provenance fields exist for " + card.id)
	# A full saved experiment must replay grouping, citations, choices and weights.
	s.case_data = Solver.empty_case()
	s.case_data.cards = ["survey", "rumor", "dowse", "watch1", "gift_claim"]
	s.case_data.lines = [line("reads", ["survey", "rumor", "dowse"]), line("walk", ["watch1", "gift_claim"])]
	s.case_data.lines[1].test_factor = {"target": "nisha", "log2_ratio": -1.0}
	s.case_data.citations = {"constance:1": "gift_claim"}
	s.present(false)
	s.case_data.lines[1].test_factor.log2_ratio = 1.0
	s.present(true, "meeting")
	var saved = JSON.parse_string(JSON.stringify(s.export_data()))
	var restored = Session.new(101)
	check(restored.restore(saved) == "" and restored.last_results == s.last_results, "multi-line experiment with revised soft factors and citations replays exactly")
	var malformed = saved.duplicate(true)
	malformed.case.lines[1].test_factor.log2_ratio = INF
	check(restored.restore(malformed) != "" and restored.last_results == s.last_results, "invalid factor import is rejected atomically")
	malformed = saved.duplicate(true)
	malformed.case.answers.dowse = {"slots": ["lian"], "positive": ["merrin"]}
	check(restored.restore(malformed) != "", "an import cannot display one slot answer while evaluating another")
	malformed = saved.duplicate(true)
	malformed.case.erase("conclusion")
	check(restored.restore(malformed) != "", "a malformed grouped case is rejected before reading its intermediate claims")
	malformed = saved.duplicate(true)
	malformed.seed = INF
	check(restored.restore(malformed) != "", "non-finite seeds are rejected before scenario generation")
	var tick = Time.get_ticks_usec()
	Support.cache.clear()
	Solver.report_matches.clear()
	Solver.movement_cache.clear()
	Jury.evaluate(view, s.case_data, s.baseline[3].duplicate(true))
	var cold = (Time.get_ticks_usec() - tick) / 1000.0
	tick = Time.get_ticks_usec()
	Jury.evaluate(view, s.case_data, s.baseline[3].duplicate(true))
	print("Performance example (one juror): cold %.1f ms, cached %.1f ms" % [cold, (Time.get_ticks_usec() - tick) / 1000.0])
	var broad = Solver.empty_case()
	broad.cards = view.cards.filter(func(card): return card.kind != "alibi").map(func(card): return card.id)
	var uncertain = s.baseline[3].duplicate(true)
	for key in uncertain.reading_reliability:
		uncertain.reading_reliability[key] = 0.5
	tick = Time.get_ticks_usec()
	var broad_result = Jury.evaluate(view, broad, uncertain)
	check(broad_result.has("support_model") and broad_result.pattern.has("incidents"), "all claim and report types can be selected together without confusing claims with readings")
	print("Broad all-readings stress (one juror): %.1f ms; %d credibility states" % [(Time.get_ticks_usec() - tick) / 1000.0, broad_result.support_model.states])
	print("Workshop cases: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func line(id: String, cards: Array) -> Dictionary:
	return {"id": id, "label": id, "relation": "supports", "cards": cards, "positions": {}, "answers": {}}

func check(okay: bool, label: String) -> void:
	checks += 1
	if okay:
		print("PASS: " + label)
	else:
		fails += 1
		push_error("FAIL: " + label)
