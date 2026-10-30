## The case simulation: setup, schedules, sightings, night resolution, meetings, executions.
## Deterministic from the seed. No presentation code lives here; player-facing text is
## produced by game.gd from the facts this class exposes.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const NPC = preload("res://sim/npc.gd")
const DevLog = preload("res://sim/devlog.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Social = preload("res://sim/social.gd")

var rng = RandomNumberGenerator.new()
var seed_value = 0
var dlog = DevLog.new()
var shadow_log = DevLog.new()   # legacy stream stays separate; detailed trace merges both
## Optional application adapter. Empty in simulation-only callers; no UI dependency.
var workshop_refresh: Callable
# Meeting testimony defers belief refreshes: a listener is refreshed just before they
# speak and once when testimony ends (Mind.flush_beliefs), not after every statement.
var defer_beliefs = false
var pending_beliefs: Array = []
var workshop_present: Callable
var workshop_roots: Callable # Read-only resolution of a relayed board case.
var detailed_logging = true     # debug export only; does not enable the spoiler UI
var trace_build = ""            # optional caller-supplied git/build identifier
var trace_tuning = ""           # optional caller-supplied tuning identifier

var npcs: Array = []
var by_id = {}
var day = 0
var phase = C.MORNING

var demon_id = ""
var first_demon_id = ""            # the demon at the start (a Scion may take over later)
var minion_id = ""                  # the first minion (kept for older code paths)
var minion_ids: Array = []
var bluffs: Array = []
var evil_plan = {}

## Dynamic locations (crime scenes). id -> {name, block, victim, day, trace_block, trace_true, why, searched}
var scenes = {}
var case_traces: Array = []         # canonical trace records rolled so far in this case
var deaths_last_night: Array = []
var executed_today = ""
var executions: Array = []          # {day, id, nominator, yes, player_yes, player_nominated}
var night_walkers: Array = []       # last night: {id, block, path, why}
var dropped = {}                    # location -> [{night, material (block), owner, who, why}] not yet found
var town_relationships: Array = [] # Rolled public bonds, captured before secret Lovers add a friendship.
var public_claims: Array = []       # {day, who, role}
var stances = {}                    # accuser id -> {target, day}: their latest public accusation
var totem = {}                      # the Revenant's hidden totem: {loc, day, owner} or {}
var totem_at_dawn = false           # a totem was in play when the day began (no new one today)
var curse = {}                      # the Revenant's curse: {victim, day} while someone is turned
var knell_night = -1                # night the Sexton tolled
var scion_rose = ""                 # the Scion who became the demon, if any
## Everything said or done in public (what evil, and anyone, can know without being told).
var public_log: Array = []          # {day, kind, subjects, by}

## Meeting state (BotC-style: one nomination at a time, "on the block").
var meeting = {}

## Player tools and night choices.
var tools = {"ward": 1, "clemency": 1}
var player_ward = ""
var ward_saves: Array = [] # Player-only aftermath, recorded only when their sigil stops an attack.
var sleepwalk_claims: Array = [] # who has said "I've been known to sleepwalk" (to anyone)
var player_vigil = ""
var player_vigil_seen: Array = []
var player_loc = ""

var game_over = false
var winner = ""
var end_reason = ""
var max_days = 6
var n_npcs = 7

# ---------------------------------------------------------------- helpers

func shuffled(arr: Array) -> Array:
	var a = arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a

func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]

func chance(p: float) -> bool:
	return rng.randf() < p

## The original single draw and comparison, with an observational decision record.
func decision_roll(n, topic: String, p: float, inputs: Dictionary = {}, target: String = "", comparison: String = "<") -> bool:
	var draw = rng.randf()
	var yes = draw <= p if comparison == "<=" else draw < p
	if dlog.live_feed != null and dlog.live_feed.enabled:
		dlog.decision(n.id if n != null else "world", topic, "roll", yes,
			{"mechanism": "probability", "inputs": inputs, "probability": p, "threshold": p, "draw": draw, "comparison": comparison}, target)
	return yes

func decision_pick(n, topic: String, options: Array, inputs: Dictionary = {}, target: String = ""):
	if options.is_empty(): return null
	var index = rng.randi_range(0, options.size() - 1)
	if dlog.live_feed != null and dlog.live_feed.enabled:
		var weights = {}
		var labels = {}
		for i in range(options.size()):
			weights[str(i)] = 1.0
			labels[str(i)] = str(options[i].name) if options[i] is Object else str(options[i])
		dlog.decision(n.id if n != null else "world", topic, "roll", labels[str(index)],
			{"mechanism": "uniform choice", "weights": weights, "choices": labels, "selected": str(index), "draw": index, "inputs": inputs}, target)
	return options[index]

func observe_decision(n, topic: String, result, details: Dictionary, target: String = "") -> void:
	if dlog.live_feed != null and dlog.live_feed.enabled:
		dlog.decision(n.id if n != null else "world", topic, "evaluation", result, details, target)

func observe_weighted(n, topic: String, candidates: Array, selected: String, draw: float, inputs: Dictionary, target: String, none_weight: float = 0.0) -> void:
	if dlog.live_feed == null or not dlog.live_feed.enabled: return
	var weights = {"nothing": none_weight}
	for c in candidates:
		var key: String = c[1].get("key", c[1].get("kind", "option"))
		weights[key] = weights.get(key, 0.0) + maxf(float(c[0]), 0.0)
	dlog.decision(n.id, topic, "roll", selected, {"mechanism": "weighted choice", "weights": weights,
		"selected": selected, "draw": draw, "comparison": "cumulative weights", "inputs": inputs}, target)

func observe_ranked(n, topic: String, candidates: Dictionary, selected: String, noise_max: float) -> void:
	if dlog.live_feed == null or not dlog.live_feed.enabled: return
	for id in candidates:
		var threshold = -INF
		for other in candidates:
			if other != id: threshold = maxf(threshold, float(candidates[other].score))
		var c: Dictionary = candidates[id]
		if candidates.size() == 1:
			observe_decision(n, topic, id == selected, {"gate": "only eligible candidate; no competing threshold", "score": c.score,
				"draw": c.get("raw_draw", c.noise), "noise": c.noise, "parts": c.get("parts", {})}, id)
			continue
		observe_decision(n, topic, id == selected, {"score": c.score, "threshold": threshold,
			"comparison": ">", "draw": c.get("raw_draw", c.noise), "noise": c.noise, "noise_min": 0.0, "noise_max": noise_max,
			"parts": c.get("parts", {}), "inputs": c.get("inputs", {}), "note": "Local chance against the other OBSERVED scores; not the full strategy likelihood"}, id)

func attach_decision_feed(feed) -> void:
	dlog.live_feed = feed
	shadow_log.live_feed = feed
	var weak_world = weakref(self)
	feed.resolve_actor = func(id, source):
		var world = weak_world.get_ref()
		if world == null: return {"name": id, "stats": {}}
		var n = world.by_id.get(id)
		if n == null: return {"name": "Town" if id == "world" else id, "stats": {}}
		if source == "shadow" and n.shadow != null: n = n.shadow
		var stats: Dictionary = n.traits.duplicate()
		stats.merge({"trust": n.trust, "pressure": n.pressure, "day": world.day, "paranoia": Mind.paranoia(world, n)})
		return {"name": n.name, "stats": stats}

func npc(id: String):
	return by_id.get(id)

func living() -> Array:
	return npcs.filter(func(n): return n.alive)

func living_good() -> Array:
	return npcs.filter(func(n): return n.alive and not n.is_evil())

func demon():
	return by_id[demon_id]

## The first minion (older code paths). Prefer minions() or a role lookup.
func minion():
	return by_id[minion_id]

func minions() -> Array:
	return minion_ids.map(func(i): return by_id[i])

## The living evil team (the demon, minions, anyone the Revenant turned).
func evil_team() -> Array:
	return npcs.filter(func(n): return n.alive and n.is_evil())

## The NPC holding a role who's alive, or null.
func living_with_role(r: String):
	var n = npc_with_role(r)
	return n if n != null and n.alive else null

## Gifts that read people see a Marked townsfolk as evil (or the demon) half the time.
func registers_evil(n) -> bool:
	if n.is_evil():
		return true
	return n.secret_mod == "marked" and chance(Tuning.Setup.MARKED_EVIL_CHANCE)

func registers_demon(n) -> bool:
	if n.id == demon_id:
		return true
	return n.secret_mod == "marked" and chance(Tuning.Setup.MARKED_DEMON_CHANCE)

func npc_with_role(r: String):
	for n in npcs:
		if n.role == r:
			return n
	return null

func role_in_play(r: String) -> bool:
	return npc_with_role(r) != null

func phase_name() -> String:
	return C.PHASES[phase]

func time_key(d: int = -1, p: int = -1) -> String:
	if d < 0:
		d = day
	if p < 0:
		p = phase
	return "%d:%d" % [d, p]

func loc_name(l: String) -> String:
	if scenes.has(l):
		return scenes[l]["name"]
	if l.begins_with("home_") and by_id.has(l.substr(5)):
		return "%s's home" % by_id[l.substr(5)].name
	return C.loc_name(l)

func loc_block(l: String) -> String:
	if scenes.has(l):
		return scenes[l]["block"]
	if l.begins_with("home:") or l.begins_with("night:"):
		return l.substr(l.find(":") + 1)
	if l.begins_with("home_") and by_id.has(l.substr(5)):
		return by_id[l.substr(5)].home_block
	return C.loc_block(l)

func all_locations() -> Array:
	var out: Array = C.LOCATIONS.keys()
	for s in scenes.keys():
		out.append(s)
	return out

