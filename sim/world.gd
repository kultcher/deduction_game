## The case simulation: setup, schedules, sightings, night resolution, meetings, executions.
## Deterministic from the seed. No presentation code lives here; player-facing text is
## produced by game.gd from the facts this class exposes.
##
## Setup and the day phases live here. The state and helpers are in `world_base.gd`, the
## meeting in `world_meeting.gd` and the night in `world_night.gd`, all one inheritance
## chain, so World's methods and state are unchanged for every caller.
extends "res://sim/world_night.gd"

# ---------------------------------------------------------------- setup

func setup(seed_in: int, npc_count: int = 7, on_cast_ready: Callable = Callable()) -> void:
	seed_value = seed_in
	rng.seed = seed_in
	n_npcs = npc_count
	max_days = 6 if npc_count < 10 else 8
	day = 0
	phase = C.NIGHT
	daily_npc_shares = []
	confides_made = 0
	_evening_chats_done_day = -1
	initial_good_roles = []
	town_hall_uses_left = Tuning.Setup.TOWN_HALL_USES_PER_CASE
	town_hall_shown_roles = []
	_town_hall_rng = null
	var build_id: String = trace_build if trace_build != "" else str(ProjectSettings.get_setting("application/config/version", ""))
	if build_id == "":
		build_id = preload("res://sim/build_info.gd").commit() # the git commit, so a log can be replayed on its code
	if build_id == "":
		build_id = "dev"
	var tuning_id: String = trace_tuning if trace_tuning != "" else Tuning.fingerprint()
	trace_build = build_id
	trace_tuning = tuning_id
	dlog.configure_trace(detailed_logging)
	shadow_log.configure_trace(detailed_logging, dlog.trace_context(), "shadow")
	dlog.set_time(0, "Setup")
	dlog.begin_action("setup", {"seed": seed_in, "npcs": npc_count, "build": build_id, "tuning": tuning_id})
	dlog.trace_event("trace_header", "world", "", {"seed": seed_in, "npcs": npc_count,
		"engine": Engine.get_version_info(), "build": build_id, "tuning": tuning_id,
		"shared_execution_priority_weight": C.SHARED_EXECUTION_PRIORITY_WEIGHT,
		"coverage": "milestone_2_state_and_structured_decisions"})
	var start: Dictionary = {"seed": seed_in, "npcs": npc_count, "build": build_id,
		"tuning": tuning_id, "shared_execution_priority_weight": C.SHARED_EXECUTION_PRIORITY_WEIGHT}
	# Every log since #160 is played on the connections belief model and says so; the replay
	# tools stop on a log without it (one played on the earlier model, purge phase 3).
	start["connections"] = true
	dlog.add("case_start", "world", "", start)
	if case_script == null:
		case_script = ScriptDef.default_script()
	elif not case_script.is_default():
		# Only a non-default script is logged, so Default cases stay trace-identical.
		dlog.add("case_script", "world", "", {"name": case_script.name, "fingerprint": case_script.fingerprint(),
			"script": case_script.to_dict()})
	# A script that deals one kind of Demon starts declared (game/demon_declaration.gd).
	var kinds: Dictionary = {}
	for d in (case_script.demons if not case_script.demons.is_empty() else ["demon"]):
		kinds["hexer" if C.is_day_demon(str(d)) else "walker"] = true
	declared_demon_type = kinds.keys()[0] if kinds.size() == 1 else ""

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
		# One shift each (Nov 10). The old extra-shift roll still draws, so the rest of the
		# setup (homes, haunts, roles) deals exactly as before; the shift is just not added.
		if chance(Tuning.Setup.LEGACY_EXTRA_SHIFT_DRAW):
			var extra = pick([0, 1, 2].filter(func(p): return not (p in n.work_phases)))
			if Tuning.Setup.EXTRA_WORK_SHIFT_CHANCE > 0.0:
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

	# Each good NPC knows their own gift: a firsthand record that counts against anyone
	# who claims it falsely.
	for n in npcs:
		if not n.is_evil():
			Mind.hear_claim(self, n, n.id, n.role, Tuning.Setup.OWN_ROLE_CLAIM_WEIGHT, "own")
	evil_plan = Evil.make_plan(self)
	_log_grimoire()
	trace_capture("initial_setup", true)
	if on_cast_ready.is_valid():
		on_cast_ready.call(self)

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
	var sc = case_script
	# Forced roles (custom games) are dealt first; the rest is drawn as before, so the
	# Default script deals exactly what the global lists always did.
	var forced_town: Array = sc.forced_in(sc.town)
	var town_pool: Array = sc.town.filter(func(r): return not r in forced_town)
	var forced_mins: Array = sc.forced_in(sc.minions)
	var minion_pool: Array = sc.minions.filter(func(r): return not r in forced_mins)
	var good: Array = []
	var guaranteed = func(g: Array) -> bool:
		return g.filter(func(r): return r in C.START_ROLES).size() >= 2 and g.any(func(r): return r in C.IDENTIFIER_ROLES)
	for attempt in range(200):
		good = forced_town + shuffled(town_pool).slice(0, cfg["town"] - forced_town.size())
		if guaranteed.call(good):
			break
	var mins: Array = forced_mins + shuffled(minion_pool).slice(0, cfg["minions"] - forced_mins.size())
	# Night-walkers in play must sit in the size's band (ScriptDef.DEAL_RULES). A deal that
	# already fits is kept as drawn (same draws as before the rule existed); otherwise gifts
	# and minions are redrawn together until everything holds. After 200 tries the last
	# draw stands.
	if not ScriptDef.deal_ok(good + mins, n_npcs):
		for attempt in range(200):
			good = forced_town + shuffled(town_pool).slice(0, cfg["town"] - forced_town.size())
			mins = forced_mins + shuffled(minion_pool).slice(0, cfg["minions"] - forced_mins.size())
			if guaranteed.call(good) and ScriptDef.deal_ok(good + mins, n_npcs):
				break
	var order = shuffled(npcs)
	var forced_demon: Array = sc.forced_in(sc.demons)
	order[0].role = forced_demon[0] if not forced_demon.is_empty() else (sc.demons[0] if sc.demons.size() == 1 else pick(sc.demons))
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
	initial_good_roles = good.duplicate()
	initial_minion_ids = minion_ids.duplicate()
	initial_evil_ids = ([demon_id] + minion_ids).duplicate()
	var evil_count = 1 + mins.size()
	# Evil only ever bluffs a gift that is on the script.
	bluffs = shuffled(sc.town.filter(func(r): return not role_in_play(r))).slice(0, maxi(3, evil_count + 1))
	for n in npcs:
		var rdef = C.role_def(n.role)
		if rdef != null:
			rdef.setup_world(self, n)

