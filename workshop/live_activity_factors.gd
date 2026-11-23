## The joint movement factor machinery: list mixing, the sighting contests, the quiet-night
## Warden guards, the Hexer's kills and successions, the scene tables, and the C# factor
## handles (split from `workshop/live_activity.gd`; part of LiveActivity's inheritance chain).
extends "res://workshop/live_activity_pack.gd"
static var _factor_handles: Dictionary = {}
static var _mru_factor = null
static var _mru_handle: int = -1
static var _mru_epoch: int = -1
static var _mru_norm: int = 0

## Diagnostics: turn the Hexer factor off to measure what it adds (tools only).
static var hex_factor_enabled: bool = true
## Diagnostics: turn the sighter contests off (_sighting_contests; tests and tools only).
static var sighter_contests_enabled: bool = true

## The Night Watch lists to mix as sound or broken as a whole (BACKLOG "A Night Watch list
## that wrongly names the listener", Michael, Nov 18): another's report, carrying the chance
## its gift was broken that night ("broken_chance", CaseEval._list_broken).
static func _mixed_lists(view: Dictionary, cards: Array) -> Array:
	var ids: Array = view.people.map(func(p): return p.id)
	# A Lamplighter's count is mixed the same way (Michael, Nov 19, the Lamplighter fix (b),
	# step 1), whatever its broken chance: in a world where its teller is evil it says nothing
	# (CaseEval._list_broken stamps `count_mix`). Lists and counts share one cap.
	var lists: Array = cards.filter(func(c): return c.get("kind", "") == "report" and not c.get("quoted", false) and not c.get("duty_only", false) and ids.has(str(c.get("source", ""))) \
		and ((str(c.get("role", "")) == "nightwatch" and (float(c.get("broken_chance", 0.0)) > 0.0 or not c.get("omen_claimants", []).is_empty())) or (str(c.get("role", "")) == "lamplighter" and c.get("count_mix", false))))
	# At most SourceDoubt.LIST_MIX_MAX carry a broken chance (SourceDoubt.list_broken_chance
	# picks them, so a list left out keeps the old fallback); the cap here is only a guard.
	lists.sort_custom(func(a, b): return int(a.get("night", -1)) > int(b.get("night", -1)) or (int(a.get("night", -1)) == int(b.get("night", -1)) and str(a.id) < str(b.id)))
	return lists.slice(0, 2)

## The movement factor, mixed over each list being sound or broken: in a world where the
## watcher is good, the list is sound (every name at its small error) with chance 1 - b, or
## broken (it says nothing about who walked) with chance b, the watcher's poison and
## Delusional priors; a broken list clears nobody. In a world where the watcher is evil the
## sighting contest already lets it say anything. The kernel weighs the two by fit
## (LiveActivityKernel.ScoreMixed).
static func _factors_cs(view: Dictionary, cards: Array, observations: Array) -> Array:
	return [_list_mix(view, cards, observations, _mixed_lists(view, cards))]

static func _list_mix(view: Dictionary, cards: Array, observations: Array, lists: Array) -> Dictionary:
	if lists.is_empty():
		return _factors_core(view, cards, observations)[0]
	var list: Dictionary = lists[0]
	var rest: Array = lists.slice(1)
	var sound: Dictionary = _list_mix(view, cards, observations, rest)
	# Broken, the list says nothing about who walked, but the watcher still went out to
	# watch that block (sim/world.gd walks it there whatever its gift): a duty-only copy
	# keeps that (Codex on #273).
	var duty: Dictionary = list.duplicate(true)
	duty["duty_only"] = true
	duty.erase("broken_chance")
	var is_count: bool = str(list.get("role", "")) == "lamplighter"
	duty.erase("count_mix")
	# A broken count says nothing about who was out; the Lamplighter still walked its round.
	duty["data"] = {} if is_count else {"block": list.get("data", {}).get("block", ""), "seen": []}
	var broken: Dictionary = _list_mix(view, cards.map(func(c): return duty if c.get("id", "") == list.id else c), observations, rest)
	# (broken_cards below is the same list, for the outsider's scale.)
	var b: float = clampf(float(list.broken_chance), 0.0, 1.0)
	# The kernel scores the broken branch on the sound branch's scale (it divides by the sound
	# branch's good profiles in every component; LiveActivityKernel.SetListNorm, Codex on #273).
	# A broken list says these words as often as an honest one would, from what an outsider
	# could know (the sighting contests' balance, without the listener's own nights):
	# prod outsider good(sound) / prod outsider good(broken). No new number.
	var broken_cards: Array = cards.map(func(c): return duty if c.get("id", "") == list.id else c)
	# Nor a card the listener's own knowledge proves false: a sighting of the listener out on a
	# night it knows it spent at home can't make a count look honest (#506, seed 100100: Lian's
	# false sighting of Constance supplied one of his count's "others", so his lie spoke for him).
	var own: Dictionary = view.get("own_home", {})
	var me_id: String = str(own.get("self", ""))
	var home_nights: Dictionary = own.get("nights", {})
	var out_nights: Dictionary = own.get("out_nights", {})
	var known_false := func(x: Dictionary) -> bool:
		if me_id == "" or str(x.get("kind", "")) != "sighting" or x.get("quoted", false) or not me_id in x.get("subjects", [x.get("subject", "")]):
			return false
		var nk: String = str(int(x.get("night", -1)))
		# Home that night, or out on other blocks than the one it puts me on (gap 2).
		return home_nights.has(nk) or (out_nights.has(nk) and str(x.get("block", "")) not in out_nights[nk])
	var private_free: Callable = func(cs: Array) -> Array: return cs.filter(func(x): return not x.get("known_self", false) and not known_false.call(x))
	var log_scale: float = _log_good_of(view, private_free.call(cards)) - _log_good_of(view, private_free.call(broken_cards))
	# A count that no route mask of the other movement evidence fits makes the sound branch
	# impossible (Lantern, Nov 19): it scores 0, so the count tells against its teller by fit.
	# Only evidence that can't be a lie decides it (Lantern on #346): the count itself, the
	# listener's own nights and sightings, and physical traces. Anyone else's word (an alibi,
	# a sighting, coverage, a report, a claim, the player's included) could be the lie instead,
	# and stays weighed world by world in the sound branch. Deaths and homes come from the view.
	var sound_zero: bool = false
	if is_count:
		var night_key: String = str(int(list.get("night", list.get("observed_at", {}).get("day", -1))))
		var me: String = str(view.get("own_home", {}).get("self", ""))
		var certain: Array = cards.filter(func(c): return certain_for_count(c, str(list.id), me))
		var routes: Dictionary = _routes_cs(view, certain, {}, {}, false)
		sound_zero = routes.get("nights", {}).has(night_key) and int(routes.nights[night_key].get("compatible", 1)) == 0
	var top: Dictionary = sound.duplicate(false)
	# Under a fallen omen, in a world where its claimant truly held Ill-Omened, a good teller's
	# list or count was poisoned outright (the kernel takes the broken branch; Codex on #547).
	var omen: int = preload("res://workshop/role_constraints.gd").omen_mask(view.people.map(func(p): return p.id), list)
	top["list_mix"] = {"watcher": view.people.map(func(p): return p.id).find(str(list.source)), "broken": b, "scale": exp(log_scale), "cursed": _told_cursed(view.get("chronology", {}).get("curse", {}), list), "next": sound, "alt": broken,
		"count": is_count, "sound_zero": sound_zero, "omen": omen,
		"key": "%s:%s:%s:%s:%s:%s:%s|%s|%s" % [list.id, b, log_scale, _told_cursed(view.get("chronology", {}).get("curse", {}), list), is_count, sound_zero, omen, sound.get("list_mix", {}).get("key", ""), broken.get("list_mix", {}).get("key", "")]}
	return top

