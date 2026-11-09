## Daytime presence (docs/demon_types_plan.md, step 2): for each person, day and day phase,
## the chance they were at each town place or at home.
##
## The prior is the sim's own schedule model (`World.start_phase` / `_choose_idle_location`):
## working phases put a person at their workplace; idle phases follow the per-phase odds,
## with a share going to their two haunts (known ones from haunt cards, unknown ones spread
## over the places they could be). Evidence then updates each slot:
##   - the player's watch record (`view.watched`): the player saw everyone at every public
##     place on the block they spent the phase on, so being listed is certain, and not being
##     listed rules that block's places out;
##   - the player's own sightings (certain);
##   - NPC-reported sightings (trusted at PRESENCE_TESTIMONY_TRUST).
## Slots are independent of each other (the sim draws each phase afresh).
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const History = preload("res://workshop/live_history.gd")

const PHASES: Array = ["morning", "afternoon", "evening"]
## The 8 town places NPCs use (C.LOCATIONS), then home.
const PLACES: Array = ["tavern", "well", "smithy", "bakery", "wharf", "mill", "chapel", "graveyard"]
const HOME: int = 8
const SLOTS: int = 9
const TRUST: float = Tuning.Workshop.PRESENCE_TESTIMONY_TRUST

## The sim's idle odds by phase (World._choose_idle_location): fixed places first, and the
## rest goes to "social" picks (a haunt with IDLE_HAUNT_CHANCE, else any of the 8 places).
## Afternoon's friend visit (0.15 to a friend's workplace) is spread over the workplaces in
## use that phase, since friendships aren't known.
const IDLE_FIXED: Array = [
	{"home": 0.15},
	{"tavern": 0.3, "friend": 0.15},
	{"tavern": 0.4, "home": 0.25, "chapel": 0.1},
]


static func place_index(loc: String) -> int:
	if loc == "home" or loc.begins_with("home"):
		return HOME
	return PLACES.find(loc)


static func phase_index(phase) -> int:
	if phase is int:
		return int(phase)
	return PHASES.find(str(phase).to_lower())


static func place_block(i: int) -> String:
	return C.LOCATIONS[PLACES[i]].block if i >= 0 and i < HOME else ""


## {pid: {"d:p": PackedFloat64Array(SLOTS)}} for days 1..view.day and phases 0..2. A dead
## person's slots are all zero.
static func build(view: Dictionary, cards: Array) -> Dictionary:
	var ids: Array = view.get("people", []).map(func(p): return p.id)
	var last_day: int = int(view.get("day", 1))
	var work: Dictionary = {}
	var haunts: Dictionary = {}
	# Occupations are public: the view's people carry them (WorkshopBridge.capture).
	for p in view.get("people", []):
		if str(p.get("work", "")) != "":
			work[p.id] = {"loc": str(p.work), "phases": p.get("work_phases", [])}
	for c in cards:
		if c.get("kind", "") != "context":
			continue
		var subj: String = str(c.get("subject", ""))
		if c.get("context_kind", "") == "work":
			work[subj] = {"loc": str(c.get("data", {}).get("loc", "")), "phases": c.get("data", {}).get("work_phases", [])}
		elif c.get("context_kind", "") == "haunt":
			var known: Array = haunts.get(subj, [])
			for l in c.get("data", {}).get("locs", []):
				if l in PLACES and l not in known:
					known.append(l)
			haunts[subj] = known
	var out: Dictionary = {}
	for pid in ids:
		out[pid] = {}
	for d in range(1, last_day + 1):
		for p in range(3):
			var stamp: Dictionary = {"day": d, "phase": PHASES[p]}
			var busy: PackedFloat64Array = _workplaces_in_use(ids, work, p, view, stamp)
			for pid in ids:
				var dist := PackedFloat64Array()
				dist.resize(SLOTS)
				if History.observer_alive(view, pid, stamp):
					dist = _prior(pid, p, work, haunts, busy)
				out[pid]["%d:%d" % [d, p]] = dist
	_apply_evidence(view, cards, out)
	return out


static func _workplaces_in_use(ids: Array, work: Dictionary, p: int, view: Dictionary, stamp: Dictionary) -> PackedFloat64Array:
	var busy := PackedFloat64Array()
	busy.resize(HOME)
	for pid in ids:
		var w: Dictionary = work.get(pid, {})
		var i: int = PLACES.find(w.get("loc", ""))
		if i >= 0 and p in w.get("phases", []) and History.observer_alive(view, pid, stamp):
			busy[i] += 1.0
	return busy


