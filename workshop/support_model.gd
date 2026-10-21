## Experimental mixture over shared credibility assumptions, not calibrated probabilities.
## A false accuracy assumption removes a constraint; it never negates the report.
extends RefCounted

const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
static var cache: Dictionary = {}

static func assess(view: Dictionary, value: Dictionary, listener: Dictionary) -> Dictionary:
	var case_data = Graph.compile_case(view, value)
	var cards: Array = Solver.selected(view, case_data)
	var factor_refs: Array = []
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
	for card in cards:
		var required: Array = []
		var source_key: String = "source:" + card.source
		_add_atom(atoms, source_key, source_quality(listener, card.source))
		required.append(source_key)
		if card.kind == "report":
			var accuracy_key: String = "accuracy:" + Solver.semantic_key(card)
			_add_atom(atoms, accuracy_key, float(listener.get("reading_reliability", {}).get(Solver.semantic_key(card), 1.0)))
			required.append(accuracy_key)
		requirements[card.id] = required
	var uncertain: Array = atoms.filter(func(a): return a.weight > 0.0 and a.weight < 1.0)
	var total = 0.0
	var agreement = 0.0
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
	var ranks = prior_scores(view, listener)
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
		var active: Array = cards.filter(func(c): return requirements[c.id].all(func(key): return accepted[key]))
		var solved = _solve(view, active, listener.knowledge)
		states += 1
		if solved.worlds.is_empty() or not solved.movement_ok:
			impossible += weight
			continue
		total += weight
		for card in active:
			accuracy[card.id] = accuracy.get(card.id, 0.0) + weight
		var factors: Array = case_data.test_factors.filter(func(f): return not is_zero_approx(float(f.log2_ratio)) and f.routes.any(func(route): return route.all(func(id): return active.any(func(c): return Solver.semantic_key(c) == Solver.semantic_key(Solver.card_by_id(view, id))))))
		for factor in factors:
			if factor.label not in used_factors and not is_zero_approx(float(factor.log2_ratio)):
				used_factors.append(factor.label)
		var contributing: Array = active.filter(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"])
		var a = 0.0
		var all_hold: bool = solved.worlds.all(func(w): return Solver.holds(view, w, case_data.conclusion))
		var any_hold: bool = solved.worlds.any(func(w): return Solver.holds(view, w, case_data.conclusion))
		if all_hold and presented_reading:
			a = 1.0
			forced_mass += weight
			var path: Array = contributing.map(func(c): return c.id)
			path.sort()
			if not paths.has(path):
				paths.append(path)
		elif any_hold and ((presented_reading and not contributing.is_empty()) or not factors.is_empty()):
			a = possibility(view, solved.worlds, case_data.conclusion, listener, factors, ranks)
			if contributing.is_empty():
				# A factor about someone else that does not distinguish this conclusion
				# must not create the generic 'possible accusation' tier by its presence.
				a -= possibility(view, solved.worlds, case_data.conclusion, listener, [], ranks)
			var positions: Dictionary = case_data.positions.duplicate(true)
			positions.erase(case_data.conclusion.target)
			var answers: Dictionary = case_data.answers.duplicate(true)
			if case_data.conclusion.type == "marked":
				for card in contributing:
					if card.role == "rumormonger":
						answers.erase(card.id)
			if not positions.is_empty() or not answers.is_empty():
				var chosen = Solver.solve(view, active, positions, answers, listener.knowledge)
				if not chosen.worlds.is_empty() and chosen.worlds.all(func(w): return Solver.holds(view, w, case_data.conclusion)):
					a = maxf(a, 0.4)
					conditional_mass += weight
		agreement += weight * a
		strongest = maxf(strongest, weight * a)
	var minimal: Array = []
	for path in paths:
		if not paths.any(func(other): return other.size() < path.size() and other.all(func(id): return id in path)):
			minimal.append(path)
	minimal.sort_custom(func(a, b): return str(a) < str(b))
	if total > 0.0:
		agreement /= total
		forced_mass /= total
		conditional_mass /= total
		for id in accuracy:
			accuracy[id] /= total
	return {"agreement": agreement, "forced_mass": forced_mass, "conditional_mass": conditional_mass,
		"paths": minimal, "report_acceptance": accuracy, "atoms": atoms, "states": states,
		"conflict_mass": impossible, "strongest_state": strongest, "factors": used_factors,
		"model": "Experimental credibility-state mixture; weights are uncalibrated. Test factors are supplied inputs, not movement likelihoods."}

static func source_quality(listener: Dictionary, source: String) -> float:
	if source == listener.id:
		return 1.0
	if source == "player":
		return 0.9
	return clampf(0.2 + 0.65 * listener.npc_trust.get(source, 0.5) - 0.35 * listener.suspicion.get(source, 0.1), 0.05, 0.95)

static func _add_atom(atoms: Array, key: String, weight: float) -> void:
	if not atoms.any(func(a): return a.key == key):
		atoms.append({"key": key, "weight": weight})

static func _solve(view: Dictionary, cards: Array, knowledge: Dictionary) -> Dictionary:
	var signatures: Array = cards.map(func(c): return JSON.stringify([Solver.semantic_key(c), c.kind, c.source, c.get("role"), c.get("night"), c.get("block"), c.get("subject"), c.get("observed_at"), c.get("data", {})]))
	signatures.sort()
	var key = JSON.stringify([view.people, view.evil_count, signatures, knowledge.get("good", [])])
	if not cache.has(key):
		if cache.size() > 512:
			cache.clear()
		cache[key] = Solver.solve(view, cards, {}, {}, knowledge)
	return cache[key]

static func prior_scores(view: Dictionary, listener: Dictionary) -> Dictionary:
	var ranks = {}
	for world in _solve(view, [], listener.knowledge).worlds:
		var score = 1.0
		for i in range(view.people.size()):
			var id: String = view.people[i].id
			var suspicion: float = listener.suspicion.get(id, 0.1)
			var trust: float = listener.npc_trust.get(id, 0.5)
			if world.evil & (1 << i):
				score *= maxf(0.15 + suspicion * 1.2 - (trust - 0.5) * 0.5, 0.02)
			else:
				score *= maxf(0.3 + (0.6 - suspicion) * 0.6 + (trust - 0.5) * 0.4, 0.05)
		ranks[world.evil * view.people.size() + world.marked] = score
	return ranks

static func possibility(view: Dictionary, worlds: Array, conclusion: Dictionary, listener: Dictionary, factors: Array = [], ranks: Dictionary = {}) -> float:
	if ranks.is_empty():
		ranks = prior_scores(view, listener)
	var supporting = 0.0
	var rival = 0.0
	for world in worlds:
		var score: float = ranks.get(world.evil * view.people.size() + world.marked, 0.0)
		for factor in factors:
			var target: int = view.people.map(func(p): return p.id).find(factor.target)
			if target >= 0 and world.evil & (1 << target):
				score *= pow(2.0, float(factor.log2_ratio))
		if Solver.holds(view, world, conclusion):
			supporting = maxf(supporting, score)
		else:
			rival = maxf(rival, score)
	return 0.02 + 0.16 * supporting / maxf(supporting + rival, 0.000000000001)
