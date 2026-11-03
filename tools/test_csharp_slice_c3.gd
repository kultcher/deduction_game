## Headless verification suite for C# Solver Migration Slice C3:
##   1. Float literal IEEE-754 bit-exactness audit (GdFloor1e30 + C3 constants via VerifyFloat64Buffer)
##   2. Arena lifecycle & WorkshopCaches.clear_all() reset across CompiledCases, Programs & Circuits
##   3. SolverKernel parity (world_bits, sig_groups, valid_table, report_table across all CONTENT_ROLES,
##      answers, testimony_only shapes & curse events, solve, _movement, question_table, analyze, conflicts)
##   4. CaseEvalKernel parity (checkpoint_v5 specimens, sparse own_reports + synthetic _own_cache override,
##      prior_k = -1.0 override, theory_bias, test_factors, theory_fit, pivotal, and Revenant curse views)
##   5. ChannelSumProduct & FactoredChannels parity (compile, evaluate, circuit, run, zero-weight rows,
##      30 independent sources, 7/10-NPC live & relay & coupled & fixture FactoredChannels.assess)
##   6. Full multi-day passive games on Seed 42 (7 NPCs, Day 4) & Seed 54875 (10 NPCs, Day 3) at --tol 0
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Caches = preload("res://workshop/caches.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Sum = preload("res://workshop/channel_sum_product.gd")
const Channels = preload("res://workshop/evidence_channels.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const ChannelOracle = preload("res://workshop/channel_likelihood.gd")
const Ownership = preload("res://game/workshop_ownership.gd")

const CHECKPOINT_PATH = "res://tests/fixtures/workshop_checkpoint_v5.json"

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

	_audit_float_literals(bridge)
	_test_arena_clear(bridge)
	_test_solver_kernel(bridge)
	_test_case_eval_kernel(bridge)
	_test_sum_product_and_factored(bridge)
	_test_passive_games()

	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	Caches.clear_all()
	if _failures == 0:
		print("PASS: Slice C3 C# Solver + CaseEval + ChannelSumProduct + FactoredChannels (%d checks) matched at --tol 0" % _checks)
	quit(1 if _failures > 0 else 0)

func _audit_float_literals(bridge) -> void:
	# Verify Godot's 1e-30 literal matches SolverBridge.GetGdFloor1e30() bit-for-bit:
	var gd_1e30: float = 1e-30
	var cs_1e30: float = float(bridge.GetGdFloor1e30())
	var gd_bytes: PackedByteArray = var_to_bytes(gd_1e30)
	var cs_bytes: PackedByteArray = var_to_bytes(cs_1e30)
	_check(gd_bytes == cs_bytes and bridge.VerifyScalarFloat64("Audit.1e-30", gd_1e30, cs_1e30, 0.0),
		"GdFloor1e30 matches GDScript 1e-30 literal raw var_to_bytes bits")

	# Verify exp/pow/lerpf batch on C3 literals at 0 ULP:
	var xs := PackedFloat64Array([0.02, 0.98, 1.5, -2.0, 0.5, 1e-9, 1e-12, 9.0e18, CaseEval.DEFAULT_ERR, CaseEval.OWN_ERR, CaseEval.LR_WEAK, CaseEval.LR_MODERATE, CaseEval.LR_STRONG, Tuning.Workshop.PRIOR_K])
	var ops := PackedInt32Array()
	var ys := PackedFloat64Array()
	var gd_expected := PackedFloat64Array()
	for i in range(xs.size()):
		ops.append(5) # GodotLerpf(1.0, x, 1.0) == x when evaluated in double
		ys.append(1.0)
		gd_expected.append(lerpf(1.0, xs[i], 1.0))
	var cs_lerp: PackedFloat64Array = bridge.EvalMathBatch(ops, xs, ys)
	_check(bridge.VerifyFloat64Buffer("Audit.c3_constants", gd_expected, cs_lerp, 0.0) == -1,
		"All C3 tuning and boundary float constants preserve exact 64-bit representation across bridge")

func _make_live_view(count: int, with_curse: bool = false) -> Dictionary:
	var people: Array = []
	for i in range(count):
		people.append({
			"id": C.CAST[i].id,
			"name": C.CAST[i].name,
			"home": C.BLOCKS.keys()[i % 4],
			"alive": true,
		})
	var view: Dictionary = {
		"people": people,
		"evil_count": 2 if count == 7 else 3,
		"alignment_epoch": "Current alignment" if with_curse else "Original alignment",
		"live_activity": true,
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "identities": true, "roles": true},
		"timeline": {
			"deaths": {people[2].id: 2},
			"executions": {"1": [people[2].id]},
			"events": [{"kind": "execution", "subjects": [people[2].id], "at": {"day": 1, "phase": "evening"}}],
		},
		"cards": [],
	}
	if with_curse:
		view["chronology"] = {
			"epochs": {"Original alignment": 0, "during curse": 7, "Current alignment": 7},
			"curse": {
				"executed": people[2].id,
				"yes_voters": [people[0].id, people[1].id, people[3].id, people[4].id],
				"alive": [people[0].id, people[1].id, people[3].id, people[4].id, people[5].id, people[6].id],
				"from": 6,
				"until": 12,
			},
		}
	return view

func _test_arena_clear(bridge) -> void:
	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
	var v7: Dictionary = _make_live_view(7)
	v7.cards = [
		{"id": "c_s1", "kind": "report", "source": v7.people[0].id, "role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "data": {"count": 2}},
		{"id": "c_d1", "kind": "report", "source": v7.people[1].id, "role": "dowser", "night": -1, "observed_at": {"day": 1, "phase": "morning"}, "data": {"group": [v7.people[2].id, v7.people[3].id, v7.people[4].id], "count": 1}},
	]
	var cd: Dictionary = Solver.empty_case()
	cd.cards = ["c_s1", "c_d1"]
	cd.conclusion = {"type": "evil", "target": v7.people[2].id, "at": v7.alignment_epoch}
	CaseEval.evaluate(v7, cd)
	var prog: Dictionary = Sum.compile([[0], [1], [0, 1]])
	Sum.circuit(prog, [null, null, PackedFloat64Array([1.0, 1.0, 1.0, 0.0])])
	_check(int(bridge.GetRegisteredCompiledCaseCount()) > 0 and int(bridge.GetRegisteredProgramCount()) > 0 and int(bridge.GetRegisteredCircuitCount()) > 0,
		"CSHARP mode registers CompiledCase, Program, and Circuit handles in SolverContext")
	Caches.clear_all()
	_check(int(bridge.GetRegisteredCompiledCaseCount()) == 0 and int(bridge.GetRegisteredProgramCount()) == 0 and int(bridge.GetRegisteredCircuitCount()) == 0,
		"WorkshopCaches.clear_all() resets CompiledCase, Program, and Circuit arenas to 0")

func _test_solver_kernel(bridge) -> void:
	for with_curse in [false, true]:
		var v: Dictionary = _make_live_view(7, with_curse)
		var p: Array = v.people
		var cards: Array = [
			{"id": "r_surv", "kind": "report", "source": p[0].id, "role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "data": {"count": 2}},
			{"id": "r_dows", "kind": "report", "source": p[1].id, "role": "dowser", "night": -1, "observed_at": {"day": 1, "phase": "morning"}, "data": {"group": [p[2].id, p[3].id, p[4].id], "count": 1}},
			{"id": "r_rumor", "kind": "report", "source": p[3].id, "role": "rumormonger", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "data": {"secret": "marked", "pair": [p[4].id, p[5].id]}},
			{"id": "r_ward", "kind": "report", "source": p[4].id, "role": "warden", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"target": p[5].id, "saved": true}},
			{"id": "r_nw", "kind": "report", "source": p[5].id, "role": "nightwatch", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"block": p[1].home, "seen": [p[1].id]}},
			{"id": "r_gd", "kind": "report", "source": p[6].id, "role": "gravedigger", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"executed": p[2].id, "role": "revenant" if with_curse else "poisoner"}},
			{"id": "r_med_duty", "kind": "report", "source": p[0].id, "role": "medium", "duty_only": true, "night": 2, "observed_at": {"day": 2, "phase": "night"}, "data": {"block": p[2].home}},
			{"id": "t_seer", "kind": "report", "testimony_only": true, "source": p[1].id, "role": "seer", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "reported_at": {"day": 2, "phase": "morning"}, "data": {"pair": [p[2].id, p[3].id], "yes": true}},
			{"id": "t_arch", "kind": "report", "testimony_only": true, "source": p[3].id, "role": "archivist", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "reported_at": {"day": 2, "phase": "morning"}, "data": {"pair": [p[2].id, p[6].id], "role": "revenant"}},
			{"id": "t_clerk", "kind": "report", "testimony_only": true, "source": p[4].id, "role": "clerk", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "reported_at": {"day": 2, "phase": "morning"}, "data": {"pair": [p[0].id, p[1].id], "role": "surveyor"}},
			{"id": "t_rum", "kind": "report", "testimony_only": true, "source": p[5].id, "role": "rumormonger", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "reported_at": {"day": 2, "phase": "morning"}, "data": {"secret": "lovers", "pair": [p[0].id, p[1].id]}},
		]
		if with_curse:
			cards.append({"id": "ev_curse", "kind": "event", "event": "curse", "source": "town", "observed_at": {"day": 2, "phase": "morning"}, "data": {}})
		v.cards = cards

		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
		var gd_tables: Array = []
		for c in cards:
			gd_tables.append(Solver.report_table(v, c))
		var gd_surv_ans: PackedByteArray = Solver.report_table(v, cards[0], [p[2].id], [p[3].home], [p[4].id])
		var gd_dows_ans: PackedByteArray = Solver.report_table(v, cards[1], [p[3].id], [], [p[3].id])
		var gd_q_misled: PackedByteArray = Solver.question_table(v, {"type": "misled", "target": p[0].id, "report": "r_surv", "at": v.alignment_epoch})
		var gd_q_unrel: PackedByteArray = Solver.question_table(v, {"type": "unreliable", "target": p[0].id, "report": "r_surv", "at": v.alignment_epoch})
		var gd_solve: Dictionary = Solver.solve(v, [cards[0], cards[1], cards[3]], {p[0].id: "good", p[2].id: "evil"}, {"r_dows": {"positive": [p[2].id]}}, {"self": p[0].id, "own_role": "surveyor", "good": [p[0].id]}, v.alignment_epoch)

		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
		var all_eq: bool = true
		for idx_c in range(cards.size()):
			if Solver.report_table(v, cards[idx_c]) != gd_tables[idx_c]:
				all_eq = false
		var cs_surv_ans: PackedByteArray = Solver.report_table(v, cards[0], [p[2].id], [p[3].home], [p[4].id])
		var cs_dows_ans: PackedByteArray = Solver.report_table(v, cards[1], [p[3].id], [], [p[3].id])
		var cs_q_misled: PackedByteArray = Solver.question_table(v, {"type": "misled", "target": p[0].id, "report": "r_surv", "at": v.alignment_epoch})
		var cs_q_unrel: PackedByteArray = Solver.question_table(v, {"type": "unreliable", "target": p[0].id, "report": "r_surv", "at": v.alignment_epoch})
		var cs_solve: Dictionary = Solver.solve(v, [cards[0], cards[1], cards[3]], {p[0].id: "good", p[2].id: "evil"}, {"r_dows": {"positive": [p[2].id]}}, {"self": p[0].id, "own_role": "surveyor", "good": [p[0].id]}, v.alignment_epoch)

		_check(all_eq and cs_surv_ans == gd_surv_ans and cs_dows_ans == gd_dows_ans,
			"Solver.report_table bit-exact across all roles, testimony shapes & answers (curse=%s)" % str(with_curse))
		_check(cs_q_misled == gd_q_misled and cs_q_unrel == gd_q_unrel,
			"Solver.question_table bit-exact on misled & unreliable conclusions (curse=%s)" % str(with_curse))
		_check(cs_solve.worlds.size() == gd_solve.worlds.size() and cs_solve.movement_ok == gd_solve.movement_ok and cs_solve.movement == gd_solve.movement,
			"Solver.solve candidate + role + movement filtering bit-exact (curse=%s)" % str(with_curse))

		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
		for c in cards:
			Solver.report_table(v, c)
		Solver.question_table(v, {"type": "misled", "target": p[0].id, "report": "r_surv", "at": v.alignment_epoch})
		Solver.solve(v, [cards[0], cards[1], cards[3]], {p[0].id: "good", p[2].id: "evil"}, {"r_dows": {"positive": [p[2].id]}}, {"self": p[0].id, "own_role": "surveyor", "good": [p[0].id]}, v.alignment_epoch)
		_check(SolverBackend.get_verify_mismatches() == 0 and SolverBackend.get_verify_calls() > 0,
			"Solver VERIFY mode 0 mismatches (curse=%s)" % str(with_curse))

