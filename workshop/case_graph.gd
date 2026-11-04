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
			var blocks: Array = line.answers[id].get("blocks", []).duplicate()
			blocks.sort()
			var existing_blocks: Array = result.answers.get(id, {}).get("blocks", []).duplicate()
			existing_blocks.sort()
			var th_role: String = str(line.answers[id].get("in_play_role", ""))
			var existing_th: String = str(result.answers.get(id, {}).get("in_play_role", ""))
			var p_slot: String = str(line.answers[id].get("false_slot", ""))
			var existing_ps: String = str(result.answers.get(id, {}).get("false_slot", ""))
			var p_why: String = str(line.answers[id].get("false_reason", ""))
			var existing_pw: String = str(result.answers.get(id, {}).get("false_reason", ""))
			if result.answers.has(id) and (existing != positive or existing_blocks != blocks or (th_role != "" and existing_th != "" and th_role != existing_th) or (p_slot != "" and existing_ps != "" and p_slot != existing_ps) or (p_why != "" and existing_pw != "" and p_why != existing_pw)):
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
	if view.has("movement_experiment") or view.get("live_activity", false):
		# Choosing a citation in Answer is an explicit evidence reference, just like
		# drawing a string from the claim. It enters the ordinary attention budget.
		for key in result.get("citations", {}):
			var claim = find_card(view, result.citations[key])
			if claim.is_empty():
				continue
			var outings: Array = result.cards.map(func(id): return find_card(view, id)).filter(func(c): return "%s:%d" % [claim.get("subject", ""), c.get("night", -1)] == key and ((c.kind == "sighting" and claim.subject in c.get("subjects", [c.subject])) or (c.get("role") == "nightwatch" and claim.subject in c.data.seen)))
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
		if view.has("movement_experiment") or view.get("live_activity", false):
			continue # Outings already enter one shared likelihood; no extra 2x award.
		factor_lines.append({"relation": "supports", "cards": dispute.reports, "label": "Challenged home alibi: " + alibi.subject,
			"test_factor": {"target": alibi.subject, "log2_ratio": 1.0, "origin": "false_alibi"}})
	# Psychologist pair selections & none_false day-evidence bolstering:
	for pid in result.cards:
		var pcard: Dictionary = find_card(view, pid)
		if pcard.is_empty() or pcard.get("kind", "") != "report" or pcard.get("role", "") != "psychologist" or pcard.get("quoted", false) or result.get("reading_challenges", {}).has(pid):
			continue
		var pdata: Dictionary = pcard.get("data", {}) if pcard.get("data") is Dictionary else {}
		var pmode: String = str(pdata.get("mode", ""))
		if pmode == "pair" and pdata.get("statements") is Array and pdata.statements.size() == 2:
			var pans: Dictionary = result.answers.get(pid, {})
			var f_slot: String = str(pans.get("false_slot", ""))
			var f_why: String = str(pans.get("false_reason", ""))
			var idxs: Array = [0] if f_slot == "0" else ([1] if f_slot == "1" else ([0, 1] if f_slot == "both" else []))
			for s_idx in idxs:
				var st: Dictionary = pdata.statements[s_idx]
				var tid: String = str(st.get("fact_id", ""))
				var tsrc: String = str(st.get("source", ""))
				var tkind: String = str(st.get("kind", ""))
				if tid != "" and tid in result.cards:
					if tkind == "info" and f_why in ["lying", "misled"] and idxs.size() == 1:
						if not result.reading_challenges.has(tid):
							result.reading_challenges[tid] = {"mode": f_why, "supports": result.cards.filter(func(cid): return cid != tid)}
					elif tid not in result.quoted_cards:
						result.quoted_cards.append(tid)
				if idxs.size() == 1 and f_why == "lying" and tsrc != "":
					var other_fid: String = str(pdata.statements[1 - s_idx].get("fact_id", ""))
					var cites: Array = [pid] + ([other_fid] if other_fid != "" and other_fid in result.cards else [])
					factor_lines.append({"relation": "supports", "cards": cites, "label": "Psychologist reading: %s lied" % tsrc,
						"test_factor": {"target": tsrc, "log2_ratio": 1.35 if cites.size() >= 2 else 0.75, "origin": "psychologist_lie", "psych_event": "psych_lie:%s:%d" % [pid, s_idx]}})
		elif pmode == "none_false":
			var dh: int = int(pdata.get("day_heard", -1))
			var c_target: String = str(result.get("conclusion", {}).get("target", ""))
			if dh >= 1 and c_target != "":
				for cid in result.cards:
					if cid == pid or cid in result.quoted_cards or result.get("reading_challenges", {}).has(cid):
						continue
					var dc: Dictionary = find_card(view, cid)
					if dc.is_empty() or not is_day_statement(dc, dh):
						continue
					if dc.get("kind") == "sighting" and int(dc.get("night", -1)) >= 0 and c_target in dc.get("subjects", [dc.get("subject", "")]):
						factor_lines.append({"relation": "supports", "cards": [pid, cid], "label": "Psychologist day-%d no-lies bolsters sighting of %s" % [dh, c_target],
							"test_factor": {"target": c_target, "log2_ratio": 0.65, "origin": "psychologist_bolster", "psych_event": "psych_bolster:%s:%s" % [pid, cid]}})
					elif dc.get("kind") == "alibi" and c_target in dc.get("subjects", [dc.get("subject", "")]):
						factor_lines.append({"relation": "supports", "cards": [pid, cid], "label": "Psychologist day-%d no-lies bolsters alibi of %s" % [dh, c_target],
							"test_factor": {"target": c_target, "log2_ratio": -0.65, "origin": "psychologist_bolster", "psych_event": "psych_bolster:%s:%s" % [pid, cid]}})
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
		if factor.has("psych_event"):
			facts.append(str(factor.psych_event))
		else:
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

static func is_day_statement(card: Dictionary, day_heard: int) -> bool:
	if day_heard < 1:
		return false
	var rep_d: int = int(card.get("reported_at", {}).get("day", -1)) if card.get("reported_at") is Dictionary else -1
	if rep_d >= 1:
		return rep_d == day_heard
	var lrn_d: int = int(card.get("learned_at", {}).get("day", -1)) if card.get("learned_at") is Dictionary else -1
	if lrn_d == day_heard:
		return true
	var obs_d: int = int(card.get("observed_at", {}).get("day", -1))
	if card.get("kind", "") in ["sighting", "alibi"]:
		return obs_d == day_heard - 1
	if card.get("kind", "") == "report":
		return obs_d in [day_heard - 1, day_heard]
	return false

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
	if home.is_empty() or out.is_empty() or home.kind != "alibi" or home.get("night", -1) < 0 or home.get("night", -1) != out.get("night", -2):
		return false
	if out.kind == "sighting" and home.subject in out.get("subjects", [out.subject]):
		return true
	if out.kind == "report" and out.get("role", "") == "nightwatch" and home.subject in out.data.seen:
		return true
	# One person's two accounts of one night (54875): "I was home" and their own report of
	# a gift that took them out that night can't both be true.
	return out.kind == "report" and out.get("source", "") == home.subject and C.ROLES.get(out.get("role", ""), {}).get("night_walk", false)

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
	var interval: Dictionary = claim.get("applies", {"from": 0, "through": view.get("day", 3) if view.get("live_activity", false) else 3})
	if night < interval.from or night > interval.through:
		return {}
	return claim
