## Joint role completions and a persistent Red Herring, without full permutations.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Activity = preload("res://workshop/live_activity.gd")
static var cache: Dictionary = {}
static var reuse = true

static func fits(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary = {}) -> bool:
	return fit_weight(view, world, cards, knowledge, answers) > 0.0

static func fit_weight(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary = {}, bluffs: bool = false) -> float:
	if not view.get("world_options", {}).get("roles", false):
		return 1.0
	var ids: Array = view.people.map(func(p): return p.id)
	if not reuse:
		return _fits_view(view, ids, world, cards, knowledge, answers, null, bluffs)
	var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), cards, knowledge.get("self"), knowledge.get("own_role"), knowledge.get("own_outings", {}), answers, knowledge.get("public_roles", {}), bluffs]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 64:
			cache.clear()
		cache[key] = {"input": input.duplicate(true), "results": {}, "seer": seer_flag(cards)}
	var mask: int = coarse_mask(ids.size(), world, cache[key].seer, relay_mediums(ids, cards), sleepwalk_claimants(ids, cards))
	if not cache[key].results.has(mask):
		cache[key].results[mask] = _fits_view(view, ids, world, cards, knowledge, answers, null, bluffs)
	return float(cache[key].results[mask])

## fits() for every world of a universe, hashing the view and cards once rather than
## per world. Same memo as fits(), so the results agree.
## Weight of one role declaration (claim, or a reading's implied gift) by a source who
## is evil in that world: a bluff is possible, but naming this exact role is a choice
## among several, so a claim still weakly supports its claimant (live play only).
const BLUFF_WEIGHT = Tuning.Workshop.BLUFF_WEIGHT

## bluffs (live play): evil sources' role declarations constrain nothing; see _fits.
static func fits_table(view: Dictionary, universe: Array, cards: Array, knowledge: Dictionary, answers: Dictionary = {}, bluffs: bool = false) -> PackedByteArray:
	var weights: PackedFloat64Array = fits_weights(view, universe, cards, knowledge, answers, bluffs)
	var out = PackedByteArray()
	out.resize(weights.size())
	for i in range(weights.size()):
		out[i] = 1 if weights[i] > 0.0 else 0
	return out

static func fits_weights(view: Dictionary, universe: Array, cards: Array, knowledge: Dictionary, answers: Dictionary = {}, bluffs: bool = false) -> PackedFloat64Array:
	var out = PackedFloat64Array()
	out.resize(universe.size())
	if not view.get("world_options", {}).get("roles", false):
		out.fill(1.0)
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
	var mediums: int = relay_mediums(ids, cards)
	var walkers: int = sleepwalk_claimants(ids, cards)
	var routes = null
	for i in range(universe.size()):
		var world: Dictionary = universe[i]
		var mask: int = coarse_mask(ids.size(), world, seer, mediums, walkers)
		if not results.has(mask):
			# The Medium claims a relay adds are the same in every world that passes the
			# relay checks (worlds that fail never reach routing), so routes hoist too.
			if routes == null and Activity.available(view):
				routes = Activity.routes(view, _routing_cards(_live_cards(cards)), answers, knowledge)
			results[mask] = _fits_view(view, ids, world, cards, knowledge, answers, routes, bluffs)
		out[i] = float(results[mask])
	return out

## The parts of a world the role check reads, as one int: fits() gives the same answer
## for worlds with the same mask (for the same view, cards and knowledge).
## mediums: relay_mediums(). A relay only reads whether its Medium is Delusional (the
## Medium's evil bit is already in the mask), not the other modifier holders: keying on
## all holders split every class ~12,000 ways in late games.
## walkers: sleepwalk_claimants(). A "known to sleepwalk" claim reads only whether its
## claimants are the Sleepwalker, so only their bits join the mask (0 when nobody claims).
static func coarse_mask(people: int, world: Dictionary, seer: bool, mediums: int, walkers: int = 0) -> int:
	var n: int = people + 1
	var mask: int = (int(world.evil) * n + int(world.get("demon", -1)) + 1) * n + (int(world.marked) + 1 if seer else 0)
	if mediums != 0:
		var deluded: int = int(world.get("holders", 0)) & mediums if world.get("modifier", "marked") == "delusional" else 0
		mask = mask * (1 << people) + deluded
	if walkers != 0:
		var asleep: int = int(world.get("holders", 0)) & walkers if world.get("modifier", "marked") == "sleepwalker" else 0
		mask = mask * (1 << people) + asleep
	if world.has("converted"):
		mask = mask * n + int(world.converted) + 1
	return mask