func locations_on(block: String) -> Array:
	return all_locations().filter(func(l): return loc_block(l) == block)

func npcs_at(l: String) -> Array:
	return npcs.filter(func(n): return n.alive and n.loc == l)

## Nearest living neighbours on the lane ring (left, right), excluding self.
func living_neighbours(n) -> Array:
	var ring_sorted = npcs.duplicate()
	ring_sorted.sort_custom(func(a, b): return a.ring < b.ring)
	var idx = ring_sorted.find(n)
	var out: Array = []
	var size = ring_sorted.size()
	for dir in [-1, 1]:
		for step in range(1, size):
			var m = ring_sorted[(idx + dir * step + size) % size]
			if m == n:
				break
			if m.alive:
				if not out.has(m):
					out.append(m)
				break
	return out

func set_log_time() -> void:
	dlog.set_time(day, "Setup" if (day == 0 and phase != C.NIGHT) else phase_name())

func _names(ids: Array) -> String:
	var names: Array = ids.map(func(i): return by_id[i].name)
	if names.size() == 2:
		return "%s and %s" % names
	return ", ".join(PackedStringArray(names))

func public_event(kind: String, subjects: Array, by: String, data: Dictionary = {}) -> void:
	if subjects.is_empty():
		return
	var e = {"day": day, "kind": kind, "subjects": subjects.duplicate(), "by": by}
	if kind in ["curse", "curse_lifted"]:
		e["phase"] = phase # The announced boundary's public clock time.
	if not data.is_empty():
		e["data"] = data.duplicate(true)
	public_log.append(e)

## Total voters at a meeting: living NPCs plus the player.
func voter_count() -> int:
	return living().size() + 1

## Seats round the meeting circle, clockwise: the player first, then the living townsfolk in
## roster order. (The view draws the player at the bottom; clockwise on screen.)
func seats() -> Array:
	var out: Array = ["player"]
	for n in living():
		out.append(n.id)
	return out

## BotC voting order: the hand starts with the seat clockwise of the nominee, goes round,
## and the nominee votes last.
func vote_order(nominee: String) -> Array:
	var s: Array = seats()
	var i = s.find(nominee)
	if i < 0:
		return s
	var out: Array = []
	for k in range(1, s.size() + 1):
		out.append(s[(i + k) % s.size()])
	return out

## BotC threshold: at least half the voters, rounded up.
func vote_threshold() -> int:
	return int(ceil(voter_count() / 2.0))

# ---------------------------------------------------------------- setup

func setup(seed_in: int, npc_count: int = 7) -> void:
	seed_value = seed_in
	rng.seed = seed_in
	n_npcs = npc_count
	max_days = 6 if npc_count < 10 else 8
	day = 0
	phase = C.NIGHT
	dlog.configure_trace(detailed_logging)
	shadow_log.configure_trace(detailed_logging, dlog.trace_context(), "shadow")
	dlog.set_time(0, "Setup")
	dlog.begin_action("setup", {"seed": seed_in, "npcs": npc_count})
	dlog.trace_event("trace_header", "world", "", {"seed": seed_in, "npcs": npc_count,
		"engine": Engine.get_version_info(), "build": trace_build, "tuning": trace_tuning,
		"coverage": "milestone_2_state_and_structured_decisions"})
	dlog.add("case_start", "world", "", {"seed": seed_in, "npcs": npc_count})

	var cast = shuffled(C.CAST).slice(0, npc_count)
	var occs = shuffled(C.OCCUPATIONS.keys()).slice(0, npc_count)
	var blocks: Array = C.BLOCKS.keys()
	var ring_order = shuffled(range(npc_count))
	# Homes spread as evenly as the blocks allow (10: 3/3/2/2; 7: 2/2/2/1), in a random order.
	var homes: Array = []
	var bl: Array = shuffled(blocks)
	for i in range(npc_count):
		homes.append(bl[i % bl.size()])
	homes = shuffled(homes)
	for i in range(npc_count):
		var c: Dictionary = cast[i]
		var n = NPC.new()
		n.id = c["id"]
		n.name = c["name"]
		n.pron = c["pron"]
		n.style = c["style"]
		n.blurb = c["blurb"]
		for t in C.TRAITS:
			var bv: Array = c["traits"][t]
			n.trait_base[t] = bv[0]
			n.traits[t] = snappedf(clampf(bv[0] + rng.randf_range(-bv[1], bv[1]), 0.0, 1.0), 0.01)
		var occ: Dictionary = C.OCCUPATIONS[occs[i]]
		n.occupation = occ["title"]
		n.work = occ["work"]
		n.work_phases = occ["shifts"].duplicate()
		if chance(Tuning.Setup.EXTRA_WORK_SHIFT_CHANCE):
			var extra = pick([0, 1, 2].filter(func(p): return not (p in n.work_phases)))
			n.work_phases.append(extra)
			n.work_phases.sort()
		n.home_block = homes[i]
		# Habits: two favourite spots for idle hours (not their workplace).
		n.haunts = shuffled(["tavern", "well", "chapel", "bakery", "wharf", "smithy", "mill", "graveyard"].filter(func(x): return x != n.work)).slice(0, 2)
		n.ring = ring_order[i]
		npcs.append(n)
		by_id[n.id] = n

	_assign_roles()
	_assign_relationships()
	_assign_secret_mod()
	if C.USE_FLAVOR_SECRETS:
		_assign_secrets()

	for n in npcs:
		for m in npcs:
			if m == n:
				continue
			var s = Tuning.Setup.INITIAL_SUSPICION_BASE
			var t = Tuning.Setup.INITIAL_TRUST_BASE + rng.randf_range(-Tuning.Setup.INITIAL_TRUST_JITTER, Tuning.Setup.INITIAL_TRUST_JITTER)
			if m.id in n.rivals:
				s += Tuning.Setup.INITIAL_SUSPICION_RIVAL
				t += Tuning.Setup.INITIAL_TRUST_RIVAL
			if m.id in n.friends:
				s += Tuning.Setup.INITIAL_SUSPICION_FRIEND
				t += Tuning.Setup.INITIAL_TRUST_FRIEND
			n.suspicion[m.id] = s
			n.npc_trust[m.id] = snappedf(t, 0.01)
		n.trust = clampf(Tuning.Setup.PLAYER_TRUST_BASE + Tuning.Setup.PLAYER_TRUST_OPENNESS_SCALE * (1.0 - n.traits["privacy"]) + rng.randf_range(Tuning.Setup.PLAYER_TRUST_JITTER_MIN, Tuning.Setup.PLAYER_TRUST_JITTER_MAX), Tuning.Setup.PLAYER_TRUST_MIN, Tuning.Setup.PLAYER_TRUST_MAX)
		n.trust_at_reconsider = n.trust
		if n.secret_mod == "lovers" and n.lover != "":
			n.npc_trust[n.lover] = Tuning.Setup.INITIAL_TRUST_LOVER
			n.suspicion[n.lover] = 0.0

	# Each good NPC knows their own gift: a firsthand record that counts against anyone
	# who claims it falsely.
	for n in npcs:
		if not n.is_evil():
			Mind.hear_claim(self, n, n.id, n.role, Tuning.Setup.OWN_ROLE_CLAIM_WEIGHT, "own")
	evil_plan = Evil.make_plan(self)
	_log_grimoire()
	trace_capture("initial_setup", true)

	resolve_night()
	day = 1
	phase = C.MORNING
	start_phase()
	trace_capture("setup_complete", true)
	dlog.end_action()

## Roles from the script, no duplicates, with a little protection: at least two
## start-knowledge gifts and one strong identifier (Seer, Dowser or Gravedigger).
func _assign_roles() -> void:
	var cfg: Dictionary = C.SETUPS.get(n_npcs, {"town": n_npcs - 2, "minions": 1})
	var good: Array = []
	for attempt in range(200):
		good = shuffled(C.GOOD_ROLES).slice(0, cfg["town"])
		var starts = good.filter(func(r): return r in C.START_ROLES).size()
		var ident = good.filter(func(r): return r in C.IDENTIFIER_ROLES).size()
		if starts >= 2 and ident >= 1:
			break
	var mins: Array = shuffled(C.MINION_ROLES).slice(0, cfg["minions"])
	var order = shuffled(npcs)
	order[0].role = "demon"
	order[0].alignment = "evil"
	demon_id = order[0].id
	first_demon_id = demon_id
	minion_ids = []
	for i in range(mins.size()):
		order[1 + i].role = mins[i]
		order[1 + i].alignment = "evil"
		minion_ids.append(order[1 + i].id)
	minion_id = minion_ids[0]
	var k = 0
	for i in range(1 + mins.size(), order.size()):
		order[i].role = good[k]
		k += 1
	var evil_count = 1 + mins.size()
	bluffs = shuffled(C.GOOD_ROLES.filter(func(r): return not role_in_play(r))).slice(0, maxi(3, evil_count + 1))
	for n in npcs:
		var rdef = C.role_def(n.role)
		if rdef != null:
			rdef.setup_world(self, n)