## Whether a movement card is certain enough to rule a Lamplighter's count impossible (see
## _list_mix): the count itself, the listener's (me) own nights and own sightings, or a trace
## seen for itself, not someone's report of it. Anyone else's word can be a lie.
static func certain_for_count(c: Dictionary, count_id: String, me: String) -> bool:
	if str(c.get("id", "")) == count_id:
		return true
	if bool(c.get("known_self", false)):
		# A night the listener knows it spent at home, unless it may have sleepwalked (Lantern
		# on #346): only the tiny own-reading error, not a Sleepwalker's self-doubt.
		return float(c.get("self_doubt", 0.0)) <= Tuning.Workshop.OWN_ERR
	if bool(c.get("quoted", false)) or c.has("relay_source"):
		return false
	match str(c.get("kind", "")):
		"sighting":
			return me != "" and str(c.get("source", "")) == me
		"trace":
			return true
	return false

## Sum of log good profiles of a card list's plain profiles (no contests or guards: they don't
## touch the good column), with the outings it forces.
static func _log_good_of(view: Dictionary, cards: Array) -> float:
	var checked: Array = cards.duplicate()
	var movement: Dictionary = _routes_cs(view, cards, {}, {}, false)
	for night in movement.nights:
		for person in movement.nights[night].forced_out:
			checked.append({"id": "inferred-out:%s:%s" % [person, night], "kind": "sighting", "source": "evidence", "subject": person, "subjects": [person], "block": "", "night": int(night)})
	var ids: Array = view.people.map(func(p): return p.id)
	var env: Dictionary = _pack_view_env(view, ids)
	var packed: Dictionary = _pack_activity_cards(ids, env.homes, checked, {}, {}, view.get("chronology", {}).get("curse", {}))
	var raw: PackedFloat64Array = SolverBackend._bridge().LiveAllProfiles(env.has_curse, env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
		packed.ints, packed.doubles)
	var stride: int = 4 if env.has_curse else 3
	var out: float = 0.0
	for i in range(ids.size()):
		out += log(maxf(raw[i * stride], 1e-30))
	return out

static func _factors_core(view: Dictionary, cards: Array, observations: Array) -> Array:
	var checked: Array = cards.duplicate()
	var movement: Dictionary = _routes_cs(view, cards, {}, {}, false)
	for night in movement.nights:
		for person in movement.nights[night].forced_out:
			checked.append({"id": "inferred-out:%s:%s" % [person, night], "kind": "sighting", "source": "evidence", "subject": person, "subjects": [person], "block": "", "night": int(night)})

	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var ids: Array = view.people.map(func(p): return p.id)
	var env: Dictionary = _pack_view_env(view, ids)
	var role_tok_map: Dictionary = {}
	var packed_checked: Dictionary = _pack_activity_cards(ids, env.homes, checked, {}, role_tok_map, view.get("chronology", {}).get("curse", {}))
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity.factors_profiles", pack_u)

	var has_curse: bool = env.has_curse
	var bridge = SolverBackend._bridge()
	var raw_prof: PackedFloat64Array = bridge.LiveAllProfiles(
		has_curse, env.homes, env.deaths, env.demon_events, has_curse, env.curse_from, env.curse_until,
		packed_checked.ints, packed_checked.doubles
	)
	var n: int = ids.size()
	var share: float = day_demon_share(view)
	var stride: int = 4 if has_curse else 3
	var profiles: Array = []
	profiles.resize(n)
	for i in range(n):
		var b: int = i * stride
		var p_dict: Dictionary = {
			"good": raw_prof[b],
			"minion": raw_prof[b + 1],
			# Walking always: with a Hexer possible, C# mixes whole-world scores (ScoreWorldCore).
			"demon": raw_prof[b + 2],
		}
		if has_curse:
			p_dict["converted"] = raw_prof[b + 3]
		profiles[i] = p_dict
	if deals_unrequited(view):
		# A good Unrequited holder's own column (burdens prototype): the kernel uses it in the
		# worlds where they hold it (LiveActivityKernel.UnrequitedHolder).
		var raw_u: PackedFloat64Array = bridge.LiveUnrequitedProfiles(Tuning.Burden.UNREQUITED_VISIT_CHANCE, env.homes, env.deaths, env.demon_events,
			packed_checked.ints, packed_checked.doubles)
		for i in range(n):
			profiles[i]["unrequited"] = raw_u[i]

	var guards: Dictionary = _quiet_guards(view, ids, env, cards, packed_checked, stride) if quiet_guards_enabled else {}
	var contests: Array = _sighting_contests(view, ids, env, cards, checked, profiles, guards.get("items", [])) if sighter_contests_enabled else []
	var scene_tables: Array = _build_scene_tables_cs(view, ids, env, checked, packed_checked)
	var scion_splits: Array = _scion_succession_splits_cs(view, ids, env, checked, guards.get("items", []))
	var result: Array = [{"origin": "movement_model", "joint_live": true, "target": "", "log2_ratio": 1.0,
		"label": "Movement / trace: joint live comparison", "profiles": profiles, "scene_tables": scene_tables, "scion_splits": scion_splits,
		"cards": observations.map(func(c): return c.id), "note": "One joint comparison; persistent activity and evening habits. Unknown passers remain possible. Activity rates and background contamination are experimental priors, not calibrated guilt probabilities."}]
	result[0]["relationships"] = relationships(view, cards)
	if not contests.is_empty():
		result[0]["contests"] = contests
		result[0]["contest_truth"] = Tuning.Workshop.EVIL_SIGHTER_TRUTH
	if not guards.is_empty():
		result[0]["guards"] = guards
	if share > 0.0:
		# The Scion's before/after splits keep walking demon profiles; C# mixes each split's
		# pre x post product over the one shared type (see ScoreWorldCore).
		result[0]["day_demon_share"] = share
		result[0]["hex_kills"] = hex_kills(view, cards, ids) if hex_factor_enabled else []
		result[0]["hex_floor"] = Tuning.Workshop.HEX_UNKNOWN_FLOOR
		result[0]["hex_successions"] = hex_successions(view, ids, result[0]["hex_kills"])
	return result


