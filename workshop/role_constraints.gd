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
	var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), cards, knowledge.get("self"), knowledge.get("own_role"), knowledge.get("own_outings", {}), answers]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 64:
			cache.clear()
		cache[key] = {"input": input.duplicate(true), "results": {}, "seer": cards.any(func(c): return c.get("role") in ["seer", "gravedigger", "martyr"] and not c.get("quoted", false))}
	var n: int = ids.size() + 1
	var mask: int = (int(world.evil) * n + int(world.get("demon", -1)) + 1) * n + (int(world.marked) + 1 if cache[key].seer else 0)
	if cards.any(func(c): return c.has("relay_source")):
		mask = (mask * (1 << ids.size()) + int(world.get("holders", 0))) * 2 + int(world.get("modifier") == "delusional")
	if not cache[key].results.has(mask):
		cache[key].results[mask] = _fits_view(view, ids, world, cards, knowledge, answers)
	return cache[key].results[mask]

static func _fits_view(view: Dictionary, ids: Array, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary) -> bool:
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
			cards.append({"kind": "claim", "source": card.relay_source, "role": "medium"})
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
	if Activity.available(view):
		var routes = Activity.routes(view, cards, answers, knowledge)
		if not routes.okay:
			return false
		cards = cards.duplicate()
		for person in routes.forced_lamp:
			cards.append({"kind": "claim", "source": person, "role": "lamplighter"})
	return _fits(ids, world, cards, knowledge, answers)

static func _fits(ids: Array, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary) -> bool:
	var all: int = (1 << ids.size()) - 1
	var good: int = all & ~world.evil
	var demon: int = world.get("demon", -1)
	var minions: int = world.evil & ~(1 << demon) if demon >= 0 else world.evil
	var assignments = {}
	var own: int = ids.find(knowledge.get("self", ""))
	if own >= 0 and knowledge.get("own_role", "") in C.ROLES:
		assignments[knowledge.own_role] = 1 << own
	var seer = ""
	var veteran_night = -1
	var martyr_target = ""
	var rh: int = good
	for card in cards:
		if card.get("quoted", false):
			continue
		if card.kind == "event" and card.get("event") == "martyr":
			var actor: int = ids.find(card.data.martyr)
			var saved: int = ids.find(card.data.saved)
			if actor < 0 or saved < 0 or world.evil & ((1 << actor) | (1 << saved)) or not _assign(assignments, "martyr", 1 << actor):
				return false
		if card.kind not in ["report", "claim"]:
			continue
		var source: int = ids.find(card.source)
		if source < 0 or (world.evil & (1 << source)):
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
