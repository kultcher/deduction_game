## Joint role completions and a persistent Red Herring, without full permutations.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Activity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const Chronology = preload("res://workshop/chronology.gd")
const Domain = preload("res://workshop/world_domain.gd")
const ScriptDef = preload("res://sim/script_def.gd")
static var cache: Dictionary = {}
static var cache_epoch: int = -1
static var reuse = true

const SOFT_EVENTS: Array = ["nomination", "meeting", "vote", "vote_yes", "accusation", "reading", "clear"]

static func _hard_timeline(view: Dictionary) -> Dictionary:
	var tl: Dictionary = view.get("timeline", {})
	if not tl.has("events"):
		return tl
	var copy: Dictionary = tl.duplicate(false)
	copy["events"] = tl.events.filter(func(e): return str(e.get("kind", "")) not in SOFT_EVENTS)
	return copy

static func _get_cache_entry(view: Dictionary, ids: Array, cards: Array, knowledge: Dictionary, answers: Dictionary, bluffs: bool) -> Dictionary:
	var bridge = SolverBackend._bridge()
	var ep: int = int(bridge.GetContextEpoch())
	if cache_epoch != ep:
		cache.clear()
		cache_epoch = ep
	var input = [view.people, _hard_timeline(view), view.get("chronology", {}), view.get("live_activity", false), cards, knowledge.get("self"), knowledge.get("own_role"), knowledge.get("own_outings", {}), answers, knowledge.get("public_roles", {}), bluffs]
	var key = hash(input)
	if not cache.has(key) or cache[key].input != input:
		if cache.size() >= 2048:
			cache.clear()
			bridge.RoleClearMemos()
		var slot: int = int(bridge.RoleCreateMemo())
		cache[key] = {
			"input": input.duplicate(true),
			"slot": slot,
			"populated": false,
			"seer": seer_flag(cards),
			"mediums": relay_mediums(ids, cards),
		}
	return cache[key]

## The people whose hanged Ill-Omened claim may have poisoned this reading (LiveAssessment
## tags it with "omen_claimants"), as a bit mask over ids.
static func omen_mask(ids: Array, card: Dictionary) -> int:
	var m: int = 0
	for c in card.get("omen_claimants", []):
		var i: int = ids.find(str(c))
		if i >= 0:
			m |= 1 << i
	return m

## The burdens a secret_claim card can name, as RoleConstraints.cs reads them (slot 19: the
## world modifier code plus one). A good claimant's claim holds in the world (they know their
## own burden); an evil one's may be a bluff. Two claims to the one burden dealt can't both be
## honest.
const BURDEN_CODES: Dictionary = {"delusional": 1, "marked": 2, "ill_omened": 3, "unrequited": 4}
## A world where the claimant is evil is weighed by how likely evil is to make that claim
## against a real holder, by whether it answers an evil reading (burden_claim_factors; Michael,
## Nov 21). The switch is for measuring it against claims as context.
static var burden_claims_bind: bool = true

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
		var entry: Dictionary = _get_cache_entry(view, ids, cards, knowledge, answers, bluffs)
		var bridge = SolverBackend._bridge()
		if bool(entry.populated):
			var packed_w: int = SolverBackend.pack_world(world)
			var hit: PackedFloat64Array = bridge.RoleTryLookupMemoByHandle(int(entry.slot), ids.size(), -1, PackedInt32Array(), PackedInt64Array([packed_w]), bool(entry.seer), int(entry.mediums))
			if not hit.is_empty():
				return hit[0]
		var res: PackedFloat64Array = _eval_cs_weights(view, ids, [world], -1, PackedInt32Array(), cards, knowledge, answers, bluffs, true, int(entry.slot))
		entry["populated"] = true
		return res[0]
	return _eval_cs_weights(view, ids, [world], -1, PackedInt32Array(), cards, knowledge, answers, bluffs, false, -1)[0]

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
	var bridge = SolverBackend._bridge()
	var n_worlds: int = sub_indices.size() if not sub_indices.is_empty() else (universe.size() if u_handle < 0 or not universe.is_empty() else int(bridge.GetUniverseSize(u_handle)))
	var out = PackedFloat64Array()
	if not view.get("world_options", {}).get("roles", false):
		out.resize(n_worlds)
		out.fill(1.0)
		return out
	if n_worlds == 0:
		return out
	var ids: Array = view.people.map(func(p): return p.id)
	if not reuse:
		return _eval_cs_weights(view, ids, universe, u_handle, sub_indices, cards, knowledge, answers, bluffs, false, -1)
	var entry: Dictionary = _get_cache_entry(view, ids, cards, knowledge, answers, bluffs)
	if bool(entry.populated):
		var fallback_all: PackedInt64Array = _pack_worlds_if_needed("RoleConstraints.coarse_masks", universe, u_handle)
		if u_handle >= 0:
			SolverBackend.record_boundary_call("RoleConstraints.coarse_masks", 0)
		var hit: PackedFloat64Array = bridge.RoleTryLookupMemoByHandle(int(entry.slot), ids.size(), u_handle, sub_indices, fallback_all, bool(entry.seer), int(entry.mediums))
		if not hit.is_empty():
			return hit
	var res: PackedFloat64Array = _eval_cs_weights(view, ids, universe, u_handle, sub_indices, cards, knowledge, answers, bluffs, true, int(entry.slot))
	entry["populated"] = true
	return res

