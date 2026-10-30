## Read-only boundary between simulation state and the portable evidence contract.
## Never pass the World, real evil mind, hidden gift causes or developer log onward.
extends RefCounted

const Evidence = preload("res://workshop/live_evidence.gd")
const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")

static func capture(g, selected: Array, listener_id: String = "", venue: String = "private", cover_mind = null) -> Dictionary:
	var now = {"day": g.w.day, "phase": g._phase_now()}
	var input = {"case_id": "case:%d:%d" % [g.w.seed_value, g.w.n_npcs], "now": now, "venue": venue,
		"people": [], "receipts": [], "selected": [], "arguments": [], "root": 0, "issues": [],
		"public_events": [], "rules": {"initial_evil_count": 1 + C.SETUPS.get(g.w.n_npcs, {"minions": 1}).minions,
			"modifier_options": C.SECRET_MOD_LIST.duplicate(), "one_modifier_kind": true,
			"lovers_holders": 2, "other_modifier_holders": 1, "roles": C.ROLES.keys()}}
	if venue not in ["private", "meeting", "nomination"]:
		input.issues.append({"code": "invalid_venue", "fact": "", "detail": venue})
	for n in g.w.npcs:
		input.people.append({"id": n.id, "name": n.name, "home": n.home_block, "alive": n.alive})
	for event in g.w.public_log:
		input.public_events.append({"kind": event.kind, "subjects": event.get("subjects", []).duplicate(),
			"by": event.get("by", ""), "at": {"day": event.day, "phase": "night" if event.kind == "demon_death" else ("evening" if event.kind in ["silenced", "vote"] else "unknown")}})
		if event.kind in ["curse", "curse_lifted"] and event.has("phase"):
			input.public_events[-1].at = Evidence.stamp({"day": event.day, "phase": event.phase})
		if event.kind == "vote":
			input.public_events[-1]["data"] = {}
			for field in ["nominee", "nominator", "yes", "no", "player_yes", "count", "threshold", "outcome"]:
				if event.get("data", {}).has(field):
					var value = event.data[field]
					input.public_events[-1].data[field] = value.duplicate(true) if value is Array else value
	# Native death announcements are player-observed process cards, not a query of
	# the referee's death_cause field. A public death is strong, finite evidence.
	for card in g.board:
		if card.get("kind") == "death" and card.get("source") == "player":
			input.public_events.append({"kind": "demon_death", "subjects": card.get("subject", []).duplicate(),
				"by": "town", "at": Evidence.stamp(card.get("when", {}))})
		elif card.get("kind") == "execution" and card.get("source") == "player":
			input.public_events.append({"kind": "execution", "subjects": card.get("subject", []).duplicate(),
				"by": "town", "at": Evidence.stamp(card.get("when", {}))})
		elif card.get("kind") == "martyr" and card.get("source") == "player" and card.get("subject", []).size() == 2:
			input.public_events.append({"kind": "martyr", "subjects": card.subject.duplicate(), "by": card.get("martyr", card.subject[0]), "at": Evidence.stamp(card.get("when", {}))})
	var numbers: Array = []
	for number in selected:
		_collect(g, number, numbers, input.arguments, input.issues, [])
		if input.root == 0:
			input.root = number
	for number in numbers:
		var card: Dictionary = g.receipt_by_number(number)
		if not card.is_empty() and card.get("kind") != "deduction":
			input.selected.append(number)
			input.receipts.append({"card": card, "private": false})
	if listener_id != "":
		var real = g.w.by_id.get(listener_id)
		if real == null:
			input.issues.append({"code": "unknown_listener", "fact": "", "detail": listener_id})
		else:
			# Selecting an existing cover mind is routing, not an inference from evil truth.
			# Do not create/sync it: that would mutate the simulation or advance an RNG.
			var n = cover_mind if cover_mind != null else (real.shadow if real.is_evil() else real)
			if n == null:
				input.issues.append({"code": "cover_unavailable", "fact": "", "detail": listener_id})
			else:
				_listener(input, n, now)
	return Evidence.normalize(input)

static func _collect(g, number, numbers: Array, arguments: Array, issues: Array, path: Array) -> void:
	if path.size() >= 64:
		issues.append({"code": "argument_depth", "fact": str(number), "detail": "The live adapter's deduction-depth limit was reached."})
		return
	if not number is int or number == 0:
		issues.append({"code": "missing_card", "fact": str(number), "detail": "Selected evidence is absent or deleted."})
		return
	var card: Dictionary = g.receipt_by_number(number)
	if card.is_empty() or card.get("deleted", false):
		issues.append({"code": "missing_card", "fact": str(number), "detail": "Selected evidence is absent or deleted."})
		return
	if number in path:
		issues.append({"code": "cyclic_argument", "fact": str(number), "detail": "Circular deduction support."})
		return
	if number in numbers:
		return
	numbers.append(number)
	if card.get("kind") == "deduction":
		var conclusion = {}
		for key in ["type", "a", "b", "role", "night", "mod", "group", "card"]:
			if card.get("conclusion", {}).has(key):
				var value = card.conclusion[key]
				conclusion[key] = value.duplicate(true) if value is Array or value is Dictionary else value
		arguments.append({"board_number": number, "conclusion": conclusion, "supports": card.get("supports", []).duplicate()})
		if card.has("workshop_case"):
			arguments[-1]["workshop_case"] = card.workshop_case.duplicate(true)
		for support in card.get("supports", []):
			_collect(g, support, numbers, arguments, issues, path + [number])

