extends SceneTree

const Tuning = preload("res://sim/tuning.gd")

func _init() -> void:
	var failures: int = 0
	SolverBackend.reset_profile()
	SolverBackend.clear_context()

	# 0. Verify C0b re-entrant hierarchical stage timer & boundary counter logic
	SolverBackend.profiling_enabled = true
	var t_outer: int = SolverBackend.begin_stage("outer_prep")
	SolverBackend.record_boundary_call("WorldDomain.worlds", 25)
	var t_inner: int = SolverBackend.begin_stage("world_domain")
	var t_nested: int = SolverBackend.begin_stage("world_domain")
	SolverBackend.end_stage(t_nested)
	SolverBackend.end_stage(t_inner)
	SolverBackend.end_stage(t_outer)
	var stats: Dictionary = SolverBackend.get_stage_stats()
	var b_stats: Dictionary = SolverBackend.get_boundary_stats()
	var report_txt: String = SolverBackend.format_profile_report("C0b Self-Test")
	SolverBackend.profiling_enabled = false
	SolverBackend.reset_profile()
	if int(stats.get("outer_prep", {}).get("calls", 0)) != 1 \
		or int(stats.get("world_domain", {}).get("calls", 0)) != 2 \
		or int(stats.get("pack_inputs", {}).get("self_usec", 0)) != 25 \
		or int(b_stats.get("WorldDomain.worlds", {}).get("calls", 0)) != 1 \
		or not ("Boundary Calls" in report_txt):
		push_error("FAIL: C0b hierarchical stage profiler self-test failed")
		failures += 1
	else:
		print("PASS: C0b hierarchical stage profiler & boundary call counters verified")

	if not SolverBackend.is_csharp_available():
		print("SKIP: C# SolverBridge not loaded (non-Mono binary)")
		quit(1 if failures > 0 else 0)
		return

	var bridge = SolverBackend._bridge()
	var ops := PackedInt32Array()
	var xs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	var expected := PackedFloat64Array()

	# 1. Halves rounding away from zero (must NOT banker's round to even)
	for v in [-3.5, -2.5, -1.5, -0.5, -0.0, 0.0, 0.5, 1.5, 2.5, 3.5, 0.125, -0.875]:
		ops.append(0)
		xs.append(v)
		ys.append(0.0)
		expected.append(round(v))

	# 2. snappedf across all workshop step sizes (including jury/session 1e-9 and circumstantial 1e-4)
	for v in [-1.5, -0.445, -0.015, 0.0, 0.015, 0.045, 0.1, 0.123456789012345, 0.43, 0.5, 1.25, 1.5]:
		for step in [0.000000001, 0.0001, 0.001, 0.005, 0.01, 0.05, 0.25]:
			ops.append(1)
			xs.append(v)
			ys.append(step)
			expected.append(snappedf(v, step))

	# 3. Kernel exp(prior_k * clampf(suspicion, 0.0, 1.5)) range (case_eval.gd:653)
	for pk in [Tuning.Workshop.PRIOR_K, 0.5, 1.0, 2.0, 2.5, 3.0, 4.0]:
		for s_step in range(0, 31):
			var s: float = float(s_step) * 0.05
			var arg: float = pk * clampf(s, 0.0, 1.5)
			ops.append(2); xs.append(arg); ys.append(0.0); expected.append(exp(arg))
			ops.append(2); xs.append(-arg); ys.append(0.0); expected.append(exp(-arg))

	# 4. Kernel log(x) across movement/public/speech/reason_attribution likelihood ratios [1e-12 .. 1e+12]
	var log_vals := [
		1e-12, 1e-9, 1e-6, 0.0005, 0.005, 0.015, 0.045, 0.05, 0.08, 0.1, 0.12,
		0.2, 0.25, 0.3333333333333333, 0.45, 0.5, 0.55, 0.7, 0.75, 0.9, 0.92,
		1.0, 1.25, 1.6, 2.0, 3.0, 5.5, 12.5, 64.0, 1e6, 1e12,
	]
	for v in log_vals:
		ops.append(3); xs.append(v); ys.append(0.0); expected.append(log(v))

	# 5. Kernel pow call sites:
	#    a) pow(2.0, log2_ratio) across [-20.0 .. +20.0] (case_eval, factored_channels, support_model)
	for step_i in range(-80, 81):
		var lr: float = float(step_i) * 0.25
		ops.append(4); xs.append(2.0); ys.append(lr); expected.append(pow(2.0, lr))
	for v in log_vals:
		var lr_exact: float = log(v) / log(2.0)
		ops.append(4); xs.append(2.0); ys.append(lr_exact); expected.append(pow(2.0, lr_exact))
	#    b) pow(2.0, -2.0 * (trust - 0.5)) for trust in [0.0 .. 1.0] (case_eval.gd:654)
	for t_i in range(0, 41):
		var trust: float = float(t_i) * 0.025
		var exp2: float = -2.0 * (clampf(trust, 0.0, 1.0) - 0.5)
		ops.append(4); xs.append(2.0); ys.append(exp2); expected.append(pow(2.0, exp2))
	#    c) pow(3, k) for ternary report codes k in 0..16 (case_eval.gd:360)
	for k in range(0, 17):
		ops.append(4); xs.append(3.0); ys.append(float(k)); expected.append(pow(3.0, float(k)))
	#    d) pow(THEORY_BIAS_BASE, confidence) for confidence in [0.0 .. 1.0] (theory.gd:63)
	for c_i in range(0, 21):
		var conf: float = float(c_i) * 0.05
		ops.append(4); xs.append(Tuning.Workshop.THEORY_BIAS_BASE); ys.append(conf)
		expected.append(pow(Tuning.Workshop.THEORY_BIAS_BASE, conf))
	#    e) General representative fractional exponents
	for v in [0.005, 0.045, 0.12, 0.3333333333333333, 0.45, 0.92, 1.6, 3.0, 12.5]:
		for p in [0.5, 0.75, 1.0, 1.25, 2.0, 3.0]:
			ops.append(4); xs.append(v); ys.append(p); expected.append(pow(v, p))

	var actual: PackedFloat64Array = bridge.EvalMathBatch(ops, xs, ys)
	var bad_idx: int = bridge.VerifyFloat64Buffer("EvalMathBatch_Tol0", expected, actual, 0.0)
	if bad_idx != -1:
		push_error("FAIL: C0 math batch differed at index %d (op=%d x=%.17g y=%.17g)" % [
			bad_idx, ops[bad_idx], xs[bad_idx], ys[bad_idx]
		])
		failures += 1
	else:
		print("PASS: C0 kernel math audit (%d checks) matched at 0 ULP (--tol 0)" % expected.size())

	# 6. Kernel lerpf call sites (role_constraints.gd:451, live_activity.gd:301,360,495)
	var froms := PackedFloat64Array()
	var tos := PackedFloat64Array()
	var ws := PackedFloat64Array()
	var exp_lerp := PackedFloat64Array()
	var pairs := [
		[1.0, Tuning.Workshop.BLUFF_WEIGHT],
		[0.75, 0.2],
		[0.75, 0.9],
		[0.15, 0.7],
		[0.15, 0.0],
		[0.05, 0.55],
	]
	for pr in pairs:
		for w_i in range(0, 41):
			var w: float = float(w_i) * 0.025
			froms.append(float(pr[0]))
			tos.append(float(pr[1]))
			ws.append(w)
			exp_lerp.append(lerpf(float(pr[0]), float(pr[1]), w))
		for w_odd in [0.123456789, 0.3333333333333333, 0.6666666666666666, 0.999999]:
			froms.append(float(pr[0]))
			tos.append(float(pr[1]))
			ws.append(w_odd)
			exp_lerp.append(lerpf(float(pr[0]), float(pr[1]), w_odd))

	var act_lerp: PackedFloat64Array = bridge.EvalLerpfBatch(froms, tos, ws)
	var bad_lerp: int = bridge.VerifyFloat64Buffer("EvalLerpfBatch_Tol0", exp_lerp, act_lerp, 0.0)
	if bad_lerp != -1:
		push_error("FAIL: C0 lerpf batch differed at index %d (from=%.17g to=%.17g w=%.17g)" % [
			bad_lerp, froms[bad_lerp], tos[bad_lerp], ws[bad_lerp]
		])
		failures += 1
	else:
		print("PASS: C0 lerpf audit (%d checks) matched at 0 ULP (--tol 0)" % exp_lerp.size())

	quit(1 if failures > 0 else 0)
