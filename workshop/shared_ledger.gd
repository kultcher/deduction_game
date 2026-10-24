## Portable shared ownership plan. No NPC/World references and no additive case awards.
extends RefCounted
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Jury = preload("res://workshop/jury.gd")
const Support = preload("res://workshop/support_model.gd")
const Theory = preload("res://workshop/theory.gd")
const Reasoner = preload("res://workshop/reasoner.gd")

static func reading(source: String, entry: Dictionary) -> Dictionary:
	var card = {"kind": "info", "source": source, "role": entry.get("role", ""),
		"day": entry.get("day", -1), "data": entry.get("data", {}), "text": entry.get("text", "")}
	if entry.has("phase"):
		card.phase = entry.phase
	return Evidence.normalize_card(card)

## Exact original receipts, independent of legacy source/night support references.
static func roots(cards: Array, board: Array, path: Array = []) -> Dictionary:
	var result = {"complete": true, "receipts": {}}
	for card in cards:
		if card.get("kind") == "deduction":
			var number = card.get("n", 0)
			if number in path or path.size() >= 64:
				result.complete = false
				continue
			var children: Array = []
			for support in card.get("supports", []):
				var found = board.filter(func(c): return c.get("n") == support and not c.get("deleted", false))
				if found.is_empty():
					result.complete = false
				else:
					children.append(found[0])
			var nested = roots(children, board, path + [number])
			result.complete = result.complete and nested.complete
			result.receipts.merge(nested.receipts)
		elif (card.get("kind") == "info" and card.get("role") in Assess.ROLES) or (card.get("kind") == "claim" and card.get("role") in Assess.C.GOOD_ROLES) or (card.get("kind") in ["sighting", "alibi"] and card.get("phase", -1) in [2, 3]) or card.get("kind") in ["trace", "vigil", "quiet", "execution", "martyr", "knell"]:
			var receipt = Evidence.normalize_card(card)
			result.receipts[receipt.id] = receipt
		elif card.get("kind") not in ["claim", "home"]:
			result.complete = false
	return result

static func ordinary(target: String) -> bool:
	return not target.begins_with("disc:") and not target.begins_with("pref:") and not target.begins_with("role:")

