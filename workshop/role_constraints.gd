## Joint role completions and a persistent Red Herring, without full permutations.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Activity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const Chronology = preload("res://workshop/chronology.gd")
const Domain = preload("res://workshop/world_domain.gd")
static var cache: Dictionary = {}
static var reuse = true

# Fixed role slots matching workshop/cs/RoleConstraints.cs:
const _FIXED_ROLES = {
	"medium": 0,
	"lamplighter": 1,
	"revenant": 2,
	"martyr": 3,
	"sexton": 4,
	"veteran": 5,
	"seer": 6,
	"gravedigger": 7,
	"nightwatch": 8,
	"demon": 9,
	"scion": 10,
	"executor": 11,
	"registrar": 12,
}
const _CARD_STRIDE = 24

static func fits(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary = {}) -> bool:
	return fit_weight(view, world, cards, knowledge, answers) > 0.0

static func fit_weight(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary = {}, bluffs: bool = false) -> float:
	if not SolverBackend.profiling_enabled:
		return _fit_weight_dispatch(view, world, cards, knowledge, answers, bluffs)
	var st: int = SolverBackend.begin_stage("world_domain")
	var w: float = _fit_weight_dispatch(view, world, cards, knowledge, answers, bluffs)
	SolverBackend.end_stage(st)
	return w

static func _fit_weight_dispatch(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, answers: Dictionary, bluffs: bool) -> float:
	if not view.get("world_options", {}).get("roles", false):
		return 1.0
	var ids: Array = view.people.map(func(p): return p.id)
	if reuse:
		var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), cards, knowledge.get("self"), knowledge.get("own_role"), knowledge.get("own_outings", {}), answers, knowledge.get("public_roles", {}), bluffs]
		var key = hash(input)
		if not cache.has(key) or cache[key].input != input:
			if cache.size() >= 64:
				cache.clear()
			cache[key] = {"input": input.duplicate(true), "results": {}, "seer": seer_flag(cards)}
		var mask: int = _coarse_mask_gd(ids.size(), world, cache[key].seer, relay_mediums(ids, cards), sleepwalk_claimants(ids, cards))
		if cache[key].results.has(mask):
			return float(cache[key].results[mask])
		var cs_single: float = _eval_cs_weights(view, ids, [world], -1, PackedInt32Array(), cards, knowledge, answers, bluffs, false)[0]
		cache[key].results[mask] = cs_single
		return cs_single
	return _eval_cs_weights(view, ids, [world], -1, PackedInt32Array(), cards, knowledge, answers, bluffs, false)[0]

const BLUFF_WEIGHT = Tuning.Workshop.BLUFF_WEIGHT

static func fits_table(view: Dictionary, universe: Array, cards: Array, knowledge: Dictionary, answers: Dictionary = {}, bluffs: bool = false, u_handle: int = -1, sub_indices: PackedInt32Array = PackedInt32Array()) -> PackedByteArray:
	var weights: PackedFloat64Array = fits_weights(view, universe, cards, knowledge, answers, bluffs, u_handle, sub_indices)
	var out = PackedByteArray()
	out.resize(weights.size())
	for i in range(weights.size()):
		out[i] = 1 if weights[i] > 0.0 else 0
	return out

static func fits_weights(view: Dictionary, universe: Array, cards: Array, knowledge: Dictionary, answers: Dictionary = {}, bluffs: bool = false, u_handle: int = -1, sub_indices: PackedInt32Array = PackedInt32Array()) -> PackedFloat64Array:
	if not SolverBackend.profiling_enabled:
		return _fits_weights_dispatch(view, universe, cards, knowledge, answers, bluffs, u_handle, sub_indices)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: PackedFloat64Array = _fits_weights_dispatch(view, universe, cards, knowledge, answers, bluffs, u_handle, sub_indices)
	SolverBackend.end_stage(st)
	return out

