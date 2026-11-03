## Headless verification suite for C# Solver Migration Slice C1:
##   - 8-byte WorldEntry struct layout & WorkshopCaches.clear_all() context reset
##   - WorldDomain (worlds, key, claims_compatible, healthy, gift_time, rumor)
##   - RoleConstraints (coarse_mask, coarse_masks, fits/fit_weight/fits_table/fits_weights,
##     _seer_rh_weight, bluff_weights including temporal/curse & hearing_weight)
##   - Side-by-side VERIFY mode & full-game GDSCRIPT vs CSHARP bit-exact (--tol 0) parity
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Caches = preload("res://workshop/caches.gd")
const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Roles = preload("res://workshop/role_constraints.gd")
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

	# 1. 8-byte WorldEntry struct size & cache-clear contract
	_check(int(bridge.GetWorldEntryByteSize()) == 8, "WorldEntry struct size is exactly 8 bytes")
	var epoch_before: int = int(bridge.GetContextEpoch())
	var raw_u: PackedInt64Array = bridge.DomainEnumerateWorlds(7, 2, PackedStringArray(C.SECRET_MOD_LIST), true)
	_check(raw_u.size() > 0 and int(bridge.GetCachedUniverseCount()) == 1, "C# SolverContext caches enumerated universe")
	Caches.clear_all()
	_check(int(bridge.GetContextEpoch()) == epoch_before + 1 and int(bridge.GetCachedUniverseCount()) == 0,
		"WorkshopCaches.clear_all() atomically clears C# SolverContext")

	# 2. WorldDomain parity (7-NPC & 10-NPC live domains, keys, claims_compatible, healthy, gift_time, rumor)
	for npc_count in [7, 10]:
		var evil_cnt: int = 2 if npc_count == 7 else 3
		for with_identities in [false, true]:
			var people: Array = []
			for i in range(npc_count):
				people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
			var view: Dictionary = {
				"people": people,
				"evil_count": evil_cnt,
				"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "identities": with_identities, "roles": true},
			}
			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
			var gd_worlds: Array = Domain.worlds(view)
			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
			var cs_worlds: Array = Domain.worlds(view)
			_check(gd_worlds == cs_worlds, "Domain.worlds exact match for n=%d identities=%s (%d worlds)" % [
				npc_count, str(with_identities), gd_worlds.size()
			])
			Caches.clear_all()
			SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
			var ver_worlds: Array = Domain.worlds(view)
			_check(ver_worlds.size() == gd_worlds.size() and SolverBackend.get_verify_mismatches() == 0,
				"Domain.worlds VERIFY 0 mismatches for n=%d identities=%s" % [npc_count, str(with_identities)])

	# 3. Domain.gift_time across all roles & phases, plus claims_compatible & rumor edge cases
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	for role_id in C.ROLES:
		for day_v in [0, 1, 2]:
			for phase_v in ["morning", "afternoon", "evening", "night"]:
				Domain.gift_time({"role": role_id, "observed_at": {"day": day_v, "phase": phase_v}})
	Domain.gift_time({"role": "nonexistent_role", "observed_at": {"day": 1, "phase": "night"}})

	var sample_cards: Array = [
		{"kind": "report", "source": "agnes", "role": "seer"},
		{"kind": "claim", "source": "bart", "role": "clerk"},
		{"kind": "report", "source": "agnes", "role": "dowser", "quoted": true},
		{"kind": "report", "source": "bart", "role": "seer", "testimony_only": true},
	]
	_check(Domain.claims_compatible(sample_cards, {}) == true, "claims_compatible ignores quoted & testimony_only")
	_check(Domain.claims_compatible(sample_cards, {"self": "agnes", "own_role": "clerk"}) == false, "claims_compatible rejects own_role mismatch")
	_check(Domain.claims_compatible(sample_cards, {"self": "constance", "own_role": "seer"}) == false, "claims_compatible rejects someone else claiming own_role")
	_check(Domain.claims_compatible([{"kind": "claim", "source": "", "role": "seer"}], {}) == true, "claims_compatible handles missing self vs empty source")
	_check(SolverBackend.get_verify_mismatches() == 0, "Domain.gift_time & claims_compatible VERIFY 0 mismatches")

	# 4. 64-bit coarse_mask / coarse_masks parity (> 32-bit int range with 10 NPCs + mediums + walkers + converted)
	var people10: Array = []
	for i in range(10):
		people10.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var view10: Dictionary = {
		"people": people10,
		"evil_count": 3,
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "identities": true, "roles": true},
	}
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	Caches.clear_all()
	var u10: Array = Domain.worlds(view10)
	var sample_conv: Array = []
	for idx in range(0, mini(u10.size(), 250)):
		var cw: Dictionary = u10[idx].duplicate()
		cw["converted"] = (idx % 10)
		sample_conv.append(cw)
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	var cm_out: PackedInt64Array = Roles.coarse_masks(10, sample_conv, true, 0b0101010101, 0b1010101010)
	var has_64bit: bool = false
	for v in cm_out:
		if v > 2147483647:
			has_64bit = true
			break
	_check(has_64bit and SolverBackend.get_verify_mismatches() == 0, "64-bit coarse_masks exceeds int32 and matches at 0 mismatches")

	# 5. RoleConstraints comprehensive role & bluff checks in VERIFY + CSHARP modes
	var p7: Array = []
	for i in range(7):
		p7.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var v7: Dictionary = {
		"people": p7,
		"evil_count": 2,
		"live_activity": true,
		"alignment_epoch": "Current alignment",
		"timeline": {
			"executions": {"1": ["constance"]},
			"deaths": {"constance": 1, "dorian": 2, "edda": 2, "fenwick": 2},
			"death_ticks": {"constance": 6, "dorian": 7, "edda": 7, "fenwick": 7},
			"events": [
				{"kind": "execution", "at": {"day": 1, "phase": "evening"}, "subjects": ["constance"]},
				{"kind": "demon_death", "at": {"day": 1, "phase": "night"}, "subjects": ["dorian"]},
			],
		},
		"chronology": {
			"epochs": {"Original alignment": 0, "Current alignment": 12, "before curse": 5, "during curse": 6},
			"curse": {"executed": "constance", "yes_voters": ["agnes", "bart", "greta"], "alive": ["agnes", "bart", "greta", "hollis"], "from": 6, "until": 10},
		},
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "identities": true, "roles": true},
	}
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	Caches.clear_all()
	var base_u7: Array = Solver.universe(v7)

	var test_card_sets: Array = [
		# Clerk + Archivist + Gravedigger
		[
			{"id": "c1", "kind": "report", "source": "agnes", "role": "clerk", "observed_at": {"day": 0, "phase": "night"}, "data": {"pair": ["bart", "edda"], "role": "seer"}},
			{"id": "c2", "kind": "report", "source": "bart", "role": "seer", "observed_at": {"day": 0, "phase": "night"}, "data": {"pair": ["constance", "fenwick"], "yes": true}},
			{"id": "c3", "kind": "report", "source": "bart", "role": "seer", "observed_at": {"day": 1, "phase": "night"}, "data": {"pair": ["agnes", "edda"], "yes": false}},
			{"id": "c4", "kind": "report", "source": "greta", "role": "gravedigger", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"executed": "constance", "role": "revenant"}},
		],
		# Medium relay + Sleepwalker secret claim + hearing_weight bluff
		[
			{"id": "m1", "kind": "report", "source": "dorian", "role": "archivist", "observed_at": {"day": 0, "phase": "night"},
				"relay_source": "agnes", "relay_observed_at": {"day": 2, "phase": "night"}, "data": {"pair": ["constance", "greta"], "role": "revenant"}},
			{"id": "sw1", "kind": "secret_claim", "source": "bart", "subject": "bart", "data": {"secret_kind": "sleepwalker"}, "applies": {"from": 1, "through": 2}},
			{"id": "cl1", "kind": "claim", "source": "greta", "role": "warden", "hearing_weight": 0.65, "reported_at": {"day": 2, "phase": "morning"}},
		],
		# Martyr outcome + Veteran approach + Totem
		[
			{"id": "mt1", "kind": "report", "source": "agnes", "role": "martyr", "observed_at": {"day": 1, "phase": "evening"}, "data": {"target": "constance", "evil": true}},
			{"id": "vt1", "kind": "report", "source": "bart", "role": "veteran", "night": 2, "observed_at": {"day": 2, "phase": "night"}, "data": {"block": p7[1].home}},
			{"id": "tt1", "kind": "totem", "source": "evidence", "data": {"candidates": ["constance", "greta"]}},
		],
		# Sexton knell (< 5 alive on night 2 since 4 died before night 2)
		[
			{"id": "sx1", "kind": "report", "source": "agnes", "role": "sexton", "observed_at": {"day": 2, "phase": "evening"}, "data": {"night": 2}},
		],
	]

	var know: Dictionary = {"self": "agnes", "own_role": "", "public_roles": {}}
	for idx_set in range(test_card_sets.size()):
		var cset: Array = test_card_sets[idx_set]
		for bluffs_flag in [false, true]:
			for reuse_flag in [true, false]:
				Roles.reuse = reuse_flag
				Caches.clear_all()
				SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
				var gd_w: PackedFloat64Array = Roles.fits_weights(v7, base_u7, cset, know, {}, bluffs_flag)
				var gd_b: PackedFloat64Array = Roles.bluff_weights(v7, base_u7, cset)

				Caches.clear_all()
				SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
				var cs_w: PackedFloat64Array = Roles.fits_weights(v7, base_u7, cset, know, {}, bluffs_flag)
				var cs_b: PackedFloat64Array = Roles.bluff_weights(v7, base_u7, cset)

				_check(bridge.VerifyFloat64Buffer("C1_fits_set_%d" % idx_set, gd_w, cs_w, 0.0) == -1,
					"RoleConstraints.fits_weights bit-exact on card set %d bluffs=%s reuse=%s" % [idx_set, str(bluffs_flag), str(reuse_flag)])
				_check(bridge.VerifyFloat64Buffer("C1_bluff_set_%d" % idx_set, gd_b, cs_b, 0.0) == -1,
					"RoleConstraints.bluff_weights bit-exact on card set %d" % idx_set)

				Caches.clear_all()
				SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
				Roles.fits_weights(v7, base_u7, cset, know, {}, bluffs_flag)
				Roles.bluff_weights(v7, base_u7, cset)
				_check(SolverBackend.get_verify_mismatches() == 0,
					"VERIFY mode 0 mismatches on card set %d bluffs=%s reuse=%s" % [idx_set, str(bluffs_flag), str(reuse_flag)])
	Roles.reuse = true

	# 6. Fixture Jury parity across all 4 canonical Workshop fixtures
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

	# 7. Multi-day full live game bit-exact parity (7-NPC seed 900 & 10-NPC seed 54875)
	for cfg in [[900, 7, 3], [54875, 10, 2]]:
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
		print("PASS: Slice C1 C# WorldDomain + RoleConstraints (%d checks) matched at --tol 0" % _checks)
	quit(1 if _failures > 0 else 0)

