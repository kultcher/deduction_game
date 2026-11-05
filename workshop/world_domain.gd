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
	var result: Array = _worlds_cs(view)
	if cache.size() >= 16:
		cache.clear()
	cache[ckey] = {"input": input.duplicate(true), "worlds": result}
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
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var n: int = view.people.size()
	var packed: int = SolverBackend.pack_world(world)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("WorldDomain.key", pack_u)
	return int(SolverBackend._bridge().DomainWorldKey(n, packed))

static func claims_compatible(cards: Array, knowledge: Dictionary) -> bool:
	if not SolverBackend.profiling_enabled:
		return _claims_compatible_dispatch(cards, knowledge)
	var st: int = SolverBackend.begin_stage("world_domain")
	var ok: bool = _claims_compatible_dispatch(cards, knowledge)
	SolverBackend.end_stage(st)
	return ok

static func _claims_compatible_dispatch(cards: Array, knowledge: Dictionary) -> bool:
	return _claims_compatible_cs(cards, knowledge)

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
	var t0: int = Time.get_ticks_usec() if SolverBackend.profiling_enabled else 0
	var i: int = _person_index(view, source)
	var packed: int = SolverBackend.pack_world(world)
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("WorldDomain.healthy", pack_u)
	return bool(SolverBackend._bridge().DomainHealthy(packed, i))

static func gift_time(card: Dictionary) -> bool:
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
	return cs_val

static func rumor(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	if not SolverBackend.profiling_enabled:
		return _rumor_dispatch(view, world, card, answer)
	var st: int = SolverBackend.begin_stage("world_domain")
	var ok: bool = _rumor_dispatch(view, world, card, answer)
	SolverBackend.end_stage(st)
	return ok

static func _rumor_dispatch(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
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
	return bool(SolverBackend._bridge().DomainRumor(packed, w_mod, source, secret, pair_mask, has_ans_pos, ans_mask))

static func _gift_time_gd(card: Dictionary) -> bool:
	var rdef = C.role_def(card.get("role", ""))
	if rdef != null:
		return rdef.is_valid_gift_time(card.observed_at)
	return false

static func _count(value: int) -> int:
	var result = 0
	while value:
		value &= value - 1
		result += 1
	return result
