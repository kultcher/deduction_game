## Conditional constraints for joint source/channel likelihoods. This module only
## describes assumptions; callers supply probabilities and marginalize legal worlds.
## A failed accuracy assumption relaxes content, never negates it or erases a
## truthful gift declaration. No referee state or game RNG is available here.
extends RefCounted
const TimeModel = preload("res://workshop/chronology.gd")
const Evidence = preload("res://workshop/live_evidence.gd")

## Poison given on night d lasts through the following day, until night d+1.
static func window(at: Dictionary) -> int:
	return int(at.day) if at.phase == "night" else int(at.day) - 1

static func compile(view: Dictionary, cards: Array) -> Dictionary:
	var plan = {"channels": [], "statements": [], "issues": []}
	var indices = {}
	var originals = {}
	for card in cards:
		var statement = {"card": card.duplicate(true), "identity": [], "content": [], "relay_identity": [], "relay_content": []}
		if card.get("quoted", false):
			plan.statements.append(statement)
			continue # The statement exists without endorsing its disputed contents.
		if card.kind in ["report", "claim"] and not _stamp(card.get("observed_at", {})):
			plan.issues.append("Gift statement needs an original observation time: " + card.id)
			continue
		statement["origin"] = card.get("accuracy_origin", card.get("fact_id", card.id))
		statement["body"] = _body(card)
		var signature = Evidence.canonical(statement.body)
		if originals.has(statement.origin) and originals[statement.origin] != signature:
			plan.issues.append("Conflicting payloads share an original content identity: " + statement.origin)
			continue
		originals[statement.origin] = signature
		if card.kind in ["report", "claim"]:
			var scope: String = TimeModel.source_key(view, card).trim_prefix("source:")
			var honesty = _channel(plan, indices, "gift_honesty:" + scope, "gift_honesty", card.source)
			statement.identity.append(honesty)
			statement.content.append(honesty)
			if card.kind == "report":
				statement.content.append(_accuracy(plan, indices, card.source, card.observed_at))
		elif card.kind == "gift_hint":
			var scope: String = TimeModel.source_key(view, card).trim_prefix("source:")
			statement.content.append(_channel(plan, indices, "gift_honesty:" + scope, "gift_honesty", card.source))
		elif card.kind in ["sighting", "alibi", "evening", "location", "secret_claim"] and card.source not in ["evidence", "player"]:
			# Whereabouts honesty is independent of gift honesty and gift health.
			var scope: String = TimeModel.source_key(view, card).trim_prefix("source:")
			statement.content.append(_channel(plan, indices, "testimony_honesty:" + scope, "testimony_honesty", card.source))
		if card.has("relay_source"):
			if not _stamp(card.get("relay_observed_at", {})):
				plan.issues.append("Medium relay needs its observation time: " + card.id)
				continue
			var relay = {"source": card.relay_source, "observed_at": card.relay_observed_at}
			var scope: String = TimeModel.source_key(view, relay).trim_prefix("source:")
			var honesty = _channel(plan, indices, "gift_honesty:" + scope, "gift_honesty", card.relay_source)
			statement.relay_identity.append(honesty)
			var transmission = [honesty, _accuracy(plan, indices, card.relay_source, card.relay_observed_at)]
			statement.relay_content.append_array(transmission)
			statement.identity.append_array(transmission)
			statement.content.append_array(transmission)
		# A route discount describes hearing this original fact through this path;
		# it must not lower the original gift's accuracy on unrelated paths.
		if card.has("route_origin") or card.has("relay_source"):
			var key: String = "transmission:" + card.id
			var route = _channel(plan, indices, key, "transmission", card.get("relay_source", card.source))
			statement.identity.append(route)
			statement.content.append(route)
			statement.relay_identity.append(route)
			statement.relay_content.append(route)
		plan.statements.append(statement)
	return plan

## The original predicate, apart from its receipt/transmission metadata. A Medium
## visit has its own conditional constraint; it must not be attached a second time
## to the copied original. Payload fields used by the solver are retained.
static func _body(card: Dictionary) -> Dictionary:
	if card.kind == "report":
		return {"kind": "report", "source": card.source, "role": card.role,
			"data": Evidence.report_data(card.role, card.data), "observed_at": card.observed_at.duplicate(true),
			"night": card.get("night", card.observed_at.day if card.observed_at.phase == "night" else -1)}
	var body = card.duplicate(true)
	for field in ["id", "fact_id", "accuracy_origin", "logical_origin", "route_origin", "relay_source", "relay_role", "relay_observed_at", "acquired_day", "learned_at", "reported_at", "text", "provenance", "provenance_paths", "disclosures"]:
		body.erase(field)
	return body

