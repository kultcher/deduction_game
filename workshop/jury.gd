## Public-case interpretation -> assessment -> replaceable ledger effect -> response.
## Deliberately keeps the existing game's trust/suspicion/confidence/stance vocabulary.
## This is a workshop adapter, not a balance change to Mind or Argue.
extends RefCounted

const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const Support = preload("res://workshop/support_model.gd")

static func evaluate(view: Dictionary, case_data: Dictionary, listener: Dictionary, context: Dictionary = {}) -> Dictionary:
	var original = case_data.duplicate(true)
	case_data = Graph.compile_case(view, case_data)
	var conclusion: Dictionary = case_data.conclusion
	var target: String = conclusion.target
	var before_suspicion: float = listener.suspicion.get(target, 0.1)
	var before_trust: float = listener.trust
	var old: Dictionary = listener.ledger.get(case_data.id, {})
	# Assess from the baseline without this case's own previous persuasion. Otherwise
	# accusing a witness would lower their credibility on every repetition.
	if not old.is_empty():
		listener.suspicion[old.target] = snappedf(listener.suspicion.get(old.target, 0.1) - old.applied, 0.000000001)
	var knowledge: Dictionary = listener.knowledge
	var full_case = case_data.duplicate(true)
	for id in knowledge.get("own_reports", []):
		if id not in full_case.cards:
			full_case.cards.append(id)
	var assessment = Solver.analyze(view, full_case, knowledge)
	var shared = Solver.analyze(view, case_data)
	var overall = Solver.solve(view, Solver.selected(view, full_case), {}, {}, knowledge)
	var logical_cards: Array = Solver.selected(view, case_data).filter(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"])
	var best = {"weight": 0.0, "agreement": 0.0, "quality": 0.0, "cards": [], "kind": "none"}
	# Consider independent support paths. Adding an optional premise cannot erase an
	# already valid smaller path; a contradiction in the asserted case can reopen it.
	for mask in range(1, 1 << logical_cards.size()):
		var path: Array = []
		for i in range(logical_cards.size()):
			if mask & (1 << i):
				path.append(logical_cards[i].id)
		var subcase = Solver.empty_case()
		subcase.cards = path.duplicate()
		subcase.conclusion = conclusion
		for id in knowledge.get("own_reports", []):
			if id not in subcase.cards:
				subcase.cards.append(id)
		var analysis = Solver.analyze(view, subcase, knowledge)
		var agreement = 1.0 if analysis.entailment == "forced" else 0.0
		if analysis.entailment == "possible":
			agreement = _possibility_agreement(view, overall.worlds, conclusion, listener)
		if conclusion.type == "conflict":
			agreement = 0.0 # handled using the whole asserted set below
		var quality = _quality(view, path, listener)
		var weight = agreement * quality
		if weight > best.weight:
			best = {"weight": weight, "agreement": agreement, "quality": quality, "cards": path, "kind": "reading"}
		if shared.entailment == "possible" and conclusion.type != "conflict":
			var positions: Dictionary = case_data.positions.duplicate(true)
			positions.erase(target)
			var answers: Dictionary = case_data.answers.duplicate(true)
			if conclusion.type == "marked":
				for id in answers.keys():
					if Solver.card_by_id(view, id).get("role", "") == "rumormonger":
						answers.erase(id)
			var conditional_path = Solver.solve(view, Solver.selected(view, subcase), positions, answers, knowledge)
			if not conditional_path.worlds.is_empty() and conditional_path.worlds.all(func(w): return Solver.holds(view, w, conclusion)):
				if 0.4 * quality > best.weight:
					best = {"weight": 0.4 * quality, "agreement": 0.4, "quality": quality, "cards": path, "kind": "conditional"}
	var pattern = _pattern(view, case_data, listener)
	var legacy = best.duplicate(true)
	var combined = Support.assess(view, original, listener)
	var paths: Array = []
	for path in combined.paths:
		for id in path:
			if id not in paths:
				paths.append(id)
	if paths.is_empty():
		paths = logical_cards.map(func(c): return c.id)
	best = {"weight": combined.agreement, "agreement": combined.agreement, "quality": 1.0,
		"cards": paths, "kind": "conditional" if combined.conditional_mass > combined.forced_mass else "reading"}
	if conclusion.type == "suspicious" and pattern.weight > best.weight:
		best = pattern
	var conflict = assessment.status == "conflicting"
	if conclusion.type == "conflict":
		var agreement = 1.0 if shared.entailment == "forced" else 0.0
		best = {"weight": agreement * _quality(view, case_data.cards, listener), "agreement": agreement, "quality": _quality(view, case_data.cards, listener), "cards": case_data.cards, "kind": "conflict"}
	elif not assessment.errors.is_empty() or (assessment.proposed == 0 and assessment.compatible > 0):
		best.weight = 0.0
		best.agreement = 0.0
	var player_factor: float = 0.5 + listener.trust
	var confidence_factor: float = 1.4 - 0.8 * listener.confidence
	# Venue is deliberately the same: no private/public/nomination duplicate effects.
	var strength: float = best.weight * player_factor * confidence_factor
	var coefficient: float = {"evil": 0.45, "good": -0.4, "marked": -0.1, "suspicious": 0.3, "conflict": 0.0}.get(conclusion.type, 0.0)
	var effect: float = strength * coefficient
	var previous: Dictionary = listener.case_memory.get(case_data.id, {})
	var signature = _signature(view, case_data)
	var repeated: bool = previous.get("signature", "") == signature
	# Replace this case's complete prior effect, even if target/conclusion changed.
	var baseline: float = listener.suspicion.get(target, 0.1)
	listener.suspicion[target] = snappedf(clampf(baseline + effect, 0.0, 1.5), 0.000000001)
	var applied: float = snappedf(listener.suspicion[target] - baseline, 0.000000001)
	listener.ledger[case_data.id] = {"target": target, "applied": applied, "cards": best.cards.duplicate(), "version": case_data.version,
		"conclusion": conclusion.duplicate(true), "signature": signature, "report_acceptance": combined.report_acceptance.duplicate(true)}
	# No recurring trust reward for restating a case. Workshop trust is a controlled input.
	var changes = _changes(view, previous.get("case", {}), case_data)
	listener.case_memory[case_data.id] = {"signature": signature, "version": case_data.version, "cards": case_data.cards.duplicate(), "strength": strength, "case": case_data.duplicate(true)}
	var objection = _objection(view, case_data, listener, shared, assessment, best, pattern)
	var stance = "accept" if best.agreement >= 0.6 else ("partial" if best.agreement >= 0.35 else "reject")
	var delta: float = listener.suspicion[target] - before_suspicion
	var response = ""
	if repeated:
		response = "That is the same case. Repeating it adds no new reason."
	elif conclusion.type == "conflict":
		response = "Those accounts cannot all be accurate. I have reopened which report to believe; this does not establish anyone's alignment." if shared.entailment == "forced" else "I don't see a conflict among the reports you selected."
	elif best.kind == "pattern" and best.weight > 0:
		response = "That gives me a reason to be suspicious, though it does not establish evil."
	elif conflict and conclusion.type != "conflict":
		response = "I cannot accept all those premises together. I give weight only to the explanations that survive doubting a report." if best.weight > 0 else "Those premises or choices do not fit together. I have withdrawn this case's earlier weight."
	elif best.kind == "conditional":
		response = "That follows if I grant your extra choices. You still need to establish those choices."
	elif stance == "accept":
		response = "The conclusion follows if those reports are sound. My doubt is in the premises."
	elif combined.agreement < 0:
		response = "The supplied evidence makes me less suspicious of this person."
	elif assessment.entailment == "forced":
		response = "The inference follows if the reports are accurate. I give it some weight, but I still doubt the supporting reports."
	else:
		response = "I can see that possibility, but the reports also allow another explanation."
	if not combined.factors.is_empty():
		response += " The supplied test factor changes which remaining explanation I favor; it does not prove it."
	if not previous.is_empty() and not repeated and not changes.is_empty():
		response += " " + " ".join(PackedStringArray(changes))
	return {"listener": listener.id, "name": listener.name, "version": case_data.version, "stance": stance,
		"agreement": best.agreement, "quality": best.quality, "strength": strength, "path": best.cards,
		"path_kind": best.kind, "repeated": repeated, "response": response, "objection": objection, "changes": changes,
		"assessment": assessment, "shared_assessment": shared, "pattern": pattern, "support_model": combined, "legacy_path": legacy,
		"before_suspicion": before_suspicion, "after_suspicion": listener.suspicion[target], "suspicion_delta": delta,
		"before_trust": before_trust, "after_trust": listener.trust, "trust_delta": 0.0,
		"calculation": {"agreement": best.agreement, "premise_quality": best.quality, "player_factor": player_factor,
			"confidence_factor": confidence_factor, "coefficient": coefficient, "old_case_effect": old.get("applied", 0.0), "new_case_effect": applied,
			"venue": context.get("venue", "private"), "rule": "Replace this case's prior effect; never add it again. Trust is held fixed for controlled comparisons."}}

static func _quality(view: Dictionary, ids: Array, listener: Dictionary) -> float:
	var sources: Array = []
	var quality = 1.0
	for id in ids:
		var card = Solver.card_by_id(view, id)
		if card.is_empty():
			continue
		var source: String = card.source
		if source == listener.id or source in sources:
			continue
		sources.append(source)
		if source == "player":
			quality *= 0.9
		else:
			quality *= clampf(0.2 + 0.65 * listener.npc_trust.get(source, 0.5) - 0.35 * listener.suspicion.get(source, 0.1), 0.05, 0.95)
	return quality

static func _possibility_agreement(view: Dictionary, worlds: Array, conclusion: Dictionary, listener: Dictionary) -> float:
	# Compare the listener's strongest supporting and rival explanations, as Argue
	# does. This is an uncalibrated disposition score, not a fraction of worlds.
	var supporting = 0.0
	var rival = 0.0
	for world in worlds:
		var score = 1.0
		for i in range(view.people.size()):
			var id: String = view.people[i].id
			var suspicion: float = listener.suspicion.get(id, 0.1)
			var trust: float = listener.npc_trust.get(id, 0.5)
			if world.evil & (1 << i):
				score *= maxf(0.15 + suspicion * 1.2 - (trust - 0.5) * 0.5, 0.02)
			else:
				score *= maxf(0.3 + (0.6 - suspicion) * 0.6 + (trust - 0.5) * 0.4, 0.05)
		if Solver.holds(view, world, conclusion):
			supporting = maxf(supporting, score)
		else:
			rival = maxf(rival, score)
	return 0.02 + 0.16 * supporting / maxf(supporting + rival, 0.000000001)

static func _pattern(view: Dictionary, case_data: Dictionary, listener: Dictionary) -> Dictionary:
	var target: String = case_data.conclusion.target
	var incidents = {}
	var contradictions: Array = []
	var cards = Solver.selected(view, case_data)
	for card in cards:
		var out: bool = (card.kind == "sighting" and card.subject == target) or (card.kind == "report" and card.get("role", "") == "nightwatch" and target in card.data.seen)
		if not out:
			continue
		var key = "%s:%d" % [target, card.night]
		var q = _quality(view, [card.id], listener)
		if not incidents.has(key) or q > incidents[key].quality:
			incidents[key] = {"quality": q, "card": card.id, "night": card.night}
	var weight = 0.0
	var path: Array = []
	for key in incidents:
		var incident: Dictionary = incidents[key]
		var explanation: String = case_data.reasons.get(key, "unexplained")
		var explained = 0.0
		if explanation == "gift":
			var claim = Graph.valid_citation(view, case_data, target, incident.night)
			if not claim.is_empty():
				explained = 0.8 * _quality(view, [claim.id], listener)
				path.append(claim.id)
		# Merely selecting 'gift' without supporting testimony is not an explanation.
		weight += 0.3 * incident.quality * (1.0 - explained)
		path.append(incident.card)
		for card in cards:
			if card.kind == "alibi" and card.subject == target and card.night == incident.night:
				weight += 0.2 * minf(incident.quality, _quality(view, [card.id], listener))
				contradictions.append(card.id)
				path.append(card.id)
	return {"weight": minf(weight, 0.8), "agreement": 0.5 if weight > 0 else 0.0, "quality": minf(weight / 0.5, 1.0),
		"cards": path, "kind": "pattern", "incidents": incidents.size(), "alibi_conflicts": contradictions}

static func _objection(view: Dictionary, case_data: Dictionary, listener: Dictionary, shared: Dictionary, assessment: Dictionary, best: Dictionary, pattern: Dictionary) -> String:
	if best.kind == "pattern" and best.weight > 0:
		if not pattern.alibi_conflicts.is_empty():
			return "The outing conflicts with the home alibi. Someone's account is wrong; that adds suspicion but does not identify evil."
		return "These are %d distinct outings. A credible night gift can explain an outing; seeing someone twice on one night is one incident." % pattern.incidents
	if assessment.status == "conflicting":
		if not assessment.errors.is_empty():
			return assessment.errors[0]
		if shared.status != "conflicting":
			return "That conflicts with my own gift or my knowledge that I am good."
		return "The asserted reports, answers or home alibis cannot all hold together. Remove or challenge a premise."
	if best.kind == "conditional":
		return "Your selected people narrow the world; choosing an answer does not establish it."
	if best.quality < 0.45 and not best.cards.is_empty():
		var weakest = ""
		var lowest = 2.0
		for id in best.cards:
			var q = _quality(view, [id], listener)
			if q < lowest:
				lowest = q
				weakest = id
		return "I am least convinced by %s's report (%s); its source and health assumptions still matter." % [Solver.person_name(view, Solver.card_by_id(view, weakest).source), weakest]
	if not assessment.alternative.is_empty() and assessment.entailment == "possible":
		var a: Dictionary = assessment.alternative
		return "An alternative still fits: %s evil; %s Marked." % [", ".join(PackedStringArray(a.evil.map(func(id): return Solver.person_name(view, id)))), Solver.person_name(view, a.marked)]
	if assessment.entailment == "unsupported":
		return "The accepted reports exclude that conclusion."
	return "This depends on the named sources being honest, holding their claimed gifts and being healthy at the reported times."

static func _signature(view: Dictionary, case_data: Dictionary) -> String:
	var keys: Array = Solver.selected(view, case_data).map(func(c): return Solver.semantic_key(c))
	keys.sort()
	var answers = {}
	for card in Solver.selected(view, case_data):
		var positive: Array = case_data.answers.get(card.id, {}).get("positive", []).duplicate()
		if not positive.is_empty():
			positive.sort()
			answers[Solver.semantic_key(card)] = positive
	# Ignore wrapper ids, card/slot order, version and venue.
	var citations = {}
	for key in case_data.get("citations", {}):
		citations[key] = Solver.semantic_key(Solver.card_by_id(view, case_data.citations[key]))
	var scope: Array = Graph.roots(case_data, case_data.get("conflict_scope", [])).map(func(id): return Solver.semantic_key(Solver.card_by_id(view, id)))
	scope.sort()
	var factors: Array = []
	for factor in case_data.get("test_factors", []):
		if not is_zero_approx(float(factor.log2_ratio)):
			var routes: Array = []
			for route in factor.routes:
				var facts: Array = route.map(func(id): return Solver.semantic_key(Solver.card_by_id(view, id)))
				facts.sort()
				routes.append(JSON.stringify(facts))
			routes.sort()
			factors.append(JSON.stringify([factor.target, factor.log2_ratio, factor.events, routes]))
	factors.sort()
	return JSON.stringify(_canonical([keys, case_data.positions, answers, case_data.reasons, citations, scope, case_data.get("challenges", {}), factors, case_data.conclusion]))

static func _canonical(value):
	if value is Dictionary:
		var result = {}
		var keys = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		return value.map(func(item): return _canonical(item))
	return value

static func _changes(view: Dictionary, previous: Dictionary, current: Dictionary) -> Array:
	var changes: Array = []
	if previous.is_empty():
		return changes
	for id in current.cards:
		if id not in previous.cards:
			var card = Solver.card_by_id(view, id)
			changes.append("You added %s's %s." % [Solver.person_name(view, card.source), card.get("role", card.kind)])
	for id in previous.cards:
		if id not in current.cards:
			var card = Solver.card_by_id(view, id)
			if card.is_empty():
				changes.append("You removed a previously cited report.")
			else:
				changes.append("You removed %s's %s." % [Solver.person_name(view, card.source), card.get("role", card.kind)])
	if previous.positions != current.positions:
		changes.append("You changed the assumed alignments or Marked identity.")
	if previous.answers != current.answers:
		changes.append("You changed the answers on your cards.")
	if previous.reasons != current.reasons:
		changes.append("You changed the explanations for the outings.")
	if previous.conclusion != current.conclusion:
		changes.append("You changed the conclusion.")
	return changes
