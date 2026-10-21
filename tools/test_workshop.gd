## Semantic acceptance tests: run with Godot --headless --path . --script res://tools/test_workshop.gd
extends SceneTree

const Scenario = preload("res://workshop/scenario.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Session = preload("res://workshop/session.gd")
var fails = 0
var checks = 0

func _init() -> void:
	var s = Session.new(692)
	var view: Dictionary = s.scenario.public_view
	var c = Solver.empty_case()
	c.cards = ["survey"]
	var partial = Solver.analyze(view, c)
	check(partial.status == "incomplete" and partial.compatible > 0, "partial Surveyor case is valid, not a contradiction")
	check(partial.entailment == "possible", "Surveyor alone does not establish Constance's alignment")
	c.cards = ["survey", "rumor", "dowse"]
	var combined = Solver.analyze(view, c)
	check(combined.compatible == 2, "three core reports retain precisely the two mirrored worlds (%d)" % combined.compatible)
	check(combined.entailment == "possible", "Constance/Nisha mirror remains unresolved")
	for target in ["hollis", "lian"]:
		c.conclusion.target = target
		check(Solver.analyze(view, c).entailment == "forced", "%s is evil in both compatible worlds" % target)
	c.conclusion.target = "constance"
	c.positions.nisha = "marked"
	check(Solver.analyze(view, c).proposed == 1, "answering Nisha Marked selects a coherent world")
	var result = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	check(result.path_kind == "conditional" and result.agreement < 0.6, "chosen answer is a premise, not proof")
	c.positions = {"constance": "evil"}
	result = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	check(result.path_kind != "conditional", "conclusion cannot support itself")
	c.positions = {"constance": "good"}
	check(Solver.analyze(view, c).status == "conflicting", "a conclusion that contradicts the proposed world is flagged")
	c.positions = {}
	c.conclusion.target = "hollis"
	var listener: Dictionary = s.baseline[0].duplicate(true)
	var first = Jury.evaluate(view, c, listener)
	var second = Jury.evaluate(view, c, listener, {"venue": "meeting"})
	check(is_equal_approx(second.suspicion_delta, 0.0) and second.repeated, "repeat at another venue has zero added effect")
	var cloned_view = view.duplicate(true)
	var clone = Solver.card_by_id(cloned_view, "dowse").duplicate(true)
	clone.id = "rewrapped"
	cloned_view.cards.append(clone)
	c.cards.append("rewrapped")
	var third = Jury.evaluate(cloned_view, c, listener)
	check(is_equal_approx(third.suspicion_delta, 0.0), "new wrapper of the same report adds nothing")
	clone.data.group.reverse()
	check(Solver.semantic_key(clone) == Solver.semantic_key(Solver.card_by_id(view, "dowse")), "reordering a count's named group does not create a new fact")
	c.cards = ["survey", "rumor", "dowse", "gift_claim"]
	var optional = Jury.evaluate(view, c, listener)
	check(is_equal_approx(optional.strength, first.strength), "optional unrelated support preserves the stronger path")
	c.cards = ["survey"]
	var removed = Jury.evaluate(view, c, listener)
	check(removed.suspicion_delta < 0, "removing essential support retracts earlier persuasion")
	check(not removed.changes.is_empty(), "the response identifies what changed in the revised case")
	c.cards = []
	var emptied = Jury.evaluate(view, c, listener)
	check(is_equal_approx(emptied.after_suspicion, s.baseline[0].suspicion.hollis), "removing the complete case restores original suspicion")
	# Repeated outings and multiple observations of one outing are different.
	c.conclusion = {"type": "suspicious", "target": "constance", "at": view.alignment_epoch}
	c.cards = ["watch1"]
	var one = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	c.cards = ["watch1", "vigil1"]
	var twice = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	check(twice.pattern.incidents == 1, "two reports of night 1 remain one outing")
	c.cards = ["watch1", "watch2"]
	var nights = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	check(nights.pattern.incidents == 2 and nights.strength > one.strength, "a second night adds a distinct suspicious incident")
	c.cards.append("gift_claim")
	c.reasons = {"constance:1": "gift", "constance:2": "gift"}
	var explained = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	check(explained.strength < nights.strength, "credible night-gift testimony reduces outing suspicion")
	var pattern_listener: Dictionary = s.baseline[0].duplicate(true)
	Jury.evaluate(view, c, pattern_listener)
	check(is_zero_approx(Jury.evaluate(view, c, pattern_listener).suspicion_delta), "a witness's case cannot feed back into its own credibility on repetition")
	c.cards.erase("gift_claim")
	var unsupported = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	check(is_equal_approx(unsupported.strength, nights.strength), "an unsupported explanation label grants no free discount")
	c = Solver.empty_case()
	c.cards = ["watch1", "alibi1"]
	check(Solver.analyze(view, c).status == "conflicting", "watch sighting and same-night home alibi conflict")
	c.conclusion.type = "conflict"
	check(Solver.analyze(view, c).entailment == "forced", "the player can conclude that the reports conflict")
	c.cards = ["watch2", "lamp2"]
	var movement = Solver.analyze(view, c)
	check(movement.movement["2"].compatible == 1 and movement.movement["2"].forced_out.size() == 4, "Watch and Lamplighter jointly account for four walkers, excluding the lamp from its own count")
	c = Solver.empty_case()
	c.cards = ["survey", "rumor", "dowse"]
	c.conclusion.target = "hollis"
	var high: Dictionary = s.baseline[0].duplicate(true)
	var low: Dictionary = high.duplicate(true)
	low.npc_trust.merrin = 0.05
	var trusted = Jury.evaluate(view, c, high)
	var distrusted = Jury.evaluate(view, c, low)
	check(trusted.assessment.entailment == distrusted.assessment.entailment, "trust does not change logical implication")
	check(trusted.strength > distrusted.strength, "trust changes willingness to accept the premises")
	var stubborn: Dictionary = s.baseline[0].duplicate(true)
	stubborn.confidence = 1.0
	var suggestible: Dictionary = s.baseline[0].duplicate(true)
	suggestible.confidence = 0.0
	check(Jury.evaluate(view, c, stubborn).strength < Jury.evaluate(view, c, suggestible).strength, "confidence scales movement without changing arithmetic")
	var before = JSON.stringify(Jury.evaluate(view, c, s.baseline[0].duplicate(true)))
	s.scenario.truth[0].alignment = "good"
	s.scenario.timeline.clear()
	var after = JSON.stringify(Jury.evaluate(view, c, s.baseline[0].duplicate(true)))
	check(before == after, "changing hidden truth alone has no evaluator effect")
	for seed_value in [692, 101, 202, 303, 404]:
		var fixture = Scenario.generate(seed_value)
		check(fixture.public_view.cards.size() == 10, "seed %d generates five report types and supporting testimony" % seed_value)
		var truth = fixture.truth
		var roles: Array = truth.map(func(p): return p.role)
		check(roles.size() == 10 and roles.has("lamplighter"), "seed %d has a coherent ten-person lineup" % seed_value)
		var tc = Solver.empty_case()
		tc.cards = ["survey", "rumor", "dowse", "watch1", "watch2", "lamp1", "lamp2"]
		for person in truth:
			tc.positions[person.id] = "marked" if person.secret == "marked" else person.alignment
		check(Solver.analyze(fixture.public_view, tc).proposed == 1, "seed %d's actual world satisfies its generated reports" % seed_value)
		check(JSON.stringify(Scenario.generate(seed_value).public_view) == JSON.stringify(fixture.public_view), "seed %d is reproducible" % seed_value)
	s.case_data = c
	s.present(false)
	var exported = s.export_data()
	check(exported.history.size() == 1 and not exported.has("developer_truth"), "export includes reproducible presentation and omits optional spoilers")
	# JSON serialization changes integer types; a real roundtrip must still replay.
	s.present(true, "meeting")
	s.case_data.cards.erase("dowse")
	s.revise()
	s.present(true, "nomination")
	var saved = JSON.parse_string(JSON.stringify(s.export_data()))
	var restored = Session.new(101)
	var restore_error = restored.restore(saved)
	check(restore_error == "", "JSON experiment restores successfully: " + restore_error)
	check(restored.last_results == s.last_results, "restored history reproduces actual before/after jury assessments")
	check(restored.case_data == s.case_data, "restore preserves the current version and choices")
	var malformed = saved.duplicate(true)
	malformed.case.positions["intruder"] = "evil"
	check(restored.restore(malformed) != "", "invalid import is refused without replacing the session")
	check(restored.case_data == s.case_data, "failed restore is atomic")
	# Jurors can prefer different alternatives without disagreeing about arithmetic.
	c = Solver.empty_case()
	c.cards = ["survey", "rumor", "dowse"]
	var rival_listener: Dictionary = s.baseline[0].duplicate(true)
	rival_listener.suspicion.nisha = 0.8
	var neutral = Jury.evaluate(view, c, s.baseline[0].duplicate(true))
	var rival = Jury.evaluate(view, c, rival_listener)
	check(rival.strength < neutral.strength and rival.shared_assessment == neutral.shared_assessment, "prior suspicion favors a rival world without changing public logic")
	print("Case Workshop: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(okay: bool, label: String) -> void:
	checks += 1
	if not okay:
		fails += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)
