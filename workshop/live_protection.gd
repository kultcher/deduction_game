## Circumstantial quiet-night support, not an inferred attack or a role proof.
extends RefCounted
const Challenges = preload("res://workshop/reading_challenges.gd")

static func assess(view: Dictionary, cards: Array, listener: Dictionary) -> Dictionary:
	var result = {}
	if not view.get("live_activity", false):
		return result
	var quiets: Array = cards.filter(func(c): return c.kind == "quiet" and not c.get("quoted", false))
	var counted: Array = []
	for quiet in quiets:
		if quiet.night in counted:
			continue
		counted.append(quiet.night)
		var claims: Array = cards.filter(func(c): return not c.get("quoted", false) and ((c.kind == "claim" and c.role in ["warden", "veteran"]) or (c.kind == "report" and c.role == "veteran" and c.night == quiet.night)))
		var people: Array = []
		for claim in claims:
			if claim.source not in people:
				people.append(claim.source)
		for person in people:
			var person_claims: Array = claims.filter(func(c): return c.source == person)
			var role: String = person_claims[0].role
			var source_quality: float = Challenges.quality(listener, person)
			var weight: float = (0.06 if role == "warden" else 0.025) * source_quality / maxf(people.size(), 1)
			if quiet.get("ward", "") != "":
				weight *= 0.5 # the player's ward is an explicit competing explanation
			if view.get("timeline", {}).get("events", []).any(func(e): return e.kind == "knell" and e.at.day == quiet.night):
				weight *= 0.4
			if not result.has(person):
				result[person] = {"weight": 0.0, "nights": [], "role": role, "cards": []}
			# Only the first failed attack can validate a Veteran's survival gift.
			if role == "veteran" and not result[person].nights.is_empty():
				continue
			result[person].weight = minf(result[person].weight + weight, 0.10)
			result[person].nights.append(quiet.night)
			result[person].cards.append(quiet.id)
			result[person].cards.append_array(person_claims.map(func(c): return c.id))
	return result

static func owns(entry: Dictionary, cards: Array) -> bool:
	# Exact legacy mechanism, night and claimant. Never absorb other proof effects.
	var meta: Dictionary = entry.get("meta", {})
	if meta.get("kind") not in ["proof", "quiet_night"]:
		return false
	for quiet in cards.filter(func(c): return c.kind == "quiet"):
		for claim in cards.filter(func(c): return c.kind == "claim" and c.role in ["warden", "veteran"] or c.kind == "report" and c.get("role") == "veteran"):
			if entry.get("eid") != "quiet:%d>%s" % [quiet.night, claim.source] or entry.get("rel", []) != [claim.source, -1, "report"]:
				continue
			var expected: float = -0.15 if claim.role == "warden" else -0.06
			var effects: Array = entry.get("effects", [])
			if effects.size() == 1 and effects[0][0] == claim.source and is_equal_approx(float(effects[0][1]), expected):
				return true
	return false
