## The case simulation: setup, schedules, sightings, night resolution, executions.
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
var deaths_last_night: Array = []   # ids killed in the most recent night
var executed_today = ""
var executions: Array = []          # {day, id, votes, nominators}
var night_walkers: Array = []       # last night: {id, block, why}
var public_claims: Array = []       # {day, who, role}
var nominations_today: Array = []   # {nominee, by}

var player_ward = ""
var player_vigil = ""
var player_vigil_seen: Array = []   # ids the player saw during last night's vigil
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

func living_ids() -> Array:
	return living().map(func(n): return n.id)

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
	return C.loc_block(l)

func all_locations() -> Array:
	var out: Array = C.LOCATIONS.keys()
	for s in scenes.keys():
		out.append(s)
	return out

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
		n.traits = c["traits"].duplicate()
		n.occupation = C.OCCUPATIONS[occs[i]]["title"]
		n.work = C.OCCUPATIONS[occs[i]]["work"]
		n.home_block = pick(blocks)
		n.ring = ring_order[i]
		npcs.append(n)
		by_id[n.id] = n

	_assign_roles()
	_assign_relationships()
	_assign_secrets()

	for n in npcs:
		for m in npcs:
			if m != n:
				var s = 0.1
				if m.id in n.rivals:
					s += 0.15
				if m.id in n.friends:
					s -= 0.1
				n.suspicion[m.id] = s
		n.trust = clampf(0.3 + 0.3 * (1.0 - n.traits["caution"]) + rng.randf_range(-0.05, 0.1), 0.1, 0.9)

	evil_plan = Evil.make_plan(self)
	_log_grimoire()

	# First night: poisoner acts, first-night info, no kill.
	resolve_night()
	# Dawn of day 1.
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
		dlog.add("secret_assigned", n.id, s.get("with", ""), s, "%s %s (good NPC; will lie about it)" % [n.name, s["text"]])

func _log_grimoire() -> void:
	var g = []
	for n in npcs:
		g.append({"id": n.id, "occupation": n.occupation, "role": n.role, "align": n.alignment,
			"home": n.home_block, "ring": n.ring, "friends": n.friends, "rivals": n.rivals,
			"traits": n.traits, "secret": n.secret.get("kind", ""), "red_herring": n.red_herring})
	dlog.add("grimoire", "world", "", {"npcs": g, "bluffs": bluffs, "plan": evil_plan},
		"Hidden setup. Demon=%s, Poisoner=%s, bluffs=%s" % [demon_id, minion_id, str(bluffs)])

# ---------------------------------------------------------------- day phases

## Called at the start of each day phase: NPCs move and see each other.
func start_phase() -> void:
	set_log_time()
	for n in npcs:
		if not n.alive:
			continue
		var l = _choose_location(n)
		n.loc = l
		n.history[time_key()] = l if l != "home" else "home:" + n.home_block
	var placed = {}
	for n in living():
		placed[n.id] = n.loc
	dlog.add("positions", "world", "", placed)
	_day_sightings()

func _choose_location(n) -> String:
	var r = rng.randf()
	var social: Array = ["tavern", "well", "chapel", "bakery", "wharf", "smithy", "mill", "graveyard"]
	match phase:
		C.MORNING:
			if r < 0.85:
				return n.work
			return pick(social)
		C.AFTERNOON:
			if r < 0.45:
				return n.work
			if r < 0.62:
				return "tavern"
			if r < 0.75 and not n.friends.is_empty():
				var f = npc(pick(n.friends))
				if f and f.alive:
					return f.work
			return pick(social)
		C.EVENING:
			if r < 0.4:
				return "tavern"
			if r < 0.68:
				return "home"
			if r < 0.78:
				return "chapel"
			return pick(social)
	return "home"

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

## Advance to the next day phase (Morning->Afternoon->Evening). Returns false at Evening end.
func end_day_phase() -> bool:
	snapshot("phase_end")
	if phase < C.EVENING:
		phase += 1
		start_phase()
		return true
	return false

# ---------------------------------------------------------------- town meeting

func run_testimony() -> Array:
	set_log_time()
	nominations_today = []
	executed_today = ""
	return Mind.meeting_testimony(self)

func npc_nominations() -> Array:
	var noms: Array = Mind.npc_nominations(self)
	for nm in noms:
		nominations_today.append(nm)
	return noms

