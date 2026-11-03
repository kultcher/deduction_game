## Headless verification suite for C# Solver Migration Slice C2:
##   - Handle-based universe & sub-universe arena + WorkshopCaches.clear_all() reset
##   - VERIFY mode coarse_masks per-call check & CaseEval channel_sum_product stage timer
##   - LiveActivity.routes (sightings, vigils, alibis, coverage, Watch/Warden/Medium/Lamplighter,
##     Medium relay hearth constraint, dropped/item_drop Hall matching, own_outings)
##   - LiveActivity._likelihood, crossing_probability, factors, score & batched scores (--tol 0)
##     across walking/non-walking gifts, hearing_weight, secret_claim, Revenant curse intervals,
##     structured 1-trace & 2-trace scenes, Scion succession splits, and synthetic factor dicts
##   - Multi-day passive full-game parity on Seed 42 (7 NPCs) & Seed 54875 (10 NPCs) at --tol 0
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Caches = preload("res://workshop/caches.gd")
const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Roles = preload("res://workshop/role_constraints.gd")
const Activity = preload("res://workshop/live_activity.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Jury = preload("res://workshop/jury.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Ownership = preload("res://game/workshop_ownership.gd")

var _checks: int = 0
var _failures: int = 0

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		push_error("FAIL: " + msg)

func _init() -> void:
	Caches.clear_all()
	SolverBackend.reset_profile()
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)

	if not SolverBackend.is_csharp_available():
		print("SKIP: C# SolverBridge not loaded (non-Mono binary)")
		quit(0)
		return

	var bridge = SolverBackend._bridge()

	# 1. Handle-based universe & sub-universe arena + VERIFY coarse_masks + profiler stage check
	var p7: Array = []
	for i in range(7):
		p7.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var v_base: Dictionary = {
		"people": p7,
		"evil_count": 2,
		"live_activity": true,
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "identities": true, "roles": true},
	}

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
	var u7: Array = Solver.universe(v_base)
	var u_key: String = Solver._universe_key(v_base)
	var h_main: int = SolverBackend.get_universe_handle(u_key, u7)
	var h_main_again: int = SolverBackend.get_universe_handle(u_key, u7)
	var sub_idx := PackedInt32Array([0, 3, 7, 15, 31])
	var h_sub: int = SolverBackend.get_sub_universe_handle("test_sub", h_main, sub_idx)
	var h_sub_again: int = SolverBackend.get_sub_universe_handle("test_sub", h_main, sub_idx)
	_check(h_main == 0 and h_main_again == 0 and h_sub == 1 and h_sub_again == 1 and int(bridge.GetRegisteredHandleCount()) == 2,
		"Universe and sub-universe handles register once and reuse stable integer handles")

	Caches.clear_all()
	_check(int(bridge.GetRegisteredHandleCount()) == 0 and int(bridge.GetRegisteredMovementFactorCount()) == 0,
		"WorkshopCaches.clear_all() clears registered universe and movement factor handles")

	# Verify Note 2 fix: VERIFY mode exercises RoleConstraints.coarse_masks on every fits_weights call
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	SolverBackend.reset_profile()
	SolverBackend.profiling_enabled = true
	var h_ver: int = SolverBackend.get_universe_handle(u_key, u7)
	var ver_cards: Array = [
		{"id": "s1", "kind": "report", "source": "agnes", "role": "seer", "observed_at": {"day": 0, "phase": "night"}, "data": {"pair": ["bart", "constance"], "yes": true}},
	]
	Roles.fits_weights(v_base, u7, ver_cards, {}, {}, false, h_ver)
	Roles.fits_weights(v_base, u7, ver_cards, {}, {}, false, h_ver)
	var b_stats: Dictionary = SolverBackend.get_boundary_stats()
	_check(int(b_stats.get("RoleConstraints.coarse_masks", {}).get("calls", 0)) == 2 and SolverBackend.get_verify_mismatches() == 0,
		"VERIFY mode exercises RoleConstraints.coarse_masks on every fits_weights call (even on warm cache)")

	# Verify Note 3 fix: CaseEval.evaluate records channel_sum_product stage calls
	var eval_case: Dictionary = {
		"id": "c_prof",
		"cards": ["s1"],
		"conclusion": {"target": "bart", "type": "evil", "at": ""},
	}
	var v_prof: Dictionary = v_base.duplicate(true)
	v_prof["cards"] = ver_cards
	CaseEval.evaluate(v_prof, eval_case, CaseEval.neutral_listener(v_prof))
	var st_stats: Dictionary = SolverBackend.get_stage_stats()
	SolverBackend.profiling_enabled = false
	_check(int(st_stats.get("channel_sum_product", {}).get("calls", 0)) >= 1 and SolverBackend.get_verify_mismatches() == 0,
		"CaseEval.evaluate records channel_sum_product stage calls with 0 VERIFY mismatches")

	# 2. LiveActivity.routes exhaustive parity (GDSCRIPT vs CSHARP vs VERIFY)
	var v_routes: Dictionary = {
		"people": p7,
		"evil_count": 2,
		"live_activity": true,
		"timeline": {
			"deaths": {"dorian": 2},
			"death_ticks": {"dorian": 5},
			"events": [
				{"kind": "demon_death", "at": {"day": 1, "phase": "night"}, "subjects": ["dorian"]},
			],
		},
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "identities": true, "roles": true},
	}

	var route_card_sets: Array = [
		# Set A: Night Watch + Lamplighter count + positive answers + complete vigil + alibi + dropped Hall matching
		{
			"cards": [
				{"id": "nw1", "kind": "report", "source": "agnes", "role": "nightwatch", "night": 1, "observed_at": {"day": 1, "phase": "night"},
					"data": {"block": "market", "seen": ["bart", "constance"]}},
				{"id": "ll1", "kind": "report", "source": "edda", "role": "lamplighter", "night": 1, "observed_at": {"day": 1, "phase": "night"},
					"data": {"count": 3}},
				{"id": "al1", "kind": "alibi", "source": "fenwick", "subject": "fenwick", "night": 1},
				{"id": "vg1", "kind": "sighting", "source": "player", "subject": "bart", "subjects": ["bart"], "block": "market", "night": 1, "complete": true, "excluded": ["agnes", "edda", "constance", "greta"]},
				{"id": "dr1", "fact_id": "drop_a", "kind": "dropped", "source": "evidence", "block": "market", "night": 1, "data": {"material": p7[1].home}},
				{"id": "dr1_dup", "fact_id": "drop_a", "kind": "dropped", "source": "evidence", "block": "market", "night": 1, "data": {"material": p7[1].home}},
				{"id": "it1", "fact_id": "drop_b", "kind": "sighting", "item_drop": true, "source": "evidence", "subject": "constance", "subjects": ["constance"], "block": "market", "night": 1},
			],
			"answers": {"ll1": {"positive": ["agnes", "bart"]}},
			"knowledge": {"self": "agnes", "own_role": "nightwatch", "own_outings": {"1": true}},
		},
		# Set B: Medium relay hearth constraint (card from night 0 relayed on night 2 to dead Dorian's home), Warden, guard_claim, coverage, soft hearing_weight sighting
		{
			"cards": [
				{"id": "med_rel", "kind": "report", "source": "dorian", "role": "clerk", "night": 0, "observed_at": {"day": 0, "phase": "night"},
					"relay_source": "constance", "relay_observed_at": {"day": 2, "phase": "night"}, "data": {"pair": ["agnes", "bart"], "role": "seer"}},
				{"id": "wd2", "kind": "report", "source": "greta", "role": "warden", "block": p7[0].home, "night": 2, "observed_at": {"day": 2, "phase": "night"}, "data": {}},
				{"id": "gc2", "kind": "sighting", "source": "greta", "subject": "greta", "subjects": ["greta"], "block": p7[0].home, "night": 2, "guard_claim": true},
				{"id": "soft2", "kind": "sighting", "source": "bart", "subject": "fenwick", "subjects": ["fenwick"], "block": "hill", "night": 2, "hearing_weight": 0.6},
				{"id": "cov2", "kind": "coverage", "source": "player", "block": "docks", "night": 2, "excluded": ["constance", "greta"]},
			],
			"answers": {},
			"knowledge": {"self": "fenwick", "own_role": "seer", "own_outings": {"2": false}},
		},
		# Set C: Contradictory drops / dual forced Lamplighters -> okay == false
		{
			"cards": [
				{"id": "ll_a", "kind": "report", "source": "agnes", "role": "lamplighter", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"count": 2}},
				{"id": "ll_b", "kind": "report", "source": "bart", "role": "lamplighter", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"count": 2}},
			],
			"answers": {},
			"knowledge": {},
		},
	]

	for r_idx in range(route_card_sets.size()):
		var spec: Dictionary = route_card_sets[r_idx]
		for strict_flag in [true, false]:
			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
			var gd_r: Dictionary = Activity.routes(v_routes, spec.cards, spec.answers, spec.knowledge, strict_flag)

			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
			var cs_r: Dictionary = Activity.routes(v_routes, spec.cards, spec.answers, spec.knowledge, strict_flag)

			_check(gd_r == cs_r, "LiveActivity.routes exact dictionary match on set %d strict=%s" % [r_idx, str(strict_flag)])

			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
			var ver_r: Dictionary = Activity.routes(v_routes, spec.cards, spec.answers, spec.knowledge, strict_flag)
			_check(ver_r == gd_r and SolverBackend.get_verify_mismatches() == 0,
				"LiveActivity.routes VERIFY 0 mismatches on set %d strict=%s" % [r_idx, str(strict_flag)])

	# 3. LiveActivity._likelihood, crossing_probability, factors, score & scores (--tol 0)
	#    Includes Revenant curse chronology, Scion succession split (>= 5 alive at Day 2 execution),
	#    two-trace structured scene, half-cited 2-trace scene, and legacy material trace!
	var p10: Array = []
	for i in range(10):
		p10.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": i >= 2})
	var v_complex: Dictionary = {
		"people": p10,
		"evil_count": 3,
		"live_activity": true,
		"alignment_epoch": "Current alignment",
		"timeline": {
			"executions": {"2": ["bart"]},
			"deaths": {"agnes": 2, "bart": 3, "constance": 3},
			"death_ticks": {"agnes": 7, "bart": 10, "constance": 11},
			"events": [
				{"kind": "demon_death", "at": {"day": 1, "phase": "night"}, "subjects": ["agnes"]},
				{"kind": "execution", "at": {"day": 2, "phase": "evening"}, "subjects": ["bart"]},
				{"kind": "demon_death", "at": {"day": 2, "phase": "night"}, "subjects": ["constance"]},
			],
		},
		"chronology": {
			"epochs": {"Original alignment": 0, "Current alignment": 12, "before curse": 9, "during curse": 11},
			"curse": {"executed": "bart", "yes_voters": ["dorian", "edda", "fenwick"], "alive": ["dorian", "edda", "fenwick", "greta", "hollis", "isolde", "jory"], "from": 10, "until": 15},
		},
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "identities": true, "roles": true},
	}

	var first_loc: String = C.LOCATIONS.keys()[0]
	var second_loc: String = C.LOCATIONS.keys()[1]
	var complex_cards: Array = [
		{"id": "cl_nw", "kind": "claim", "source": "dorian", "role": "nightwatch", "hearing_weight": 0.75},
		{"id": "nw_n1", "kind": "report", "source": "dorian", "role": "nightwatch", "night": 1, "report_error": 0.12,
			"observed_at": {"day": 1, "phase": "night"}, "data": {"block": p10[0].home, "seen": ["edda", "fenwick"]}},
		{"id": "sec_edda", "kind": "secret_claim", "source": "edda", "subject": "edda", "hearing_weight": 0.8,
			"applies": {"from": 1, "through": 2}, "data": {"secret_kind": "sleepwalker"}},
		{"id": "q_alibi", "kind": "alibi", "quoted": true, "source": "fenwick", "subject": "fenwick", "night": 1},
		{"id": "ev_n1", "kind": "evening", "source": "player", "subject": "fenwick", "subjects": ["fenwick"], "block": "market", "night": 1},
		{"id": "ctx_home_f", "kind": "context", "context_kind": "home", "subject": "fenwick", "block": p10[5].home, "data": {"block": p10[5].home}},
		{"id": "ctx_work_f", "kind": "context", "context_kind": "work", "subject": "fenwick", "data": {"loc": first_loc, "work_phases": [C.EVENING]}},
		# Night 1 two-cited structured scene (locations + quarter)
		{"id": "tr1_a", "fact_id": "trace:sc1:0", "kind": "trace", "source": "player", "night": 1, "block": p10[0].home,
			"data": {"family": "locations", "scene": "sc1", "slot": 0, "scene_trace_count": 2, "scene_block": p10[0].home, "victim": "agnes", "locs": [first_loc, second_loc]}},
		{"id": "tr1_b", "fact_id": "trace:sc1:1", "kind": "trace", "source": "player", "night": 1, "block": p10[0].home,
			"data": {"family": "quarter", "scene": "sc1", "slot": 1, "scene_trace_count": 2, "scene_block": p10[0].home, "victim": "agnes", "home_block": "square", "evening_block": "market"}},
		# Night 2 half-cited 2-trace scene (connection, scene_trace_count = 2 with only slot 0 cited) + duty_only Medium
		{"id": "tr2_a", "fact_id": "trace:sc2:0", "kind": "trace", "source": "player", "night": 2, "block": p10[2].home,
			"data": {"family": "connection", "scene": "sc2", "slot": 0, "scene_trace_count": 2, "scene_block": p10[2].home, "victim": "constance", "victim_block": p10[2].home}},
		{"id": "med_n2", "kind": "report", "source": "greta", "role": "medium", "night": 2, "duty_only": true,
			"observed_at": {"day": 2, "phase": "night"}, "data": {"block": p10[0].home}},
		# Also include a legacy material trace on night 2 to exercise non-family trace branch
		{"id": "tr_leg", "fact_id": "trace:leg:0", "kind": "trace", "source": "player", "night": 2, "block": p10[2].home,
			"data": {"material": "market", "scene": "leg", "slot": 0}},
	]

	# Single-person _likelihood & crossing_probability checks in VERIFY + CSHARP vs GDSCRIPT
	for person in p10:
		for align in ["good", "minion", "demon", "converted"]:
			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
			var gd_lk: float = Activity._likelihood(v_complex, complex_cards, person, align)
			var gd_cp: float = Activity.crossing_probability(v_complex, complex_cards, person, 1, align, p10[0].home)

			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
			var cs_lk: float = Activity._likelihood(v_complex, complex_cards, person, align)
			var cs_cp: float = Activity.crossing_probability(v_complex, complex_cards, person, 1, align, p10[0].home)

			_check(bridge.VerifyScalarFloat64("C2_likelihood_%s_%s" % [person.id, align], gd_lk, cs_lk, 0.0),
				"LiveActivity._likelihood bit-exact for %s (%s)" % [person.id, align])
			_check(bridge.VerifyScalarFloat64("C2_crossing_%s_%s" % [person.id, align], gd_cp, cs_cp, 0.0),
				"LiveActivity.crossing_probability bit-exact for %s (%s)" % [person.id, align])

	# Full factors(), single-world score(), and batched scores() parity across universe (including converted worlds)
	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	var base_u10: Array = Solver.universe(v_complex)
	var test_worlds: Array = []
	for idx in range(0, base_u10.size(), maxi(1, base_u10.size() / 90)):
		var w_plain: Dictionary = base_u10[idx]
		test_worlds.append(w_plain)
		var w_conv: Dictionary = w_plain.duplicate()
		w_conv["converted"] = (idx % 7) + 3
		test_worlds.append(w_conv)

	var gd_factors: Array = Activity.factors(v_complex, complex_cards, {})
	var gd_scores: PackedFloat64Array = Activity.scores(test_worlds, gd_factors[0])

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
	var cs_factors: Array = Activity.factors(v_complex, complex_cards, {})
	var h_tw: int = SolverBackend.get_universe_handle("c2_test_worlds", test_worlds)
	var cs_scores: PackedFloat64Array = Activity.scores(test_worlds, cs_factors[0], h_tw)
	var cs_single_ok: bool = true
	for i in range(mini(25, test_worlds.size())):
		var s_one: float = Activity.score(test_worlds[i], cs_factors[0])
		if not bridge.VerifyScalarFloat64("C2_score_single_%d" % i, gd_scores[i], s_one, 0.0):
			cs_single_ok = false

	_check(gd_factors.size() == 1 and cs_factors.size() == 1 and gd_factors[0].relationships == cs_factors[0].relationships,
		"LiveActivity.factors structure & relationships exact match")
	_check(bridge.VerifyFloat64Buffer("C2_scores_batch", gd_scores, cs_scores, 0.0) == -1 and cs_single_ok,
		"LiveActivity.scores & LiveActivity.score bit-exact (--tol 0) across Scion + Revenant + 2-trace worlds (%d worlds)" % test_worlds.size())

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	var ver_factors: Array = Activity.factors(v_complex, complex_cards, {})
	var h_tw_v: int = SolverBackend.get_universe_handle("c2_test_worlds_v", test_worlds)
	Activity.scores(test_worlds, ver_factors[0], h_tw_v)
	Activity.score(test_worlds[0], ver_factors[0])
	_check(SolverBackend.get_verify_mismatches() == 0,
		"LiveActivity.factors + scores + score VERIFY 0 mismatches")

	# Synthetic factor dict fallback (matches tools/test_mechanics_curse.gd pattern)
	var synth_factor: Dictionary = {
		"profiles": [
			{"good": 1.0, "minion": 2.0, "demon": 3.0, "converted": 5.0},
			{"good": 1.0, "minion": 0.4, "demon": 0.8, "converted": 1.5},
			{"good": 0.5, "minion": 1.2, "demon": 2.4, "converted": 0.9},
		]
	}
	var synth_w: Dictionary = {"evil": 0b010, "demon": 1, "marked": -1, "converted": 2}
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	var gd_syn: float = Activity.score(synth_w, synth_factor)
	SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
	var cs_syn: float = Activity.score(synth_w, synth_factor)
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	var ver_syn: float = Activity.score(synth_w, synth_factor)
	_check(bridge.VerifyScalarFloat64("C2_synth_score", gd_syn, cs_syn, 0.0) and gd_syn == ver_syn and SolverBackend.get_verify_mismatches() == 0,
		"Synthetic factor dictionary registers on demand and matches bit-exactly")

	# 4. Canonical Workshop fixtures parity (core, movement, poison, revenant)
	for fixture in ["core", "movement", "poison", "revenant"]:
		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
		var s_gd = Session.new(692, fixture)
		var v_gd: Dictionary = s_gd.scenario.public_view
		var prop_gd: Dictionary = s_gd.case_data.duplicate(true)
		prop_gd.cards = v_gd.cards.filter(func(c): return c.kind == "report").map(func(c): return c.id)
		var res_gd: Dictionary = Jury.evaluate(v_gd, prop_gd, Ghost.profile(v_gd.people))

		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
		var s_cs = Session.new(692, fixture)
		var v_cs: Dictionary = s_cs.scenario.public_view
		var prop_cs: Dictionary = s_cs.case_data.duplicate(true)
		prop_cs.cards = v_cs.cards.filter(func(c): return c.kind == "report").map(func(c): return c.id)
		var res_cs: Dictionary = Jury.evaluate(v_cs, prop_cs, Ghost.profile(v_cs.people))

		_check(res_gd.effects == res_cs.effects and is_equal_approx(res_gd.after_suspicion, res_cs.after_suspicion),
			"Jury.evaluate bit-exact CSHARP vs GDSCRIPT on fixture '%s'" % fixture)

	# 5. Multi-day full live game bit-exact parity (Seed 42 7-NPC Day 4 & Seed 54875 10-NPC Day 3)
	for cfg in [[42, 7, 4], [54875, 10, 3]]:
		var sd: int = cfg[0]
		var sz: int = cfg[1]
		var d_lim: int = cfg[2]
		var snap_gd: Dictionary = _play_passive(sd, sz, d_lim, SolverBackend.Mode.GDSCRIPT)
		var snap_cs: Dictionary = _play_passive(sd, sz, d_lim, SolverBackend.Mode.CSHARP)
		var snap_ver: Dictionary = _play_passive(sd, sz, d_lim, SolverBackend.Mode.VERIFY)
		_check(snap_gd.rng == snap_cs.rng and snap_gd.suspicions == snap_cs.suspicions and snap_gd.requested == snap_cs.requested and snap_gd.reasons == snap_cs.reasons,
			"Full passive game seed %d (%d NPCs, Day %d) bit-exact between GDSCRIPT and CSHARP" % [sd, sz, d_lim])
		_check(snap_gd.rng == snap_ver.rng and snap_ver.mismatches == 0 and snap_ver.calls > 0,
			"Full passive game seed %d (%d NPCs, Day %d) VERIFY 0 mismatches (%d boundary checks)" % [
				sd, sz, d_lim, snap_ver.calls
			])

	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	Caches.clear_all()
	if _failures == 0:
		print("PASS: Slice C2 C# LiveActivity + Universe Handles (%d checks) matched at --tol 0" % _checks)
	quit(1 if _failures > 0 else 0)