static func _fits_weights_dispatch(view: Dictionary, universe: Array, cards: Array, knowledge: Dictionary, answers: Dictionary, bluffs: bool, u_handle: int, sub_indices: PackedInt32Array) -> PackedFloat64Array:
	var out = PackedFloat64Array()
	out.resize(universe.size())
	if not view.get("world_options", {}).get("roles", false):
		out.fill(1.0)
		return out
	if universe.is_empty():
		return out
	var ids: Array = view.people.map(func(p): return p.id)
	var bridge = SolverBackend._bridge()
	if not reuse:
		return _eval_cs_weights(view, ids, universe, u_handle, sub_indices, cards, knowledge, answers, bluffs, false)
	var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), cards, knowledge.get("self"), knowledge.get("own_role"), knowledge.get("own_outings", {}), answers, knowledge.get("public_roles", {}), bluffs]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 64:
			cache.clear()
		cache[key] = {"input": input.duplicate(true), "results": {}, "seer": seer_flag(cards)}
	var entry: Dictionary = cache[key]
	var results: Dictionary = entry.results
	var seer: bool = entry.seer
	var mediums: int = relay_mediums(ids, cards)
	var walkers: int = sleepwalk_claimants(ids, cards)
	var fallback_all: PackedInt64Array = _pack_worlds_if_needed("RoleConstraints.coarse_masks", universe, u_handle)
	if u_handle >= 0:
		SolverBackend.record_boundary_call("RoleConstraints.coarse_masks", 0)
	var masks: PackedInt64Array = bridge.RoleCoarseMasksByHandle(ids.size(), u_handle, sub_indices, fallback_all, seer, mediums, walkers)
	var miss_worlds: Array = []
	var miss_masks := PackedInt64Array()
	var miss_sub := PackedInt32Array()
	var miss_seen: Dictionary = {}
	var use_sub_handle: bool = u_handle >= 0
	var has_sub: bool = not sub_indices.is_empty()
	for i in range(universe.size()):
		var m: int = masks[i]
		if not results.has(m) and not miss_seen.has(m):
			miss_seen[m] = true
			miss_worlds.append(universe[i])
			miss_masks.append(m)
			if use_sub_handle:
				miss_sub.append(sub_indices[i] if has_sub else i)
	if not miss_worlds.is_empty():
		var miss_h: int = u_handle if use_sub_handle else -1
		var miss_weights: PackedFloat64Array = _eval_cs_weights(view, ids, miss_worlds, miss_h, miss_sub, cards, knowledge, answers, bluffs, false)
		for j in range(miss_worlds.size()):
			results[miss_masks[j]] = miss_weights[j]
	for i in range(universe.size()):
		out[i] = float(results[masks[i]])
	return out

static func _intern_role(role_map: Dictionary, role: String) -> int:
	if role_map.has(role):
		return int(role_map[role])
	var next_id: int = role_map.size()
	role_map[role] = next_id
	return next_id

static func _intern_token(tok_map: Dictionary, s: String) -> int:
	if tok_map.has(s):
		return int(tok_map[s])
	var next_id: int = tok_map.size() + 1
	tok_map[s] = next_id
	return next_id

static func _pack_worlds_if_needed(fn_name: String, universe: Array, u_handle: int) -> PackedInt64Array:
	if u_handle >= 0:
		return PackedInt64Array()
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var packed: PackedInt64Array = SolverBackend.pack_worlds(universe)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call(fn_name, pack_u)
	return packed

