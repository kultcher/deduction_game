## Portable shared ownership plan. No NPC/World references and no additive case awards.
extends RefCounted
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Jury = preload("res://workshop/jury.gd")

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
		elif card.get("kind") == "info" and card.get("role") in Assess.ROLES:
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
	var issues: Array = []
	for receipt in input.evidence:
		if receipt.id in input.private_evidence and receipt.kind == "info":
			_add(facts, owners, receipt, "learned")
	for eid in ledger:
		var entry: Dictionary = ledger[eid]
		if entry.get("meta", {}).get("kind") == "reading":
			for receipt in entry.meta.get("workshop_receipts", {}).values():
				_add(facts, owners, receipt, "reading:" + eid)
	for key in presentations:
		var presented: Dictionary = presentations[key]
		for argument in presented.arguments:
			if argument.conclusion.get("type") not in Assess.CONCLUSIONS:
				issues.append("Unsupported endorsed claim: " + str(argument.conclusion.get("type")))
			elif argument.conclusion.get("type") == "conflict":
				issues.append("Conflict-only presentations need a shared quoted-report ownership adapter.")
		for issue in presented.issues:
			if issue.code in ["missing_card", "cyclic_argument", "argument_depth"]:
				issues.append("Incomplete endorsement: " + issue.code)
		for receipt in presented.evidence:
			if receipt.id in presented.selected:
				_add(facts, owners, receipt, "case:" + str(key))
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
		if kind == "reading" and aliases.has(eid):
			var receipts: Dictionary = meta.get("workshop_receipts", {})
			if receipts.size() != 1 or not receipts.has(aliases[eid]):
				issues.append("Reading ownership lacks an exact receipt: " + eid)
			else:
				owned[eid] = true
		elif kind == "arg" and (_overlaps(entry, input.evidence) or _withdrawn(entry, withdrawn)):
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
			issues.append("Overlapping card testimony still needs an exact ownership adapter: " + eid)
	for eid in owned:
		if ledger[eid].get("workshop_clipped", false):
			issues.append("A legacy contribution was clipped; its reversible baseline is unavailable: " + eid)
		for i in range(ledger[eid].effects.size()):
			var effect: Array = ledger[eid].effects[i]
			if not ordinary(effect[0]):
				continue
			for person in input.people:
				var key = i if effect[0] == person.id else "%d:%s" % [i, person.id]
				if absf(float(ledger[eid].get("applied", {}).get(key, 0.0))) < 0.000001:
					continue
				# Without an outside layer, a saturated legacy target cannot promise
				# exact reversal. Unrelated cleared people don't block migration.
				var suspicion: float = input.listener.suspicion.get(person.id, 0.1)
				if suspicion <= 0.0 or suspicion >= 1.5:
					issues.append("Saturated legacy beliefs need a reversible baseline before migration: " + eid)
	if prepared.ready or (facts.is_empty() and issues.is_empty()):
		# TOTAL learned evidence, not the marginal value of a presentation over private
		# reports. Self/role/public good knowledge remains; reports move into the union.
		prepared.case.cards = facts.keys()
		prepared.case.id = "shared:" + input.case_id
		prepared.case.arguments = []
		prepared.listener.knowledge.own_reports = []
		# Raw discoveries must not change strength when player trust changes. Player
		# trust discounts only facts whose sole route is the player's presentation.
		var player_weight = clampf(0.5 + prepared.listener.trust, 0.0, 1.0)
		prepared.listener.trust = 0.5
		for id in facts:
			if facts[id].kind != "info":
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
		if sources.size() + uncertain > 6:
			issues.append("Shared evidence exceeds the 64-state credibility budget.")
	return {"ready": issues.is_empty(), "empty": facts.is_empty(), "issues": issues, "owned": owned if issues.is_empty() else {},
		"prepared": prepared, "facts": facts.keys(), "owners": owners, "input": input}

static func evaluate(plan: Dictionary, suspicion: Dictionary, discounted: Dictionary) -> Dictionary:
	if not plan.ready:
		return {}
	if plan.empty:
		return {"effects": {}}
	var prepared: Dictionary = plan.prepared.duplicate(true)
	prepared.listener.suspicion = suspicion.duplicate(true)
	for card in prepared.view.cards:
		var doubt = maxf(discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), discounted.get(card.source + ":*", 0.0))
		# Keep hearing-route discount, replacing only the stale interval reliability.
		var previous = maxf(plan.input.listener.discounted.get("%s:%d" % [card.source, card.observed_at.day], 0.0), plan.input.listener.discounted.get(card.source + ":*", 0.0))
		var route_weight = prepared.listener.reading_reliability[card.id] / (1.0 - previous) if previous < 1.0 else 0.0
		prepared.listener.reading_reliability[card.id] = route_weight * (1.0 - doubt)
	return Jury.evaluate(prepared.view, prepared.case, prepared.listener)

static func _add(facts: Dictionary, owners: Dictionary, receipt: Dictionary, owner: String) -> void:
	facts[receipt.id] = receipt.duplicate(true)
	if not owners.has(receipt.id):
		owners[receipt.id] = []
	if owner not in owners[receipt.id]:
		owners[receipt.id].append(owner)

static func _overlaps(entry: Dictionary, receipts: Array) -> bool:
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
