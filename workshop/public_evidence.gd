## Public observations with finite alignment weight. No referee state is read.
extends RefCounted

const DEMON_VICTIM_GOOD = 0.95

static func demon_victims(events: Array, ids: Array) -> Array:
	var result: Array = []
	for event in events:
		if event.get("kind") != "demon_death" or event.get("at", {}).get("day", -1) < 1:
			continue
		for person in event.get("subjects", []):
			if person in ids and person not in result:
				result.append(person)
	return result

## 95:5 support for innocence, expressed as an odds multiplier. Setup rules,
## private knowledge and other evidence still determine the final probability.
static func victim_ratio() -> float:
	return (1.0 - DEMON_VICTIM_GOOD) / DEMON_VICTIM_GOOD

static func factors(view: Dictionary) -> Array:
	var events: Array = view.get("timeline", {}).get("events", [])
	var result: Array = []
	for person in demon_victims(events, view.people.map(func(p): return p.id)):
		result.append({"target": person, "log2_ratio": log(victim_ratio()) / log(2.0),
			"epoch": view.get("alignment_epoch", ""), "origin": "public_evidence",
			"label": "Killed by the Demon: " + person, "cards": []})
	return result

## Transitional native ledger uses the same finite odds update and the existing
## alignment contribution coefficient. The shared owner retracts this entry.
static func victim_effect(prior: float) -> float:
	prior = clampf(prior, 0.02, 0.98)
	var odds = prior / (1.0 - prior) * victim_ratio()
	var posterior = odds / (1.0 + odds)
	return 0.45 * (posterior - prior) / prior
