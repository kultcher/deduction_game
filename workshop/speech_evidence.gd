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
	return by_person.values()
