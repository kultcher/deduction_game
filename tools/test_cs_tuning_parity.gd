## Verifies that C# solver kernels hold no independent copies of sim/tuning.gd constants,
## receive all tuning values from GDScript via SolverBackend.sync_tuning(), fail loudly if
## unconfigured or given non-finite values, and agree with GDScript on modifier/burden codes.
extends SceneTree

const Tuning = preload("res://sim/tuning.gd")
const SolverBackend = preload("res://workshop/solver_backend.gd")
const Solver = preload("res://workshop/solver.gd")
const RoleConstraints = preload("res://workshop/role_constraints.gd")

var _checks := 0
var _fails := 0

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: " + msg)

func _init() -> void:
	var bridge = SolverBackend._bridge()
	_check(bridge != null, "C# SolverBridge loads")
	if bridge == null:
		quit(1)
		return

	# 1. Runtime tuning parity: every tuning value held in C# equals sim/tuning.gd.
	_check(bool(bridge.IsTuningConfigured()), "C# kernels report tuning configured at bridge init")
	var cs_tuning: Dictionary = bridge.GetConfiguredTuning()
	var expected := {
		"marked_demon_chance": float(Tuning.Setup.MARKED_DEMON_CHANCE),
		"vigil_miss": float(Tuning.Workshop.VIGIL_MISS),
		"walker_claim_gift": float(Tuning.Workshop.WALKER_CLAIM_GIFT),
		"walker_claim_home": float(Tuning.Workshop.WALKER_CLAIM_HOME),
		"walker_claim_secret": float(Tuning.Workshop.WALKER_CLAIM_SECRET),
	}
	_check(cs_tuning.size() == expected.size(),
		"GetConfiguredTuning exposes all %d expected tuning keys (got %d)" % [expected.size(), cs_tuning.size()])
	for k in expected:
		_check(cs_tuning.has(k), "GetConfiguredTuning has key '%s'" % k)
		if cs_tuning.has(k):
			_check(float(cs_tuning[k]) == expected[k],
				"C# %s (%.17g) == sim/tuning.gd (%.17g)" % [k, float(cs_tuning[k]), expected[k]])

	# 2. Fail-loud contract: unconfigured reads throw InvalidOperationException and NaN/Inf throws ArgumentOutOfRangeException.
	_check(bool(bridge.VerifyTuningFailLoud()), "C# tuning guards fail loudly when unconfigured or given NaN/Infinity")
	_check(bool(bridge.IsTuningConfigured()), "VerifyTuningFailLoud restores configured tuning values")

	# 3. Burden / modifier integer code parity across SolverBackend, Solver, RoleConstraints, and SolverContext.cs.
	var cs_mods: Dictionary = bridge.GetModifierCodes()
	for mod_name in ["delusional", "marked", "ill_omened", "unrequited"]:
		var sb_code: int = SolverBackend.modifier_code({"modifier": mod_name})
		var sv_code: int = Solver._secret_mod_code(mod_name)
		var rc_code: int = int(RoleConstraints.BURDEN_CODES.get(mod_name, -99)) - 1
		var cs_code: int = int(cs_mods.get(mod_name, -99))
		_check(sb_code == cs_code and sv_code == cs_code and rc_code == cs_code,
			"modifier code parity for '%s': SolverBackend=%d Solver=%d RoleConstraints-1=%d C#=%d" % [
				mod_name, sb_code, sv_code, rc_code, cs_code])

	# 4. Guard against re-introducing hand-copied Tuning constants in workshop/cs/*.cs.
	var dir := DirAccess.open("res://workshop/cs")
	_check(dir != null, "workshop/cs directory opens for static scan")
	if dir != null:
		var rx_const_float := RegEx.new()
		rx_const_float.compile("\\bconst\\s+(?:double|float)\\b")
		var rx_mirror_comment := RegEx.new()
		rx_mirror_comment.compile("(?i)\\bmirrors?\\b.*(?:sim/tuning\\.gd|Tuning\\.)")
		# Local structural math constants allowed in hot paths (not tuning):
		var allowed_const_lines := {
			"LiveActivity.cs:const double evP = 0.25;": true,
		}
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".cs"):
				var txt := FileAccess.get_file_as_string("res://workshop/cs/" + fname)
				var lines := txt.split("\n")
				for i in range(lines.size()):
					var stripped := lines[i].strip_edges()
					if rx_const_float.search(stripped) != null:
						var key := "%s:%s" % [fname, stripped]
						_check(allowed_const_lines.has(key),
							"Unexpected floating-point const in workshop/cs/%s:%d ('%s') — inject from sim/tuning.gd instead" % [fname, i + 1, stripped])
					if rx_mirror_comment.search(stripped) != null:
						_check(false,
							"Mirror-of-Tuning comment in workshop/cs/%s:%d ('%s') — pass from sim/tuning.gd instead of copying" % [fname, i + 1, stripped])
			fname = dir.get_next()
		dir.list_dir_end()

	print("C# tuning parity: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