func _eval_matches_exact(a: Dictionary, b: Dictionary) -> bool:
	if a.prior != b.prior or a.posterior != b.posterior or a.lr != b.lr:
		return false
	if a.category != b.category or a.impossible != b.impossible or a.consistent != b.consistent:
		return false
	if a.credence != b.credence or a.theory_fit != b.theory_fit:
		return false
	if a.people != b.people or a.acceptance != b.acceptance or a.rivals != b.rivals:
		return false
	if a.get("pivotal", []) != b.get("pivotal", []):
		return false
	return true

func _test_case_eval_kernel(bridge) -> void:
	var data = JSON.parse_string(FileAccess.open(CHECKPOINT_PATH, FileAccess.READ).get_as_text())
	for ex in data.examples:
		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
		var gd_l: Dictionary = CaseEval.evaluate(ex.view, ex.case, ex.listener)
		var gd_n: Dictionary = CaseEval.evaluate(ex.view, ex.case)
		var gd_an: Dictionary = Solver.analyze(ex.view, ex.case, ex.listener.get("knowledge", {}))

		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
		var cs_l: Dictionary = CaseEval.evaluate(ex.view, ex.case, ex.listener)
		var cs_n: Dictionary = CaseEval.evaluate(ex.view, ex.case)
		var cs_an: Dictionary = Solver.analyze(ex.view, ex.case, ex.listener.get("knowledge", {}))

		_check(_eval_matches_exact(gd_l, cs_l) and _eval_matches_exact(gd_n, cs_n) and gd_an == cs_an,
			"Checkpoint v5 specimen '%s' bit-exact in CaseEval.evaluate & Solver.analyze" % str(ex.name))

		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
		CaseEval.evaluate(ex.view, ex.case, ex.listener)
		CaseEval.evaluate(ex.view, ex.case)
		Solver.analyze(ex.view, ex.case, ex.listener.get("knowledge", {}))
		_check(SolverBackend.get_verify_mismatches() == 0,
			"Checkpoint v5 specimen '%s' VERIFY 0 mismatches" % str(ex.name))

	# Test sparse private states, synthetic _own_cache override, theory_bias, answers/positions theory_fit, and prior_k = -1.0:
	var core: Dictionary = data.examples[0]
	var view_p: Dictionary = core.view.duplicate(true)
	var own_cards: Array = view_p.cards.filter(func(c): return c.kind == "report").slice(0, 3)
	var extra_own: Dictionary = own_cards[0].duplicate(true)
	extra_own.id += ":c3-later"
	extra_own["fact_id"] = extra_own.id
	extra_own.observed_at.day += 1
	view_p.cards.append(extra_own)
	own_cards.append(extra_own)

	var val_case: Dictionary = Solver.empty_case()
	val_case.conclusion = core.case.conclusion.duplicate(true)
	val_case.cards = view_p.cards.filter(func(c): return c not in own_cards).map(func(c): return c.id)
	val_case.positions = {"constance": "evil"}
	var lis_p: Dictionary = core.listener.duplicate(true)
	lis_p.knowledge.own_reports = own_cards.map(func(c): return c.id)
	lis_p["theory_bias"] = {"target": "constance", "position": "evil", "factor": 1.35}

	var saved_pk: float = CaseEval.prior_k
	for pk in [saved_pk, -1.0]:
		CaseEval.prior_k = pk
		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
		var gd_e: Dictionary = CaseEval.evaluate(view_p, val_case, lis_p)
		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
		var cs_e: Dictionary = CaseEval.evaluate(view_p, val_case, lis_p)
		Caches.clear_all()
		SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
		CaseEval.evaluate(view_p, val_case, lis_p)
		_check(_eval_matches_exact(gd_e, cs_e) and SolverBackend.get_verify_mismatches() == 0,
			"CaseEval own_reports + theory_bias + theory_fit + prior_k=%.2f bit-exact at --tol 0" % pk)
	CaseEval.prior_k = saved_pk

	# Test live Revenant curse CaseEval parity:
	var vc: Dictionary = _make_live_view(7, true)
	vc.cards = [
		{"id": "c_ev", "kind": "event", "event": "curse", "source": "town", "observed_at": {"day": 2, "phase": "morning"}, "data": {}},
		{"id": "c_s", "kind": "report", "source": vc.people[0].id, "role": "surveyor", "night": 2, "observed_at": {"day": 2, "phase": "night"}, "data": {"count": 2}},
		{"id": "c_d", "kind": "report", "source": vc.people[1].id, "role": "dowser", "night": -1, "observed_at": {"day": 2, "phase": "morning"}, "data": {"group": [vc.people[2].id, vc.people[3].id, vc.people[4].id], "count": 2}},
	]
	var cc_case: Dictionary = Solver.empty_case()
	cc_case.cards = ["c_ev", "c_s", "c_d"]
	cc_case.conclusion = {"type": "evil", "target": vc.people[3].id, "at": "Current alignment"}
	var cc_lis: Dictionary = {
		"id": vc.people[0].id,
		"suspicion": {vc.people[3].id: 0.55, vc.people[4].id: 0.25},
		"npc_trust": {vc.people[1].id: 0.75},
		"reading_reliability": {"c_d": 0.85},
		"knowledge": {"self": vc.people[0].id, "own_role": "surveyor", "good": [vc.people[0].id], "good_epoch": "Original alignment"},
	}
	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	var gd_vc: Dictionary = CaseEval.evaluate(vc, cc_case, cc_lis)
	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
	var cs_vc: Dictionary = CaseEval.evaluate(vc, cc_case, cc_lis)
	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	CaseEval.evaluate(vc, cc_case, cc_lis)
	_check(_eval_matches_exact(gd_vc, cs_vc) and SolverBackend.get_verify_mismatches() == 0,
		"CaseEval live Revenant curse evaluation bit-exact at --tol 0")

