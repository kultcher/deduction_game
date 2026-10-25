## Exact reference marginalization for the source/channel model. Conditional
## solves enforce joint unique-role and movement constraints only in states where
## their statements are accurate. This is also the oracle for a faster kernel.
extends RefCounted
const Channels = preload("res://workshop/evidence_channels.gd")
const Solver = preload("res://workshop/solver.gd")
const Movement = preload("res://workshop/movement_model.gd")
const Public = preload("res://workshop/public_evidence.gd")
const Speech = preload("res://workshop/speech_evidence.gd")
static var cache = {}

## rates maps channel keys to probabilities, or {healthy, impaired} for an
## accuracy channel. In a hypothetical Delusional world its impaired prior applies.
## q maps original reading IDs to false-content likelihoods. Role declarations
## and ordinary testimony have no extra random-content penalty: their credibility
## is already the shared honesty channel. Several faithful paths
## to one original fact are priced once, and accurate content may occur by chance.
## baseline_ids identifies private evidence held before the submitted case.
static func assess(view: Dictionary, cards: Array, knowledge: Dictionary, rates: Dictionary, q: Dictionary, baseline_ids: Array = [], prune_irrelevant: bool = true, representatives: PackedInt32Array = PackedInt32Array(), multiplicity: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	var plan = Channels.compile(view, cards)
	var universe: Array = Solver.universe(view)
	var base = PackedFloat64Array()
	var post = PackedFloat64Array()
	var size: int = universe.size() if representatives.is_empty() else representatives.size()
	assert(multiplicity.is_empty() or multiplicity.size() == size)
	base.resize(size)
	post.resize(size)
	var result = {"base": base, "post": post, "acceptance": {}, "held": {}, "consistent": false, "issues": plan.issues, "states": 0}
	if not plan.issues.is_empty():
		return result
	# Enumerate both sides of a world-dependent channel even if its healthy prior
	# is certain. The arbitrary structural half is never used as a probability.
	var structural = {}
	for channel in plan.channels:
		assert(rates.has(channel.key), "Missing channel prior: " + channel.key)
		structural[channel.key] = 0.5 if rates[channel.key] is Dictionary else rates[channel.key]
	var states = Channels.states(plan, structural, prune_irrelevant)
	var input = [Solver._universe_key(view), view.people, view.get("timeline", {}), view.get("live_activity", false), cards, knowledge, baseline_ids]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 16:
			cache.clear()
		cache[key] = {"input": input.duplicate(true), "states": {}, "solves": {}}
	var subsets: Dictionary = cache[key].states
	var totals = {}
	var origins = {}
	var report_origins = {}
	var private_origins = {}
	for card in cards:
		if card.get("quoted", false):
			continue
		var origin: String = card.get("accuracy_origin", card.get("fact_id", card.id))
		origins[card.id] = origin
		if card.kind == "report":
			report_origins[origin] = true
		var held: Array = []
		held.resize(size)
		held.fill(0.0)
		result.held[card.id] = held
		if card.id in baseline_ids:
			private_origins[origin] = true
	var public_factors = Public.factors(view)
	var speech_factors = Speech.factors(cards)
	var private_speech = Speech.factors(cards.filter(func(card): return card.id in baseline_ids))
	for item in states:
		var state: PackedByteArray = item.state
		if not subsets.has(state):
			var materialized = Channels.materialize(plan, state)
			var private_cards: Array = []
			# Materialize private evidence independently so an implied gift claim or
			# Medium visit survives exactly when its private statement supports it.
			var private_plan = plan.duplicate(false)
			private_plan.statements = plan.statements.filter(func(statement): return statement.card.id in baseline_ids)
			private_cards = Channels.materialize(private_plan, state).cards
			var solved = _conditional(view, materialized.cards, knowledge, cache[key].solves)
			var prior = _conditional(view, private_cards, knowledge, cache[key].solves)
			var factors: Array = solved.factors.duplicate()
			factors.append_array(public_factors)
			factors.append_array(speech_factors)
			var private_factors: Array = prior.factors.duplicate()
			private_factors.append_array(private_speech)
			subsets[state.duplicate()] = {"accurate": materialized.accurate, "private_accurate": Channels.materialize(private_plan, state).accurate, "accepted": solved.allowed, "allowed": prior.allowed,
				"factors": factors, "private_factors": private_factors}
		var subset: Dictionary = subsets[state]
		var accurate = {}
		for id in subset.accurate:
			if origins.has(id):
				accurate[origins[id]] = true
		var false_content = 1.0
		var false_private = 1.0
		var private_accurate = {}
		for id in subset.private_accurate:
			if origins.has(id):
				private_accurate[origins[id]] = true
		var priced = {}
		for id in origins:
			var origin: String = origins[id]
			if priced.has(origin):
				continue
			priced[origin] = true
			var likelihood: float = float(q.get(origin, q.get(id, 1.0))) if report_origins.has(origin) else 1.0
			assert(is_finite(likelihood) and likelihood >= 0.0 and likelihood <= 1.0)
			if not accurate.has(origin):
				false_content *= likelihood
			if private_origins.has(origin) and not private_accurate.has(origin):
				false_private *= likelihood
		for slot in range(size):
			var i: int = slot if representatives.is_empty() else representatives[slot]
			var world: Dictionary = universe[i]
			var weight = 1.0
			for index in range(plan.channels.size()):
				if state[index] == 255:
					continue
				var channel: Dictionary = plan.channels[index]
				var rate = rates[channel.key]
				var probability: float = Channels.probability(view, world, channel, rate)
				assert(is_finite(probability) and probability >= 0.0 and probability <= 1.0)
				weight *= probability if state[index] == 1 else 1.0 - probability
				if weight == 0.0:
					break
			if weight == 0.0:
				continue
			if subset.allowed.has(i):
				base[slot] += weight * false_private * _movement(view, world, subset.private_factors)
			if subset.accepted.has(i):
				var likelihood: float = weight * false_content * _movement(view, world, subset.factors)
				post[slot] += likelihood
				for id in subset.accurate:
					totals[id] = totals.get(id, 0.0) + likelihood * (1.0 if multiplicity.is_empty() else multiplicity[slot])
					if result.held.has(id):
						result.held[id][slot] += likelihood
				if subset.accurate.size() == origins.size():
					result.consistent = true
		result.states += 1
	var total = 0.0
	for slot in range(size):
		total += post[slot] * (1.0 if multiplicity.is_empty() else multiplicity[slot])
	for id in origins:
		result.acceptance[id] = totals.get(id, 0.0) / total if total > 0.0 else 0.0
	result.base = base
	result.post = post
	return result

static func _conditional(view: Dictionary, cards: Array, knowledge: Dictionary, solves: Dictionary) -> Dictionary:
	var key = hash(cards)
	if solves.has(key) and solves[key].cards == cards:
		return solves[key]
	var universe: Array = Solver.universe(view)
	var solved = Solver.solve(view, cards, {}, {}, knowledge)
	var allowed = {}
	for world in solved.worlds if solved.movement_ok else []:
		allowed[world.__i if world.has("__i") else universe.find(world)] = true
	var factors: Array = Movement.factors(view, cards, {}).duplicate()
	solves[key] = {"cards": cards.duplicate(true), "allowed": allowed, "factors": factors}
	return solves[key]

static func _movement(view: Dictionary, world: Dictionary, factors: Array) -> float:
	var score = 1.0
	for factor in factors:
		if factor.get("joint_live", false):
			score *= Movement.Live.score(world, factor)
		elif Solver.TimeModel.evil_at(view, world, factor.target, factor.get("epoch", view.alignment_epoch)):
			score *= pow(2.0, float(factor.log2_ratio))
	return score