## One secret modifier per case, on a townsfolk (the Lovers take two), on top of their gift.
func _assign_secret_mod() -> void:
	var goods = shuffled(npcs.filter(func(n): return not n.is_evil()))
	if goods.size() < 2:
		return
	var k: String = pick(C.SECRET_MOD_LIST)
	if k != "lovers":
		# The Rumormonger's gift can't name its own holder, so it never holds the secret
		# alone (Lovers always involve someone else). The shared model knows the rule.
		goods = goods.filter(func(n): return not C.role_def(n.role).cannot_hold_solo_secret)
		if goods.size() < 2:
			return
	if k in ["lovers", "sleepwalker"]:
		# These send their holder out at night: never on a role that is already out at
		# night, so nobody has two reasons to be out (Case 22485).
		goods = goods.filter(func(n): return not C.ROLES.get(n.role, {}).get("night_walk", false))
		if goods.size() < 2:
			return
	var a = goods[0]
	a.secret_mod = k
	if k == "lovers":
		var b = goods[1]
		b.secret_mod = "lovers"
		a.lover = b.id
		b.lover = a.id
		for pr in [[a, b], [b, a]]:
			if not (pr[1].id in pr[0].friends):
				pr[0].friends.append(pr[1].id)
			pr[0].rivals.erase(pr[1].id)
			pr[0].secret = {"kind": "lover", "with": pr[1].id, "dest": pr[1].home_block,
				"text": "slips out to meet %s in secret" % pr[1].name, "me": "slip out to meet %s in secret" % pr[1].name}
			pr[0].known_secrets[pr[1].id] = pr[1].id
	dlog.add("secret_mod", a.id, a.lover, {"mod": k}, "Secret: %s is %s%s." % [a.name, C.secret_name(k),
		(" with " + by_id[a.lover].name) if a.lover != "" else ""])

func _assign_relationships() -> void:
	for i in range(npcs.size()):
		for j in range(i + 1, npcs.size()):
			var a = npcs[i]
			var b = npcs[j]
			var r = rng.randf()
			if r < Tuning.Setup.FRIEND_PAIR_CUTOFF:
				a.friends.append(b.id)
				b.friends.append(a.id)
			elif r < Tuning.Setup.RIVAL_PAIR_CUTOFF:
				a.rivals.append(b.id)
				b.rivals.append(a.id)
	for n in npcs:
		if n.friends.is_empty():
			var cands = npcs.filter(func(m): return m != n and not (m.id in n.rivals))
			var f = pick(cands)
			if f:
				n.friends.append(f.id)
				f.friends.append(n.id)

	# Keep public setup bonds distinct from friendships added by secret modifiers.
	town_relationships = []
	for i in range(npcs.size()):
		for j in range(i + 1, npcs.size()):
			var a = npcs[i]
			var b = npcs[j]
			if b.id in a.friends:
				town_relationships.append({"kind": "friend", "people": [a.id, b.id]})
			elif b.id in a.rivals:
				town_relationships.append({"kind": "rival", "people": [a.id, b.id]})

## Personal reasons to be out at night (flavour, separate from the secret modifier).
func _assign_secrets() -> void:
	var goods = shuffled(npcs.filter(func(n): return not n.is_evil() and n.secret.is_empty() and n.secret_mod != "sleepwalker"))
	var busy_nights = npcs.any(func(n): return n.secret_mod in ["lovers", "sleepwalker"])
	var count = (1 if not busy_nights or chance(0.5) else 0) + (1 if n_npcs >= 10 and chance(0.5) else 0)
	for i in range(mini(count, goods.size())):
		var n = goods[i]
		var s: Dictionary = pick(C.SECRETS).duplicate()
		if s.get("needs_friend", false):
			var f = npc(pick(n.friends))
			s["with"] = f.id
			s["dest"] = f.home_block
			s["text"] = s["text"] % f.name
		n.secret = s
		if s.has("with"):
			npc(s["with"]).known_secrets[n.id] = n.id
		dlog.add("secret_assigned", n.id, s.get("with", ""), s, "%s %s (good NPC; will hide it)" % [n.name, s["text"]])

func _log_grimoire() -> void:
	var g = []
	for n in npcs:
		g.append({"id": n.id, "occupation": n.occupation, "work_phases": n.work_phases, "role": n.role,
			"align": n.alignment, "home": n.home_block, "ring": n.ring, "friends": n.friends, "rivals": n.rivals,
			"traits": n.traits, "trait_base": n.trait_base, "secret": n.secret.get("kind", ""),
			"red_herring": n.red_herring, "trust": snappedf(n.trust, 0.01), "secret_mod": n.secret_mod, "lover": n.lover})
	dlog.add("grimoire", "world", "", {"npcs": g, "bluffs": bluffs, "plan": evil_plan},
		"Hidden setup. Demon=%s, minions=%s, bluffs=%s" % [demon_id, ", ".join(PackedStringArray(minion_ids.map(func(i): return "%s (%s)" % [i, by_id[i].role]))), str(bluffs)])

# ---------------------------------------------------------------- day phases

## Start of each day phase: workers go to work, idlers wander, some idlers pair off
## into a visible conversation (keeping at least 3 people available to the player).
func start_phase() -> void:
	set_log_time()
	if phase == C.MORNING:
		totem_at_dawn = not totem.is_empty()
		for n in npcs:
			n.talked_today = []
	if phase == C.EVENING:
		# A silence lasts until the next evening.
		for n in living():
			if n.silenced and n.silence_day < day:
				n.silenced = false
				dlog.add("silence_ends", "world", n.id, {}, "%s can speak again." % n.name)
	for n in living():
		n.busy_with = ""
		n.working = phase in n.work_phases
		if n.working:
			n.loc = n.work
		else:
			n.loc = _choose_idle_location(n)
	_pre_pair()
	Social.tavern_whispers(self)
	for n in living():
		n.history[time_key()] = n.loc if n.loc != "home" else "home:" + n.home_block
	var placed = {}
	for n in living():
		placed[n.id] = {"loc": n.loc, "working": n.working, "busy_with": n.busy_with}
	dlog.add("positions", "world", "", placed)
	_day_sightings()
	_day_gifts()

func _choose_idle_location(n) -> String:
	var r = rng.randf()
	var social: Array = ["tavern", "well", "chapel", "bakery", "wharf", "smithy", "mill", "graveyard"]
	# Creatures of habit: idle hours often go to one of their two haunts (40%; at 60% the bot
	# player found fewer people and won ~8 points less at 7 townsfolk).
	if not n.haunts.is_empty() and chance(0.4):
		social = n.haunts
	match phase:
		C.MORNING:
			if r < 0.15:
				return "home"
			return pick(social)
		C.AFTERNOON:
			if r < 0.3:
				return "tavern"
			if r < 0.45 and not n.friends.is_empty():
				var f = npc(pick(n.friends))
				if f and f.alive:
					return f.work
			return pick(social)
		C.EVENING:
			if r < 0.4:
				return "tavern"
			if r < 0.65:
				return "home"
			if r < 0.75:
				return "chapel"
			return pick(social)
	return "home"

## Player options this phase: working NPCs plus available idlers.
func player_options() -> Array:
	return living().filter(func(n): return n.available())

## Weight for two NPCs choosing to talk: driven by mutual trust.
func pair_weight(a, b) -> float:
	var t: float = (a.npc_trust.get(b.id, 0.5) + b.npc_trust.get(a.id, 0.5)) / 2.0
	var nudge: float = maxf(
		C.role_def(a.role).conversation_nudge if not a.is_evil() else 0.0,
		C.role_def(b.role).conversation_nudge if not b.is_evil() else 0.0
	)
	if a.silenced or b.silenced:
		return 0.02
	return clampf((t - 0.3) * 2.0 + Social.news_bonus(self, a, b) + nudge, 0.02, 2.0)

func _idle_pairable() -> Array:
	return living().filter(func(n): return not n.working and n.available() and n.pair_day != day)

func _pre_pair() -> void:
	var max_pairs = 1 if n_npcs < 10 else n_npcs / 5
	var made = 0
	while made < max_pairs:
		var cands = _idle_pairable()
		if cands.size() < 2 or player_options().size() - 2 < 3:
			break
		if not decision_roll(null, "pre_phase_conversation", 0.65):
			break
		var pr = _choose_pair(cands)
		if pr.is_empty():
			break
		_make_pair(pr[0], pr[1], "pre")
		made += 1

func _choose_pair(cands: Array) -> Array:
	var best: Array = []
	var total = 0.0
	var options: Array = []
	for i in range(cands.size()):
		for j in range(i + 1, cands.size()):
			var wgt = pair_weight(cands[i], cands[j])
			options.append([cands[i], cands[j], wgt])
			total += wgt
	if options.is_empty():
		return best
	var r = rng.randf() * total
	var observed_draw = r
	for o in options:
		r -= o[2]
		if r <= 0:
			_observe_pair_choice(options, o, observed_draw)
			return [o[0], o[1]]
	var last = options[options.size() - 1]
	_observe_pair_choice(options, last, observed_draw)
	return [last[0], last[1]]

func _observe_pair_choice(options: Array, selected: Array, draw: float) -> void:
	if dlog.live_feed == null or not dlog.live_feed.enabled: return
	var weights = {}
	var inputs = {}
	for o in options:
		var key: String = o[0].name + " + " + o[1].name
		weights[key] = o[2]
		inputs[key] = {"trust_a_to_b": o[0].npc_trust.get(o[1].id, 0.5), "trust_b_to_a": o[1].npc_trust.get(o[0].id, 0.5)}
	observe_decision(selected[0], "conversation_partner", selected[1].name, {"weights": weights,
		"selected": selected[0].name + " + " + selected[1].name, "draw": draw, "comparison": "cumulative weights", "inputs": inputs}, selected[1].id)

func _make_pair(a, b, when: String) -> void:
	if when == "pre":
		b.loc = a.loc
	a.busy_with = b.id
	b.busy_with = a.id
	a.pair_day = day
	b.pair_day = day
	a.talked_today.append(b.id)
	b.talked_today.append(a.id)
	var evil_meet = a.is_evil() and b.is_evil()
	dlog.add("npc_conversation", a.id, b.id, {"when": when, "loc": a.loc, "visible": when == "pre", "evil_meeting": evil_meet},
		"%s and %s talk%s (content: stage 2)." % [a.name, b.name, " (evil meeting)" if evil_meet else ""])
	Social.converse(self, a, b, when)

