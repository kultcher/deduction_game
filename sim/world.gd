## The case simulation: setup, schedules, sightings, night resolution, meetings, executions.
## Deterministic from the seed. No presentation code lives here; player-facing text is
## produced by game.gd from the facts this class exposes.
extends RefCounted

const C = preload("res://sim/content.gd")
const NPC = preload("res://sim/npc.gd")
const DevLog = preload("res://sim/devlog.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Social = preload("res://sim/social.gd")

var rng = RandomNumberGenerator.new()
var seed_value = 0
var dlog = DevLog.new()
var shadow_log = DevLog.new()   # the shadow selves' reasoning (kept out of the case log)

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
var deaths_last_night: Array = []
var executed_today = ""
var executions: Array = []          # {day, id, nominator, yes, player_yes, player_nominated}
var night_walkers: Array = []       # last night: {id, block, path, why}
var dropped = {}                    # location -> [{night, material (block), owner, who, why}] not yet found
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
	return n.secret_mod == "marked" and chance(0.5)

func registers_demon(n) -> bool:
	if n.id == demon_id:
		return true
	return n.secret_mod == "marked" and chance(0.5)

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

func public_event(kind: String, subjects: Array, by: String) -> void:
	if subjects.is_empty():
		return
	public_log.append({"day": day, "kind": kind, "subjects": subjects.duplicate(), "by": by})

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
	dlog.set_time(0, "Setup")
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
		if chance(0.3):
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
			var s = 0.1
			var t = 0.5 + rng.randf_range(-0.05, 0.05)
			if m.id in n.rivals:
				s += 0.15
				t -= 0.25
			if m.id in n.friends:
				s -= 0.1
				t += 0.25
			n.suspicion[m.id] = s
			n.npc_trust[m.id] = snappedf(t, 0.01)
		n.trust = clampf(0.3 + 0.25 * (1.0 - n.traits["privacy"]) + rng.randf_range(-0.05, 0.1), 0.1, 0.9)
		n.trust_at_reconsider = n.trust
		if n.secret_mod == "lovers" and n.lover != "":
			n.npc_trust[n.lover] = 0.9
			n.suspicion[n.lover] = 0.0

	# Each good NPC knows their own gift: a firsthand record that counts against anyone
	# who claims it falsely.
	for n in npcs:
		if not n.is_evil():
			Mind.hear_claim(self, n, n.id, n.role, 1.5, "own")
	evil_plan = Evil.make_plan(self)
	_log_grimoire()

	resolve_night()
	day = 1
	phase = C.MORNING
	start_phase()

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
	var seer = npc_with_role("seer")
	if seer:
		var cands = npcs.filter(func(m): return m != seer and not m.is_evil())
		seer.red_herring = pick(cands).id

## One secret modifier per case, on a townsfolk (the Lovers take two), on top of their gift.
func _assign_secret_mod() -> void:
	var goods = shuffled(npcs.filter(func(n): return not n.is_evil()))
	if goods.size() < 2:
		return
	var k: String = pick(C.SECRET_MOD_LIST)
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
			if r < 0.2:
				a.friends.append(b.id)
				b.friends.append(a.id)
			elif r < 0.32:
				a.rivals.append(b.id)
				b.rivals.append(a.id)
	for n in npcs:
		if n.friends.is_empty():
			var cands = npcs.filter(func(m): return m != n and not (m.id in n.rivals))
			var f = pick(cands)
			if f:
				n.friends.append(f.id)
				f.friends.append(n.id)

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
	var nudge = 0.0
	if (a.role == "psychologist" and not a.is_evil()) or (b.role == "psychologist" and not b.is_evil()):
		nudge = 0.5  # the Psychologist seeks people out: their gift needs a conversation
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
		if not chance(0.65):
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
	for o in options:
		r -= o[2]
		if r <= 0:
			return [o[0], o[1]]
	var last = options[options.size() - 1]
	return [last[0], last[1]]

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
		var p = 0.4 * pair_weight(pr[0], pr[1])
		if chance(p):
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
	set_log_time()
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
			for l in living_good():
				if l != n:
					var e: Array = []
					Mind._eff(e, n.id, -0.12, "silenced by the demon's side: they must have been a threat to it")
					Mind.ledger_hear(self, l, "silenced:%s:%d" % [n.id, day], e, 1.0, [], {"kind": "event"})
	Mind.refresh_all_consensus(self)  # yesterday's accusations count for less today
	return Mind.meeting_testimony(self)

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
	dlog.add("vote_tally", "world", nid, res)
	if player_yes:
		var t = by_id[nid]
		if nm["by"] != "player":
			Mind.set_trust(self, t, t.trust - 0.08, "the Demonologist voted to hang me")
	return res

## Close the meeting: whoever is on the block is executed.
func end_meeting() -> String:
	set_log_time()
	var b: String = meeting["block"]
	if b == "":
		dlog.add("no_execution", "world", "", {}, "Nobody is on the block when the meeting closes.")
		return ""
	var res = {}
	for r in meeting["results"]:
		if r["nominee"] == b:
			res = r
	execute(b, res)
	return b

func execute(id: String, res: Dictionary) -> void:
	var n = by_id[id]
	var alive_before = living().size()
	# The Martyr dies in the place of a good soul they chose.
	var mart = living_with_role("martyr")
	# The Martyr's gift reads the nominee like any other: a Marked soul may read as evil.
	var reads_evil = mart != null and mart.martyr_target == id and registers_evil(n)
	if mart != null and mart != n and mart.martyr_target == id and not reads_evil and not mart.gift_broken():
		_martyr_dies(mart, n, res)
		return
	n.alive = false
	n.death_day = day
	n.death_cause = "executed"
	n.loc = "dead"
	executed_today = id
	executions.append({"day": day, "id": id, "nominator": res.get("by", ""), "yes": res.get("yes", []),
		"player_yes": res.get("player_yes", false), "player_nominated": res.get("by", "") == "player"})
	dlog.add("execution", "world", id, {"role": n.role, "align": n.alignment},
		"%s (%s) executed by town vote." % [n.name, n.role])
	_grief(n, res)
	if mart != null and mart.martyr_target == id and reads_evil and not mart.gift_broken():
		# Hanged, and the Martyr still stands: their chosen was evil.
		var info = {"data": {"target": id, "evil": true}, "true": n.is_evil(),
			"text": "%s was hanged and I still stand: %s was evil" % [n.name, n.name]}
		if not n.is_evil():
			info["why"] = "Marked reads as evil"
		_add_info(mart, info)
	if n.role == "revenant":
		_revenant_curse(n, res)
	if id == demon_id:
		var sc = living_with_role("scion")
		if sc != null and alive_before >= 5 and not sc.gift_broken():
			_scion_rises(sc)
		else:
			_finish("good", "The demon's host was executed.")
	else:
		_check_parity()

## The Martyr falls dead as the noose tightens; the nominee lives. Everyone sees it: both
## are proven good.
func _martyr_dies(mart, saved, res: Dictionary) -> void:
	mart.alive = false
	mart.death_day = day
	mart.death_cause = "martyr"
	mart.loc = "dead"
	mart.gift_used = true
	executed_today = ""
	executions.append({"day": day, "id": mart.id, "saved": saved.id, "martyr": true, "nominator": res.get("by", ""),
		"yes": res.get("yes", []), "player_yes": res.get("player_yes", false), "player_nominated": res.get("by", "") == "player"})
	public_event("martyr", [mart.id, saved.id], mart.id)
	meeting["martyr"] = {"martyr": mart.id, "saved": saved.id}
	dlog.add("martyr", mart.id, saved.id, {}, "%s (Martyr) dies in %s's place at the gallows. Both proven good." % [mart.name, saved.name])
	for l in living_good():
		var e: Array = []
		for id in [mart.id, saved.id]:
			if id != l.id:
				l.cleared[id] = true
				Mind._eff(e, id, -2.0, "the Martyr died in %s's place: proven good" % saved.id)
		Mind.ledger_hear(self, l, "martyr:%d" % day, e, 1.0, [], {"kind": "proof"})
	_check_parity()

## The Revenant hangs with a totem hidden: a good soul who voted for it turns evil, and
## the town is warned (not told who).
func _revenant_curse(rv, res: Dictionary) -> void:
	if totem.is_empty():
		dlog.add("curse_fizzles", rv.id, "", {}, "The Revenant hangs with no totem in play: no curse.")
		return
	if rv.gift_broken():
		dlog.add("curse_fizzles", rv.id, "", {}, "The Revenant was poisoned: the curse fails.")
		return
	var cands: Array = res.get("yes", []).map(func(i): return by_id[i]).filter(func(m): return m.alive and not m.is_evil())
	if cands.is_empty():
		dlog.add("curse_fizzles", rv.id, "", {}, "No good soul voted to hang the Revenant: the curse finds nobody.")
		return
	var v = pick(cands)
	turn_evil(v, "the Revenant's curse")
	curse = {"victim": v.id, "day": day, "totem": totem.duplicate()}
	# Someone who voted to hang it has turned: each good yes-voter is a little suspect to the rest.
	var voters: Array = res.get("yes", []).filter(func(i): return by_id[i].alive)
	for l in living_good():
		var e: Array = []
		for i in voters:
			if i != l.id:
				Mind._eff(e, i, 0.15, "voted to hang the Revenant; the curse turned one of those voters")
		if not e.is_empty():
			Mind.ledger_hear(self, l, "curse:%d" % day, e, 1.0, [], {"kind": "event"})
	public_event("curse", [rv.id], rv.id)
	meeting["curse"] = true

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
	Mind.shadow_reset(v)
	v.turned = false
	v.intel = {}
	for e in v.info_log:
		if e.get("fake", false):
			e["disowned"] = true
			e["shared"] = true  # never repeated
	for m in npcs:
		if m != v:
			v.suspicion[m.id] = minf(v.suspicion.get(m.id, 0.1), 0.25)
	Mind.hear_claim(self, v, v.id, v.role, 1.5, "own")
	public_event("curse_lifted", ["town"], "")
	dlog.add("freed", "world", v.id, {}, "%s is freed from the curse; remembers nothing of their time as evil." % v.name)
	return v.id

## The demon hangs with five or more alive: the Scion takes its place.
func _scion_rises(sc) -> void:
	var old = demon_id
	sc.role = "demon"
	demon_id = sc.id
	scion_rose = sc.id
	minion_ids.erase(sc.id)
	if minion_id == sc.id and not minion_ids.is_empty():
		minion_id = minion_ids[0]
	dlog.add("scion", sc.id, old, {}, "The demon is hanged, but %s, the Scion, becomes the demon." % sc.name)
	_check_parity()

## Those who trusted the executed resent whoever pushed for it (shifting allegiances).
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
		n.pressure = n.pressure * 0.6
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
	var kill_outcome = ""
	if kill_t != "":
		var v = by_id[kill_t]
		var outcome = attack_outcome(v, protected)
		kill_outcome = outcome
		if outcome == "killed":
			_kill(v)
		else:
			dlog.add("kill_failed", demon_id, kill_t, {"why": outcome}, "The demon's attack on %s failed (%s)." % [v.name, outcome])
			if outcome == "veteran":
				_veteran_survives(v)

	if day >= 1 and deaths_last_night.is_empty():
		_quiet_night()
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
	if v.role == "veteran" and not v.is_evil() and not v.gift_broken() and not v.vet_used:
		return "veteran"
	if protected.has(v.id):
		return "protected_" + protected[v.id]
	return "killed"

## Whether the Sexton tolls tonight, and whether it works (a broken gift tolls for nothing).
func _sexton_knell() -> bool:
	var sx = living_with_role("sexton")
	if sx == null or sx.is_evil() or sx.gift_used or day < 1 or living().size() >= 5:
		return false
	var toll = Mind.decide(self, sx, "sexton_toll", {"few_left": 0.35, "deaths": 0.1 * npcs.filter(func(m): return not m.alive).size(),
		"base": 0.0}, "Toll the death knell tonight (fewer than five alive)?")
	if not toll:
		return false
	sx.gift_used = true
	knell_night = day
	public_event("knell", [sx.id], sx.id)
	if sx.gift_broken():
		dlog.add("knell", sx.id, "", {"works": false}, "%s tolls the death knell, but their gift is broken: nothing stops tonight." % sx.name)
		knell_night = -1
		return false
	dlog.add("knell", sx.id, "", {"works": true}, "%s tolls the death knell: no gift that walks abroad works tonight." % sx.name)
	_add_info(sx, {"data": {"night": day}, "true": true, "text": "I tolled the death knell on night %d" % day}, true)
	return true

## The Veteran survives their one attack and learns the last block the attacker came through.
func _veteran_survives(v) -> void:
	v.vet_used = true
	var path: Array = demon().night_path
	var from: String = path[path.size() - 2] if path.size() >= 2 else v.home_block
	_add_info(v, {"data": {"attacked": day, "block": from}, "true": true,
		"text": "the demon came for me on night %d and I lived; it came by way of %s" % [day, C.block_name(from)]})

## The Martyr chooses once, only someone they trust well.
func _martyr_choice(mart) -> void:
	var best = ""
	var best_t = 0.0
	for m in living():
		if m == mart:
			continue
		var t: float = mart.npc_trust.get(m.id, 0.5) - Mind.susp(mart, m.id) * 0.5 + mart.protect_pref.get(m.id, 0.0) * 0.5
		if t > best_t:
			best_t = t
			best = m.id
	if best == "" or best_t < 0.62:
		dlog.think(mart.id, "martyr_pick", "Martyr: nobody trusted enough yet (best %s at %.2f; needs 0.62)." % [best, best_t])
		return
	mart.martyr_target = best
	dlog.add("martyr_choice", mart.id, best, {"score": snappedf(best_t, 0.01)}, "%s (Martyr) secretly chooses %s." % [mart.name, by_id[best].name])
	_add_info(mart, {"data": {"target": best, "chosen": true}, "true": not mart.gift_broken(),
		"text": "I have given my life over for %s, should the town ever hang them" % by_id[best].name})

## The Medium visits the most recent dead they haven't visited (demon victims first).
func _medium_choice(m) -> String:
	var dead: Array = npcs.filter(func(x): return not x.alive and not (x.id in m.medium_visited))
	if dead.is_empty():
		return ""
	dead.sort_custom(func(a, b): return a.death_day > b.death_day or (a.death_day == b.death_day and a.death_cause == "demon"))
	m.medium_visited.append(dead[0].id)
	dlog.think(m.id, "medium_pick", "Medium visits %s's home." % dead[0].id)
	return dead[0].id

## Nobody died: a point in favour of whoever publicly claims to protect (Warden) or to be
## unkillable (Veteran). Evil can claim these too, so it's evidence, not proof.
func _quiet_night() -> void:
	dlog.add("quiet_night", "world", "", {"night": day}, "Nobody died on night %d." % day)
	for pc in public_claims:
		if not (pc["role"] in ["warden", "veteran"]) or not by_id[pc["who"]].alive:
			continue
		for l in living_good():
			if l.id == pc["who"]:
				continue
			var e: Array = []
			Mind._eff(e, pc["who"], -0.15 if pc["role"] == "warden" else -0.06,
				"nobody died on night %d, and they claim the %s" % [day, C.role_name(pc["role"])])
			# Scaled live by how credible the claimant is to this listener.
			Mind.ledger_hear(self, l, "quiet:%d>%s" % [day, pc["who"]], e, 1.0, [pc["who"], -1, "report"])

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
		_walk(lamp, lamp.home_block, "walking the lamp route")
		lamp.night_path = C.BLOCKS.keys()
		night_walkers.back()["path"] = lamp.night_path
	# The Secret Lovers meet somewhere new each night; the Sleepwalker wanders unknowing.
	var met = {}
	for n in living():
		if n.secret_mod == "lovers" and n.lover != "" and not met.has(n.id) and by_id[n.lover].alive and not n.out_last_night and not by_id[n.lover].out_last_night:
			var spot: String = pick(C.BLOCKS.keys())
			for x in [n, by_id[n.lover]]:
				x.secret["dest"] = spot
				_walk(x, spot, "secret: meeting %s" % by_id[x.lover].name)
				met[x.id] = true
		elif n.secret_mod == "sleepwalker" and not n.out_last_night and chance(0.5):
			_walk(n, pick(C.BLOCKS.keys()), "sleepwalking (doesn't know it)")
	for n in living_good():
		if not n.secret.is_empty() and n.secret.get("kind", "") != "lover" and not n.out_last_night and chance(0.55):
			_walk(n, n.secret["dest"], "secret: " + n.secret["kind"])
	for n in living():
		n.history[time_key(day, C.NIGHT)] = ("night:" if n.out_last_night else "home:") + n.night_block
	dlog.add("night_movement", "world", "", {"walkers": night_walkers})

func _walk(n, block: String, why: String) -> void:
	n.out_last_night = true
	n.night_block = block
	n.night_path = C.route(n.home_block, block)
	n.loc = "night:" + block
	night_walkers.append({"id": n.id, "block": block, "path": n.night_path, "why": why})
	_maybe_drop(n, why)

## Something a night walker may leave behind somewhere along their route: usually a
## material from their own home block (mud, chalk, soot, straw); rarely something of theirs.
func _maybe_drop(n, why: String) -> void:
	var p = 0.35 if n.id == demon_id else 0.15
	if not chance(p):
		return
	var blk: String = pick(n.night_path)
	var l: String = pick(C.LOCATIONS.keys().filter(func(x): return C.LOCATIONS[x]["block"] == blk))
	var owned = chance(0.12)
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
		if player_vigil != "" and player_vigil in path and wn.alive:
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

func _kill(v) -> void:
	v.alive = false
	v.death_day = day
	v.death_cause = "demon"
	v.loc = "dead"
	deaths_last_night.append(v.id)
	var d = demon()
	var ev_loc: String = d.history.get(time_key(day, C.EVENING), "home:" + d.home_block)
	var true_block: String = loc_block(ev_loc)
	var trace_block = true_block
	var trace_true = true
	var why = "Trace matches where the demon spent the evening (%s)." % true_block
	# A misleading trace has a cause: someone else passed the cottage that night and left
	# traces from where *they* spent the evening.
	var passers: Array = night_walkers.filter(func(wk): return wk["id"] != demon_id and wk["id"] != v.id and v.home_block in wk.get("path", [wk["block"]]))
	if not passers.is_empty() and chance(0.4):
		var wk: Dictionary = pick(passers)
		var o = by_id[wk["id"]]
		var o_block: String = loc_block(o.history.get(time_key(day, C.EVENING), "home:" + o.home_block))
		if o_block != true_block:
			trace_true = false
			trace_block = o_block
			why = "Misleading trace: %s passed the cottage that night (%s) and left traces from their evening on %s; the demon spent the evening on %s." % [o.name, wk["why"], o_block, true_block]
	var sid = "scene_" + v.id
	scenes[sid] = {"name": "%s's cottage" % v.name, "block": v.home_block, "victim": v.id, "day": day,
		"trace_block": trace_block, "trace_true": trace_true, "why": why, "searched": false}
	dlog.add("kill", demon_id, v.id, {"role": v.role, "scene": sid, "trace_block": trace_block, "trace_true": trace_true}, why)
	for n in npcs:
		if n.alive and not n.is_evil():
			n.suspicion[v.id] = 0.0
		elif n.alive and n.shadow != null:
			n.shadow.suspicion[v.id] = 0.0  # a good self knows the demon's victims were good

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
	if phase != C.NIGHT:
		entry["phase"] = phase
	n.info_log.append(entry)
	dlog.add("info", n.id, "", entry, "%s (%s) learns: %s%s" % [n.name, n.role, entry["text"],
		"" if entry["true"] else "  [FALSE: %s]" % entry.get("why", "?")])

## Arbitrary result for a broken gift: any value in range other than the true one.
func _other_than(true_v: int, lo: int, hi: int) -> int:
	var opts: Array = range(lo, hi + 1).filter(func(x): return x != true_v)
	return pick(opts) if not opts.is_empty() else true_v

func _receive_info(n, watch_block: String, medium_t: String = "", lamp = null) -> void:
	var r: String = n.role
	var first = day == 0
	if C.ROLES[r].get("first_night", false) and not first:
		return
	if C.ROLES[r].get("day", false):
		return
	var broken: bool = n.gift_broken()
	var entry = {}
	match r:
		"hearthwitch":
			var nb = living_neighbours(n)
			var ids: Array = nb.map(func(m): return m.id)
			var count = nb.filter(func(m): return registers_evil(m)).size()
			var reported = count
			if broken:
				reported = _other_than(count, 0, nb.size())
			entry = {"data": {"nbrs": ids, "count": reported}, "true": reported == count,
				"text": "I sensed that %d of my neighbours (%s) %s evil" % [reported, _names(ids), "is" if reported == 1 else "are"]}
		"seer":
			var pair: Array = Mind.seer_picks(self, n)
			var yes = false
			var true_yes = false
			for pid in pair:
				if pid == n.red_herring or registers_demon(by_id[pid]):
					yes = true
				if pid == demon_id:
					true_yes = true
			var reported_yes = yes
			if broken:
				reported_yes = chance(0.5)
			entry = {"data": {"pair": pair, "yes": reported_yes}, "true": reported_yes == true_yes,
				"text": "I looked at %s: %s" % [_names(pair), "one of them reads as the demon" if reported_yes else "neither is the demon"]}
			if yes and not true_yes and not broken:
				entry["why"] = "red herring %s" % n.red_herring if n.red_herring in pair else "a Marked soul read as the demon"
		"nightwatch":
			if watch_block == "":
				return  # didn't go out (the knell)
			var seen: Array = []
			for wk in night_walkers:
				if watch_block in wk.get("path", [wk["block"]]) and wk["id"] != n.id:
					seen.append(wk["id"])
			var real = seen.duplicate()
			if broken:
				seen = []
				var innocent = pick(living().filter(func(m): return m != n and not (m.id in real)))
				if innocent:
					seen.append(innocent.id)
			entry = {"data": {"block": watch_block, "seen": seen}, "true": seen == real,
				"text": "I watched %s: %s" % [C.block_name(watch_block),
					("I saw " + _names(seen) + " pass by") if not seen.is_empty() else "nobody stirred"]}
		"archivist":
			var mid: String = pick(minion_ids)
			var mrole: String = by_id[mid].role
			var other = pick(npcs.filter(func(m): return m != n and m.id != mid))
			var pair = shuffled([mid, other.id])
			var ok = true
			if broken:
				var goods = npcs.filter(func(m): return m != n and not m.is_evil())
				pair = shuffled(goods).slice(0, 2).map(func(m): return m.id)
				mrole = pick(C.MINION_ROLES)
				ok = false
			entry = {"data": {"pair": pair, "role": mrole}, "true": ok,
				"text": "I learned that one of %s is the %s" % [_names(pair), C.role_name(mrole)]}
		"clerk":
			var targets = npcs.filter(func(m): return m != n and not m.is_evil())
			var t = pick(targets)
			var other = pick(npcs.filter(func(m): return m != n and m != t))
			var role: String = t.role
			var ok = true
			if broken:
				role = pick(C.GOOD_ROLES.filter(func(x): return x != t.role and x != other.role and x != "clerk"))
				ok = false
			var pair = shuffled([t.id, other.id])
			entry = {"data": {"pair": pair, "role": role}, "true": ok,
				"text": "I learned that one of %s is the %s" % [_names(pair), C.role_name(role)]}
		"rumormonger":
			var holders: Array = npcs.filter(func(m): return m != n and m.secret_mod != "")
			var ok = true
			var pair: Array = []
			var sk = ""
			if holders.is_empty() or broken:
				var plain = npcs.filter(func(m): return m != n and m.secret_mod == "")
				pair = shuffled(plain).slice(0, 2).map(func(m): return m.id)
				sk = pick(C.SECRET_MOD_LIST)
				ok = false
			else:
				var h = pick(holders)
				sk = h.secret_mod
				var other = pick(npcs.filter(func(m): return m != n and m != h))
				pair = shuffled([h.id, other.id])
			entry = {"data": {"pair": pair, "secret": sk}, "true": ok,
				"text": "I heard that one of %s is %s" % [_names(pair), _secret_phrase(sk)]}
		"surveyor":
			var blocks = {}
			for m in npcs:
				if registers_evil(m):
					blocks[m.home_block] = true
			var count = blocks.size()
			var truth = 0
			var tb = {}
			for m in npcs:
				if m.is_evil():
					tb[m.home_block] = true
			truth = tb.size()
			if broken:
				count = _other_than(truth, 1, C.BLOCKS.size())
			entry = {"data": {"count": count}, "true": count == truth,
				"text": "I learned that %d of the four blocks %s an evil resident" % [count, "has" if count == 1 else "have"]}
		"lamplighter":
			if lamp != n:
				return
			var count = night_walkers.filter(func(wk): return wk["id"] != n.id).size()
			var truth = count
			if broken:
				count = _other_than(truth, 0, maxi(3, living().size() - 1))
			entry = {"data": {"count": count}, "true": count == truth,
				"text": "walking the lamps, I counted %d other%s out" % [count, "" if count == 1 else "s"]}
		"medium":
			if medium_t == "":
				return
			var item = _medium_item(n, by_id[medium_t], broken)
			entry = {"data": {"dead": medium_t, "item": item}, "true": not broken and not item.get("lie", false),
				"text": _medium_text(by_id[medium_t], item)}
		"psychologist":
			var talked: Array = n.talked_today.filter(func(i): return by_id[i].alive and i != n.id)
			if talked.is_empty():
				return
			var subj = by_id[pick(talked)]
			var res = _psych_read(subj)
			var ok = true
			if broken:
				var others: Array = living().filter(func(m): return m != subj).map(func(m): return m.id)
				res = {"trusts": pick(others), "suspects": pick(others)}
				ok = false
			entry = {"data": {"subject": subj.id, "trusts": res["trusts"], "suspects": res["suspects"]}, "true": ok,
				"text": "I read %s: they trust %s most, and suspect %s most" % [subj.name, by_id[res["trusts"]].name, by_id[res["suspects"]].name]}
		"gravedigger":
			if executed_today == "":
				return
			var ex = by_id[executed_today]
			var role: String = ex.role
			if ex.secret_mod == "marked" and chance(0.3):
				role = pick(C.EVIL_ROLES)
				entry["why"] = "Marked reads as evil"
			if broken:
				role = pick(C.ROLES.keys().filter(func(x): return x != ex.role and x != "demon" and x != "hearthwitch"))
			entry["data"] = {"executed": ex.id, "role": role}
			entry["true"] = role == ex.role
			entry["text"] = "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(role)]
		_:
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
	if broken:
		var who = pick(living().filter(func(x): return x != m))
		return {"type": "sighting", "who": who.id, "block": who.home_block, "night": maxi(0, dead.death_day - 1), "lie": true}
	for e in dead.info_log:
		if not e.get("shared", false) and not e.get("disowned", false) and C.ROLES.get(e.get("role", ""), {}).get("kind", "") == "info":
			e["shared"] = true
			return {"type": "reading", "entry": e.duplicate(true), "lie": e.get("fake", false)}
	for b in dead.beliefs:
		if b["kind"] == "saw" and b["phase"] == C.NIGHT and by_id.has(b["who"]) and not dead.told_to.has("medium|" + b["who"]):
			if dead.is_evil() and by_id[b["who"]].is_evil():
				continue
			dead.told_to["medium|" + b["who"]] = true
			return {"type": "sighting", "who": b["who"], "block": b["block"], "night": b["day"]}
	if dead.is_evil():
		var sg: String = evil_plan.get("scapegoat", "")
		if sg != "" and by_id[sg].alive and not dead.told_to.has("medium|cover"):
			dead.told_to["medium|cover"] = true
			return {"type": "suspicion", "about": sg, "lie": true}
	else:
		var best = ""
		var bs = 0.35
		for k in dead.suspicion:
			if by_id[k].alive and dead.suspicion[k] > bs:
				bs = dead.suspicion[k]
				best = k
		if best != "" and not dead.told_to.has("medium|susp:" + best):
			dead.told_to["medium|susp:" + best] = true
			return {"type": "suspicion", "about": best}
	var nd = maxi(0, dead.death_day - (1 if dead.death_cause == "demon" else 0))
	return {"type": "home", "night": nd, "block": dead.home_block, "lie": dead.is_evil()}

func _medium_text(dead, it: Dictionary) -> String:
	match it["type"]:
		"reading":
			return "communing with the dead at %s's hearth, I heard what they never told us: %s" % [dead.name, C.third_person(it["entry"]["text"])]
		"sighting":
			return "communing with the dead at %s's hearth, I learned they saw %s out on %s on night %d" % [dead.name, by_id[it["who"]].name, C.block_name(it["block"]), it["night"]]
		"suspicion":
			return "communing with the dead at %s's hearth, I felt their distrust of %s" % [dead.name, by_id[it["about"]].name]
	return "communing with the dead at %s's hearth, I learned only that they were home on their last night" % dead.name

# ---------------------------------------------------------------- day gifts

## Gifts that work in the daytime: the Dowser reads a crowd; the Breathstealer silences;
## the Revenant hides a totem.
func _day_gifts() -> void:
	var dw = living_with_role("dowser")
	if dw != null and not dw.is_evil() and dw.dowsed_day != day:
		var b: String = dw.home_block if dw.at_home() else loc_block(dw.loc)
		var others: Array = living().filter(func(m): return m != dw and (m.home_block if m.at_home() else loc_block(m.loc)) == b)
		if others.size() >= 2:
			dw.dowsed_day = day
			var ids: Array = others.map(func(m): return m.id)
			var count = others.filter(func(m): return registers_evil(m)).size()
			var truth = others.filter(func(m): return m.is_evil()).size()
			var dwhy = ""
			if dw.gift_broken():
				count = _other_than(truth, 0, others.size())
			elif count != truth:
				dwhy = "a Marked soul read as evil"
			_add_info(dw, {"data": {"group": ids, "count": count, "block": b}, "true": count == truth, "why": dwhy,
				"text": "on %s I sensed %d evil among %s" % [C.block_name(b), count, _names(ids)]})
			Mind.update_from_own_info(self)
	var bs = living_with_role("breathstealer")
	if bs != null and bs.is_evil() and bs.breath_day != day:
		var tgt = Evil.breath_target(self, bs)
		if tgt != "":
			bs.breath_day = day
			bs.breath_last = tgt
			if bs.gift_broken():
				dlog.add("breath_failed", bs.id, tgt, {}, "%s tries to steal %s's breath, but is poisoned." % [bs.name, by_id[tgt].name])
			else:
				by_id[tgt].silence_pending = day
				dlog.add("breath", bs.id, tgt, {"loc": bs.loc}, "%s steals %s's breath: silent from this evening's meeting." % [bs.name, by_id[tgt].name])
	var rv = living_with_role("revenant")
	if rv != null and rv.is_evil() and totem.is_empty() and not totem_at_dawn and C.LOCATIONS.has(rv.loc):
		if Evil.place_totem_now(self, rv):
			totem = {"loc": rv.loc, "day": day, "owner": rv.id, "material": rv.home_block}
			dlog.add("totem", rv.id, "", totem, "%s hides a totem at %s." % [rv.name, C.loc_name(rv.loc)])

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
	start_phase()

# ---------------------------------------------------------------- dev snapshots

func snapshot(tag: String) -> void:
	var s = {}
	for n in npcs:
		if not n.alive:
			continue
		var sus = {}
		for k in n.suspicion.keys():
			if by_id[k].alive:
				sus[k] = snappedf(n.suspicion[k], 0.01)
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
