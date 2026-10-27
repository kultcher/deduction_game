## Presentation of the live adapter's existing context/location classification.
## Ward/sigil are explicitly context pending Claude's adapter (batch 3). No evaluator runs here.
extends RefCounted
const Live = preload("res://game/workshop_canvas.gd")
const EXPLANATION = "Context: background or location information. This card cannot establish guilt on its own."

static func is_context(adapter: Dictionary) -> bool:
	return adapter.get("kind", "") in ["context", "location", "ward", "scorched_sigil"]

## Once per library refresh, never once per card or draw frame.
static func numbers(g) -> Dictionary:
	var originals = {}
	for card in g.board:
		if card.get("kind", "") != "deduction" and not card.get("deleted", false):
			originals[Live.Evidence.normalize_card(card).id] = card.n
	var result = {}
	for adapter in Live.view(g).cards:
		if is_context(adapter) and originals.has(adapter.id):
			result[originals[adapter.id]] = true
	return result
