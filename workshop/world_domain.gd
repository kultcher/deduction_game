## Legal live alignment/modifier possibilities, derived solely from public setup rules.
## Fixture domains stay unchanged. This is a domain, never a list of referee survivors.
extends RefCounted
const C = preload("res://sim/content.gd")
static var cache = {}
static var _cached_people = null
static var _cached_idx: Dictionary = {}

static func _person_index(view: Dictionary, id: String) -> int:
	if view.people != _cached_people:
		_cached_people = view.people.duplicate(true)
		_cached_idx = {}
		for i in range(view.people.size()):
			_cached_idx[view.people[i].id] = i
	return _cached_idx.get(id, -1)

static func live(view: Dictionary) -> bool:
	return view.has("world_options")

static func worlds(view: Dictionary) -> Array:
	if not SolverBackend.profiling_enabled:
		return _worlds_dispatch(view)
	var st: int = SolverBackend.begin_stage("world_domain")
	var out: Array = _worlds_dispatch(view)
	SolverBackend.end_stage(st)
	return out

static func _worlds_dispatch(view: Dictionary) -> Array:
	var input = [view.people.map(func(p): return p.id), view.evil_count, view.world_options]
	var ckey = hash(input)
	if cache.has(ckey) and cache[ckey].input == input:
		return cache[ckey].worlds
	var mode: int = SolverBackend.active_mode()
	var result: Array
	if mode == SolverBackend.Mode.GDSCRIPT:
		result = _worlds_gd(view)
	elif mode == SolverBackend.Mode.CSHARP:
		result = _worlds_cs(view)
	else:
		result = _worlds_gd(view)
		var cs_stride3: PackedInt64Array = _worlds_cs_raw(view)
		var gd_packed := PackedInt64Array()
		var gd_keys := PackedInt64Array()
		gd_packed.resize(result.size())
		gd_keys.resize(result.size())
		for i in range(result.size()):
			gd_packed[i] = SolverBackend.pack_world(result[i])
			gd_keys[i] = int(result[i]["__key"])
		var cs_count: int = cs_stride3.size() / 3
		var cs_packed := PackedInt64Array()
		var cs_keys := PackedInt64Array()
		cs_packed.resize(cs_count)
		cs_keys.resize(cs_count)
		for i in range(cs_count):
			cs_packed[i] = cs_stride3[i * 3]
			cs_keys[i] = cs_stride3[i * 3 + 1]
		var b = SolverBackend._bridge()
		b.VerifyInt64Buffer("WorldDomain.worlds.packed", gd_packed, cs_packed)
		b.VerifyInt64Buffer("WorldDomain.worlds.keys", gd_keys, cs_keys)
	if cache.size() >= 16:
		cache.clear()
	cache[ckey] = {"input": input.duplicate(true), "worlds": result}
	return result

static func _worlds_gd(view: Dictionary) -> Array:
	var result: Array = []
	var n: int = view.people.size()
	for evil in range(1 << n):
		if _count(evil) != view.evil_count:
			continue
		for kind in view.world_options.modifiers:
			for i in range(n):
				if evil & (1 << i):
					continue
				if kind != "lovers":
					var w = {"evil": evil, "marked": i if kind == "marked" else -1, "modifier": kind, "holders": 1 << i}
					w["__key"] = _key_gd(view, w)
					w["__i"] = result.size()
					result.append(w)
				else:
					for j in range(i + 1, n):
						if not evil & (1 << j):
							var w = {"evil": evil, "marked": -1, "modifier": kind, "holders": (1 << i) | (1 << j)}
							w["__key"] = _key_gd(view, w)
							w["__i"] = result.size()
							result.append(w)
	if view.world_options.get("identities", false):
		var expanded: Array = []
		for world in result:
			for i in range(n):
				if world.evil & (1 << i):
					var candidate: Dictionary = world.duplicate()
					candidate["demon"] = i
					candidate["__key"] = _key_gd(view, candidate)
					candidate["__i"] = expanded.size()
					expanded.append(candidate)
		result = expanded
	return result

static func _worlds_cs_raw(view: Dictionary) -> PackedInt64Array:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var n: int = view.people.size()
	var evil_count: int = int(view.evil_count)
	var mods := PackedStringArray()
	for kind in view.world_options.modifiers:
		mods.append(str(kind))
	var identities: bool = bool(view.world_options.get("identities", false))
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("WorldDomain.worlds", pack_u)
	return SolverBackend._bridge().DomainEnumerateWorlds(n, evil_count, mods, identities)