## The Martyr's own outcome reading ("they must have been evil") about `target` from
## `source`, among `cards`.
static func _has_martyr_outcome(cards: Array, source: String, target: String) -> bool:
	# Only a direct outcome reading: the kernel skips a relayed one in worlds where the
	# relaying Medium is evil, so it can't stand in for the promise there (Codex, #183).
	return cards.any(func(c): return c.get("kind", "") == "report" and str(c.get("role", "")) == "martyr" and str(c.get("source", "")) == source \
		and not c.has("relay_source") and not bool(c.get("quoted", false)) and c.get("data") is Dictionary and bool(c.data.get("evil", false)) and str(c.data.get("target", "")) == target)


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

static func _eval_cs_weights(view: Dictionary, ids: Array, universe: Array, u_handle: int, sub_indices: PackedInt32Array, cards: Array, knowledge: Dictionary, answers: Dictionary, bluffs: bool, use_coarse_memo: bool, memo_slot: int = -1) -> PackedFloat64Array:
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
	var omen_all: int = 0
	for oc in cards:
		omen_all |= omen_mask(ids, oc)

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
		omen_all,  # the hanged Ill-Omened claimants whose windows cover these cards
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
		if bool(card.get("content_only", false)):
			flags |= (1 << 16) # RoleConstraints.FlagContentOnly
		if omen_mask(ids, card) != 0:
			flags |= (1 << 18) # RoleConstraints.FlagOmenWindow

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

		if kind_code == 1 and not quoted:
			if role_str == "martyr":
				if bool(data.get("evil", false)):
					flags |= (1 << 4)
					if History.executed(view, str(data.get("target", "")), int(card.get("observed_at", {}).get("day", -1))):
						flags |= (1 << 5)
				elif bool(data.get("chosen", false)) and History.hanged_while_alive(view, str(data.get("target", "")), str(card.get("source", ""))) \
						and not _has_martyr_outcome(live_cards, str(card.get("source", "")), str(data.get("target", ""))):
					# The chosen was hanged and the Martyr still stood: a true, healthy choice
					# means the chosen registered evil (evil or Marked), the same check as the
					# Martyr's own outcome reading. Otherwise the promise is what failed: an evil
					# bluff, or a poisoned or Delusional Martyr (the report's false-teller worlds).
					# Only public events: the hanging and the Martyr's survival of it. Bit 17
					# marks it a promise (in play a world where the Martyr is the Delusional
					# holder skips it, as it does every reading's content; Codex, #183).
					# With the same Martyr's outcome reading about the same person in the set,
					# that reading carries the check, so one failure isn't counted twice.
					flags |= (1 << 4) | (1 << 5) | (1 << 17)
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

		if kind_code == 1 or kind_code == 2 or kind_code == 3:
			card_ints[off + 12] = Chronology.tick(Chronology.statement_time(card))
		if kind_code == 3:
			# A claimed burden (docs/design/burdens.md): which world field the claim names.
			card_ints[off + 19] = burden_code(card)
			card_ints[off + 13] = forbidding_claim_tick(card, live_cards)
		if kind_code == 2:
			# Impossible pairs for unclaimed holders (Michael, Nov 21): the burdens the deal never
			# puts on this claimed role, as modifier-code bits; a good claimant can't hold one.
			card_ints[off + 13] = forbidden_burdens(card)

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
				if C.is_demon(read_role) and rdef.role_group_key != "pair":
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
					if C.is_demon(e_role):
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
				# A promise's hanging time: a chosen the Revenant turned evil registers evil
				# at a hanging inside the curse (Codex, #183). Slots 20-22 are the Registrar's.
				card_ints[off + 20] = History.hanged_while_alive_tick(view, m_tgt, str(card.get("source", ""))) if (flags & (1 << 17)) != 0 else -1
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
	if memo_slot >= 0:
		return SolverBackend._bridge().RoleFitsWeightsMemoByHandle(memo_slot, u_handle, sub_indices, fallback_worlds, header, pub_roles, forced_lamp, card_ints)
	return SolverBackend._bridge().RoleFitsWeightsByHandle(u_handle, sub_indices, fallback_worlds, header, pub_roles, forced_lamp, card_ints)

