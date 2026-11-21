## The night: kills, movement, sightings and traces, gifts and abilities, day gifts
## (split from `sim/world.gd`; part of World's inheritance chain).
extends "res://sim/world_meeting.gd"


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
	load("res://sim/burdens.gd").lift_omen(self)  # a fallen Ill-Omened's poison (burdens prototype)

	# The Sexton's bell (start of night, once per case from night 1): suppresses all minions
	var sexton = living_with_role("sexton")
	if sexton and not sexton.is_evil() and not first:
		C.role_def("sexton").try_toll(self, sexton, Mind)

	var brute = living_with_role("brute")
	var brute_active: bool = (brute != null and brute.alive and not brute.gift_broken() and not is_minion_suppressed())

	var kill_t = ""
	# A Hexer (day-killing demon) kills from today's hex, without walking, unless an active
	# Brute hunts in its place.
	var hexer_kills: bool = C.is_day_demon(demon().role) and not brute_active
	if not first and demon().alive:
		kill_t = C.role_def(demon().role).night_victim(self, demon()) if hexer_kills else Evil.choose_kill_target(self)
	var poisoner = living_with_role("poisoner")
	var poison_t = ""
	if poisoner != null:
		poison_t = Evil.choose_poison_target(self, kill_t)
	var warden = living_with_role("warden")
	var warden_t = ""
	if warden and not warden.is_evil():
		warden_t = Mind.warden_target(self, warden)
		# No guard on night 0: there's no kill to stop yet (Michael, Nov 13; triage 7.1).
		# The pick still runs so the random stream doesn't shift.
		if first:
			warden_t = ""
	var watch = living_with_role("nightwatch")
	var watch_block = ""
	if watch and not watch.is_evil():
		watch_block = Mind.watch_block(self, watch)
	var medium = living_with_role("medium")
	var medium_t = ""
	if medium and not medium.is_evil():
		medium_t = _medium_choice(medium)
	var lamp = living_with_role("lamplighter")
	if lamp != null and lamp.is_evil():
		lamp = null
	var mart = living_with_role("martyr")
	if mart != null and not mart.is_evil() and mart.martyr_target == "" and not first:
		_martyr_choice(mart)
	var confessor = living_with_role("confessor")
	var confessor_t = ""
	if confessor and not confessor.is_evil() and not first:
		confessor_t = _confessor_choice(confessor)

	_night_movement(poison_t, kill_t, watch, watch_block, warden, warden_t, medium, medium_t, lamp, confessor, confessor_t, brute, brute_active)

	if poison_t != "":
		if is_minion_suppressed():
			dlog.add("poison_suppressed", poisoner.id, poison_t, {}, "The Poisoner targets %s, but their ability is suppressed by the church bell." % by_id[poison_t].name)
		else:
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
				_receive_info(n, watch_block, medium_t, lamp, confessor_t)
	var was_defer: bool = defer_beliefs
	defer_beliefs = true
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
			dlog.add("kill_failed", demon_id, kill_t, {"why": outcome}, "The Demon's attack on %s failed (%s)." % [v.name, outcome])
			if C.has_role_def(outcome):
				C.role_def(outcome).on_survive_attack(self, v)

	if day >= 1 and deaths_last_night.is_empty():
		_quiet_night()
		if warden_t != "" and demon() != null and demon().alive:
			_warden_credit(warden, warden_t)
	if not C.INFO_BEFORE_KILL:
		for n in living_good():
			if C.ROLES[n.role]["kind"] == "info":
				_receive_info(n, watch_block, medium_t, lamp, confessor_t)

	_night_sightings()
	if kill_t != "":
		Evil.note_kill_result(self, kill_t, kill_outcome)
	Evil.gather_night_intel(self)
	Evil.make_fake_info(self)
	Mind.update_from_own_info(self)
	Mind.flush_beliefs(self)
	defer_beliefs = was_defer
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


func _sexton_knell() -> bool:
	var sx = living_with_role("sexton")
	return C.role_def("sexton").try_knell(self, sx, Mind)