## After the player's action: remaining idlers on the same location may pair off.
func _post_pair(talked_id: String) -> void:
	var cands = _idle_pairable().filter(func(n): return n.id != talked_id)
	var by_loc = {}
	for n in cands:
		if not by_loc.has(n.loc):
			by_loc[n.loc] = []
		by_loc[n.loc].append(n)
	for l in by_loc:
		var group: Array = by_loc[l]
		if group.size() < 2:
			continue
		var pr = _choose_pair(group)
		if pr.is_empty():
			continue
		var p = Tuning.Setup.POST_PHASE_PAIR_MULT * pair_weight(pr[0], pr[1])
		if decision_roll(pr[0], "post_phase_conversation", p, {"pair_weight": p / Tuning.Setup.POST_PHASE_PAIR_MULT}, pr[1].id):
			_make_pair(pr[0], pr[1], "post")

func _day_sightings() -> void:
	var live = living()
	for a in live:
		if a.at_home():
			continue
		for b in live:
			if a == b or b.at_home():
				continue
			var same_loc: bool = a.loc == b.loc
			var same_block: bool = loc_block(a.loc) == loc_block(b.loc)
			if same_loc or (same_block and chance(0.4)):
				a.beliefs.append({"kind": "saw", "who": b.id, "loc": b.loc if same_loc else "",
					"block": loc_block(b.loc), "day": day, "phase": phase,
					"with": b.busy_with if same_loc and b.busy_with != a.id else ""})

## Advance to the next day phase. Returns false at the end of Evening.
func end_day_phase(talked_id: String = "") -> bool:
	_post_pair(talked_id)
	snapshot("phase_end")
	if phase < C.EVENING:
		phase += 1
		start_phase()
		return true
	return false

# ---------------------------------------------------------------- town meeting

func begin_meeting() -> Array:
	open_meeting()
	return Mind.meeting_testimony(self)

## Everything before the testimony (begin_meeting without it), for a streamed meeting:
## then Mind.testimony_start / testimony_step.
func open_meeting() -> void:
	set_log_time()
	# Hold belief refreshes from here until each speaker's turn (or the end of the
	# testimony): one refresh per mind instead of one now and another a moment later.
	defer_beliefs = true
	executed_today = ""
	meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
	meeting["accusations"] = []
	meeting["silenced"] = []
	for n in living():
		n.busy_with = ""
		if n.silence_pending == day:
			n.silence_pending = -1
			n.silenced = true
			n.silence_day = day
			meeting["silenced"].append(n.id)
			public_event("silenced", [n.id], "")
			dlog.add("silenced", "world", n.id, {}, "%s cannot speak at the meeting (the Breathstealer's work)." % n.name)
			# Evil wanted them quiet: a point in their favour with everyone else.
			for real in living():
				var l = real.shadow if real.is_evil() else real
				if l != null and real != n:
					var e: Array = []
					Mind._eff(e, n.id, -0.12, "silenced by the demon's side: they must have been a threat to it")
					Mind.ledger_hear(self, l, "silenced:%s:%d" % [n.id, day], e, 1.0, [], {"kind": "silenced", "subject": n.id, "day": day})
	Mind.refresh_all_consensus(self)  # yesterday's accusations count for less today

func can_nominate(by: String, nominee: String) -> String:
	if not by_id.has(nominee) or not by_id[nominee].alive:
		return "They are not here."
	if nominee in meeting["nominated"]:
		return "%s has already been nominated today." % by_id[nominee].name
	if by in meeting["nominators"]:
		return "You have already nominated today." if by == "player" else "already nominated"
	return ""

## Opens a nomination. Returns the pending nomination dict.
func open_nomination(by: String, nominee: String, reason: String = "") -> Dictionary:
	meeting["nominated"].append(nominee)
	meeting["nominators"].append(by)
	var nm = {"by": by, "nominee": nominee, "statement": "", "reason": reason}
	meeting["pending"] = nm
	var target = by_id[nominee]
	public_event("nomination", [nominee], by)
	target.pressure += 0.4
	if by == "player":
		Mind.set_trust(self, target, target.trust - 0.15, "the Demonologist nominated me")
	else:
		target.npc_trust[by] = clampf(target.npc_trust.get(by, 0.5) - 0.25, 0.0, 1.0)
		dlog.add("npc_trust", nominee, by, {"to": target.npc_trust[by]}, "%s nominated me" % by)
	dlog.add("nomination", by, nominee, {"reason": reason, "on_block": meeting["block"], "block_count": meeting["block_count"]})
	return nm

## The player intervenes with Clemency: the nomination is cancelled.
func clemency() -> void:
	var nm: Dictionary = meeting["pending"]
	var spared = by_id[nm["nominee"]]
	tools["clemency"] -= 1
	evil_plan["spared"].append(spared.id)
	dlog.add("clemency", "player", spared.id, {"nominator": nm["by"]}, "The Demonologist spares %s from this nomination." % spared.name)
	for n in living():
		if n == spared:
			Mind.set_trust(self, n, n.trust + 0.15, "the Demonologist spared me")
			continue
		if n.is_evil():
			continue
		var s = Mind.susp(n, spared.id)
		if s < 0.35:
			Mind.set_trust(self, n, n.trust + 0.06, "the Demonologist spared %s, whom I trust" % spared.id)
		elif s > 0.6:
			Mind.set_trust(self, n, n.trust - 0.1, "the Demonologist spared %s, whom I suspect" % spared.id)
	if nm["by"] != "player":
		var nom = by_id[nm["by"]]
		Mind.set_trust(self, nom, nom.trust - 0.08, "the Demonologist overruled my nomination")
	meeting["pending"] = {}

## Count the votes on the pending nomination and update who is on the block.
func vote_pending(player_yes: bool) -> Dictionary:
	set_log_time()
	var nm: Dictionary = meeting["pending"]
	var nid: String = nm["nominee"]
	var yes: Array = []
	var no: Array = []
	var order: Array = vote_order(nid)
	for vid in order:
		if vid == "player":
			continue  # declared up front; counted as the hand passes your seat
		var v = by_id[vid]
		if Mind.vote(self, v, nid, nm["by"], player_yes, nm["statement"], yes.size()):
			yes.append(v.id)
			public_event("vote_yes", [nid], v.id)
		else:
			no.append(v.id)
	var count = yes.size() + (1 if player_yes else 0)
	var thr = vote_threshold()
	var outcome = "fails"
	if count >= thr:
		if count > meeting["block_count"]:
			meeting["block"] = nid
			meeting["block_count"] = count
			outcome = "on_block"
		elif count == meeting["block_count"]:
			meeting["block"] = ""
			outcome = "tie"
		else:
			outcome = "short_of_block"
	var res = {"nominee": nid, "by": nm["by"], "yes": yes, "no": no, "player_yes": player_yes, "count": count,
		"threshold": thr, "order": order, "outcome": outcome, "block": meeting["block"], "block_count": meeting["block_count"]}
	meeting["results"].append(res)
	meeting["pending"] = {}
	# An aggregate process receipt is not another hostile act by the nominator.
	# Individual vote_yes records above retain their existing social meaning.
	public_event("vote", [nid], "town", {"nominee": nid, "nominator": nm["by"], "yes": yes.duplicate(), "no": no.duplicate(),
		"player_yes": player_yes, "count": count, "threshold": thr, "outcome": outcome})
	dlog.add("vote_tally", "world", nid, res)
	if player_yes:
		var t = by_id[nid]
		if nm["by"] != "player":
			Mind.set_trust(self, t, t.trust - 0.08, "the Demonologist voted to hang me")
	return res

## Close the meeting: whoever is on the block is executed.
func end_meeting(last_words: Callable = Callable()) -> String:
	if meeting.get("closed", false): return ""
	meeting["closed"] = true
	set_log_time()
	var b: String = meeting["block"]
	if b == "":
		dlog.add("no_execution", "world", "", {}, "Nobody is on the block when the meeting closes.")
		return ""
	var res = {}
	for r in meeting["results"]:
		if r["nominee"] == b:
			res = r
	execute(b, res, last_words)
	return b

func execute(id: String, res: Dictionary, last_words: Callable = Callable()) -> void:
	var n = by_id[id]
	if not n.alive: return
	var alive_before = living().size()
	# The Martyr dies in the place of a good soul they chose.
	var mart = living_with_role("martyr")
	var mart_def = C.role_def("martyr")
	var substituted: bool = mart_def.can_substitute_execution(self, mart, id)
	# The substitution decision is final before the actual condemned person speaks.
	if last_words.is_valid():
		last_words.call(mart if substituted else n)
	if substituted:
		_martyr_dies(mart, n, res)
		return
	n.alive = false
	n.death_day = day
	n.death_cause = "executed"
	n.loc = "dead"
	_bereave(n)
	executed_today = id
	executions.append({"day": day, "id": id, "nominator": res.get("by", ""), "yes": res.get("yes", []),
		"player_yes": res.get("player_yes", false), "player_nominated": res.get("by", "") == "player"})
	dlog.add("execution", "world", id, {"role": n.role, "align": n.alignment},
		"%s (%s) executed by town vote." % [n.name, n.role])
	_grief(n, res)
	mart_def.on_chosen_executed(self, mart, n)
	C.role_def(n.role).on_executed(self, n, res, Mind)
	if id == demon_id:
		var sc = living_with_role("scion")
		if C.role_def("scion").can_promote_to_demon(sc, alive_before):
			_scion_rises(sc)
		else:
			_finish("good", "The demon's host was executed.")
	else:
		_check_parity()