static func coarse_mask(people: int, world: Dictionary, seer: bool, mediums: int) -> int:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var packed: int = SolverBackend.pack_world(world)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("RoleConstraints.coarse_mask", pack_u)
	var cs_val: int = int(SolverBackend._bridge().RoleCoarseMask(people, packed, seer, mediums))
	return cs_val

static func coarse_masks(people: int, universe: Array, seer: bool, mediums: int, u_handle: int = -1, sub_indices: PackedInt32Array = PackedInt32Array()) -> PackedInt64Array:
	if not SolverBackend.profiling_enabled:
		return _coarse_masks_dispatch(people, universe, seer, mediums, u_handle, sub_indices)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: PackedInt64Array = _coarse_masks_dispatch(people, universe, seer, mediums, u_handle, sub_indices)
	SolverBackend.end_stage(st)
	return out

static func _coarse_masks_dispatch(people: int, universe: Array, seer: bool, mediums: int, u_handle: int, sub_indices: PackedInt32Array) -> PackedInt64Array:
	var fallback: PackedInt64Array = _pack_worlds_if_needed("RoleConstraints.coarse_masks", universe, u_handle)
	if u_handle >= 0:
		SolverBackend.record_boundary_call("RoleConstraints.coarse_masks", 0)
	var cs_out: PackedInt64Array = SolverBackend._bridge().RoleCoarseMasksByHandle(people, u_handle, sub_indices, fallback, seer, mediums)
	return cs_out

static func _coarse_mask_gd(people: int, world: Dictionary, seer: bool, mediums: int) -> int:
	var n: int = people + 1
	var mask: int = (int(world.evil) * n + int(world.get("demon", -1)) + 1) * n + (int(world.marked) + 1 if seer else 0)
	if mediums != 0:
		var mod: int = SolverBackend.modifier_code(world) if world.has("modifier") else 1
		var tellers: int = mediums & 0xFFFF
		var claimants: int = (mediums >> 16) & 0xFFFF
		var held: int = int(world.get("holders", 0)) & ((tellers | claimants) if mod == 0 else (0 if mod == 1 else claimants))
		mask = (mask * (1 << people) + held) * 5 + ((mod + 1) if held != 0 else 0)
	if world.has("converted"):
		mask = mask * n + int(world.converted) + 1
	return mask

