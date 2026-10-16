## The case simulation: setup, schedules, sightings, night resolution, meetings, executions.
## Deterministic from the seed. No presentation code lives here; player-facing text is
## produced by game.gd from the facts this class exposes.
extends RefCounted

const C = preload("res://sim/content.gd")
const NPC = preload("res://sim/npc.gd")
const DevLog = preload("res://sim/devlog.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")

var rng = RandomNumberGenerator.new()
var seed_value = 0
var dlog = DevLog.new()

var npcs: Array = []
var by_id = {}
var day = 0
var phase = C.MORNING

var demon_id = ""
var minion_id = ""
var bluffs: Array = []
var evil_plan = {}

## Dynamic locations (crime scenes). id -> {name, block, victim, day, trace_block, trace_true, why, searched}
var scenes = {}
var deaths_last_night: Array = []
var executed_today = ""
var executions: Array = []          # {day, id, nominator, yes, player_yes, player_nominated}
var night_walkers: Array = []       # last night: {id, block, why}
var public_claims: Array = []       # {day, who, role}

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

func minion():
	return by_id[minion_id]

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
	return C.loc_name(l)

func loc_block(l: String) -> String:
	if scenes.has(l):
		return scenes[l]["block"]
	if l.begins_with("home:") or l.begins_with("night:"):
		return l.substr(l.find(":") + 1)
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

## Total voters at a meeting: living NPCs plus the player.
func voter_count() -> int:
	return living().size() + 1

## BotC threshold: at least half the voters, rounded up.
func vote_threshold() -> int:
	return int(ceil(voter_count() / 2.0))

# ---------------------------------------------------------------- setup

func setup(seed_in: int, npc_count: int = 7) -> void:
	seed_value = seed_in
	rng.seed = seed_in
	n_npcs = npc_count
	day = 0
	phase = C.NIGHT
	dlog.set_time(0, "Setup")
	dlog.add("case_start", "world", "", {"seed": seed_in, "npcs": npc_count})

	var cast = shuffled(C.CAST).slice(0, npc_count)
	var occs = shuffled(C.OCCUPATIONS.keys()).slice(0, npc_count)
	var blocks: Array = C.BLOCKS.keys()
	var ring_order = shuffled(range(npc_count))
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
		n.home_block = pick(blocks)
		n.ring = ring_order[i]
		npcs.append(n)
		by_id[n.id] = n

	_assign_roles()
	_assign_relationships()
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

	evil_plan = Evil.make_plan(self)
	_log_grimoire()

	resolve_night()
	day = 1
	phase = C.MORNING
	start_phase()

func _assign_roles() -> void:
	var good: Array = []
	for attempt in range(50):
		good = shuffled(C.GOOD_ROLES).slice(0, n_npcs - 2)
		var info = good.filter(func(r): return r in C.INFO_ROLES).size()
		if info >= 3:
			break
	var order = shuffled(npcs)
	order[0].role = "demon"
	order[0].alignment = "evil"
	demon_id = order[0].id
	order[1].role = "poisoner"
	order[1].alignment = "evil"
	minion_id = order[1].id
	for i in range(2, order.size()):
		order[i].role = good[i - 2]
	bluffs = shuffled(C.GOOD_ROLES.filter(func(r): return not role_in_play(r))).slice(0, 3)
	var seer = npc_with_role("seer")
	if seer:
		var cands = npcs.filter(func(m): return m != seer and not m.is_evil())
		seer.red_herring = pick(cands).id

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

func _assign_secrets() -> void:
	var goods = shuffled(npcs.filter(func(n): return not n.is_evil()))
	var count = 1 + (1 if chance(0.5) else 0)
	for i in range(count):
		var n = goods[i]
		var s: Dictionary = pick(C.SECRETS).duplicate()
		if s.get("needs_friend", false):
			var f = npc(pick(n.friends))
			s["with"] = f.id
			s["dest"] = f.home_block
			s["text"] = s["text"] % f.name
		n.secret = s
		dlog.add("secret_assigned", n.id, s.get("with", ""), s, "%s %s (good NPC; will hide it)" % [n.name, s["text"]])

