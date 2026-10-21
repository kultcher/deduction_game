extends SceneTree
const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var s = Session.new(692)
	var view: Dictionary = s.scenario.public_view
	var c = Solver.empty_case()
	c.cards = ["survey", "rumor", "dowse"]
	var juror = s.baseline[3].duplicate(true)
	juror.reasoning_mode = "bounded"
	juror.trust = 0.9
	for id in juror.suspicion:
		juror.suspicion[id] = 0.0 if id == juror.id else 0.1
		juror.npc_trust[id] = 1.0
	var outcomes: Array = []
	for insight in [0.1, 0.5, 0.9]:
		var clone = juror.duplicate(true)
		clone.insight = insight
		outcomes.append(Jury.evaluate(view, c, clone))
		print("%s: %s; agreement %.3f; checked %d worlds" % [outcomes[-1].reasoning.profile, outcomes[-1].reasoning.status, outcomes[-1].agreement, outcomes[-1].reasoning.tested])
	check(outcomes[0].shared_assessment == outcomes[1].shared_assessment and outcomes[1].shared_assessment == outcomes[2].shared_assessment, "Insight leaves the complete referee answer unchanged")
	check(outcomes[0].reasoning.status == "provisional" and outcomes[0].reasoning.rivals_tested == 0, "Low Insight provisionally accepts a checked explanation without a rival search")
	check(not outcomes[0].objection.contains("An alternative still fits") and not outcomes[0].objection.contains("Nisha"), "spoken low-Insight objections cannot leak the referee's unseen Nisha alternative")
	check(outcomes[0].stance == "accept" and outcomes[0].shared_assessment.entailment == "possible", "trusted coherent case can convince a low-Insight juror without being mislabeled proved")
	check(outcomes[1].reasoning.status == "rival_found" and outcomes[2].reasoning.status == "rival_found", "Medium and High find the Nisha rival")
	check(outcomes[0].agreement > outcomes[1].agreement, "rival search changes subjective conviction with all other inputs held constant")
	var force = c.duplicate(true)
	force.conclusion.target = "hollis"
	var thorough = juror.duplicate(true)
	thorough.insight = 0.9
	check(Jury.evaluate(view, force, thorough).reasoning.status == "entailed_in_attention", "exhaustive rival search can certify an implication within the attended premises")
	juror.insight = 0.1
	var first = Jury.evaluate(view, c, juror)
	var again = Jury.evaluate(view, c, juror, {"venue": "meeting"})
	check(again.repeated and is_zero_approx(again.suspicion_delta) and again.reasoning == first.reasoning, "repetition at another venue repeats the same checks without extra persuasion")
	juror.insight = 0.5
	check(not Jury.evaluate(view, c, juror).repeated, "changing Insight is recorded as changed assessment input")
	for insight in [0.1, 0.5, 0.9]:
		var clone = juror.duplicate(true)
		clone.insight = insight
		var self_case = c.duplicate(true)
		self_case.conclusion.target = clone.id
		var r = Jury.evaluate(view, self_case, clone)
		check(r.reasoning.private_checks.fatal and r.agreement == 0, "own good alignment is protected at Insight %.1f" % insight)
	var large = c.duplicate(true)
	large.cards.append_array(["watch1", "watch2", "lamp1", "lamp2", "warden_claim"])
	var small_mind = juror.duplicate(true)
	small_mind.insight = 0.1
	var limited = Jury.evaluate(view, large, small_mind)
	check(not limited.reasoning.ignored.is_empty() and limited.reasoning.considered.filter(func(id): return id not in limited.reasoning.private_reports).size() <= 3, "oversized case exposes the evidence not attended to")
	check(limited.reasoning.private_reports.size() == 2, "own gift reports remain available outside the attention budget")
	var joined = c.duplicate(true)
	joined.cards.append_array(["watch1", "watch2"])
	joined.lines = [{"id": "readings", "label": "Readings", "relation": "supports", "cards": ["survey", "rumor", "dowse"], "positions": {}, "answers": {}},
		{"id": "movement", "label": "Movement", "relation": "supports", "cards": ["watch1", "watch2"], "positions": {}, "answers": {}, "test_factor": {"target": "constance", "log2_ratio": 1.0}}]
	var missed_connection = Jury.evaluate(view, joined, small_mind.duplicate(true))
	check(missed_connection.reasoning.ignored_lines.has("movement") and missed_connection.support_model.factors.is_empty(), "a juror can know the sightings but miss connecting their line to the readings")
	var hidden_mistake = joined.duplicate(true)
	hidden_mistake.lines[1].positions = {"hollis": "good"}
	var missed_mistake = Jury.evaluate(view, hidden_mistake, small_mind.duplicate(true))
	check(missed_mistake.assessment.proposed == 0 and missed_mistake.agreement > 0 and missed_mistake.reasoning.status == "provisional", "an unattended contradiction cannot veto bounded conviction through the full referee")
	var movement_case = joined.duplicate(true)
	movement_case.conclusion.type = "suspicious"
	var inattentive_bart = s.baseline[0].duplicate(true)
	inattentive_bart.reasoning_mode = "bounded"
	inattentive_bart.insight = 0.1
	var unseen_movements = Jury.evaluate(view, movement_case, inattentive_bart)
	check(unseen_movements.reasoning.ignored_lines.has("movement") and unseen_movements.pattern.incidents == 0, "direct outing suspicion cannot bypass the evidence attention budget")
	var connected_mind = small_mind.duplicate(true)
	connected_mind.insight = 0.9
	check(not Jury.evaluate(view, joined, connected_mind).support_model.factors.is_empty(), "higher attention can connect the movement line and use its supplied factor")
	var remembered_group = small_mind.duplicate(true)
	Jury.evaluate(view, joined, remembered_group)
	var duplicate = joined.lines[0].duplicate(true)
	duplicate.id = "wrapper"
	joined.lines.append(duplicate)
	check(Jury.evaluate(view, joined, remembered_group).repeated, "a duplicate reasoning-line wrapper cannot consume attention or create a fresh attempt")
	var direct = c.duplicate(true)
	direct.lines = [{"id": "direct", "label": "Supplied contrary factor", "relation": "supports", "cards": c.cards.duplicate(), "positions": {}, "answers": {}, "test_factor": {"target": "constance", "log2_ratio": -4.0}}]
	check(Jury.evaluate(view, direct, small_mind.duplicate(true)).agreement < outcomes[0].agreement, "an attended direct contrary factor weakens even a juror who did not search for rivals")
	var weak_sources = small_mind.duplicate(true)
	for id in weak_sources.npc_trust:
		if id != weak_sources.id:
			weak_sources.npc_trust[id] = 0.0
	check(Jury.evaluate(view, c, weak_sources).stance != "accept", "low Insight does not automatically accept a case from distrusted sources")
	var misleading = view.duplicate(true)
	var false_watch = Solver.card_by_id(misleading, "watch1").duplicate(true)
	false_watch.id = "false_watch"
	false_watch.fact_id = "misquoted-nightwatch"
	false_watch.data.seen.append("bart")
	misleading.cards.append(false_watch)
	var home_case = c.duplicate(true)
	home_case.cards.append("false_watch")
	for insight in [0.1, 0.5, 0.9]:
		var at_home: Dictionary = s.baseline[0].duplicate(true)
		at_home.reasoning_mode = "bounded"
		at_home.insight = insight
		var r = Jury.evaluate(misleading, home_case, at_home)
		check(r.reasoning.private_checks.rejected.has("false_watch") and r.support_model.report_acceptance.get("false_watch", 0.0) == 0.0, "firsthand whereabouts reject a wrong sighting even outside attention at Insight %.1f" % insight)
	var wrong_result = Solver.card_by_id(misleading, "survey").duplicate(true)
	wrong_result.id = "wrong_result"
	wrong_result.fact_id = "misquoted-survey"
	wrong_result.data.count = 3
	misleading.cards.append(wrong_result)
	home_case.cards = ["wrong_result"]
	var bart: Dictionary = s.baseline[0].duplicate(true)
	bart.reasoning_mode = "bounded"
	bart.insight = 0.1
	var receipt = Jury.evaluate(misleading, home_case, bart)
	check(receipt.reasoning.private_checks.rejected.has("wrong_result"), "a juror notices a misquoted own reading without assuming its actual result was healthy")
	bart.reading_reliability[Solver.semantic_key(Solver.card_by_id(view, "survey"))] = 0.0
	var impaired = Jury.evaluate(view, c, bart)
	check(impaired.support_model.report_acceptance.survey == 0.0 and not impaired.reasoning.private_checks.fatal, "a juror may doubt their own reading's accuracy while retaining firsthand receipt knowledge")
	var conflict_case = Solver.empty_case()
	conflict_case.cards = ["survey", "watch1", "alibi1"]
	conflict_case.conclusion.type = "conflict"
	conflict_case.conflict_scope = ["watch1", "alibi1"]
	var obvious = Jury.evaluate(view, conflict_case, small_mind.duplicate(true))
	check(obvious.agreement == 1.0 and obvious.reasoning.status == "inconsistent", "even low Insight catches a direct two-account home/sighting contradiction")
	conflict_case.conflict_scope = ["survey"]
	var unrelated = Jury.evaluate(view, conflict_case, small_mind.duplicate(true))
	check(unrelated.agreement == 0.0, "a bounded juror cannot borrow the referee's out-of-scope conflict")
	var empty = Solver.empty_case()
	check(Jury.evaluate(view, empty, small_mind).strength == 0, "low Insight gives no free weight to an unsupported accusation")
	var pc = c.duplicate(true)
	pc.cards.append("watch1")
	pc.lines = [{"id": "reading", "label": "Readings", "relation": "supports", "cards": ["survey", "rumor", "dowse"], "positions": {}, "answers": {}},
		{"id": "test", "label": "Supplied comparison", "relation": "supports", "cards": ["watch1"], "positions": {}, "answers": {}, "test_factor": {"target": "constance", "log2_ratio": 0.0}}]
	var low = juror.duplicate(true)
	low.ledger = {}
	low.case_memory = {}
	low.theories = {}
	low.reasoning_mode = "full"
	low.confidence_mode = "persistence"
	low.confidence = 0.1
	low.suspicion.constance = 0.15
	low.npc_trust.constance = 0.5
	low.npc_trust.nisha = 0.5
	var high = low.duplicate(true)
	high.confidence = 0.9
	var adopted_low = Jury.evaluate(view, pc, low)
	var adopted_high = Jury.evaluate(view, pc, high)
	var undecided = high.duplicate(true)
	undecided.ledger = {}
	undecided.case_memory = {}
	undecided.theories = {}
	Jury.evaluate(view, Solver.empty_case(), undecided)
	check(Jury.evaluate(view, pc, undecided).theory.status == "adopted", "a previously empty theory does not become stubbornness about remaining undecided")
	check(adopted_high.theory.position == "evil" and adopted_low.theory.position == "evil", "both confidence levels begin with the same provisional theory")
	check(adopted_low.calculation.confidence_factor == 1.0 and adopted_high.calculation.confidence_factor == 1.0 and is_equal_approx(adopted_low.strength, adopted_high.strength), "persistence mode replaces the old confidence multiplier instead of stacking it")
	pc.lines[1].test_factor.log2_ratio = -1.0
	var changed_low = Jury.evaluate(view, pc, low)
	var changed_high = Jury.evaluate(view, pc, high)
	print("Moderate contrary factor: low %s/%s, high %s/%s" % [changed_low.theory.status, changed_low.theory.position, changed_high.theory.status, changed_high.theory.position])
	check(changed_low.theory.status == "revised" and changed_low.theory.position == "good", "low confidence revises its theory under moderate contrary evidence")
	check(changed_high.theory.status == "retained" and changed_high.theory.position == "evil" and changed_high.strength > changed_low.strength, "high confidence visibly retains a defeasible earlier theory")
	var unchanged = Jury.evaluate(view, pc, high)
	check(unchanged.repeated and is_zero_approx(unchanged.suspicion_delta), "repetition cannot incrementally build persistence or persuasion")
	check(changed_high.support_model.atoms == adopted_high.support_model.atoms, "confidence does not invent a poisoning excuse or change source/reading reliability")
	pc.lines[1].test_factor.log2_ratio = -4.0
	var decisive = Jury.evaluate(view, pc, high)
	check(decisive.theory.status == "revised" and decisive.theory.position == "good", "strong contrary evidence can dislodge the high-confidence theory")
	var unsupported = pc.duplicate(true)
	unsupported.cards = []
	unsupported.lines = []
	check(Jury.evaluate(view, unsupported, high).strength == 0.0, "retaining a theory cannot replace missing evidence or prevent complete case retraction")
	var private_case = c.duplicate(true)
	private_case.conclusion.target = high.id
	high.theories[high.id + "|" + private_case.conclusion.at] = {"position": "evil"}
	var corrected = Jury.evaluate(view, private_case, high)
	check(corrected.theory.status == "private_fact" and corrected.theory.position == "good" and corrected.agreement == 0, "direct private knowledge overrides even a stale committed theory")
	# Replay recomputes theories; exported baseline settings may not inject memory.
	var replay = Session.new(692)
	var settings = s.baseline[3].duplicate(true)
	settings.reasoning_mode = "bounded"
	settings.insight = 0.9
	settings.confidence_mode = "persistence"
	settings.confidence = 0.9
	settings.suspicion.constance = 0.15
	settings.suspicion.nisha = 0.1
	replay.baseline[3] = settings
	replay.case_data = pc.duplicate(true)
	replay.case_data.lines[1].test_factor.log2_ratio = 0.0
	replay.present(false)
	replay.case_data.lines[1].test_factor.log2_ratio = -1.0
	replay.present(true)
	var snapshot = JSON.stringify(replay.export_data())
	var comparisons = replay.compare_reasoning(3)
	check(snapshot == JSON.stringify(replay.export_data()) and comparisons.size() == 4, "Insight comparisons neither mutate the session nor become evidence/history")
	var restored = Session.new(101)
	var saved = JSON.parse_string(snapshot)
	var error = restored.restore(saved)
	check(error == "" and restored.last_results == replay.last_results and restored.listeners == replay.listeners, "bounded reasoning and persistent theories replay exactly from history: " + error)
	var bad = saved.duplicate(true)
	bad.jury_settings[3].theories = {"injected": {"position": "evil"}}
	check(restored.restore(bad) != "" and restored.last_results == replay.last_results, "theory memory cannot be injected through saved baseline settings")
	var before = JSON.stringify(Jury.evaluate(view, c, juror.duplicate(true)))
	s.scenario.truth.clear()
	s.scenario.timeline.clear()
	check(JSON.stringify(Jury.evaluate(view, c, juror.duplicate(true))) == before, "bounded reasoning has no hidden-truth input")
	print("Workshop reasoning: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(okay: bool, label: String) -> void:
	checks += 1
	if okay:
		print("PASS: " + label)
	else:
		fails += 1
		push_error("FAIL: " + label)