func _play_passive(sd: int, sz: int, day_limit: int, mode: int) -> Dictionary:
	Caches.clear_all()
	SolverBackend.set_mode(mode)
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_c2_logs"
	g.new_case(sd, sz)
	var steps: int = 0
	var reasons_snap: Dictionary = {}
	while g.w.day < day_limit and not g.w.game_over and steps < 350:
		if g.state == "meeting" and not reasons_snap.has(g.w.day):
			var day_r: Dictionary = {}
			for npc in g.w.npcs:
				if npc.alive:
					# reasons_for fills workshop_state.reasons (it returns nothing)
					Ownership.reasons_for(g, npc)
					day_r[npc.id] = npc.workshop_state.get("reasons", {}).duplicate(true)
			reasons_snap[g.w.day] = day_r
		var cmd: String = _passive_command(g)
		g.command(cmd)
		steps += 1
	var sus: Dictionary = {}
	var req: Dictionary = {}
	for npc in g.w.npcs:
		sus[npc.id] = npc.suspicion.duplicate(true)
		req[npc.id] = npc.workshop_state.get("requested", {}).duplicate(true)
	return {
		"rng": str(g.w.rng.state),
		"suspicions": sus,
		"requested": req,
		"reasons": reasons_snap,
		"calls": SolverBackend.get_verify_calls(),
		"mismatches": SolverBackend.get_verify_mismatches(),
	}

func _passive_command(g) -> String:
	# Same passive player as tools/golden_capture.gd.
	match g.state:
		"day": return "wait"
		"approach": return "decline"
		"talk": return "bye"
		"meeting": return "done" if g.town_quiet else "wait"
		"nomination": return "vote no"
		"night": return "sleep"
	return "look"