static func _worlds_cs(view: Dictionary) -> Array:
	var mods: Array = view.world_options.modifiers
	var identities: bool = bool(view.world_options.get("identities", false))
	var raw: PackedInt64Array = _worlds_cs_raw(view)
	var count: int = raw.size() / 3
	var result: Array = []
	result.resize(count)
	for i in range(count):
		var packed: int = raw[i * 3]
		var wkey: int = raw[i * 3 + 1]
		var mslot: int = int(raw[i * 3 + 2])
		var evil: int = packed & 0x3FFFF
		var holders: int = (packed >> 18) & 0x3FFFF
		var marked: int = ((packed >> 36) & 0x3F) - 2
		var w: Dictionary = {
			"evil": evil,
			"marked": marked,
			"modifier": mods[mslot],
			"holders": holders,
		}
		if identities:
			w["demon"] = ((packed >> 46) & 0x3F) - 2
		w["__key"] = wkey
		w["__i"] = i
		result[i] = w
	return result

static func key(view: Dictionary, world: Dictionary) -> int:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _key_gd(view, world)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var n: int = view.people.size()
	var packed: int = SolverBackend.pack_world(world)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("WorldDomain.key", pack_u)
	var cs_val: int = int(SolverBackend._bridge().DomainWorldKey(n, packed))
	if mode == SolverBackend.Mode.CSHARP:
		return cs_val
	var gd_val: int = _key_gd(view, world)
	SolverBackend._bridge().VerifyScalarInt64("WorldDomain.key", gd_val, cs_val)
	return gd_val

static func _key_gd(view: Dictionary, world: Dictionary) -> int:
	var n: int = view.people.size()
	var base: int = ((int(world.evil) * (n + 1) + int(world.marked) + 1) * 5 + C.SECRET_MOD_LIST.find(world.modifier)) * (1 << n) + int(world.holders)
	base = base * (n + 1) + world.demon + 1 if world.has("demon") else base
	return base * (n + 1) + world.converted + 1 if world.has("converted") else base

static func claims_compatible(cards: Array, knowledge: Dictionary) -> bool:
	if not SolverBackend.profiling_enabled:
		return _claims_compatible_dispatch(cards, knowledge)
	var st: int = SolverBackend.begin_stage("world_domain")
	var ok: bool = _claims_compatible_dispatch(cards, knowledge)
	SolverBackend.end_stage(st)
	return ok

static func _claims_compatible_dispatch(cards: Array, knowledge: Dictionary) -> bool:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _claims_compatible_gd(cards, knowledge)
	var cs_val: bool = _claims_compatible_cs(cards, knowledge)
	if mode == SolverBackend.Mode.CSHARP:
		return cs_val
	var gd_val: bool = _claims_compatible_gd(cards, knowledge)
	SolverBackend._bridge().VerifyScalarBool("WorldDomain.claims_compatible", gd_val, cs_val)
	return gd_val

static func _claims_compatible_gd(cards: Array, knowledge: Dictionary) -> bool:
	var sources = {}
	var roles = {}
	for card in cards:
		if card.kind not in ["report", "claim"] or card.get("quoted", false) or card.get("testimony_only", false):
			continue
		if sources.has(card.source) and sources[card.source] != card.role:
			return false
		if roles.has(card.role) and roles[card.role] != card.source:
			return false
		if card.source == knowledge.get("self") and knowledge.get("own_role", card.role) != card.role:
			return false
		if card.source != knowledge.get("self") and card.role == knowledge.get("own_role", ""):
			return false
		sources[card.source] = card.role
		roles[card.role] = card.source
	return true

static func _claims_compatible_cs(cards: Array, knowledge: Dictionary) -> bool:
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var count: int = cards.size()
	var kinds := PackedInt32Array()
	var flags := PackedByteArray()
	var sources := PackedStringArray()
	var roles := PackedStringArray()
	kinds.resize(count)
	flags.resize(count)
	sources.resize(count)
	roles.resize(count)
	for i in range(count):
		var card: Dictionary = cards[i]
		var k: String = str(card.get("kind", ""))
		kinds[i] = 1 if k == "report" else (2 if k == "claim" else 0)
		var f: int = 0
		if card.get("quoted", false):
			f |= 1
		if card.get("testimony_only", false):
			f |= 2
		flags[i] = f
		sources[i] = str(card.get("source", ""))
		roles[i] = str(card.get("role", ""))
	var self_raw = knowledge.get("self")
	var has_self: bool = self_raw is String
	var self_id: String = str(self_raw) if has_self else ""
	var own_raw = knowledge.get("own_role")
	var has_own_role: bool = knowledge.has("own_role") and own_raw != null
	var own_role: String = str(own_raw) if has_own_role else ""
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("WorldDomain.claims_compatible", pack_u)
	return bool(SolverBackend._bridge().DomainClaimsCompatible(kinds, flags, sources, roles, has_self, self_id, has_own_role, own_role))

