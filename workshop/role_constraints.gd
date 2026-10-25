## Joint role completions and a persistent Red Herring, without full permutations.
extends RefCounted
const C = preload("res://sim/content.gd")
const Activity = preload("res://workshop/live_activity.gd")
static var cache: Dictionary = {}
static var reuse = true

static func fits(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary = {}) -> bool:
	if not view.get("world_options", {}).get("roles", false):
		return true
	var ids: Array = view.people.map(func(p): return p.id)
	if not reuse:
		return _fits_view(view, ids, world, cards, knowledge, answers)
	var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), cards, knowledge.get("self"), knowledge.get("own_role"), knowledge.get("own_outings", {}), answers, knowledge.get("public_roles", {})]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 64:
			cache.clear()
		cache[key] = {"input": input.duplicate(true), "results": {}, "seer": seer_flag(cards)}
	var mask: int = coarse_mask(ids.size(), world, cache[key].seer, cards.any(func(c): return c.has("relay_source")))
	if not cache[key].results.has(mask):
		cache[key].results[mask] = _fits_view(view, ids, world, cards, knowledge, answers)
	return cache[key].results[mask]

## fits() for every world of a universe, hashing the view and cards once rather than
## per world. Same memo as fits(), so the results agree.
## Weight of one role declaration (claim, or a reading's implied gift) by a source who
## is evil in that world: a bluff is possible, but naming this exact role is a choice
## among several, so a claim still weakly supports its claimant (live play only).
const BLUFF_WEIGHT = 0.35

## bluffs (live play): evil sources' role declarations constrain nothing; see _fits.
static func fits_table(view: Dictionary, universe: Array, cards: Array, knowledge: Dictionary, answers: Dictionary = {}, bluffs: bool = false) -> PackedByteArray:
	var out = PackedByteArray()
	out.resize(universe.size())
	if not view.get("world_options", {}).get("roles", false):
		out.fill(1)
		return out
	var ids: Array = view.people.map(func(p): return p.id)
	var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), cards, knowledge.get("self"), knowledge.get("own_role"), knowledge.get("own_outings", {}), answers, knowledge.get("public_roles", {}), bluffs]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 64:
			cache.clear()
		cache[key] = {"input": input.duplicate(true), "results": {}, "seer": seer_flag(cards)}
	var entry: Dictionary = cache[key]
	var results: Dictionary = entry.results
	var seer: bool = entry.seer
	var relay: bool = cards.any(func(c): return c.has("relay_source"))
	var routes = null
	for i in range(universe.size()):
		var world: Dictionary = universe[i]
		var mask: int = coarse_mask(ids.size(), world, seer, relay)
		if not results.has(mask):
			# Relays add Medium claims per world before routing: no hoist then.
			if routes == null and not relay and Activity.available(view):
				routes = Activity.routes(view, cards, answers, knowledge)
			results[mask] = _fits_view(view, ids, world, cards, knowledge, answers, routes, bluffs)
		out[i] = 1 if results[mask] else 0
	return out

## The parts of a world the role check reads, as one int: fits() gives the same answer
## for worlds with the same mask (for the same view, cards and knowledge).
static func coarse_mask(people: int, world: Dictionary, seer: bool, relay: bool) -> int:
	var n: int = people + 1
	var mask: int = (int(world.evil) * n + int(world.get("demon", -1)) + 1) * n + (int(world.marked) + 1 if seer else 0)
	if relay:
		mask = (mask * (1 << people) + int(world.get("holders", 0))) * 2 + int(world.get("modifier") == "delusional")
	return mask

## The seer flag fits() keys its memo on.
static func seer_flag(cards: Array) -> bool:
	return cards.any(func(c): return c.get("role") in ["seer", "gravedigger", "martyr"] and not c.get("quoted", false))

