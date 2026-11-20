## A listener's bounded explanation search over the cards it attends (explain), the world
## priors it ranks explanations by, and how far it trusts each source. The credibility
## mixture that once judged cases here went with the pre-CaseEval engine (purge phase 7).
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Movement = preload("res://workshop/movement_model.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Profiler = preload("res://workshop/profiler.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")
static var cache: Dictionary = {}
static var priors: Dictionary = {}
# Developer A/B switch for the reproducible profiler, not a gameplay setting.
static var reuse_priors = true
static var next_solve_id: int = 1
static var next_rank_id: int = 1
static var explanations: Dictionary = {}
static var reuse_explanations = true

static func explain(view: Dictionary, value: Dictionary, listener: Dictionary, prepared: Dictionary = {}) -> Dictionary:
	value = Solver.with_hanged_refuters(view, value)  # "was the Demon when hanged" refuted alike (Lantern)
	var span = Profiler.open("explain")
	# These are the inputs read by attention, bounded search, source quality and
	# prior ranking. Theory memory/receipt bookkeeping do not enter this operation.
	var profile = {}
	for field in ["id", "reasoning_mode", "insight", "knowledge", "suspicion", "npc_trust", "reading_reliability"]:
		profile[field] = listener.get(field)
	var inputs = [view, value, profile, prepared]
	var key = hash(inputs)
	if reuse_explanations and explanations.has(key) and explanations[key].inputs == inputs:
		Profiler.count("explanation_cache_hit")
		var cached: Dictionary = explanations[key].result.duplicate(true)
		Profiler.close(span)
		return cached
	var result = _explain(view, value, listener, prepared)
	if reuse_explanations:
		if explanations.size() >= 256:
			explanations.erase(explanations.keys()[0])
		explanations[key] = {"inputs": inputs.duplicate(true), "result": result.duplicate(true)}
	Profiler.close(span)
	return result

static func _explain(view: Dictionary, value: Dictionary, listener: Dictionary, prepared: Dictionary = {}) -> Dictionary:
	var attention = Reasoner.prepare(view, value, listener) if prepared.is_empty() else prepared
	var considered = attention.case
	var cards = Solver.selected(view, considered)
	for id in listener.knowledge.get("own_reports", []):
		if listener.get("reasoning_mode", "full") == "bounded" and listener.knowledge.has("presented_reports") and id not in attention.considered:
			continue
		if listener.get("reasoning_mode", "full") == "bounded" and id not in attention.considered and id not in listener.knowledge.get("attention_reports", listener.knowledge.get("own_reports", [])):
			continue
		if not cards.any(func(c): return c.id == id):
			cards.append(Solver.card_by_id(view, id))
	var accepted: Array = cards.filter(func(c): return not TimeModel.disowned(view, c, listener.knowledge.get("known_events", [])) and (c.get("quoted", false) or (c.id not in attention.private_checks.rejected and source_quality(listener, c.source) >= 0.4 and (c.kind != "report" or listener.reading_reliability.get(c.get("accuracy_origin", Solver.semantic_key(c)), 1.0) >= 0.5))))
	var limits: Dictionary = attention.limits if listener.get("reasoning_mode", "full") == "bounded" else {"support": 840, "rivals": 840, "complete": true}
	if Solver.Domain.live(view) and listener.get("reasoning_mode", "full") == "full":
		limits.support = Solver.Domain.worlds(view).size()
		limits.rivals = limits.support
	var result = Reasoner.search(view, considered, accepted, listener, limits)
	if result.support.is_empty():
		var own_ids: Array = listener.knowledge.get("own_reports", [])
		var core_accepted: Array = accepted.filter(func(c): return c.id not in own_ids or c.source == listener.id)
		if not core_accepted.is_empty() and core_accepted.size() < accepted.size():
			var core_result = Reasoner.search(view, considered, core_accepted, listener, limits)
			if not core_result.support.is_empty():
				result = core_result
				accepted = core_accepted
		if result.support.is_empty() and not result.get("local_conflict", []).is_empty():
			var conflict_ids: Array = result.local_conflict
			var challenged_cards: Array = []
			for c in accepted:
				if c.kind == "alibi" and c.id in conflict_ids:
					var q = c.duplicate(true)
					q["quoted"] = true
					challenged_cards.append(q)
				else:
					challenged_cards.append(c)
			var challenged_result = Reasoner.search(view, considered, challenged_cards, listener, limits)
			if not challenged_result.support.is_empty():
				result = challenged_result
				accepted = challenged_cards
	result.merge(attention)
	result.erase("case")
	result["accepted"] = accepted.map(func(c): return c.id)
	result["doubted"] = cards.filter(func(c): return not accepted.any(func(a): return a.id == c.id)).map(func(c): return c.id)
	var factors: Array = considered.test_factors.filter(func(f): return f.routes.any(func(route): return route.all(func(id): return accepted.any(func(c): return Solver.semantic_key(c) == Solver.semantic_key(Solver.card_by_id(view, id))))))
	factors.append_array(Movement.factors(view, accepted, considered))
	for factor in factors:
		factor["epoch"] = considered.conclusion.at
	var ranks = prior_scores(view, listener, {}, considered.conclusion.at)
	result["support_score"] = world_score(view, result.support, ranks, factors)
	result["rival_score"] = world_score(view, result.rival, ranks, factors)
	result["has_evidence"] = not Solver.selected(view, considered).is_empty()
	result["assumption_note"] = "Search explanation grants source weight >= 0.4 and reading accuracy >= 0.5; numerical conviction averages credibility states."
	return result

static func source_quality(listener: Dictionary, source: String) -> float:
	if source == listener.id:
		return 1.0
	if source == "player":
		return 0.9
	return clampf(Tuning.Workshop.WITNESS_QUALITY_BASE + Tuning.Workshop.WITNESS_QUALITY_TRUST_SCALE * listener.npc_trust.get(source, 0.5) - Tuning.Workshop.WITNESS_QUALITY_SUSP_SCALE * listener.suspicion.get(source, 0.1), Tuning.Workshop.WITNESS_QUALITY_MIN, Tuning.Workshop.WITNESS_QUALITY_MAX)

static func _direct_ratio(factors: Array, conclusion: Dictionary) -> float:
	if conclusion.type not in ["evil", "good", "suspicious"]:
		return 1.0
	var exponent = 0.0
	for factor in factors:
		if factor.target == conclusion.target:
			exponent += float(factor.log2_ratio) * (-1.0 if conclusion.type == "good" else 1.0)
	return pow(2.0, exponent)

static func _solve(view: Dictionary, cards: Array, knowledge: Dictionary) -> Dictionary:
	var span = Profiler.open("support_solve")
	var result = _solve_inner(view, cards, knowledge)
	Profiler.close(span)
	return result

static func _solve_inner(view: Dictionary, cards: Array, knowledge: Dictionary) -> Dictionary:
	# Hash lookup plus exact input comparison avoids rebuilding JSON signatures in
	# every credibility state / character projection. Equality guards collisions.
	var inputs = [view.people, view.evil_count, view.get("chronology", {}), view.get("timeline", {}), view.get("live_activity", false), view.get("world_options", {}), cards, knowledge]
	var key = hash(inputs)
	if cache.has(key) and cache[key].inputs == inputs:
		Profiler.count("solve_cache_hit")
		return cache[key].result
	Profiler.count("solve_cache_miss")
	if cache.size() > 512:
		cache.clear()
	var solved = Solver.solve(view, cards, {}, {}, knowledge)
	next_solve_id += 1
	solved["__id"] = next_solve_id
	cache[key] = {"inputs": inputs.duplicate(true), "result": solved}
	return solved

static func prior_scores(view: Dictionary, listener: Dictionary, bias: Dictionary = {}, epoch: String = "") -> Dictionary:
	var span = Profiler.open("priors")
	var result = _prior_scores(view, listener, bias, epoch)
	Profiler.close(span)
	return result

static func _prior_scores(view: Dictionary, listener: Dictionary, bias: Dictionary = {}, epoch: String = "") -> Dictionary:
	# The same baseline ranks every person's projection and every credibility
	# subset. Accuracy weights and the question's target do not enter these priors.
	var inputs = [view.people, view.evil_count, view.get("chronology", {}), view.get("timeline", {}), view.get("live_activity", false), view.get("world_options", {}),
		view.alignment_epoch, epoch, listener.knowledge, listener.suspicion, listener.npc_trust, bias]
	var key = hash(inputs)
	if reuse_priors and priors.has(key) and priors[key].inputs == inputs:
		Profiler.count("prior_cache_hit")
		return priors[key].ranks
	Profiler.count("prior_cache_miss")
	var ranks = {}
	# Without conversion histories a world's score depends only on its evil team.
	var plain: bool = Solver.Domain.live(view) and Solver.world_bits(view).plain
	var by_team = {}
	for world in _solve(view, [], listener.knowledge).worlds:
		if plain and by_team.has(world.evil):
			var cached: float = by_team[world.evil]
			if not bias.is_empty() and Solver.position_holds(view, world, bias.target, bias.position, epoch):
				cached *= bias.factor
			ranks[TimeModel.key(view, world)] = cached
			continue
		var score = 1.0
		for i in range(view.people.size()):
			var id: String = view.people[i].id
			var suspicion: float = listener.suspicion.get(id, 0.1)
			var trust: float = listener.npc_trust.get(id, 0.5)
			if TimeModel.evil_index(view, world, i, view.alignment_epoch if epoch == "" else epoch):
				score *= maxf(0.15 + suspicion * 1.2 - (trust - 0.5) * 0.5, 0.02)
			else:
				score *= maxf(0.3 + (0.6 - suspicion) * 0.6 + (trust - 0.5) * 0.4, 0.05)
		if plain:
			by_team[world.evil] = score
		if not bias.is_empty() and Solver.position_holds(view, world, bias.target, bias.position, epoch):
			score *= bias.factor
		ranks[TimeModel.key(view, world)] = score
	next_rank_id += 1
	ranks["__id"] = next_rank_id
	if reuse_priors:
		if priors.size() >= 64:
			priors.clear()
		priors[key] = {"inputs": inputs.duplicate(true), "ranks": ranks}
	return ranks

static func world_score(view: Dictionary, world: Dictionary, ranks: Dictionary, factors: Array) -> float:
	if world.is_empty():
		return 0.0
	var score: float = ranks.get(TimeModel.key(view, world), 0.0)
	for factor in factors:
		if factor.get("joint_live", false):
			score *= Movement.Live.score(world, factor)
			continue
		var target: int = Solver.person_index(view, factor.target)
		if target >= 0 and TimeModel.evil_at(view, world, factor.target, factor.get("epoch", view.alignment_epoch)):
			score *= pow(2.0, float(factor.log2_ratio))
		elif target >= 0 and factor.get("origin", "") == "movement_model" and world.marked == target:
			score *= maxf(factor.good_marked_likelihood, 1e-12) / maxf(factor.good_likelihood, 1e-12)
	return score