static func _listener(input: Dictionary, n, now: Dictionary) -> void:
	input["listener"] = {"id": n.id, "name": n.name, "trust": n.trust, "own_gift": n.role,
		"suspicion": preload("res://sim/mind.gd").suspicion_view(n), "npc_trust": n.npc_trust.duplicate(true),
		"confidence": n.traits.get("confidence", 0.5), "insight": n.traits.get("insight", 0.5),
		"reasoning_mode": n.workshop_state.get("reasoning_mode", "bounded"),
		"confidence_mode": n.workshop_state.get("confidence_mode", "scale"),
		"theories": n.workshop_state.get("theories", {}).duplicate(true),
		"discounted": n.discounted.duplicate(true), "honesty": n.honesty.duplicate(true),
		"known_claims": {}, "own_outings": {}, "role_beliefs": n.believed_roles.duplicate(true), "legacy_evidence": []}
	input.listener["disowned_reports"] = []
	for entry in n.ledger.values():
		if entry.get("meta", {}).get("kind", "") not in ["reading", "arg", "tell"]:
			continue
		var supports: Array = entry.get("meta", {}).get("supports", []).duplicate(true)
		for justification in entry.get("justs", []):
			for support in justification.get("supports", []):
				if support not in supports:
					supports.append(support.duplicate())
		var id: String = entry.get("eid", "")
		var relation: Array = entry.get("rel", []).duplicate(true)
		var receipts: Array = entry.meta.get("workshop_receipts", {}).values()
		if not receipts.is_empty() and receipts.all(func(receipt): return receipt.get("content", {}).get("anonymous", false)):
			# The native compatibility key contains referee identity. It is not
			# permitted provenance for an unnamed public report.
			id = "anonymous:" + str(receipts[0].id)
			if not relation.is_empty():
				relation[0] = ""
			supports = []
		input.listener.legacy_evidence.append({"id": id, "kind": entry.meta.kind,
			"rel": relation, "supports": supports})
	for key in n.history:
		if str(key).ends_with(":3"):
			input.listener.own_outings[str(key).trim_suffix(":3")] = n.secret_mod != "sleepwalker" and not str(n.history[key]).begins_with("home")
	for e in n.info_log:
		var card = _reading(n.id, e)
		if e.get("disowned", false):
			input.listener.disowned_reports.append(Evidence.normalize_card(card).id)
			continue # Their own withdrawn memory is not firsthand support.
		input.receipts.append({"card": card, "private": true})
	for source in n.known_claims:
		var claim: Dictionary = n.known_claims[source]
		input.listener.known_claims[source] = {"role": claim.get("role", ""), "via": claim.get("via", "")}
		for e in claim.get("readings", []):
			var card = _reading(source, e)
			card["via"] = claim.get("via", "")
			input.receipts.append({"card": card, "private": true})
	for belief in n.beliefs:
		if belief.get("kind") != "saw":
			continue
		var card = {"kind": "sighting", "source": n.id, "subject": [belief.who],
			"day": belief.day, "phase": belief.phase, "block": belief.get("block", ""), "loc": belief.get("loc", "")}
		card["when"] = CardModel.when(card, now.day, now.phase)
		input.receipts.append({"card": card, "private": true})
	for key in n.warden_log:
		var target: String = n.warden_log[key]
		var night: int = int(key)
		var residents: Array = input.people.filter(func(p): return p.id == target)
		if night < 1 or night > now.day or residents.is_empty():
			continue
		input.receipts.append({"private": true, "card": {"kind": "sighting", "source": n.id, "subject": [n.id], "guard_claim": target,
			"block": residents[0].home, "day": night, "phase": C.NIGHT, "text": "My own guard statement."}})
	# No role/alignment certainty is manufactured from truth or inferred from a gift.
	input.issues.append({"code": "listener_history_partial", "fact": "", "detail": "Legacy knowledge lacks complete report/learning times and withdrawal receipts; own and known readings are retained."})

static func _reading(source: String, e: Dictionary) -> Dictionary:
	var card = {"kind": "info", "source": source, "subject": [], "role": e.get("role", ""),
		"day": e.get("day", -1), "data": e.get("data", {}), "text": e.get("text", "")}
	if e.has("phase"):
		card["phase"] = e.phase
	card["when"] = CardModel.when(card, card.day, -1)
	return card
