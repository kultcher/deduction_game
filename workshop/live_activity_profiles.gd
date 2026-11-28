## Movement inputs and per-person profiles: which cards the movement model reads, claimed
## roles, each person's candidate paths and activity profiles (demon routes, day-demon share),
## and the GDScript single-person likelihood, crossing and trace readings (split from
## `workshop/live_activity.gd`; part of LiveActivity's inheritance chain).
extends "res://workshop/live_activity_base.gd"
static var demon_route_cache = {}

static func relevant(cards: Array) -> Array:
	return cards.filter(func(c): return c.kind in ["sighting", "evening", "trace", "coverage", "alibi"] or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran", "medium", "monitor"]))

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
	return [cards.filter(func(c): return c.has("relay_source") or c.kind in ["sighting", "evening", "trace", "coverage", "alibi"] or (include_context and c.kind == "secret_claim") or (has_struct_trace and ((c.kind == "context" and c.get("context_kind", "") in ["home", "work", "haunt", "bond"]) or c.kind == "location")) or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran", "medium", "monitor", "sexton"])), roles]

static func role_of(cards: Array, person: String, knowledge: Dictionary = {}) -> String:
	if person == knowledge.get("self", ""):
		return knowledge.get("own_role", "")
	for card in cards:
		if card.get("relay_source") == person and not card.get("quoted", false):
			return "medium"
		if not card.get("quoted", false) and not card.get("testimony_only", false) and card.get("source", "") == person and card.kind in ["claim", "report"]:
			return card.role
	return ""

## Whether the person's own (unquoted) Sexton report says it tolled on this night.
static func sexton_tolled(cards: Array, person: String, night: int) -> bool:
	for card in cards:
		if card.get("kind", "") == "report" and str(card.get("role", "")) == "sexton" and not card.get("quoted", false) \
				and str(card.get("source", "")) == person and int(card.get("data", {}).get("night", card.get("night", -1))) == night:
			return true
	return false

static func role_hearing(cards: Array, person: String, role: String) -> float:
	var strength = 0.0
	for card in cards:
		if not card.get("quoted", false) and not card.get("testimony_only", false) and card.get("source", "") == person and card.get("role", "") == role and card.kind in ["claim", "report"]:
			strength = maxf(strength, float(card.get("hearing_weight", 1.0)))
	return strength

# --- Routes & Paths ---

static func _paths(view: Dictionary, person: Dictionary, night: int, cards: Array, knowledge: Dictionary, strict_reports: bool = true) -> Array:
	if not History.alive_at_night(view, person.id, night):
		return [[]]
	var role = role_of(cards, person.id, knowledge)
	var paths: Array = [[]]
	for block in C.BLOCKS:
		paths.append(C.route(person.home, block))
	if role in ["", "lamplighter"] or (role == "sexton" and sexton_tolled(cards, person.id, night)):
		paths.append(C.BLOCKS.keys())
	var result: Array = []
	for path in paths:
		var out: bool = not path.is_empty()
		if knowledge.get("self") == person.id and knowledge.get("own_outings", {}).has(str(night)) and out != knowledge.own_outings[str(night)]:
			continue
		var okay = true
		for card in cards:
			if strict_reports and card.has("relay_source") and not card.get("quoted", false) and card.relay_source == person.id and card.relay_observed_at.day == night:
				var hearth: String = view.people.filter(func(p): return p.id == card.source)[0].home
				okay = okay and out and path.back() == hearth
			if card.get("night", -1) != night or card.get("quoted", false):
				continue
			if card.kind == "sighting" and (card.get("hearing_weight", 1.0) < 1.0 or card.get("admitted", false)):
				continue  # (an admitted outing is only the teller's word: no hard route)
			if card.kind == "sighting" and person.id in card.get("subjects", [card.get("subject", "")]):
				okay = okay and out and (card.block == "" or (C.vigil_sees_path(card.block, path, str(person.get("home", ""))) if card.get("complete", false) else card.block in path))
				if card.has("guard_claim"):
					okay = okay and out and path.back() == card.block
			elif card.kind == "sighting" and card.get("complete", false) and person.id not in card.get("excluded", []):
				# Logical consistency; the probabilistic score uses VIGIL_MISS instead.
				okay = okay and not C.vigil_sees_path(card.block, path, str(person.get("home", "")))
			elif card.kind == "alibi" and card.subject == person.id and not card.get("known_self", false):
				okay = okay and not out
			elif card.kind == "coverage" and person.id not in card.get("excluded", []):
				okay = okay and not C.vigil_sees_path(card.block, path, str(person.get("home", "")))
			elif card.kind == "report" and card.role == "nightwatch":
				if strict_reports and card.source == person.id:
					okay = okay and out and path.back() == card.data.block
				elif strict_reports and not card.get("duty_only", false):
					okay = okay and ((card.data.block in path) == (person.id in card.data.seen))
			elif strict_reports and card.kind == "report" and card.role == "monitor" and card.source != person.id and not card.get("duty_only", false) and not card.get("data", {}).get("walked", false):
				# "No one walked by my house": nobody else's route crossed the Monitor's block.
				okay = okay and not (card.data.block in path)
			elif strict_reports and card.kind == "report" and card.role == "warden" and card.source == person.id:
				okay = okay and out and path.back() == card.get("block", "")
			elif strict_reports and card.kind == "report" and card.role == "medium" and card.source == person.id:
				okay = okay and out and path.back() == card.data.get("block", card.get("block", ""))
			elif strict_reports and card.kind == "report" and card.role == "lamplighter" and card.source == person.id:
				okay = okay and path.size() == C.BLOCKS.size()
			if not okay:
				break
		if okay:
			result.append(path)
	return result

## The listener's known home nights (view.own_home) as movement cards: one soft alibi a
## night ("I know I was home"), doubted only by its self-doubt (FlagKnownSelf). They exist
## only inside the movement model, so the sighting contests and profiles weigh a sighting
## of the listener out against whoever told it.
static func own_home_cards(view: Dictionary) -> Array:
	var own: Dictionary = view.get("own_home", {})
	var me: String = str(own.get("self", ""))
	if me == "" or not view.get("people", []).any(func(p): return p.id == me):
		return []
	var out: Array = []
	for k in own.get("nights", {}):
		var nd: int = int(k)
		out.append({"id": "own-home:%s:%d" % [me, nd], "kind": "alibi", "source": me, "subject": me, "subjects": [me],
			"block": str(own.get("block", "")), "night": nd, "observed_at": {"day": nd, "phase": "night"}, "data": {},
			"known_self": true, "self_doubt": float(own.nights[k])})
	# Nights out: "I know where I walked" (reading-note gap 2), the same soft knowledge.
	for k in own.get("out_nights", {}):
		var nd: int = int(k)
		out.append({"id": "own-out:%s:%d" % [me, nd], "kind": "alibi", "source": me, "subject": me, "subjects": [me],
			"block": str(own.get("block", "")), "night": nd, "observed_at": {"day": nd, "phase": "night"}, "data": {},
			"known_self": true, "route": own.out_nights[k].duplicate(), "self_doubt": Tuning.Workshop.OWN_ERR})
	out.sort_custom(func(a, b): return a.night < b.night)
	return out

static func _likelihood_gd(view: Dictionary, cards: Array, person: Dictionary, alignment: String) -> float:
	var relevant_cards = relevant(cards)
	var nights: Array = []
	for card in relevant_cards:
		if card.get("night", -1) >= 0 and card.night not in nights:
			nights.append(card.night)
	var role = role_of(cards, person.id)
	var gift: bool = C.ROLES.get(role, {}).get("night_walk", false)
	var profiles: Array = [{"kind": alignment, "weight": 1.0}] if alignment not in ["good", "converted"] else [
		{"kind": "ordinary", "weight": WALKER_CLAIM_HOME if gift else 0.75},
		{"kind": "gift", "weight": WALKER_CLAIM_GIFT if gift else 0.15}, {"kind": "secret", "weight": WALKER_CLAIM_SECRET if gift else 0.1}]
	if alignment in ["good", "converted"] and role != "" and not gift:
		profiles = [{"kind": "ordinary", "weight": 0.9}, {"kind": "secret", "weight": 0.1}]
	if alignment in ["good", "converted"] and role != "" and cards.any(func(c): return c.get("source", "") == person.id and c.has("hearing_weight")):
		var strength: float = role_hearing(cards, person.id, role)
		profiles = [{"kind": "ordinary", "weight": lerpf(0.75, WALKER_CLAIM_HOME if gift else 0.9, strength)}, {"kind": "gift", "weight": lerpf(0.15, WALKER_CLAIM_GIFT if gift else 0.0, strength)}, {"kind": "secret", "weight": lerpf(0.1, WALKER_CLAIM_SECRET if gift else 0.1, strength)}]
	if alignment in ["good", "converted"] and not secret_errand:
		profiles = _without_errand(profiles)
	var reports_by_night: Array = []
	for night in nights:
		var reports: Array = []
		var incidents: Array = []
		for card in relevant_cards:
			if card.night != night:
				continue
			var incident: String = _alibi_incident(card) if card.kind == "alibi" else (("trace:%s:%d" % [str(card.data.get("scene", "")), int(card.data.get("slot", 0))]) if card.kind == "trace" else card.id)
			if incident in incidents:
				continue
			incidents.append(incident)
			reports.append(card)
		reports_by_night.append(reports)
	var total = 0.0
	for profile in profiles:
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
						p *= _observed(card, person.id, evening, path.path, current, view, night, cards, alignment)
					products.append(p)
				by_evening.append(products)
			tables.append(by_evening)
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

## Whether the script deals Unrequited (burdens prototype): the movement model then scores a
## good holder on their own column, in the worlds where they hold it.
static func deals_unrequited(view: Dictionary) -> bool:
	return "unrequited" in view.get("world_options", {}).get("modifiers", [])

## A good person's movement likelihood as the Unrequited holder (C#:
## LiveActivityKernel.UnrequitedLikelihood, which the kernel uses; this is the mirror the
## suites check it against). Their good profiles, with the ordinary one also visiting the
## beloved: on UNREQUITED_VISIT_CHANCE of nights, forced the night after a missed one once
## they've visited (sim/burdens.gd unrequited_visit), forward over nights 0 to the last night
## a card is about. A visit is the way to the beloved's block (home if it's theirs, the hill
## once the beloved is dead); other nights the ordinary paths without a claimed walk's raised
## rate. The beloved: the one their own Unrequited claim names, else anyone else.
static func _unrequited_likelihood_gd(view: Dictionary, cards: Array, person: Dictionary) -> float:
	var q: float = Tuning.Burden.UNREQUITED_VISIT_CHANCE
	var relevant_cards = relevant(cards)
	var nights: Array = []
	for card in relevant_cards:
		if card.get("night", -1) >= 0 and card.night not in nights:
			nights.append(card.night)
	var role = role_of(cards, person.id)
	var gift: bool = C.ROLES.get(role, {}).get("night_walk", false)
	var profiles: Array = [{"kind": "ordinary", "weight": WALKER_CLAIM_HOME if gift else 0.75},
		{"kind": "gift", "weight": WALKER_CLAIM_GIFT if gift else 0.15}, {"kind": "secret", "weight": WALKER_CLAIM_SECRET if gift else 0.1}]
	if role != "" and not gift:
		profiles = [{"kind": "ordinary", "weight": 0.9}, {"kind": "secret", "weight": 0.1}]
	if role != "" and cards.any(func(c): return c.get("source", "") == person.id and c.has("hearing_weight")):
		var strength: float = role_hearing(cards, person.id, role)
		profiles = [{"kind": "ordinary", "weight": lerpf(0.75, WALKER_CLAIM_HOME if gift else 0.9, strength)}, {"kind": "gift", "weight": lerpf(0.15, WALKER_CLAIM_GIFT if gift else 0.0, strength)}, {"kind": "secret", "weight": lerpf(0.1, WALKER_CLAIM_SECRET if gift else 0.1, strength)}]
	if not secret_errand:
		profiles = _without_errand(profiles)
	var reports_by_night: Array = []
	for night in nights:
		var reports: Array = []
		var incidents: Array = []
		for card in relevant_cards:
			if card.night != night:
				continue
			var incident: String = _alibi_incident(card) if card.kind == "alibi" else (("trace:%s:%d" % [str(card.data.get("scene", "")), int(card.data.get("slot", 0))]) if card.kind == "trace" else card.id)
			if incident in incidents:
				continue
			incidents.append(incident)
			reports.append(card)
		reports_by_night.append(reports)
	var named: String = ""
	for card in cards:
		if card.get("kind", "") == "secret_claim" and not card.get("quoted", false) and claim_walks(card) and str(card.get("source", "")) == person.id \
				and str(card.get("subject", "")) == person.id and str(card.get("data", {}).get("beloved", "")) in ids_of_view(view) and str(card.data.beloved) != person.id:
			named = str(card.data.beloved)
			break
	var beloveds: Array = [named] if named != "" else view.people.filter(func(p): return p.id != person.id).map(func(p): return p.id)
	# An announced spell break stops the visits from that meeting's night on (as the kernel).
	var break_night: int = 1 << 30
	for card in cards:
		if card.get("kind", "") == "secret_claim" and not card.get("quoted", false) and str(card.get("source", "")) == person.id \
				and str(card.get("subject", "")) == person.id and bool(card.get("data", {}).get("spell_broken", false)):
			var bd: int = int(card.get("observed_at", {}).get("day", -1))
			if bd >= 0:
				break_night = mini(break_night, bd)
	var max_night: int = -1
	for night in nights:
		max_night = maxi(max_night, int(night))
	var total: float = 0.0
	for profile in profiles:
		var visits: bool = profile.kind == "ordinary"
		var ord: Array = []
		var vis: Array = []
		for n in range(nights.size()):
			var night: int = nights[n]
			var paths: Array = _profile_paths(view, person, night, profile.kind, cards, visits)
			var by_e: Array = []
			for evening in C.BLOCKS:
				var sum: float = 0.0
				for path in paths:
					var pv: float = path.weight
					for card in reports_by_night[n]:
						pv *= _observed(card, person.id, evening, path.path, "good", view, night, cards, "good")
					sum += pv
				by_e.append(sum)
			ord.append(by_e)
			if not visits:
				vis.append([])
				continue
			var per_b: Array = []
			for b_id in beloveds:
				var b: Dictionary = view.people.filter(func(p): return p.id == b_id)[0]
				var path: Array = []
				if not History.alive_at_night(view, person.id, night):
					path = []
				elif not History.alive_at_night(view, b_id, night):
					path = C.route(person.home, "hill")
				elif b.home != person.home:
					path = C.route(person.home, b.home)
				var by_e_v: Array = []
				for evening in C.BLOCKS:
					var pv: float = 1.0
					for card in reports_by_night[n]:
						pv *= _observed(card, person.id, evening, path, "good", view, night, cards, "good")
					by_e_v.append(pv)
				per_b.append(by_e_v)
			vis.append(per_b)
		for haunt in C.BLOCKS:
			var w0: float = profile.weight / C.BLOCKS.size()
			var fo_n: Array = []
			for n in range(nights.size()):
				var sum: float = 0.0
				var e: int = 0
				for evening in C.BLOCKS:
					sum += (0.7 if evening == haunt else 0.1) * float(ord[n][e])
					e += 1
				fo_n.append(sum)
			if not visits:
				var weight: float = w0
				for n in range(nights.size()):
					weight *= float(fo_n[n])
				total += weight
				continue
			var acc: float = 0.0
			for bi in range(beloveds.size()):
				var s_n: float = 1.0
				var s_v: float = 0.0
				var s_m: float = 0.0
				for night in range(max_night + 1):
					var n: int = nights.find(night)
					var fo: float = 1.0
					var fv: float = 1.0
					if n >= 0:
						fo = float(fo_n[n])
						fv = 0.0
						var e: int = 0
						for evening in C.BLOCKS:
							fv += (0.7 if evening == haunt else 0.1) * float(vis[n][bi][e])
							e += 1
					if night >= break_night:
						s_n = (s_n + s_v + s_m) * fo
						s_v = 0.0
						s_m = 0.0
						continue
					if role == "sexton" and sexton_tolled(cards, person.id, night):
						# The toll walk first, then no visit; a due visit stays due (as the kernel).
						var t_m: float = (s_v + s_m) * fo
						s_n = s_n * fo
						s_v = 0.0
						s_m = t_m
						continue
					var nn: float = s_n * (1.0 - q) * fo
					var nv: float = (s_n * q + s_v * q + s_m) * fv
					var nm: float = s_v * (1.0 - q) * fo
					s_n = nn
					s_v = nv
					s_m = nm
				acc += s_n + s_v + s_m
			total += w0 * acc / beloveds.size()
	return total

static func ids_of_view(view: Dictionary) -> Array:
	return view.people.map(func(p): return p.id)

## The share of the script's possible demons that never walk at night (the day-killer,
## docs/demon_types_plan.md). 0 on every script the game deals today, which leaves every
## movement likelihood exactly as before.
## Daytime presence evidence the Hexer factor reads (DayPresence): the watch record and
## morning/afternoon location reports.
static func has_day_evidence(cards: Array) -> bool:
	return cards.any(func(c): return c.get("kind", "") in ["watch_log", "location"])

## The demon-type declaration (game/demon_declaration.gd; docs/belief_model.md,
## Phase 2) sets the town's mix: "walker" = no day demon, "hexer" = day demon only. It reaches
## the view as `declared_demon_type`; this static stands in for it in developer experiments
## (tools/measure_evidence.gd --declare), where it overrides the view's. Empty in play.
static var declared_demon_type: String = ""

static func day_demon_share(view: Dictionary) -> float:
	var declared: String = declared_demon_type
	if declared == "":
		declared = str(view.get("declared_demon_type", ""))
	if declared == "walker":
		return 0.0
	if declared == "hexer":
		return 1.0
	var demons: Array = view.get("script_demons", [])
	if demons.is_empty():
		return 0.0
	var day: int = 0
	for d in demons:
		if C.is_day_demon(str(d)):
			day += 1
	return float(day) / float(demons.size())

## The demon slot's movement likelihood, mixed over the script's demon types. A day-killer
## kills without walking, so at night it's out like a minion. The type is one hidden fact for
## the whole case, and in any world only the demon's own movement factor depends on it, so
## mixing that person's whole likelihood (every night at once) is exact:
##   sum_t pi_t * prod_i L_i^t = prod_{i != demon} L_i * (pi_walk * L_walk + pi_day * L_still).
## Mixing night by night instead would act as if the type were redrawn each night, and
## evidence about it wouldn't build up. Trace and scene factors don't change: either demon
## is at the victim's house. Returns `walking` untouched when the share is 0.
static func mix_demon(walking: float, still: float, share: float) -> float:
	if share <= 0.0:
		return walking
	return walking * (1.0 - share) + still * share

## How often a good person is out on a night, as the movement model's good profile has it,
## from what the cards say they claim (ReadingChallenges._outing_poison_chance): its profile
## weights (_likelihood_gd) times each profile's walk rate (_profile_paths).
static func good_walk_chance(cards: Array, person: String) -> float:
	var role: String = role_of(cards, person)
	var gift: bool = bool(C.ROLES.get(role, {}).get("night_walk", false))
	if role != "" and not gift:
		return 0.9 * PROFILE_RATES.ordinary + 0.1 * PROFILE_RATES.secret
	if gift:
		return WALKER_CLAIM_HOME * PROFILE_RATES.ordinary + WALKER_CLAIM_GIFT * PROFILE_RATES.gift + WALKER_CLAIM_SECRET * PROFILE_RATES.secret
	return 0.75 * PROFILE_RATES.ordinary + 0.15 * PROFILE_RATES.gift + 0.1 * PROFILE_RATES.secret

## Each profile's chance of being out on a night (the C# kernel's BuildProfilePaths has the same).
const PROFILE_RATES = {"minion": 0.25, "gift": 1.0, "secret": 0.55, "ordinary": 0.05}

static func _profile_paths(view: Dictionary, person: Dictionary, night: int, profile: String, cards: Array, skip_claim_bump: bool = false) -> Array:
	var rates = {"demon": 1.0 if night > 0 else 0.0, "minion": PROFILE_RATES.minion, "gift": PROFILE_RATES.gift, "secret": PROFILE_RATES.secret, "ordinary": PROFILE_RATES.ordinary}
	var rate: float = rates[profile]
	if profile == "gift" and night < 1 and role_of(cards, person.id) == "warden":
		rate = 0.0  # no guard on night 0 (triage 7.1): a night-0 outing isn't the Warden's gift
	if profile == "ordinary" and not skip_claim_bump:
		for card in cards:
			if card.kind == "secret_claim" and not card.get("quoted", false) and card.subject == person.id and night >= card.applies.from and night <= card.applies.through \
					and (secret_errand or claim_walks(card)):
				rate = maxf(rate, lerpf(float(rates.ordinary), float(rates.secret), float(card.get("hearing_weight", 1.0))))
	if not History.alive_at_night(view, person.id, night):
		return [{"path": [], "weight": 1.0}]
	# A good Sexton walks every block on the night it says it tolled (Michael, Nov 21).
	if profile in ["gift", "secret", "ordinary"] and role_of(cards, person.id) == "sexton" and sexton_tolled(cards, person.id, night):
		return [{"path": C.BLOCKS.keys(), "weight": 1.0}]
	var destinations: Array = C.BLOCKS.keys()
	if profile == "gift":
		var role = role_of(cards, person.id)
		if role == "medium":
			# Demon victims' hearths only, not the hanged.
			var victims: Array = view.get("timeline", {}).get("events", []).filter(func(e): return e.kind == "demon_death").map(func(e): return e.subjects[0] if not e.subjects.is_empty() else "")
			destinations = view.people.filter(func(p): return p.id in victims and not History.alive_at_night(view, p.id, night)).map(func(p): return p.home)
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

static func demon_routes(home: String, destination: String) -> Array:
	var key: String = home + ":" + destination
	if demon_route_cache.has(key):
		return demon_route_cache[key]
	# The Demon walks the direct way to its victim. It never detours, so inference doesn't
	# allow one either (Michael, Nov 17).
	var result: Array = [{"path": C.route(home, destination), "weight": 1.0}]
	demon_route_cache[key] = result
	return result

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
					result.append("Seen elsewhere: %s's sighting on night %d argues strongly against being that night's killer." % [person.name, card.night])
	for id in blocks:
		var role: String = role_of(cards, id)
		if blocks[id].size() >= 2 and C.ROLES.get(role, {}).get("night_walk", false):
			var person: Dictionary = view.people.filter(func(p): return p.id == id)[0]
			result.append("Scattered sightings: %s's movements fit the claimed %s gift. This is corroboration, not proof of that identity." % [person.name, C.role_name(role)])
	return result

static func _crossing_probability_gd(view: Dictionary, cards: Array, person: Dictionary, night: int, alignment: String, scene_block: String) -> float:
	if not History.alive_at_night(view, person.id, night) or scene_block == "":
		return 0.0
	var role: String = role_of(cards, person.id)
	var gift: bool = C.ROLES.get(role, {}).get("night_walk", false)
	var profiles: Array = [{"kind": alignment, "weight": 1.0}] if alignment not in ["good", "converted"] else [
		{"kind": "ordinary", "weight": WALKER_CLAIM_HOME if gift else 0.75},
		{"kind": "gift", "weight": WALKER_CLAIM_GIFT if gift else 0.15}, {"kind": "secret", "weight": WALKER_CLAIM_SECRET if gift else 0.1}]
	if alignment in ["good", "converted"] and role != "" and not gift:
		profiles = [{"kind": "ordinary", "weight": 0.9}, {"kind": "secret", "weight": 0.1}]
	if alignment in ["good", "converted"] and role != "" and cards.any(func(c): return c.get("source", "") == person.id and c.has("hearing_weight")):
		var strength: float = role_hearing(cards, person.id, role)
		profiles = [{"kind": "ordinary", "weight": lerpf(0.75, WALKER_CLAIM_HOME if gift else 0.9, strength)}, {"kind": "gift", "weight": lerpf(0.15, WALKER_CLAIM_GIFT if gift else 0.0, strength)}, {"kind": "secret", "weight": lerpf(0.1, WALKER_CLAIM_SECRET if gift else 0.1, strength)}]
	if alignment in ["good", "converted"] and not secret_errand:
		profiles = _without_errand(profiles)
	var night_obs: Array = []
	var seen_inc: Array = []
	for c in relevant(cards):
		if c.get("night", -1) != night or c.kind == "trace" or (c.get("quoted", false) and c.kind != "alibi"):
			continue
		var inc: String = _alibi_incident(c) if c.kind == "alibi" else c.id
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
					w_p *= _observed(obs, person.id, evening, path_entry.path, current, view, night, cards, alignment)
				den_all += w_p
				if not path_entry.path.is_empty() and scene_block in path_entry.path:
					num_cross += w_p
	if den_all <= 1e-20:
		return 0.0
	return clampf(num_cross / den_all, 0.0, 1.0)

static func evaluate_trace_for_person(view: Dictionary, cards: Array, trace_card: Dictionary, person_id: String) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _evaluate_trace_for_person_impl(view, cards, trace_card, person_id)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: Dictionary = _evaluate_trace_for_person_impl(view, cards, trace_card, person_id)
	SolverBackend.end_stage(_st)
	return _res

static func _evaluate_trace_for_person_impl(view: Dictionary, cards: Array, trace_card: Dictionary, person_id: String) -> Dictionary:
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
		for hl in view.get("regular_haunts", {}).get(person_id, []):
			if hl not in haunts:
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

## Copies of one alibi count once. A person's own alibi and a witness's for them are
## separate incidents: the own one is lie-aware in evil worlds, the witness's stays hard,
## so keeping only whichever came first would change beliefs with card order (#124 review).
static func _alibi_incident(card: Dictionary) -> String:
	var subject: String = str(card.get("subject", ""))
	if card.get("known_self", false):
		return "alibi:" + subject + ":known"  # the listener's own knowledge, not a told alibi
	return "alibi:" + subject + (":self" if str(card.get("source", "")) == subject else "")

## The generic secret errand (every good person ~10% likely to be out on an errand of their
## own): retired with the flavour secrets (Michael, Nov 21; burdens prototype). Only a burden
## that walks (Unrequited) explains a good person's walk now, in the worlds that hold it, and
## only a claim of one raises its claimant's walk rate. Measurement switch: off in play; set it
## with set_secret_errand, which also sets the C# kernel, and clear the CaseEval caches after.
static var secret_errand: bool = false

static func set_secret_errand(on: bool) -> void:
	secret_errand = on
	SolverBackend._bridge().ActivitySetSecretErrand(on)

## Profiles without the errand: its weight stays home (ordinary).
static func _without_errand(profiles: Array) -> Array:
	var out: Array = []
	var spare: float = 0.0
	for prof in profiles:
		if prof.kind == "secret":
			spare += float(prof.weight)
		else:
			out.append(prof.duplicate())
	for prof in out:
		if prof.kind == "ordinary":
			prof.weight = float(prof.weight) + spare
			break
	return out

## Whether a burden claim explains its claimant's night walks (FlagClaimWalks in C#).
static func claim_walks(card: Dictionary) -> bool:
	return str(card.get("data", {}).get("secret_kind", "")) == "unrequited"

## A sighting places its teller (Michael, Nov 20; BACKLOG "A sighting places its teller"): in a
## world where its teller is honest, a street sighting puts them out on that block that night,
## and one from their window (their own block) puts them at home or out on their own block.
## Measurement switch: on in play; off, a sighting says nothing of where its teller was.
static var teller_place: bool = true

## Whether a sighting places its teller (FlagTellerAt in C#): one told firsthand by a person in
## the view (ids) about someone else, on a known block and night. Not a relay, a quotation, a
## person's own "I was out" (admitted), a guard or watch claim (already of the teller), a
## vigil's complete list, testimony alone, the listener's own home-night knowledge, or a card
## marked "places_teller": false (a word about the sighting alone).
static func teller_place_eligible(card: Dictionary, ids: Array) -> bool:
	if not teller_place or str(card.get("kind", "")) != "sighting" or not bool(card.get("places_teller", true)):
		return false
	if bool(card.get("quoted", false)) or card.has("relay_source") or bool(card.get("admitted", false)) or card.has("guard_claim") \
			or card.has("watch_claim") or bool(card.get("complete", false)) or bool(card.get("testimony_only", false)) or bool(card.get("known_self", false)):
		return false
	var src: String = str(card.get("source", ""))
	return src in ids and str(card.get("block", "")) in C.BLOCKS and int(card.get("night", -1)) >= 0 \
		and not src in card.get("subjects", [card.get("subject", "")])


## Whether a card was told while the Revenant's curse could have converted its teller (its
## statement time inside the curse window), as the sighter contests read it (Codex on #474).
static func teller_told_cursed(curse: Dictionary, card: Dictionary) -> bool:
	if curse.is_empty():
		return false
	var time: int = Chronology.tick(Chronology.statement_time(card))
	return time >= int(curse.get("from", 0)) and time < int(curse.get("until", 0))


## A person's home block from the view, or "" (C.vigil_sees_path then reads the path).
static func _home_of(view: Dictionary, person: String) -> String:
	for p in view.get("people", []):
		if str(p.get("id", "")) == person:
			return str(p.get("home", ""))
	return ""

static func _observed(card: Dictionary, person: String, evening: String, path: Array, alignment: String, view: Dictionary, night: int, all_cards: Array = [], base_alignment: String = "") -> float:
	if card.get("quoted", false) and card.kind != "alibi":
		return 1.0
	var out: bool = not path.is_empty()
	match card.kind:
		"sighting":
			if str(card.get("source", "")) == person and teller_place_eligible(card, view.get("people", []).map(func(p): return str(p.get("id", "")))):
				# A sighting places its teller (LiveActivity.teller_place; FlagTellerAt in C#).
				if alignment != "good" or (base_alignment == "converted" and teller_told_cursed(view.get("chronology", {}).get("curse", {}), card)):
					return 1.0
				var home: String = _home_of(view, person)
				var lamp: bool = path.size() > 2
				var fits: bool = (not out or path.back() == card.block or lamp) if card.block == home \
					else (out and (card.block in path if lamp else path.back() == card.block))
				return 1.0 if fits else 1.0 - float(card.get("hearing_weight", 1.0))
			if person in card.get("subjects", [card.get("subject", "")]):
				var matches_block: bool = card.block == "" or (C.vigil_sees_path(card.block, path, _home_of(view, person)) if card.get("complete", false) else card.block in path)
				var hw: float = float(card.get("hearing_weight", 1.0))
				if card.get("admitted", false) and alignment != "good":
					# An evil teller owns the outing but may lie about where (Codex on #372): a
					# place it truly went, or one picked among the blocks. No one admits a night
					# out they didn't take. Weighed, like any sighting, by how far the listener
					# credits hearing it.
					var told: float = 0.0
					if out:
						told = 1.0 if matches_block else 1.0 / float(C.BLOCKS.size())
					return hw * told + (1.0 - hw)
				return 1.0 if out and matches_block else 1.0 - hw
			if card.get("complete", false) and person not in card.get("excluded", []):
				return 1.0 if not C.vigil_sees_path(card.block, path, _home_of(view, person)) else VIGIL_MISS
		"evening":
			if person in card.get("subjects", [card.get("subject", "")]):
				return 1.0 if card.block == evening else 0.0
		"coverage":
			if person not in card.get("excluded", []):
				return 1.0 if not C.vigil_sees_path(card.block, path, _home_of(view, person)) else VIGIL_MISS
		"alibi":
			if card.get("known_self", false):
				if card.subject != person:
					return 1.0
				if card.has("route"):
					# "I know where I walked": out on exactly those blocks (FlagKnownRoute in C#).
					var walked: Dictionary = {}
					for b in path:
						walked[b] = true
					var known: Dictionary = {}
					for b in card.route:
						known[b] = true
					return 1.0 if out and walked.keys().all(func(b): return known.has(b)) and known.keys().all(func(b): return walked.has(b)) else float(card.get("self_doubt", 0.0))
				# "I know I was home": only its tiny self-doubt leaves room for being out.
				return 1.0 if not out else float(card.get("self_doubt", 0.0))
			if card.subject == person:
				# Someone else's word on a person's night (a witness) stays hard.
				if not card.get("quoted", false) and card.get("source", "") != person:
					return 1.0 if not out else 0.0
				# A person's own word on their night. The good mostly tell the truth, but one
				# out on a hidden gift or a secret (or a Sleepwalker) may still say "home"
				# (GOOD_OWN_ALIBI_OUT, Nov 17); an evil subject may be covering a night out,
				# priced like a relayed alibi.
				if not card.get("quoted", false) and alignment == "good":
					# out_rate: higher while an excuse for a caught lie stands (LiveAssessment._mark_excuses).
					return 1.0 if not out else float(card.get("out_rate", GOOD_OWN_ALIBI_OUT))
				return (0.7 if alignment != "good" else 0.3) if out else 0.9
		"report":
			if card.role == "warden" and card.source == person:
				return (1.0 if out and path.back() == card.block else 0.0) if alignment == "good" else 1.0
			if card.role == "medium" and card.source == person:
				return (1.0 if out and path.back() == card.data.get("block", card.get("block", "")) else 0.0) if alignment == "good" else 1.0
			if card.role == "lamplighter" and card.source == person and card.get("duty_only", false):
				return (1.0 if path.size() == C.BLOCKS.size() else 0.0) if alignment == "good" else 1.0
			if card.role == "monitor" and card.source != person and not card.get("duty_only", false) and not card.get("data", {}).get("walked", false):
				var mon_err: float = clampf(float(card.get("report_error", Tuning.Workshop.NIGHTWATCH_REPORT_ERROR)), 0.02, 0.45)
				return mon_err if (card.data.block in path) else (1.0 - mon_err)
			if card.role == "nightwatch":
				if card.source == person:
					return (1.0 if out and path.back() == card.data.block else 0.0) if alignment == "good" else 1.0
				if card.get("duty_only", false):
					return 1.0
				var nw_err: float = clampf(float(card.get("report_error", Tuning.Workshop.NIGHTWATCH_REPORT_ERROR)), 0.02, 0.45)
				return (1.0 - nw_err) if ((card.data.block in path) == (person in card.data.seen)) else nw_err
		"trace":
			if alignment == "demon":
				if card.get("data", {}).has("family"):
					return 1.0
				return (0.6 if card.data.material == evening else 0.0) + 0.4 / C.BLOCKS.size()
	return 1.0
