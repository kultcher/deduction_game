## Bounded live routes and an explicitly experimental activity/trace comparison.
## Public receipts only. One joint factor consumes each night's trace once, even
## when it is linked to several suspects. Activity profiles persist across nights.
##
## Split across a chain (`live_activity_base` <- `live_activity_profiles` <- `live_activity_pack`
## <- `live_activity_factors` <- this file): this file keeps the public face (available, factors,
## score, scores, _likelihood, crossing_probability); every LiveActivity.<fn> and static var
## still resolves here.
extends "res://workshop/live_activity_factors.gd"
static var cache = {}

static func available(view: Dictionary) -> bool:
	return view.get("live_activity", false)

# --- Joint Movement Factors & Scoring ---

static func factors(view: Dictionary, cards: Array, value: Dictionary) -> Array:
	if not SolverBackend.profiling_enabled:
		return _factors_dispatch(view, cards, value)
	var _st: int = SolverBackend.begin_stage("live_activity")
	var _res: Array = _factors_dispatch(view, cards, value)
	SolverBackend.end_stage(_st)
	return _res

static func _factors_dispatch(view: Dictionary, cards: Array, value: Dictionary) -> Array:
	if not available(view):
		return []
	var known: Array = own_home_cards(view)
	if not known.is_empty() and not relevant(cards).is_empty():
		cards = cards + known  # never a movement factor from the listener's own nights alone
	var observations = relevant(cards).filter(func(c): return not c.get("quoted", false) or c.kind == "alibi")
	# With a Hexer possible, daytime evidence alone (a Whereabouts day log, morning and
	# afternoon reports) still bears on who hexed whom, so it doesn't need a night card.
	if observations.is_empty() and not (day_demon_share(view) > 0.0 and hex_factor_enabled and has_day_evidence(cards)):
		return []
	var tc_digests: Array = view.get("trace_assessments", []).map(func(ta): return str(ta.get("digest", "")))
	var input = [view.people, view.get("timeline", {}), movement_inputs(view, cards, {}, true), tc_digests, view.get("regular_haunts", {}), sighter_contests_enabled, quiet_guards_enabled, quiet_guards_skip]
	if view.get("chronology", {}).has("curse"):
		input.append(view.chronology.curse)
	if day_demon_share(view) > 0.0:
		# The Hexer factor reads schedules, sightings and the watch record (day presence).
		input.append({"day_demon_share": day_demon_share(view), "watched": view.get("watched", []), "hex_on": hex_factor_enabled,
			"presence_cards": cards.filter(func(c): return c.get("kind", "") in ["context", "location", "evening", "watch_log"]).map(func(c): return [c.get("id", ""), c.get("data", {}), c.get("source", "")])})
	var mixed: Array = cards.filter(func(c): return float(c.get("broken_chance", 0.0)) > 0.0 or c.get("count_mix", false)).map(func(c): return [c.get("id", ""), float(c.get("broken_chance", 0.0)), c.get("count_mix", false)])
	if not mixed.is_empty():
		input.append({"list_mix": mixed})
		if mixed.any(func(m): return m[2]):
			# A count's impossibility reads the listener's own sightings (certain_for_count;
			# Codex on #346): key on who is listening, even with no home nights in the input.
			input.append(str(view.get("own_home", {}).get("self", "")))
	var key = hash(input)
	if cache.has(key) and cache[key].input == input:
		return cache[key].result
	var result: Array = _factors_cs(view, cards, observations)
	_ensure_factor_handle(result[0])
	if cache.size() >= 512:
		cache.clear()
	cache[key] = {"input": input.duplicate(true), "result": result}
	return result

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
	var packed_cards: Dictionary = _pack_activity_cards(ids, env.homes, cards, {}, role_tok_map, view.get("chronology", {}).get("curse", {}))
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity._likelihood", pack_u)
	var cs_val: float = float(SolverBackend._bridge().LiveSingleLikelihood(
		p_idx, _align_code(alignment), env.homes, env.deaths, env.demon_events,
		env.has_curse, env.curse_from, env.curse_until,
		packed_cards.ints, packed_cards.doubles
	))
	return cs_val

## The C# Unrequited holder column for one person (LiveActivityProfiles._unrequited_likelihood_gd mirrors it).
static func unrequited_likelihood(view: Dictionary, cards: Array, person: Dictionary) -> float:
	var ids: Array = view.people.map(func(p): return p.id)
	var p_idx: int = ids.find(person.id)
	if p_idx < 0:
		return _unrequited_likelihood_gd(view, cards, person)
	var env: Dictionary = _pack_view_env(view, ids)
	var packed: Dictionary = _pack_activity_cards(ids, env.homes, cards, {}, {}, view.get("chronology", {}).get("curse", {}))
	var raw: PackedFloat64Array = SolverBackend._bridge().LiveUnrequitedProfiles(Tuning.Burden.UNREQUITED_VISIT_CHANCE, env.homes, env.deaths, env.demon_events,
		packed.ints, packed.doubles)
	return raw[p_idx]

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
	var packed_cards: Dictionary = _pack_activity_cards(ids, env.homes, cards, {}, role_tok_map, view.get("chronology", {}).get("curse", {}))
	var pack_u: int = (Time.get_ticks_usec() - t0) if SolverBackend.profiling_enabled else 0
	SolverBackend.record_boundary_call("LiveActivity.crossing_probability", pack_u)
	var cs_val: float = float(SolverBackend._bridge().LiveCrossingProbability(
		p_idx, night, _align_code(alignment), _block_code(scene_block),
		env.homes, env.deaths, env.demon_events, env.has_curse, env.curse_from, env.curse_until,
		packed_cards.ints, packed_cards.doubles
	))
	return cs_val
