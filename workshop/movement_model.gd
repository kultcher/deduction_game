## Bounded generative experiment. Hypotheses persist across nights; observations
## of one incident are conjoined, not multiplied as independent outings.
extends RefCounted
const C = preload("res://sim/content.gd")
const Live = preload("res://workshop/live_activity.gd")
static var cache: Dictionary = {}

static func available(view: Dictionary) -> bool:
	return view.has("movement_experiment") or Live.available(view)

static func claim_refs(view: Dictionary, value: Dictionary) -> Array:
	if not available(view):
		return []
	return value.get("citations", {}).values()

static func evidence(view: Dictionary, cards: Array) -> Array:
	return cards.filter(func(c): return c.kind in ["sighting", "coverage", "evening", "trace", "item"] or (c.kind == "alibi" and c.get("quoted", false)) or c.get("role") == "nightwatch") if available(view) else []

static func factors(view: Dictionary, cards: Array, value: Dictionary) -> Array:
	if Live.available(view):
		return Live.factors(view, cards, value)
	if not available(view):
		return []
	var model: Dictionary = view.movement_experiment
	var result: Array = []
	for subject in model.subjects:
		var observed = evidence(view, cards).filter(func(c): return c.get("subject", "") == subject or subject in c.get("data", {}).get("seen", []))
		if observed.is_empty():
			continue
		var cited: Array = value.get("citations", {}).values()
		var gift: bool = cards.any(func(c): return c.id in cited and c.kind == "claim" and c.subject == subject and C.ROLES.get(c.get("role", ""), {}).get("night_walk", false))
		var secret: bool = cards.any(func(c): return c.id in cited and c.kind == "secret_claim" and c.subject == subject)
		var good = likelihood(view, observed, subject, false, gift, secret)
		var marked_good = likelihood(view, observed, subject, false, gift, secret, true)
		var evil = likelihood(view, observed, subject, true, gift, secret)
		result.append({"target": subject, "log2_ratio": log(maxf(evil, 1e-12) / maxf(good, 1e-12)) / log(2.0),
			"label": "Movement / trace comparison: " + subject, "good_likelihood": good, "good_marked_likelihood": marked_good, "evil_likelihood": evil,
			"cards": observed.map(func(c): return c.id), "origin": "movement_model"})
	return result

static func likelihood(view: Dictionary, cards: Array, subject: String, evil: bool, gift: bool = false, secret: bool = false, marked: bool = false) -> float:
	var rules: Dictionary = view.movement_experiment
	if marked:
		secret = false # Secret modifiers are exclusive in the actual NPC model.
	var inputs = [view.people, rules, cards, subject, evil, gift, secret, marked]
	var key = hash(inputs)
	if cache.has(key) and cache[key].inputs == inputs:
		return cache[key].value
	var profiles: Array = [{"kind": "hunt", "weight": 1.0 / 3.0}, {"kind": "minion", "weight": 2.0 / 3.0}] if evil else [
		{"kind": "ordinary", "weight": 0.75 if not gift and not secret else 0.2},
		{"kind": "gift", "weight": 0.15 if not gift and not secret else (0.7 if gift else 0.1)},
		{"kind": "secret", "weight": 0.1 if not gift and not secret else (0.7 if secret else 0.1)}]
	if marked and not evil:
		profiles = profiles.filter(func(p): return p.kind != "secret")
		var normalization = 0.0
		for profile in profiles:
			normalization += profile.weight
		for profile in profiles:
			profile.weight /= normalization
	var total = 0.0
	# A common evening haunt is one latent cause shared by repeated soot reports.
	for profile in profiles:
		for haunt in C.BLOCKS:
			var p: float = profile.weight / float(C.BLOCKS.size())
			var nights: Array = []
			for card in cards:
				if card.night not in nights:
					nights.append(card.night)
			for night in nights:
				var reports: Array = cards.filter(func(c): return c.night == night)
				var night_p = 0.0
				var out_rate: float = {"hunt": 1.0, "minion": 0.25, "gift": 1.0, "secret": 0.55, "ordinary": 0.05}[profile.kind]
				var eligible: Array = rules.gift_destinations[subject][str(int(night))]
				if profile.kind == "gift" and eligible.is_empty():
					out_rate = 0.0
				for out in [false, true]:
					for destination in C.BLOCKS:
						var dest_p: float = 1.0 / C.BLOCKS.size()
						if profile.kind == "hunt":
							dest_p = 1.0 if destination == rules.scenes[str(int(night))] else 0.0
						elif profile.kind == "gift" and not eligible.is_empty():
							dest_p = 1.0 / eligible.size() if destination in eligible else 0.0
						var home: String = view.people.filter(func(p0): return p0.id == subject)[0].home
						var path: Array = C.route(home, destination) if out else []
						var route_p: float = (out_rate if out else 1.0 - out_rate) * dest_p
						var incident = _incident(profile.kind, haunt, rules.get("haunt_visit", 0.7), out, path, reports)
						night_p += route_p * incident
				p *= night_p
			total += p
	if cache.size() > 256:
		cache.clear()
	cache[key] = {"inputs": inputs.duplicate(true), "value": total}
	return total

static func _incident(kind: String, haunt: String, haunt_visit: float, out: bool, path: Array, reports: Array) -> float:
	var total = 0.0
	for evening in C.BLOCKS:
		var incident: float = haunt_visit if evening == haunt else (1.0 - haunt_visit) / 3.0
		var facts: Array = []
		for card in reports:
			var fact_key: String = card.get("fact_id", card.id)
			if fact_key in facts:
				continue
			facts.append(fact_key)
			match card.kind:
				"sighting": incident *= 1.0 if out and card.block in path else 0.0
				"report":
					var block: String = card.get("block", card.data.get("block", ""))
					incident *= 1.0 if out and (block == "" or block in path) else 0.0
				"coverage":
					var detection: float = card.data.detection if out and card.block in path else 0.0
					incident *= detection if card.data.seen else 1.0 - detection
				"evening": incident *= 1.0 if card.block == evening else 0.0
				"alibi":
					# Both evil activity and a good private errand can explain concealment.
					incident *= {"hunt": 0.7, "minion": 0.7, "secret": 0.65, "gift": 0.15, "ordinary": 0.2}[kind] if out else 0.9
				"trace":
					var q: Dictionary = trace_distribution(evening, card.data.passers) if kind == "hunt" else passer_distribution(card.data.background, card.data.passers, out and card.data.scene_block in path, evening)
					incident *= q.get(card.data.material, 0.0)
				"item":
					var drop: float = (0.35 if kind == "hunt" else 0.15) * 0.12
					incident *= drop / maxf(path.size(), 1.0) / card.data.locations_in_block if out and card.block in path else 0.0
		total += incident
	return total

static func trace_distribution(demon_evening: String, passers: Array) -> Dictionary:
	var result = {}
	for block in C.BLOCKS:
		result[block] = 0.0
	result[demon_evening] = 1.0 if passers.is_empty() else 0.6
	for passer in passers:
		result[passer] += 0.4 / passers.size()
	return result

static func passer_distribution(background: Dictionary, passers: Array, subject_passed: bool, evening: String) -> Dictionary:
	var result = {}
	var eligible: Array = passers.duplicate()
	if subject_passed:
		eligible.append(evening)
	for demon_evening in background:
		var conditional = trace_distribution(demon_evening, eligible)
		for block in conditional:
			result[block] = result.get(block, 0.0) + background[demon_evening] * conditional[block]
	return result
