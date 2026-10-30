extends SceneTree
const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
const Support = preload("res://workshop/support_model.gd")
const Movement = preload("res://workshop/movement_model.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Model = preload("res://workshop/canvas_model.gd")
const World = preload("res://sim/world.gd")
const NPC = preload("res://sim/npc.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
var checks = 0
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var movement = Session.new(692, "movement")
	var view: Dictionary = movement.scenario.public_view
	var cards: Array = [Solver.card_by_id(view, "vigil3")]
	var one = Movement.likelihood(view, cards, "constance", false)
	cards.append(cards[0].duplicate(true))
	check(one == Movement.likelihood(view, cards, "constance", false), "duplicate observations of one incident do not multiply its likelihood")
	var direct = Movement.factors(view, cards, Solver.empty_case())[0]
	var two_cards: Array = [Solver.card_by_id(view, "vigil1"), Solver.card_by_id(view, "vigil3")]
	var two = Movement.factors(view, two_cards, Solver.empty_case())[0]
	check(two.log2_ratio > direct.log2_ratio, "a second night adds evidence through one persistent activity hypothesis")
	var eligible = view.duplicate(true)
	eligible.movement_experiment.gift_destinations.constance["3"] = ["square"]
	check(Movement.likelihood(eligible, cards, "constance", false, true) > Movement.likelihood(eligible, cards, "constance", false), "credible applicable gift activity makes the observed outing less incriminating")
	var cited = Solver.empty_case()
	cited.cards = ["vigil3"]
	cited.citations["constance:3"] = "gift_claim"
	cited.reasons["constance:3"] = "gift"
	check("gift_claim" in Solver.Graph.compile_case(eligible, cited).cards, "choosing a gift citation in Answer enrolls that reference in the normal attention budget")
	check(Movement.likelihood(view, cards, "constance", false, false, true) > one, "a supported private errand is an alternative explanation")
	check(Movement.likelihood(view, cards, "constance", false, false, true, true) == Movement.likelihood(view, cards, "constance", false, false, false, true), "a Marked person cannot receive an additional secret-modifier outing explanation")
	var absent: Dictionary = Solver.card_by_id(view, "coverage3").duplicate(true)
	absent.subject = "constance"
	absent.data.detection = 0.0
	check(is_equal_approx(Movement.likelihood(view, [absent], "constance", true), 1.0), "zero observation coverage provides no evidence of absence")
	absent.data.detection = 1.0
	check(Movement.likelihood(view, [absent], "constance", true) < Movement.likelihood(view, [absent], "constance", false), "complete relevant coverage can favor a non-hunting explanation without proving good")
	absent.block = "market"
	check(Movement.likelihood(view, [absent], "constance", true) > 0, "watching a block off the route does not prove the suspect stayed home")
	var trace = Movement.trace_distribution("market", ["hill"])
	check(trace.market == 0.6 and trace.hill == 0.4, "trace mechanism matches the game's eligible-passer 40 percent branch")
	check(Movement.trace_distribution("market", ["market"]).market == 1.0, "a matching eligible passer does not change the trace material")
	check(Movement.trace_distribution("market", []).market == 1.0, "without an eligible passer the trace reflects the killer's evening")
	var soot: Array = [Solver.card_by_id(view, "soot2"), Solver.card_by_id(view, "evening2")]
	var first = Movement.factors(view, soot, Solver.empty_case())[0]
	soot.append(Solver.card_by_id(view, "soot3"))
	soot.append(Solver.card_by_id(view, "evening3"))
	var repeated = Movement.factors(view, soot, Solver.empty_case())[0]
	check(repeated.log2_ratio > first.log2_ratio, "repeated soot can favor a shared evening haunt while retaining a passer alternative")
	check(repeated.good_likelihood > 0, "matching crime-scene material does not eliminate the innocent-passer explanation")
	var changed_evening = Solver.card_by_id(view, "evening3").duplicate(true)
	changed_evening.block = "hill"
	check(Movement.likelihood(view, [Solver.card_by_id(view, "evening2"), changed_evening], "constance", true) > 0, "a preferred haunt does not force the same evening location every day")
	var quote = Solver.card_by_id(view, "alibi1").duplicate(true)
	quote["quoted"] = true
	var vigil: Dictionary = Solver.card_by_id(view, "vigil1")
	check(Movement.factors(view, [vigil, quote], Solver.empty_case())[0].log2_ratio > Movement.factors(view, [vigil], Solver.empty_case())[0].log2_ratio, "a challenged home account is assessed jointly with the outing, including good concealment alternatives")
	_calibration()
	var c = Solver.empty_case()
	c.cards = ["survey", "rumor", "dowse", "soot2", "evening2", "soot3", "evening3", "vigil3"]
	var juror: Dictionary = movement.baseline[3].duplicate(true)
	var result = Jury.evaluate(view, c, juror)
	check(result.support_model.factors.any(func(f): return f.begins_with("Movement / trace")) and result.effects.constance.pattern_signal == 0, "the common case engine uses the joint movement factor instead of adding the old pattern heuristic")
	check(result.shared_assessment.compatible == 2, "soft evidence changes preference without deleting the hard-reading mirror")
	check(result.stance == "accept" and result.shared_assessment.entailment == "possible" and result.response.contains("alternative"), "strong circumstantial evidence can persuade while the NPC acknowledges a surviving logical alternative")
	var again = Jury.evaluate(view, c, juror)
	check(again.effects.values().all(func(e): return is_zero_approx(e.delta)), "joint soft evidence is repeat-stable for all character effects")
	Support.cache.clear()
	Support.comparisons.clear()
	Solver.report_matches.clear()
	Solver.movement_cache.clear()
	Movement.cache.clear()
	var started = Time.get_ticks_msec()
	var measured = Jury.evaluate(view, c, movement.baseline[3].duplicate(true))
	var cold_ms = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	Jury.evaluate(view, c, movement.baseline[3].duplicate(true))
	print("Movement model caches cold/cached (one juror): %d/%d ms; %d credibility states; %d explanation checks; %d compatible assignments" % [cold_ms, Time.get_ticks_msec() - started, measured.support_model.states, measured.reasoning.tested, measured.assessment.compatible])
	movement.case_data = c
	movement.present(false)
	_roundtrip(movement, "movement")
	var poison = Session.new(692, "poison")
	view = poison.scenario.public_view
	var bad = Solver.card_by_id(view, "dowse")
	var recovered = Solver.card_by_id(view, "dowse_recovered")
	check(bad.data.count < 2 and recovered.data.count == 3, "poison and recovery reports are generated by the actual gift routine in the scripted legal group")
	c = poison.case_data.duplicate(true)
	c.cards = ["survey", "rumor", "dowse", "dowse_relay", "dowse_recovered", "vial1"]
	c.conclusion.target = "hollis"
	c.faults = {"night1": {"type": "poisoned", "window": "night1", "basis": "vial1"}}
	check(poison.validate_case(c) == "", "a supported fault refers to the legal poison duration")
	check(Solver.analyze(view, c).proposed > 0 and not Solver.analyze(view, c).hypothetically_released.is_empty(), "validator can represent the proposed poisoned explanation without treating its broken reading as healthy")
	check(TimeModel.fault_for(view, c, bad).key == TimeModel.fault_for(view, c, Solver.card_by_id(view, "dowse_relay")).key, "reports and retellings within one poison interval share one health cause")
	check(TimeModel.fault_for(view, c, recovered).is_empty(), "recovery reading is outside the poison interval")
	var assessment = Support.assess(view, c, poison.baseline[3])
	started = Time.get_ticks_msec()
	var conflicts = Solver.minimal_conflicts(view, Solver.selected(view, c))
	print("Poison healthy-report conflict extraction: %d ms; %d minimal cores" % [Time.get_ticks_msec() - started, conflicts.size()])
	check(assessment.faults == ["healthy:night1"] and assessment.atoms.filter(func(a): return a.key.begins_with("healthy:")).size() == 1, "the credibility mixture counts a poison episode once")
	var unsupported = c.duplicate(true)
	unsupported.faults.night1.basis = ""
	check(Support.assess(view, unsupported, poison.baseline[3]).faults.is_empty(), "a bare poisoning assertion receives no free reliability discount")
	var no_fault = Support.assess(view, unsupported, poison.baseline[3])
	check(assessment.report_acceptance.dowse <= no_fault.report_acceptance.dowse + 1e-9 and assessment.report_acceptance.dowse_recovered >= no_fault.report_acceptance.dowse_recovered - 1e-9, "interval doubt does not increase acceptance of the bad report or discredit the recovered reading")
	var isolated = c.duplicate(true)
	isolated.cards.erase("dowse_recovered")
	var with_fault = Support.assess(view, isolated, poison.baseline[3])
	isolated.faults.night1.basis = ""
	var without_fault = Support.assess(view, isolated, poison.baseline[3])
	check(with_fault.report_acceptance.dowse < without_fault.report_acceptance.dowse, "before recovery, supported interval doubt retracts acceptance of the affected report")
	var with_sighting = c.duplicate(true)
	with_sighting.cards.append("watch1")
	check(Support.assess(view, with_sighting, poison.baseline[3]).report_acceptance.watch1 == 1.0, "poisoning another source does not weaken the juror's independent firsthand Watch report")
	var invalid = c.duplicate(true)
	invalid.faults.night1.window = "night99"
	check(poison.validate_case(invalid) != "", "impossible poison timing is rejected")
	var poison_board = Model.new(view)
	poison_board.nodes["e:dowse"]["faults"] = c.faults.duplicate(true)
	poison_board.nodes["e:dowse_relay"]["faults"] = unsupported.faults.duplicate(true)
	for id in ["dowse", "dowse_relay", "vial1"]:
		poison_board.connect_cards("e:" + id, poison_board.selected)
	var supported_basis: String = poison_board.compile(poison_board.selected).faults.night1.basis
	poison_board.links.reverse()
	check(supported_basis == "vial1" and poison_board.compile(poison_board.selected).faults.night1.basis == supported_basis, "a bare restatement cannot erase supported poisoning when links are reordered")
	poison.case_data = c
	poison.present(false)
	poison.case_data.cards.erase("vial1")
	poison.revise()
	var withdrew_support = poison.present(true)
	check(withdrew_support.all(func(r): return r.support_model.faults.is_empty()), "removing the poison basis retracts its interval support in remembered discussion")
	_roundtrip(poison, "poison")
	var revenant = Session.new(692, "revenant")
	view = revenant.scenario.public_view
	check(revenant.scenario.timeline[-2].curse_victim == "merrin" and revenant.scenario.timeline[-1].freed == "merrin", "real Revenant eligibility and totem destruction paths convert and restore Merrin")
	check(revenant.scenario.timeline[-2].evil_intel_count > 0 and revenant.scenario.timeline[-1].intel_after == {}, "native restoration removes actual evil-only intelligence learned while converted")
	check(revenant.scenario.timeline[-1].fake_disowned, "native restoration disowns the actual fake report recorded while converted")
	c = revenant.case_data.duplicate(true)
	c.cards = ["survey", "rumor", "dowse", "curse_warning"]
	c.conclusion = {"type": "evil", "target": "merrin", "at": "during curse"}
	var worlds: Array = Solver.solve(view, Solver.selected(view, c)).worlds
	check(worlds.any(func(w): return view.people[w.converted].id == "merrin"), "a later converted Merrin remains compatible with his earlier good healthy reading")
	check(worlds.all(func(w): return view.people[w.converted].id in ["merrin", "nisha", "odette"] and not (w.evil & (1 << w.converted))), "converted candidates are surviving originally-good yes-voters, not the hanged Revenant")
	var candidate: Dictionary = worlds.filter(func(w): return view.people[w.converted].id == "merrin")[0]
	check(not TimeModel.evil_at(view, candidate, "merrin", "before curse") and TimeModel.evil_at(view, candidate, "merrin", "during curse") and not TimeModel.evil_at(view, candidate, "merrin", "after restoration"), "alignment is evaluated at the requested epoch with an exclusive restoration boundary")
	check(Solver._report_holds(view, candidate, Solver.card_by_id(view, "rumor"), {}), "earlier reading is not retroactively invalidated by conversion")
	var during_read = Solver.card_by_id(view, "rumor").duplicate(true)
	during_read.observed_at = {"day": 4, "phase": "night"}
	check(not Solver._report_holds(view, candidate, during_read, {}), "a healthy-good gift assumption made during conversion cannot reuse the earlier good alignment")
	check(TimeModel.source_key(view, Solver.card_by_id(view, "rumor")) != TimeModel.source_key(view, Solver.card_by_id(view, "rumor_retold")), "retelling during conversion has a distinct testimony-period credibility assumption")
	c.answers.curse_warning = {"positive": ["merrin"]}
	check(Solver.analyze(view, c).proposed < Solver.analyze(view, c).compatible, "answering who converted is a proposed world, not new evidence identifying them")
	var before_case = c.duplicate(true)
	before_case.conclusion.at = "before curse"
	check(Solver.analyze(view, before_case).entailment == "unsupported", "accepting Merrin's early good report excludes his original evil alignment")
	var cover: Dictionary = revenant.baseline[1].duplicate(true)
	cover["intel"] = {"demon": "constance"}
	cover["evil_only"] = true
	cover.knowledge.own_reports.append("rumor_retold")
	var restored_cover = TimeModel.restore_cover(cover, view)
	check(not restored_cover.has("intel") and not restored_cover.has("evil_only") and "rumor_retold" not in restored_cover.knowledge.own_reports, "restoration adapter copies only permitted cover knowledge and removes withdrawn own retellings")
	var late = c.duplicate(true)
	late.cards.append("rumor_retold")
	var late_support = Support.assess(view, late, revenant.baseline[3])
	check(late_support.report_acceptance.rumor_retold == 0 and late_support.report_acceptance.rumor > 0, "known withdrawal disables the later retelling without erasing the original reading")
	revenant.case_data = c
	revenant.present(false)
	revenant.case_data.conclusion.at = "after restoration"
	revenant.case_data.conclusion.type = "good"
	revenant.revise()
	var restored_results = revenant.present(true)
	check(restored_results[3].effects.merrin.delta < 0, "presenting the restored epoch retracts earlier curse-era suspicion")
	_roundtrip(revenant, "Revenant")
	var board = Model.new(view)
	var early = board.add_premise("merrin", "good", Vector2.ZERO)
	board.nodes[early].conclusion.at = "before curse"
	board.nodes[early].positions.merrin = "good"
	board.nodes[board.selected].conclusion = {"type": "evil", "target": "merrin", "at": "during curse"}
	# add_premise does not select the new card; the initial root remains selected.
	board.nodes[board.selected].positions.merrin = "evil"
	board.connect_cards("e:rumor", early)
	board.connect_cards(early, board.selected)
	var dated = board.compile(board.selected)
	check(revenant.validate_case(dated) == "" and not Solver.analyze(view, dated).proposed == 0, "good before conversion and evil during conversion are compatible dated assumptions")
	var persistent = revenant.baseline[3].duplicate(true)
	persistent.confidence_mode = "persistence"
	Jury.evaluate(view, dated, persistent)
	var restated = board.add_premise("merrin", "good", Vector2.ZERO)
	board.nodes[restated].conclusion.at = "before curse"
	board.nodes[restated].positions.merrin = "good"
	board.connect_cards("e:rumor", restated)
	board.connect_cards(restated, board.selected)
	var restatement = Jury.evaluate(view, board.compile(board.selected), persistent)
	check(restatement.repeated and restatement.effects.values().all(func(e): return is_zero_approx(e.delta)), "duplicate dated premises cannot farm confidence persistence or evidence effects")
	await _ui()
	print("Remaining Workshop slices: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _calibration() -> void:
	var native = World.new()
	native.rng.seed = 7421
	native.day = 2
	var killer = NPC.new()
	killer.id = "constance"
	killer.name = "Constance"
	killer.alignment = "evil"
	killer.role = "demon"
	killer.home_block = "market"
	killer.night_path = ["square"]
	var passer = NPC.new()
	passer.id = "bart"
	passer.name = "Bart"
	passer.home_block = "hill"
	passer.night_path = ["square"]
	var victim = NPC.new()
	victim.id = "agnes"
	victim.name = "Agnes"
	victim.home_block = "square"
	native.npcs = [killer, passer, victim]
	native.by_id = {killer.id: killer, passer.id: passer, victim.id: victim}
	native.demon_id = killer.id
	killer.history[native.time_key(2, C.EVENING)] = "bakery"
	passer.history[native.time_key(2, C.EVENING)] = "chapel"
	native.night_walkers = [{"id": passer.id, "block": "square", "path": ["square"], "why": "calibration"}]
	var demon_fit_count = 0
	var two_trace_count = 0
	var slot0_demon_count = 0
	var token_count = 0
	var loc_count = 0
	var demon_items = 0
	var good_items = 0
	killer.work = "bakery"
	killer.haunts = ["tavern", "mill"]
	passer.work = "chapel"
	passer.haunts = ["graveyard", "well"]
	for i in range(10000):
		victim.alive = true
		native.deaths_last_night.clear()
		native.case_traces.clear()
		native._kill(victim)
		var scene_traces: Array = native.scenes["scene_agnes"]["traces"]
		demon_fit_count += int(scene_traces.any(func(t): return native.actor_fits_trace_truth(killer, t)))
		if scene_traces.size() == 2:
			two_trace_count += 1
			slot0_demon_count += int(scene_traces[0].get("actor", "") == killer.id)
		var dtr: Dictionary = native.scenes["scene_agnes"]["trace"]
		if dtr.trace_family == "locations":
			loc_count += 1
			token_count += int(dtr.trace_subtype == "token")
		native.dropped.clear()
		native._maybe_drop(killer, "calibration")
		for dropped in native.dropped.values():
			demon_items += int(dropped[0].owner == killer.id)
		native.dropped.clear()
		native._maybe_drop(passer, "calibration")
		for dropped in native.dropped.values():
			good_items += int(dropped[0].owner == passer.id)
	check(demon_fit_count == 10000 and loc_count > 6000 and absf(float(token_count) / float(loc_count) - Tuning.Setup.TRACE_TOKEN_PROB) < 0.03 and absf(two_trace_count / 10000.0 - Tuning.Setup.EXTRA_TRACE_CHANCE) < 0.025 and absf(float(slot0_demon_count) / maxf(two_trace_count, 1) - 0.5) < 0.04, "10,000 kill-generator samples always include the Demon trace, hit ~75% locations (67/33 token/scent), and roll 45% shuffled passer second traces")
	check(absf(demon_items / 10000.0 - 0.042) < 0.007 and absf(good_items / 10000.0 - 0.018) < 0.005, "actual drop-generator samples match the conditional 4.2/1.8 percent mechanism, before route/location search")

func _ui() -> void:
	var scene = load("res://ui/case_workshop.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var picker = scene.find_child("WorkshopExperiment", true, false)
	for i in [1, 2, 3]:
		picker.select(i)
		picker.item_selected.emit(i)
		check(scene.session.validate_case(scene.session.case_data) == "", "experiment picker produces a valid connected case %d" % i)
		if i == 2:
			scene._open_answer("e:dowse")
			var fault = scene.find_child("PoisonExplanation", true, false)
			fault.select(2)
			fault.item_selected.emit(2)
			scene.answer_window.hide()
			check(scene.board.compile(scene.case_root).faults.night1.basis == "vial1", "actual Answer control cites a shared poison interval")
		if i == 3:
			scene._open_answer("e:curse_warning")
			var voter = scene.find_child("ConvertedVoter", true, false)
			voter.select(1)
			voter.item_selected.emit(1)
			scene.answer_window.hide()
			check(scene.board.compile(scene.case_root).answers.curse_warning.positive == ["merrin"], "actual curse card answers who converted, preserving uncertainty as a choice")
			scene._open_answer(scene.case_root)
			var epoch = scene.find_child("ClaimEpoch", true, false)
			epoch.select(2)
			epoch.item_selected.emit(2)
			scene.answer_window.hide()
			check(scene.board.compile(scene.case_root).conclusion.at == "after restoration", "actual premise control selects the alignment epoch")
		var start = Time.get_ticks_msec()
		scene._present()
		print("Fixture %s jury latency: %d ms" % [scene.session.scenario.fixture, Time.get_ticks_msec() - start])
		check(scene.session.last_results.size() == 4, "new fixture presents through the shared jury engine %d" % i)
		scene.jury_window.hide()
		var before = scene.session.last_results.duplicate(true)
		var path = "user://workshop-remaining-%d.json" % i
		scene._save(path)
		scene._load_fixture(0)
		scene._open(path)
		check(scene.session.last_results == before and picker.selected == i, "canvas experiment, answers, dates and jury history restore %d: %s" % [i, scene.status.text])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame

func _roundtrip(session, label: String) -> void:
	var restored = Session.new()
	var error = restored.restore(JSON.parse_string(JSON.stringify(session.export_data())))
	check(error == "" and restored.last_results == session.last_results, label + " fixture and chronology replay exactly: " + error)
	var before = Support.assess(session.scenario.public_view, session.case_data, session.baseline[3])
	session.scenario.truth.reverse()
	session.scenario.timeline.append({"actual_hidden_cause": "changed for isolation test"})
	check(Support.assess(session.scenario.public_view, session.case_data, session.baseline[3]) == before, label + " assessment is independent of hidden causes and truth ordering")

func check(okay: bool, label: String) -> void:
	checks += 1
	if okay:
		print("PASS: " + label)
	else:
		fails += 1
		push_error("FAIL: " + label)
