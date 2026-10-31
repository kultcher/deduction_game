## Bounded live routes and an explicitly experimental activity/trace comparison.
## Public receipts only. One joint factor consumes each night's trace once, even
## when it is linked to several suspects. Activity profiles persist across nights.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const History = preload("res://workshop/live_history.gd")
static var cache = {}
static var route_cache = {}
const DEMON_DETOUR = Tuning.Workshop.DEMON_DETOUR
static var demon_route_cache = {}

static func available(view: Dictionary) -> bool:
	return view.get("live_activity", false)

static func relevant(cards: Array) -> Array:
	return cards.filter(func(c): return c.kind in ["sighting", "evening", "trace", "coverage", "alibi", "dropped"] or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran", "medium"]))

## Everything routes() and factors() read from a card list: the movement-relevant
## cards, relayed cards (in order) and each person's claimed role. Two listeners who
## differ only in other readings (Dowser, Surveyor, Clerk...) share one cache entry.
static func movement_inputs(view: Dictionary, cards: Array, knowledge: Dictionary = {}, include_context: bool = false) -> Array:
	var roles: Array = []
	var weighted: bool = cards.any(func(c): return c.kind in ["claim", "report"] and c.has("hearing_weight"))
	for person in view.people:
		var role: String = role_of(cards, person.id, knowledge)
		roles.append([role, role_hearing(cards, person.id, role)] if weighted else role)
	var has_struct_trace: bool = include_context and cards.any(func(x): return x.kind == "trace" and x.get("data", {}).has("family"))
	return [cards.filter(func(c): return c.has("relay_source") or c.kind in ["sighting", "evening", "trace", "coverage", "alibi", "dropped"] or (include_context and c.kind == "secret_claim") or (has_struct_trace and ((c.kind == "context" and c.get("context_kind", "") in ["home", "work", "haunt", "bond"]) or c.kind == "location")) or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran", "medium"])), roles]

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
		if not card.get("quoted", false) and not card.get("testimony_only", false) and card.source == person and card.get("role", "") == role and card.kind in ["claim", "report"]:
			strength = maxf(strength, float(card.get("hearing_weight", 1.0)))
	return strength

static func _paths(view: Dictionary, person: Dictionary, night: int, cards: Array, knowledge: Dictionary, strict_reports: bool = true) -> Array:
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
				okay = okay and out and (card.block == "" or (C.vigil_sees_path(card.block, path) if card.get("complete", false) else card.block in path))
				if card.has("guard_claim"):
					okay = okay and out and path.back() == card.block
			elif card.kind == "sighting" and card.get("complete", false) and person.id not in card.get("excluded", []):
				okay = okay and not C.vigil_sees_path(card.block, path)
			elif card.kind == "alibi" and card.subject == person.id:
				okay = okay and not out
			elif card.kind == "coverage" and person.id not in card.get("excluded", []):
				okay = okay and not C.vigil_sees_path(card.block, path)
			elif card.kind == "report" and card.role == "nightwatch":
				if card.source == person.id:
					okay = okay and out and path.back() == card.data.block
				elif strict_reports and not card.get("duty_only", false):
					okay = okay and ((card.data.block in path) == (person.id in card.data.seen))
			elif card.kind == "report" and card.role == "warden" and card.source == person.id:
				okay = okay and out and path.back() == card.block
			elif card.kind == "report" and card.role == "medium" and card.source == person.id:
				okay = okay and out and path.back() == card.data.get("block", card.get("block", ""))
			elif card.kind == "report" and card.role == "lamplighter" and card.source == person.id:
				okay = okay and path.size() == C.BLOCKS.size()
			if not okay:
				break
		if okay:
			result.append(path)
	return result

static func routes(view: Dictionary, cards: Array, answers: Dictionary = {}, knowledge: Dictionary = {}, strict_reports: bool = true) -> Dictionary:
	var input = [view.people, view.get("timeline", {}), movement_inputs(view, cards, knowledge), answers, knowledge, strict_reports]
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
			var options = _paths(view, view.people[i], int(night_key), cards, knowledge, strict_reports)
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
				if card.kind != "report" or card.get("duty_only", false) or card.get("night", -1) != int(night_key) or card.get("quoted", false) or card.get("role") != "lamplighter":
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
	var tc_digests: Array = view.get("trace_assessments", []).map(func(ta): return str(ta.get("digest", "")))
	var input = [view.people, view.get("timeline", {}), movement_inputs(view, cards, {}, true), tc_digests]
	if view.get("chronology", {}).has("curse"):
		input.append(view.chronology.curse)
	var key = hash(input)
	if cache.has(key) and cache[key].input == input:
		return cache[key].result
	var checked = cards.duplicate()
	var movement = routes(view, cards, {}, {}, false)
	for night in movement.nights:
		for person in movement.nights[night].forced_out:
			checked.append({"id": "inferred-out:%s:%s" % [person, night], "kind": "sighting", "source": "evidence", "subject": person, "subjects": [person], "block": "", "night": int(night)})
	var profiles: Array = []
	for person in view.people:
		profiles.append({"good": _likelihood(view, checked, person, "good"), "minion": _likelihood(view, checked, person, "minion"), "demon": _likelihood(view, checked, person, "demon")})
		if view.get("chronology", {}).has("curse"):
			profiles[-1]["converted"] = _likelihood(view, checked, person, "converted")
	var scene_tables: Array = _build_scene_tables(view, checked)
	var scion_splits: Array = _scion_succession_splits(view, checked, profiles)
	var result: Array = [{"origin": "movement_model", "joint_live": true, "target": "", "log2_ratio": 1.0,
		"label": "Movement / trace: joint live comparison", "profiles": profiles, "scene_tables": scene_tables, "scion_splits": scion_splits,
		"cards": observations.map(func(c): return c.id), "note": "One joint comparison; persistent activity and evening habits. Unknown passers remain possible. Activity rates and background contamination are experimental priors, not calibrated guilt probabilities."}]
	result[0]["relationships"] = relationships(view, cards)
	if cache.size() >= 128:
		cache.clear()
	cache[key] = {"input": input.duplicate(true), "result": result}
	return result

static func _passer_expected_weight(world: Dictionary, st: Dictionary, trace_weights: Array, demon_idx: int) -> float:
	var eps: float = Tuning.Setup.TRACE_PASSER_PRIOR_FLOOR
	var num: float = eps * Tuning.Setup.TRACE_UNKNOWN_WEIGHT
	var den: float = eps
	var n_people: int = trace_weights.size()
	for j in range(n_people):
		if j == demon_idx or j == st.victim_idx:
			continue
		var cp: float
		if world.get("converted", -1) == j and not st.cross_converted.is_empty():
			cp = float(st.cross_converted[j])
		elif (world.evil & (1 << j)) != 0:
			cp = float(st.cross_minion[j])
		else:
			cp = float(st.cross_good[j])
		if cp > 0.0:
			num += cp * float(trace_weights[j])
			den += cp
	return num / maxf(den, 1e-12)

static func _scene_score(world: Dictionary, scene_tables: Array, demon_idx: int) -> float:
	if demon_idx < 0 or scene_tables.is_empty():
		return 1.0
	var total = 1.0
	for st in scene_tables:
		var w1_d: float = float(st.w1[demon_idx])
		if st.two_cited:
			var w2_d: float = float(st.w2[demon_idx])
			var ep2: float = _passer_expected_weight(world, st, st.w2, demon_idx)
			var ep1: float = _passer_expected_weight(world, st, st.w1, demon_idx)
			total *= 0.5 * (w1_d * ep2 + w2_d * ep1)
		elif st.scene_trace_count >= 2:
			# Only 1 of 2 traces from a two-trace scene was cited: 50% killer, 50% passer.
			var ep_single: float = _passer_expected_weight(world, st, st.w1, demon_idx)
			total *= 0.5 * w1_d + 0.5 * ep_single
		else:
			total *= w1_d
	return total

static func _base_score(world: Dictionary, profiles: Array, demon_idx: int, scene_tables: Array = []) -> float:
	var result = 1.0
	for i in range(profiles.size()):
		var profile: Dictionary = profiles[i]
		var type: String = "demon" if demon_idx == i else ("minion" if world.evil & (1 << i) else "good")
		if world.get("converted", -1) == i and profile.has("converted"):
			type = "converted"
		result *= maxf(profile[type], 1e-30) / maxf(profile.good, 1e-30)
	result *= _scene_score(world, scene_tables, demon_idx)
	return result

static func score(world: Dictionary, factor: Dictionary) -> float:
	var d_idx: int = world.get("demon", -1)
	var scene_tables: Array = factor.get("scene_tables", [])
	var direct: float = _base_score(world, factor.profiles, d_idx, scene_tables)
	for split in factor.get("scion_splits", []):
		var exec_idx: int = split.executed_idx
		if d_idx >= 0 and exec_idx != d_idx and (world.evil & (1 << exec_idx)) != 0 and split.alive_demon_mask & (1 << d_idx):
			# Scion succession possible: either d_idx was always Demon, or exec_idx was Demon
			# on nights < exec_day and d_idx rose as Scion before night exec_day.
			var pre_s: float = _base_score(world, split.pre_profiles, exec_idx, split.get("pre_scenes", []))
			var post_s: float = _base_score(world, split.post_profiles, d_idx, split.get("post_scenes", []))
			return 0.5 * direct + 0.5 * (pre_s * post_s)
	return direct

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
			var incident: String = "alibi:" + card.subject if card.kind == "alibi" else (("trace:%s:%d" % [str(card.data.get("scene", "")), int(card.data.get("slot", 0))]) if card.kind == "trace" else card.id)
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
						p *= _observed(card, person.id, evening, path.path, current, view, night, cards)
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
		var scenes: Array = view.get("timeline", {}).get("events", []).filter(func(e): return e.kind in ["demon_death", "demon_attack"] and e.at.day == night)
		if not scenes.is_empty():
			var victim: String = scenes[0].subjects[0]
			destinations = view.people.filter(func(p): return p.id == victim).map(func(p): return p.home)
	var result: Array = [{"path": [], "weight": 1.0 - rate}]
	var unknown_lamp: bool = profile == "gift" and role_of(cards, person.id) == ""
	if unknown_lamp:
		result.append({"path": C.BLOCKS.keys(), "weight": rate * 0.1})
	for destination in destinations:
		var path: Array = C.BLOCKS.keys() if profile == "gift" and role_of(cards, person.id) == "lamplighter" else C.route(person.home, destination)
		var weight: float = rate * (0.9 if unknown_lamp else 1.0) / maxf(destinations.size(), 1)
		if profile == "demon":
			for route in demon_routes(person.home, destination):
				result.append({"path": route.path, "weight": weight * route.weight})
		else:
			result.append({"path": path, "weight": weight})
	return result

## Marginalize a few extra paths, never add a detour variable to the world domain.
static func demon_routes(home: String, destination: String) -> Array:
	var key: String = home + ":" + destination
	if demon_route_cache.has(key):
		return demon_route_cache[key]
	var direct: Array = C.route(home, destination)
	var via: Array = C.BLOCKS.keys().filter(func(block): return block not in direct)
	var result: Array = [{"path": direct, "weight": 1.0 - DEMON_DETOUR if not via.is_empty() else 1.0}]
	for block in via:
		var path: Array = C.route(home, block) + C.route(block, destination).slice(1)
		result.append({"path": path, "weight": DEMON_DETOUR / via.size()})
	demon_route_cache[key] = result
	return result

## Explain relationships already scored by movement; these notes add no factors.
static func relationships(view: Dictionary, cards: Array) -> Array:
	var result: Array = []
	var seen = {}
	var blocks = {}
	for card in cards:
		if card.kind != "sighting" or card.get("quoted", false) or card.get("night", -1) < 1 or card.get("block", "") not in C.BLOCKS:
			continue
		for id in card.get("subjects", [card.get("subject", "")]):
			var people: Array = view.people.filter(func(p): return p.id == id)
			if people.is_empty():
				continue
			var person: Dictionary = people[0]
			if not blocks.has(id):
				blocks[id] = []
			if card.block not in blocks[id]:
				blocks[id].append(card.block)
			for event in view.get("timeline", {}).get("events", []):
				if event.kind not in ["demon_death", "demon_attack"] or event.at.day != card.night:
					continue
				var victims: Array = view.people.filter(func(p): return p.id in event.subjects)
				if victims.is_empty() or card.block in C.route(person.home, victims[0].home):
					continue
				var key: String = id + ":" + str(card.night)
				if not seen.has(key):
					seen[key] = true
					result.append("Seen elsewhere: %s's sighting on night %d argues strongly against being that night's killer; a Demon detour remains possible." % [person.name, card.night])
	for id in blocks:
		var role: String = role_of(cards, id)
		if blocks[id].size() >= 2 and C.ROLES.get(role, {}).get("night_walk", false):
			var person: Dictionary = view.people.filter(func(p): return p.id == id)[0]
			result.append("Scattered sightings: %s's movements fit the claimed %s gift. This is corroboration, not proof of that identity." % [person.name, C.role_name(role)])
	return result

static func _scion_succession_splits(view: Dictionary, cards: Array, full_profiles: Array) -> Array:
	var out: Array = []
	var execs: Dictionary = view.get("timeline", {}).get("executions", {})
	if execs.is_empty():
		return out
	var nights: Array = []
	for c in relevant(cards):
		if c.get("night", -1) >= 0 and c.night not in nights:
			nights.append(c.night)
	if nights.is_empty():
		return out
	for day_str in execs:
		var exec_day: int = int(day_str)
		# Execution happens at Day exec_day Evening (tick exec_day*4 + 2), promoting the Scion
		# BEFORE Night exec_day (tick exec_day*4 + 3). Pre-takeover nights are strictly < exec_day.
		if not nights.any(func(n): return n < exec_day):
			continue
		var alive_before: int = 0
		for p in view.people:
			if view.get("timeline", {}).get("death_ticks", {}).get(p.id, 2147483647) >= exec_day * 4 + 2:
				alive_before += 1
		if alive_before < 5:
			continue
		var pre_cards: Array = cards.filter(func(c): return c.get("night", -1) < 0 or c.night < exec_day)
		var post_cards: Array = cards.filter(func(c): return c.get("night", -1) < 0 or c.night >= exec_day)
		var pre_profiles: Array = []
		var post_profiles: Array = []
		var alive_mask: int = 0
		for i in range(view.people.size()):
			var p: Dictionary = view.people[i]
			if History.alive_at_night(view, p.id, exec_day):
				alive_mask |= (1 << i)
			pre_profiles.append({"good": _likelihood(view, pre_cards, p, "good"), "minion": _likelihood(view, pre_cards, p, "minion"), "demon": _likelihood(view, pre_cards, p, "demon")})
			post_profiles.append({"good": _likelihood(view, post_cards, p, "good"), "minion": _likelihood(view, post_cards, p, "minion"), "demon": _likelihood(view, post_cards, p, "demon")})
		var pre_scenes: Array = _build_scene_tables(view, pre_cards)
		var post_scenes: Array = _build_scene_tables(view, post_cards)
		for exec_id in execs[day_str]:
			var idx: int = view.people.map(func(p): return p.id).find(exec_id)
			if idx >= 0:
				out.append({"exec_day": exec_day, "executed_idx": idx, "alive_demon_mask": alive_mask, "pre_profiles": pre_profiles, "post_profiles": post_profiles, "pre_scenes": pre_scenes, "post_scenes": post_scenes})
	return out

## Normalized probability in [0, 1] that `person` walked across `scene_block` on `night`
## given non-trace movement observations in `cards` under `alignment`.
static func crossing_probability(view: Dictionary, cards: Array, person: Dictionary, night: int, alignment: String, scene_block: String) -> float:
	if not History.alive_at_night(view, person.id, night) or scene_block == "":
		return 0.0
	var role: String = role_of(cards, person.id)
	var gift: bool = C.ROLES.get(role, {}).get("night_walk", false)
	var profiles: Array = [{"kind": alignment, "weight": 1.0}] if alignment not in ["good", "converted"] else [
		{"kind": "ordinary", "weight": 0.2 if gift else 0.75},
		{"kind": "gift", "weight": 0.7 if gift else 0.15}, {"kind": "secret", "weight": 0.1}]
	if alignment in ["good", "converted"] and role != "" and not gift:
		profiles = [{"kind": "ordinary", "weight": 0.9}, {"kind": "secret", "weight": 0.1}]
	if alignment in ["good", "converted"] and role != "" and cards.any(func(c): return c.source == person.id and c.has("hearing_weight")):
		var strength: float = role_hearing(cards, person.id, role)
		profiles = [{"kind": "ordinary", "weight": lerpf(0.75, 0.2 if gift else 0.9, strength)}, {"kind": "gift", "weight": lerpf(0.15, 0.7 if gift else 0.0, strength)}, {"kind": "secret", "weight": 0.1}]
	var night_obs: Array = []
	var seen_inc: Array = []
	for c in relevant(cards):
		if c.get("night", -1) != night or c.kind == "trace" or (c.get("quoted", false) and c.kind != "alibi"):
			continue
		var inc: String = "alibi:" + c.subject if c.kind == "alibi" else c.id
		if inc not in seen_inc:
			seen_inc.append(inc)
			night_obs.append(c)
	var current: String = alignment
	if alignment == "converted" and view.get("chronology", {}).has("curse"):
		var curse: Dictionary = view.chronology.curse
		current = "minion" if night * 4 + 3 >= curse.from and night * 4 + 3 < curse.until else "good"
	var num_cross: float = 0.0
	var den_all: float = 0.0
	for prof in profiles:
		var pkind: String = "minion" if alignment == "converted" and current == "minion" else prof.kind
		var paths: Array = _profile_paths(view, person, night, pkind, cards)
		for evening in C.BLOCKS:
			var ev_p: float = 0.25
			for path_entry in paths:
				var w_p: float = float(prof.weight) * ev_p * float(path_entry.weight)
				for obs in night_obs:
					w_p *= _observed(obs, person.id, evening, path_entry.path, current, view, night, cards)
				den_all += w_p
				if not path_entry.path.is_empty() and scene_block in path_entry.path:
					num_cross += w_p
	if den_all <= 1e-20:
		return 0.0
	return clampf(num_cross / den_all, 0.0, 1.0)

static func _build_scene_tables(view: Dictionary, cards: Array) -> Array:
	var out: Array = []
	var has_curse: bool = view.get("chronology", {}).has("curse")
	var people_ids: Array = view.people.map(func(p): return p.id)
	var compiled_by_scene: Dictionary = {}
	var compiled_order: Array = []
	for ta in view.get("trace_assessments", []):
		if not ta is Dictionary:
			continue
		for cs in ta.get("scenes", []):
			var sc_key: String = str(cs.get("scene", ""))
			if sc_key == "":
				continue
			# Only evaluate scenes whose selected trace is actually attended in `cards`.
			var sel_id: String = str(cs.get("selected_trace_id", ""))
			if sel_id != "" and not cards.any(func(c): return not c.get("quoted", false) and c.id == sel_id):
				continue
			if not compiled_by_scene.has(sc_key):
				compiled_order.append(sc_key)
			compiled_by_scene[sc_key] = cs
	for sc_key in compiled_order:
		var cs: Dictionary = compiled_by_scene[sc_key]
		var c_night: int = int(cs.get("night", 1))
		var c_block: String = str(cs.get("scene_block", ""))
		var c_victim_idx: int = people_ids.find(str(cs.get("victim_id", "")))
		var c_two: bool = bool(cs.get("two_cited", false)) and cs.get("w2", []).size() == view.people.size()
		var c_count: int = maxi(2 if c_two else 1, int(cs.get("scene_trace_count", 1)))
		var c_good: Array = []
		var c_minion: Array = []
		var c_conv: Array = []
		if c_two or c_count >= 2:
			for p in view.people:
				c_good.append(crossing_probability(view, cards, p, c_night, "good", c_block))
				c_minion.append(crossing_probability(view, cards, p, c_night, "minion", c_block))
				if has_curse:
					c_conv.append(crossing_probability(view, cards, p, c_night, "converted", c_block))
		out.append({
			"scene": sc_key,
			"night": c_night,
			"scene_block": c_block,
			"victim_idx": c_victim_idx,
			"scene_trace_count": c_count,
			"two_cited": c_two,
			"w1": cs.get("w1", []).duplicate(),
			"w2": cs.get("w2", []).duplicate() if c_two else [],
			"cross_good": c_good,
			"cross_minion": c_minion,
			"cross_converted": c_conv,
		})
	var by_scene: Dictionary = {}
	var scene_order: Array = []
	for c in cards:
		if c.get("quoted", false) or c.kind != "trace" or not c.get("data", {}).has("family"):
			continue
		var sc_id: String = str(c.data.get("scene", ""))
		if sc_id == "" or compiled_by_scene.has(sc_id):
			continue
		var slot: int = int(c.data.get("slot", 0))
		if not by_scene.has(sc_id):
			by_scene[sc_id] = {}
			scene_order.append(sc_id)
		if not by_scene[sc_id].has(slot):
			by_scene[sc_id][slot] = c
	for sc_id in scene_order:
		var slot_map: Dictionary = by_scene[sc_id]
		var slots: Array = slot_map.keys()
		slots.sort()
		var t1: Dictionary = slot_map[slots[0]]
		var two_cited: bool = slots.size() >= 2
		var t2: Dictionary = slot_map[slots[1]] if two_cited else {}
		var night: int = int(t1.get("night", 1))
		var scene_block: String = str(t1.data.get("scene_block", ""))
		var victim_id: String = str(t1.data.get("victim", ""))
		var victim_idx: int = view.people.map(func(p): return p.id).find(victim_id)
		var scene_trace_count: int = maxi(slots.size(), int(t1.data.get("scene_trace_count", 1)))
		var w1: Array = []
		var w2: Array = []
		var cross_good: Array = []
		var cross_minion: Array = []
		var cross_converted: Array = []
		for p in view.people:
			w1.append(evaluate_trace_for_person(view, cards, t1, p.id).weight)
			if two_cited:
				w2.append(evaluate_trace_for_person(view, cards, t2, p.id).weight)
			if two_cited or scene_trace_count >= 2:
				cross_good.append(crossing_probability(view, cards, p, night, "good", scene_block))
				cross_minion.append(crossing_probability(view, cards, p, night, "minion", scene_block))
				if has_curse:
					cross_converted.append(crossing_probability(view, cards, p, night, "converted", scene_block))
		out.append({
			"scene": sc_id,
			"night": night,
			"scene_block": scene_block,
			"victim_idx": victim_idx,
			"scene_trace_count": scene_trace_count,
			"two_cited": two_cited,
			"w1": w1,
			"w2": w2,
			"cross_good": cross_good,
			"cross_minion": cross_minion,
			"cross_converted": cross_converted,
		})
	return out

## Three-valued evaluation of a structured trace against ONLY the receipts present in `cards`.
## Returns {"state": "matches" | "unknown" | "contradicts", "weight": float, "missing": String, "reason": String}.
static func evaluate_trace_for_person(view: Dictionary, cards: Array, trace_card: Dictionary, person_id: String) -> Dictionary:
	var d: Dictionary = trace_card.get("data", {})
	var fam: String = d.get("family", "")
	var night: int = int(trace_card.get("night", d.get("day", -1)))
	var match_w: float = Tuning.Setup.TRACE_MATCH_WEIGHT
	var unk_w: float = Tuning.Setup.TRACE_UNKNOWN_WEIGHT
	var contra_w: float = Tuning.Setup.TRACE_CONTRADICT_WEIGHT
	if fam == "locations":
		var locs: Array = d.get("locs", [])
		var work_loc: String = ""
		var haunts: Array = []
		for c in cards:
			if c.get("quoted", false) or c.get("kind", "") != "context":
				continue
			if c.get("subject", "") != person_id:
				continue
			if c.get("context_kind", "") == "work":
				work_loc = c.get("data", {}).get("loc", "")
			elif c.get("context_kind", "") == "haunt":
				for hl in c.get("data", {}).get("locs", [c.get("data", {}).get("loc", "")]):
					if hl != "" and hl not in haunts:
						haunts.append(hl)
		if work_loc != "" and work_loc in locs:
			return {"state": "matches", "weight": match_w, "missing": "", "reason": "works at " + C.LOCATIONS.get(work_loc, {}).get("name", work_loc)}
		for hl in haunts:
			if hl in locs:
				return {"state": "matches", "weight": match_w, "missing": "", "reason": "frequents " + C.LOCATIONS.get(hl, {}).get("name", hl)}
		if work_loc != "" and haunts.size() >= 2:
			return {"state": "contradicts", "weight": contra_w, "missing": "", "reason": "work and both haunts outside trace"}
		var missing_parts: Array = []
		if work_loc == "":
			missing_parts.append("work uncited")
		if haunts.size() < 2:
			missing_parts.append("%d haunt%s unknown/uncited" % [2 - haunts.size(), "s" if 2 - haunts.size() > 1 else ""])
		return {"state": "unknown", "weight": unk_w, "missing": ", ".join(PackedStringArray(missing_parts)), "reason": ""}
	elif fam == "quarter":
		var hb: String = d.get("home_block", "")
		var eb: String = d.get("evening_block", "")
		var cited_home: String = ""
		var evening_blocks: Array = []
		for c in cards:
			if c.get("quoted", false):
				continue
			if c.get("kind", "") == "context" and c.get("subject", "") == person_id:
				if c.get("context_kind", "") == "home":
					cited_home = c.get("block", c.get("data", {}).get("block", ""))
				elif c.get("context_kind", "") == "work":
					var phases: Array = c.get("data", {}).get("work_phases", [])
					var wloc: String = c.get("data", {}).get("loc", "")
					if C.EVENING in phases and C.LOCATIONS.has(wloc):
						var wb: String = C.LOCATIONS[wloc]["block"]
						if wb not in evening_blocks:
							evening_blocks.append(wb)
			elif c.get("kind", "") == "evening" and c.get("night", -1) == night and person_id in c.get("subjects", [c.get("subject", "")]):
				var sb: String = c.get("block", "")
				if sb != "" and sb not in evening_blocks:
					evening_blocks.append(sb)
		if cited_home != "" and cited_home == hb:
			return {"state": "matches", "weight": match_w, "missing": "", "reason": "lives on " + C.block_name(hb)}
		if eb in evening_blocks:
			return {"state": "matches", "weight": match_w, "missing": "", "reason": "on %s on evening %d" % [C.block_name(eb), night]}
		if cited_home != "" and cited_home != hb and not evening_blocks.is_empty() and not (eb in evening_blocks):
			return {"state": "contradicts", "weight": contra_w, "missing": "", "reason": "lives elsewhere and spent evening %d off %s" % [night, C.block_name(eb)]}
		var q_missing: Array = []
		if cited_home == "":
			q_missing.append("home uncited")
		if evening_blocks.is_empty():
			q_missing.append("evening %d unknown" % night)
		return {"state": "unknown", "weight": unk_w, "missing": ", ".join(PackedStringArray(q_missing)), "reason": ""}
	elif fam == "connection":
		var victim: String = d.get("victim", "")
		var vblock: String = d.get("victim_block", d.get("scene_block", ""))
		var cited_home: String = ""
		var has_bond: bool = false
		var shared_day: bool = false
		var victim_day_locs = {}
		var person_day_phases = {}
		for c in cards:
			if c.get("quoted", false):
				continue
			if c.get("kind", "") == "context":
				if c.get("context_kind", "") == "home" and c.get("subject", "") == person_id:
					cited_home = c.get("block", c.get("data", {}).get("block", ""))
				elif c.get("context_kind", "") == "bond":
					var subs: Array = c.get("subjects", [])
					if person_id in subs and victim in subs:
						has_bond = true
			elif c.get("kind", "") in ["location", "evening"] and int(c.get("day", c.get("night", -1))) == night:
				var subs2: Array = c.get("subjects", [c.get("subject", "")])
				if person_id in subs2 and victim in subs2:
					shared_day = true
				var ph_name: String = str(c.get("observed_at", {}).get("phase", ""))
				var cloc: String = c.get("loc", "")
				if victim in subs2 and cloc != "" and ph_name != "":
					victim_day_locs[ph_name] = cloc
				if person_id in subs2 and ph_name != "":
					person_day_phases[ph_name] = cloc if cloc != "" else ("block:" + c.get("block", ""))
		for ph_k in victim_day_locs:
			if person_day_phases.get(ph_k, "") == victim_day_locs[ph_k]:
				shared_day = true
		if has_bond:
			return {"state": "matches", "weight": match_w, "missing": "", "reason": "known bond with victim"}
		if cited_home != "" and cited_home == vblock:
			return {"state": "matches", "weight": match_w, "missing": "", "reason": "lives on " + C.block_name(vblock)}
		if shared_day:
			return {"state": "matches", "weight": match_w, "missing": "", "reason": "crossed paths on day %d" % night}
		if cited_home != "" and cited_home != vblock and person_day_phases.size() >= 2:
			return {"state": "contradicts", "weight": Tuning.Setup.TRACE_CONNECTION_MISS_WEIGHT, "missing": "", "reason": "no cited bond, home, or day-%d overlap" % night}
		return {"state": "unknown", "weight": unk_w, "missing": "bonds or day-%d overlap unresolved" % night, "reason": ""}
	return {"state": "unknown", "weight": 1.0, "missing": "", "reason": ""}

static func _observed(card: Dictionary, person: String, evening: String, path: Array, alignment: String, view: Dictionary, night: int, all_cards: Array = []) -> float:
	if card.get("quoted", false) and card.kind != "alibi":
		return 1.0
	var out: bool = not path.is_empty()
	match card.kind:
		"sighting":
			if person in card.get("subjects", [card.get("subject", "")]):
				var matches_block: bool = card.block == "" or (C.vigil_sees_path(card.block, path) if card.get("complete", false) else card.block in path)
				return 1.0 if out and matches_block else 1.0 - float(card.get("hearing_weight", 1.0))
			if card.get("complete", false) and person not in card.get("excluded", []):
				return 1.0 if not C.vigil_sees_path(card.block, path) else 0.0
		"evening":
			if person in card.get("subjects", [card.get("subject", "")]):
				return 1.0 if card.block == evening else 0.0
		"coverage":
			if person not in card.get("excluded", []):
				return 1.0 if not C.vigil_sees_path(card.block, path) else 0.0
		"alibi":
			if card.subject == person:
				if not card.get("quoted", false):
					return 1.0 if not out else 0.0
				return (0.7 if alignment != "good" else 0.3) if out else 0.9
		"report":
			if card.role == "warden" and card.source == person:
				return 1.0 if out and path.back() == card.block else 0.0
			if card.role == "medium" and card.source == person:
				return 1.0 if out and path.back() == card.data.get("block", card.get("block", "")) else 0.0
			if card.role == "lamplighter" and card.source == person and card.get("duty_only", false):
				return 1.0 if path.size() == C.BLOCKS.size() else 0.0
			if card.role == "nightwatch":
				if card.source == person:
					return 1.0 if out and path.back() == card.data.block else 0.0
				if card.get("duty_only", false):
					return 1.0
				var nw_err: float = clampf(float(card.get("report_error", Tuning.Workshop.NIGHTWATCH_REPORT_ERROR)), 0.02, 0.45)
				return (1.0 - nw_err) if ((card.data.block in path) == (person in card.data.seen)) else nw_err
		"trace":
			if alignment == "demon":
				if card.get("data", {}).has("family"):
					return 1.0 # Scored jointly per scene in _scene_score (single & two-trace aware).
				# Legacy block-material fixture formula (retained for existing movement tests).
				return (0.6 if card.data.material == evening else 0.0) + 0.4 / C.BLOCKS.size()
	return 1.0