## A presentation is an endorsement path, not an additional copy of its facts.
## Removing it removes only roots with no remaining learned/endorsed owner.
static func prepare(current: Dictionary, presentations: Dictionary, ledger: Dictionary, withdrawn: Dictionary = {}) -> Dictionary:
	var input = current.duplicate(true)
	var facts = {}
	var owners = {}
	var quotations = {}
	var issues: Array = []
	var marked_questions: Array = []
	var disputes: Array = []
	var reading_challenges = {}
	for receipt in input.evidence:
		if receipt.id in input.private_evidence and supported(receipt):
			_add(facts, owners, receipt, "learned")
	for eid in ledger:
		var entry: Dictionary = ledger[eid]
		if entry.get("meta", {}).get("kind") == "reading":
			for receipt in entry.meta.get("workshop_receipts", {}).values():
				if supported(receipt):
					_add(facts, owners, receipt, "reading:" + eid)
		if entry.get("meta", {}).get("kind") == "tell" and entry.meta.has("workshop_card") and supported(entry.meta.workshop_card):
			_add(facts, owners, entry.meta.workshop_card, "testimony:" + eid)
	for key in presentations:
		var presented: Dictionary = presentations[key]
		for argument in presented.arguments:
			for id in argument.get("workshop_case", {}).get("reading_challenges", {}):
				var challenge: Dictionary = argument.workshop_case.reading_challenges[id]
				if reading_challenges.has(id) and reading_challenges[id].mode != challenge.mode:
					issues.append("Conflicting reading challenges need separate alternatives.")
				else:
					reading_challenges[id] = challenge.duplicate(true)
			for dispute in argument.get("workshop_case", {}).get("disputes", []):
				if dispute not in disputes:
					disputes.append(dispute.duplicate(true))
			if argument.conclusion.get("type") == "marked":
				var target: String = Assess._target(argument.conclusion)
				if target not in marked_questions:
					marked_questions.append(target)
			for claim in argument.get("workshop_case", {}).get("arguments", []):
				if claim.case.conclusion.get("type") == "marked" and claim.case.conclusion.target not in marked_questions:
					marked_questions.append(claim.case.conclusion.target)
			if argument.conclusion.get("type") not in Assess.CONCLUSIONS:
				issues.append("Unsupported endorsed claim: " + str(argument.conclusion.get("type")))
		for issue in presented.issues:
			if issue.code in ["missing_card", "cyclic_argument", "argument_depth"]:
				issues.append("Incomplete endorsement: " + issue.code)
		var endorsed = endorsed_facts(presented, presented.root)
		for receipt in presented.evidence:
			if receipt.id in presented.selected:
				if receipt.id in endorsed:
					_add(facts, owners, receipt, "case:" + str(key))
				else:
					quotations[receipt.id] = receipt.duplicate(true)
	input.evidence = facts.values()
	input.selected = facts.keys()
	input.private_evidence = input.private_evidence.filter(func(id): return facts.has(id))
	input.board_map = {}
	var numbers: Array = []
	for i in range(input.evidence.size()):
		var number = -2 - i
		input.board_map[str(number)] = input.evidence[i].id
		numbers.append(number)
	# Claim labels are questions, never extra evidence. All consequences project the
	# same union; the actual presentation retains its separately scoped diagnostics.
	input.root = -1
	input.arguments = [{"board_number": -1, "conclusion": {"type": "evil", "a": input.people[0].id}, "supports": numbers}]
	var prepared = Assess.prepare(input)
	issues.append_array(prepared.issues.filter(func(issue): return not facts.is_empty() or issue != "No supported reading is presented."))
	var aliases = {}
	for receipt in input.evidence:
		if receipt.kind != "info":
			continue
		var coarse = "info:%s:%d:%s" % [receipt.source, receipt.observed_at.day, receipt.content.role]
		if aliases.has(coarse) and aliases[coarse] != receipt.id:
			issues.append("Unresolved original reading identity: " + coarse)
		aliases[coarse] = receipt.id
	var owned = {}
	for eid in ledger:
		var entry: Dictionary = ledger[eid]
		var meta: Dictionary = entry.get("meta", {})
		var kind: String = meta.get("kind", "")
		if preload("res://workshop/live_protection.gd").owns(entry, prepared.view.get("cards", [])):
			owned[eid] = true
			continue
		if kind == "tell" and meta.get("workshop_card", {}).get("kind") == "deduction" and not facts.is_empty():
			issues.append("Unresolved deduction wrapper in old card testimony: " + eid)
		if kind == "reading" and aliases.has(eid):
			var receipts: Dictionary = meta.get("workshop_receipts", {})
			if receipts.size() != 1 or not receipts.has(aliases[eid]):
				issues.append("Reading ownership lacks an exact receipt: " + eid)
			else:
				owned[eid] = true
		elif kind == "arg" and (_overlaps(entry, input.evidence) or _withdrawn(entry, withdrawn) or _presented(entry, presentations)):
			var justifications: Array = entry.get("justs", [])
			var certified = not justifications.is_empty() and meta.get("workshop_conclusion", "") in Assess.CONCLUSIONS
			for justification in justifications:
				certified = certified and not justification.get("workshop_uncertified", false)
				var routes: Dictionary = justification.get("workshop_cases", {})
				certified = certified and not routes.is_empty()
				for number in routes:
					if withdrawn.has(number):
						continue
					var proof: Dictionary = routes[number]
					certified = certified and proof.get("complete", false) and not proof.get("receipts", {}).is_empty()
					for id in proof.get("receipts", {}):
						# A re-presented board argument replaces its old endorsement.
						certified = certified and (presentations.has(number) or facts.has(id))
			if certified:
				owned[eid] = true
			else:
				issues.append("Mixed or uncertified argument ownership: " + eid)
		elif kind == "tell" and _overlaps(entry, input.evidence):
			if meta.has("workshop_card") and supported(meta.workshop_card) and facts.has(meta.workshop_card.id):
				owned[eid] = true
			else:
				issues.append("Overlapping card testimony lacks an exact original receipt: " + eid)
	# Unsupported effects can coexist only when their reading source is separate.
	# Two claimed gifts from one source share role/credibility uncertainty that the
	# restricted model cannot safely split between independent owners.
	for eid in ledger:
		var entry: Dictionary = ledger[eid]
		if owned.has(eid) or entry.get("meta", {}).get("kind") != "reading" or entry.get("weight", 0.0) <= 0.01:
			continue
		var relation: Array = entry.get("rel", [])
		if not relation.is_empty() and input.evidence.any(func(e): return e.kind in ["info", "claim"] and supported(e) and e.source == relation[0]):
			issues.append("Unsupported reading shares a source with owned reports: " + eid)
	if prepared.ready or (facts.is_empty() and issues.is_empty()):
		# TOTAL learned evidence, not the marginal value of a presentation over private
		# reports. Self/role/public good knowledge remains; reports move into the union.
		prepared.case.cards = facts.keys()
		prepared.case.id = "shared:" + input.case_id
		prepared.case.arguments = []
		prepared.case.disputes = disputes
		prepared.case.reading_challenges = reading_challenges
		prepared.listener.knowledge.own_reports = []
		# Personally received gifts stay available outside the attention budget.
		# Other learned testimony competes for attention like presented reports.
		# Keep this separate from the private-only subtraction: the union owns the
		# TOTAL effect, including the listener's own native gift contribution.
		prepared.listener.knowledge["attention_reports"] = input.private_evidence.filter(func(id): return facts.has(id) and facts[id].source == input.listener.id)
		# Raw discoveries must not change strength when player trust changes. Player
		# trust discounts only facts whose sole route is the player's presentation.
		var player_weight = clampf(0.5 + prepared.listener.trust, 0.0, 1.0)
		prepared.listener.trust = 0.5
		for id in facts:
			if facts[id].kind not in ["info", "claim"]:
				continue
			var weight = player_weight
			if owners[id].any(func(owner): return owner == "learned" or owner.begins_with("reading:")):
				weight = 1.0
				for owner in owners[id]:
					if owner.begins_with("reading:"):
						weight = minf(weight, clampf(ledger[owner.trim_prefix("reading:")].weight, 0.0, 1.0))
			prepared.listener.reading_reliability[id] *= weight
		# Presentation weights add per-report uncertainty; enforce the budget AFTER
		# introducing those dimensions as well as during ordinary preparation.
		var sources = {}
		for card in prepared.view.cards:
			if card.source != prepared.listener.id:
				sources[card.source] = true
		var uncertain = prepared.listener.reading_reliability.values().filter(func(v): return v > 0 and v < 1).size()
		var dimensions: int = Support.dimensions(prepared.view.cards, prepared.listener, prepared.case.reading_challenges) if prepared.view.world_options.get("roles", false) or not prepared.case.reading_challenges.is_empty() else sources.size() + uncertain
		if Jury.engine == "legacy" and dimensions > 6:
			issues.append("Shared evidence exceeds the 64-state credibility budget.")
	return {"ready": issues.is_empty(), "empty": facts.is_empty(), "issues": issues, "owned": owned if issues.is_empty() else {},
		"prepared": prepared, "facts": facts.keys(), "owners": owners, "quotations": quotations, "input": input,
		"marked_questions": marked_questions}