## Diagnostics: turn the quiet-night Warden guards off (_quiet_guards; tests and tools only).
static var quiet_guards_enabled: bool = true
## Warden report ids whose guard is left out (the Test juror's leave-one-out,
## WorkshopCanvas.guard_reasons). The factor and compiled-case keys carry it.
static var quiet_guards_skip: Array = []
## At most this many guards, the latest nights first: the Demon's profile is computed for
## every subset of them.
const QUIET_GUARD_MAX = 3

## A Warden's guard of a door on a night the Demon killed nobody (BACKLOG "Quiet-night
## evidence argued by the player"; DESIGN "Warden saves"). Where the Warden and the guarded
## person are both good, the quiet is the guard holding, so the Demon walked to that door:
## the same route reasoning as a player's held ward (the scorched sigil), at the reliability
## of a Warden's claimed save, shared with any other living Veteran claimant who could have
## turned the Demon instead (1 / (1 + Veteran claims), as the Warden's own belief). The
## kernel mixes the Demon's profile over which guards held (GuardedDemon). Returns
## {"items": [{source, target, night, r}], "alt": [the demon profile per subset]}, or {}.
## The guards in a card list that the route reads, as ids: {report (card id), source,
## target, night, saved, r}. r is scaled by the card's "route_trust", the listener's trust
## in the reading (CaseEval._route_trusted).
static func quiet_guard_cards(view: Dictionary, cards: Array) -> Array:
	var ids: Array = view.people.map(func(p): return p.id)
	var d_map: Dictionary = view.get("timeline", {}).get("deaths", {})
	var busy: Dictionary = {}
	for ev in view.get("timeline", {}).get("events", []):
		if ev.get("kind", "") in ["demon_death", "demon_attack"]:
			busy[int(ev.get("at", {}).get("day", -1))] = true
	var vets: Array = []
	for card in cards:
		if card.get("kind", "") in ["claim", "report"] and str(card.get("role", "")) == "veteran" and not card.get("quoted", false) and str(card.get("source", "")) in ids and str(card.source) not in vets:
			vets.append(str(card.source))
	var out: Array = []
	var seen: Dictionary = {}
	for card in cards:
		if card.get("kind", "") != "report" or str(card.get("role", "")) != "warden" or card.get("quoted", false) or card.has("relay_source") or card.get("duty_only", false):
			continue
		var night: int = int(card.get("night", -1))
		var src: String = str(card.get("source", ""))
		var data = card.get("data", {})
		var tgt: String = str(data.get("target", "")) if data is Dictionary else ""
		if night < 1 or src not in ids or tgt not in ids or src == tgt or busy.has(night) or night >= int(d_map.get(src, 2147483647)) or night >= int(d_map.get(tgt, 2147483647)):
			continue
		var key: String = "%s:%d" % [src, night]
		if seen.has(key):
			continue
		seen[key] = true
		var others: int = vets.filter(func(v): return v != src and night < int(d_map.get(v, 2147483647))).size()
		out.append({"report": str(card.get("id", "")), "source": src, "target": tgt, "night": night, "saved": bool(data.get("saved", false)),
			"r": Tuning.Roles.WARDEN_SAVE_RELIABILITY / (1.0 + others) * clampf(float(card.get("route_trust", 1.0)), 0.0, 1.0)})
	out.sort_custom(func(x, y): return x.night > y.night or (x.night == y.night and x.source < y.source))
	# The cap first, then the skip: leaving one guard out mustn't let a capped-out one in
	# (Codex on #243).
	return out.slice(0, QUIET_GUARD_MAX).filter(func(g): return g.report not in quiet_guards_skip)

static func _quiet_guards(view: Dictionary, ids: Array, env: Dictionary, cards: Array, packed: Dictionary, stride: int) -> Dictionary:
	var items: Array = quiet_guard_cards(view, cards).map(func(g): return {"source": ids.find(g.source), "target": ids.find(g.target), "night": g.night, "r": g.r})
	if items.is_empty():
		return {}
	return {"items": items, "alt": _guard_alt(items, env, packed, env.has_curse, stride),
		"curse": {"on": env.has_curse, "from": env.curse_from, "until": env.curse_until}}

## The demon profile of each person with the attacks of each non-empty subset of the guards.
static func _guard_alt(items: Array, env: Dictionary, packed: Dictionary, include_converted: bool, stride: int) -> Array:
	var n: int = env.homes.size()
	var alt: Array = []
	var bridge = SolverBackend._bridge()
	for sub in range(1, 1 << items.size()):
		var ev_sub := PackedInt32Array(env.demon_events)
		for j in range(items.size()):
			if sub & (1 << j):
				ev_sub.append(int(items[j].night))
				ev_sub.append(int(items[j].target))
		var raw: PackedFloat64Array = bridge.LiveAllProfiles(
			include_converted, env.homes, env.deaths, ev_sub, env.has_curse, env.curse_from, env.curse_until,
			packed.ints, packed.doubles)
		var col: Array = []
		for i in range(n):
			col.append(raw[i * stride + 2])
		alt.append(col)
	return alt


