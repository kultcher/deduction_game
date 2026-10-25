## Bounded live routes and an explicitly experimental activity/trace comparison.
## Public receipts only. One joint factor consumes each night's trace once, even
## when it is linked to several suspects. Activity profiles persist across nights.
extends RefCounted
const C = preload("res://sim/content.gd")
const History = preload("res://workshop/live_history.gd")
static var cache = {}
static var route_cache = {}

static func available(view: Dictionary) -> bool:
	return view.get("live_activity", false)

static func relevant(cards: Array) -> Array:
	return cards.filter(func(c): return c.kind in ["sighting", "evening", "trace", "coverage", "alibi", "dropped"] or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran"]))

## Everything routes() and factors() read from a card list: the movement-relevant
## cards, relayed cards (in order) and each person's claimed role. Two listeners who
## differ only in other readings (Dowser, Surveyor, Clerk...) share one cache entry.
static func movement_inputs(view: Dictionary, cards: Array, knowledge: Dictionary = {}, include_context: bool = false) -> Array:
	var roles: Array = []
	var weighted: bool = cards.any(func(c): return c.kind in ["claim", "report"] and c.has("hearing_weight"))
	for person in view.people:
		var role: String = role_of(cards, person.id, knowledge)
		roles.append([role, role_hearing(cards, person.id, role)] if weighted else role)
	return [cards.filter(func(c): return c.has("relay_source") or c.kind in ["sighting", "evening", "trace", "coverage", "alibi", "dropped"] or (include_context and c.kind == "secret_claim") or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran"])), roles]

static func role_of(cards: Array, person: String, knowledge: Dictionary = {}) -> String:
	if person == knowledge.get("self", ""):
		return knowledge.get("own_role", "")
	for card in cards:
		if card.get("relay_source") == person and not card.get("quoted", false):
			return "medium"
		if not card.get("quoted", false) and not card.get("testimony_only", false) and card.source == person and card.kind in ["claim", "report"]:
			return card.role
	return ""

static func role_hearing(cards: Array, person: String, role: String) -> float:
	var strength = 0.0
	for card in cards:
		if not card.get("quoted", false) and card.source == person and card.get("role", "") == role and card.kind in ["claim", "report"]:
			strength = maxf(strength, float(card.get("hearing_weight", 1.0)))
	return strength

static func _paths(view: Dictionary, person: Dictionary, night: int, cards: Array, knowledge: Dictionary) -> Array:
	if not History.alive_at_night(view, person.id, night):
		return [[]]
	var role = role_of(cards, person.id, knowledge)
	var paths: Array = [[]]
	for block in C.BLOCKS:
		paths.append(C.route(person.home, block))
	if role in ["", "lamplighter"]:
		paths.append(C.BLOCKS.keys())
	var result: Array = []
	for path in paths:
		var out: bool = not path.is_empty()
		if knowledge.get("self") == person.id and knowledge.get("own_outings", {}).has(str(night)) and out != knowledge.own_outings[str(night)]:
			continue
		var okay = true
		for card in cards:
			if card.has("relay_source") and not card.get("quoted", false) and card.relay_source == person.id and card.relay_observed_at.day == night:
				var hearth: String = view.people.filter(func(p): return p.id == card.source)[0].home
				okay = okay and out and path.back() == hearth
			if card.get("night", -1) != night or card.get("quoted", false):
				continue
			if card.kind == "sighting" and card.get("hearing_weight", 1.0) < 1.0:
				continue # Weakly relayed testimony cannot force a walk or gift identity.
			if card.kind == "sighting" and person.id in card.get("subjects", [card.get("subject", "")]):
				okay = okay and out and (card.block == "" or card.block in path)
				if card.has("guard_claim"):
					okay = okay and out and path.back() == card.block
			elif card.kind == "sighting" and card.get("complete", false) and person.id not in card.get("excluded", []):
				okay = okay and card.block not in path
			elif card.kind == "alibi" and card.subject == person.id:
				okay = okay and not out
			elif card.kind == "coverage" and person.id not in card.get("excluded", []):
				okay = okay and card.block not in path
			elif card.kind == "report" and card.role == "nightwatch":
				if card.source == person.id:
					okay = okay and out and path.back() == card.data.block
				else:
					okay = okay and ((card.data.block in path) == (person.id in card.data.seen))
			elif card.kind == "report" and card.role == "warden" and card.source == person.id:
				okay = okay and out and path.back() == card.block
			elif card.kind == "report" and card.role == "lamplighter" and card.source == person.id:
				okay = okay and path.size() == C.BLOCKS.size()
			if not okay:
				break
		if okay:
			result.append(path)
	return result

static func routes(view: Dictionary, cards: Array, answers: Dictionary = {}, knowledge: Dictionary = {}) -> Dictionary:
	var input = [view.people, view.get("timeline", {}), movement_inputs(view, cards, knowledge), answers, knowledge]
	var key = hash(input)
	if route_cache.has(key) and route_cache[key].input == input:
		return route_cache[key].result
	var nights = {}
	for card in relevant(cards):
		if card.get("night", -1) >= 0 and card.kind not in ["evening", "trace"]:
			nights[str(card.night)] = {}
	for card in cards:
		if card.has("relay_source") and not card.get("quoted", false):
			nights[str(card.relay_observed_at.day)] = {}
	var okay = true
	var forced_lamp: Array = []
	for night_key in nights:
		var forced = 0
		var possible = 0
		var paths: Array = []
		for i in range(view.people.size()):
			var options = _paths(view, view.people[i], int(night_key), cards, knowledge)
			paths.append(options)
			if options.is_empty():
				okay = false
			if not options.is_empty() and options.all(func(path): return not path.is_empty()):
				forced |= 1 << i
			if options.any(func(path): return not path.is_empty()):
				possible |= 1 << i
			if not options.is_empty() and options.all(func(path): return path.size() == C.BLOCKS.size()) and view.people[i].id not in forced_lamp:
				forced_lamp.append(view.people[i].id)
		var drops = {}
		for card in cards:
			if card.get("night", -1) != int(night_key) or card.get("quoted", false):
				continue
			if card.kind != "dropped" and not card.get("item_drop", false):
				continue
			var candidates = 0
			for i in range(view.people.size()):
				var person: Dictionary = view.people[i]
				var matches_owner: bool = person.home == card.data.material if card.kind == "dropped" else person.id == card.subject
				if matches_owner and paths[i].any(func(path): return card.block in path):
					candidates |= 1 << i
			drops[card.get("fact_id", card.id)] = candidates
		var count_masks: Array = []
		for mask in range(1 << view.people.size()):
			if mask & forced != forced or mask & ~possible:
				continue
			var valid = true
			for card in cards:
				if card.kind != "report" or card.get("night", -1) != int(night_key) or card.get("quoted", false) or card.get("role") != "lamplighter":
					continue
				var source: int = view.people.map(func(p): return p.id).find(card.source)
				if _count(mask & ~(1 << source)) != card.data.count or not answers.get(card.id, {}).get("positive", []).all(func(id): return mask & (1 << view.people.map(func(p): return p.id).find(id))):
					valid = false
			if valid and _drop_owners(drops.values(), mask):
				count_masks.append(mask)
		if count_masks.is_empty():
			okay = false
		var out: Array = []
		for i in range(view.people.size()):
			if not count_masks.is_empty() and count_masks.all(func(mask): return mask & (1 << i)):
				out.append(view.people[i].id)
		nights[night_key] = {"compatible": count_masks.size(), "forced_out": out}
	okay = okay and forced_lamp.size() <= 1
	var result = {"okay": okay, "nights": nights, "forced_lamp": forced_lamp}
	if route_cache.size() >= 128:
		route_cache.clear()
	route_cache[key] = {"input": input.duplicate(true), "result": result}
	return result

## One native walker can drop at most one item per night. Material identifies a
## home group, never an owner; only the jointly feasible assignments constrain it.
static func _drop_owners(groups: Array, available: int) -> bool:
	if groups.is_empty():
		return true
	var remaining = groups.duplicate()
	var candidates: int = remaining.pop_back() & available
	while candidates:
		var bit = candidates & -candidates
		if _drop_owners(remaining, available & ~bit):
			return true
		candidates &= ~bit
	return false

static func _count(mask: int) -> int:
	var result = 0
	while mask:
		mask &= mask - 1
		result += 1
	return result

static func factors(view: Dictionary, cards: Array, value: Dictionary) -> Array:
	if not available(view):
		return []
	var observations = relevant(cards).filter(func(c): return not c.get("quoted", false) or c.kind == "alibi")
	if observations.is_empty():
		return []
	var input = [view.people, view.get("timeline", {}), movement_inputs(view, cards, {}, true)]
	if view.get("chronology", {}).has("curse"):
		input.append(view.chronology.curse)
	var key = hash(input)
	if cache.has(key) and cache[key].input == input:
		return cache[key].result
	var checked = cards.duplicate()
	var movement = routes(view, cards)
	for night in movement.nights:
		for person in movement.nights[night].forced_out:
			checked.append({"id": "inferred-out:%s:%s" % [person, night], "kind": "sighting", "source": "evidence", "subject": person, "subjects": [person], "block": "", "night": int(night)})
	var profiles: Array = []
	for person in view.people:
		profiles.append({"good": _likelihood(view, checked, person, "good"), "minion": _likelihood(view, checked, person, "minion"), "demon": _likelihood(view, checked, person, "demon")})
		if view.get("chronology", {}).has("curse"):
			profiles[-1]["converted"] = _likelihood(view, checked, person, "converted")
	var result: Array = [{"origin": "movement_model", "joint_live": true, "target": "", "log2_ratio": 1.0,
		"label": "Movement / trace: joint live comparison", "profiles": profiles,
		"cards": observations.map(func(c): return c.id), "note": "One joint comparison; persistent activity and evening habits. Unknown passers remain possible. Activity rates and background contamination are experimental priors, not calibrated guilt probabilities."}]
	if cache.size() >= 128:
		cache.clear()
	cache[key] = {"input": input.duplicate(true), "result": result}
	return result

static func score(world: Dictionary, factor: Dictionary) -> float:
	var result = 1.0
	for i in range(factor.profiles.size()):
		var profile: Dictionary = factor.profiles[i]
		var type: String = "demon" if world.get("demon", -1) == i else ("minion" if world.evil & (1 << i) else "good")
		if world.get("converted", -1) == i and profile.has("converted"):
			type = "converted"
		result *= maxf(profile[type], 1e-30) / maxf(profile.good, 1e-30)
	return result

static func _likelihood(view: Dictionary, cards: Array, person: Dictionary, alignment: String) -> float:
	var relevant_cards = relevant(cards)
	var nights: Array = []
	for card in relevant_cards:
		if card.get("night", -1) >= 0 and card.night not in nights:
			nights.append(card.night)
	var role = role_of(cards, person.id)
	var gift: bool = C.ROLES.get(role, {}).get("night_walk", false)
	var profiles: Array = [{"kind": alignment, "weight": 1.0}] if alignment not in ["good", "converted"] else [
		{"kind": "ordinary", "weight": 0.2 if gift else 0.75},
		{"kind": "gift", "weight": 0.7 if gift else 0.15}, {"kind": "secret", "weight": 0.1}]
	if alignment in ["good", "converted"] and role != "" and not gift:
		profiles = [{"kind": "ordinary", "weight": 0.9}, {"kind": "secret", "weight": 0.1}]
	if alignment in ["good", "converted"] and role != "" and cards.any(func(c): return c.source == person.id and c.has("hearing_weight")):
		var strength: float = role_hearing(cards, person.id, role)
		profiles = [{"kind": "ordinary", "weight": lerpf(0.75, 0.2 if gift else 0.9, strength)}, {"kind": "gift", "weight": lerpf(0.15, 0.7 if gift else 0.0, strength)}, {"kind": "secret", "weight": 0.1}]
	# Each night's incident cards, deduplicated once in their original order.
	var reports_by_night: Array = []
	for night in nights:
		var reports: Array = []
		var incidents: Array = []
		for card in relevant_cards:
			if card.night != night:
				continue
			var incident: String = "alibi:" + card.subject if card.kind == "alibi" else ("trace:" + str(card.data.get("scene", "")) if card.kind == "trace" else card.id)
			if incident in incidents:
				continue
			incidents.append(incident)
			reports.append(card)
		reports_by_night.append(reports)
	var total = 0.0
	for profile in profiles:
		# Path products per night, evening and path. None depend on the habitual
		# block, so they are built once and summed below in the original order.
		var tables: Array = []
		for n in range(nights.size()):
			var night = nights[n]
			var current: String = alignment
			if alignment == "converted":
				var curse: Dictionary = view.chronology.curse
				current = "minion" if night * 4 + 3 >= curse.from and night * 4 + 3 < curse.until else "good"
			var paths: Array = _profile_paths(view, person, night, "minion" if alignment == "converted" and current == "minion" else profile.kind, cards)
			var by_evening: Array = []
			for evening in C.BLOCKS:
				var products = PackedFloat64Array()
				for path in paths:
					var p: float = path.weight
					for card in reports_by_night[n]:
						p *= _observed(card, person.id, evening, path.path, current, view, night)
					products.append(p)
				by_evening.append(products)
			tables.append(by_evening)
		# One latent habitual evening block across every night; repeated identical
		# material alone does not pretend to be independent confirmation of guilt.
		for haunt in C.BLOCKS:
			var weight: float = profile.weight / C.BLOCKS.size()
			for n in range(nights.size()):
				var sum = 0.0
				var e: int = 0
				for evening in C.BLOCKS:
					var evening_p: float = 0.7 if evening == haunt else 0.1
					for p in tables[n][e]:
						sum += evening_p * p
					e += 1
				weight *= sum
			total += weight
	return total

static func _profile_paths(view: Dictionary, person: Dictionary, night: int, profile: String, cards: Array) -> Array:
	var rates = {"demon": 1.0 if night > 0 else 0.0, "minion": 0.25, "gift": 1.0, "secret": 0.55, "ordinary": 0.05}
	var rate: float = rates[profile]
	if profile == "ordinary":
		for card in cards:
			if card.kind == "secret_claim" and not card.get("quoted", false) and card.subject == person.id and night >= card.applies.from and night <= card.applies.through:
				rate = maxf(rate, lerpf(float(rates.ordinary), float(rates.secret), float(card.get("hearing_weight", 1.0))))
	if not History.alive_at_night(view, person.id, night):
		return [{"path": [], "weight": 1.0}]
	var destinations: Array = C.BLOCKS.keys()
	if profile == "gift":
		var role = role_of(cards, person.id)
		if role == "medium":
			destinations = view.people.filter(func(p): return not History.alive_at_night(view, p.id, night)).map(func(p): return p.home)
		elif role == "warden":
			destinations = view.people.filter(func(p): return p.id != person.id and History.alive_at_night(view, p.id, night)).map(func(p): return p.home)
		if destinations.is_empty():
			rate = 0.0
	if profile == "demon":
		var scenes: Array = view.get("timeline", {}).get("events", []).filter(func(e): return e.kind == "demon_death" and e.at.day == night)
		if not scenes.is_empty():
			var victim: String = scenes[0].subjects[0]
			destinations = view.people.filter(func(p): return p.id == victim).map(func(p): return p.home)
	var result: Array = [{"path": [], "weight": 1.0 - rate}]
	var unknown_lamp: bool = profile == "gift" and role_of(cards, person.id) == ""
	if unknown_lamp:
		result.append({"path": C.BLOCKS.keys(), "weight": rate * 0.1})
	for destination in destinations:
		var path: Array = C.BLOCKS.keys() if profile == "gift" and role_of(cards, person.id) == "lamplighter" else C.route(person.home, destination)
		result.append({"path": path, "weight": rate * (0.9 if unknown_lamp else 1.0) / maxf(destinations.size(), 1)})
	return result

static func _observed(card: Dictionary, person: String, evening: String, path: Array, alignment: String, view: Dictionary, night: int) -> float:
	if card.get("quoted", false) and card.kind != "alibi":
		return 1.0
	var out: bool = not path.is_empty()
	match card.kind:
		"sighting":
			if person in card.get("subjects", [card.get("subject", "")]):
				return 1.0 if out and (card.block == "" or card.block in path) else 1.0 - float(card.get("hearing_weight", 1.0))
			if card.get("complete", false) and person not in card.get("excluded", []):
				return 1.0 if card.block not in path else 0.0
		"evening":
			if person in card.get("subjects", [card.get("subject", "")]):
				return 1.0 if card.block == evening else 0.0
		"coverage":
			if person not in card.get("excluded", []):
				return 1.0 if card.block not in path else 0.0
		"alibi":
			if card.subject == person:
				if not card.get("quoted", false):
					return 1.0 if not out else 0.0
				return (0.7 if alignment != "good" else 0.3) if out else 0.9
		"report":
			if card.role == "warden" and card.source == person:
				return 1.0 if out and path.back() == card.block else 0.0
			if card.role == "nightwatch":
				if card.source == person:
					return 1.0 if out and path.back() == card.data.block else 0.0
				return 1.0 if ((card.data.block in path) == (person in card.data.seen)) else 0.0
		"trace":
			if alignment == "demon":
				# The generator is 60% killer-evening material when passers exist.
				# Unknown public passers use a uniform background, never the referee list.
				return (0.6 if card.data.material == evening else 0.0) + 0.4 / C.BLOCKS.size()
	return 1.0