## routes: Activity.routes(view, cards, answers, knowledge) if already computed. It
## doesn't depend on the world, so fits_table computes it once for all worlds.
static func _fits_view(view: Dictionary, ids: Array, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary, routes = null, bluffs: bool = false) -> bool:
	cards = cards.duplicate()
	var visits = {}
	for card in cards.duplicate():
		if card.has("relay_source") and not card.get("quoted", false):
			var medium: int = ids.find(card.relay_source)
			if medium < 0 or world.evil & (1 << medium) or not preload("res://workshop/world_domain.gd").healthy(view, world, card.relay_source) or not preload("res://workshop/live_history.gd").alive_at_night(view, card.relay_source, card.relay_observed_at.day):
				return false
			var visit: String = card.relay_source + ":" + card.source
			if visits.has(visit) and visits[visit] != card.relay_observed_at.day:
				return false
			visits[visit] = card.relay_observed_at.day
			cards.append({"kind": "claim", "source": card.relay_source, "role": "medium", "inferred": true})
	var sexton_night = -1
	for card in cards:
		if card.kind != "report" or card.get("quoted", false):
			continue
		if card.role == "martyr" and card.data.get("evil", false) and not preload("res://workshop/live_history.gd").executed(view, card.data.target, card.observed_at.day):
			return false
		if card.role == "sexton":
			if sexton_night >= 0 and sexton_night != card.data.night:
				return false
			sexton_night = card.data.night
	if sexton_night >= 0:
		if view.people.filter(func(p): return preload("res://workshop/live_history.gd").alive_at_night(view, p.id, sexton_night)).size() >= 5:
			return false
		if view.get("timeline", {}).get("events", []).any(func(e): return e.kind == "demon_death" and e.at.day == sexton_night):
			return false
		for card in cards:
			if card.get("quoted", false):
				continue
			if card.kind == "report" and card.role in ["nightwatch", "lamplighter", "medium"] and card.get("night", -1) == sexton_night:
				return false
			if card.has("relay_source") and card.relay_observed_at.day == sexton_night:
				return false
	for card in cards:
		if card.get("role") != "veteran" or card.kind != "report" or card.get("quoted", false):
			continue
		var demon: int = world.get("demon", -1)
		if demon < 0:
			return false
		var path: Array = C.route(view.people[demon].home, view.people[ids.find(card.source)].home)
		var approach: String = path[path.size() - 2] if path.size() >= 2 else view.people[ids.find(card.source)].home
		if approach != card.data.block or view.get("timeline", {}).get("events", []).any(func(e): return e.kind == "demon_death" and e.at.day == card.night):
			return false
	var live: bool = bluffs
	if Activity.available(view):
		if routes == null:
			routes = Activity.routes(view, cards, answers, knowledge)
		# Live testimony can be false (an evil fake sighting, a lying alibi): routes that
		# can't all hold no longer void every world; the movement likelihood weighs them.
		if not routes.okay and not live:
			return false
		if routes.okay:
			cards = cards.duplicate()
			for person in routes.forced_lamp:
				cards.append({"kind": "claim", "source": person, "role": "lamplighter", "inferred": true})
	return _fits(ids, world, cards, knowledge, answers, live)

