## Legal live alignment/modifier possibilities, derived solely from public setup rules.
## Fixture domains stay unchanged. This is a domain, never a list of referee survivors.
extends RefCounted
const C = preload("res://sim/content.gd")
static var cache = {}
static var _cached_people = null
static var _cached_idx: Dictionary = {}

static func _person_index(view: Dictionary, id: String) -> int:
	if view.people != _cached_people:
		_cached_people = view.people.duplicate(true)
		_cached_idx = {}
		for i in range(view.people.size()):
			_cached_idx[view.people[i].id] = i
	return _cached_idx.get(id, -1)

static func live(view: Dictionary) -> bool:
	return view.has("world_options")

static func worlds(view: Dictionary) -> Array:
	var input = [view.people.map(func(p): return p.id), view.evil_count, view.world_options]
	var key = hash(input)
	if cache.has(key) and cache[key].input == input:
		return cache[key].worlds
	var result: Array = []
	var n: int = view.people.size()
	for evil in range(1 << n):
		if _count(evil) != view.evil_count:
			continue
		for kind in view.world_options.modifiers:
			for i in range(n):
				if evil & (1 << i):
					continue
				if kind != "lovers":
					var w = {"evil": evil, "marked": i if kind == "marked" else -1, "modifier": kind, "holders": 1 << i}
					w["__key"] = key(view, w)
					w["__i"] = result.size()
					result.append(w)
				else:
					for j in range(i + 1, n):
						if not evil & (1 << j):
							var w = {"evil": evil, "marked": -1, "modifier": kind, "holders": (1 << i) | (1 << j)}
							w["__key"] = key(view, w)
							w["__i"] = result.size()
							result.append(w)
	if cache.size() >= 16:
		cache.clear()
	if view.world_options.get("identities", false):
		var expanded: Array = []
		for world in result:
			for i in range(n):
				if world.evil & (1 << i):
					var candidate: Dictionary = world.duplicate()
					candidate["demon"] = i
					candidate["__key"] = key(view, candidate)
					candidate["__i"] = expanded.size()
					expanded.append(candidate)
		result = expanded
	cache[key] = {"input": input.duplicate(true), "worlds": result}
	return result

static func key(view: Dictionary, world: Dictionary) -> int:
	var n: int = view.people.size()
	var base: int = ((int(world.evil) * (n + 1) + int(world.marked) + 1) * 4 + C.SECRET_MOD_LIST.find(world.modifier)) * (1 << n) + int(world.holders)
	return base * (n + 1) + world.demon + 1 if world.has("demon") else base

static func claims_compatible(cards: Array, knowledge: Dictionary) -> bool:
	var sources = {}
	var roles = {}
	for card in cards:
		if card.kind not in ["report", "claim"] or card.get("quoted", false):
			continue
		if sources.has(card.source) and sources[card.source] != card.role:
			return false
		if roles.has(card.role) and roles[card.role] != card.source:
			return false
		if card.source == knowledge.get("self") and knowledge.get("own_role", card.role) != card.role:
			return false
		if card.source != knowledge.get("self") and card.role == knowledge.get("own_role", ""):
			return false
		sources[card.source] = card.role
		roles[card.role] = card.source
	return true

static func healthy(view: Dictionary, world: Dictionary, source: String) -> bool:
	var i: int = _person_index(view, source)
	if i < 0:
		return false
	return world.get("modifier", "marked") != "delusional" or not (world.get("holders", 0) & (1 << i))

static func gift_time(card: Dictionary) -> bool:
	if card.role in ["martyr", "sexton"]:
		return card.observed_at.day >= 1 and card.observed_at.phase in ["evening", "night"]
	if card.role in ["surveyor", "rumormonger", "clerk", "archivist"]:
		return card.observed_at.day == 0 and card.observed_at.phase == "night"
	if card.role in ["seer", "nightwatch", "gravedigger", "veteran", "lamplighter", "medium", "psychologist"]:
		return card.observed_at.day >= 0 and card.observed_at.phase == "night"
	return card.role == "dowser" and card.observed_at.day >= 1 and card.observed_at.phase in ["morning", "afternoon", "evening"]

static func rumor(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	var source: int = _person_index(view, card.source)
	# The native gift excludes itself. With no other modifier holder, even a healthy
	# Rumormonger receives an arbitrary pair/secret fallback. Keep that legal world;
	# it cannot establish the reported pair or secret type.
	if source >= 0 and (world.holders & ~(1 << source)) == 0:
		return card.data.secret in C.SECRET_MOD_LIST and card.data.pair.all(func(id): return id != card.source) and answer.get("positive", []).is_empty()
	if world.modifier != card.data.secret:
		return false
	var pair_mask: int = 0
	for id in card.data.pair:
		var idx = _person_index(view, id)
		if idx >= 0:
			pair_mask |= (1 << idx)
	if not (world.holders & pair_mask):
		return false
	var ans_pos = answer.get("positive", [])
	if not ans_pos.is_empty():
		var ans_mask: int = 0
		for id in ans_pos:
			var idx = _person_index(view, id)
			if idx >= 0:
				ans_mask |= (1 << idx)
		if (world.holders & ans_mask) != ans_mask:
			return false
	return true

static func _count(value: int) -> int:
	var result = 0
	while value:
		value &= value - 1
		result += 1
	return result