## The Martyr falls dead as the noose tightens; the nominee lives. Everyone sees it: both
## are proven good.
func _martyr_dies(mart, saved, res: Dictionary) -> void:
	C.role_def("martyr").on_substitute_execution(self, mart, saved, res, Mind)

## The Revenant hangs with a totem hidden: a good soul who voted for it turns evil, and
## the town is warned (not told who).
func _revenant_curse(rv, res: Dictionary) -> void:
	C.role_def("revenant").on_executed(self, rv, res, Mind)

func turn_evil(v, why: String) -> void:
	v.alignment = "evil"
	Mind.shadow_reset(v)  # rebuilt from their good mind as it stands now
	v.turned = true
	v.turned_day = day
	evil_plan["bluffs"][v.id] = v.role  # they keep claiming their own gift
	for m in evil_team():
		if m != v:
			Evil.add_intel(self, m, "teammate", v.id, 0.0, "%s has joined us (%s)" % [v.name, why])
	dlog.add("turned", "world", v.id, {"why": why, "role": v.role}, "%s turns evil (%s). Keeps their gift and claims; now works for the demon." % [v.name, why])

## The totem is found: the curse breaks. The turned soul is good again and remembers
## nothing of who else was evil; what they said while turned they no longer stand by.
func free_turned() -> String:
	if curse.is_empty():
		return ""
	var v = by_id[curse["victim"]]
	curse = {}
	if not v.alive:
		return ""
	v.alignment = "good"
	Mind.shadow_adopt(self, v)  # their good self, kept while turned, is their mind again
	if v.workshop_state.get("active", false):
		# A turned mind may never have needed a cover. Retract its shared layer
		# BEFORE applying the native post-restoration suspicion cap below.
		Mind.recompute_beliefs(self, v, " (shared ownership before restoration cap)")
	Mind.shadow_reset(v)
	v.turned = false
	v.intel = {}
	for e in v.info_log:
		if e.get("fake", false):
			e["disowned"] = true
			e["shared"] = true  # never repeated
	for m in npcs:
		if m != v:
			Mind.adjust(self, v, m.id, minf(Mind.susp(v, m.id), 0.25) - v.suspicion.get(m.id, 0.1), "freed soul", "", false)
	Mind.hear_claim(self, v, v.id, v.role, 1.5, "own")
	public_event("curse_lifted", ["town"], "")
	dlog.add("freed", "world", v.id, {}, "%s is freed from the curse; remembers nothing of their time as evil." % v.name)
	return v.id

## The demon hangs with five or more alive: the Scion takes its place.
func _scion_rises(sc) -> void:
	C.role_def("scion").promote_to_demon(self, sc)

## Those who trusted the executed resent whoever pushed for it (shifting allegiances).
## A Lover's death leaves the other withdrawn for the rest of the case: Privacy to the top,
## Gossip to the bottom, harder to read. Visible in their profile, so it's a clue.
func _bereave(dead) -> void:
	if dead.secret_mod != "lovers" or dead.lover == "" or not by_id.has(dead.lover):
		return
	var survivor = by_id[dead.lover]
	if not survivor.alive or survivor.withdrawn_since != "":
		return
	survivor.traits["privacy"] = 1.0
	survivor.traits["gossip"] = 0.0
	survivor.traits["composure"] = minf(1.0, survivor.traits.get("composure", 0.5) + 0.3)
	survivor.withdrawn_since = dead.id
	dlog.add("bereaved", survivor.id, dead.id, {"traits": survivor.traits.duplicate()},
		"%s withdraws after %s's death (Lovers)." % [survivor.name, dead.name])

func _grief(ex, res: Dictionary) -> void:
	if ex.id == demon_id:
		return  # the town was right; nobody mourns the demon
	for f in living_good():
		var t: float = f.npc_trust.get(ex.id, 0.5)
		if t < 0.62:
			continue
		var strength = (t - 0.5) * 2.0
		var nom: String = res.get("by", "")
		if nom != "" and nom != "player" and nom != f.id:
			Mind.adjust(self, f, nom, 0.3 * strength, "grief: %s nominated %s, whom I trusted" % [nom, ex.id],
				"they pushed to hang %s" % ex.name, false)
			f.npc_trust[nom] = clampf(f.npc_trust.get(nom, 0.5) - 0.2 * strength, 0.0, 1.0)
		for v in res.get("yes", []):
			if v != f.id and v != nom:
				Mind.adjust(self, f, v, 0.12 * strength, "grief: voted to hang %s" % ex.id, "", false)
		if nom == "player":
			Mind.set_trust(self, f, f.trust - 0.3 * strength, "grief: the Demonologist nominated %s" % ex.id)
			Mind.cap_trust(self, f, 0.55, "grief: the Demonologist nominated %s" % ex.id)
		elif res.get("player_yes", false):
			Mind.set_trust(self, f, f.trust - 0.2 * strength, "grief: the Demonologist voted to hang %s" % ex.id)
		dlog.think(f.id, "grief", "Mourns %s (trust %.2f); resents those who pushed the execution." % [ex.id, t])

func _check_parity() -> void:
	if game_over:
		return
	if demon().alive and living().size() <= 2:
		_finish("evil", "Only two townsfolk remain and the demon still walks among them.")
	elif demon().alive and living_good().is_empty():
		_finish("evil", "No good soul remains.")

func _finish(wn: String, why: String) -> void:
	game_over = true
	winner = wn
	end_reason = why
	dlog.add("game_over", "world", "", {"winner": wn}, why)

# ---------------------------------------------------------------- night

func resolve_night() -> void:
	phase = C.NIGHT
	set_log_time()
	var first = day == 0
	for n in npcs:
		if n.poisoned:
			dlog.add("poison_wears_off", "world", n.id)
		n.poisoned = false
		n.pressed_today = 0
		n.busy_with = ""
		n.pressure = n.pressure * Tuning.Setup.NIGHT_PRESSURE_DECAY
	Mind.end_of_day_trust(self)

	# The Sexton's knell (evening, fewer than five alive, once): no gift that walks abroad works.
	var knell = _sexton_knell()

	var kill_t = ""
	if not first and demon().alive and not knell:
		kill_t = Evil.choose_kill_target(self)
	var poisoner = living_with_role("poisoner")
	var poison_t = ""
	if poisoner != null and not knell:
		poison_t = Evil.choose_poison_target(self, kill_t)
	var warden = living_with_role("warden")
	var warden_t = ""
	if warden and not warden.is_evil() and not knell:
		warden_t = Mind.warden_target(self, warden)
	var watch = living_with_role("nightwatch")
	var watch_block = ""
	if watch and not watch.is_evil() and not knell:
		watch_block = Mind.watch_block(self, watch)
	var medium = living_with_role("medium")
	var medium_t = ""
	if medium and not medium.is_evil() and not knell:
		medium_t = _medium_choice(medium)
	var lamp = living_with_role("lamplighter")
	if lamp != null and (lamp.is_evil() or knell):
		lamp = null
	var mart = living_with_role("martyr")
	if mart != null and not mart.is_evil() and mart.martyr_target == "" and not first:
		_martyr_choice(mart)

	_night_movement(poison_t, kill_t, watch, watch_block, warden, warden_t, medium, medium_t, lamp)

	if poison_t != "":
		by_id[poison_t].poisoned = true
		dlog.add("poison", poisoner.id, poison_t, {}, "%s's gift will fail until next night." % by_id[poison_t].name)

	var protected = {}
	if warden_t != "":
		if warden.gift_broken():
			dlog.add("protect_failed", warden.id, warden_t, {}, "Warden's gift is broken (%s); protection does nothing." % ("poisoned" if warden.poisoned else "delusional"))
		else:
			protected[warden_t] = "warden"
			dlog.add("protect", warden.id, warden_t)
	if player_ward != "":
		protected[player_ward] = "player"
		dlog.add("protect", "player", player_ward, {}, "Demonologist's ward.")

	deaths_last_night = []
	# The night's readings come before the kill (unlike BotC: our dead can't speak, so a
	# victim's last reading only reaches the town through a Medium).
	if C.INFO_BEFORE_KILL:
		for n in living_good():
			if C.ROLES[n.role]["kind"] == "info":
				_receive_info(n, watch_block, medium_t, lamp)
	var kill_outcome = ""
	if kill_t != "":
		var v = by_id[kill_t]
		var outcome = attack_outcome(v, protected)
		kill_outcome = outcome
		if outcome == "killed":
			_kill(v)
		else:
			if outcome == "protected_player":
				ward_saves.append({"target": kill_t, "night": day})
			dlog.add("kill_failed", demon_id, kill_t, {"why": outcome}, "The demon's attack on %s failed (%s)." % [v.name, outcome])
			if C.has_role_def(outcome):
				C.role_def(outcome).on_survive_attack(self, v)

	if day >= 1 and deaths_last_night.is_empty():
		_quiet_night()
	if not C.INFO_BEFORE_KILL:
		for n in living_good():
			if C.ROLES[n.role]["kind"] == "info":
				_receive_info(n, watch_block, medium_t, lamp)

	_night_sightings()
	if kill_t != "":
		Evil.note_kill_result(self, kill_t, kill_outcome)
	Evil.gather_night_intel(self)
	Evil.make_fake_info(self)
	Mind.update_from_own_info(self)
	player_ward = ""
	snapshot("night_end")
	_check_parity()

## What happens when the demon attacks someone: the Veteran survives their first attack;
## a guarded door holds.
func attack_outcome(v, protected: Dictionary) -> String:
	if C.role_def(v.role).survives_demon_attack(v):
		return v.role
	if protected.has(v.id):
		return "protected_" + protected[v.id]
	return "killed"

