## Bounded live routes and an explicitly experimental activity/trace comparison.
## Public receipts only. One joint factor consumes each night's trace once, even
## when it is linked to several suspects. Activity profiles persist across nights.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const History = preload("res://workshop/live_history.gd")
const DayPresence = preload("res://workshop/day_presence.gd")
static var cache = {}
static var route_cache = {}
const DEMON_DETOUR = Tuning.Workshop.DEMON_DETOUR
const VIGIL_MISS = Tuning.Workshop.VIGIL_MISS
const WALKER_CLAIM_GIFT = Tuning.Workshop.WALKER_CLAIM_GIFT
const WALKER_CLAIM_HOME = Tuning.Workshop.WALKER_CLAIM_HOME
const WALKER_CLAIM_SECRET = Tuning.Workshop.WALKER_CLAIM_SECRET
static var demon_route_cache = {}
static var _factor_handles: Dictionary = {}
static var _mru_factor = null
static var _mru_handle: int = -1
static var _mru_epoch: int = -1
static var _env_cache: Dictionary = {}

const _CARD_STRIDE = 20

static func available(view: Dictionary) -> bool:
	return view.get("live_activity", false)

static func relevant(cards: Array) -> Array:
	return cards.filter(func(c): return c.kind in ["sighting", "evening", "trace", "coverage", "alibi", "dropped"] or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran", "medium", "monitor"]))

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
	return [cards.filter(func(c): return c.has("relay_source") or c.kind in ["sighting", "evening", "trace", "coverage", "alibi", "dropped"] or (include_context and c.kind == "secret_claim") or (has_struct_trace and ((c.kind == "context" and c.get("context_kind", "") in ["home", "work", "haunt", "bond"]) or c.kind == "location")) or (c.kind == "report" and c.role in ["nightwatch", "warden", "lamplighter", "veteran", "medium", "monitor"])), roles]

static func role_of(cards: Array, person: String, knowledge: Dictionary = {}) -> String:
	if person == knowledge.get("self", ""):
		return knowledge.get("own_role", "")
	for card in cards:
		if card.get("relay_source") == person and not card.get("quoted", false):
			return "medium"
		if not card.get("quoted", false) and not card.get("testimony_only", false) and card.get("source", "") == person and card.kind in ["claim", "report"]:
			return card.role
	return ""

static func role_hearing(cards: Array, person: String, role: String) -> float:
	var strength = 0.0
	for card in cards:
		if not card.get("quoted", false) and not card.get("testimony_only", false) and card.get("source", "") == person and card.get("role", "") == role and card.kind in ["claim", "report"]:
			strength = maxf(strength, float(card.get("hearing_weight", 1.0)))
	return strength

# --- C# Packing Helpers (Matches workshop/cs/LiveActivity.cs) ---

static func _block_code(blk: String) -> int:
	if blk == "":
		return -1
	match blk:
		"square":
			return 0
		"market":
			return 1
		"docks":
			return 2
		"hill":
			return 3
		_:
			return -2

static func _move_role_code(role: String) -> int:
	if role == "":
		return 0
	match role:
		"nightwatch":
			return 1
		"warden":
			return 2
		"lamplighter":
			return 3
		"veteran":
			return 4
		"medium":
			return 5
		"monitor":
			return 7
		_:
			return 6

static func _align_code(alignment: String) -> int:
	match alignment:
		"minion":
			return 1
		"demon":
			return 2
		"converted":
			return 3
		_:
			return 0

static func _intern_tok(map: Dictionary, s: String) -> int:
	if s == "":
		return 0
	if map.has(s):
		return int(map[s])
	var nxt: int = map.size() + 1
	map[s] = nxt
	return nxt

static func _pack_view_env(view: Dictionary, ids: Array) -> Dictionary:
	var env_in: Array = [ids, view.people, view.get("timeline", {}), view.get("chronology", {})]
	var env_k: int = hash(env_in)
	if _env_cache.has(env_k) and _env_cache[env_k].input == env_in:
		return _env_cache[env_k].env
	var n: int = ids.size()
	var homes := PackedInt32Array()
	var deaths := PackedInt32Array()
	homes.resize(n)
	deaths.resize(n)
	var d_map: Dictionary = view.get("timeline", {}).get("deaths", {})
	for i in range(n):
		var p: Dictionary = view.people[i]
		homes[i] = _block_code(str(p.get("home", "")))
		deaths[i] = int(d_map.get(ids[i], 2147483647))
	var demon_events := PackedInt32Array()
	for ev in view.get("timeline", {}).get("events", []):
		if ev.get("kind", "") in ["demon_death", "demon_attack"]:
			var ev_day: int = int(ev.get("at", {}).get("day", -1))
			var subs: Array = ev.get("subjects", [])
			var v_idx: int = ids.find(subs[0]) if not subs.is_empty() else -1
			demon_events.append(ev_day)
			demon_events.append(v_idx)
	var chrono: Dictionary = view.get("chronology", {})
	var has_curse: bool = chrono.has("curse")
	var curse_from: int = 0
	var curse_until: int = 0
	if has_curse:
		var curse: Dictionary = chrono.curse
		curse_from = int(curse.get("from", 0))
		curse_until = int(curse.get("until", 0))
	var env_out: Dictionary = {
		"homes": homes,
		"deaths": deaths,
		"demon_events": demon_events,
		"has_curse": has_curse,
		"curse_from": curse_from,
		"curse_until": curse_until,
	}
	if _env_cache.size() >= 16:
		_env_cache.clear()
	_env_cache[env_k] = {"input": env_in.duplicate(true), "env": env_out}
	return env_out

static func _pack_activity_cards(ids: Array, homes: PackedInt32Array, cards: Array, answers: Dictionary, role_tok_map: Dictionary) -> Dictionary:
	var c_count: int = cards.size()
	var card_ints := PackedInt32Array()
	var card_doubles := PackedFloat64Array()
	card_ints.resize(c_count * _CARD_STRIDE)
	card_doubles.resize(c_count * 2)
	var inc_map: Dictionary = {}
	var drop_map: Dictionary = {}
	var default_nw_err: float = Tuning.Workshop.NIGHTWATCH_REPORT_ERROR

	for c_i in range(c_count):
		var card: Dictionary = cards[c_i]
		var off: int = c_i * _CARD_STRIDE
		var k_str: String = str(card.get("kind", ""))
		var kind_code: int = 0
		match k_str:
			"sighting":
				kind_code = 1
			"evening":
				kind_code = 2
			"trace":
				kind_code = 3
			"coverage":
				kind_code = 4
			"alibi":
				kind_code = 5
			"dropped":
				kind_code = 6
			"report":
				kind_code = 7
			"claim":
				kind_code = 8
			"secret_claim":
				kind_code = 9
		card_ints[off] = kind_code

		var quoted: bool = bool(card.get("quoted", false))
		var has_relay: bool = card.has("relay_source")
		var role_str: String = str(card.get("role", ""))
		var data: Dictionary = card.get("data", {}) if card.get("data") is Dictionary else {}
		var flags: int = 0
		if quoted:
			flags |= (1 << 0)
		if bool(card.get("testimony_only", false)):
			flags |= (1 << 1)
		if has_relay:
			flags |= (1 << 2)
		if card.has("hearing_weight"):
			flags |= (1 << 3)
		if bool(card.get("complete", false)):
			flags |= (1 << 4)
		if card.has("guard_claim"):
			flags |= (1 << 5)
		if bool(card.get("duty_only", false)):
			flags |= (1 << 6)
		if bool(card.get("item_drop", false)):
			flags |= (1 << 7)
		if data.has("family"):
			flags |= (1 << 8)
		if bool(C.ROLES.get(role_str, {}).get("night_walk", false)):
			flags |= (1 << 9)
		card_ints[off + 1] = flags

		var src_idx: int = ids.find(str(card.get("source", "")))
		card_ints[off + 2] = src_idx
		var subj_raw = card.get("subject", "")
		card_ints[off + 3] = ids.find(subj_raw) if subj_raw is String else -1

		var subjs_mask: int = 0
		if card.has("subjects") and card.subjects is Array:
			for s_id in card.subjects:
				var s_i: int = ids.find(s_id)
				if s_i >= 0:
					subjs_mask |= (1 << s_i)
		elif subj_raw is String and card_ints[off + 3] >= 0:
			subjs_mask = 1 << card_ints[off + 3]
		card_ints[off + 4] = subjs_mask

		var excl_mask: int = 0
		for ex_id in card.get("excluded", []):
			var ex_i: int = ids.find(ex_id)
			if ex_i >= 0:
				excl_mask |= (1 << ex_i)
		card_ints[off + 5] = excl_mask

		var move_rc: int = _move_role_code(role_str)
		card_ints[off + 7] = move_rc
		card_ints[off + 8] = _intern_tok(role_tok_map, role_str)
		card_ints[off + 9] = int(card.get("night", -1))
		card_ints[off + 10] = _block_code(str(card.get("block", "")))

		if kind_code == 7 and move_rc == 1: # nightwatch
			var seen_m: int = 0
			for sn_id in data.get("seen", []):
				var sn_i: int = ids.find(sn_id)
				if sn_i >= 0:
					seen_m |= (1 << sn_i)
			card_ints[off + 6] = seen_m
			card_ints[off + 11] = _block_code(str(data.get("block", "")))
		elif kind_code == 7 and move_rc == 7: # monitor: home block; walked flag in [17]
			card_ints[off + 11] = _block_code(str(data.get("block", "")))
			card_ints[off + 17] = 1 if bool(data.get("walked", false)) else 0
		elif kind_code == 7 and move_rc == 5: # medium
			card_ints[off + 11] = _block_code(str(data.get("block", card.get("block", ""))))
		elif kind_code == 7 and move_rc == 3: # lamplighter
			var pos_m: int = 0
			if not answers.is_empty():
				for pos_id in answers.get(card.get("id", ""), {}).get("positive", []):
					var pos_i: int = ids.find(pos_id)
					if pos_i < 0:
						pos_m = -1
						break
					pos_m |= (1 << pos_i)
			card_ints[off + 6] = pos_m
			card_ints[off + 17] = int(data.get("count", 0))
		elif kind_code == 6 or kind_code == 3: # dropped / legacy trace
			card_ints[off + 11] = _block_code(str(data.get("material", "")))

		if has_relay:
			card_ints[off + 12] = ids.find(str(card.relay_source))
			if not quoted:
				card_ints[off + 13] = int(card.relay_observed_at.day)
				card_ints[off + 14] = homes[src_idx] if src_idx >= 0 else -2
			else:
				card_ints[off + 13] = -1
				card_ints[off + 14] = -2
		else:
			card_ints[off + 12] = -1
			card_ints[off + 13] = -1
			card_ints[off + 14] = -2

		var inc_str: String
		if kind_code == 5:
			inc_str = "alibi:" + str(card.get("subject", ""))
		elif kind_code == 3:
			inc_str = "trace:%s:%d" % [str(data.get("scene", "")), int(data.get("slot", 0))]
		else:
			inc_str = str(card.get("id", ""))
		card_ints[off + 15] = _intern_tok(inc_map, inc_str)

		if kind_code == 6 or (flags & (1 << 7)) != 0:
			var df_key: String = str(card.get("fact_id", card.get("id", "")))
			card_ints[off + 16] = _intern_tok(drop_map, df_key)

		if kind_code == 9:
			var app: Dictionary = card.get("applies", {})
			card_ints[off + 18] = int(app.get("from", 0))
			card_ints[off + 19] = int(app.get("through", -1))

		card_doubles[c_i * 2] = float(card.get("hearing_weight", 1.0))
		card_doubles[c_i * 2 + 1] = clampf(float(card.get("report_error", default_nw_err)), 0.02, 0.45)

	return {"ints": card_ints, "doubles": card_doubles}

# --- Routes & Paths ---

static func _paths(view: Dictionary, person: Dictionary, night: int, cards: Array, knowledge: Dictionary, strict_reports: bool = true) -> Array:
	if not History.alive_at_night(view, person.id, night):
		return [[]]
	var role = role_of(cards, person.id, knowledge)
	var paths: Array = [[]]
	for block in C.BLOCKS:
		paths.append(C.route(person.home, block))
	if role in ["", "lamplighter"]:
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
			if card.kind == "sighting" and card.get("hearing_weight", 1.0) < 1.0:
				continue
			if card.kind == "sighting" and person.id in card.get("subjects", [card.get("subject", "")]):
				okay = okay and out and (card.block == "" or (C.vigil_sees_path(card.block, path) if card.get("complete", false) else card.block in path))
				if card.has("guard_claim"):
					okay = okay and out and path.back() == card.block
			elif card.kind == "sighting" and card.get("complete", false) and person.id not in card.get("excluded", []):
				# Logical consistency; the probabilistic score uses VIGIL_MISS instead.
				okay = okay and not C.vigil_sees_path(card.block, path)
			elif card.kind == "alibi" and card.subject == person.id:
				okay = okay and not out
			elif card.kind == "coverage" and person.id not in card.get("excluded", []):
				okay = okay and not C.vigil_sees_path(card.block, path)
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

static func routes(view: Dictionary, cards: Array, answers: Dictionary = {}, knowledge: Dictionary = {}, strict_reports: bool = true) -> Dictionary:
	if not SolverBackend.profiling_enabled:
		return _routes_dispatch(view, cards, answers, knowledge, strict_reports)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: Dictionary = _routes_dispatch(view, cards, answers, knowledge, strict_reports)
	SolverBackend.end_stage(_st)
	return _res

static func _routes_dispatch(view: Dictionary, cards: Array, answers: Dictionary, knowledge: Dictionary, strict_reports: bool) -> Dictionary:
	var input = [view.people, view.get("timeline", {}), movement_inputs(view, cards, knowledge), answers, knowledge, strict_reports]
	var key = hash(input)
	if route_cache.has(key) and route_cache[key].input == input:
		return route_cache[key].result
	var result: Dictionary = _routes_cs(view, cards, answers, knowledge, strict_reports)
	if route_cache.size() >= 128:
		route_cache.clear()
	route_cache[key] = {"input": input.duplicate(true), "result": result}
	return result

static func _routes_cs(view: Dictionary, cards: Array, answers: Dictionary, knowledge: Dictionary, strict_reports: bool) -> Dictionary:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var ids: Array = view.people.map(func(p): return p.id)
	var env: Dictionary = _pack_view_env(view, ids)
	var role_tok_map: Dictionary = {}
	var packed_cards: Dictionary = _pack_activity_cards(ids, env.homes, cards, answers, role_tok_map)
	var self_id: String = str(knowledge.get("self", "")) if knowledge.get("self") is String else ""
	var self_idx: int = ids.find(self_id) if self_id != "" else -1
	var own_role_str: String = str(knowledge.get("own_role", ""))
	var own_move_rc: int = _move_role_code(own_role_str)
	var own_role_tok: int = _intern_tok(role_tok_map, own_role_str)
	var own_nw: int = 1 if bool(C.ROLES.get(own_role_str, {}).get("night_walk", false)) else 0
	var own_outings_dict: Dictionary = knowledge.get("own_outings", {})
	var own_outings := PackedInt32Array()
	for ok_k in own_outings_dict:
		own_outings.append(int(ok_k))
		own_outings.append(1 if bool(own_outings_dict[ok_k]) else 0)
	var header := PackedInt32Array([
		ids.size(),
		1 if strict_reports else 0,
		self_idx,
		own_move_rc,
		own_role_tok,
		own_nw,
	])
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity.routes", pack_u)
	var raw: PackedInt32Array = SolverBackend._bridge().LiveEvaluateRoutes(
		header, env.homes, env.deaths, own_outings, packed_cards.ints, packed_cards.doubles
	)
	var okay: bool = raw[0] != 0
	var fl_cnt: int = raw[1]
	var forced_lamp: Array = []
	for i in range(fl_cnt):
		forced_lamp.append(ids[raw[2 + i]])
	var m_pos: int = 2 + fl_cnt
	var m_cnt: int = raw[m_pos]
	var nights: Dictionary = {}
	var n_people: int = ids.size()
	for ni in range(m_cnt):
		var b: int = m_pos + 1 + ni * 3
		var n_int: int = raw[b]
		var comp_cnt: int = raw[b + 1]
		var fo_mask: int = raw[b + 2]
		var out_ids: Array = []
		if comp_cnt > 0:
			for p_i in range(n_people):
				if (fo_mask & (1 << p_i)) != 0:
					out_ids.append(ids[p_i])
		nights[str(n_int)] = {"compatible": comp_cnt, "forced_out": out_ids}
	return {"okay": okay, "nights": nights, "forced_lamp": forced_lamp}

static func _count(mask: int) -> int:
	var result = 0
	while mask:
		mask &= mask - 1
		result += 1
	return result

# --- Joint Movement Factors & Scoring ---

static func factors(view: Dictionary, cards: Array, value: Dictionary) -> Array:
	if not SolverBackend.profiling_enabled:
		return _factors_dispatch(view, cards, value)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: Array = _factors_dispatch(view, cards, value)
	SolverBackend.end_stage(_st)
	return _res

## Diagnostics: turn the Hexer factor off to measure what it adds (tools only).
static var hex_factor_enabled: bool = true

static func _factors_dispatch(view: Dictionary, cards: Array, value: Dictionary) -> Array:
	if not available(view):
		return []
	var observations = relevant(cards).filter(func(c): return not c.get("quoted", false) or c.kind == "alibi")
	if observations.is_empty():
		return []
	var tc_digests: Array = view.get("trace_assessments", []).map(func(ta): return str(ta.get("digest", "")))
	var input = [view.people, view.get("timeline", {}), movement_inputs(view, cards, {}, true), tc_digests]
	if view.get("chronology", {}).has("curse"):
		input.append(view.chronology.curse)
	if day_demon_share(view) > 0.0:
		# The Hexer factor reads schedules, sightings and the watch record (day presence).
		input.append({"day_demon_share": day_demon_share(view), "watched": view.get("watched", []), "hex_on": hex_factor_enabled,
			"presence_cards": cards.filter(func(c): return c.get("kind", "") in ["context", "location", "evening"]).map(func(c): return [c.get("id", ""), c.get("data", {}), c.get("source", "")])})
	var key = hash(input)
	if cache.has(key) and cache[key].input == input:
		return cache[key].result
	var result: Array = _factors_cs(view, cards, observations)
	_ensure_factor_handle(result[0])
	if cache.size() >= 128:
		cache.clear()
	cache[key] = {"input": input.duplicate(true), "result": result}
	return result

static func _factors_cs(view: Dictionary, cards: Array, observations: Array) -> Array:
	var checked: Array = cards.duplicate()
	var movement: Dictionary = _routes_cs(view, cards, {}, {}, false)
	for night in movement.nights:
		for person in movement.nights[night].forced_out:
			checked.append({"id": "inferred-out:%s:%s" % [person, night], "kind": "sighting", "source": "evidence", "subject": person, "subjects": [person], "block": "", "night": int(night)})

	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var ids: Array = view.people.map(func(p): return p.id)
	var env: Dictionary = _pack_view_env(view, ids)
	var role_tok_map: Dictionary = {}
	var packed_checked: Dictionary = _pack_activity_cards(ids, env.homes, checked, {}, role_tok_map)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity.factors_profiles", pack_u)

	var has_curse: bool = env.has_curse
	var bridge = SolverBackend._bridge()
	var raw_prof: PackedFloat64Array = bridge.LiveAllProfiles(
		has_curse, env.homes, env.deaths, env.demon_events, has_curse, env.curse_from, env.curse_until,
		DEMON_DETOUR, packed_checked.ints, packed_checked.doubles
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

	var scene_tables: Array = _build_scene_tables_cs(view, ids, env, checked, packed_checked)
	var scion_splits: Array = _scion_succession_splits_cs(view, ids, env, checked)
	var result: Array = [{"origin": "movement_model", "joint_live": true, "target": "", "log2_ratio": 1.0,
		"label": "Movement / trace: joint live comparison", "profiles": profiles, "scene_tables": scene_tables, "scion_splits": scion_splits,
		"cards": observations.map(func(c): return c.id), "note": "One joint comparison; persistent activity and evening habits. Unknown passers remain possible. Activity rates and background contamination are experimental priors, not calibrated guilt probabilities."}]
	result[0]["relationships"] = relationships(view, cards)
	if share > 0.0:
		# The Scion's before/after splits keep walking demon profiles; C# mixes each split's
		# pre x post product over the one shared type (see ScoreWorldCore).
		result[0]["day_demon_share"] = share
		result[0]["hex_kills"] = hex_kills(view, cards, ids) if hex_factor_enabled else []
		result[0]["hex_floor"] = Tuning.Workshop.HEX_UNKNOWN_FLOOR
	return result


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
	for p in view.get("people", []):
		if str(p.get("work", "")) != "":
			work[p.id] = str(p.work)
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
					for pl in DayPresence.PLACES:
						var a: float = DayPresence.at(table, ids[i], night, p, pl) * (Tuning.Workshop.HEX_OWN_WORK_WEIGHT if pl == own else 1.0)
						public_mass += w[p] / wsum * a
						if pl == l:
							at_l += w[p] / wsum * a
				row.append(at_l / public_mass if public_mass > 0.0 else 0.0)
			shares.append(row)
		out.append({"night": night, "victim": victim, "places": places, "alive_mask": alive_mask, "reg_masks": reg_masks, "shares": shares})
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

static func _ensure_factor_handle(factor: Dictionary) -> int:
	var bridge = SolverBackend._bridge()
	var epoch: int = int(bridge.GetContextEpoch())
	if _mru_epoch == epoch and _mru_factor != null and is_same(_mru_factor, factor):
		return _mru_handle
	if _mru_epoch != epoch:
		_factor_handles.clear()
		_mru_epoch = epoch
	var day_share: float = float(factor.get("day_demon_share", 0.0))
	var fkey: int = hash([factor.get("profiles", []), factor.get("scene_tables", []), factor.get("scion_splits", [])]) if day_share <= 0.0 \
		else hash([factor.get("profiles", []), factor.get("scene_tables", []), factor.get("scion_splits", []), day_share, factor.get("hex_kills", [])])
	if _factor_handles.has(fkey):
		var hit: Dictionary = _factor_handles[fkey]
		if hit.factor == factor:
			_mru_factor = factor
			_mru_handle = int(hit.handle)
			return _mru_handle

	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var profs: Array = factor.get("profiles", [])
	var n: int = profs.size()
	var has_conv: bool = n > 0 and profs[0].has("converted")
	var scenes: Array = factor.get("scene_tables", [])
	var splits: Array = factor.get("scion_splits", [])

	var meta_ints := PackedInt32Array([
		n,
		1 if has_conv else 0,
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
			for pi in range(hk.places.size()):
				meta_ints.append(int(hk.reg_masks[pi]))
				for v in hk.shares[pi]:
					meta_doubles.append(float(v))

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity.register_factor", pack_u)
	var h: int = int(bridge.LiveRegisterMovementFactor(meta_ints, meta_doubles))
	if _factor_handles.size() >= 64:
		_factor_handles.clear()
	_factor_handles[fkey] = {"factor": factor, "handle": h}
	_mru_factor = factor
	_mru_handle = h
	return h

static func score(world: Dictionary, factor: Dictionary) -> float:
	if not SolverBackend.profiling_enabled:
		return _score_dispatch(world, factor)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: float = _score_dispatch(world, factor)
	SolverBackend.end_stage(_st)
	return _res

static func _score_dispatch(world: Dictionary, factor: Dictionary) -> float:
	var fh: int = _ensure_factor_handle(factor)
	var packed_w: int = SolverBackend.pack_world(world)
	SolverBackend.record_boundary_call("LiveActivity.score", 0)
	var cs_val: float = float(SolverBackend._bridge().LiveScoreWorld(packed_w, fh))
	return cs_val

static func scores(universe: Array, factor: Dictionary, u_handle: int = -1, sub_indices: PackedInt32Array = PackedInt32Array()) -> PackedFloat64Array:
	if not SolverBackend.profiling_enabled:
		return _scores_dispatch(universe, factor, u_handle, sub_indices)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: PackedFloat64Array = _scores_dispatch(universe, factor, u_handle, sub_indices)
	SolverBackend.end_stage(_st)
	return _res

static func _scores_dispatch(universe: Array, factor: Dictionary, u_handle: int, sub_indices: PackedInt32Array) -> PackedFloat64Array:
	var n: int = universe.size()
	if n == 0:
		return PackedFloat64Array()
	var fh: int = _ensure_factor_handle(factor)
	var fallback_worlds: PackedInt64Array = PackedInt64Array()
	var pack_u: int = 0
	if u_handle < 0:
		var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
		fallback_worlds = SolverBackend.pack_worlds(universe)
		if SolverBackend.profiling_enabled:
			pack_u = Time.get_ticks_usec() - t0
	SolverBackend.record_boundary_call("LiveActivity.scores", pack_u)
	var cs_out: PackedFloat64Array = SolverBackend._bridge().LiveScoreWorldsByHandle(u_handle, sub_indices, fallback_worlds, fh)
	return cs_out

# --- Single-Person Likelihood & Crossing Probability ---

static func _likelihood(view: Dictionary, cards: Array, person: Dictionary, alignment: String) -> float:
	if not SolverBackend.profiling_enabled:
		return _likelihood_typed(view, cards, person, alignment)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: float = _likelihood_typed(view, cards, person, alignment)
	SolverBackend.end_stage(_st)
	return _res

## The demon's likelihood mixes over demon types (mix_demon); every other alignment is as before.
static func _likelihood_typed(view: Dictionary, cards: Array, person: Dictionary, alignment: String) -> float:
	var walking: float = _likelihood_dispatch(view, cards, person, alignment)
	var share: float = day_demon_share(view) if alignment == "demon" else 0.0
	if share <= 0.0:
		return walking
	return mix_demon(walking, _likelihood_dispatch(view, cards, person, "minion"), share)

static func _likelihood_dispatch(view: Dictionary, cards: Array, person: Dictionary, alignment: String) -> float:
	var ids: Array = view.people.map(func(p): return p.id)
	var p_idx: int = ids.find(person.id)
	if p_idx < 0:
		return _likelihood_gd(view, cards, person, alignment)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var env: Dictionary = _pack_view_env(view, ids)
	var role_tok_map: Dictionary = {}
	var packed_cards: Dictionary = _pack_activity_cards(ids, env.homes, cards, {}, role_tok_map)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity._likelihood", pack_u)
	var cs_val: float = float(SolverBackend._bridge().LiveSingleLikelihood(
		p_idx, _align_code(alignment), env.homes, env.deaths, env.demon_events,
		env.has_curse, env.curse_from, env.curse_until, DEMON_DETOUR,
		packed_cards.ints, packed_cards.doubles
	))
	return cs_val

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
	var reports_by_night: Array = []
	for night in nights:
		var reports: Array = []
		var incidents: Array = []
		for card in relevant_cards:
			if card.night != night:
				continue
			var incident: String = "alibi:" + card.subject if card.kind == "alibi" else (("trace:%s:%d" % [str(card.data.get("scene", "")), int(card.data.get("slot", 0))]) if card.kind == "trace" else card.id)
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
						p *= _observed(card, person.id, evening, path.path, current, view, night, cards)
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

## The share of the script's possible demons that never walk at night (the day-killer,
## docs/demon_types_plan.md). 0 on every script the game deals today, which leaves every
## movement likelihood exactly as before.
static func day_demon_share(view: Dictionary) -> float:
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

static func _profile_paths(view: Dictionary, person: Dictionary, night: int, profile: String, cards: Array) -> Array:
	var rates = {"demon": 1.0 if night > 0 else 0.0, "minion": 0.25, "gift": 1.0, "secret": 0.55, "ordinary": 0.05}
	var rate: float = rates[profile]
	if profile == "ordinary":
		for card in cards:
			if card.kind == "secret_claim" and not card.get("quoted", false) and card.subject == person.id and night >= card.applies.from and night <= card.applies.through:
				rate = maxf(rate, lerpf(float(rates.ordinary), float(rates.secret), float(card.get("hearing_weight", 1.0))))
	if not History.alive_at_night(view, person.id, night):
		return [{"path": [], "weight": 1.0}]
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
	var direct: Array = C.route(home, destination)
	var via: Array = C.BLOCKS.keys().filter(func(block): return block not in direct)
	var result: Array = [{"path": direct, "weight": 1.0 - DEMON_DETOUR if not via.is_empty() else 1.0}]
	for block in via:
		var path: Array = C.route(home, block) + C.route(block, destination).slice(1)
		result.append({"path": path, "weight": DEMON_DETOUR / via.size()})
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
					result.append("Seen elsewhere: %s's sighting on night %d argues strongly against being that night's killer; a Demon detour remains possible." % [person.name, card.night])
	for id in blocks:
		var role: String = role_of(cards, id)
		if blocks[id].size() >= 2 and C.ROLES.get(role, {}).get("night_walk", false):
			var person: Dictionary = view.people.filter(func(p): return p.id == id)[0]
			result.append("Scattered sightings: %s's movements fit the claimed %s gift. This is corroboration, not proof of that identity." % [person.name, C.role_name(role)])
	return result

static func _scion_succession_splits_cs(view: Dictionary, ids: Array, env: Dictionary, cards: Array) -> Array:
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
		var p_pre: Dictionary = _pack_activity_cards(ids, env.homes, pre_cards, {}, rmap_pre)
		var p_post: Dictionary = _pack_activity_cards(ids, env.homes, post_cards, {}, rmap_post)
		var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
		SolverBackend.record_boundary_call("LiveActivity.scion_split_profiles", pack_u)

		var raw_pre: PackedFloat64Array = bridge.LiveAllProfiles(
			false, env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
			DEMON_DETOUR, p_pre.ints, p_pre.doubles
		)
		var raw_post: PackedFloat64Array = bridge.LiveAllProfiles(
			false, env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
			DEMON_DETOUR, p_post.ints, p_post.doubles
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
		for exec_id in execs[day_str]:
			var idx: int = ids.find(exec_id)
			if idx >= 0:
				out.append({"exec_day": exec_day, "executed_idx": idx, "alive_demon_mask": alive_mask, "pre_profiles": pre_profiles, "post_profiles": post_profiles, "pre_scenes": pre_scenes, "post_scenes": post_scenes})
	return out

static func crossing_probability(view: Dictionary, cards: Array, person: Dictionary, night: int, alignment: String, scene_block: String) -> float:
	if not SolverBackend.profiling_enabled:
		return _crossing_probability_dispatch(view, cards, person, night, alignment, scene_block)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: float = _crossing_probability_dispatch(view, cards, person, night, alignment, scene_block)
	SolverBackend.end_stage(_st)
	return _res

static func _crossing_probability_dispatch(view: Dictionary, cards: Array, person: Dictionary, night: int, alignment: String, scene_block: String) -> float:
	var ids: Array = view.people.map(func(p): return p.id)
	var p_idx: int = ids.find(person.id)
	if p_idx < 0:
		return _crossing_probability_gd(view, cards, person, night, alignment, scene_block)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var env: Dictionary = _pack_view_env(view, ids)
	var role_tok_map: Dictionary = {}
	var packed_cards: Dictionary = _pack_activity_cards(ids, env.homes, cards, {}, role_tok_map)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity.crossing_probability", pack_u)
	var cs_val: float = float(SolverBackend._bridge().LiveCrossingProbability(
		p_idx, night, _align_code(alignment), _block_code(scene_block),
		env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
		DEMON_DETOUR, packed_cards.ints, packed_cards.doubles
	))
	return cs_val

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
	var night_obs: Array = []
	var seen_inc: Array = []
	for c in relevant(cards):
		if c.get("night", -1) != night or c.kind == "trace" or (c.get("quoted", false) and c.kind != "alibi"):
			continue
		var inc: String = "alibi:" + c.subject if c.kind == "alibi" else c.id
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
					w_p *= _observed(obs, person.id, evening, path_entry.path, current, view, night, cards)
				den_all += w_p
				if not path_entry.path.is_empty() and scene_block in path_entry.path:
					num_cross += w_p
	if den_all <= 1e-20:
		return 0.0
	return clampf(num_cross / den_all, 0.0, 1.0)

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
				has_curse, env.curse_from, env.curse_until, DEMON_DETOUR, packed_cards.ints, packed_cards.doubles
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
				has_curse, env.curse_from, env.curse_until, DEMON_DETOUR, packed_cards.ints, packed_cards.doubles
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

static func _observed(card: Dictionary, person: String, evening: String, path: Array, alignment: String, view: Dictionary, night: int, all_cards: Array = []) -> float:
	if card.get("quoted", false) and card.kind != "alibi":
		return 1.0
	var out: bool = not path.is_empty()
	match card.kind:
		"sighting":
			if person in card.get("subjects", [card.get("subject", "")]):
				var matches_block: bool = card.block == "" or (C.vigil_sees_path(card.block, path) if card.get("complete", false) else card.block in path)
				return 1.0 if out and matches_block else 1.0 - float(card.get("hearing_weight", 1.0))
			if card.get("complete", false) and person not in card.get("excluded", []):
				return 1.0 if not C.vigil_sees_path(card.block, path) else VIGIL_MISS
		"evening":
			if person in card.get("subjects", [card.get("subject", "")]):
				return 1.0 if card.block == evening else 0.0
		"coverage":
			if person not in card.get("excluded", []):
				return 1.0 if not C.vigil_sees_path(card.block, path) else VIGIL_MISS
		"alibi":
			if card.subject == person:
				if not card.get("quoted", false):
					return 1.0 if not out else 0.0
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