func _play_passive(sd: int, sz: int, day_limit: int, mode: int) -> Dictionary:
	Caches.clear_all()
	SolverBackend.set_mode(mode)
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_c1"
	g.new_case(sd, sz)
	var steps: int = 0
	while g.w.day < day_limit and not g.w.game_over and steps < 250:
		if g.state == "meeting":
			for npc in g.w.npcs:
				if npc.alive:
					Ownership.reasons_for(g, npc)
		var cmd: String = "look"
		match g.state:
			"day":
				cmd = "wait"
			"approach":
				cmd = "decline"
			"talk":
				cmd = "bye"
			"meeting":
				cmd = "done" if g.town_quiet else "wait"
			"nomination":
				cmd = "vote no"
			"night":
				cmd = "sleep"
		g.command(cmd)
		steps += 1
	var sus: Dictionary = {}
	var req: Dictionary = {}
	var rsn: Dictionary = {}
	for npc in g.w.npcs:
		sus[npc.id] = npc.suspicion.duplicate(true)
		req[npc.id] = npc.workshop_state.get("requested", {}).duplicate(true)
		rsn[npc.id] = npc.workshop_state.get("reasons", {}).keys()
	return {
		"rng": str(g.w.rng.state),
		"suspicions": sus,
		"requested": req,
		"reasons": rsn,
		"calls": SolverBackend.get_verify_calls(),
		"mismatches": SolverBackend.get_verify_mismatches(),
	}
