extends SceneTree
const Profile = preload("res://workshop/profiler.gd")
const Session = preload("res://workshop/session.gd")
const Support = preload("res://workshop/support_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
var checks = 0
var fails = 0

func _initialize() -> void:
	check(not Profile.enabled and Profile.open("disabled") == -1, "profiling is opt-in and disabled spans are inert")
	Profile.start()
	var outer = Profile.open("outer", "listener")
	var inner = Profile.open("inner")
	Profile.count("cache_hit")
	Profile.close(inner)
	Profile.close(outer)
	var measured = Profile.finish()
	check(not Profile.enabled and measured.rows.size() == 2, "finish balances nested spans and disables profiling")
	var parent: Dictionary = measured.rows.filter(func(row): return row.stage == "outer")[0]
	var child: Dictionary = measured.rows.filter(func(row): return row.stage == "inner")[0]
	check(parent.total_us == parent.self_us + child.total_us and child.listener == "listener", "exclusive times reconcile exactly and inherit the listener")
	check(measured.counters.get("listener|outer/inner|cache_hit") == 1, "cache counters retain listener and calculation path")
	Profile.start()
	check(Profile.finish().rows.is_empty(), "new measurements do not retain previous rows")
	var session = Session.new(692)
	var view: Dictionary = session.scenario.public_view
	var listener = Ghost.profile(view.people)
	var baseline = _priors(view, listener)
	Profile.start()
	check(_priors(view, listener) == baseline, "identical prior inputs reuse exactly the same ranking")
	var repeated = Profile.finish()
	check(repeated.counters.values().any(func(v): return v > 0), "prior reuse exposes hit/miss counters")
	listener.suspicion.constance = 0.9
	check(_priors(view, listener) != baseline, "changed suspicion invalidates priors")
	listener.suspicion.constance = 0.1
	check(_priors(view, listener) == baseline, "restoring suspicion recovers the original cached ranking")
	listener.npc_trust.constance = 0.9
	check(_priors(view, listener) != baseline, "changed witness trust invalidates priors")
	listener.npc_trust.constance = 0.5
	check(_priors(view, listener, {"target": "constance", "position": "evil", "factor": 3.0}) != baseline, "confidence-persistence bias has separate priors")
	listener.knowledge.good = ["constance"]
	check(_priors(view, listener).size() < baseline.size(), "private good knowledge invalidates the candidate domain")
	listener.knowledge.good = []
	var changed_view: Dictionary = view.duplicate(true)
	changed_view.evil_count -= 1
	check(_priors(changed_view, listener).size() != baseline.size(), "setup changes cannot reuse a prior domain")
	for fixture in ["core", "movement", "poison", "revenant"]:
		var experiment = Session.new(692, fixture)
		var proposal = Solver.empty_case()
		proposal.conclusion = experiment.case_data.conclusion.duplicate(true)
		proposal.cards = experiment.scenario.public_view.cards.filter(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"]).slice(0, 3).map(func(c): return c.id)
		if fixture == "movement":
			proposal.cards.append_array(["soot2", "evening2"])
		Support.reuse_priors = false
		Support.reuse_comparisons = false
		var old = Support.assess(experiment.scenario.public_view, proposal, experiment.baseline[0])
		Support.reuse_priors = true
		Support.reuse_comparisons = true
		check(Support.assess(experiment.scenario.public_view, proposal, experiment.baseline[0]) == old, fixture + " support results match exactly with both optimizations")
	var live: Dictionary = view.duplicate(true)
	live.world_options = {"modifiers": ["marked", "delusional", "lovers", "sleepwalker"]}
	var claim = Solver.empty_case()
	claim.conclusion.at = live.alignment_epoch
	claim.cards = ["survey", "rumor", "dowse"]
	for target in ["constance", "hollis", "nisha"]:
		claim.conclusion.target = target
		for budget in [4, 48, 5040]:
			_search(live, claim, listener, budget)
	claim.positions.constance = "good"
	_search(live, claim, listener, 5040)
	claim.positions.clear()
	claim.answers.dowse = {"positive": ["hollis"]}
	_search(live, claim, listener, 5040)
	claim.answers.clear()
	listener.knowledge.good = ["constance"]
	_search(live, claim, listener, 5040)
	listener.knowledge.good = []
	live.world_options.modifiers = ["sleepwalker"]
	_search(live, claim, listener, 5040)
	print("Workshop profiling: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _priors(view: Dictionary, listener: Dictionary, bias: Dictionary = {}) -> Dictionary:
	Support.reuse_priors = false
	var expected = Support.prior_scores(view, listener, bias)
	Support.reuse_priors = true
	var actual = Support.prior_scores(view, listener, bias)
	var actual_scores = actual.duplicate()
	actual_scores.erase("__id")
	expected.erase("__id")
	check(actual_scores == expected, "cached prior rankings match fresh calculation (cache IDs are metadata)")
	return actual

func _search(view: Dictionary, claim: Dictionary, listener: Dictionary, budget: int) -> void:
	var cards = Solver.selected(view, claim)
	var limits = {"support": budget, "rivals": budget, "complete": true}
	Reasoner.reuse_matches = false
	var expected = Reasoner.search(view, claim, cards, listener, limits)
	Reasoner.reuse_matches = true
	check(Reasoner.search(view, claim, cards, listener, limits) == expected, "cached candidate checks preserve worlds, ordering, exhaustion and exact search counts")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