static func healthy(view: Dictionary, world: Dictionary, source: String) -> bool:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _healthy_gd(view, world, source)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var i: int = _person_index(view, source)
	var packed: int = SolverBackend.pack_world(world)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("WorldDomain.healthy", pack_u)
	var cs_val: bool = bool(SolverBackend._bridge().DomainHealthy(packed, i))
	if mode == SolverBackend.Mode.CSHARP:
		return cs_val
	var gd_val: bool = _healthy_gd(view, world, source)
	SolverBackend._bridge().VerifyScalarBool("WorldDomain.healthy", gd_val, cs_val)
	return gd_val

static func _healthy_gd(view: Dictionary, world: Dictionary, source: String) -> bool:
	var i: int = _person_index(view, source)
	if i < 0:
		return false
	return world.get("modifier", "marked") != "delusional" or not (world.get("holders", 0) & (1 << i))

static func gift_time(card: Dictionary) -> bool:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _gift_time_gd(card)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var role_id: String = str(card.get("role", ""))
	var rdef = C.role_def(role_id)
	var obs: Dictionary = card.get("observed_at", {})
	var obs_day: int = int(obs.get("day", -1))
	var obs_phase: String = str(obs.get("phase", ""))
	var cs_val: bool = false
	if rdef != null:
		var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
		SolverBackend.record_boundary_call("WorldDomain.gift_time", pack_u)
		cs_val = bool(SolverBackend._bridge().DomainGiftTime(
			rdef.id, rdef.align, rdef.evening_or_night, rdef.day, rdef.first_night, rdef.min_gift_day, obs_day, obs_phase
		))
	else:
		var pack_u2: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
		SolverBackend.record_boundary_call("WorldDomain.gift_time", pack_u2)
		cs_val = bool(SolverBackend._bridge().DomainGiftTime("", "", false, false, false, 0, obs_day, obs_phase))
	if mode == SolverBackend.Mode.CSHARP:
		return cs_val
	var gd_val: bool = _gift_time_gd(card)
	SolverBackend._bridge().VerifyScalarBool("WorldDomain.gift_time", gd_val, cs_val)
	return gd_val

static func _gift_time_gd(card: Dictionary) -> bool:
	var rdef = C.role_def(card.get("role", ""))
	if rdef != null:
		return rdef.is_valid_gift_time(card.observed_at)
	return false

static func rumor(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	if not SolverBackend.profiling_enabled:
		return _rumor_dispatch(view, world, card, answer)
	var st: int = SolverBackend.begin_stage("world_domain")
	var ok: bool = _rumor_dispatch(view, world, card, answer)
	SolverBackend.end_stage(st)
	return ok

static func _rumor_dispatch(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	var mode: int = SolverBackend.active_mode()
	if mode == SolverBackend.Mode.GDSCRIPT:
		return _rumor_gd(view, world, card, answer)
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var source: int = _person_index(view, card.source)
	var pair_mask: int = 0
	for id in card.data.pair:
		var idx: int = _person_index(view, id)
		if idx >= 0:
			pair_mask |= (1 << idx)
	var ans_pos: Array = answer.get("positive", [])
	var has_ans_pos: bool = not ans_pos.is_empty()
	var ans_mask: int = 0
	if has_ans_pos:
		for id in ans_pos:
			var idx2: int = _person_index(view, id)
			if idx2 >= 0:
				ans_mask |= (1 << idx2)
	var packed: int = SolverBackend.pack_world(world)
	var w_mod: String = str(world.get("modifier", ""))
	var secret: String = str(card.data.secret)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("WorldDomain.rumor", pack_u)
	var cs_val: bool = bool(SolverBackend._bridge().DomainRumor(packed, w_mod, source, secret, pair_mask, has_ans_pos, ans_mask))
	if mode == SolverBackend.Mode.CSHARP:
		return cs_val
	var gd_val: bool = _rumor_gd(view, world, card, answer)
	SolverBackend._bridge().VerifyScalarBool("WorldDomain.rumor", gd_val, cs_val)
	return gd_val

static func _rumor_gd(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	var source: int = _person_index(view, card.source)
	# Setup rule (Oct 26): the Rumormonger never holds the secret alone (its gift can't
	# name itself), so a world where the source is the only holder can't produce a
	# healthy report.
	if source >= 0 and (world.holders & ~(1 << source)) == 0:
		return false
	if world.modifier != card.data.secret:
		return false
	var pair_mask: int = 0
	for id in card.data.pair:
		var idx = _person_index(view, id)
		if idx >= 0:
			pair_mask |= (1 << idx)
	if not (world.holders & pair_mask):
		return false
	var ans_pos = answer.get("positive", [])
	if not ans_pos.is_empty():
		var ans_mask: int = 0
		for id in ans_pos:
			var idx = _person_index(view, id)
			if idx >= 0:
				ans_mask |= (1 << idx)
		if (world.holders & ans_mask) != ans_mask:
			return false
	return true

static func _count(value: int) -> int:
	var result = 0
	while value:
		value &= value - 1
		result += 1
	return result