static func _stamp(at: Dictionary) -> bool:
	return at.get("day", -1) >= 0 and at.get("phase", "") in ["morning", "afternoon", "evening", "night"]

static func _accuracy(plan: Dictionary, indices: Dictionary, source: String, at: Dictionary) -> int:
	var night: int = window(at)
	var index = _channel(plan, indices, "gift_accuracy:%s:%d" % [source, night], "gift_accuracy", source)
	plan.channels[index]["window"] = {"from": night * 4 + 3, "until": (night + 1) * 4 + 3}
	return index

static func _channel(plan: Dictionary, indices: Dictionary, key: String, kind: String, source: String) -> int:
	if not indices.has(key):
		indices[key] = plan.channels.size()
		plan.channels.append({"key": key, "kind": kind, "source": source})
	return indices[key]

## Constraints for one latent state, plus the original content IDs that state
## endorses. The caller still prices false contents by their report likelihoods.
static func materialize(plan: Dictionary, state: PackedByteArray) -> Dictionary:
	assert(state.size() == plan.channels.size())
	var result = {"cards": [], "accurate": [], "statements": []}
	var claims = {}
	var visits = {}
	var emitted = {}
	for statement in plan.statements:
		var card: Dictionary = statement.card
		result.statements.append(card.id)
		if card.get("quoted", false):
			result.cards.append(card.duplicate(true))
			continue
		if card.has("relay_source") and _all(state, statement.relay_identity):
			_add_claim(result.cards, claims, card.relay_source, "medium", card.relay_observed_at)
		if card.has("relay_source") and _all(state, statement.relay_content):
			# The Medium's faithful visit remains true even when the original gift's
			# content was inaccurate. Its role/route constraints are independent.
			var key: String = "%s:%s:%s" % [card.relay_source, card.source, str(card.relay_observed_at)]
			if not visits.has(key):
				visits[key] = true
				result.cards.append({"id": "channel-relay:" + key, "kind": "context", "source": card.source,
					"relay_source": card.relay_source, "relay_observed_at": card.relay_observed_at.duplicate(true)})
		if not _all(state, statement.content):
			if card.kind == "report" and _all(state, statement.identity):
				_add_claim(result.cards, claims, card.source, card.role, card.observed_at)
			continue
		if not emitted.has(statement.origin):
			emitted[statement.origin] = true
			var body: Dictionary = statement.body.duplicate(true)
			body["id"] = statement.origin
			body["fact_id"] = statement.origin
			result.cards.append(body)
		if card.id not in result.accurate:
			result.accurate.append(card.id)
	return result

static func _all(state: PackedByteArray, indices: Array) -> bool:
	return indices.all(func(index): return state[index] == 1)

static func _add_claim(cards: Array, claims: Dictionary, source: String, role: String, at: Dictionary) -> void:
	var key: String = "%s:%s:%s" % [source, role, str(at)]
	if claims.has(key):
		return
	claims[key] = true
	cards.append({"id": "channel-claim:" + key, "kind": "claim", "source": source, "role": role,
		"observed_at": at.duplicate(true), "data": {}})

## Independent latent channels, shared by every statement that names them. Fixed
## channels do not branch. A caller can evaluate states lazily if the plan is large.
static func states(plan: Dictionary, weights: Dictionary, prune_irrelevant: bool = true) -> Array:
	var result: Array = [{"state": PackedByteArray(), "weight": 1.0}]
	var uses: Array = []
	for statement in plan.statements:
		for field in ["identity", "content", "relay_identity", "relay_content"]:
			uses.append(statement[field])
	for index in range(plan.channels.size()):
		var channel: Dictionary = plan.channels[index]
		assert(weights.has(channel.key), "Missing channel prior: " + channel.key)
		var probability: float = float(weights[channel.key])
		assert(is_finite(probability) and probability >= 0.0 and probability <= 1.0)
		var next: Array = []
		for item in result:
			# Once an earlier required channel is false, later uncertainty that
			# affects only that same statement integrates to one. 255 means summed
			# out, never a claim that the channel was false. This is exact elimination.
			if prune_irrelevant and not uses.any(func(dependencies): return index in dependencies and dependencies.all(func(dependency): return dependency >= index or item.state[dependency] != 0)):
				var state: PackedByteArray = item.state.duplicate()
				state.append(255)
				next.append({"state": state, "weight": item.weight})
				continue
			for value in [0, 1]:
				var weight: float = probability if value == 1 else 1.0 - probability
				if weight <= 0.0:
					continue
				var state: PackedByteArray = item.state.duplicate()
				state.append(value)
				next.append({"state": state, "weight": item.weight * weight})
		result = next
	return result
