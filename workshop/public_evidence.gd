## Public observations and witnessed facts. No referee state is read.
extends RefCounted
const Evidence = preload("res://workshop/live_evidence.gd")

const DEMON_VICTIM_GOOD = 0.95

static func martyr_receipts(events: Array, ids: Array) -> Array:
	var receipts = {}
	for event in events:
		var subjects: Array = event.get("subjects", [])
		var actor: String = event.get("by", "")
		var day: int = event.get("at", {}).get("day", -1)
		if event.get("kind") != "martyr" or day < 1 or subjects.size() != 2 or subjects[0] == subjects[1] or actor not in subjects or not subjects.all(func(id): return id in ids):
			continue
		var saved: String = subjects[1] if subjects[0] == actor else subjects[0]
		var receipt = Evidence.normalize_card({"kind": "martyr", "source": "player", "subject": [actor, saved], "martyr": actor, "saved": saved,
			"day": day, "phase": 2, "text": "A public Martyr substitution."})
		receipts[receipt.id] = receipt
	return receipts.values()

static func known_good(events: Array, ids: Array) -> Array:
	var result: Array = []
	for receipt in martyr_receipts(events, ids):
		for person in receipt.subjects:
			if person not in result:
				result.append(person)
	return result

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
			"key": "demon_death:" + person, "label": "Killed by the Demon: " + person, "cards": []})
	# Convert the existing -.12 alignment contribution at the native .3 reference
	# prior to a finite likelihood ratio. Rehearing an event is not a new silence.
	var prior = 0.3
	var posterior = prior * (1.0 - 0.12 / 0.45)
	var ratio = (posterior / (1.0 - posterior)) / (prior / (1.0 - prior))
	var seen = {}
	for event in events:
		var day: int = event.get("at", {}).get("day", -1)
		if event.get("kind") != "silenced" or day < 1:
			continue
		for person in event.get("subjects", []):
			var key = "silenced:%s:%d" % [person, day]
			if seen.has(key) or not view.people.any(func(p): return p.id == person):
				continue
			seen[key] = true
			result.append({"target": person, "log2_ratio": log(ratio) / log(2.0),
				"epoch": view.get("alignment_epoch", ""), "origin": "public_evidence",
				"key": key, "label": "Silenced at the meeting: " + person, "cards": []})
	return result

## Transitional native ledger uses the same finite odds update and the existing
## alignment contribution coefficient. The shared owner retracts this entry.
static func victim_effect(prior: float) -> float:
	prior = clampf(prior, 0.02, 0.98)
	var odds = prior / (1.0 - prior) * victim_ratio()
	var posterior = odds / (1.0 + odds)
	return 0.45 * (posterior - prior) / prior