## Whether the Sexton tolls tonight, and whether it works (a broken gift tolls for nothing).
func _sexton_knell() -> bool:
	var sx = living_with_role("sexton")
	return C.role_def("sexton").try_knell(self, sx, Mind)

## The Veteran survives their one attack and learns the last block the attacker came through.
func _veteran_survives(v) -> void:
	C.role_def("veteran").on_survive_attack(self, v)

## The Martyr chooses once, only someone they trust well.
func _martyr_choice(mart) -> void:
	C.role_def("martyr").pick_targets(self, mart, Mind)

## Public hearth eligibility: Demon victims only; revisit the latest after all are visited.
func _medium_choice(m) -> String:
	return C.role_def("medium").pick_targets(self, m, Mind)

## Nobody died: a point in favour of whoever publicly claims to protect (Warden) or to be
## unkillable (Veteran). Evil can claim these too, so it's evidence, not proof.
func _quiet_night() -> void:
	dlog.add("quiet_night", "world", "", {"night": day}, "Nobody died on night %d." % day)
	for pc in public_claims:
		var qdef = C.role_def(pc["role"])
		if qdef == null or not qdef.can_cause_quiet_night or not by_id[pc["who"]].alive:
			continue
		var q_eff: float = qdef.quiet_night_effect
		for l in living_good():
			if l.id == pc["who"]:
				continue
			var e: Array = []
			Mind._eff(e, pc["who"], q_eff,
				"nobody died on night %d, and they claim the %s" % [day, C.role_name(pc["role"])])
			# Scaled live by how credible the claimant is to this listener.
			Mind.ledger_hear(self, l, "quiet:%d>%s" % [day, pc["who"]], e, 1.0, [pc["who"], -1, "report"], {"kind": "quiet_night", "night": day, "claimant": pc["who"], "role": pc["role"]})

func _night_movement(poison_t: String, kill_t: String, watch, watch_block: String, warden = null, warden_t: String = "",
		medium = null, medium_t: String = "", lamp = null) -> void:
	night_walkers = []
	for n in living():
		n.out_last_night = false
		n.night_block = n.home_block
		n.night_path = []
		n.loc = "home"
	if kill_t != "":
		_walk(demon(), by_id[kill_t].home_block, "hunting %s" % by_id[kill_t].name)
	if poison_t != "":
		var m = living_with_role("poisoner")
		if m != null:
			_walk(m, by_id[poison_t].home_block, "poisoning %s" % by_id[poison_t].name)
	if watch and watch_block != "":
		_walk(watch, watch_block, "keeping the night watch")
	if warden and warden_t != "":
		# The Warden stands guard at the door, so it can be seen (and hunted).
		_walk(warden, by_id[warden_t].home_block, "guarding %s" % by_id[warden_t].name)
		warden.warden_log[str(day)] = warden_t
	if medium and medium_t != "":
		_walk(medium, by_id[medium_t].home_block, "visiting the home of the dead %s" % by_id[medium_t].name)
	if lamp:
		# The lamp route runs through every block; they finish where they started.
		_walk(lamp, lamp.home_block, "walking the lamp route", C.BLOCKS.keys())
	# The Secret Lovers meet somewhere new each night; the Sleepwalker wanders unknowing.
	var met = {}
	for n in living():
		if n.secret_mod == "lovers" and n.lover != "" and not met.has(n.id) and by_id[n.lover].alive and not n.out_last_night and not by_id[n.lover].out_last_night:
			var spot: String = pick(C.BLOCKS.keys())
			for x in [n, by_id[n.lover]]:
				x.secret["dest"] = spot
				_walk(x, spot, "secret: meeting %s" % by_id[x.lover].name)
				met[x.id] = true
		elif n.secret_mod == "sleepwalker" and not n.out_last_night and chance(Tuning.Setup.SLEEPWALK_CHANCE):
			_walk(n, pick(C.BLOCKS.keys()), "sleepwalking (doesn't know it)")
	for n in living_good():
		if not n.secret.is_empty() and n.secret.get("kind", "") != "lover" and not n.out_last_night and chance(Tuning.Setup.FLAVOR_SECRET_WALK_CHANCE):
			_walk(n, n.secret["dest"], "secret: " + n.secret["kind"])
	for n in living():
		n.history[time_key(day, C.NIGHT)] = ("night:" if n.out_last_night else "home:") + n.night_block
	dlog.add("night_movement", "world", "", {"walkers": night_walkers})

func _walk(n, block: String, why: String, path: Array = []) -> void:
	n.out_last_night = true
	n.night_block = block
	n.night_path = C.route(n.home_block, block) if path.is_empty() else path.duplicate()
	n.loc = "night:" + block
	night_walkers.append({"id": n.id, "block": block, "path": n.night_path, "why": why})
	_maybe_drop(n, why)

## Something a night walker may leave behind somewhere along their route: usually a
## material from their own home block (mud, chalk, soot, straw); rarely something of theirs.
func _maybe_drop(n, why: String) -> void:
	var p = Tuning.Setup.DROP_CHANCE_DEMON if n.id == demon_id else Tuning.Setup.DROP_CHANCE_WALKER
	if not chance(p):
		return
	var blk: String = pick(n.night_path)
	var l: String = pick(C.LOCATIONS.keys().filter(func(x): return C.LOCATIONS[x]["block"] == blk))
	var owned = chance(Tuning.Setup.DROP_OWNED_CHANCE)
	var item = {"night": day, "material": n.home_block, "owner": n.id if owned else "", "who": n.id, "why": why}
	if not dropped.has(l):
		dropped[l] = []
	dropped[l].append(item)
	dlog.add("dropped", n.id, "", {"loc": l, "night": day, "owned": owned, "material": n.home_block},
		"%s dropped %s at %s while %s." % [n.name, ("a personal item" if owned else C.BLOCKS[n.home_block]["trace"]), C.loc_name(l), why])

func _night_sightings() -> void:
	player_vigil_seen = []
	for wk in night_walkers:
		var wn = by_id[wk["id"]]
		var path: Array = wk.get("path", [wk["block"]])
		for o in living():
			if o == wn or o.secret_mod == "sleepwalker":
				continue  # (a sleepwalker sees nothing; they're asleep)
			var saw = false
			var where = ""
			if o.out_last_night and o.night_block in path:
				saw = chance(0.5)
				where = o.night_block
			elif not o.out_last_night and o.home_block in path:
				saw = chance(0.15)
				where = o.home_block
			if saw:
				# From home you see the street from your window; out, you see them in passing.
				var how = "street" if o.out_last_night else "window"
				var detail = "leaving_home" if (how == "window" and where == wn.home_block) else "street"
				o.beliefs.append({"kind": "saw", "who": wn.id, "loc": "", "block": where, "day": day, "phase": C.NIGHT, "how": how, "detail": detail})
				dlog.add("night_sighting", o.id, wn.id, {"block": where}, "%s glimpsed %s on %s at night." % [o.name, wn.name, C.block_name(where)])
		if player_vigil != "" and C.vigil_sees_path(player_vigil, path) and wn.alive:
			player_vigil_seen.append(wn.id)
	# Neighbours at home sometimes notice each other going in for the night and not coming
	# out again: a (true, if weak) alibi for those who stayed in.
	for o in living():
		if o.out_last_night or o.secret_mod == "sleepwalker":
			continue
		for m in living():
			if m != o and m.home_block == o.home_block and not m.out_last_night and chance(0.2):
				o.beliefs.append({"kind": "stayed_in", "who": m.id, "loc": "", "block": m.home_block, "day": day, "phase": C.NIGHT, "how": "window"})
				dlog.add("night_alibi", o.id, m.id, {"block": m.home_block}, "%s saw %s go in for the night and not come out." % [o.name, m.name])
	if player_vigil != "":
		dlog.add("player_vigil", "player", "", {"block": player_vigil, "seen": player_vigil_seen})

func _has_public_bond(a_id: String, b_id: String) -> bool:
	for rel in town_relationships:
		if a_id in rel.get("people", []) and b_id in rel.get("people", []):
			return true
	return false

func _shared_daytime_loc(a, b, check_day: int) -> bool:
	for ph in [C.MORNING, C.AFTERNOON, C.EVENING]:
		var la: String = str(a.history.get(time_key(check_day, ph), ""))
		var lb: String = str(b.history.get(time_key(check_day, ph), ""))
		if la != "" and la == lb and not la.begins_with("home:"):
			return true
	return false

func actor_fits_trace_truth(actor, tr: Dictionary) -> bool:
	match tr.get("trace_family", ""):
		"locations":
			var locs: Array = tr.get("locs", [])
			if actor.work in locs:
				return true
			return actor.haunts.any(func(h): return h in locs)
		"quarter":
			var ev_loc: String = actor.history.get(time_key(int(tr.get("day", day)), C.EVENING), "home:" + actor.home_block)
			return actor.home_block == tr.get("home_block", "") or loc_block(ev_loc) == tr.get("evening_block", "")
		"connection":
			var v_id: String = tr.get("victim", "")
			var v = by_id.get(v_id)
			if v == null:
				return false
			return actor.home_block == v.home_block or _has_public_bond(actor.id, v_id) or _shared_daytime_loc(actor, v, int(tr.get("day", day)))
	return false

func _loc_subsets_of_size(all_locs: Array, k: int) -> Array:
	var out: Array = []
	var m: int = all_locs.size()
	if k == 2:
		for i in range(m):
			for j in range(i + 1, m):
				out.append([all_locs[i], all_locs[j]])
	elif k == 3:
		for i in range(m):
			for j in range(i + 1, m):
				for r in range(j + 1, m):
					out.append([all_locs[i], all_locs[j], all_locs[r]])
	return out