static func supported(receipt: Dictionary) -> bool:
	if receipt.get("kind") == "info" and receipt.get("content", {}).get("role") == "medium":
		var item: Dictionary = receipt.content.get("data", {}).get("item", {})
		if item.get("type") == "reading":
			return item.get("entry", {}).get("role") in Assess.ROLES and item.entry.role != "medium"
		return item.get("type") in ["sighting", "home", "guard"] and item.get("night", -1) >= 0
	return (receipt.get("kind") == "info" and receipt.get("content", {}).get("role") in Assess.ROLES) or (receipt.get("kind") == "claim" and receipt.content.get("role") in Assess.C.GOOD_ROLES) or (receipt.get("kind") in ["sighting", "alibi"] and receipt.observed_at.phase in ["night", "evening"]) or receipt.kind in ["trace", "vigil", "quiet", "execution", "martyr", "knell"]

static func endorsed_facts(snapshot: Dictionary, number: int, path: Array = []) -> Array:
	if number in path or path.size() >= 64:
		return []
	if snapshot.board_map.has(str(number)):
		return [snapshot.board_map[str(number)]]
	var arguments: Array = snapshot.arguments.filter(func(a): return a.board_number == number)
	if arguments.is_empty() or arguments[0].conclusion.get("type") == "conflict":
		return []
	if arguments[0].has("workshop_case"):
		var value: Dictionary = arguments[0].workshop_case
		var assigned: Array = []
		var endorsed: Array = []
		for line in value.get("lines", []):
			assigned.append_array(line.cards)
			if line.get("relation", "supports") == "supports":
				for id in line.cards:
					if id not in endorsed:
						endorsed.append(id)
		for id in value.cards:
			if id not in assigned and id not in endorsed:
				endorsed.append(id)
		return endorsed
	var result: Array = []
	for child in arguments[0].supports:
		for id in endorsed_facts(snapshot, child, path + [number]):
			if id not in result:
				result.append(id)
	return result

