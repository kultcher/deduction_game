## Ordinary speech is fallible context, never a healthy-gift assertion.
extends RefCounted

## The existing evaluator's lower threshold for weak evidence. Fear preserves
## the native .25/.35 relative reduction, without treating fear as exoneration.
const REFUSAL_LR = 1.5

static func factors(cards: Array) -> Array:
	var by_person = {}
	for card in cards:
		if card.kind != "refusal" or card.get("quoted", false):
			continue
		var ratio = pow(REFUSAL_LR, 0.25 / 0.35) if card.data.get("fear", false) else REFUSAL_LR
		if not by_person.has(card.subject):
			by_person[card.subject] = {"target": card.subject, "log2_ratio": 0.0,
				"label": "Withheld testimony: " + card.subject, "origin": "speech_evidence", "cards": []}
		# A person's continuing reluctance is one explanation, not independent
		# evidence every time someone asks. Use their strongest attended refusal.
		var factor: Dictionary = by_person[card.subject]
		factor.log2_ratio = maxf(factor.log2_ratio, log(ratio) / log(2.0))
		if card.id not in factor.cards:
			factor.cards.append(card.id)
	var result: Array = by_person.values()
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