## The Veteran survives their one attack and learns the last block the attacker came through.
func _veteran_survives(v) -> void:
	C.role_def("veteran").on_survive_attack(self, v)

## The Martyr chooses once, only someone they trust well.
func _confessor_choice(conf) -> String:
	return C.role_def("confessor").pick_targets(self, conf, Mind)

func _martyr_choice(mart) -> void:
	C.role_def("martyr").pick_targets(self, mart, Mind)

## Public hearth eligibility: Demon victims only; revisit the latest after all are visited.
func _medium_choice(m) -> String:
	return C.role_def("medium").pick_targets(self, m, Mind)

## Nobody died: a point in favour of whoever publicly claims to protect (Warden) or to be
## unkillable (Veteran). Evil can claim these too, so it's evidence, not proof.
## A quiet night while a good Warden stood at someone's door (Oct 30, phase 3 of
## docs/social_trust_pass.md). The Demon kills every night from night 1, so the Warden takes
## the quiet as their save, discounted by the other explanations they know of (a living
## public Veteran claim each). They don't know whether their gift actually worked. Above
## WARDEN_SAVE_BELIEF_MIN they believe it: they warm to the person the Demon went for (the
## Demon picks the good), and, if they trust that person, tell them.
func warden_knows_ward(warden, night: int) -> bool:
	if warden == null:
		return false
	if night == day and player_ward == warden.id:
		return true
	if dlog.entries.any(func(e): return e["type"] == "protect" and e["day"] == night and e["actor"] == "player" and e["target"] == warden.id):
		return true
	return dlog.entries.any(func(e): return e["type"] == "player_ward_context" and int(e["data"].get("night", -1)) == night and (e["data"].get("public", false) or warden.id in e["data"].get("listeners", [])))

func reweigh_warden_credit_for_ward(warden, night: int, card_kind: String, ward_target: String) -> void:
	if warden == null or warden.is_evil() or not warden.warden_saves.has(str(night)):
		return
	var prev: Dictionary = warden.warden_saves[str(night)]
	var prot_id: String = str(prev.get("target", ""))
	var old_belief: float = float(prev.get("belief", 0.0))
	if card_kind == "scorched_sigil" and ward_target != "" and ward_target != prot_id:
		warden.warden_saves.erase(str(night))
		if by_id.has(prot_id):
			warden.npc_trust[prot_id] = clampf(warden.npc_trust.get(prot_id, 0.5) - Tuning.Roles.WARDEN_SAVE_TRUST * old_belief, 0.0, 1.0)
		return
	var alternatives: int = public_claims.filter(func(pc): return pc["role"] == "veteran" and pc["who"] != warden.id and by_id[pc["who"]].alive).size()
	if warden_knows_ward(warden, night):
		alternatives += 1
	var new_belief: float = 1.0 / float(1 + alternatives)
	if new_belief >= old_belief:
		return
	if by_id.has(prot_id):
		warden.npc_trust[prot_id] = clampf(warden.npc_trust.get(prot_id, 0.5) + Tuning.Roles.WARDEN_SAVE_TRUST * (new_belief - old_belief), 0.0, 1.0)
	if new_belief < Tuning.Roles.WARDEN_SAVE_BELIEF_MIN:
		warden.warden_saves.erase(str(night))
	else:
		warden.warden_saves[str(night)]["belief"] = new_belief

func _warden_credit(warden, target: String) -> void:
	if warden == null or warden.is_evil() or not by_id.has(target) or not by_id[target].alive:
		return
	var alternatives: int = public_claims.filter(func(pc): return pc["role"] == "veteran" and pc["who"] != warden.id and by_id[pc["who"]].alive).size()
	if warden_knows_ward(warden, day):
		alternatives += 1
	var belief: float = 1.0 / float(1 + alternatives)
	if belief < Tuning.Roles.WARDEN_SAVE_BELIEF_MIN:
		return
	var protectee = by_id[target]
	warden.warden_saves[str(day)] = {"target": target, "belief": belief}
	warden.npc_trust[target] = clampf(warden.npc_trust.get(target, 0.5) + Tuning.Roles.WARDEN_SAVE_TRUST * belief, 0.0, 1.0)
	dlog.add("warden_save_belief", warden.id, target, {"night": day, "belief": belief, "alternatives": alternatives},
		"%s believes their watch turned the Demon from %s's door." % [warden.name, protectee.name])
	if warden.npc_trust.get(target, 0.5) >= Tuning.Roles.WARDEN_TELL_TRUST:
		Mind.tell_save(self, warden, protectee, day, belief)