## The sighters whose word about a person depends on the sighter's alignment: anyone in the
## town who told a sighting of them (or a Night Watch report seeing them). In a world where
## the sighter is evil the sighting may be invented, so the kernel (BaseScore) mixes the
## person's usual profile with their profile without those sightings, scaled by C: the
## honest sightings' prior-weighted mean likelihood ratio, so an invented sighting is as
## likely as an honest one on average and the priors decide. Without this, a sighting
## against a person's own home alibi convicted the alibi-giver alone (Tally, Nov 11: evil's
## fake sightings of good stay-at-homes). At most SIGHTER_CONTEST_MAX sighters a person,
## the most-cited first. The Scion's split branches keep their usual profiles.
static func _sighting_contests(view: Dictionary, ids: Array, env: Dictionary, cards: Array, checked: Array, profiles: Array, guard_items: Array = []) -> Array:
	var n: int = ids.size()
	var curse: Dictionary = view.get("chronology", {}).get("curse", {})
	var by_person: Dictionary = {}   # person idx -> {sighter idx: count}
	var cursed_by: Dictionary = {}   # "person:sighter" -> they told some of these while converted
	for c in checked:
		if c.get("quoted", false):
			continue
		# Who might have made it up: the sighter; for a relayed card (a Medium's word from the
		# dead) only the relayer. The dead person never told it: a Medium learns what they
		# knew and never said, firsthand, so the dead can't have invented it, and an evil
		# relayer can. Counting the dead as a teller too let the two-sighter cap drop the
		# relayer, so an invented relay was weighed as the dead's honest word (seeds 929 and
		# 100029; BACKLOG "A relayer cut from the sighter contest", Michael, Nov 18).
		var tellers: Array = []
		var si: int = ids.find(str(c.get("source", "")))
		var ri: int = ids.find(str(c.get("relay_source", ""))) if c.has("relay_source") else -1
		if ri >= 0:
			tellers.append(ri)
		elif si >= 0:
			tellers.append(si)
		if tellers.is_empty():
			continue
		var named: Array = []
		if c.kind == "sighting":
			named = c.get("subjects", [c.get("subject", "")])
		elif c.kind == "alibi" and ri >= 0:
			# A relayed alibi ("the dead told me they were home") is the relayer's word too:
			# an evil relayer can invent it, so in a world where the relayer is evil it says
			# nothing about its subject. Only the relayer is contested; the subject's own
			# word is priced by alignment in _observed.
			named = [c.get("subject", "")]
			tellers = [ri]
		elif c.kind == "report" and str(c.get("role", "")) == "nightwatch" and c.get("data") is Dictionary:
			named = c.data.get("seen", [])
		for who in named:
			var pi: int = ids.find(str(who))
			if pi < 0:
				continue
			for ti in tellers:
				if pi == ti:
					continue
				if not by_person.has(pi):
					by_person[pi] = {}
				by_person[pi][ti] = int(by_person[pi].get(ti, 0)) + 1
				if _told_cursed(curse, c):
					cursed_by["%d:%d" % [pi, ti]] = true
	if by_person.is_empty():
		return []
	var has_curse: bool = env.has_curse
	var stride: int = 4 if has_curse else 3
	var bridge = SolverBackend._bridge()
	var alt_cache: Dictionary = {}   # [full sighters, cursed-only sighter] -> raw profiles
	var guard_cache: Dictionary = {}   # the same key -> the guard subsets' demon columns
	# The balance C is an outsider's: how often an honest sighter would report this, from what
	# anyone could know. The listener's own knowledge of its nights (known_self cards) stays
	# out of it; otherwise knowing a sighting of itself is false would make an honest one
	# impossible, and the invented one with it (Beadle, Nov 17: an evil Medium's
	# invented relay of a home-staying listener counted almost nothing against them).
	var private_ids: Array = cards.filter(func(x): return x.get("known_self", false)).map(func(x): return str(x.get("id", "")))
	var outsider_cache: Dictionary = {}  # same keys, without the known_self cards
	var outsider_with: PackedFloat64Array = PackedFloat64Array()
	if not private_ids.is_empty():
		var outside: Array = checked.filter(func(x): return str(x.get("id", "")) not in private_ids)
		var p_out: Dictionary = _pack_activity_cards(ids, env.homes, outside, {}, {}, view.get("chronology", {}).get("curse", {}))
		outsider_with = SolverBackend._bridge().LiveAllProfiles(env.has_curse, env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
			p_out.ints, p_out.doubles)
	var evil_n: float = float(view.get("evil_count", 1))
	var weights: Array = [maxf(0.0, 1.0 - evil_n / float(n)), maxf(0.0, evil_n - 1.0) / float(n), 1.0 / float(n)]
	# The profile without `full`'s sightings and the ones `cursed` told while converted.
	var alt_of: Callable = func(pi: int, full: Array, cursed: int) -> Dictionary:
		var key: String = str([full, cursed])
		if not alt_cache.has(key):
			var full_ids: Array = full.map(func(x): return ids[x])
			var cursed_id: String = ids[cursed] if cursed >= 0 else ""
			var minus: Array = cards.filter(func(c):
				var src: String = str(c.get("source", ""))
				var rel: String = str(c.get("relay_source", "~"))
				var movement: bool = c.kind == "sighting" or (c.kind == "report" and str(c.get("role", "")) == "nightwatch")
				if c.kind == "alibi" and c.has("relay_source") and not c.get("quoted", false):
					return not (rel in full_ids or (rel == cursed_id and _told_cursed(curse, c)))
				return not (movement and (src in full_ids or rel in full_ids or ((src == cursed_id or rel == cursed_id) and _told_cursed(curse, c)))))
			# Forced outings re-inferred from what's left.
			var mv: Dictionary = _routes_cs(view, minus, {}, {}, false)
			for night in mv.nights:
				for person in mv.nights[night].forced_out:
					minus.append({"id": "inferred-out:%s:%s" % [person, night], "kind": "sighting", "source": "evidence", "subject": person, "subjects": [person], "block": "", "night": int(night)})
			var packed: Dictionary = _pack_activity_cards(ids, env.homes, minus, {}, {}, view.get("chronology", {}).get("curse", {}))
			alt_cache[key] = bridge.LiveAllProfiles(
				has_curse, env.homes, env.deaths, env.demon_events, has_curse, env.curse_from, env.curse_until,
				packed.ints, packed.doubles)
			# With quiet-night guards, the same alternative with each guard subset's attacks
			# (Codex on #243): removing a witness's sightings keeps the guards' evidence.
			if not guard_items.is_empty():
				guard_cache[key] = _guard_alt(guard_items, env, packed, has_curse, stride)
			if not private_ids.is_empty():
				var minus_out: Array = minus.filter(func(x): return str(x.get("id", "")) not in private_ids)
				var packed_out: Dictionary = _pack_activity_cards(ids, env.homes, minus_out, {}, {}, view.get("chronology", {}).get("curse", {}))
				outsider_cache[key] = bridge.LiveAllProfiles(
					has_curse, env.homes, env.deaths, env.demon_events, has_curse, env.curse_from, env.curse_until,
					packed_out.ints, packed_out.doubles)
		var raw: PackedFloat64Array = alt_cache[key]
		var b: int = pi * stride
		var alt: Array = [raw[b], raw[b + 1], raw[b + 2], raw[b + 3] if has_curse else 0.0]
		var with_: Array = [float(profiles[pi].good), float(profiles[pi].minion), float(profiles[pi].demon)]
		var with_c: Array = with_
		var alt_c: Array = alt
		if not private_ids.is_empty():
			var raw_o: PackedFloat64Array = outsider_cache[key]
			with_c = [outsider_with[b], outsider_with[b + 1], outsider_with[b + 2]]
			alt_c = [raw_o[b], raw_o[b + 1], raw_o[b + 2]]
		var c: float = 0.0
		for a in range(3):
			c += weights[a] * (with_c[a] / alt_c[a] if alt_c[a] > 1e-30 else 1.0)
		var out_sub: Dictionary = {"alt": alt, "c": c}
		if guard_cache.has(key):
			out_sub["guard_alt"] = guard_cache[key].map(func(col): return col[pi])
		return out_sub
	var out: Array = []
	var persons: Array = by_person.keys()
	persons.sort()
	for pi in persons:
		var counts: Dictionary = by_person[pi]
		var sighters: Array = counts.keys()
		sighters.sort_custom(func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and a < b))
		sighters = sighters.slice(0, Tuning.Workshop.SIGHTER_CONTEST_MAX)
		var k: int = sighters.size()
		var subsets: Array = []
		for m in range(1, 1 << k):
			var full: Array = []
			for j in range(k):
				if m & (1 << j):
					full.append(sighters[j])
			full.sort()
			subsets.append(alt_of.call(pi, full, -1))
		# A sighter the curse converted is evil only for what they told while converted
		# (Chronology.statement_time against the curse window): in a world where they are the
		# converted person, only those sightings are removed.
		var conv: Array = []
		for j in range(k):
			if not cursed_by.has("%d:%d" % [pi, sighters[j]]):
				conv.append([])
				continue
			var per: Array = []
			for m in range(1, 1 << k):
				if not (m & (1 << j)):
					continue
				var full: Array = []
				for jj in range(k):
					if jj != j and m & (1 << jj):
						full.append(sighters[jj])
				full.sort()
				per.append(alt_of.call(pi, full, sighters[j]))
			conv.append(per)
		out.append({"person": pi, "sighters": sighters, "subsets": subsets, "converted": conv})
	return out


