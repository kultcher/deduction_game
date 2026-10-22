## Legal live alignment/modifier possibilities, derived solely from public setup rules.
## Fixture domains stay unchanged. This is a domain, never a list of referee survivors.
extends RefCounted
const C = preload("res://sim/content.gd")
static var cache = {}

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
					result.append({"evil": evil, "marked": i if kind == "marked" else -1, "modifier": kind, "holders": 1 << i})
				else:
					for j in range(i + 1, n):
						if not evil & (1 << j):
							result.append({"evil": evil, "marked": -1, "modifier": kind, "holders": (1 << i) | (1 << j)})
	if cache.size() >= 16:
		cache.clear()
	cache[key] = {"input": input.duplicate(true), "worlds": result}
	return result

static func key(view: Dictionary, world: Dictionary) -> int:
	var n: int = view.people.size()
	return ((int(world.evil) * (n + 1) + int(world.marked) + 1) * 4 + C.SECRET_MOD_LIST.find(world.modifier)) * (1 << n) + int(world.holders)

static func claims_compatible(cards: Array, knowledge: Dictionary) -> bool:
	var sources = {}
	var roles = {}
	for card in cards:
		if card.kind != "report":
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
	var i: int = view.people.map(func(p): return p.id).find(source)
	if i < 0:
		return false
	return world.modifier != "delusional" or not world.holders & (1 << i)

static func gift_time(card: Dictionary) -> bool:
	if card.role in ["surveyor", "rumormonger"]:
		return card.observed_at.day == 0 and card.observed_at.phase == "night"
	return card.role == "dowser" and card.observed_at.day >= 1 and card.observed_at.phase in ["morning", "afternoon", "evening"]

static func rumor(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	var ids: Array = view.people.map(func(p): return p.id)
	var source: int = ids.find(card.source)
	# The native gift excludes itself. With no other modifier holder, even a healthy
	# Rumormonger receives an arbitrary pair/secret fallback. Keep that legal world;
	# it cannot establish the reported pair or secret type.
	if source >= 0 and (world.holders & ~(1 << source)) == 0:
		return card.data.secret in C.SECRET_MOD_LIST and card.data.pair.all(func(id): return id != card.source) and answer.get("positive", []).is_empty()
	if world.modifier != card.data.secret:
		return false
	return card.data.pair.any(func(id): return world.holders & (1 << ids.find(id))) and answer.get("positive", []).all(func(id): return world.holders & (1 << ids.find(id)))

static func _count(value: int) -> int:
	var result = 0
	while value:
		value &= value - 1
		result += 1
	return result