## The people whose holding a burden changes the role check, so the coarse memo key
## (coarse_mask) must tell them apart. Low 16 bits: Medium relayers and the teller of every
## reading, who matter only as the Delusional (in play a Delusional teller's reading content
## isn't checked; Codex, #183). High 16 bits: whoever claims a burden other than Marked (their
## claim is checked in good worlds) and the hanged Ill-Omened claimants (the omen window),
## who matter for any burden but Marked (Argon, Nov 21).
static func relay_mediums(ids: Array, cards: Array) -> int:
	assert(ids.size() <= 15, "relay_mediums packs two masks into a signed 32-bit int")
	var bits: int = 0
	var claim_bits: int = 0
	for card in cards:
		if card.get("quoted", false):
			continue
		if card.has("relay_source"):
			var medium: int = ids.find(card.relay_source)
			if medium >= 0:
				bits |= 1 << medium
		# Independent of the relay: a relayed reading needs its teller in the key too, and so
		# does whoever claims to be the Delusional (their claim is checked in good worlds).
		for c in card.get("omen_claimants", []):
			var oi: int = ids.find(str(c))
			if oi >= 0:
				claim_bits |= 1 << oi
		var teller: int = ids.find(str(card.get("source", "")))
		if teller < 0:
			continue
		if card.get("kind", "") == "report":
			bits |= 1 << teller
		elif burden_code(card) > 0 and str(card.data.secret_kind) != "marked":
			claim_bits |= 1 << teller
		elif forbidden_burdens(card) != 0:
			claim_bits |= 1 << teller  # a claimed role the deal keeps some burden off
	return bits | (claim_bits << 16)

static func _live_cards(cards: Array) -> Array:
	return cards.filter(func(card): return not card.get("testimony_only", false))

static func _routing_cards(cards: Array) -> Array:
	var out: Array = cards.duplicate()
	for card in cards:
		if card.has("relay_source") and not card.get("quoted", false):
			out.append({"kind": "claim", "source": card.relay_source, "role": "medium", "inferred": true})
	return out

static func seer_flag(cards: Array) -> bool:
	return cards.any(func(c): return not c.get("quoted", false) and (c.get("role") in ["seer", "gravedigger", "martyr", "augur", "executor", "registrar"]
		or (burden_claims_bind and c.get("kind", "") == "secret_claim" and str(c.get("data", {}).get("secret_kind", "")) == "marked")
		or (forbidden_burdens(c) & (1 << 1)) != 0))  # a claimed role the deal never makes Marked: the key tells Marked apart

## Impossible pairs for unclaimed holders (Michael, Nov 21): the burdens the deal's placement
## table never puts on this card's claimed role (ScriptDef.placement_allows), as bits of the
## world's modifier code (1 << burden_code - 1), for an unquoted own role claim; 0 otherwise.
## The role check makes a world impossible where its claimant, good when they claimed the
## role, holds one of them. Read from the table, not a list of roles.
static func forbidden_burdens(card: Dictionary) -> int:
	if not burden_claims_bind or str(card.get("kind", "")) != "claim" or card.get("quoted", false) or card.get("content_only", false) \
			or card.get("inferred", false) or card.get("testimony_only", false):
		return 0
	var role: String = str(card.get("role", ""))
	if role == "":
		return 0
	var bits: int = 0
	for kind in BURDEN_CODES:
		if not ScriptDef.placement_allows(kind, role):
			bits |= 1 << (int(BURDEN_CODES[kind]) - 1)
	return bits

## A claimed burden this card's claimant must hold if good (0 for none, or the switch off).
## Only a person's own claim binds: someone retelling another's burden is not claiming it.
static func burden_code(card: Dictionary) -> int:
	if not burden_claims_bind or card.get("kind", "") != "secret_claim" or card.get("quoted", false) or card.get("content_only", false):
		return 0
	var subject = card.get("subject", "")
	if str(subject[0] if subject is Array and not subject.is_empty() else subject) != str(card.get("source", "")):
		return 0
	return int(BURDEN_CODES.get(str(card.get("data", {}).get("secret_kind", "")), 0))

## Impossible pairs (Michael, Nov 21): the deal never puts some burdens on some gifts
## (ScriptDef.PLACEMENT_RULES: Unrequited never on a night-walking gift, the Rumormonger never
## a burden's lone holder), so a good person can't truly claim both. The statement time of the
## claimant's earliest own role claim that the placement table rules out alongside this burden
## claim, or -1. Read from the table, not a list of roles.
static func forbidding_claim_tick(card: Dictionary, cards: Array) -> int:
	if burden_code(card) == 0:
		return -1
	var kind: String = str(card.data.secret_kind)
	var src: String = str(card.get("source", ""))
	var out: int = -1
	for c in cards:
		if str(c.get("kind", "")) != "claim" or c.get("quoted", false) or c.get("content_only", false) or c.get("inferred", false) \
				or c.get("testimony_only", false) or str(c.get("source", "")) != src:
			continue
		var role: String = str(c.get("role", ""))
		if role == "" or ScriptDef.placement_allows(kind, role):
			continue
		var t: int = Chronology.tick(Chronology.statement_time(c))
		out = t if out < 0 else mini(out, t)
	return out