static func _eval_cs_weights(view: Dictionary, ids: Array, universe: Array, u_handle: int, sub_indices: PackedInt32Array, cards: Array, knowledge: Dictionary, answers: Dictionary, bluffs: bool, use_coarse_memo: bool) -> PackedFloat64Array:
	var live_cards: Array = _live_cards(cards)
	var routes_avail: bool = Activity.available(view)
	var routes_okay: bool = true
	var forced_lamp := PackedInt32Array()
	if routes_avail:
		var r_dict: Dictionary = Activity.routes(view, _routing_cards(live_cards), answers, knowledge, not bluffs)
		routes_okay = bool(r_dict.get("okay", false))
		if routes_okay:
			var fl: Array = r_dict.get("forced_lamp", [])
			forced_lamp.resize(fl.size())
			for idx_f in range(fl.size()):
				forced_lamp[idx_f] = ids.find(fl[idx_f])

	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback_worlds: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var role_map: Dictionary = _FIXED_ROLES.duplicate()
	var src_tokens: Dictionary = {}
	var martyr_tokens: Dictionary = {}
	var executor_tokens: Dictionary = {}

	var view_empty: bool = view.is_empty()
	var chrono: Dictionary = view.get("chronology", {})
	var has_curse: bool = chrono.has("curse")
	var curse_exec_idx: int = -1
	var curse_from: int = 0
	var curse_until: int = 0
	if has_curse:
		var curse: Dictionary = chrono.curse
		curse_exec_idx = ids.find(str(curse.get("executed", "")))
		curse_from = int(curse.get("from", 0))
		curse_until = int(curse.get("until", 0))

	var own_idx: int = ids.find(knowledge.get("self", ""))
	var own_role_str: String = str(knowledge.get("own_role", ""))
	var own_role_id: int = -1
	if own_idx >= 0 and own_role_str in C.ROLES:
		own_role_id = _intern_role(role_map, own_role_str)
	else:
		own_idx = -1

	var pub_roles_dict: Dictionary = knowledge.get("public_roles", {})
	var pub_roles := PackedInt32Array()
	pub_roles.resize(pub_roles_dict.size() * 2)
	var pr_pos: int = 0
	for person in pub_roles_dict:
		pub_roles[pr_pos] = ids.find(person)
		pub_roles[pr_pos + 1] = _intern_role(role_map, str(pub_roles_dict[person]))
		pr_pos += 2

	var seer_on: bool = seer_flag(cards)
	var mediums_mask: int = relay_mediums(ids, cards)
	var walkers_mask: int = sleepwalk_claimants(ids, cards)

	var header := PackedInt32Array([
		ids.size(),
		1 if bluffs else 0,
		1 if view_empty else 0,
		1 if has_curse else 0,
		curse_exec_idx,
		curse_from,
		curse_until,
		own_idx,
		own_role_id,
		1 if routes_avail else 0,
		1 if routes_okay else 0,
		1 if use_coarse_memo else 0,
		1 if seer_on else 0,
		mediums_mask,
		walkers_mask,
	])

	var events: Array = view.get("timeline", {}).get("events", [])
	var has_timeline: bool = view.has("timeline")
	var c_count: int = live_cards.size()
	var card_ints := PackedInt32Array()
	card_ints.resize(c_count * _CARD_STRIDE)

	for c_idx in range(c_count):
		var card: Dictionary = live_cards[c_idx]
		var off: int = c_idx * _CARD_STRIDE
		var k_str: String = str(card.get("kind", ""))
		var kind_code: int = 0
		if k_str == "report":
			kind_code = 1
		elif k_str == "claim":
			kind_code = 2
		elif k_str == "secret_claim":
			kind_code = 3
		elif k_str == "totem":
			kind_code = 4
		elif k_str == "event" and card.get("event") == "martyr":
			kind_code = 5
		elif k_str == "town_hall":
			kind_code = 6
		card_ints[off] = kind_code

		var quoted: bool = bool(card.get("quoted", false))
		var inferred: bool = bool(card.get("inferred", false))
		var has_relay: bool = card.has("relay_source")
		var flags: int = 0
		if quoted:
			flags |= (1 << 0)
		if inferred:
			flags |= (1 << 1)
		if has_relay:
			flags |= (1 << 2)

		var src_str: String = str(card.get("source", ""))
		var src_idx: int = ids.find(src_str)
		var src_tok: int = _intern_token(src_tokens, src_str)
		card_ints[off + 2] = src_idx
		card_ints[off + 3] = src_tok

		var subj_val = card.get("subject", "")
		card_ints[off + 4] = ids.find(subj_val) if subj_val is String else -1

		var role_str: String = str(card.get("role", ""))
		var role_id: int = _intern_role(role_map, role_str) if role_str != "" else -1
		card_ints[off + 5] = role_id

		if has_relay:
			var rel_str: String = str(card.relay_source)
			card_ints[off + 6] = ids.find(rel_str)
			card_ints[off + 7] = _intern_token(src_tokens, rel_str)
			if not quoted:
				var rel_day: int = int(card.relay_observed_at.day)
				card_ints[off + 8] = rel_day
				if History.alive_at_night(view, rel_str, rel_day):
					flags |= (1 << 3)
			else:
				card_ints[off + 8] = -1
		else:
			card_ints[off + 6] = -1
			card_ints[off + 7] = -1
			card_ints[off + 8] = -1

		var c_night: int = int(card.get("night", -1))
		card_ints[off + 9] = c_night
		var data: Dictionary = card.get("data", {}) if card.get("data") is Dictionary else {}
		card_ints[off + 10] = int(data.get("night", -1))

		if kind_code == 3 and data.get("secret_kind", "") == "sleepwalker":
			flags |= (1 << 11)

		if kind_code == 1 and not quoted:
			if role_str == "martyr":
				if bool(data.get("evil", false)):
					flags |= (1 << 4)
					if History.executed(view, str(data.get("target", "")), int(card.get("observed_at", {}).get("day", -1))):
						flags |= (1 << 5)
			elif role_str == "sexton":
				var sx_night: int = int(data.get("night", -1))
				if sx_night >= 1:
					flags |= (1 << 12)
			elif role_str == "veteran":
				var vet_mask: int = 0
				var demon_ev_v: bool = events.any(func(e): return e.kind in ["demon_death", "demon_attack"] and e.at.day == c_night)
				if not demon_ev_v and not view.people.is_empty():
					var v_src_home: String = view.people[src_idx].home if src_idx >= 0 else view.people[-1].home
					var blk: String = str(data.get("block", ""))
					for d_i in range(ids.size()):
						var d_routes: Array = Activity.demon_routes(view.people[d_i].home, v_src_home)
						var fits_app: bool = d_routes.any(func(rt): return (rt.path[rt.path.size() - 2] if rt.path.size() >= 2 else v_src_home) == blk)
						if fits_app:
							vet_mask |= (1 << d_i)
				card_ints[off + 11] = vet_mask

		if kind_code == 1 or kind_code == 2:
			card_ints[off + 12] = Chronology.tick(Chronology.statement_time(card))

		if kind_code == 4: # totem
			var t_cands: int = 0
			for tid in data.get("candidates", []):
				var t_i: int = ids.find(tid)
				if t_i >= 0:
					t_cands |= (1 << t_i)
			card_ints[off + 13] = t_cands
		elif kind_code == 5: # martyr event
			card_ints[off + 13] = ids.find(data.get("martyr", ""))
			card_ints[off + 14] = ids.find(data.get("saved", ""))
		elif kind_code == 6: # town_hall
			var th_roles: Array = data.get("roles", card.get("roles", []))
			if th_roles is Array and th_roles.size() == 2 and str(th_roles[0]) != "" and str(th_roles[1]) != "" and str(th_roles[0]) != str(th_roles[1]):
				card_ints[off + 13] = _intern_role(role_map, str(th_roles[0]))
				card_ints[off + 14] = _intern_role(role_map, str(th_roles[1]))
				var th_ans: Dictionary = answers.get(card.get("id", ""), {})
				var th_pick: String = str(th_ans.get("in_play_role", ""))
				card_ints[off + 15] = 0 if th_pick == "" else (1 if th_pick == str(th_roles[0]) else (2 if th_pick == str(th_roles[1]) else 3))
			else:
				card_ints[off + 13] = -1
				card_ints[off + 14] = -1
				card_ints[off + 15] = 3
		elif kind_code == 1: # report
			if role_str == "gravedigger":
				if not has_timeline:
					flags |= (1 << 6)
				else:
					var gd_night: int = c_night if c_night >= 0 else int(card.get("observed_at", {}).get("day", -1))
					if History.executed(view, str(data.get("executed", "")), gd_night):
						flags |= (1 << 6)
			else:
				flags |= (1 << 6)

			var pair_mask: int = 0
			for person in data.get("pair", []):
				var p_i: int = ids.find(person)
				if p_i < 0:
					pair_mask = -1
					break
				pair_mask |= (1 << p_i)
			card_ints[off + 13] = pair_mask

			var ans: Dictionary = answers.get(card.get("id", ""), {})
			var sel_mask: int = 0
			for person in ans.get("positive", []):
				var s_i: int = ids.find(person)
				if s_i < 0:
					sel_mask = -1
					break
				sel_mask |= (1 << s_i)
			card_ints[off + 14] = sel_mask

			var rdef = C.role_def(role_str)
			if rdef != null and rdef.shape == "ROLE_IN_GROUP":
				flags |= (1 << 7)
				if rdef.marked_registers:
					flags |= (1 << 8)
				if rdef.role_group_key == "pair":
					card_ints[off + 15] = 0
					card_ints[off + 16] = -1
				else:
					card_ints[off + 15] = 1
					card_ints[off + 16] = ids.find(data.get(rdef.role_group_key, ""))
				match rdef.role_target_pool:
					"minion":
						card_ints[off + 17] = 1
					"demon":
						card_ints[off + 17] = 2
					"any":
						card_ints[off + 17] = 3
					_:
						card_ints[off + 17] = 0
				var read_role: String = str(data.get("role", ""))
				if C.ROLES.get(read_role, {}).get("align") == "evil":
					flags |= (1 << 9)
				card_ints[off + 18] = _intern_role(role_map, read_role)
				if read_role == "demon" and rdef.role_group_key != "pair":
					card_ints[off + 11] = _scion_exec_alive_demon_mask(view, ids, str(data.get(rdef.role_group_key, "")))
			elif role_str == "executor":
				var e_tgt: String = str(data.get("target", ""))
				card_ints[off + 16] = ids.find(e_tgt)
				card_ints[off + 17] = _intern_token(executor_tokens, e_tgt) if e_tgt != "" else 0
				if data.has("role") and not bool(data.get("assigned", false)):
					flags |= (1 << 14)
					flags |= (1 << 8)
					var e_role: String = str(data.get("role", ""))
					if C.ROLES.get(e_role, {}).get("align") == "evil":
						flags |= (1 << 9)
					card_ints[off + 18] = _intern_role(role_map, e_role)
					if e_role == "demon":
						card_ints[off + 11] = _scion_exec_alive_demon_mask(view, ids, e_tgt)
					var ex_obs_day: int = int(card.get("observed_at", {}).get("day", -1))
					if not has_timeline or History.died_before_morning(view, e_tgt, ex_obs_day):
						flags |= (1 << 13)
				elif bool(data.get("assigned", false)) and not data.has("role"):
					flags |= (1 << 15)
			elif role_str == "registrar":
				var reg_meta: int = _pack_registrar_card(data, ids, role_map, card_ints, off)
				card_ints[off + 23] = reg_meta
			elif role_str == "martyr":
				var m_tgt: String = str(data.get("target", ""))
				card_ints[off + 16] = ids.find(m_tgt)
				card_ints[off + 17] = _intern_token(martyr_tokens, m_tgt) if m_tgt != "" else 0
			elif role_str == "seer":
				if bool(data.get("yes", false)):
					flags |= (1 << 10)
				var reg: String = str(ans.get("registration", ""))
				var reg_code: int = 0
				if reg == "demon":
					reg_code = 1
				elif reg == "red_herring":
					reg_code = 2
				elif reg == "marked":
					reg_code = 3
				card_ints[off + 19] = reg_code

		card_ints[off + 1] = flags

	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("RoleConstraints.fits_weights", pack_u)
	return SolverBackend._bridge().RoleFitsWeightsByHandle(u_handle, sub_indices, fallback_worlds, header, pub_roles, forced_lamp, card_ints)