func _quiet_night() -> void:
	dlog.add("quiet_night", "world", "", {"night": day}, "Nobody died on night %d." % day)
	for pc in public_claims:
		var qdef = C.role_def(pc["role"])
		if qdef == null or not qdef.can_cause_quiet_night or not by_id[pc["who"]].alive:
			continue
		for l in living_good():
			if l.id == pc["who"]:
				continue
			Mind.ledger_hear(self, l, "quiet:%d>%s" % [day, pc["who"]], [], 1.0, [pc["who"], -1, "report"], {"kind": "quiet_night", "night": day, "claimant": pc["who"], "role": pc["role"]})

func _night_movement(poison_t: String, kill_t: String, watch, watch_block: String, warden = null, warden_t: String = "",
		medium = null, medium_t: String = "", lamp = null, confessor = null, confessor_t: String = "", brute = null, brute_active: bool = false) -> void:
	night_walkers = []
	for n in living():
		n.out_last_night = false
		n.night_block = n.home_block
		n.night_path = []
		n.loc = "home"
	if kill_t != "":
		if brute_active and brute != null:
			_walk(brute, by_id[kill_t].home_block, "hunting %s (as Brute)" % by_id[kill_t].name)
		elif not C.is_day_demon(demon().role):
			_walk(demon(), by_id[kill_t].home_block, "hunting %s" % by_id[kill_t].name)
		# (A Hexer kills from where it sleeps: no walk, never seen in the streets.)
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
	if confessor and confessor_t != "" and by_id.has(confessor_t):
		_walk(confessor, by_id[confessor_t].home_block, "hearing confession of %s" % by_id[confessor_t].name)
	var sx_walk = living_with_role("sexton")
	if sx_walk and sexton_tolled_night == day:
		_walk(sx_walk, sx_walk.home_block, "tolling the church bell through every parish", C.BLOCKS.keys())
	# The Unrequited visits the beloved's door, or their grave once they're gone (burdens prototype).
	for n in living():
		var visit: String = load("res://sim/burdens.gd").unrequited_visit(self, n)
		if visit != "":
			_walk(n, visit, "secret: unrequited (%s)" % ("the beloved's grave" if visit == "hill" and not by_id[n.beloved].alive else "the beloved's door"))
	for n in living():
		n.history[time_key(day, C.NIGHT)] = ("night:" if n.out_last_night else "home:") + n.night_block
	dlog.add("night_movement", "world", "", {"walkers": night_walkers})

func _walk(n, block: String, why: String, path: Array = []) -> void:
	n.out_last_night = true
	n.night_block = block
	n.night_path = C.route(n.home_block, block) if path.is_empty() else path.duplicate()
	n.loc = "night:" + block
	night_walkers.append({"id": n.id, "block": block, "path": n.night_path, "why": why})