static func _prior(pid: String, p: int, work: Dictionary, haunts: Dictionary, busy: PackedFloat64Array) -> PackedFloat64Array:
	var dist := PackedFloat64Array()
	dist.resize(SLOTS)
	var w: Dictionary = work.get(pid, {})
	var wi: int = PLACES.find(w.get("loc", ""))
	if wi >= 0 and p in w.get("phases", []):
		dist[wi] = 1.0
		return dist
	# Social picks: a haunt (two, never the workplace) with IDLE_HAUNT_CHANCE, else any place.
	var known: Array = haunts.get(pid, []).filter(func(l): return PLACES.find(l) != wi).slice(0, 2)
	var open: Array = PLACES.filter(func(l): return l not in known and PLACES.find(l) != wi)
	var unknown: int = 2 - known.size()
	var social := PackedFloat64Array()
	social.resize(HOME)
	var hc: float = Tuning.Setup.IDLE_HAUNT_CHANCE
	for i in range(HOME):
		var l: String = PLACES[i]
		var as_haunt: float = 0.0
		if l in known:
			as_haunt = 0.5
		elif l in open and unknown > 0:
			as_haunt = 0.5 * float(unknown) / float(open.size())
		social[i] = hc * as_haunt + (1.0 - hc) / float(HOME)
	var fixed: Dictionary = IDLE_FIXED[p]
	var rest: float = 1.0
	for k in fixed:
		var share: float = float(fixed[k])
		if k == "friend":
			var total: float = 0.0
			for i in range(HOME):
				total += busy[i]
			if total <= 0.0:
				continue
			for i in range(HOME):
				dist[i] += share * busy[i] / total
		elif k == "home":
			dist[HOME] += share
		else:
			dist[PLACES.find(k)] += share
		rest -= share
	for i in range(HOME):
		dist[i] += rest * social[i]
	return dist


static func _apply_evidence(view: Dictionary, cards: Array, out: Dictionary) -> void:
	# The player's watch: everyone at the block's public places is listed.
	for wtch in view.get("watched", []):
		var p: int = phase_index(wtch.get("phase", ""))
		var key: String = "%d:%d" % [int(wtch.get("day", -1)), p]
		var blk: String = str(wtch.get("block", ""))
		if p < 0 or blk not in C.BLOCKS:
			continue
		var seen_at: Dictionary = {}
		for l in wtch.get("at", {}):
			for pid in wtch.at[l]:
				seen_at[str(pid)] = str(l)
		for pid in out:
			if not out[pid].has(key):
				continue
			if seen_at.has(pid):
				_certain(out[pid], key, PLACES.find(seen_at[pid]))
			else:
				_rule_out_block(out[pid], key, blk)
	# Sightings on cards.
	for c in cards:
		if c.get("kind", "") not in ["location", "evening"] or c.get("quoted", false):
			continue
		var p: int = phase_index(c.get("observed_at", {}).get("phase", ""))
		var key: String = "%d:%d" % [int(c.get("day", c.get("observed_at", {}).get("day", -1))), p]
		var li: int = PLACES.find(str(c.get("loc", "")))
		var blk: String = str(c.get("block", ""))
		for pid in c.get("subjects", [c.get("subject", "")]):
			if not out.has(pid) or not out[pid].has(key):
				continue
			if c.get("source", "") == "player":
				if li >= 0:
					_certain(out[pid], key, li)
				else:
					_restrict_block(out[pid], key, blk)
			else:
				if li >= 0:
					_soften(out[pid], key, func(i): return i == li)
				elif blk in C.BLOCKS:
					_soften(out[pid], key, func(i): return place_block(i) == blk)


static func _certain(slots: Dictionary, key: String, i: int) -> void:
	if i < 0:
		return
	# Seen beats the schedule: if the prior ruled this place out, the eyes win.
	var nd := PackedFloat64Array()
	nd.resize(SLOTS)
	nd[i] = 1.0
	slots[key] = nd


static func _rule_out_block(slots: Dictionary, key: String, blk: String) -> void:
	var dist: PackedFloat64Array = slots[key]
	var nd: PackedFloat64Array = dist.duplicate()
	for i in range(HOME):
		if place_block(i) == blk:
			nd[i] = 0.0
	# A schedule that only allowed the watched block (a worker who wasn't there): keep the
	# prior rather than invent an impossible slot. It can't happen in a consistent record.
	if _total(nd) > 0.0:
		slots[key] = _normalized(nd)


static func _restrict_block(slots: Dictionary, key: String, blk: String) -> void:
	var dist: PackedFloat64Array = slots[key]
	var nd: PackedFloat64Array = dist.duplicate()
	for i in range(SLOTS):
		if i == HOME or place_block(i) != blk:
			nd[i] = 0.0
	if _total(nd) > 0.0:
		slots[key] = _normalized(nd)


static func _soften(slots: Dictionary, key: String, fits: Callable) -> void:
	var dist: PackedFloat64Array = slots[key]
	var nd: PackedFloat64Array = dist.duplicate()
	for i in range(SLOTS):
		nd[i] *= TRUST if fits.call(i) else (1.0 - TRUST)
	if _total(nd) > 0.0:
		slots[key] = _normalized(nd)


static func _total(d: PackedFloat64Array) -> float:
	var t: float = 0.0
	for x in d:
		t += x
	return t


static func _normalized(d: PackedFloat64Array) -> PackedFloat64Array:
	var t: float = _total(d)
	var nd: PackedFloat64Array = d.duplicate()
	for i in range(nd.size()):
		nd[i] /= t
	return nd


# --- Queries ---

