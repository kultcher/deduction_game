extends SceneTree

func _init() -> void:
	var failures: int = 0
	SolverBackend.reset_profile()
	SolverBackend.clear_context()

	if not SolverBackend.is_csharp_available():
		print("SKIP: C# SolverBridge not loaded (non-Mono binary)")
		quit(0)
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

	# 2. snappedf across solver step sizes
	for v in [-0.445, -0.015, 0.015, 0.045, 0.123456789, 0.5, 1.25]:
		for step in [0.001, 0.005, 0.01, 0.05, 0.25]:
			ops.append(1)
			xs.append(v)
			ys.append(step)
			expected.append(snappedf(v, step))

	# 3. exp / log / pow across likelihood & channel sum-product ranges
	var test_vals := [1e-12, 1e-6, 0.005, 0.015, 0.045, 0.08, 0.12, 0.3333333333333333, 0.45, 0.92, 1.6, 3.0, 12.5]
	for v in test_vals:
		ops.append(2); xs.append(v); ys.append(0.0); expected.append(exp(v))
		ops.append(2); xs.append(-v); ys.append(0.0); expected.append(exp(-v))
		ops.append(3); xs.append(v); ys.append(0.0); expected.append(log(v))
		for p in [0.5, 1.0, 2.0, 3.0, 0.75, 1.25]:
			ops.append(4); xs.append(v); ys.append(p); expected.append(pow(v, p))

	var actual: PackedFloat64Array = bridge.EvalMathBatch(ops, xs, ys)
	var bad_idx: int = bridge.VerifyFloat64Buffer("EvalMathBatch_Tol0", expected, actual, 0.0)
	if bad_idx != -1:
		push_error("FAIL: C0 math batch differed at index %d (op=%d x=%.17g y=%.17g)" % [
			bad_idx, ops[bad_idx], xs[bad_idx], ys[bad_idx]
		])
		failures += 1
	else:
		print("PASS: C0 math batch (%d checks) matched at 0 ULP (--tol 0)" % expected.size())

	quit(1 if failures > 0 else 0)