## One secret modifier per case, on a townsfolk (the Lovers take two), on top of their gift.
func _assign_secret_mod() -> void:
	initial_secret_holders = []
	var goods = shuffled(npcs.filter(func(n): return not n.is_evil()))
	if goods.size() < 2:
		return
	var forced_secret: Array = case_script.forced_in(case_script.secrets)
	var k: String = forced_secret[0] if not forced_secret.is_empty() else pick(case_script.secrets)
	# Placement rules (ScriptDef.PLACEMENT_RULES): the Rumormonger never holds a secret
	# alone; Lovers and Sleepwalker never land on a night-walker (Case 22485). Each rule
	# narrows the candidates in turn, as the hand-written checks always did.
	for rule in ScriptDef.PLACEMENT_RULES:
		if rule.has("except") and k in rule.except:
			continue
		if rule.has("only") and not k in rule.only:
			continue
		goods = goods.filter(func(n): return not C.role_def(n.role).get(rule.not_on_flag))
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
	initial_secret_holders = npcs.filter(func(n): return not n.is_evil() and n.secret_mod != "").map(func(n): return n.id)
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
		if day >= 1:
			_morning_executor_gifts()
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
			if n.is_evil() and (C.is_day_demon(n.role) or n.role == "breathstealer"):
				n.loc = C.role_def(n.role).free_location(self, n, n.loc, Evil)
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
	if not n.haunts.is_empty() and chance(Tuning.Setup.IDLE_HAUNT_CHANCE):
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
		return Tuning.Setup.PAIR_SILENCED_WEIGHT
	return clampf((t - Tuning.Setup.PAIR_TRUST_PIVOT) * Tuning.Setup.PAIR_TRUST_SLOPE + Social.news_bonus(self, a, b) + nudge, Tuning.Setup.PAIR_SILENCED_WEIGHT, Tuning.Setup.PAIR_MAX_WEIGHT)

