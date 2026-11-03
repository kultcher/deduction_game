class_name SolverBackend
extends RefCounted

enum Mode { GDSCRIPT = 0, CSHARP = 1, VERIFY = 2 }

static var _cs_bridge: Variant = null
static var _cs_probed: bool = false
static var _mode: int = Mode.GDSCRIPT

# --- Slice C0 Microsecond Stage Timers & Call Counters ---
static var profiling_enabled: bool = false
static var _stage_usec: Dictionary = {}
static var _stage_calls: Dictionary = {}

const STAGES: Array[String] = [
	"outer_prep",          # jury.gd, shared_ledger.gd, circumstantial.gd
	"pack_inputs",         # full dictionary -> Packed*Array repacking
	"world_domain",        # world_domain.gd + role_constraints.gd
	"live_activity",       # live_activity.gd route masks & trace likelihoods
	"case_eval_compile",   # case_eval.gd equivalence classes
	"channel_sum_product", # channel_sum_product.gd + factored_channels.gd
	"reason_attribution",  # reason_attribution.gd (_class_like / _subset_fits)
]

static func _bridge() -> Variant:
	if not _cs_probed:
		_cs_probed = true
		if ResourceLoader.exists("res://workshop/cs/SolverBridge.cs"):
			var scr = load("res://workshop/cs/SolverBridge.cs")
			if scr != null and scr.can_instantiate():
				_cs_bridge = scr
	return _cs_bridge

static func is_csharp_available() -> bool:
	return _bridge() != null

static func set_mode(m: int) -> void:
	_mode = clampi(m, Mode.GDSCRIPT, Mode.VERIFY)
	var b = _bridge()
	if b != null:
		b.SetMode(_mode)

static func get_mode() -> int:
	return _mode

static func clear_context() -> void:
	var b = _bridge()
	if b != null:
		b.ClearContext()

# --- Profiling Helpers ---

static func reset_profile() -> void:
	_stage_usec.clear()
	_stage_calls.clear()
	for s in STAGES:
		_stage_usec[s] = 0
		_stage_calls[s] = 0

static func record_stage(stage: String, elapsed_usec: int, calls: int = 1) -> void:
	if not profiling_enabled:
		return
	_stage_usec[stage] = int(_stage_usec.get(stage, 0)) + elapsed_usec
	_stage_calls[stage] = int(_stage_calls.get(stage, 0)) + calls

static func format_profile_report(label: String = "Solver Profile") -> String:
	var total_usec: int = 0
	for s in _stage_usec.values():
		total_usec += int(s)
	var lines: Array[String] = []
	lines.append("=== %s (Total: %.2f ms) ===" % [label, total_usec / 1000.0])
	lines.append("%-22s %10s %10s %10s %8s" % ["Stage", "Time (ms)", "Calls", "us/Call", "Share"])
	for s in STAGES:
		var u: int = int(_stage_usec.get(s, 0))
		var c: int = int(_stage_calls.get(s, 0))
		var ms: float = u / 1000.0
		var per_call: float = float(u) / float(max(c, 1))
		var pct: float = (100.0 * float(u) / float(total_usec)) if total_usec > 0 else 0.0
		lines.append("%-22s %10.2f %10d %10.1f %7.1f%%" % [s, ms, c, per_call, pct])
	return "\n".join(lines)
