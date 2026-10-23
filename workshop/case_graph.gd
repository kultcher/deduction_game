## Case organization and provenance. Compilation never promotes a conclusion to evidence.
extends RefCounted
const C = preload("res://sim/content.gd")

static func compile_case(view: Dictionary, value: Dictionary) -> Dictionary:
	var result = value.duplicate(true)
	var errors: Array = []
	var assigned: Array = []
	var included: Array = []
	result["faults"] = value.get("faults", {}).duplicate(true)
	for line in value.get("lines", []):
		for id in line.cards:
			if id not in assigned:
				assigned.append(id)
		if line.get("relation", "supports") != "supports":
			continue
		included.append_array(line.cards)
		result.faults = combine_faults(result.faults, line.get("faults", {}), errors)
		for positions in [line.get("positions", {})] + line.get("assumption_sets", []):
			for id in positions:
				var position: String = positions[id]
				if result.positions.has(id) and result.positions[id] != position:
					if result.positions[id] in ["good", "marked"] and position in ["good", "marked"]:
						position = "marked"
					else:
						errors.append("%s: the supporting lines assign incompatible identities to %s." % [line.label, id])
				result.positions[id] = position
		for id in line.get("answers", {}):
			if id not in roots(value, line.cards):
				continue
			var positive: Array = line.answers[id].get("positive", []).duplicate()
			positive.sort()
			var existing: Array = result.answers.get(id, {}).get("positive", []).duplicate()
			existing.sort()
			if result.answers.has(id) and existing != positive:
				errors.append("%s: supporting lines give different answers to %s; put alternatives in a separate explanation." % [line.label, id])
			result.answers[id] = line.answers[id].duplicate(true)
		for key in line.get("reasons", {}):
			var reason: String = line.reasons[key]
			if reason == "unexplained":
				continue
			if result.reasons.get(key, "unexplained") not in ["unexplained", reason]:
				errors.append("Supporting lines offer incompatible outing explanations for %s." % key)
			result.reasons[key] = reason
		for key in line.get("citations", {}):
			if result.citations.has(key) and result.citations[key] != line.citations[key]:
				errors.append("Supporting lines cite different gift explanations for %s; separate the alternatives." % key)
			result.citations[key] = line.citations[key]
	for id in value.cards:
		if id not in assigned:
			included.append(id)
	result.cards = roots(value, included)
	if view.has("movement_experiment"):
		# Choosing a citation in Answer is an explicit evidence reference, just like
		# drawing a string from the claim. It enters the ordinary attention budget.
		for key in result.get("citations", {}):
			var claim = find_card(view, result.citations[key])
			if claim.is_empty():
				continue
			var outings: Array = result.cards.map(func(id): return find_card(view, id)).filter(func(c): return "%s:%d" % [claim.get("subject", ""), c.get("night", -1)] == key and ((c.kind == "sighting" and c.subject == claim.subject) or (c.get("role") == "nightwatch" and claim.subject in c.data.seen)))
			if outings.is_empty():
				continue
			var night: int = outings[0].night
			var valid: bool = not valid_citation(view, result, claim.subject, night).is_empty()
			if claim.kind == "secret_claim":
				valid = night >= claim.applies.from and night <= claim.applies.through
			if valid and claim.id not in result.cards:
				result.cards.append(claim.id)
	result["graph_errors"] = errors
	result["test_factors"] = []
	# A challenged statement is evidence that the statement was made, not an
	# instruction to endorse its contents alongside the contradicting observation.
	result["quoted_cards"] = []
	var factor_lines: Array = value.get("lines", []).duplicate(true)
	for dispute in value.get("disputes", []):
		if not valid_dispute(view, dispute) or not dispute.reports.all(func(id): return id in result.cards):
			continue
		var alibi = find_card(view, dispute.challenged)
		if alibi.id not in result.quoted_cards:
			result.quoted_cards.append(alibi.id)
		if view.has("movement_experiment"):
			continue # Outings already enter one shared likelihood; no extra 2x award.
		factor_lines.append({"relation": "supports", "cards": dispute.reports, "label": "Challenged home alibi: " + alibi.subject,
			"test_factor": {"target": alibi.subject, "log2_ratio": 1.0, "origin": "false_alibi"}})
	var factor_keys: Array = []
	for line in factor_lines:
		if line.get("relation", "supports") != "supports" or not line.has("test_factor"):
			continue
		var factor: Dictionary = line.test_factor.duplicate(true)
		factor["cards"] = roots(value, line.cards)
		factor.cards.sort()
		if factor.cards.is_empty():
			errors.append("%s: a test factor needs cited evidence." % line.label)
			continue
		# Same event represented on multiple lines is still one input factor.
		var facts: Array = []
		for id in factor.cards:
			var card: Dictionary = find_card(view, id)
			var key = card.get("fact_id", id)
			if card.kind in ["sighting", "alibi"]:
				key = "outing:%s:%s" % [factor.target if factor.target in card.get("subjects", [card.subject]) else card.subject, card.night]
			elif card.get("role", "") == "nightwatch" and card.kind == "report" and factor.target in card.data.seen:
				key = "outing:%s:%s" % [factor.target, card.night]
			if key not in facts:
				facts.append(key)
		facts.sort()
		var key = JSON.stringify([factor.target, facts])
		if key in factor_keys:
			var prior: Dictionary = result.test_factors[factor_keys.find(key)]
			if not is_equal_approx(float(prior.log2_ratio), float(factor.log2_ratio)):
				errors.append("The same evidence has conflicting test factors in different lines.")
			if not prior.routes.has(factor.cards):
				prior.routes.append(factor.cards)
			continue
		for prior in result.test_factors:
			if prior.target == factor.target and facts.any(func(event): return event in prior.events):
				errors.append("Overlapping test factors reuse the same incident. Combine those citations in one line.")
		factor_keys.append(key)
		factor["label"] = line.label
		factor["events"] = facts
		factor["routes"] = [factor.cards]
		result.test_factors.append(factor)
	return result

