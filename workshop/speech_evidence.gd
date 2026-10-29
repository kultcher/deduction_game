## Ordinary speech is fallible context, never a healthy-gift assertion.
## Refusals are evaluated exclusively in Stage 2 (`workshop/circumstantial.gd`);
## Stage 1 speech factors cover only tentative gift-family hints and contradictions.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")

const REFUSAL_LR = Tuning.Workshop.REFUSAL_LR

static func factors(cards: Array) -> Array:
	var result: Array = []
	var hints = {}
	for card in cards:
		if card.kind != "gift_hint" or card.get("quoted", false):
			continue
		if not hints.has(card.subject):
			hints[card.subject] = {"roles": card.data.roles.duplicate(), "cards": []}
		var hint: Dictionary = hints[card.subject]
		hint.roles = hint.roles.filter(func(role): return role in card.data.roles)
		if card.id not in hint.cards:
			hint.cards.append(card.id)
	for person in hints:
		var hint: Dictionary = hints[person]
		var contradictory: bool = hint.roles.is_empty() or cards.any(func(c): return not c.get("quoted", false) and c.source == person and c.kind in ["claim", "report"] and c.get("role", "") not in hint.roles)
		# A tentative good-gift family claim is weak support for that claim, never
		# a specific healthy role assertion. Incompatible declarations instead
		# weakly undermine it. All retellings share this one testimony factor.
		result.append({"target": person, "log2_ratio": (1.0 if contradictory else -1.0) * log(REFUSAL_LR) / log(2.0),
			"label": ("Incompatible gift hint: " if contradictory else "Tentative gift-family claim: ") + person,
			"origin": "speech_evidence", "cards": hint.cards.duplicate(), "possible_roles": hint.roles.duplicate()})
	return result