## Measurement switch: when >= 0, every claimed burden takes this factor instead.
static var burden_factor_override: float = -1.0
static var _names_evil_cache: Dictionary = {}

## Whether an unquoted reading card points at `who` being evil: over the deal's worlds, its
## content holds more often where `who` is evil than where they're good and hold no burden
## (a Seer's yes in a pair with them, a Dowser count over a group with them). General: read
## off the judge, no list of gifts.
static func names_evil(view: Dictionary, card: Dictionary, who: int) -> bool:
	if card.get("kind", "") != "report" or card.get("quoted", false) or ids_of(view).find(str(card.get("source", ""))) == who:
		return false
	var Solver = load("res://workshop/solver.gd")
	var key: String = str([Solver._universe_key(view), str(card.get("id", "")), who])
	if _names_evil_cache.has(key):
		return bool(_names_evil_cache[key])
	var worlds: Array = Solver.universe(view)
	var table: PackedByteArray = Solver.reading_holds_table(view, card)
	var e_n := 0
	var e_h := 0
	var g_n := 0
	var g_h := 0
	for i in range(mini(worlds.size(), table.size())):
		var w: Dictionary = worlds[i]
		if int(w.evil) & (1 << who):
			e_n += 1
			e_h += int(table[i])
		elif int(w.get("marked", -1)) != who and not (int(w.get("holders", 0)) & (1 << who)):
			g_n += 1
			g_h += int(table[i])
		if _names_evil_cache.size() > 4096:
			_names_evil_cache.clear()
	var evil_rate: float = float(e_h) / float(e_n) if e_n > 0 else 0.0
	var good_rate: float = float(g_h) / float(g_n) if g_n > 0 else 0.0
	var out: bool = evil_rate > good_rate * 1.05 + 1e-9
	_names_evil_cache[key] = out
	return out

static var _burden_share_cache: Dictionary = {}

## The share of the deal's worlds with `who` good in which they hold burden `kind`.
static func _deal_share(view: Dictionary, who: int, kind: String) -> float:
	# Over the worlds the listener can't rule out: what it knows of its own burden narrows who
	# else can hold one (CaseEval._own_burden_ok), and a neutral claim must stay neutral there.
	var ob: Dictionary = view.get("own_burden", {})
	var me: int = ids_of(view).find(str(ob.get("self", ""))) if not ob.is_empty() else -1
	var ckey: String = str([ids_of(view), view.get("evil_count", 0), view.get("world_options", {}).get("modifiers", []), who, kind, ob if me >= 0 else {}])
	if not _burden_share_cache.has(ckey):
		var good: int = 0
		var held: int = 0
		for w in Domain.worlds(view):
			if int(w.evil) & (1 << who):
				continue
			# Only a good listener knows its own burden, so these are worlds where it's good.
			if me >= 0 and ((int(w.evil) & (1 << me)) or not preload("res://workshop/case_eval_classes.gd")._own_burden_ok(ob, me, w)):
				continue
			good += 1
			if (int(w.get("marked", -1)) == who) if kind == "marked" else (str(w.get("modifier", "")) == kind and int(w.get("holders", 0)) & (1 << who)):
				held += 1
		_burden_share_cache[ckey] = float(held) / float(good) if good > 0 else 1.0
	return float(_burden_share_cache[ckey])

static func ids_of(view: Dictionary) -> Array:
	return view.people.map(func(p): return p.id)

## When `card` was first said: the time it was observed (a relay or a later retelling keeps
## the first telling's time), else when it was reported.
static func _first_told_tick(card: Dictionary) -> int:
	return Chronology.tick(card.observed_at) if card.get("observed_at") is Dictionary else Chronology.tick(Chronology.statement_time(card))