func _log_grimoire() -> void:
	var g = []
	for n in npcs:
		g.append({"id": n.id, "occupation": n.occupation, "work_phases": n.work_phases, "role": n.role,
			"align": n.alignment, "home": n.home_block, "ring": n.ring, "friends": n.friends, "rivals": n.rivals,
			"traits": n.traits, "trait_base": n.trait_base, "secret": n.secret.get("kind", ""),
			"red_herring": n.red_herring, "trust": snappedf(n.trust, 0.01)})
	dlog.add("grimoire", "world", "", {"npcs": g, "bluffs": bluffs, "plan": evil_plan},
		"Hidden setup. Demon=%s, Poisoner=%s, bluffs=%s" % [demon_id, minion_id, str(bluffs)])

# ---------------------------------------------------------------- day phases

## Start of each day phase: workers go to work, idlers wander, some idlers pair off
## into a visible conversation (keeping at least 3 people available to the player).
func start_phase() -> void:
	set_log_time()
	for n in living():
		n.busy_with = ""
		n.working = phase in n.work_phases
		if n.working:
			n.loc = n.work
		else:
			n.loc = _choose_idle_location(n)
	_pre_pair()
	for n in living():
		n.history[time_key()] = n.loc if n.loc != "home" else "home:" + n.home_block
	var placed = {}
	for n in living():
		placed[n.id] = {"loc": n.loc, "working": n.working, "busy_with": n.busy_with}
	dlog.add("positions", "world", "", placed)
	_day_sightings()

func _choose_idle_location(n) -> String:
	var r = rng.randf()
	var social: Array = ["tavern", "well", "chapel", "bakery", "wharf", "smithy", "mill", "graveyard"]
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
	return clampf((t - 0.3) * 2.0, 0.02, 1.5)

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
	var evil_meet = a.is_evil() and b.is_evil()
	dlog.add("npc_conversation", a.id, b.id, {"when": when, "loc": a.loc, "visible": when == "pre", "evil_meeting": evil_meet},
		"%s and %s talk%s (content: stage 2)." % [a.name, b.name, " (evil meeting)" if evil_meet else ""])
	for p in [[a, b], [b, a]]:
		p[0].npc_trust[p[1].id] = clampf(p[0].npc_trust.get(p[1].id, 0.5) + 0.02, 0.0, 1.0)

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
		var p = 0.5 * pair_weight(pr[0], pr[1])
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
					"block": loc_block(b.loc), "day": day, "phase": phase})

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
	for n in living():
		n.busy_with = ""
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
	for v in living():
		if Mind.vote(self, v, nid, nm["by"], player_yes, nm["statement"], yes.size()):
			yes.append(v.id)
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
		"threshold": thr, "outcome": outcome, "block": meeting["block"], "block_count": meeting["block_count"]}
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
	if id == demon_id:
		_finish("good", "The demon's host was executed.")
	else:
		_check_parity()

## Those who trusted the executed resent whoever pushed for it (shifting allegiances).
func _grief(ex, res: Dictionary) -> void:
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

	var kill_t = ""
	if not first and demon().alive:
		kill_t = Evil.choose_kill_target(self)
	var poison_t = ""
	if minion().alive:
		poison_t = Evil.choose_poison_target(self, kill_t)
	var warden = npc_with_role("warden")
	var warden_t = ""
	if warden and warden.alive:
		warden_t = Mind.warden_target(self, warden)
	var watch = npc_with_role("nightwatch")
	var watch_block = ""
	if watch and watch.alive:
		watch_block = Mind.watch_block(self, watch)

	_night_movement(poison_t, kill_t, watch, watch_block)

	if poison_t != "":
		by_id[poison_t].poisoned = true
		dlog.add("poison", minion_id, poison_t, {}, "%s's gift will fail until next night." % by_id[poison_t].name)

	var protected = {}
	if warden_t != "":
		if warden.poisoned:
			dlog.add("protect_failed", warden.id, warden_t, {}, "Warden is poisoned; protection does nothing.")
		else:
			protected[warden_t] = "warden"
			dlog.add("protect", warden.id, warden_t)
	if player_ward != "":
		protected[player_ward] = "player"
		dlog.add("protect", "player", player_ward, {}, "Demonologist's ward.")

	deaths_last_night = []
	if kill_t != "":
		var v = by_id[kill_t]
		var outcome = "killed"
		if v.role == "veteran" and not v.poisoned:
			outcome = "veteran"
		elif protected.has(kill_t):
			outcome = "protected_" + protected[kill_t]
		Evil.note_kill_result(self, kill_t, outcome)
		if outcome == "killed":
			_kill(v)
		else:
			dlog.add("kill_failed", demon_id, kill_t, {"why": outcome}, "The demon's attack on %s failed (%s)." % [v.name, outcome])

	for n in living_good():
		if C.ROLES[n.role]["kind"] == "info":
			_receive_info(n, watch_block)

	_night_sightings()
	Evil.make_fake_info(self)
	Mind.update_from_own_info(self)
	player_ward = ""
	snapshot("night_end")
	_check_parity()