## Same original facts and credibility inputs as the applied union. A scoped claim
## is assessed against the other learned reports, without applying a second vector.
static func response(plan: Dictionary, snapshot: Dictionary, baseline: Dictionary) -> Dictionary:
	var scoped = Assess.prepare(snapshot)
	if not plan.ready or not scoped.ready:
		return {}
	var view: Dictionary = scoped.view.duplicate(true)
	view.world_options = plan.prepared.view.world_options.duplicate(true)
	if plan.prepared.view.get("live_activity", false):
		view["live_activity"] = true
	for card in plan.prepared.view.cards:
		if not view.cards.any(func(c): return c.id == card.id):
			view.cards.append(card.duplicate(true))
	var listener: Dictionary = plan.prepared.listener.duplicate(true)
	listener.suspicion = baseline.duplicate(true)
	# A scoped explanation uses the union's current commitment. It cannot adopt a
	# second, stronger commitment just because a different headline was asked.
	listener["fixed_theory_decisions"] = {}
	for key in listener.theories:
		if listener.theories[key].has("decision"):
			listener.fixed_theory_decisions[key] = listener.theories[key].decision.duplicate(true)
	for card in view.cards:
		if not listener.reading_reliability.has(card.id):
			listener.reading_reliability[card.id] = scoped.listener.reading_reliability.get(card.id, 1.0)
	var endorsed = endorsed_facts(snapshot, snapshot.root)
	listener.knowledge.own_reports = plan.facts.filter(func(id): return id not in endorsed)
	if listener.get("reasoning_mode", "full") == "bounded":
		for id in listener.knowledge.own_reports:
			if id not in scoped.case.cards:
				scoped.case.cards.append(id)
	if scoped.case.conclusion.type == "conflict":
		listener.knowledge.own_reports = [] # Test the quoted set, not an unrelated background inconsistency.
	return Jury.evaluate(view, scoped.case, listener)

