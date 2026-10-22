## Experimental mixture over shared credibility assumptions, not calibrated probabilities.
## A false accuracy assumption removes a constraint; it never negates the report.
extends RefCounted

const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Movement = preload("res://workshop/movement_model.gd")
const TimeModel = preload("res://workshop/chronology.gd")
static var cache: Dictionary = {}
static var comparisons: Dictionary = {}

static func assess(view: Dictionary, value: Dictionary, listener: Dictionary, bias: Dictionary = {}, prepared: Dictionary = {}) -> Dictionary:
	var case_data = Graph.compile_case(view, value)
	var bounded: bool = listener.get("reasoning_mode", "full") == "bounded"
	var attention = Reasoner.prepare(view, value, listener) if prepared.is_empty() else prepared
	if bounded or case_data.conclusion.type == "conflict" or not prepared.is_empty():
		case_data = attention.case
	var cards: Array = Solver.selected(view, case_data)
	var factor_refs: Array = []
	factor_refs.append_array(Movement.claim_refs(view, case_data))
	for factor in case_data.test_factors:
		if not is_zero_approx(float(factor.log2_ratio)):
			for route in factor.routes:
				factor_refs.append_array(route)
	# A role assertion alone supplies no alignment constraint. Avoid enumerating
	# irrelevant reliability dimensions for optional claims with no test factor.
	cards = cards.filter(func(c): return c.kind != "claim" or c.id in factor_refs)
	var presented_reading: bool = cards.any(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"])
	for id in listener.knowledge.get("own_reports", []):
		var card = Solver.card_by_id(view, id)
		if not cards.any(func(c): return Solver.semantic_key(c) == Solver.semantic_key(card)):
			cards.append(card)
	var atoms: Array = []
	var requirements = {}
	var fault_controls = {}
	for card in cards:
		var required: Array = []
		if card.get("quoted", false):
			requirements[card.id] = required
			continue # Known testimony exists; its disputed contents are not endorsed.
		if card.id in attention.private_checks.rejected:
			var known_key: String = "firsthand:" + Solver.semantic_key(card)
			_add_atom(atoms, known_key, 0.0)
			required.append(known_key)
		var source_key: String = TimeModel.source_key(view, card)
		_add_atom(atoms, source_key, source_quality(listener, card.source))
		required.append(source_key)
		if card.kind == "report":
			if TimeModel.disowned(view, card, listener.knowledge.get("known_events", [])):
				_add_atom(atoms, "withdrawn:" + card.id, 0.0)
				required.append("withdrawn:" + card.id)
			var fault = TimeModel.fault_for(view, case_data, card)
			if not fault.is_empty() and fault.basis in case_data.cards:
				var basis = Solver.card_by_id(view, fault.basis)
				if basis.get("kind") == "fault_evidence" and basis.get("window") in case_data.get("faults", {}):
					var basis_key: String = TimeModel.source_key(view, basis)
					_add_atom(atoms, basis_key, source_quality(listener, basis.source))
					_add_atom(atoms, fault.key, 0.5)
					required.append(fault.key)
					fault_controls[fault.key] = basis_key
			var accuracy_key: String = "accuracy:" + card.get("accuracy_origin", Solver.semantic_key(card))
			_add_atom(atoms, accuracy_key, float(listener.get("reading_reliability", {}).get(card.get("accuracy_origin", Solver.semantic_key(card)), 1.0)))
			required.append(accuracy_key)
		requirements[card.id] = required
	var uncertain: Array = atoms.filter(func(a): return a.weight > 0.0 and a.weight < 1.0)
	var total = 0.0
	var agreement = 0.0
	var evidence_agreement = 0.0
	var conditional_mass = 0.0
	var forced_mass = 0.0
	var accuracy = {}
	for card in cards:
		accuracy[card.id] = 0.0
	var paths: Array = []
	var used_factors: Array = []
	var strongest = 0.0
	var states = 0
	var impossible = 0.0
	var ranks = prior_scores(view, listener, bias, case_data.conclusion.at)
	# The comparison starts with the listener's private reports, not an empty mind.
	# Removing the public evidence must remove its effect, including effects on
	# people who were never named in the player's conclusion.
	for mask in range(1 << uncertain.size()):
		var weight = 1.0
		var accepted = {}
		for atom in atoms:
			accepted[atom.key] = atom.weight >= 1.0
		for i in range(uncertain.size()):
			var atom: Dictionary = uncertain[i]
			var yes: bool = (mask & (1 << i)) != 0
			accepted[atom.key] = yes
			weight *= atom.weight if yes else (1.0 - atom.weight)
		if weight <= 0.0:
			continue
		for healthy in fault_controls:
			if not accepted[fault_controls[healthy]]:
				accepted[healthy] = true
		var active: Array = cards.filter(func(c): return requirements[c.id].all(func(key): return accepted[key]))
		var private_cards: Array = active.filter(func(c): return c.id in listener.knowledge.get("own_reports", []))
		var private_worlds: Array = _solve(view, private_cards, listener.knowledge).worlds
		var solved = {}
		var searched = {}
		if bounded:
			searched = Reasoner.search(view, case_data, active, listener, attention.limits)
		else:
			solved = _solve(view, active, listener.knowledge)
		states += 1
		if (bounded and searched.status == "inconsistent") or (not bounded and (solved.worlds.is_empty() or not solved.movement_ok)):
			impossible += weight
			continue
		total += weight
		for card in active:
			accuracy[card.id] = accuracy.get(card.id, 0.0) + weight
		var factors: Array = case_data.test_factors.filter(func(f): return not is_zero_approx(float(f.log2_ratio)) and f.routes.any(func(route): return route.all(func(id): return active.any(func(c): return Solver.semantic_key(c) == Solver.semantic_key(Solver.card_by_id(view, id))))))
		factors.append_array(Movement.factors(view, active, case_data))
		for factor in factors:
			factor["epoch"] = case_data.conclusion.at
		for factor in factors:
			if factor.label not in used_factors and not is_zero_approx(float(factor.log2_ratio)):
				used_factors.append(factor.label)
		var contributing: Array = active.filter(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"])
		var a = 0.0
		var comparison: Dictionary = {} if bounded else _comparison(view, solved.worlds, case_data.conclusion, factors, ranks)
		var all_hold: bool = searched.status == "entailed_in_attention" if bounded else comparison.support > 0.0 and comparison.rival == 0.0
		var any_hold: bool = not searched.support.is_empty() if bounded else comparison.support > 0.0
		if all_hold and presented_reading:
			a = 1.0
			forced_mass += weight
			var path: Array = contributing.map(func(c): return c.id)
			path.sort()
			if not paths.has(path):
				paths.append(path)
		elif any_hold and ((presented_reading and not contributing.is_empty()) or not factors.is_empty()):
			if bounded and searched.status == "provisional":
				var ratio = _direct_ratio(factors, case_data.conclusion)
				if contributing.is_empty():
					a = (2.0 if Movement.available(view) else 0.16) * (ratio / (1.0 + ratio) - 0.5)
				else:
					a = minf(0.95, (0.76 if contributing.size() >= 2 else 0.3) * 2.0 * ratio / (1.0 + ratio))
				if not bias.is_empty() and not Solver.position_holds(view, searched.support, bias.target, bias.position, case_data.conclusion.at):
					a /= bias.factor
			elif bounded:
				a = possibility(view, [searched.support, searched.rival], case_data.conclusion, listener, factors, ranks)
			else:
				a = possibility(view, solved.worlds, case_data.conclusion, listener, factors, ranks)
			if Movement.available(view) and not (bounded and searched.status == "provisional") and factors.any(func(f): return f.get("origin") == "movement_model"):
				# Soft evidence can persuade without logically eliminating a rival.
				# Only the CHANGE in preference adds conviction; irrelevant factors
				# cannot promote a merely possible accusation into a stronger tier.
				var candidates: Array = [searched.support] + ([] if searched.rival.is_empty() else [searched.rival]) if bounded else solved.worlds
				var preferred = _comparison(view, candidates, case_data.conclusion, factors, ranks)
				var reference_factors: Array = factors.filter(func(f): return f.get("origin") != "movement_model")
				var neutral = _comparison(view, candidates, case_data.conclusion, reference_factors, ranks)
				var shift: float = preferred.support / maxf(preferred.support + preferred.rival, 1e-12) - neutral.support / maxf(neutral.support + neutral.rival, 1e-12)
				a = clampf(a + 2.0 * shift, -1.0, 1.0)
			if contributing.is_empty() and not (bounded and searched.status == "provisional"):
				# A factor about someone else that does not distinguish this conclusion
				# must not create the generic 'possible accusation' tier by its presence.
				var candidates: Array = [searched.support] + ([] if searched.rival.is_empty() else [searched.rival]) if bounded else solved.worlds
				a -= possibility(view, candidates, case_data.conclusion, listener, [], ranks)
			var positions: Dictionary = case_data.positions.duplicate(true)
			positions.erase(case_data.conclusion.target)
			var answers: Dictionary = case_data.answers.duplicate(true)
			if case_data.conclusion.type == "marked":
				for card in contributing:
					if card.role == "rumormonger":
						answers.erase(card.id)
			if not positions.is_empty() or not answers.is_empty() or not case_data.get("temporal_positions", []).is_empty():
				var conditional = false
				if bounded:
					conditional = not searched.support.is_empty()
				else:
					var chosen = Solver.solve(view, active, positions, answers, listener.knowledge, case_data.conclusion.at, case_data.get("temporal_positions", []))
					conditional = not chosen.worlds.is_empty() and chosen.worlds.all(func(w): return Solver.holds(view, w, case_data.conclusion))
				if conditional:
					a = maxf(a, 0.4)
					conditional_mass += weight
		agreement += weight * a
		var reference = 0.0
		if presented_reading and not contributing.is_empty() and not private_worlds.is_empty():
			var prior = _comparison(view, private_worlds, case_data.conclusion, [], ranks)
			if prior.support > 0 and prior.rival == 0:
				reference = 1.0
			elif prior.support > 0:
				reference = 0.02 + 0.16 * prior.support / maxf(prior.support + prior.rival, 0.000000000001)
		evidence_agreement += weight * (a - reference)
		strongest = maxf(strongest, weight * a)
	var minimal: Array = []
	for path in paths:
		if not paths.any(func(other): return other.size() < path.size() and other.all(func(id): return id in path)):
			minimal.append(path)
	minimal.sort_custom(func(a, b): return str(a) < str(b))
	if total > 0.0:
		agreement /= total
		evidence_agreement /= total
		forced_mass /= total
		conditional_mass /= total
		for id in accuracy:
			accuracy[id] /= total
	return {"agreement": agreement, "evidence_agreement": evidence_agreement, "forced_mass": forced_mass, "conditional_mass": conditional_mass,
		"movement_comparison": Movement.factors(view, cards.filter(func(c): return c.get("quoted", false) or source_quality(listener, c.source) >= 0.4), case_data),
		"paths": minimal, "report_acceptance": accuracy, "atoms": atoms, "states": states,
		"quoted_cards": cards.filter(func(card): return card.get("quoted", false)).map(func(card): return card.id),
		"faults": fault_controls.keys(),
		"conflict_mass": impossible, "strongest_state": strongest, "factors": used_factors,
		"model": "Experimental shared route/activity/haunt likelihood. Conviction adds twice the preference shift; signed alignment is capped before social multipliers. Profile priors and conviction tuning are uncalibrated; conditional trace/drop mechanisms are tested against the generator." if Movement.available(view) else "Experimental credibility-state mixture. Supplied test factors and the fixed 2x challenged-alibi factor are uncalibrated; no general movement/trace likelihood is inferred."}

static func explain(view: Dictionary, value: Dictionary, listener: Dictionary, prepared: Dictionary = {}) -> Dictionary:
	var attention = Reasoner.prepare(view, value, listener) if prepared.is_empty() else prepared
	var considered = attention.case
	var cards = Solver.selected(view, considered)
	for id in listener.knowledge.get("own_reports", []):
		if not cards.any(func(c): return c.id == id):
			cards.append(Solver.card_by_id(view, id))
	var accepted: Array = cards.filter(func(c): return not TimeModel.disowned(view, c, listener.knowledge.get("known_events", [])) and (c.get("quoted", false) or (c.id not in attention.private_checks.rejected and source_quality(listener, c.source) >= 0.4 and (c.kind != "report" or listener.reading_reliability.get(c.get("accuracy_origin", Solver.semantic_key(c)), 1.0) >= 0.5))))
	var limits: Dictionary = attention.limits if listener.get("reasoning_mode", "full") == "bounded" else {"support": 840, "rivals": 840, "complete": true}
	var result = Reasoner.search(view, considered, accepted, listener, limits)
	result.merge(attention)
	result.erase("case")
	result["accepted"] = accepted.map(func(c): return c.id)
	result["doubted"] = cards.filter(func(c): return c not in accepted).map(func(c): return c.id)
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
	return clampf(0.2 + 0.65 * listener.npc_trust.get(source, 0.5) - 0.35 * listener.suspicion.get(source, 0.1), 0.05, 0.95)

static func _direct_ratio(factors: Array, conclusion: Dictionary) -> float:
	if conclusion.type not in ["evil", "good", "suspicious"]:
		return 1.0
	var exponent = 0.0
	for factor in factors:
		if factor.target == conclusion.target:
			exponent += float(factor.log2_ratio) * (-1.0 if conclusion.type == "good" else 1.0)
	return pow(2.0, exponent)

static func _add_atom(atoms: Array, key: String, weight: float) -> void:
	if not atoms.any(func(a): return a.key == key):
		atoms.append({"key": key, "weight": weight})

static func _solve(view: Dictionary, cards: Array, knowledge: Dictionary) -> Dictionary:
	# Hash lookup plus exact input comparison avoids rebuilding JSON signatures in
	# every credibility state / character projection. Equality guards collisions.
	var inputs = [view.people, view.evil_count, view.get("chronology", {}), cards, knowledge]
	var key = hash(inputs)
	if cache.has(key) and cache[key].inputs == inputs:
		return cache[key].result
	if cache.size() > 512:
		cache.clear()
	var solved = Solver.solve(view, cards, {}, {}, knowledge)
	cache[key] = {"inputs": inputs.duplicate(true), "result": solved}
	return solved

static func prior_scores(view: Dictionary, listener: Dictionary, bias: Dictionary = {}, epoch: String = "") -> Dictionary:
	var ranks = {}
	for world in _solve(view, [], listener.knowledge).worlds:
		var score = 1.0
		for i in range(view.people.size()):
			var id: String = view.people[i].id
			var suspicion: float = listener.suspicion.get(id, 0.1)
			var trust: float = listener.npc_trust.get(id, 0.5)
			if TimeModel.evil_index(view, world, i, view.alignment_epoch if epoch == "" else epoch):
				score *= maxf(0.15 + suspicion * 1.2 - (trust - 0.5) * 0.5, 0.02)
			else:
				score *= maxf(0.3 + (0.6 - suspicion) * 0.6 + (trust - 0.5) * 0.4, 0.05)
		if not bias.is_empty() and Solver.position_holds(view, world, bias.target, bias.position, epoch):
			score *= bias.factor
		ranks[TimeModel.key(view, world)] = score
	return ranks

static func world_score(view: Dictionary, world: Dictionary, ranks: Dictionary, factors: Array) -> float:
	if world.is_empty():
		return 0.0
	var score: float = ranks.get(TimeModel.key(view, world), 0.0)
	for factor in factors:
		var target: int = view.people.map(func(p): return p.id).find(factor.target)
		if target >= 0 and TimeModel.evil_at(view, world, factor.target, factor.get("epoch", view.alignment_epoch)):
			score *= pow(2.0, float(factor.log2_ratio))
		elif target >= 0 and factor.get("origin", "") == "movement_model" and world.marked == target:
			score *= maxf(factor.good_marked_likelihood, 1e-12) / maxf(factor.good_likelihood, 1e-12)
	return score

static func possibility(view: Dictionary, worlds: Array, conclusion: Dictionary, listener: Dictionary, factors: Array = [], ranks: Dictionary = {}) -> float:
	if ranks.is_empty():
		ranks = prior_scores(view, listener)
	var comparison = _comparison(view, worlds, conclusion, factors, ranks)
	return 0.02 + 0.16 * comparison.support / maxf(comparison.support + comparison.rival, 0.000000000001)

static func _comparison(view: Dictionary, worlds: Array, conclusion: Dictionary, factors: Array, ranks: Dictionary) -> Dictionary:
	# One set of ranked worlds answers all characters' alignment/Marked questions.
	# This cache only speeds the full/mixture calculation; bounded searches still
	# construct their own candidates and never receive unseen public worlds.
	var inputs = [view.people, view.get("chronology", {}), worlds, factors, ranks, conclusion.at]
	var key = hash(inputs)
	if not comparisons.has(key) or comparisons[key].inputs != inputs:
		if comparisons.size() > 512:
			comparisons.clear()
		var scores: Array = []
		for i in range(view.people.size()):
			scores.append({"evil": 0.0, "good": 0.0, "marked": 0.0, "unmarked": 0.0})
		for world in worlds:
			if world.is_empty():
				continue
			var score = world_score(view, world, ranks, factors)
			for i in range(scores.size()):
				var alignment: String = "evil" if TimeModel.evil_index(view, world, i, conclusion.at) else "good"
				var registration: String = "marked" if world.marked == i else "unmarked"
				scores[i][alignment] = maxf(scores[i][alignment], score)
				scores[i][registration] = maxf(scores[i][registration], score)
		comparisons[key] = {"inputs": inputs, "scores": scores}
	var index: int = view.people.map(func(p): return p.id).find(conclusion.target)
	if index < 0 or conclusion.type == "conflict":
		return {"support": 0.0, "rival": 0.0}
	var scores: Dictionary = comparisons[key].scores[index]
	var type: String = "evil" if conclusion.type == "suspicious" else conclusion.type
	var opposite: String = {"evil": "good", "good": "evil", "marked": "unmarked"}[type]
	return {"support": scores[type], "rival": scores[opposite]}