func _night_sightings() -> void:
	player_vigil_seen = []
	for wk in night_walkers:
		var wn = by_id[wk["id"]]
		var path: Array = wk.get("path", [wk["block"]])
		for o in living():
			if o == wn:
				continue
			var saw = false
			var where = ""
			if o.out_last_night and o.night_block in path:
				saw = chance(Tuning.Setup.NIGHT_SIGHTING_STREET_CHANCE)
				where = o.night_block
			elif not o.out_last_night and o.home_block in path:
				var is_mon: bool = (o.role == "monitor") or (o.is_evil() and evil_plan.get("bluffs", {}).get(o.id, "") == "monitor")
				if not is_mon:
					saw = chance(Tuning.Setup.NIGHT_SIGHTING_WINDOW_CHANCE)
					where = o.home_block
			if saw:
				# From home you see the street from your window; out, you see them in passing.
				var how = "street" if o.out_last_night else "window"
				var detail = "leaving_home" if (how == "window" and where == wn.home_block) else "street"
				o.beliefs.append({"kind": "saw", "who": wn.id, "loc": "", "block": where, "day": day, "phase": C.NIGHT, "how": how, "detail": detail})
				dlog.add("night_sighting", o.id, wn.id, {"block": where}, "%s glimpsed %s on %s at night." % [o.name, wn.name, C.block_name(where)])
		if player_vigil != "" and C.vigil_sees_path(player_vigil, path, wn.home_block) and wn.alive:
			player_vigil_seen.append(wn.id)
	# Neighbours at home sometimes notice each other going in for the night and not coming
	# out again: a (true, if weak) alibi for those who stayed in.
	for o in living():
		if o.out_last_night:
			continue
		for m in living():
			if m != o and m.home_block == o.home_block and not m.out_last_night and chance(Tuning.Setup.NIGHT_NEIGHBOUR_ALIBI_CHANCE):
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
	var target_lo: int = maxi(3, int(floor(npcs.size() * Tuning.Setup.TRACE_CAST_BAND_LO)))
	var target_hi: int = maxi(target_lo + 1, int(ceil(npcs.size() * Tuning.Setup.TRACE_CAST_BAND_HI)))
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
	if q_w > 0.0:
		family_options.append({"family": "quarter", "weight": q_w})
	var conn_key: String = "connection:%s:%d" % [v.id, day]
	if not used_keys.has(conn_key) and (actor.home_block == v.home_block or _has_public_bond(actor.id, v.id) or _shared_daytime_loc(actor, v, day)):
		var c_w: float = Tuning.Setup.TRACE_CONNECTION_BASE_WEIGHT * (Tuning.Setup.TRACE_FRESH_FAMILY_WEIGHT if not seen_families.has("connection") else 1.0)
		if c_w > 0.0:
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

## Who hunts tonight: an active Brute (alive, unbroken, not under the Sexton's bell)
## hunts in the Demon's place; otherwise the Demon.
func night_killer():
	var brute = living_with_role("brute")
	if brute != null and C.role_def("brute").is_active_hunter(self, brute):
		return brute
	return demon()