static func _told_cursed(curse: Dictionary, card: Dictionary) -> bool:
	if curse.is_empty():
		return false
	var time: int = Chronology.tick(Chronology.statement_time(card))
	return time >= int(curse.get("from", 0)) and time < int(curse.get("until", 0))


## The Hexer's side of each demon kill or attack (docs/demon_types_plan.md, step 3): the
## victim's known regular places (work and learned haunts), who were regulars of each that
## day, and each person's chance of having hexed each place that day. The chance comes from
## the presence table (DayPresence), weighted by when a Hexer tends to strike (Tuning HEXER)
## and normalized over the public places they were likely in, since the hex falls where the
## Hexer stands. C#'s HexFactor turns this into a per-world likelihood.
static func hex_kills(view: Dictionary, cards: Array, ids: Array) -> Array:
	var events: Array = view.get("timeline", {}).get("events", []).filter(func(e): return e.get("kind", "") in ["demon_death", "demon_attack"] and int(e.get("at", {}).get("day", 0)) >= 1)
	if events.is_empty():
		return []
	var table: Dictionary = DayPresence.build(view, cards)
	var hx: Dictionary = Tuning.Roles.HEXER
	var q: Array = hx.phase_probs
	var w: Array = [float(q[0]), (1.0 - float(q[0])) * float(q[1]), (1.0 - float(q[0])) * (1.0 - float(q[1])) * maxf(float(q[2]), float(hx.evening_floor))]
	var wsum: float = w[0] + w[1] + w[2]
	var work: Dictionary = {}
	var haunts: Dictionary = {}
	var shifts: Dictionary = {}   # id -> work phases (public)
	for p in view.get("people", []):
		if str(p.get("work", "")) != "":
			work[p.id] = str(p.work)
		shifts[p.id] = p.get("work_phases", []).map(func(x): return int(x))
	for c in cards:
		if c.get("kind", "") != "context":
			continue
		var subj: String = str(c.get("subject", ""))
		if c.get("context_kind", "") == "work" and str(c.get("data", {}).get("loc", "")) != "":
			work[subj] = str(c.data.loc)
		elif c.get("context_kind", "") == "haunt":
			var known: Array = haunts.get(subj, [])
			for l in c.get("data", {}).get("locs", []):
				if l in DayPresence.PLACES and l not in known:
					known.append(l)
			haunts[subj] = known
	var regular: Dictionary = view.get("regular_haunts", {})
	for subj in regular:
		var known: Array = haunts.get(subj, [])
		for l in regular[subj]:
			if l in DayPresence.PLACES and l not in known:
				known.append(l)
		haunts[subj] = known
	var excluded: Dictionary = DayPresence.exclusions(view, cards)
	var out: Array = []
	var seen: Dictionary = {}
	for e in events:
		var victim: String = str(e.get("subjects", [""])[0]) if not e.get("subjects", []).is_empty() else ""
		var night: int = int(e.at.day)
		if victim == "" or seen.has("%d:%s" % [night, victim]):
			continue  # (the timeline can carry an event twice)
		seen["%d:%s" % [night, victim]] = true
		var stamp: Dictionary = {"day": night, "phase": "evening"}
		var alive_mask: int = 0
		for i in range(ids.size()):
			if History.observer_alive(view, ids[i], stamp):
				alive_mask |= 1 << i
		var places: Array = []
		if work.has(victim):
			places.append(work[victim])
		for l in haunts.get(victim, []):
			if l not in places:
				places.append(l)
		var reg_masks: Array = []
		var shares: Array = []
		for l in places:
			var mask: int = 0
			for i in range(ids.size()):
				if work.get(ids[i], "") == l or l in haunts.get(ids[i], []):
					mask |= 1 << i
			reg_masks.append(mask)
			var row: Array = []
			for i in range(ids.size()):
				# The Hexer is wary of hexing its own workplace (Tuning HEXER.own_work_penalty),
				# so time spent there counts for less, in the place and in the total.
				var own: String = work.get(ids[i], "")
				var at_l: float = 0.0
				var public_mass: float = 0.0
				for p in range(3):
					# A Hexer may seek out a target at work in its own free time (sim HEXER
					# seek_target_chance): when the victim worked here this phase and this
					# person was free and not seen elsewhere, some of their time goes here.
					var seek: float = 0.0
					if l == work.get(victim, "") and p in shifts.get(victim, []) and not (p in shifts.get(ids[i], [])):
						var best_p: float = 0.0
						for pl2 in DayPresence.PLACES + ["home"]:
							best_p = maxf(best_p, DayPresence.at(table, ids[i], night, p, pl2))
						# Not if the watch record puts them off that block then (#125 review).
						var ruled_out: bool = excluded.has("%s:%d:%d:%s" % [ids[i], night, p, C.loc_block(l)])
						if best_p < 0.999 and not ruled_out:
							seek = Tuning.Workshop.HEX_SEEK_SHARE
					for pl in DayPresence.PLACES:
						var a: float = DayPresence.at(table, ids[i], night, p, pl) * (Tuning.Workshop.HEX_OWN_WORK_WEIGHT if pl == own else 1.0)
						a = (1.0 - seek) * a + (seek if pl == l else 0.0)
						public_mass += w[p] / wsum * a
						if pl == l:
							at_l += w[p] / wsum * a
				row.append(at_l / public_mass if public_mass > 0.0 else 0.0)
			shares.append(row)
		out.append({"night": night, "victim": victim, "places": places, "alive_mask": alive_mask, "reg_masks": reg_masks, "shares": shares})
	return out


