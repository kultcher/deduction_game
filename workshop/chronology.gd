## Public fixture chronology. No actual converted identity or hidden poison target
## is read here. A selected fault remains a hypothesis unless evidence supports it.
extends RefCounted
const C = preload("res://sim/content.gd")
const Domain = preload("res://workshop/world_domain.gd")

static func tick(stamp: Dictionary) -> int:
	var phase: String = str(stamp.get("phase", "day"))
	return int(stamp.get("day", 0)) * 4 + {"morning": 0, "day": 1, "afternoon": 1, "evening": 2, "night": 3}.get(phase, 1)

static func epochs(view: Dictionary) -> Array:
	return view.get("chronology", {}).get("epochs", {view.alignment_epoch: 0}).keys()

static func expand(view: Dictionary, world: Dictionary) -> Array:
	if not view.get("chronology", {}).has("curse"):
		return [world]
	var curse: Dictionary = view.chronology.curse
	var ids: Array = view.people.map(func(p): return p.id)
	if not world.evil & (1 << ids.find(curse.executed)):
		return [] # Public activation identifies the executed evil Revenant.
	var result: Array = []
	for candidate in curse.yes_voters:
		var index: int = ids.find(candidate)
		if candidate not in curse.alive or candidate == curse.executed or index < 0 or world.evil & (1 << index):
			continue
		var alternative = world.duplicate(true)
		alternative["converted"] = index
		result.append(alternative)
	return result

static func evil_at(view: Dictionary, world: Dictionary, person: String, at) -> bool:
	var index: int = view.people.map(func(p): return p.id).find(person)
	return evil_index(view, world, index, at)

static func evil_index(view: Dictionary, world: Dictionary, index: int, at) -> bool:
	if index < 0:
		return false
	if world.evil & (1 << index):
		return true
	if not world.has("converted") or world.converted != index:
		return false
	var time: int = tick(at) if at is Dictionary else int(view.chronology.epochs.get(at, -1))
	var curse: Dictionary = view.chronology.curse
	return time >= curse.from and time < curse.until

static func key(view: Dictionary, world: Dictionary) -> int:
	if Domain.live(view):
		return Domain.key(view, world)
	var n: int = view.people.size()
	return (world.evil * n + world.marked) * (n + 1) + world.get("converted", -1) + 1

static func known_good(view: Dictionary, knowledge: Dictionary, person: String, epoch: String) -> bool:
	if person not in knowledge.get("good", []):
		return false
	return not view.get("chronology", {}).has("curse") or epoch != "during curse" or knowledge.get("good_epoch", epoch) == epoch

static func source_key(view: Dictionary, card: Dictionary) -> String:
	if not view.has("chronology"):
		return "source:" + card.source
	var interval = "ordinary"
	var curse: Dictionary = view.chronology.get("curse", {})
	var reported: int = tick(card.get("reported_at", card.observed_at))
	if not curse.is_empty():
		interval = "before" if reported < curse.from else ("during" if reported < curse.until else "restored")
	return "source:%s:%s" % [card.source, interval]

static func valid_fault(view: Dictionary, fault) -> bool:
	if not fault is Dictionary or fault.get("type") != "poisoned" or not fault.get("window") is String:
		return false
	return view.get("chronology", {}).get("poison_windows", {}).has(fault.window)

static func fault_for(view: Dictionary, value: Dictionary, card: Dictionary) -> Dictionary:
	if card.kind != "report":
		return {}
	for fault in value.get("faults", {}).values():
		if not valid_fault(view, fault):
			continue
		var window: Dictionary = view.chronology.poison_windows[fault.window]
		var observed: int = tick(card.observed_at)
		if card.source == window.subject and observed >= window.from and observed < window.until:
			return {"key": "healthy:" + fault.window, "basis": fault.get("basis", ""), "window": window}
	return {}

static func hypothetical_cards(view: Dictionary, value: Dictionary, cards: Array) -> Array:
	# For the PLAYER'S conditional explanation only. Numeric NPC conviction still
	# averages healthy/broken credibility states and requires actual supporting input.
	return cards.filter(func(card): return fault_for(view, value, card).is_empty())

static func disowned(view: Dictionary, card: Dictionary, known_events: Array) -> bool:
	# A public withdrawal must actually be in the listener's permitted knowledge.
	for event in view.get("chronology", {}).get("withdrawals", []):
		if event.card in known_events and card.id in event.reports:
			return true
	return false

static func restore_cover(cover: Dictionary, view: Dictionary = {}) -> Dictionary:
	# Only explicitly permitted workshop fields cross the boundary. Evil-only intel,
	# role truth and real-mind memories cannot be accidentally copied by this adapter.
	var result = {}
	for field in ["id", "name", "preset", "trust", "confidence", "insight", "reasoning_mode", "confidence_mode", "npc_trust", "suspicion", "reading_reliability", "knowledge", "ledger", "case_memory", "theories"]:
		if cover.has(field):
			result[field] = cover[field].duplicate(true) if cover[field] is Dictionary or cover[field] is Array else cover[field]
	if result.has("knowledge"):
		var withdrawn: Array = []
		for event in view.get("chronology", {}).get("withdrawals", []):
			if event.card in result.knowledge.get("known_events", []):
				withdrawn.append_array(event.reports)
		result.knowledge.own_reports = result.knowledge.get("own_reports", []).filter(func(id): return id not in withdrawn)
	return result
