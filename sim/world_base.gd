## The case's state and the helpers every part of the simulation uses (split from
## `sim/world.gd`). The simulation is one inheritance chain, so every method is World's:
## `world_base` <- `world_meeting` <- `world_night` <- `world`.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const NPC = preload("res://sim/npc.gd")
const DevLog = preload("res://sim/devlog.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Social = preload("res://sim/social.gd")
const ScriptDef = preload("res://sim/script_def.gd")

var rng = RandomNumberGenerator.new()
var seed_value = 0
var dlog = DevLog.new()
var shadow_log = DevLog.new()   # legacy stream stays separate; detailed trace merges both
## Optional application adapter. Empty in simulation-only callers; no UI dependency.
var workshop_refresh: Callable
var workshop_reasons: Callable # deferred reason attribution for a mind (purge 2a)
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
## What may be in play (sim/script_def.gd). Set before setup(); null deals the Default script.
var case_script = null
var declared_demon_type = ""        # the player's demon-type declaration: "walker", "hexer" or "" (game/demon_declaration.gd)
var declaration_day = -1
var declaration_changes = 0
var evil_plan = {}

## Dynamic locations (crime scenes). id -> {name, block, victim, day, trace_block, trace_true, why, searched}
var scenes = {}
var case_traces: Array = []         # canonical trace records rolled so far in this case
var deaths_last_night: Array = []
var executed_today = ""
var executions: Array = []          # {day, id, nominator, yes, player_yes, player_nominated}
var night_walkers: Array = []       # last night: {id, block, path, why}
var town_relationships: Array = [] # Rolled public bonds, captured before secret Lovers add a friendship.
var public_claims: Array = []       # {day, who, role}
var stances = {}                    # accuser id -> {target, day}: their latest public accusation
var defences = {}                   # supporter id -> {target, day}: their latest public word for someone (M2c)
var meeting_arguments = []          # recency: [{day, target}] the player argued at a meeting
var suspicious_pressure = {}        # premises step 2: "target|cards" -> {sum, count, applied, venue, heard}
var totem = {}                      # the Revenant's hidden totem: {loc, day, owner} or {}
var totem_at_dawn = false           # a totem was in play when the day began (no new one today)
var curse = {}                      # the Revenant's curse: {victim, day} while someone is turned
var sexton_tolled_night = -1        # night the Sexton tolled the church bell
var sexton_suppression_night = -1   # night during which minions are suppressed
var scion_rose = ""                 # the Scion who became the demon, if any
## Everything said or done in public (what evil, and anyone, can know without being told).
var public_log: Array = []          # {day, kind, subjects, by}

## Meeting state (BotC-style: one nomination at a time, "on the block").
var meeting = {}

## Player tools and night choices.
var tools = {"ward": 1, "clemency": 1}
var confides_made: int = 0              # day-1 confidant claims so far (Social._gift_disclosure; capped)
var daily_npc_shares: Array = []    # Non-strategizing NPC-to-NPC items spoken today
var _evening_chats_done_day: int = -1
var initial_good_roles: Array = []  # Good roles dealt at case start (unaffected by death/curse)
var initial_minion_ids: Array = []  # Minion ids dealt at case start (unaffected by Scion promotion)
var initial_evil_ids: Array = []    # Initial evil ids dealt at case start (unaffected by Revenant curse)
var initial_secret_holders: Array = [] # Good townsfolk dealt a secret modifier at case start
var town_hall_uses_left: int = Tuning.Setup.TOWN_HALL_USES_PER_CASE
var town_hall_shown_roles: Array = []
var _town_hall_rng: RandomNumberGenerator = null
var player_ward = ""
var ward_saves: Array = [] # Player-only aftermath, recorded only when their sigil stops an attack.
var sleepwalk_claims: Array = [] # who has said "I've been known to sleepwalk" (to anyone)
var player_vigil = ""
var player_vigil_seen: Array = []
var player_loc = ""
var phase_player_loc = ""   # where the Demonologist spent the phase now ending (the Hexer's wariness)

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

func player_locations() -> Array:
	var out: Array = all_locations()
	for pb in C.PLAYER_BUILDINGS.keys():
		out.append(pb)
	return out

func locations_on(block: String) -> Array:
	return all_locations().filter(func(l): return loc_block(l) == block)

func player_locations_on(block: String) -> Array:
	return player_locations().filter(func(l): return loc_block(l) == block)

## Consult Town Hall census records: returns {roles: [r0, r1], in_play: r_in, uses_left: int}
## using a dedicated deterministic RNG stream so passive simulation RNG is never perturbed.
func consult_town_hall() -> Dictionary:
	if town_hall_uses_left <= 0:
		return {}
	if _town_hall_rng == null:
		_town_hall_rng = RandomNumberGenerator.new()
		_town_hall_rng.seed = hash([seed_value, n_npcs, "town_hall"])
	var in_pool: Array = initial_good_roles.filter(func(r): return not (r in town_hall_shown_roles))
	var out_pool: Array = case_script.town.filter(func(r): return not (r in initial_good_roles) and not (r in town_hall_shown_roles))
	if in_pool.is_empty() or out_pool.is_empty():
		return {}
	var r_in: String = in_pool[_town_hall_rng.randi_range(0, in_pool.size() - 1)]
	var r_out: String = out_pool[_town_hall_rng.randi_range(0, out_pool.size() - 1)]
	var pair: Array = [r_in, r_out] if _town_hall_rng.randi_range(0, 1) == 0 else [r_out, r_in]
	town_hall_shown_roles.append(r_in)
	town_hall_shown_roles.append(r_out)
	town_hall_uses_left -= 1
	dlog.add("town_hall", "player", "", {"roles": pair.duplicate(), "in_play": r_in, "uses_left": town_hall_uses_left},
		"Town Hall records: %s vs %s (in play: %s; %d left)." % [r_in, r_out, r_in, town_hall_uses_left])
	return {"roles": pair, "in_play": r_in, "uses_left": town_hall_uses_left}

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


## Whether the Sexton tolls tonight, and whether it works (a broken gift tolls for nothing).
## The Sexton's bell suppresses minions "until the following night": the toll night and the
## day after it (executions, the Breathstealer, the Revenant's curse, the Scion's rise).
func is_minion_suppressed() -> bool:
	if sexton_suppression_night < 0:
		return false
	return day == sexton_suppression_night or (day == sexton_suppression_night + 1 and phase != C.NIGHT)

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
## A fingerprint of everything the minds hold and the world's random stream, at full
## precision, for the dev log (Game._finish_command; the 16010 replay drift, Nov 18: play and
## replay parted below anything the log recorded). Per NPC, a hash of its suspicion, trust,
## credibility, NPC trust and Workshop state (the connections memory, presentations and
## cached reasoning), real mind and shadow; and the world's RNG state. Strings, so a JSON
## round trip keeps them exact. The replay compares them (LogReplay.digest_hooks).
func state_digest() -> Dictionary:
	var minds: Dictionary = {}
	for n in npcs:
		var parts: Array = [n.suspicion, n.trust, n.credibility, n.npc_trust, n.workshop_state]
		if n.shadow != null:
			parts.append([n.shadow.suspicion, n.shadow.trust, n.shadow.credibility, n.shadow.npc_trust, n.shadow.workshop_state])
		minds[n.id] = str(hash(parts))
	return {"rng": str(rng.state), "minds": minds}

func trace_capture(tag: String, checkpoint: bool = false) -> void:
	if not detailed_logging:
		return
	for n in npcs:
		dlog.capture_npc(n, tag, checkpoint)
		if n.shadow != null:
			shadow_log.set_time(dlog.day, dlog.phase)
			shadow_log.capture_npc(n.shadow, tag, checkpoint)