static func coarse_mask(people: int, world: Dictionary, seer: bool, mediums: int, walkers: int = 0) -> int:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var packed: int = SolverBackend.pack_world(world)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("RoleConstraints.coarse_mask", pack_u)
	var cs_val: int = int(SolverBackend._bridge().RoleCoarseMask(people, packed, seer, mediums, walkers))
	return cs_val

static func coarse_masks(people: int, universe: Array, seer: bool, mediums: int, walkers: int = 0, u_handle: int = -1, sub_indices: PackedInt32Array = PackedInt32Array()) -> PackedInt64Array:
	if not SolverBackend.profiling_enabled:
		return _coarse_masks_dispatch(people, universe, seer, mediums, walkers, u_handle, sub_indices)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: PackedInt64Array = _coarse_masks_dispatch(people, universe, seer, mediums, walkers, u_handle, sub_indices)
	SolverBackend.end_stage(st)
	return out

static func _coarse_masks_dispatch(people: int, universe: Array, seer: bool, mediums: int, walkers: int, u_handle: int, sub_indices: PackedInt32Array) -> PackedInt64Array:
	var fallback: PackedInt64Array = _pack_worlds_if_needed("RoleConstraints.coarse_masks", universe, u_handle)
	if u_handle >= 0:
		SolverBackend.record_boundary_call("RoleConstraints.coarse_masks", 0)
	var cs_out: PackedInt64Array = SolverBackend._bridge().RoleCoarseMasksByHandle(people, u_handle, sub_indices, fallback, seer, mediums, walkers)
	return cs_out