func _is_subset_or_superset(a: Array, b: Array) -> bool:
	return a.all(func(x): return x in b) or b.all(func(x): return x in a)

func _build_locations_trace(actor, v, slot: int, used_keys: Dictionary, prev_loc_sets: Array) -> Dictionary:
	var all_locs: Array = C.LOCATIONS.keys()
	all_locs.sort()
	var actor_spots: Array = [actor.work] + actor.haunts
	var want_scent: bool = not chance(Tuning.Setup.TRACE_TOKEN_PROB)
	var k: int = 3 if want_scent else 2
	var candidates: Array = []
	for comb in _loc_subsets_of_size(all_locs, k):
		if not comb.any(func(l): return l in actor_spots):
			continue
		var tkey: String = "locations:" + ":".join(PackedStringArray(comb))
		if used_keys.has(tkey):
			continue
		candidates.append(comb)
	if candidates.is_empty():
		var alt_k: int = 2 if k == 3 else 3
		for comb in _loc_subsets_of_size(all_locs, alt_k):
			if comb.any(func(l): return l in actor_spots):
				candidates.append(comb)
	var non_subset: Array = candidates.filter(func(comb): return prev_loc_sets.all(func(prev): return not _is_subset_or_superset(comb, prev)))
	var pool: Array = non_subset if not non_subset.is_empty() else candidates
	var low_overlap: Array = pool.filter(func(comb): return prev_loc_sets.all(func(prev): return comb.filter(func(x): return x in prev).size() <= 1))
	if not low_overlap.is_empty():
		pool = low_overlap
	# Prefer candidates whose cast match count lands near ~70% of the town (6..8 of 10, 4..6 of 7).
	var target_lo: int = maxi(3, int(floor(npcs.size() * 0.6)))
	var target_hi: int = maxi(target_lo + 1, int(ceil(npcs.size() * 0.85)))
	var in_band: Array = pool.filter(func(comb):
		var cnt: int = npcs.filter(func(p): return p.work in comb or p.haunts.any(func(h): return h in comb)).size()
		return cnt >= target_lo and cnt <= target_hi)
	var chosen: Array = pick(in_band if not in_band.is_empty() else pool)
	var is_scent: bool = chosen.size() == 3
	var label: String = C.trace_scent_label(chosen) if is_scent else C.trace_token_label(chosen)
	var places: String = C.loc_list_or(chosen)
	var scene_prose: String
	var card_text: String
	if is_scent:
		scene_prose = "Near the body, a distinct scent of %s clings to the threshold; you smell that on folk who frequent %s." % [label, places]
		card_text = "At %s's scene: scent of %s (%s)." % [v.name, label, places]
	else:
		scene_prose = "Near the body, caught by the threshold, lies %s; folk carry those around %s." % [label, places]
		card_text = "At %s's scene: %s (%s)." % [v.name, label, places]
	return {
		"trace_family": "locations",
		"trace_subtype": "scent" if is_scent else "token",
		"trace_key": "locations:" + ":".join(PackedStringArray(chosen)),
		"trace_slot": slot,
		"scene_trace_count": 1,
		"day": day,
		"victim": v.id,
		"locs": chosen.duplicate(),
		"item_label": label,
		"scene_prose": scene_prose,
		"card_text": card_text,
		"actor": actor.id,
	}

func _build_quarter_trace(actor, v, slot: int, used_keys: Dictionary) -> Dictionary:
	var ev_loc: String = actor.history.get(time_key(day, C.EVENING), "home:" + actor.home_block)
	var ev_block: String = loc_block(ev_loc)
	var pairs: Array = []
	if ev_block != actor.home_block:
		pairs.append([actor.home_block, ev_block])
	else:
		for other_b in C.BLOCKS.keys():
			if other_b != actor.home_block:
				pairs.append([actor.home_block, other_b])
				pairs.append([other_b, ev_block])
	var fresh: Array = pairs.filter(func(pr): return not used_keys.has("quarter:%s:%s:%d" % [pr[0], pr[1], day]))
	var chosen_pair: Array = pick(fresh if not fresh.is_empty() else pairs)
	var hb: String = chosen_pair[0]
	var eb: String = chosen_pair[1]
	var h_tok: String = C.QUARTER_TOKENS.get(hb, C.BLOCKS[hb]["trace"])
	var e_mat: String = C.BLOCKS[eb]["trace"]
	var item_lbl: String = "%s dusted with %s" % [h_tok, e_mat]
	return {
		"trace_family": "quarter",
		"trace_subtype": "home_or_evening",
		"trace_key": "quarter:%s:%s:%d" % [hb, eb, day],
		"trace_slot": slot,
		"scene_trace_count": 1,
		"day": day,
		"victim": v.id,
		"home_block": hb,
		"evening_block": eb,
		"item_label": item_lbl,
		"scene_prose": "Near the body lies %s, pointing to someone who lives on %s or spent day %d's evening on %s." % [item_lbl, C.block_name(hb), day, C.block_name(eb)],
		"card_text": "At %s's scene: %s (lives on %s or D%d evening on %s)." % [v.name, h_tok, C.block_name(hb), day, C.block_name(eb)],
		"actor": actor.id,
	}

func _build_connection_trace(actor, v, slot: int) -> Dictionary:
	return {
		"trace_family": "connection",
		"trace_subtype": "victim_tie",
		"trace_key": "connection:%s:%d" % [v.id, day],
		"trace_slot": slot,
		"scene_trace_count": 1,
		"day": day,
		"victim": v.id,
		"victim_block": v.home_block,
		"item_label": "two pewter cups and an unforced bolt",
		"scene_prose": "Near the body, two pewter cups sit by the hearth and the door-bolt was drawn from within, pointing to a %s neighbour, a bond with %s, or day-%d company." % [C.block_name(v.home_block), v.name, day],
		"card_text": "At %s's scene: unforced bolt & two cups (%s resident, bond, or D%d company)." % [v.name, C.block_name(v.home_block), day],
		"actor": actor.id,
	}

func build_actor_trace(actor, v, slot: int = 0) -> Dictionary:
	var used_keys = {}
	var seen_families = {}
	var prev_loc_sets: Array = []
	for prev in case_traces:
		used_keys[prev.get("trace_key", "")] = true
		seen_families[prev.get("trace_family", "")] = true
		if prev.get("trace_family", "") == "locations":
			prev_loc_sets.append(prev.get("locs", []))
	var family_options: Array = []
	var loc_w: float = Tuning.Setup.TRACE_LOCATIONS_BASE_WEIGHT * (Tuning.Setup.TRACE_FRESH_FAMILY_WEIGHT if not seen_families.has("locations") else 1.0)
	family_options.append({"family": "locations", "weight": loc_w})
	var q_w: float = Tuning.Setup.TRACE_QUARTER_BASE_WEIGHT * (Tuning.Setup.TRACE_FRESH_FAMILY_WEIGHT if not seen_families.has("quarter") else 1.0)
	family_options.append({"family": "quarter", "weight": q_w})
	var conn_key: String = "connection:%s:%d" % [v.id, day]
	if not used_keys.has(conn_key) and (actor.home_block == v.home_block or _has_public_bond(actor.id, v.id) or _shared_daytime_loc(actor, v, day)):
		var c_w: float = Tuning.Setup.TRACE_CONNECTION_BASE_WEIGHT * (Tuning.Setup.TRACE_FRESH_FAMILY_WEIGHT if not seen_families.has("connection") else 1.0)
		family_options.append({"family": "connection", "weight": c_w})
	var total_w = 0.0
	for opt in family_options:
		total_w += float(opt.weight)
	var roll: float = rng.randf() * total_w
	var chosen_family: String = family_options[-1].family
	var acc = 0.0
	for opt in family_options:
		acc += float(opt.weight)
		if roll <= acc:
			chosen_family = opt.family
			break
	match chosen_family:
		"quarter":
			return _build_quarter_trace(actor, v, slot, used_keys)
		"connection":
			return _build_connection_trace(actor, v, slot)
		_:
			return _build_locations_trace(actor, v, slot, used_keys, prev_loc_sets)