static func combine_faults(first: Dictionary, second: Dictionary, errors: Array = []) -> Dictionary:
	var result = first.duplicate(true)
	for key in second:
		if not result.has(key):
			result[key] = second[key].duplicate(true)
		elif result[key] != second[key]:
			var old: String = result[key].get("basis", "")
			var added: String = second[key].get("basis", "")
			if old != "" and added != "" and old != added:
				errors.append("Supporting lines offer different fault grounds; separate the alternatives.")
			elif old == "":
				result[key] = second[key].duplicate(true)
	return result

static func valid_dispute(view: Dictionary, dispute) -> bool:
	if not dispute is Dictionary or not dispute.get("reports") is Array or dispute.reports.size() != 2 or not dispute.get("challenged") is String or not dispute.get("preferred") is String:
		return false
	if dispute.challenged == dispute.preferred or not dispute.reports.has(dispute.challenged) or not dispute.reports.has(dispute.preferred):
		return false
	var home = find_card(view, dispute.challenged)
	var out = find_card(view, dispute.preferred)
	return not home.is_empty() and not out.is_empty() and home.kind == "alibi" and home.get("night", -1) >= 0 and home.get("night", -1) == out.get("night", -2) and ((out.kind == "sighting" and home.subject in out.get("subjects", [out.subject])) or (out.kind == "report" and out.get("role", "") == "nightwatch" and home.subject in out.data.seen))

static func roots(value: Dictionary, ids: Array) -> Array:
	var result: Array = []
	for id in ids:
		var expanded: Array = [id]
		for question in value.get("derived", []):
			if question.id == id:
				expanded = question.supports
		for root in expanded:
			if root not in result:
				result.append(root)
	return result

static func find_card(view: Dictionary, id: String) -> Dictionary:
	for card in view.cards:
		if card.id == id:
			return card
	return {}

static func valid_citation(view: Dictionary, value: Dictionary, person: String, night: int) -> Dictionary:
	var id: String = value.get("citations", {}).get("%s:%d" % [person, night], "")
	var claim = find_card(view, id)
	if claim.is_empty() or claim.kind != "claim" or claim.subject != person:
		return {}
	var gift: Dictionary = C.ROLES.get(claim.role, {})
	if not gift.get("night_walk", false) or gift.get("align", "") != "good":
		return {}
	var interval: Dictionary = claim.get("applies", {"from": 0, "through": 3})
	if night < interval.from or night > interval.through:
		return {}
	return claim