## Executions that could be a Scion succession for the Hexer factor: in such a world the
## kills before the execution were the executed demon's hexes, not the successor's, so C#
## scores those against the executed person (HexFactor's succession branch). Mirrors the
## movement splits' gate (_scion_succession_splits_cs) on crowd size, but needs only a hex
## kill before the execution rather than a movement card.
static func hex_successions(view: Dictionary, ids: Array, kills: Array) -> Array:
	var out: Array = []
	var execs: Dictionary = view.get("timeline", {}).get("executions", {})
	if execs.is_empty() or kills.is_empty():
		return out
	var deaths: Dictionary = view.get("timeline", {}).get("deaths", {})
	var ticks: Dictionary = view.get("timeline", {}).get("death_ticks", {})
	for day_str in execs:
		var exec_day: int = int(day_str)
		if not kills.any(func(k): return int(k.night) < exec_day):
			continue
		var alive_before: int = 0
		for p in view.people:
			if ticks.get(p.id, 2147483647) >= exec_day * 4 + 2:
				alive_before += 1
		if alive_before < 5:
			continue
		var alive_mask: int = 0
		for i in range(ids.size()):
			if exec_day < int(deaths.get(ids[i], 2147483647)):
				alive_mask |= 1 << i
		for exec_id in execs[day_str]:
			var idx: int = ids.find(exec_id)
			if idx >= 0:
				out.append({"exec_day": exec_day, "executed_idx": idx, "alive_demon_mask": alive_mask})
	return out

static func _append_scene_packed(n: int, st: Dictionary, meta_ints: PackedInt32Array, meta_doubles: PackedFloat64Array) -> void:
	var two_c: bool = bool(st.get("two_cited", false))
	var cg: Array = st.get("cross_good", [])
	var cm: Array = st.get("cross_minion", [])
	var cc: Array = st.get("cross_converted", [])
	var has_cross: bool = cg.size() == n and cm.size() == n
	var has_cc: bool = has_cross and cc.size() == n
	meta_ints.append(int(st.get("victim_idx", -1)))
	meta_ints.append(int(st.get("scene_trace_count", 1)))
	meta_ints.append(1 if two_c else 0)
	meta_ints.append(1 if has_cross else 0)
	meta_ints.append(1 if has_cc else 0)
	for v in st.get("w1", []):
		meta_doubles.append(float(v))
	if two_c:
		for v in st.get("w2", []):
			meta_doubles.append(float(v))
	if has_cross:
		for v in cg:
			meta_doubles.append(float(v))
		for v in cm:
			meta_doubles.append(float(v))
		if has_cc:
			for v in cc:
				meta_doubles.append(float(v))