func _kill(v) -> void:
	v.alive = false
	v.death_day = day
	v.death_cause = "demon"
	v.loc = "dead"
	_bereave(v)
	deaths_last_night.append(v.id)
	var d = demon()
	var ev_loc: String = d.history.get(time_key(day, C.EVENING), "home:" + d.home_block)
	var true_block: String = loc_block(ev_loc)
	var passers: Array = night_walkers.filter(func(wk): return wk["id"] != demon_id and wk["id"] != v.id and v.home_block in wk.get("path", [wk["block"]]))
	var demon_trace: Dictionary = build_actor_trace(d, v, 0)
	case_traces.append(demon_trace.duplicate(true))
	var traces: Array = [demon_trace]
	var passer_actor_id: String = ""
	if not passers.is_empty() and chance(Tuning.Setup.EXTRA_TRACE_CHANCE):
		var wk: Dictionary = pick(passers)
		var passer = by_id[wk["id"]]
		passer_actor_id = passer.id
		var passer_trace: Dictionary = build_actor_trace(passer, v, 1)
		case_traces.append(passer_trace.duplicate(true))
		if chance(0.5):
			traces = [passer_trace, demon_trace]
		else:
			traces = [demon_trace, passer_trace]
	for idx in range(traces.size()):
		traces[idx]["trace_slot"] = idx
		traces[idx]["scene_trace_count"] = traces.size()
		if idx == 1:
			var ptxt: String = str(traces[idx].get("scene_prose", ""))
			if ptxt.begins_with("Near the body, "):
				traces[idx]["scene_prose"] = "A second detail catches your eye: " + ptxt.trim_prefix("Near the body, ")
			elif ptxt.begins_with("Near the body "):
				traces[idx]["scene_prose"] = "A second detail catches your eye: you also notice " + ptxt.trim_prefix("Near the body ")
	var why = "Scene trace (%s / %s) generated from %s." % [demon_trace.trace_family, demon_trace.trace_subtype, d.name]
	if passer_actor_id != "":
		why += " Extra trace added by passing night-walker %s." % by_id[passer_actor_id].name
	var sid = "scene_" + v.id
	scenes[sid] = {"name": "%s's cottage" % v.name, "block": v.home_block, "victim": v.id, "day": day,
		"trace_block": true_block, "trace_true": true, "traces": traces, "trace": demon_trace,
		"passer_ids": passers.map(func(wk): return wk["id"]), "passer_trace_actor": passer_actor_id,
		"why": why, "searched": false}
	dlog.add("kill", demon_id, v.id, {"role": v.role, "scene": sid, "trace_family": demon_trace.trace_family,
		"trace_subtype": demon_trace.trace_subtype, "trace_key": demon_trace.trace_key,
		"trace_count": traces.size(), "passer_trace_actor": passer_actor_id, "trace_true": true}, why)
	public_event("demon_death", [v.id], "town")
	for n in npcs:
		if not n.alive:
			continue
		var listener = n.shadow if n.is_evil() else n
		if listener == null:
			continue
		var effects: Array = []
		Mind._eff(effects, v.id, preload("res://workshop/public_evidence.gd").victim_effect(Mind.susp(listener, v.id)),
			"killed by the Demon: strong evidence of innocence, not a guarantee", "", false)
		Mind.ledger_hear(self, listener, "demon_death:" + v.id, effects, 1.0, [], {"kind": "demon_death", "victim": v.id})

# ---------------------------------------------------------------- abilities

## Record a gift result in an NPC's info log (and the dev log). quiet: not a reading to
## pass on (the knell is public anyway).
func _add_info(n, entry: Dictionary, quiet: bool = false) -> void:
	entry["day"] = day
	entry["role"] = n.role
	entry["shared"] = quiet
	if not entry.has("true"):
		entry["true"] = true
	if n.gift_broken() and entry.get("why", "") == "":
		entry["why"] = ("poisoned" if n.poisoned else "delusional")
	if not entry["true"]:
		entry["why"] = false_reading_reason(entry)
	if phase != C.NIGHT:
		entry["phase"] = phase
	n.info_log.append(entry)
	dlog.add("info", n.id, "", entry, "%s (%s) learns: %s%s" % [n.name, n.role, entry["text"],
		"" if entry["true"] else "  [FALSE: %s]" % false_reading_reason(entry)])

## Diagnostic provenance only: never infer a cause from today's role/health for an
## old reading. Keep explicit causes; identify a known fabricated relay or be honest
## that the producing path failed to record its cause.
static func false_reading_reason(entry: Dictionary) -> String:
	var recorded = str(entry.get("why", "")).strip_edges()
	if recorded != "" and recorded != "?": return recorded
	if entry.get("fake", false): return "evil fabrication"
	var rdef_fr = C.role_def(entry.get("role", ""))
	if rdef_fr != null and rdef_fr.shape == "ROLE_AT_SITE" and rdef_fr.site_mode == "hearth_relay":
		var item: Dictionary = entry.get("data", {}).get("item", {})
		var inner: Dictionary = item.get("entry", {})
		if inner.get("fake", false):
			return "evil fabrication relayed from the dead: " + false_reading_reason(inner)
		if item.get("lie", false): return "evil fabrication relayed from the dead"
	return "fallback: false reading; cause was not recorded"

## Arbitrary result for a broken gift: any value in range other than the true one.
func _other_than(true_v: int, lo: int, hi: int) -> int:
	var opts: Array = range(lo, hi + 1).filter(func(x): return x != true_v)
	return pick(opts) if not opts.is_empty() else true_v

## Fabricated/impaired Surveyor counts favor ordinary layouts, retaining tails.
func surveyor_result(exclude: int = -1) -> int:
	var options: Array = []
	for count in range(1, C.BLOCKS.size() + 1):
		if count == exclude:
			continue
		for _i in range(12 if count in [2, 3] else 1):
			options.append(count)
	return pick(options)

func _receive_info(n, watch_block: String, medium_t: String = "", lamp = null) -> void:
	var r: String = n.role
	var first = day == 0
	if C.ROLES[r].get("first_night", false) and not first:
		return
	if C.ROLES[r].get("day", false):
		return
	var broken: bool = n.gift_broken()
	var entry = {}
	var rdef = C.role_def(r)
	if rdef == null:
		return
	entry = rdef.generate_reading(self, n, {"watch_block": watch_block, "medium_t": medium_t, "lamp": lamp}, Mind)
	if entry.is_empty():
		return
	if broken:
		entry["why"] = "%s" % ("poisoned" if n.poisoned else "delusional")
	_add_info(n, entry)

static func _secret_phrase(k: String) -> String:
	match k:
		"delusional":
			return "Delusional, their gift a fancy"
		"marked":
			return "Marked, and may read as evil"
		"lovers":
			return "one of the Secret Lovers"
		"sleepwalker":
			return "a Sleepwalker"
	return k

## Whom someone trusts and suspects most. Evil keep their team close and point at their
## scapegoat (or whoever threatens them).
func _psych_read(subj) -> Dictionary:
	var others: Array = living().filter(func(m): return m != subj)
	var trusts = ""
	var suspects = ""
	if subj.is_evil():
		var mates: Array = others.filter(func(m): return m.is_evil())
		if not mates.is_empty() and chance(0.75):
			trusts = pick(mates).id
		var sg: String = evil_plan.get("scapegoat", "")
		if sg != "" and by_id[sg].alive and sg != subj.id:
			suspects = sg
	if trusts == "":
		var bt = -1.0
		for m in others:
			var t: float = subj.npc_trust.get(m.id, 0.5)
			if t > bt:
				bt = t
				trusts = m.id
	if suspects == "":
		var bsu = -1.0
		for m in others:
			if subj.is_evil() and m.is_evil():
				continue
			var su: float = Mind.susp(subj, m.id)
			if su > bsu and m.id != trusts:
				bsu = su
				suspects = m.id
	if trusts == "":
		trusts = pick(others).id
	if suspects == "":
		suspects = pick(others.filter(func(m): return m.id != trusts)).id if others.size() > 1 else trusts
	return {"trusts": trusts, "suspects": suspects}

## What the Medium hears from the dead: something they knew and never said in public.
## Priority: unshared readings, then night sightings they kept to themselves, then their
## strongest suspicion; else where they were their last night. The evil dead give what
## their cover story would have said.
func _medium_item(m, dead, broken: bool) -> Dictionary:
	return C.role_def("medium").medium_item(self, m, dead, broken, Mind)

func _medium_text(dead, it: Dictionary) -> String:
	return C.role_def("medium").medium_text(self, dead, it)

# ---------------------------------------------------------------- day gifts

## Gifts that work in the daytime: the Dowser reads a crowd; the Breathstealer silences;
## the Revenant hides a totem.
func _day_gifts() -> void:
	for role_id in ["dowser", "breathstealer", "revenant"]:
		var holder = living_with_role(role_id)
		if holder != null:
			C.role_def(role_id).run_day_gift(self, holder, Mind, Evil)

## The player searches a location: a hidden totem is found and destroyed. Returns the
## totem (with "freed": id of anyone released from the curse), or {}.
func find_totem(l: String) -> Dictionary:
	if totem.is_empty() or totem["loc"] != l:
		return {}
	var t = totem.duplicate()
	totem = {}
	dlog.add("totem_found", "player", t["owner"], t, "The Demonologist finds and burns the totem at %s." % C.loc_name(l))
	var freed = free_turned()
	t["freed"] = freed
	return t

func start_new_day() -> void:
	day += 1
	phase = C.MORNING
	if day > max_days and not game_over:
		dlog.set_time(day, "Morning")
		_finish("evil", "Time ran out: the demon survived %d days." % max_days)
		return
	dlog.set_time(day, "Morning")
	Social.paranoia_drift(self)
	if C.SHADOW_SELF:
		Evil.review_scapegoat(self)
	start_phase()

# ---------------------------------------------------------------- dev snapshots

func snapshot(tag: String) -> void:
	trace_capture(tag, true)
	var s = {}
	for n in npcs:
		if not n.alive:
			continue
		var sus = {}
		for k in n.suspicion.keys():
			if by_id[k].alive:
				sus[k] = snappedf(Mind.susp(n, k), 0.01)
		s[n.id] = {"loc": n.loc, "poisoned": n.poisoned, "trust": snappedf(n.trust, 0.01), "trust_cap": n.trust_cap,
			"pressure": snappedf(n.pressure, 0.01), "claim": n.claimed_role, "max_tier": n.max_tier, "suspicion": sus}
	var shadows = {}
	for n in npcs:
		if n.alive and n.shadow != null:
			shadows[n.id] = Mind.shadow_view(self, n)
	var d = {"tag": tag, "npcs": s}
	if not shadows.is_empty():
		d["shadow"] = shadows  # evil NPCs' "if I were good" view (debug only)
	dlog.add("snapshot", "world", "", d)

## Capture boundaries catch direct assignments, including death/conversion resets.
## Does not create/sync shadow minds or mutate any gameplay state.
func trace_capture(tag: String, checkpoint: bool = false) -> void:
	if not detailed_logging:
		return
	for n in npcs:
		dlog.capture_npc(n, tag, checkpoint)
		if n.shadow != null:
			shadow_log.set_time(dlog.day, dlog.phase)
			shadow_log.capture_npc(n.shadow, tag, checkpoint)