static func _coarse_mask_gd(people: int, world: Dictionary, seer: bool, mediums: int, walkers: int = 0) -> int:
	var n: int = people + 1
	var mask: int = (int(world.evil) * n + int(world.get("demon", -1)) + 1) * n + (int(world.marked) + 1 if seer else 0)
	if mediums != 0:
		var deluded: int = int(world.get("holders", 0)) & mediums if world.get("modifier", "marked") == "delusional" else 0
		mask = mask * (1 << people) + deluded
	if walkers != 0:
		var asleep: int = int(world.get("holders", 0)) & walkers if world.get("modifier", "marked") == "sleepwalker" else 0
		mask = mask * (1 << people) + asleep
	if world.has("converted"):
		mask = mask * n + int(world.converted) + 1
	return mask

static func sleepwalk_claimants(ids: Array, cards: Array) -> int:
	var bits: int = 0
	for card in cards:
		if card.get("kind", "") == "secret_claim" and card.get("data", {}).get("secret_kind", "") == "sleepwalker" and not card.get("quoted", false):
			var i: int = ids.find(card.get("subject", ""))
			if i >= 0:
				bits |= 1 << i
	return bits

static func relay_mediums(ids: Array, cards: Array) -> int:
	var bits: int = 0
	for card in cards:
		if card.has("relay_source") and not card.get("quoted", false):
			var medium: int = ids.find(card.relay_source)
			if medium >= 0:
				bits |= 1 << medium
	return bits