static func evaluate(plan: Dictionary, suspicion: Dictionary, discounted: Dictionary) -> Dictionary:
	if not plan.ready:
		return {}
	if plan.empty:
		return {"effects": {}}
	var prepared: Dictionary = plan.prepared.duplicate(true)
	prepared.listener.suspicion = suspicion.duplicate(true)
	for card in prepared.view.cards:
		if card.has("relay_source"):
			prepared.listener.reading_reliability[card.accuracy_origin] = 1.0 - maxf(discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), discounted.get(card.source + ":*", 0.0))
			var relay_source: String = card.relay_source
			var relay_day: int = card.relay_observed_at.day
			var relay_before: float = maxf(plan.input.listener.discounted.get("%s:%d" % [relay_source, relay_day], 0.0), plan.input.listener.discounted.get(relay_source + ":*", 0.0))
			var relay_after: float = maxf(discounted.get("%s:%d" % [relay_source, relay_day], 0.0), discounted.get(relay_source + ":*", 0.0))
			prepared.listener.reading_reliability[card.id] = prepared.listener.reading_reliability[card.id] * (1.0 - relay_after) / (1.0 - relay_before) if relay_before < 1.0 else 0.0
			continue
		if card.has("route_origin"):
			prepared.listener.reading_reliability[card.accuracy_origin] = 1.0 - maxf(discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), discounted.get(card.source + ":*", 0.0))
			continue
		if card.kind != "report":
			continue # Impairment does not invalidate ordinary testimony/role claims.
		var doubt = maxf(discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), discounted.get(card.source + ":*", 0.0))
		# Keep hearing-route discount, replacing only the stale interval reliability.
		var previous = maxf(plan.input.listener.discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), plan.input.listener.discounted.get(card.source + ":*", 0.0))
		var route_weight = prepared.listener.reading_reliability[card.id] / (1.0 - previous) if previous < 1.0 else 0.0
		prepared.listener.reading_reliability[card.id] = route_weight * (1.0 - doubt)
	var result = Jury.evaluate(prepared.view, prepared.case, prepared.listener)
	if prepared.listener.get("confidence_mode") == "persistence":
		# Registration is a separate theory, never an asserted identity or another
		# suspicion award. Retain questions already considered as evidence changes.
		prepared.listener.suspicion = suspicion.duplicate(true)
		var attention = Reasoner.prepare(prepared.view, prepared.case, prepared.listener)
		var targets: Array = plan.get("marked_questions", []).duplicate()
		var fact_key: Array = plan.facts.duplicate()
		fact_key.sort()
		for key in prepared.listener.theories:
			if key.ends_with("|marked") and key.get_slice("|", 0) not in targets:
				targets.append(key.get_slice("|", 0))
		for target in targets:
			var question: Dictionary = attention.case.duplicate(true)
			question.conclusion = {"type": "marked", "target": target, "at": prepared.case.conclusion.at}
			var scoped = attention.duplicate(true)
			scoped.case = question
			var reasoning = Support.explain(prepared.view, question, prepared.listener, scoped)
			var key = JSON.stringify(Evidence.canonical([fact_key, suspicion, prepared.listener.npc_trust,
				prepared.listener.reading_reliability, prepared.listener.knowledge, prepared.listener.insight,
				prepared.listener.confidence, target, reasoning.considered]))
			Theory.prepare(prepared.view, question, prepared.listener, reasoning, key)
	result["theories"] = prepared.listener.theories.duplicate(true)
	return result

static func _add(facts: Dictionary, owners: Dictionary, receipt: Dictionary, owner: String) -> void:
	facts[receipt.id] = receipt.duplicate(true)
	if not owners.has(receipt.id):
		owners[receipt.id] = []
	if owner not in owners[receipt.id]:
		owners[receipt.id].append(owner)

static func _overlaps(entry: Dictionary, receipts: Array) -> bool:
	if entry.get("meta", {}).has("workshop_card"):
		return receipts.any(func(e): return e.id == entry.meta.workshop_card.id)
	var supports: Array = [entry.rel] if not entry.get("rel", []).is_empty() else []
	for justification in entry.get("justs", []):
		supports.append_array(justification.get("supports", []))
	for support in supports:
		if support.size() < 2 or (support.size() > 2 and support[2] != "reading"):
			continue
		if receipts.any(func(e): return e.kind == "info" and e.source == support[0] and (support[1] == -1 or e.observed_at.day == support[1])):
			return true
	return false

static func _withdrawn(entry: Dictionary, withdrawn: Dictionary) -> bool:
	for justification in entry.get("justs", []):
		for number in justification.get("workshop_cases", {}):
			if withdrawn.has(number):
				return true
	return false

static func _presented(entry: Dictionary, presentations: Dictionary) -> bool:
	for justification in entry.get("justs", []):
		for number in justification.get("workshop_cases", {}):
			if presentations.has(number):
				return true
	return false