func _test_sum_product_and_factored(bridge) -> void:
	# 1. ChannelSumProduct standalone + zero-weight derivatives + 30 independent sources:
	var scopes: Array = [[0], [1], [0, 1], [0], [1]]
	var vals1: Array = [PackedFloat64Array([0.2, 0.8]), PackedFloat64Array([0.3, 0.7]), PackedFloat64Array([1.0, 1.0, 1.0, 0.0]), PackedFloat64Array([1.0, 1.0]), PackedFloat64Array([1.0, 1.0])]
	var vals2: Array = [PackedFloat64Array([0.0, 1.0]), PackedFloat64Array([0.3, 0.7]), PackedFloat64Array([1.0, 1.0, 1.0, 0.0]), PackedFloat64Array([1.0, 1.0]), PackedFloat64Array([1.0, 1.0])]

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	var gd_prog: Dictionary = Sum.compile(scopes)
	var gd_ev1: Dictionary = Sum.evaluate(gd_prog, vals1)
	var gd_ev2: Dictionary = Sum.evaluate(gd_prog, vals2)
	var gd_cir: Dictionary = Sum.circuit(gd_prog, [null, null, vals1[2], null, null])
	var gd_run1: Dictionary = Sum.run(gd_cir, vals1)
	var gd_run2: Dictionary = Sum.run(gd_cir, vals2)

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
	var cs_prog: Dictionary = Sum.compile(scopes)
	var cs_ev1: Dictionary = Sum.evaluate(cs_prog, vals1)
	var cs_ev2: Dictionary = Sum.evaluate(cs_prog, vals2)
	var cs_cir: Dictionary = Sum.circuit(cs_prog, [null, null, vals1[2], null, null])
	var cs_run1: Dictionary = Sum.run(cs_cir, vals1)
	var cs_run2: Dictionary = Sum.run(cs_cir, vals2)

	_check(gd_ev1 == cs_ev1 and gd_ev2 == cs_ev2 and gd_run1 == cs_run1 and gd_run2 == cs_run2,
		"ChannelSumProduct compile/evaluate/circuit/run bit-exact including zero-weight rows")

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	var v_prog: Dictionary = Sum.compile(scopes)
	Sum.evaluate(v_prog, vals1)
	Sum.evaluate(v_prog, vals2)
	var v_cir: Dictionary = Sum.circuit(v_prog, [null, null, vals1[2], null, null])
	Sum.run(v_cir, vals1)
	Sum.run(v_cir, vals2)

	var scopes30: Array = []
	var vals30: Array = []
	for i in range(30):
		scopes30.append([i])
		vals30.append(PackedFloat64Array([0.2, 0.8]))
	var p30: Dictionary = Sum.compile(scopes30)
	var r30: Dictionary = Sum.evaluate(p30, vals30)
	_check(p30.peak == 2 and p30.steps.size() == 30 and is_equal_approx(r30.total, 1.0) and SolverBackend.get_verify_mismatches() == 0,
		"ChannelSumProduct VERIFY 0 mismatches across 30 independent sources")

	# 2. FactoredChannels.assess across 7-NPC live (with relay & coupled Lamplighter) and compact representatives:
	var vf: Dictionary = _make_live_view(7)
	var pf: Array = vf.people
	var f_cards: Array = [
		{"id": "survey", "kind": "report", "source": pf[0].id, "role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "data": {"count": 2}},
		{"id": "seer", "kind": "report", "source": pf[2].id, "role": "seer", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"pair": [pf[3].id, pf[4].id], "yes": true}},
		{"id": "relay", "kind": "report", "accuracy_origin": "seer", "source": pf[2].id, "relay_source": pf[1].id, "role": "seer", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "relay_observed_at": {"day": 2, "phase": "night"}, "data": {"pair": [pf[3].id, pf[4].id], "yes": true}},
		{"id": "lamp", "kind": "report", "source": pf[5].id, "role": "lamplighter", "night": 2, "observed_at": {"day": 2, "phase": "night"}, "data": {"count": 1}},
		{"id": "sight", "kind": "sighting", "source": pf[6].id, "subject": pf[1].id, "subjects": [pf[1].id], "block": pf[2].home, "night": 2, "observed_at": {"day": 2, "phase": "night"}},
	]
	vf.cards = f_cards
	var f_know: Dictionary = {"self": pf[6].id, "own_role": "warden", "good": [pf[6].id]}
	var rates: Dictionary = {}
	var q_map: Dictionary = {}
	for ch in Channels.compile(vf, f_cards).channels:
		rates[ch.key] = {"healthy": 0.83, "impaired": 0.0} if ch.kind == "gift_accuracy" else 0.72
	for fc in f_cards:
		if fc.kind == "report":
			q_map[fc.get("accuracy_origin", fc.id)] = CaseEval.chance_content(vf, fc)

	var f_case: Dictionary = Solver.empty_case()
	f_case.cards = f_cards.map(func(c): return c.id)
	f_case.conclusion = {"type": "evil", "target": pf[3].id, "at": vf.alignment_epoch}

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	var gd_cc: Dictionary = CaseEval.compile(vf, f_cards, f_case)
	var gd_full: Dictionary = Factored.assess(vf, f_cards, f_know, rates, q_map, ["survey"])
	var gd_comp: Dictionary = Factored.assess(vf, f_cards, f_know, rates, q_map, ["survey"], gd_cc.rep, gd_cc.count)

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.CSHARP)
	var cs_cc: Dictionary = CaseEval.compile(vf, f_cards, f_case)
	var cs_full: Dictionary = Factored.assess(vf, f_cards, f_know, rates, q_map, ["survey"])
	var cs_comp: Dictionary = Factored.assess(vf, f_cards, f_know, rates, q_map, ["survey"], cs_cc.rep, cs_cc.count)

	_check(gd_full.post == cs_full.post and gd_full.base == cs_full.base and gd_full.held == cs_full.held and gd_full.acceptance == cs_full.acceptance and gd_full.consistent == cs_full.consistent and gd_full.states == cs_full.states,
		"FactoredChannels.assess full universe bit-exact between GDSCRIPT and CSHARP")
	_check(gd_comp.post == cs_comp.post and gd_comp.base == cs_comp.base and gd_comp.held == cs_comp.held and gd_comp.acceptance == cs_comp.acceptance and gd_comp.consistent == cs_comp.consistent,
		"FactoredChannels.assess compact class representatives bit-exact between GDSCRIPT and CSHARP")

	Caches.clear_all()
	SolverBackend.set_mode(SolverBackend.Mode.VERIFY)
	var ver_cc: Dictionary = CaseEval.compile(vf, f_cards, f_case)
	Factored.assess(vf, f_cards, f_know, rates, q_map, ["survey"])
	Factored.assess(vf, f_cards, f_know, rates, q_map, ["survey"], ver_cc.rep, ver_cc.count)
	_check(SolverBackend.get_verify_mismatches() == 0,
		"FactoredChannels.assess VERIFY 0 mismatches on full and compact runs")

func _test_passive_games() -> void:
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

func _play_passive(sd: int, sz: int, day_limit: int, mode: int) -> Dictionary:
	Caches.clear_all()
	SolverBackend.set_mode(mode)
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_c3_logs"
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