func _night_movement(poison_t: String, kill_t: String, watch, watch_block: String) -> void:
	night_walkers = []
	for n in living():
		n.out_last_night = false
		n.night_block = n.home_block
		n.loc = "home"
	if kill_t != "":
		_walk(demon(), by_id[kill_t].home_block, "hunting %s" % by_id[kill_t].name)
	if poison_t != "":
		var m = minion()
		if m.alive:
			_walk(m, by_id[poison_t].home_block, "poisoning %s" % by_id[poison_t].name)
	if watch and watch.alive and watch_block != "":
		_walk(watch, watch_block, "keeping the night watch")
	for n in living_good():
		if not n.secret.is_empty() and n != watch and chance(0.55):
			_walk(n, n.secret["dest"], "secret: " + n.secret["kind"])
	for n in living():
		n.history[time_key(day, C.NIGHT)] = ("night:" if n.out_last_night else "home:") + n.night_block
	dlog.add("night_movement", "world", "", {"walkers": night_walkers})

func _walk(n, block: String, why: String) -> void:
	n.out_last_night = true
	n.night_block = block
	n.loc = "night:" + block
	night_walkers.append({"id": n.id, "block": block, "why": why})

func _night_sightings() -> void:
	player_vigil_seen = []
	for wk in night_walkers:
		var wn = by_id[wk["id"]]
		for o in living():
			if o == wn:
				continue
			var saw = false
			if o.out_last_night and o.night_block == wk["block"]:
				saw = chance(0.5)
			elif not o.out_last_night and o.home_block == wk["block"]:
				saw = chance(0.15)
			if saw:
				o.beliefs.append({"kind": "saw", "who": wn.id, "loc": "", "block": wk["block"], "day": day, "phase": C.NIGHT})
				dlog.add("night_sighting", o.id, wn.id, {"block": wk["block"]}, "%s glimpsed %s on %s at night." % [o.name, wn.name, C.block_name(wk["block"])])
		if player_vigil != "" and wk["block"] == player_vigil and wn.alive:
			player_vigil_seen.append(wn.id)
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
	if chance(0.25):
		trace_true = false
		var others: Array = C.BLOCKS.keys().filter(func(b): return b != true_block)
		trace_block = pick(others)
		why = "Misleading trace (25%% roll): points to %s, demon was on %s." % [trace_block, true_block]
	var sid = "scene_" + v.id
	scenes[sid] = {"name": "%s's cottage" % v.name, "block": v.home_block, "victim": v.id, "day": day,
		"trace_block": trace_block, "trace_true": trace_true, "why": why, "searched": false}
	dlog.add("kill", demon_id, v.id, {"role": v.role, "scene": sid, "trace_block": trace_block, "trace_true": trace_true}, why)
	for n in npcs:
		if n.alive and not n.is_evil():
			n.suspicion[v.id] = 0.0

# ---------------------------------------------------------------- abilities

