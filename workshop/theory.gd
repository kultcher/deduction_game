## A defeasible partial theory, separate from certainty and source credibility.
extends RefCounted
const Solver = preload("res://workshop/solver.gd")

static func prepare(view: Dictionary, value: Dictionary, listener: Dictionary, reasoning: Dictionary, input_key: String) -> Dictionary:
	var result = {"mode": listener.get("confidence_mode", "scale"), "status": "scale", "bias": {}, "position": "", "before": "", "threshold": 0.0,
		"note": "Confidence scales the incoming effect; no theory persistence is applied.",
		"guardrail": "Commitment changes hypothesis ranking only; source and reading reliability are not changed."}
	if result.mode != "persistence":
		return result
	if not listener.has("theories"):
		listener.theories = {}
	# A fixed or unchanged decision never reads the reasoning; callers can check
	# this first (cached) and skip the explanation search entirely.
	var hit: Dictionary = cached(view, value, listener, input_key)
	if not hit.is_empty():
		return hit
	input_key = _stored_key(view, input_key)
	var target: String = value.conclusion.target
	var key: String = _key(value)
	var old: Dictionary = listener.theories.get(key, {}).duplicate(true)
	result.before = old.get("position", "")
	result.threshold = 1.0 + 4.0 * listener.confidence
	var candidate: Dictionary = reasoning.support
	var candidate_score: float = reasoning.support_score
	var other: Dictionary = reasoning.rival
	var other_score: float = reasoning.rival_score
	if candidate.is_empty() or (not other.is_empty() and other_score > candidate_score):
		candidate = reasoning.rival
		candidate_score = reasoning.rival_score
		other = reasoning.support
		other_score = reasoning.support_score
	var position = _position(view, candidate, target, value.conclusion.type, value.conclusion.at)
	var status = "adopted"
	var apply_bias = false
	if reasoning.private_checks.fatal:
		position = "good" if target in listener.knowledge.get("good", []) else ""
		status = "private_fact"
	elif not reasoning.has_evidence:
		position = old.get("position", "")
		status = "unsupported"
	elif position == "":
		position = old.get("position", "")
		status = "unresolved"
	elif not old.is_empty() and old.get("position", "") != "":
		if position == old.position:
			status = "retained"
			apply_bias = true
		else:
			var certified: bool = value.positions.is_empty() and value.answers.is_empty() and value.get("temporal_positions", []).is_empty() and ((reasoning.support.is_empty() and reasoning.support_exhausted) or (reasoning.rival.is_empty() and reasoning.rivals_exhausted))
			var old_score = other_score
			var strong: bool = old_score > 0.0 and candidate_score / old_score >= result.threshold
			if certified or strong or (old_score == 0.0 and listener.confidence < 0.34):
				status = "revised"
			else:
				position = old.position
				status = "retained"
				apply_bias = true
	result.position = position
	result.status = status
	if apply_bias and position in ["evil", "good", "marked", "unmarked"]:
		result.bias = {"target": target, "position": position, "factor": pow(3.0, listener.confidence)}
	result.note = {"adopted": "I have a provisional working theory; other explanations can remain possible.",
		"retained": "I am holding my earlier theory. The new comparison has not outweighed that commitment.",
		"revised": "The contrary evidence changed my working theory.",
		"private_fact": "My firsthand knowledge overrides the proposed theory.",
		"unresolved": "I did not resolve a new explanation; my old theory is not a proof.",
		"unsupported": "No presented evidence supports an additional case effect. The earlier theory supplies no new evidence."}.get(status, "")
	listener.theories[key] = {"position": position, "input_key": input_key, "decision": result.duplicate(true),
		"shortlist": [reasoning.support.duplicate(true), reasoning.rival.duplicate(true)], "epoch": value.conclusion.at}
	return result

## The decision prepare() would return without reading any reasoning: a fixed
## decision (a scoped reply uses the union's commitment) or an unchanged input.
## Empty when prepare() would need the explanation search. Read-only.
static func cached(view: Dictionary, value: Dictionary, listener: Dictionary, input_key: String) -> Dictionary:
	if listener.get("confidence_mode", "scale") != "persistence":
		return {}
	var key: String = _key(value)
	if value.conclusion.type in ["evil", "good", "suspicious", "marked", "demon", "minion"] and listener.get("fixed_theory_decisions", {}).has(key):
		return listener.fixed_theory_decisions[key].duplicate(true)
	var old: Dictionary = listener.get("theories", {}).get(key, {})
	if old.get("input_key", "") == _stored_key(view, input_key):
		var result: Dictionary = old.decision.duplicate(true)
		if not Solver.Domain.live(view):
			result.status = "unchanged"
		return result
	return {}

## Live minds retain a theory per person. Store a compact deterministic signature
## rather than duplicating the entire evidence/belief JSON in each.
static func _stored_key(view: Dictionary, input_key: String) -> String:
	return input_key.sha256_text() if Solver.Domain.live(view) else input_key

## Alignment and Marked are different questions. Alignment theories are shared
## across accusing and defending the same person, not stored as opposing claims.
static func _key(value: Dictionary) -> String:
	var key: String = value.conclusion.target + "|" + value.conclusion.at
	if value.conclusion.type == "marked":
		key += "|marked"
	elif value.conclusion.type in ["demon", "minion"]:
		key += "|" + value.conclusion.type
	return key

static func _position(view: Dictionary, world: Dictionary, target: String, type: String, epoch: String) -> String:
	if world.is_empty():
		return ""
	var index: int = Solver.person_index(view, target)
	if type == "marked":
		return "marked" if world.marked == index else "unmarked"
	if type in ["demon", "minion"]:
		return type if Solver.position_holds(view, world, target, type, epoch) else "not" + type
	return "evil" if Solver.position_holds(view, world, target, "evil", epoch) else "good"