## `norm`: the scale the kernel scores this factor on, when it is the broken branch of a
## mixed list or count, or sits under one (0: its own). AttachListMix's SetListNorm writes the
## sound branch's scale into the broken branch's compiled factor and everything under it, so
## a handle is shared only between uses on the same scale. Before Nov 19 the handle was keyed
## by content alone: a broken branch identical to a factor used on its own (a broken
## Lamplighter count says nothing, so its branch is the case's factor without the count)
## rewrote that factor's scale, and whichever mix attached last decided how it scored, so
## beliefs depended on judgement order and the caches changed them (Lantern, Nov 19; Quill's
## seed-900 cache parity). Correctness, not speed.
static func _ensure_factor_handle(factor: Dictionary, norm: int = 0) -> int:
	var bridge = SolverBackend._bridge()
	var epoch: int = int(bridge.GetContextEpoch())
	if _mru_epoch == epoch and _mru_factor != null and is_same(_mru_factor, factor) and _mru_norm == norm:
		return _mru_handle
	if _mru_epoch != epoch:
		_factor_handles.clear()
		_mru_epoch = epoch
	var day_share: float = float(factor.get("day_demon_share", 0.0))
	var mix_key: String = str(factor.get("list_mix", {}).get("key", ""))
	var fkey: int = hash([factor.get("profiles", []), factor.get("scene_tables", []), factor.get("scion_splits", []), factor.get("contests", []), factor.get("guards", {}), mix_key]) if day_share <= 0.0 \
		else hash([factor.get("profiles", []), factor.get("scene_tables", []), factor.get("scion_splits", []), day_share, factor.get("hex_kills", []), factor.get("hex_successions", []), factor.get("contests", []), factor.get("guards", {}), mix_key])
	# Its own scale: what a broken branch under it is normed to (unless an outer mix norms
	# this one, whose scale then reaches everything under it: SetListNorm runs outermost last).
	var own_scale: int = fkey
	if norm != 0:
		fkey = hash([fkey, norm])
	if _factor_handles.has(fkey):
		var hit: Dictionary = _factor_handles[fkey]
		if hit.factor == factor and int(hit.get("norm", 0)) == norm:
			_mru_factor = factor
			_mru_handle = int(hit.handle)
			_mru_norm = norm
			return _mru_handle

	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var profs: Array = factor.get("profiles", [])
	var n: int = profs.size()
	var has_conv: bool = n > 0 and profs[0].has("converted")
	var has_unreq: bool = n > 0 and profs[0].has("unrequited")
	var scenes: Array = factor.get("scene_tables", [])
	var splits: Array = factor.get("scion_splits", [])

	var meta_ints := PackedInt32Array([
		n,
		(1 if has_conv else 0) | (2 if has_unreq else 0),
		scenes.size(),
		splits.size(),
	])
	var meta_doubles := PackedFloat64Array([
		Tuning.Setup.TRACE_PASSER_PRIOR_FLOOR,
		Tuning.Setup.TRACE_UNKNOWN_WEIGHT,
	])

	for i in range(n):
		meta_doubles.append(float(profs[i].good))
	for i in range(n):
		meta_doubles.append(float(profs[i].minion))
	for i in range(n):
		meta_doubles.append(float(profs[i].demon))
	if has_conv:
		for i in range(n):
			meta_doubles.append(float(profs[i].converted))
	if has_unreq:
		for i in range(n):
			meta_doubles.append(float(profs[i].unrequited))

	for st in scenes:
		_append_scene_packed(n, st, meta_ints, meta_doubles)

	for sp in splits:
		var pre_sc: Array = sp.get("pre_scenes", [])
		var post_sc: Array = sp.get("post_scenes", [])
		meta_ints.append(int(sp.executed_idx))
		meta_ints.append(int(sp.alive_demon_mask))
		meta_ints.append(pre_sc.size())
		meta_ints.append(post_sc.size())
		for i in range(n):
			meta_doubles.append(float(sp.pre_profiles[i].good))
		for i in range(n):
			meta_doubles.append(float(sp.pre_profiles[i].minion))
		for i in range(n):
			meta_doubles.append(float(sp.pre_profiles[i].demon))
		for i in range(n):
			meta_doubles.append(float(sp.post_profiles[i].good))
		for i in range(n):
			meta_doubles.append(float(sp.post_profiles[i].minion))
		for i in range(n):
			meta_doubles.append(float(sp.post_profiles[i].demon))
		for st in pre_sc:
			_append_scene_packed(n, st, meta_ints, meta_doubles)
		for st in post_sc:
			_append_scene_packed(n, st, meta_ints, meta_doubles)
	if day_share > 0.0:
		# Trailing, so a share of 0 packs exactly as before.
		meta_doubles.append(day_share)
		# Then the Hexer's kills (LiveActivityKernel.HexFactor).
		var hks: Array = factor.get("hex_kills", [])
		meta_ints.append(hks.size())
		meta_doubles.append(float(factor.get("hex_floor", 0.0)))
		for hk in hks:
			meta_ints.append(hk.places.size())
			meta_ints.append(int(hk.alive_mask))
			meta_ints.append(int(hk.get("night", 0)))
			for pi in range(hk.places.size()):
				meta_ints.append(int(hk.reg_masks[pi]))
				for v in hk.shares[pi]:
					meta_doubles.append(float(v))
		# Then the possible successions: [S, (executed, exec day, alive mask) x S].
		var succ: Array = factor.get("hex_successions", [])
		meta_ints.append(succ.size())
		for sc in succ:
			meta_ints.append(int(sc.executed_idx))
			meta_ints.append(int(sc.exec_day))
			meta_ints.append(int(sc.alive_demon_mask))

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity.register_factor", pack_u)
	var h: int = int(bridge.LiveRegisterMovementFactor(meta_ints, meta_doubles))
	var contests: Array = factor.get("contests", [])
	if not contests.is_empty():
		var c_ints := PackedInt32Array([contests.size()])
		var c_doubles := PackedFloat64Array([float(factor.get("contest_truth", 1.0))])
		for ct in contests:
			c_ints.append(int(ct.person))
			c_ints.append(ct.sighters.size())
			for s in ct.sighters:
				c_ints.append(int(s))
			for sub in ct.subsets:
				for v in sub.alt:
					c_doubles.append(float(v))
				c_doubles.append(float(sub.c))
			for per in ct.get("converted", []):
				c_ints.append(0 if per.is_empty() else 1)
				for sub in per:
					for v in sub.alt:
						c_doubles.append(float(v))
					c_doubles.append(float(sub.c))
		bridge.LiveAttachContests(h, c_ints, c_doubles)
	var guards: Dictionary = factor.get("guards", {})
	if not guards.is_empty():
		var g_ints := PackedInt32Array([guards.items.size()])
		var g_doubles := PackedFloat64Array()
		for item in guards.items:
			g_ints.append(int(item.source))
			g_ints.append(int(item.target))
			g_ints.append(int(item.night))
			g_doubles.append(float(item.r))
		for col in guards.alt:
			for v in col:
				g_doubles.append(float(v))
		for sp in factor.get("scion_splits", []):
			for side in ["pre_guard_alt", "post_guard_alt"]:
				for col in sp.get(side, []):
					for v in col:
						g_doubles.append(float(v))
		# The contested sightings' guarded alternatives, in person order as AttachContests
		# stored them: per subset, then per converted sighter's subsets.
		var by_p: Array = factor.get("contests", []).duplicate()
		by_p.sort_custom(func(x, y): return int(x.person) < int(y.person))
		for ct in by_p:
			for sub in ct.subsets:
				for v in sub.get("guard_alt", []):
					g_doubles.append(float(v))
			for per in ct.get("converted", []):
				for sub in per:
					for v in sub.get("guard_alt", []):
						g_doubles.append(float(v))
		var curse: Dictionary = guards.get("curse", {})
		g_ints.append(1 if curse.get("on", false) else 0)
		g_ints.append(int(curse.get("from", 0)))
		g_ints.append(int(curse.get("until", 0)))
		bridge.LiveAttachGuards(h, g_ints, g_doubles)
	var mix: Dictionary = factor.get("list_mix", {})
	if not mix.is_empty():
		# The sound branch keeps this factor's scale; the broken branch takes the sound
		# branch's (SetListNorm), or an outer mix's when this factor is itself normed.
		var next_h: int = _ensure_factor_handle(mix.next, norm)
		var alt_h: int = _ensure_factor_handle(mix.alt, norm if norm != 0 else own_scale)
		if mix.get("count", false):
			bridge.LiveAttachCountMix(h, int(mix.watcher), float(mix.broken), float(mix.get("scale", 1.0)), bool(mix.get("cursed", false)), next_h, alt_h, bool(mix.get("sound_zero", false)), int(mix.get("omen", 0)))
		else:
			bridge.LiveAttachListMix(h, int(mix.watcher), float(mix.broken), float(mix.get("scale", 1.0)), bool(mix.get("cursed", false)), next_h, alt_h, int(mix.get("omen", 0)))
	if _factor_handles.size() >= 2048:
		_factor_handles.clear()
	_factor_handles[fkey] = {"factor": factor, "handle": h, "norm": norm}
	_mru_factor = factor
	_mru_handle = h
	_mru_norm = norm
	return h

static func _scion_succession_splits_cs(view: Dictionary, ids: Array, env: Dictionary, cards: Array, guard_items: Array = []) -> Array:
	var out: Array = []
	var execs: Dictionary = view.get("timeline", {}).get("executions", {})
	if execs.is_empty():
		return out
	var nights: Array = []
	for c in relevant(cards):
		if c.get("night", -1) >= 0 and c.night not in nights:
			nights.append(c.night)
	if nights.is_empty():
		return out
	var bridge = SolverBackend._bridge()
	var n: int = ids.size()
	for day_str in execs:
		var exec_day: int = int(day_str)
		if not nights.any(func(ng): return ng < exec_day):
			continue
		var alive_before: int = 0
		for p in view.people:
			if view.get("timeline", {}).get("death_ticks", {}).get(p.id, 2147483647) >= exec_day * 4 + 2:
				alive_before += 1
		if alive_before < 5:
			continue
		var pre_cards: Array = cards.filter(func(c): return c.get("night", -1) < 0 or c.night < exec_day)
		var post_cards: Array = cards.filter(func(c): return c.get("night", -1) < 0 or c.night >= exec_day)
		var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
		var rmap_pre: Dictionary = {}
		var rmap_post: Dictionary = {}
		var p_pre: Dictionary = _pack_activity_cards(ids, env.homes, pre_cards, {}, rmap_pre, view.get("chronology", {}).get("curse", {}))
		var p_post: Dictionary = _pack_activity_cards(ids, env.homes, post_cards, {}, rmap_post, view.get("chronology", {}).get("curse", {}))
		var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
		SolverBackend.record_boundary_call("LiveActivity.scion_split_profiles", pack_u)

		var raw_pre: PackedFloat64Array = bridge.LiveAllProfiles(
			false, env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
			p_pre.ints, p_pre.doubles
		)
		var raw_post: PackedFloat64Array = bridge.LiveAllProfiles(
			false, env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
			p_post.ints, p_post.doubles
		)
		var pre_profiles: Array = []
		var post_profiles: Array = []
		pre_profiles.resize(n)
		post_profiles.resize(n)
		var alive_mask: int = 0
		for i in range(n):
			if exec_day < env.deaths[i]:
				alive_mask |= (1 << i)
			var b: int = i * 3
			pre_profiles[i] = {"good": raw_pre[b], "minion": raw_pre[b + 1], "demon": raw_pre[b + 2]}
			post_profiles[i] = {"good": raw_post[b], "minion": raw_post[b + 1], "demon": raw_post[b + 2]}
		var pre_scenes: Array = _build_scene_tables_cs(view, ids, env, pre_cards, p_pre)
		var post_scenes: Array = _build_scene_tables_cs(view, ids, env, post_cards, p_post)
		# The quiet-night guards on each side (Codex on #243): the same subsets as the direct
		# branch, against each side's own cards.
		var pre_guard_alt: Array = _guard_alt(guard_items, env, p_pre, false, 3) if not guard_items.is_empty() else []
		var post_guard_alt: Array = _guard_alt(guard_items, env, p_post, false, 3) if not guard_items.is_empty() else []
		for exec_id in execs[day_str]:
			var idx: int = ids.find(exec_id)
			if idx >= 0:
				var split: Dictionary = {"exec_day": exec_day, "executed_idx": idx, "alive_demon_mask": alive_mask, "pre_profiles": pre_profiles, "post_profiles": post_profiles, "pre_scenes": pre_scenes, "post_scenes": post_scenes}
				if not guard_items.is_empty():
					split["pre_guard_alt"] = pre_guard_alt
					split["post_guard_alt"] = post_guard_alt
				out.append(split)
	return out

