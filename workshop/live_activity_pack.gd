## The C# packing helpers (matching workshop/cs/LiveActivity.cs) and the bounded live
## routes (split from `workshop/live_activity.gd`; part of LiveActivity's inheritance chain).
extends "res://workshop/live_activity_profiles.gd"
static var route_cache = {}
static var _env_cache: Dictionary = {}

const _CARD_STRIDE = 20

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
		"sexton":
			return 8
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
	if _env_cache.size() >= 128:
		_env_cache.clear()
	_env_cache[env_k] = {"input": env_in.duplicate(true), "env": env_out}
	return env_out

static func _pack_activity_cards(ids: Array, homes: PackedInt32Array, cards: Array, answers: Dictionary, role_tok_map: Dictionary, curse: Dictionary = {}) -> Dictionary:
	var c_count: int = cards.size()
	var card_ints := PackedInt32Array()
	var card_doubles := PackedFloat64Array()
	card_ints.resize(c_count * _CARD_STRIDE)
	card_doubles.resize(c_count * 2)
	var inc_map: Dictionary = {}
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
		if data.has("family"):
			flags |= (1 << 8)
		if bool(C.ROLES.get(role_str, {}).get("night_walk", false)):
			flags |= (1 << 9)
		if bool(card.get("known_self", false)):
			flags |= (1 << 10)  # FlagKnownSelf: the listener's own home night
		if bool(card.get("admitted", false)):
			flags |= (1 << 11)  # FlagAdmitted: a person's own "I was out"
		if kind_code == 1 and teller_place_eligible(card, ids):
			flags |= (1 << 12)  # FlagTellerAt
			if homes[ids.find(str(card.source))] == _block_code(str(card.block)):
				flags |= (1 << 13)  # FlagTellerAtHome: from their window
			if teller_told_cursed(curse, card):
				flags |= (1 << 14)  # FlagTellerToldCursed
		if kind_code == 9 and claim_walks(card):
			flags |= (1 << 15)  # FlagClaimWalks: an Unrequited claim
		if kind_code == 5 and bool(card.get("known_self", false)) and card.has("route"):
			flags |= (1 << 16)  # FlagKnownRoute: the listener's own walk that night
			var r_mask: int = 0
			for b in card.route:
				r_mask |= 1 << _block_code(str(b))
			card_ints[off + 17] = r_mask
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
		elif kind_code == 7 and move_rc == 8: # sexton: the night it says it tolled, in [17]
			card_ints[off + 17] = int(data.get("night", card.get("night", -1)))
		elif kind_code == 3: # legacy trace
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
			inc_str = _alibi_incident(card)
		elif kind_code == 3:
			inc_str = "trace:%s:%d" % [str(data.get("scene", "")), int(data.get("slot", 0))]
		else:
			inc_str = str(card.get("id", ""))
		card_ints[off + 15] = _intern_tok(inc_map, inc_str)

		if kind_code == 9:
			var app: Dictionary = card.get("applies", {})
			card_ints[off + 18] = int(app.get("from", 0))
			card_ints[off + 19] = int(app.get("through", -1))
			# The beloved an Unrequited claim names (LiveActivityKernel.UnrequitedLikelihood), or -1.
			card_ints[off + 16] = ids.find(str(data.get("beloved", ""))) if claim_walks(card) else -1
			# The night an announced spell break stops the visits (the meeting's day), or -1.
			card_ints[off + 17] = int(card.get("observed_at", {}).get("day", -1)) if bool(data.get("spell_broken", false)) else -1

		card_doubles[c_i * 2] = (1.0 - float(card.get("self_doubt", 0.0))) if card.get("known_self", false) else float(card.get("hearing_weight", 1.0))
		# The second slot: a report's error, or an alibi's good out-rate (out_rate, an excused lie).
		card_doubles[c_i * 2 + 1] = float(card.get("out_rate", GOOD_OWN_ALIBI_OUT)) if kind_code == 5 else clampf(float(card.get("report_error", default_nw_err)), 0.02, 0.45)

	return {"ints": card_ints, "doubles": card_doubles}

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
	if route_cache.size() >= 512:
		route_cache.clear()
	route_cache[key] = {"input": input.duplicate(true), "result": result}
	return result

static func _routes_cs(view: Dictionary, cards: Array, answers: Dictionary, knowledge: Dictionary, strict_reports: bool) -> Dictionary:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var ids: Array = view.people.map(func(p): return p.id)
	var env: Dictionary = _pack_view_env(view, ids)
	var role_tok_map: Dictionary = {}
	var packed_cards: Dictionary = _pack_activity_cards(ids, env.homes, cards, answers, role_tok_map, view.get("chronology", {}).get("curse", {}))
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