static func at(table: Dictionary, pid: String, day: int, phase: int, loc: String) -> float:
	var dist: PackedFloat64Array = table.get(pid, {}).get("%d:%d" % [day, phase], PackedFloat64Array())
	var i: int = place_index(loc)
	return dist[i] if i >= 0 and i < dist.size() else 0.0


## Out in public on a block (homes don't count).
static func on_block(table: Dictionary, pid: String, day: int, phase: int, block: String) -> float:
	var dist: PackedFloat64Array = table.get(pid, {}).get("%d:%d" % [day, phase], PackedFloat64Array())
	var s: float = 0.0
	for i in range(mini(HOME, dist.size())):
		if place_block(i) == block:
			s += dist[i]
	return s


## The chance two people were out on the same block in a phase (independent slots).
static func same_block(table: Dictionary, a: String, b: String, day: int, phase: int) -> float:
	var s: float = 0.0
	for blk in C.BLOCKS:
		s += on_block(table, a, day, phase, blk) * on_block(table, b, day, phase, blk)
	return s


## The chance someone was at any of `locs` in at least one of `phases` on `day`.
static func at_any(table: Dictionary, pid: String, day: int, locs: Array, phases: Array = [0, 1, 2]) -> float:
	var miss: float = 1.0
	for p in phases:
		var s: float = 0.0
		for l in locs:
			s += at(table, pid, day, int(p), l)
		miss *= 1.0 - clampf(s, 0.0, 1.0)
	return 1.0 - miss


# --- Breathstealer by presence ---

## The Breathstealer silences someone out on its own block, in one of the day phases
## (sim/roles/breathstealer.gd), so for each silencing the silencer was out on the victim's
## block in the same phase. For each person m, A_m = product over silencings of
##     sum over phases p of  P(not yet, before p) * h_p * c_p,
## where c_p = P(m and the victim out on the same block in p) and h_p is the sim's
## per-phase chance of acting (the mean of its low and high odds). The per-world factor is
## the mean of A_m over the world's minions (each equally likely to hold the role), mixed with
## DEFAULT_ERR. Returns {} when nobody was silenced or no Breathstealer can be in play.
static func breath_factor(view: Dictionary, cards: Array = []) -> Dictionary:
	var minions: Array = view.get("script_minions", [])
	if not minions.is_empty() and "breathstealer" not in minions:
		return {}
	var silencings: Array = []
	var seen: Dictionary = {}
	for e in view.get("timeline", {}).get("events", []):
		if e.get("kind", "") == "silenced" and int(e.get("at", {}).get("day", -1)) >= 1:
			for v in e.get("subjects", []):
				if seen.has("%d:%s" % [int(e.at.day), v]):
					continue  # (the timeline can carry an event twice)
				seen["%d:%s" % [int(e.at.day), v]] = true
				silencings.append({"day": int(e.at.day), "victim": str(v)})
	if silencings.is_empty():
		return {}
	var all_cards: Array = cards if not cards.is_empty() else view.get("cards", [])
	var table: Dictionary = build(view, all_cards)
	var ids: Array = view.get("people", []).map(func(p): return p.id)
	var bs: Dictionary = Tuning.Roles.BREATHSTEALER
	var h: Array = []
	for p in range(3):
		h.append(0.5 * (float(bs.phase_probs_low[p]) + float(bs.phase_probs_high[p])))
	var weights := PackedFloat64Array()
	weights.resize(ids.size())
	var total: float = 0.0
	var counted: int = 0
	for i in range(ids.size()):
		var m: String = ids[i]
		var a: float = 1.0
		for s in silencings:
			if s.victim == m:
				a = 0.0
				break
			var not_yet: float = 1.0
			var like: float = 0.0
			for p in range(3):
				var c: float = same_block(table, m, s.victim, s.day, p)
				like += not_yet * float(h[p]) * c
				not_yet *= 1.0 - float(h[p]) * c
			a *= like
		weights[i] = a
		if a > 0.0:
			total += a
			counted += 1
	if counted == 0 or total <= 0.0:
		return {}
	var mean: float = total / float(counted)
	for i in range(weights.size()):
		weights[i] /= mean
	var days: Array = []
	for s in silencings:
		if s.day not in days:
			days.append(s.day)
	return {"origin": "breath_presence", "breath_presence": true, "target": "", "log2_ratio": 1.0,
		"label": "Who was near each silencing (day %s)" % ", ".join(PackedStringArray(days.map(func(d): return str(d)))),
		"cards": [], "weights": weights, "silencings": silencings}


## The factor's per-world value (GDScript reference for the C# kernel): the mean weight of the
## world's minions (evil, not the Demon), mixed with `err`.
static func breath_score(world: Dictionary, factor: Dictionary, err: float) -> float:
	var evil: int = int(world.get("evil", 0))
	var demon: int = int(world.get("demon", -1))
	var w: PackedFloat64Array = factor.weights
	var s: float = 0.0
	var k: int = 0
	for j in range(w.size()):
		if (evil >> j) & 1 and j != demon:
			s += w[j]
			k += 1
	return (1.0 - err) * (s / float(k) if k > 0 else 0.0) + err