## Bit per person who said they've been known to sleepwalk (unquoted secret claims).
static func sleepwalk_claimants(ids: Array, cards: Array) -> int:
	var bits: int = 0
	for card in cards:
		if card.get("kind", "") == "secret_claim" and card.get("data", {}).get("secret_kind", "") == "sleepwalker" and not card.get("quoted", false):
			var i: int = ids.find(card.get("subject", ""))
			if i >= 0:
				bits |= 1 << i
	return bits

## Bit per Medium named by an unquoted relay card (the people the relay check reads).
static func relay_mediums(ids: Array, cards: Array) -> int:
	var bits: int = 0
	for card in cards:
		if card.has("relay_source") and not card.get("quoted", false):
			var medium: int = ids.find(card.relay_source)
			if medium >= 0:
				bits |= 1 << medium
	return bits

## Cards the role check reads: testimony-only cards are weighed elsewhere.
static func _live_cards(cards: Array) -> Array:
	return cards.filter(func(card): return not card.get("testimony_only", false))

## The cards routing reads in a world that passes the relay checks: each unquoted relay
## adds its Medium's inferred claim, in card order (as _fits_view does).
static func _routing_cards(cards: Array) -> Array:
	var out: Array = cards.duplicate()
	for card in cards:
		if card.has("relay_source") and not card.get("quoted", false):
			out.append({"kind": "claim", "source": card.relay_source, "role": "medium", "inferred": true})
	return out

## The seer flag fits() keys its memo on.
static func seer_flag(cards: Array) -> bool:
	return cards.any(func(c): return c.get("role") in ["seer", "gravedigger", "martyr"] and not c.get("quoted", false))

## routes: Activity.routes(view, cards, answers, knowledge) if already computed. It
## doesn't depend on the world, so fits_table computes it once for all worlds.
static func _fits_view(view: Dictionary, ids: Array, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary, routes = null, bluffs: bool = false) -> float:
	cards = _live_cards(cards)
	# "I've been known to sleepwalk": true of the one Sleepwalker; anyone else saying it
	# is evil and lying. (Two claimants: at least one is evil.)
	var walkers: int = sleepwalk_claimants(ids, cards)
	if walkers != 0:
		var asleep: int = int(world.get("holders", 0)) if world.get("modifier", "marked") == "sleepwalker" else 0
		if walkers & ~int(world.evil) & ~asleep:
			return 0.0
	var visits = {}
	for card in cards:
		if card.has("relay_source") and not card.get("quoted", false):
			var medium: int = ids.find(card.relay_source)
			if medium < 0 or world.evil & (1 << medium) or not preload("res://workshop/world_domain.gd").healthy(view, world, card.relay_source) or not preload("res://workshop/live_history.gd").alive_at_night(view, card.relay_source, card.relay_observed_at.day):
				return 0.0
			var visit: String = card.relay_source + ":" + card.source
			if visits.has(visit) and visits[visit] != card.relay_observed_at.day:
				return 0.0
			visits[visit] = card.relay_observed_at.day
	cards = _routing_cards(cards)
	var sexton_night = -1
	for card in cards:
		if card.kind != "report" or card.get("quoted", false):
			continue
		if card.role == "martyr" and card.data.get("evil", false) and not preload("res://workshop/live_history.gd").executed(view, card.data.target, card.observed_at.day):
			return 0.0
		if card.role == "sexton":
			if sexton_night >= 0 and sexton_night != card.data.night:
				return 0.0
			sexton_night = card.data.night
	if sexton_night >= 0:
		if view.people.filter(func(p): return preload("res://workshop/live_history.gd").alive_at_night(view, p.id, sexton_night)).size() >= 5:
			return 0.0
		if view.get("timeline", {}).get("events", []).any(func(e): return e.kind in ["demon_death", "demon_attack"] and e.at.day == sexton_night):
			return 0.0
		for card in cards:
			if card.get("quoted", false):
				continue
			if card.kind == "report" and card.role in ["nightwatch", "lamplighter", "medium"] and card.get("night", -1) == sexton_night:
				return 0.0
			if card.has("relay_source") and card.relay_observed_at.day == sexton_night:
				return 0.0
	for card in cards:
		if card.get("role") != "veteran" or card.kind != "report" or card.get("quoted", false):
			continue
		var demon: int = world.get("demon", -1)
		if demon < 0:
			return 0.0
		var attack_routes: Array = Activity.demon_routes(view.people[demon].home, view.people[ids.find(card.source)].home)
		var fits_approach: bool = attack_routes.any(func(route): return (route.path[route.path.size() - 2] if route.path.size() >= 2 else view.people[ids.find(card.source)].home) == card.data.block)
		if not fits_approach or view.get("timeline", {}).get("events", []).any(func(e): return e.kind in ["demon_death", "demon_attack"] and e.at.day == card.night):
			return 0.0
	var live: bool = bluffs
	if Activity.available(view):
		if routes == null:
			routes = Activity.routes(view, cards, answers, knowledge)
		# Live testimony can be false (an evil fake sighting, a lying alibi): routes that
		# can't all hold no longer void every world; the movement likelihood weighs them.
		if not routes.okay and not live:
			return 0.0
		if routes.okay:
			cards = cards.duplicate()
			for person in routes.forced_lamp:
				if world.get("demon", -1) == ids.find(person):
					continue # The killer may have taken a detour; no forced good-gift proof.
				cards.append({"kind": "claim", "source": person, "role": "lamplighter", "inferred": true})
	return _fits(ids, world, cards, knowledge, answers, live, view)