## nominees: Array of {nominee, by}. player_vote: npc id the player supports ("" = none).
## Returns {results:[{nominee, by, yes:[ids], no:[ids], player_yes}], executed}
func run_votes(nominees: Array, player_vote: String) -> Dictionary:
	set_log_time()
	var voters = living()
	var total_voters = voters.size() + 1
	var results: Array = []
	var best = ""
	var best_votes = 0
	var tie = false
	for nm in nominees:
		var nid: String = nm["nominee"]
		if not by_id[nid].alive:
			continue
		var yes: Array = []
		var no: Array = []
		for v in voters:
			var decision: bool = Mind.vote(self, v, nid, nm["by"], player_vote == nid, yes.size())
			if decision:
				yes.append(v.id)
			else:
				no.append(v.id)
		var py: bool = player_vote == nid
		var count = yes.size() + (1 if py else 0)
		results.append({"nominee": nid, "by": nm["by"], "yes": yes, "no": no, "player_yes": py, "count": count})
		dlog.add("vote_tally", "world", nid, {"yes": yes, "no": no, "player_yes": py, "count": count,
			"needed": total_voters / 2 + 1})
		if count > total_voters / 2:
			if count > best_votes:
				best = nid
				best_votes = count
				tie = false
			elif count == best_votes:
				tie = true
	var executed = ""
	if best != "" and not tie:
		executed = best
		execute(best, results)
	elif tie:
		dlog.add("no_execution", "world", "", {}, "Tie between nominees; nobody is executed.")
	else:
		dlog.add("no_execution", "world", "", {}, "No nominee reached a majority.")
	return {"results": results, "executed": executed, "total_voters": total_voters}

func execute(id: String, results: Array) -> void:
	var n = by_id[id]
	n.alive = false
	n.death_day = day
	n.death_cause = "executed"
	n.loc = "dead"
	executed_today = id
	var nominators: Array = []
	for r in results:
		if r["nominee"] == id:
			nominators.append(r["by"])
	executions.append({"day": day, "id": id, "nominators": nominators})
	dlog.add("execution", "world", id, {"role": n.role, "align": n.alignment},
		"%s (%s) executed by town vote." % [n.name, n.role])
	if id == demon_id:
		_finish("good", "The demon's host was executed.")
	else:
		_check_parity()

func _check_parity() -> void:
	if game_over:
		return
	if demon().alive and living().size() <= 2:
		_finish("evil", "Only two townsfolk remain and the demon still walks among them.")

func _finish(w: String, why: String) -> void:
	game_over = true
	winner = w
	end_reason = why
	dlog.add("game_over", "world", "", {"winner": w}, why)

# ---------------------------------------------------------------- night

## Resolves one night: evil choices, movement, poison, protection, kill, info, sightings.
func resolve_night() -> void:
	phase = C.NIGHT
	set_log_time()
	var first = day == 0
	for n in npcs:
		if n.poisoned:
			dlog.add("poison_wears_off", "world", n.id)
		n.poisoned = false
		n.pressed_today = 0

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
	for w in night_walkers:
		var wn = by_id[w["id"]]
		for o in living():
			if o == wn:
				continue
			var saw = false
			if o.out_last_night and o.night_block == w["block"]:
				saw = chance(0.5)
			elif not o.out_last_night and o.home_block == w["block"]:
				saw = chance(0.15)
			if saw:
				o.beliefs.append({"kind": "saw", "who": wn.id, "loc": "", "block": w["block"], "day": day, "phase": C.NIGHT})
				dlog.add("night_sighting", o.id, wn.id, {"block": w["block"]}, "%s glimpsed %s on %s at night." % [o.name, wn.name, C.block_name(w["block"])])
		if player_vigil != "" and w["block"] == player_vigil and wn.alive:
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
	# Physical trace: usually the block where the killer spent the evening.
	var ev_loc: String = d.history.get(time_key(day, C.EVENING), "home:" + d.home_block)
	var true_block = ""
	if ev_loc.begins_with("home:"):
		true_block = ev_loc.substr(5)
	else:
		true_block = loc_block(ev_loc)
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
			for pid in pair:
				if pid == demon_id or pid == n.red_herring:
					yes = true
			var true_yes = false
			for pid in pair:
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
			for w in night_walkers:
				if w["block"] == watch_block and w["id"] != n.id:
					seen.append(w["id"])
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

func _names(ids: Array) -> String:
	var names: Array = ids.map(func(i): return by_id[i].name)
	if names.size() == 2:
		return "%s and %s" % names
	return ", ".join(PackedStringArray(names))

## Morning bookkeeping after a night.
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
		s[n.id] = {"loc": n.loc, "poisoned": n.poisoned, "trust": snappedf(n.trust, 0.01),
			"claim": n.claimed_role, "suspicion": sus}
	dlog.add("snapshot", "world", "", {"tag": tag, "npcs": s})