## When a reading could first have been told: the morning after a night reading, else when it
## was observed. Not when this listener learned it, which can be later than the claim it
## prompted (a reading heard second-hand on day 3 still answered a day-2 claim).
static func _reading_known_tick(card: Dictionary) -> int:
	var obs = card.get("observed_at")
	if not obs is Dictionary:
		return Chronology.tick(Chronology.statement_time(card))
	if str(obs.get("phase", "")) == "night":
		return Chronology.tick({"day": int(obs.get("day", 0)) + 1, "phase": "morning"})
	return Chronology.tick(obs)

## Whether `r` is evidence already against the claimant that the claimed burden explains
## (Michael, Nov 21: "a burden claim that explains evidence already against the claimant takes
## the reactive weight"): a reading that names them evil, for any burden; and, for a burden
## whose claim explains its claimant's night walks (LiveActivity.claim_walks: Unrequited), a
## sighting of them out at night told by someone else. Dated as a reading is
## (_reading_known_tick: the morning after a night).
static func explains_against(view: Dictionary, claim: Dictionary, r: Dictionary, who: int) -> bool:
	if names_evil(view, r, who):
		return true
	if not Activity.claim_walks(claim) or str(r.get("kind", "")) != "sighting" or r.get("quoted", false) or int(r.get("night", -1)) < 0:
		return false
	var me: String = str(view.people[who].id) if who >= 0 and who < view.people.size() else ""
	return me != "" and str(r.get("source", "")) != me and me in r.get("subjects", [r.get("subject", "")])

## For each claimed burden, [who, factor, statement tick]: the factor weighs a world where the
## claimant was evil when they spoke. It's how much likelier an evil player is to make the
## claim than a real holder, measured (Tuning.Workshop.BURDEN_BLUFF_*), by whether the claim
## answers an evil reading: one the listener holds that names the claimant evil and could have
## been told no later than the claimant first told of the burden (_reading_known_tick). An earlier telling (to a friend, to
## the player) dates the claim, so a later public claim with it isn't counted as reactive
## (Michael, Nov 21). The judge can't tell a faked earlier telling from a real one.
static func burden_claim_factors(view: Dictionary, cards: Array) -> Array:
	var out: Array = []
	var ids: Array = ids_of(view)
	var held: Array = view.get("cards", [])
	var seen: Dictionary = {}
	for card in cards:
		var code: int = burden_code(card)
		var who: int = ids.find(str(card.get("source", "")))
		if code == 0 or who < 0 or seen.has("%d:%d" % [who, code]):
			continue
		seen["%d:%d" % [who, code]] = true
		var kind: String = str(card.data.secret_kind)
		var first: int = _first_told_tick(card)
		for c in held + cards:
			if burden_code(c) == code and str(c.get("source", "")) == ids[who]:
				first = mini(first, _first_told_tick(c))
		var reactive: bool = false
		for r in held + cards:
			if _reading_known_tick(r) <= first and explains_against(view, card, r, who):
				reactive = true
				break
		var factor: float = Tuning.Workshop.BURDEN_BLUFF_REACTIVE * Tuning.Workshop.BURDEN_REACTIVE_SOFTEN if reactive else Tuning.Workshop.BURDEN_BLUFF_UNPROMPTED
		if not reactive and factor < 0.0:
			factor = _deal_share(view, who, kind)
		out.append([who, factor if burden_factor_override < 0.0 else burden_factor_override, Chronology.tick(Chronology.statement_time(card)), reactive])
	return out

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
		if rs == "" or seen.has(rs) or rs == "registrar" or C.is_demon(rs):
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
	var burdens: Array = burden_claim_factors(view, cards)
	if not has_curse and not has_hw and burdens.is_empty():
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
	if not burdens.is_empty():
		var factors := PackedFloat64Array()
		for d in range(d_count):
			factors.append(lerpf(1.0, BLUFF_WEIGHT, h_weights[d]))
		for b in burdens:
			who.append(int(b[0]))
			factors.append(float(b[1]))
			stmt_ticks.append(int(b[2]))
		return SolverBackend._bridge().RoleBluffWeightsFactorsByHandle(
			u_handle, sub_indices, fallback_worlds, who, factors, stmt_ticks, has_curse, curse_from, curse_until)
	return SolverBackend._bridge().RoleBluffWeightsTemporalByHandle(
		u_handle, sub_indices, fallback_worlds, who, h_weights, stmt_ticks, has_curse, curse_from, curse_until, BLUFF_WEIGHT
	)