static func _live_cards(cards: Array) -> Array:
	return cards.filter(func(card): return not card.get("testimony_only", false))

static func _routing_cards(cards: Array) -> Array:
	var out: Array = cards.duplicate()
	for card in cards:
		if card.has("relay_source") and not card.get("quoted", false):
			out.append({"kind": "claim", "source": card.relay_source, "role": "medium", "inferred": true})
	return out

static func seer_flag(cards: Array) -> bool:
	return cards.any(func(c): return c.get("role") in ["seer", "gravedigger", "martyr", "augur", "executor", "registrar"] and not c.get("quoted", false))

static func _scion_exec_alive_demon_mask(view: Dictionary, ids: Array, target_id: String) -> int:
	if target_id == "" or not view.has("timeline"):
		return 0
	var execs: Dictionary = view.get("timeline", {}).get("executions", {})
	var death_ticks: Dictionary = view.get("timeline", {}).get("death_ticks", {})
	for day_str in execs:
		if target_id in execs[day_str]:
			var exec_day: int = int(day_str)
			var alive_before: int = 0
			for p in view.people:
				if int(death_ticks.get(p.id, 2147483647)) >= exec_day * 4 + 2:
					alive_before += 1
			if alive_before >= 5:
				var mask: int = 0
				for d_i in range(ids.size()):
					if ids[d_i] != target_id and History.alive_at_night(view, ids[d_i], exec_day):
						mask |= (1 << d_i)
				return mask
	return 0

static func _registrar_roles_ok(roles_val) -> bool:
	if not (roles_val is Array) or roles_val.size() != 3:
		return false
	var seen: Dictionary = {}
	var min_cnt: int = 0
	for r in roles_val:
		var rs: String = str(r)
		if rs == "" or seen.has(rs) or rs == "registrar" or rs == "demon":
			return false
		if C.is_minion(rs):
			min_cnt += 1
		elif rs not in C.GOOD_ROLES:
			return false
		seen[rs] = true
	return min_cnt <= 1

static func _pack_registrar_card(data: Dictionary, ids: Array, role_map: Dictionary, card_ints: PackedInt32Array, off: int) -> int:
	var r_arr = data.get("roles", [])
	if not _registrar_roles_ok(r_arr):
		return -1
	var meta: int = 0
	for k in range(3):
		var rs: String = str(r_arr[k])
		card_ints[off + 20 + k] = _intern_role(role_map, rs)
		if C.is_minion(rs):
			meta |= (1 << k)
	if data.has("target") or data.has("yes"):
		if not (data.has("target") and data.get("yes") is bool):
			return -1
		meta |= (1 << 3)
		if bool(data.get("yes", false)):
			meta |= (1 << 4)
		card_ints[off + 16] = ids.find(str(data.get("target", "")))
	return meta