static func _build_scene_tables_cs(view: Dictionary, ids: Array, env: Dictionary, cards: Array, packed_cards: Dictionary) -> Array:
	var out: Array = []
	var has_curse: bool = env.has_curse
	var n: int = ids.size()
	var c_stride: int = 3 if has_curse else 2
	var bridge = SolverBackend._bridge()
	var compiled_by_scene: Dictionary = {}
	var compiled_order: Array = []
	for ta in view.get("trace_assessments", []):
		if not ta is Dictionary:
			continue
		for cs in ta.get("scenes", []):
			var sc_key: String = str(cs.get("scene", ""))
			if sc_key == "":
				continue
			var sel_id: String = str(cs.get("selected_trace_id", ""))
			if sel_id != "" and not cards.any(func(c): return not c.get("quoted", false) and c.id == sel_id):
				continue
			if not compiled_by_scene.has(sc_key):
				compiled_order.append(sc_key)
			compiled_by_scene[sc_key] = cs
	for sc_key in compiled_order:
		var cs: Dictionary = compiled_by_scene[sc_key]
		var c_night: int = int(cs.get("night", 1))
		var c_block: String = str(cs.get("scene_block", ""))
		var c_victim_idx: int = ids.find(str(cs.get("victim_id", "")))
		var c_two: bool = bool(cs.get("two_cited", false)) and cs.get("w2", []).size() == n
		var c_count: int = maxi(2 if c_two else 1, int(cs.get("scene_trace_count", 1)))
		var c_good: Array = []
		var c_minion: Array = []
		var c_conv: Array = []
		if c_two or c_count >= 2:
			SolverBackend.record_boundary_call("LiveActivity.scene_crossings", 0)
			var raw_c: PackedFloat64Array = bridge.LiveSceneCrossings(
				c_night, _block_code(c_block), has_curse, env.homes, env.deaths, env.demon_events,
				has_curse, env.curse_from, env.curse_until, packed_cards.ints, packed_cards.doubles
			)
			c_good.resize(n)
			c_minion.resize(n)
			if has_curse:
				c_conv.resize(n)
			for i in range(n):
				var b: int = i * c_stride
				c_good[i] = raw_c[b]
				c_minion[i] = raw_c[b + 1]
				if has_curse:
					c_conv[i] = raw_c[b + 2]
		out.append({
			"scene": sc_key,
			"night": c_night,
			"scene_block": c_block,
			"victim_idx": c_victim_idx,
			"scene_trace_count": c_count,
			"two_cited": c_two,
			"w1": cs.get("w1", []).duplicate(),
			"w2": cs.get("w2", []).duplicate() if c_two else [],
			"cross_good": c_good,
			"cross_minion": c_minion,
			"cross_converted": c_conv,
		})
	var by_scene: Dictionary = {}
	var scene_order: Array = []
	for c in cards:
		if c.get("quoted", false) or c.kind != "trace" or not c.get("data", {}).has("family"):
			continue
		var sc_id: String = str(c.data.get("scene", ""))
		if sc_id == "" or compiled_by_scene.has(sc_id):
			continue
		var slot: int = int(c.data.get("slot", 0))
		if not by_scene.has(sc_id):
			by_scene[sc_id] = {}
			scene_order.append(sc_id)
		if not by_scene[sc_id].has(slot):
			by_scene[sc_id][slot] = c
	for sc_id in scene_order:
		var slot_map: Dictionary = by_scene[sc_id]
		var slots: Array = slot_map.keys()
		slots.sort()
		var t1: Dictionary = slot_map[slots[0]]
		var two_cited: bool = slots.size() >= 2
		var t2: Dictionary = slot_map[slots[1]] if two_cited else {}
		var night: int = int(t1.get("night", 1))
		var scene_block: String = str(t1.data.get("scene_block", ""))
		var victim_idx: int = ids.find(str(t1.data.get("victim", "")))
		var scene_trace_count: int = maxi(slots.size(), int(t1.data.get("scene_trace_count", 1)))
		var w1: Array = []
		var w2: Array = []
		for p in view.people:
			w1.append(evaluate_trace_for_person(view, cards, t1, p.id).weight)
			if two_cited:
				w2.append(evaluate_trace_for_person(view, cards, t2, p.id).weight)
		var cross_good: Array = []
		var cross_minion: Array = []
		var cross_converted: Array = []
		if two_cited or scene_trace_count >= 2:
			SolverBackend.record_boundary_call("LiveActivity.scene_crossings", 0)
			var raw_c2: PackedFloat64Array = bridge.LiveSceneCrossings(
				night, _block_code(scene_block), has_curse, env.homes, env.deaths, env.demon_events,
				has_curse, env.curse_from, env.curse_until, packed_cards.ints, packed_cards.doubles
			)
			cross_good.resize(n)
			cross_minion.resize(n)
			if has_curse:
				cross_converted.resize(n)
			for i in range(n):
				var b2: int = i * c_stride
				cross_good[i] = raw_c2[b2]
				cross_minion[i] = raw_c2[b2 + 1]
				if has_curse:
					cross_converted[i] = raw_c2[b2 + 2]
		out.append({
			"scene": sc_id,
			"night": night,
			"scene_block": scene_block,
			"victim_idx": victim_idx,
			"scene_trace_count": scene_trace_count,
			"two_cited": two_cited,
			"w1": w1,
			"w2": w2,
			"cross_good": cross_good,
			"cross_minion": cross_minion,
			"cross_converted": cross_converted,
		})
	return out