func _kill(v) -> void:
	v.alive = false
	v.death_day = day
	v.death_cause = "demon"
	v.loc = "dead"
	deaths_last_night.append(v.id)
	var killer = night_killer()
	var brute_killed: bool = killer.role == "brute"
	var ev_loc: String = killer.history.get(time_key(day, C.EVENING), "home:" + killer.home_block)
	var true_block: String = loc_block(ev_loc)
	var killer_trace: Dictionary = build_actor_trace(killer, v, 0)
	case_traces.append(killer_trace.duplicate(true))
	var traces: Array = [killer_trace]
	var passer_actor_id: String = ""
	var passers: Array = []
	if brute_killed:
		var brute_second_trace: Dictionary = build_actor_trace(killer, v, 1)
		case_traces.append(brute_second_trace.duplicate(true))
		traces.append(brute_second_trace)
	else:
		passers = night_walkers.filter(func(wk): return wk["id"] != killer.id and wk["id"] != v.id and v.home_block in wk.get("path", [wk["block"]]))
		if not passers.is_empty() and chance(Tuning.Setup.EXTRA_TRACE_CHANCE):
			var wk: Dictionary = pick(passers)
			var passer = by_id[wk["id"]]
			passer_actor_id = passer.id
			var passer_trace: Dictionary = build_actor_trace(passer, v, 1)
			case_traces.append(passer_trace.duplicate(true))
			if chance(0.5):
				traces = [passer_trace, killer_trace]
			else:
				traces = [killer_trace, passer_trace]
	for idx in range(traces.size()):
		traces[idx]["trace_slot"] = idx
		traces[idx]["scene_trace_count"] = traces.size()
		if idx == 1:
			var ptxt: String = str(traces[idx].get("scene_prose", ""))
			if ptxt.begins_with("Near the body, "):
				traces[idx]["scene_prose"] = "A second detail catches your eye: " + ptxt.trim_prefix("Near the body, ")
			elif ptxt.begins_with("Near the body "):
				traces[idx]["scene_prose"] = "A second detail catches your eye: you also notice " + ptxt.trim_prefix("Near the body ")
	var why = "Scene trace (%s / %s) generated from %s." % [killer_trace.trace_family, killer_trace.trace_subtype, killer.name]
	if passer_actor_id != "":
		why += " Extra trace added by passing night-walker %s." % by_id[passer_actor_id].name
	var sid = "scene_" + v.id
	scenes[sid] = {"name": "%s's cottage" % v.name, "block": v.home_block, "victim": v.id, "day": day,
		"trace_block": true_block, "trace_true": true, "traces": traces, "trace": killer_trace,
		"passer_ids": passers.map(func(wk): return wk["id"]), "passer_trace_actor": passer_actor_id,
		"why": why, "searched": false}
	dlog.add("kill", demon_id, v.id, {"role": v.role, "scene": sid, "trace_family": killer_trace.trace_family,
		"trace_subtype": killer_trace.trace_subtype, "trace_key": killer_trace.trace_key,
		"trace_count": traces.size(), "passer_trace_actor": passer_actor_id, "trace_true": true}, why)
	public_event("demon_death", [v.id], "town")
	for n in npcs:
		if not n.alive:
			continue
		var listener = n.shadow if n.is_evil() else n
		if listener == null:
			continue
		Mind.ledger_hear(self, listener, "demon_death:" + v.id, [], 1.0, [], {"kind": "demon_death", "victim": v.id})

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
		entry["why"] = ("poisoned" if (n.poisoned or n.omen_poisoned_day >= 0) else "delusional")
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

func _receive_info(n, watch_block: String, medium_t: String = "", lamp = null, confessor_t: String = "") -> void:
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
	entry = rdef.generate_reading(self, n, {"watch_block": watch_block, "medium_t": medium_t, "lamp": lamp, "confessor_t": confessor_t}, Mind)
	if entry.is_empty():
		return
	if broken:
		entry["why"] = "%s" % ("poisoned" if (n.poisoned or n.omen_poisoned_day >= 0) else "delusional")
	_add_info(n, entry)

static func _secret_phrase(k: String) -> String:
	match k:
		"delusional":
			return "Delusional, their gift a fancy"
		"marked":
			return "Marked, and may read as evil"
	return k

## Whom someone trusts and suspects most. Evil keep their team close and point at their
## scapegoat (or whoever threatens them).
func _psych_read(subj) -> Dictionary:
	var others: Array = living().filter(func(m): return m != subj)
	var trusts = ""
	var suspects = ""
	if subj.is_evil():
		var mates: Array = others.filter(func(m): return m.is_evil())
		if not mates.is_empty() and chance(Tuning.Setup.PSYCH_EVIL_TEAMMATE_TRUST_PROB):
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
func _morning_executor_gifts() -> void:
	var ex_def = C.role_def("executor")
	if ex_def == null:
		return
	var fired = false
	var holder = living_with_role("executor")
	if holder != null:
		fired = ex_def.run_morning_gift(self, holder) or fired
	for n in evil_team():
		fired = ex_def.run_morning_bluff(self, n) or fired
	if fired:
		Mind.update_from_own_info(self)

func _day_gifts() -> void:
	for role_id in ["dowser", "augur", "breathstealer", "revenant"] + C.DAY_DEMONS:
		var holder = living_with_role(role_id)
		if holder != null:
			C.role_def(role_id).run_day_gift(self, holder, Mind, Evil)
	if day >= 1:
		Evil.make_day_fake_info(self)
		Mind.update_from_own_info(self)

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