## bluffs (live play): in a world where a claim's source is evil, the claim is a bluff:
## it occupies no role and constrains nothing. A good source's claim stays binding, so a
## contradiction leaves only the worlds where some claimant is lying.
static func _fits(ids: Array, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary, bluffs: bool = false, view: Dictionary = {}) -> float:
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
			return 0.0
	if view.get("chronology", {}).has("curse"):
		var rev_idx: int = ids.find(str(view.chronology.curse.get("executed", "")))
		if rev_idx >= 0 and not _assign(assignments, "revenant", (1 << rev_idx) & minions):
			return 0.0
	var seer = ""
	var seer_source = -1
	var seer_readings: Array = []
	var veteran_night = -1
	var martyr_target = ""
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
				return 0.0
		if card.kind == "event" and card.get("event") == "martyr":
			var actor: int = ids.find(card.data.martyr)
			var saved: int = ids.find(card.data.saved)
			if actor < 0 or saved < 0 or world.evil & ((1 << actor) | (1 << saved)) or not _assign(assignments, "martyr", 1 << actor):
				return 0.0
		if card.kind not in ["report", "claim"]:
			continue
		var source: int = ids.find(card.source)
		if source < 0:
			return 0.0
		var source_evil: bool = (world.evil & (1 << source)) != 0
		if world.has("converted") and not view.is_empty():
			var time = preload("res://workshop/chronology.gd")
			source_evil = time.evil_at(view, world, card.source, time.statement_time(card))
		if source_evil:
			if bluffs and not card.get("inferred", false):
				continue
			return 0.0
		if not _assign(assignments, card.role, 1 << source):
			return 0.0
		if card.kind == "claim":
			continue
		var pair_mask = 0
		for person in card.data.get("pair", []):
			var i: int = ids.find(person)
			if i < 0:
				return 0.0
			pair_mask |= 1 << i
		var answer: Dictionary = answers.get(card.id, {})
		var selected = 0
		for person in answer.get("positive", []):
			var i: int = ids.find(person)
			if i < 0:
				return 0.0
			selected |= 1 << i
		var rdef = C.role_def(card.role)
		if rdef != null and rdef.shape == "ROLE_IN_GROUP":
			var group_mask: int = 0
			if rdef.role_group_key == "pair":
				group_mask = pair_mask
				if selected != 0:
					group_mask &= selected
			else:
				var target: int = ids.find(card.data.get(rdef.role_group_key, ""))
				if target < 0:
					return 0.0
				group_mask = 1 << target
			var read_role: String = card.data.role
			var evil_role: bool = C.ROLES.get(read_role, {}).get("align") == "evil"
			# Marked can receive any evil-role result without actually holding it.
			if rdef.marked_registers and evil_role and world.marked >= 0 and (group_mask & (1 << world.marked)) != 0:
				continue
			var pool_mask: int = good
			match rdef.role_target_pool:
				"minion":
					pool_mask = minions
				"demon":
					pool_mask = (1 << demon) if demon >= 0 else 0
				"any":
					pool_mask = (1 << demon) if read_role == "demon" and demon >= 0 else (minions if evil_role else good)
			if not _assign(assignments, read_role, group_mask & pool_mask):
				return 0.0
		elif card.role == "veteran":
			if veteran_night >= 0 and veteran_night != card.night:
				return 0.0
			veteran_night = card.night
		elif card.role == "martyr":
			if martyr_target != "" and martyr_target != card.data.target:
				return 0.0
			martyr_target = card.data.target
			if card.data.get("evil", false):
				var target: int = ids.find(card.data.target)
				if target < 0 or not (world.evil & (1 << target)) and world.marked != target:
					return 0.0
		elif card.role == "seer":
			if seer != "" and seer != card.source:
				return 0.0
			seer = card.source
			seer_source = source
			var ping: int = selected if selected != 0 else pair_mask
			var reason: String = answer.get("registration", "")
			seer_readings.append({"yes": bool(card.data.yes), "pair": pair_mask, "ping": ping, "reason": reason})
	var seer_weight: float = 1.0
	if seer != "":
		seer_weight = _seer_rh_weight(good & ~(1 << seer_source), demon, int(world.marked), seer_readings)
		if seer_weight <= 0.0:
			return 0.0
	return seer_weight if _matching(assignments.values(), 0) else 0.0

