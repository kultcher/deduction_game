## The movement gate for the judge: which cards are movement evidence, which
## citations count, and the movement factors. The weighing itself lives in
## workshop/live_activity.gd; with no live activity there are no movement factors.
extends RefCounted
const Live = preload("res://workshop/live_activity.gd")

static func available(view: Dictionary) -> bool:
	return Live.available(view)

static func claim_refs(view: Dictionary, value: Dictionary) -> Array:
	if not available(view):
		return []
	return value.get("citations", {}).values()

static func evidence(view: Dictionary, cards: Array) -> Array:
	return cards.filter(func(c): return c.kind in ["sighting", "coverage", "evening", "trace"] or (c.kind == "alibi" and c.get("quoted", false)) or c.get("role") == "nightwatch") if available(view) else []

static func factors(view: Dictionary, cards: Array, value: Dictionary) -> Array:
	if Live.available(view):
		return Live.factors(view, cards, value)
	return []