static func _seer_rh_weight(candidates_mask: int, demon: int, marked: int, readings: Array) -> float:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var r_ints := PackedInt32Array()
	r_ints.resize(readings.size() * 4)
	for idx in range(readings.size()):
		var rd: Dictionary = readings[idx]
		var b: int = idx * 4
		r_ints[b] = 1 if bool(rd.get("yes", false)) else 0
		r_ints[b + 1] = int(rd.get("pair", 0))
		r_ints[b + 2] = int(rd.get("ping", 0))
		var r_str: String = str(rd.get("reason", ""))
		r_ints[b + 3] = 1 if r_str == "demon" else (2 if r_str == "red_herring" else (3 if r_str == "marked" else 0))
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("RoleConstraints._seer_rh_weight", pack_u)
	var cs_val: float = float(SolverBackend._bridge().RoleSeerRhWeight(candidates_mask, demon, marked, r_ints))
	return cs_val

static func bluff_weights(view: Dictionary, universe: Array, cards: Array, u_handle: int = -1, sub_indices: PackedInt32Array = PackedInt32Array()) -> PackedFloat64Array:
	if not SolverBackend.profiling_enabled:
		return _bluff_weights_dispatch(view, universe, cards, u_handle, sub_indices)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: PackedFloat64Array = _bluff_weights_dispatch(view, universe, cards, u_handle, sub_indices)
	SolverBackend.end_stage(st)
	return out

static func _bluff_weights_dispatch(view: Dictionary, universe: Array, cards: Array, u_handle: int, sub_indices: PackedInt32Array) -> PackedFloat64Array:
	return _bluff_weights_cs(view, universe, cards, u_handle, sub_indices)

static func _bluff_weights_cs(view: Dictionary, universe: Array, cards: Array, u_handle: int, sub_indices: PackedInt32Array) -> PackedFloat64Array:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var fallback_worlds: PackedInt64Array = SolverBackend.pack_worlds(universe) if u_handle < 0 else PackedInt64Array()
	var ids: Array = view.people.map(func(p): return p.id)
	var has_curse: bool = view.get("chronology", {}).has("curse")
	var has_hw: bool = cards.any(func(c): return c.has("hearing_weight") and c.kind in ["claim", "report"])
	if not has_curse and not has_hw:
		var declared := PackedInt32Array()
		var seen: Dictionary = {}
		for card in cards:
			if card.kind not in ["report", "claim"] or card.get("quoted", false) or card.get("inferred", false) or card.get("testimony_only", false):
				continue
			var i: int = ids.find(card.source)
			var key: String = card.source + "|" + str(card.get("role", ""))
			if i < 0 or seen.has(key):
				continue
			seen[key] = true
			declared.append(1 << i)
		var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
		SolverBackend.record_boundary_call("RoleConstraints.bluff_weights", pack_u)
		return SolverBackend._bridge().RoleBluffWeightsSimpleByHandle(u_handle, sub_indices, fallback_worlds, declared, BLUFF_WEIGHT)

	var declarations: Dictionary = {}
	for card in cards:
		if card.kind in ["report", "claim"] and not card.get("quoted", false) and not card.get("inferred", false) and not card.get("testimony_only", false):
			var dkey: String = Chronology.source_key(view, card) + ":" + card.role
			if not declarations.has(dkey) or float(card.get("hearing_weight", 1.0)) > float(declarations[dkey].get("hearing_weight", 1.0)):
				declarations[dkey] = card
	var decl_cards: Array = declarations.values()
	var d_count: int = decl_cards.size()
	var who := PackedInt32Array()
	var h_weights := PackedFloat64Array()
	var stmt_ticks := PackedInt32Array()
	who.resize(d_count)
	h_weights.resize(d_count)
	stmt_ticks.resize(d_count)
	for d in range(d_count):
		var c: Dictionary = decl_cards[d]
		who[d] = ids.find(c.source)
		h_weights[d] = float(c.get("hearing_weight", 1.0))
		stmt_ticks[d] = Chronology.tick(Chronology.statement_time(c))
	var curse_from: int = 0
	var curse_until: int = 0
	if has_curse:
		var curse: Dictionary = view.chronology.curse
		curse_from = int(curse.get("from", 0))
		curse_until = int(curse.get("until", 0))
	var pack_u2: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("RoleConstraints.bluff_weights_temporal", pack_u2)
	return SolverBackend._bridge().RoleBluffWeightsTemporalByHandle(
		u_handle, sub_indices, fallback_worlds, who, h_weights, stmt_ticks, has_curse, curse_from, curse_until, BLUFF_WEIGHT
	)