func _receive_info(n, watch_block: String) -> void:
	var r: String = n.role
	var first = day == 0
	if C.ROLES[r].get("first_night", false) and not first:
		return
	var entry = {}
	match r:
		"hearthwitch":
			var nb = living_neighbours(n)
			var ids: Array = nb.map(func(m): return m.id)
			var count = nb.filter(func(m): return m.is_evil()).size()
			var reported = count
			if n.poisoned:
				var opts: Array = range(nb.size() + 1).filter(func(x): return x != count)
				reported = pick(opts)
			entry = {"data": {"nbrs": ids, "count": reported}, "true": reported == count,
				"text": "I sensed that %d of my neighbours (%s) %s evil" % [reported, _names(ids), "is" if reported == 1 else "are"]}
		"seer":
			var pair: Array = Mind.seer_picks(self, n)
			var yes = false
			var true_yes = false
			for pid in pair:
				if pid == demon_id or pid == n.red_herring:
					yes = true
				if pid == demon_id:
					true_yes = true
			var reported_yes = yes
			if n.poisoned:
				reported_yes = not yes
			entry = {"data": {"pair": pair, "yes": reported_yes}, "true": reported_yes == true_yes,
				"text": "I looked at %s: %s" % [_names(pair), "one of them reads as the demon" if reported_yes else "neither is the demon"]}
			if yes and not true_yes and not n.poisoned:
				entry["why"] = "red herring %s" % n.red_herring
		"nightwatch":
			var seen: Array = []
			for wk in night_walkers:
				if wk["block"] == watch_block and wk["id"] != n.id:
					seen.append(wk["id"])
			var real = seen.duplicate()
			if n.poisoned:
				seen = []
				var innocent = pick(living().filter(func(m): return m != n and not (m.id in real)))
				if innocent:
					seen.append(innocent.id)
			entry = {"data": {"block": watch_block, "seen": seen}, "true": seen == real,
				"text": "I watched %s: %s" % [C.block_name(watch_block),
					("I saw " + _names(seen) + " pass by") if not seen.is_empty() else "nobody stirred"]}
		"archivist":
			var other = pick(npcs.filter(func(m): return m != n and m.id != minion_id))
			var pair = shuffled([minion_id, other.id])
			var ok = true
			if n.poisoned:
				var goods = npcs.filter(func(m): return m != n and not m.is_evil())
				pair = shuffled(goods).slice(0, 2).map(func(m): return m.id)
				ok = false
			entry = {"data": {"pair": pair, "role": "poisoner"}, "true": ok,
				"text": "I learned that one of %s is the Poisoner" % _names(pair)}
		"clerk":
			var targets = npcs.filter(func(m): return m != n and not m.is_evil())
			var t = pick(targets)
			var other = pick(npcs.filter(func(m): return m != n and m != t))
			var role: String = t.role
			var ok = true
			if n.poisoned:
				role = pick(C.GOOD_ROLES.filter(func(x): return x != t.role and x != other.role and x != "clerk"))
				ok = false
			var pair = shuffled([t.id, other.id])
			entry = {"data": {"pair": pair, "role": role}, "true": ok,
				"text": "I learned that one of %s is the %s" % [_names(pair), C.role_name(role)]}
		"gravedigger":
			if executed_today == "":
				return
			var ex = by_id[executed_today]
			var role: String = ex.role
			if n.poisoned:
				role = pick(C.ROLES.keys().filter(func(x): return x != ex.role and x != "demon"))
			entry = {"data": {"executed": ex.id, "role": role}, "true": role == ex.role,
				"text": "I learned that %s, whom we hanged, was the %s" % [ex.name, C.role_name(role)]}
		_:
			return
	entry["day"] = day
	entry["role"] = r
	entry["shared"] = false
	if n.poisoned:
		entry["why"] = "poisoned by %s" % minion_id
	n.info_log.append(entry)
	dlog.add("info", n.id, "", entry, "%s (%s) learns: %s%s" % [n.name, r, entry["text"],
		"" if entry["true"] else "  [FALSE: %s]" % entry.get("why", "?")])

func start_new_day() -> void:
	day += 1
	phase = C.MORNING
	if day > max_days and not game_over:
		dlog.set_time(day, "Morning")
		_finish("evil", "Time ran out: the demon survived %d days." % max_days)
		return
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
	dlog.add("snapshot", "world", "", {"tag": tag, "npcs": s})