## Average over every eligible Red Herring candidate r in G of the product of each
## Seer reading's probability in this world (Marked rolls 50% independently per reading).
static func _seer_rh_weight(candidates_mask: int, demon: int, marked: int, readings: Array) -> float:
	if candidates_mask == 0:
		return 0.0
	var demon_bit: int = (1 << demon) if demon >= 0 else 0
	var marked_bit: int = (1 << marked) if marked >= 0 else 0
	var total_weight: float = 0.0
	var n_candidates: int = 0
	var pool: int = candidates_mask
	while pool != 0:
		var r_bit: int = pool & -pool
		pool &= ~r_bit
		n_candidates += 1
		var w: float = 1.0
		for reading in readings:
			var pair: int = reading.pair
			if not reading.yes:
				if (pair & demon_bit) != 0 or (pair & r_bit) != 0:
					w = 0.0
					break
				if (pair & marked_bit) != 0:
					w *= 0.5
			else:
				var ping: int = reading.ping
				var reason: String = reading.reason
				var demon_in: bool = (ping & demon_bit) != 0
				var rh_in: bool = (ping & r_bit) != 0
				var marked_in: bool = (ping & marked_bit) != 0
				if reason == "demon":
					if not demon_in:
						w = 0.0
						break
				elif reason == "red_herring":
					if not rh_in:
						w = 0.0
						break
				elif reason == "marked":
					if not marked_in:
						w = 0.0
						break
					if not demon_in and not rh_in:
						w *= 0.5
				else:
					if demon_in or rh_in:
						pass
					elif marked_in:
						w *= 0.5
					else:
						w = 0.0
						break
		total_weight += w
	return total_weight / float(n_candidates) if n_candidates > 0 else 0.0

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
	if view.get("chronology", {}).has("curse"):
		return _temporal_bluff_weights(view, universe, cards)
	if cards.any(func(c): return c.has("hearing_weight") and c.kind in ["claim", "report"]):
		return _temporal_bluff_weights(view, universe, cards)
	var ids: Array = view.people.map(func(p): return p.id)
	var declared: Array = []  # source bit per distinct declaration
	var seen = {}
	for card in cards:
		if card.kind not in ["report", "claim"] or card.get("quoted", false) or card.get("inferred", false) or card.get("testimony_only", false):
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

static func _temporal_bluff_weights(view: Dictionary, universe: Array, cards: Array) -> PackedFloat64Array:
	var time = preload("res://workshop/chronology.gd")
	var declarations = {}
	for card in cards:
		if card.kind in ["report", "claim"] and not card.get("quoted", false) and not card.get("inferred", false) and not card.get("testimony_only", false):
			var key: String = time.source_key(view, card) + ":" + card.role
			if not declarations.has(key) or float(card.get("hearing_weight", 1.0)) > float(declarations[key].get("hearing_weight", 1.0)):
				declarations[key] = card
	# Per declaration, once: the source's index, statement time and factor. A world with
	# no conversion is evil at every time exactly when its evil bit is set.
	var ids: Array = view.people.map(func(p): return p.id)
	var who = PackedInt32Array()
	var factor = PackedFloat64Array()
	var times: Array = []
	for card in declarations.values():
		who.append(ids.find(card.source))
		factor.append(lerpf(1.0, BLUFF_WEIGHT, float(card.get("hearing_weight", 1.0))))
		times.append(time.statement_time(card))
	var out = PackedFloat64Array()
	out.resize(universe.size())
	for i in range(universe.size()):
		var world: Dictionary = universe[i]
		var converted: bool = world.has("converted")
		var evil: int = int(world.evil)
		var weight = 1.0
		for d in range(who.size()):
			var j: int = who[d]
			if j < 0:
				continue
			if (evil & (1 << j)) != 0 or (converted and time.evil_index(view, world, j, times[d])):
				weight *= factor[d]
		out[i] = weight
	return out