func _idle_pairable() -> Array:
	return living().filter(func(n): return not n.working and n.available() and n.pair_day != day)

func _pre_pair() -> void:
	var max_pairs = 1 if n_npcs < 10 else n_npcs / 5
	var made = 0
	# Each pair slot rolls on its own (Nov 8): one failed roll no longer silences the phase.
	for slot in range(max_pairs):
		var cands = _idle_pairable()
		if cands.size() < 2 or player_options().size() - 2 < 3:
			break
		if not decision_roll(null, "pre_phase_conversation", Tuning.Setup.PRE_PHASE_CHAT_CHANCE):
			continue
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
	if when != "pre":
		_witness_meeting(a, b)
	Social.converse(self, a, b, when)

## Those at the place where two people talked after the player had gone see it (BACKLOG item
## 3, Michael, Nov 18: every meeting feeds the gossip network). A meeting before the player's
## choice is seen through the phase's day sightings (`_day_sightings`, the "with" field).
func _witness_meeting(a, b) -> void:
	if a.at_home() or a.loc != b.loc:
		return
	for x in living():
		if x == a or x == b or x.at_home() or x.loc != a.loc:
			continue
		for pr in [[a, b], [b, a]]:
			x.beliefs.append({"kind": "saw", "who": pr[0].id, "loc": a.loc, "block": loc_block(a.loc),
				"day": day, "phase": phase, "with": pr[1].id})

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
			if same_loc or (same_block and chance(Tuning.Setup.SAME_BLOCK_SIGHTING_CHANCE)):
				a.beliefs.append({"kind": "saw", "who": b.id, "loc": b.loc if same_loc else "",
					"block": loc_block(b.loc), "day": day, "phase": phase,
					"with": b.busy_with if same_loc and b.busy_with != a.id else ""})

## Run the evening post-phase NPC conversations early (used by Evening Tavern Gossip
## so the player hears word from across the whole day, including evening chats, once).
func finish_evening_conversations(talked_id: String = "") -> void:
	if phase != C.EVENING or _evening_chats_done_day == day:
		return
	_evening_chats_done_day = day
	_post_pair(talked_id)

## Advance to the next day phase. Returns false at the end of Evening.
func end_day_phase(talked_id: String = "") -> bool:
	for r in C.DAY_DEMONS:
		var hexer = living_with_role(r)
		if hexer != null:
			C.role_def(r).hex_decision(self, hexer, Evil)
	phase_player_loc = ""
	if phase == C.EVENING and _evening_chats_done_day == day:
		pass
	else:
		if phase == C.EVENING:
			_evening_chats_done_day = day
		_post_pair(talked_id)
	snapshot("phase_end")
	if phase < C.EVENING:
		phase += 1
		start_phase()
		return true
	return false


func start_new_day() -> void:
	day += 1
	phase = C.MORNING
	# Yesterday's talk still circulates at the tavern (Nov 8); older talk drops out.
	daily_npc_shares = daily_npc_shares.filter(func(r): return int(r.get("day", -9)) >= day - 1)
	_evening_chats_done_day = -1
	if day > max_days and not game_over:
		dlog.set_time(day, "Morning")
		_finish("evil", "Time ran out: the Demon survived %d days." % max_days)
		return
	dlog.set_time(day, "Morning")
	if C.SHADOW_SELF:
		Evil.review_scapegoat(self)
		Evil.plan_daily_frame(self)
	start_phase()
