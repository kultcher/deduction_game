## Read-only boundary between simulation state and the portable evidence contract.
## Never pass the World, real evil mind, hidden gift causes or developer log onward.
extends RefCounted

const Evidence = preload("res://workshop/live_evidence.gd")
const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")

static func capture(g, selected: Array, listener_id: String = "", venue: String = "private") -> Dictionary:
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
			"by": event.get("by", ""), "at": {"day": event.day, "phase": "unknown"}})
	var numbers: Array = []
	for number in selected:
		_collect(g.board, number, numbers, input.arguments, input.issues, [])
		if input.root == 0:
			input.root = number
	for number in numbers:
		var card: Dictionary = g.board[number - 1]
		if card.get("kind") != "deduction":
			input.selected.append(number)
			input.receipts.append({"card": card, "private": false})
	if listener_id != "":
		var real = g.w.by_id.get(listener_id)
		if real == null:
			input.issues.append({"code": "unknown_listener", "fact": "", "detail": listener_id})
		else:
			# Selecting an existing cover mind is routing, not an inference from evil truth.
			# Do not create/sync it: that would mutate the simulation or advance an RNG.
			var n = real.shadow if real.is_evil() else real
			if n == null:
				input.issues.append({"code": "cover_unavailable", "fact": "", "detail": listener_id})
			else:
				_listener(input, n, now)
	return Evidence.normalize(input)

static func _collect(board: Array, number, numbers: Array, arguments: Array, issues: Array, path: Array) -> void:
	if not number is int or number <= 0 or number > board.size() or board[number - 1].get("deleted", false):
		issues.append({"code": "missing_card", "fact": str(number), "detail": "Selected evidence is absent or deleted."})
		return
	if number in path:
		issues.append({"code": "cyclic_argument", "fact": str(number), "detail": "Circular deduction support."})
		return
	if number in numbers:
		return
	numbers.append(number)
	var card: Dictionary = board[number - 1]
	if card.get("kind") == "deduction":
		var conclusion = {}
		for key in ["type", "a", "b", "role", "night", "mod", "group", "card"]:
			if card.get("conclusion", {}).has(key):
				var value = card.conclusion[key]
				conclusion[key] = value.duplicate(true) if value is Array or value is Dictionary else value
		arguments.append({"board_number": number, "conclusion": conclusion, "supports": card.get("supports", []).duplicate()})
		for support in card.get("supports", []):
			_collect(board, support, numbers, arguments, issues, path + [number])

static func _listener(input: Dictionary, n, now: Dictionary) -> void:
	input["listener"] = {"id": n.id, "name": n.name, "trust": n.trust, "own_gift": n.role,
		"suspicion": n.suspicion.duplicate(true), "npc_trust": n.npc_trust.duplicate(true),
		"confidence": n.traits.get("confidence", 0.5), "insight": n.traits.get("insight", 0.5),
		"discounted": n.discounted.duplicate(true), "honesty": n.honesty.duplicate(true),
		"known_claims": {}, "own_outings": {}, "role_beliefs": n.believed_roles.duplicate(true)}
	for key in n.history:
		if str(key).ends_with(":3"):
			input.listener.own_outings[str(key).trim_suffix(":3")] = not str(n.history[key]).begins_with("home")
	for e in n.info_log:
		var card = _reading(n.id, e)
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
	# No role/alignment certainty is manufactured from truth or inferred from a gift.
	input.issues.append({"code": "listener_history_partial", "fact": "", "detail": "Legacy knowledge lacks complete report/learning times and withdrawal receipts; own and known readings are retained."})

static func _reading(source: String, e: Dictionary) -> Dictionary:
	var card = {"kind": "info", "source": source, "subject": [], "role": e.get("role", ""),
		"day": e.get("day", -1), "data": e.get("data", {}), "text": e.get("text", "")}
	if e.has("phase"):
		card["phase"] = e.phase
	card["when"] = CardModel.when(card, card.day, -1)
	return card