## bluffs (live play): in a world where a claim's source is evil, the claim is a bluff:
## it occupies no role and constrains nothing. A good source's claim stays binding, so a
## contradiction leaves only the worlds where some claimant is lying.
static func _fits(ids: Array, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary, bluffs: bool = false) -> bool:
	var all: int = (1 << ids.size()) - 1
	var good: int = all & ~world.evil
	var demon: int = world.get("demon", -1)
	var minions: int = world.evil & ~(1 << demon) if demon >= 0 else world.evil
	var assignments = {}
	var own: int = ids.find(knowledge.get("self", ""))
	if own >= 0 and knowledge.get("own_role", "") in C.ROLES:
		assignments[knowledge.own_role] = 1 << own
	for person in knowledge.get("public_roles", {}):
		var index: int = ids.find(person)
		var role: String = knowledge.public_roles[person]
		if index < 0 or world.evil & (1 << index) or not _assign(assignments, role, 1 << index):
			return false
	var seer = ""
	var veteran_night = -1
	var martyr_target = ""
	var rh: int = good
	for card in cards:
		if card.get("quoted", false):
			continue
		if card.kind == "totem":
			var candidates = 0
			for id in card.data.candidates:
				var index: int = ids.find(id)
				if index >= 0:
					candidates |= 1 << index
			if not _assign(assignments, "revenant", candidates & minions):
				return false
		if card.kind == "event" and card.get("event") == "martyr":
			var actor: int = ids.find(card.data.martyr)
			var saved: int = ids.find(card.data.saved)
			if actor < 0 or saved < 0 or world.evil & ((1 << actor) | (1 << saved)) or not _assign(assignments, "martyr", 1 << actor):
				return false
		if card.kind not in ["report", "claim"]:
			continue
		var source: int = ids.find(card.source)
		if source < 0:
			return false
		if world.evil & (1 << source):
			if bluffs and not card.get("inferred", false):
				continue
			return false
		if not _assign(assignments, card.role, 1 << source):
			return false
		if card.kind == "claim":
			continue
		var pair_mask = 0
		for person in card.data.get("pair", []):
			var i: int = ids.find(person)
			if i < 0:
				return false
			pair_mask |= 1 << i
		var answer: Dictionary = answers.get(card.id, {})
		var selected = 0
		for person in answer.get("positive", []):
			var i: int = ids.find(person)
			if i < 0:
				return false
			selected |= 1 << i
		if card.role in ["clerk", "archivist"]:
			var candidates: int = pair_mask & (good if card.role == "clerk" else minions)
			if selected != 0:
				candidates &= selected
			if not _assign(assignments, card.data.role, candidates):
				return false
		elif card.role == "veteran":
			if veteran_night >= 0 and veteran_night != card.night:
				return false
			veteran_night = card.night
		elif card.role == "martyr":
			if martyr_target != "" and martyr_target != card.data.target:
				return false
			martyr_target = card.data.target
			if card.data.get("evil", false):
				var target: int = ids.find(card.data.target)
				if target < 0 or not (world.evil & (1 << target)) and world.marked != target:
					return false
		elif card.role == "gravedigger":
			var target: int = ids.find(card.data.executed)
			if target < 0:
				return false
			var read_role: String = card.data.role
			var evil_role: bool = C.ROLES.get(read_role, {}).get("align") == "evil"
			# Marked can receive any evil-role result without actually holding it.
			if evil_role and world.marked == target:
				continue
			var candidates: int = (1 << demon) if read_role == "demon" and demon >= 0 else (minions if evil_role else good)
			if not _assign(assignments, read_role, (1 << target) & candidates):
				return false
		elif card.role == "seer":
			if seer != "" and seer != card.source:
				return false
			seer = card.source
			rh &= ~(1 << source) # native setup excludes the Seer
			if not card.data.yes:
				if demon >= 0 and pair_mask & (1 << demon):
					return false
				rh &= ~pair_mask
				continue
			var ping: int = selected if selected != 0 else pair_mask
			var reason: String = answer.get("registration", "")
			var demon_ok: bool = demon >= 0 and (ping & (1 << demon)) != 0
			var marked_ok: bool = world.marked >= 0 and (ping & (1 << world.marked)) != 0
			if reason == "demon" and not demon_ok:
				return false
			if reason == "marked" and not marked_ok:
				return false
			if reason == "red_herring" or (reason == "" and not demon_ok and not marked_ok):
				rh &= ping
	if seer != "" and rh == 0:
		return false
	return _matching(assignments.values(), 0)

static func _assign(assignments: Dictionary, role: String, candidates: int) -> bool:
	if assignments.has(role):
		candidates &= assignments[role]
	assignments[role] = candidates
	return candidates != 0

static func _matching(masks: Array, occupied: int) -> bool:
	if masks.is_empty():
		return true
	var remaining: Array = masks.duplicate()
	var available: int = int(remaining.pop_back()) & ~occupied
	while available:
		var bit: int = available & -available
		if _matching(remaining, occupied | bit):
			return true
		available &= ~bit
	return false

## Per world: BLUFF_WEIGHT for each distinct (source, role) declared by a source who is
## evil in that world. Inferred and quoted declarations don't count.
static func bluff_weights(view: Dictionary, universe: Array, cards: Array) -> PackedFloat64Array:
	var ids: Array = view.people.map(func(p): return p.id)
	var declared: Array = []  # source bit per distinct declaration
	var seen = {}
	for card in cards:
		if card.kind not in ["report", "claim"] or card.get("quoted", false) or card.get("inferred", false):
			continue
		var i: int = ids.find(card.source)
		var key: String = card.source + "|" + str(card.get("role", ""))
		if i < 0 or seen.has(key):
			continue
		seen[key] = true
		declared.append(1 << i)
	var out = PackedFloat64Array()
	out.resize(universe.size())
	for w in range(universe.size()):
		var evil: int = universe[w].evil
		var weight = 1.0
		for bit in declared:
			if evil & bit:
				weight *= BLUFF_WEIGHT
		out[w] = weight
	return out
