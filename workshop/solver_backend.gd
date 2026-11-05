class_name SolverBackend
extends RefCounted

enum Mode { GDSCRIPT = 0, CSHARP = 1, VERIFY = 2 }

static var _cs_bridge: Variant = null
static var _cs_probed: bool = false
static var _mode: int = Mode.GDSCRIPT
static var _universe_handles: Dictionary = {}

# --- Slice C0 / C0b Microsecond Stage Timers & Boundary Call Counters ---
static var profiling_enabled: bool = false
static var _stage_usec: Dictionary = {}
static var _stage_incl_usec: Dictionary = {}
static var _stage_calls: Dictionary = {}
static var _stage_stack: Array = []
static var _boundary_calls: Dictionary = {}
static var _boundary_pack_usec: Dictionary = {}

const STAGES: Array[String] = [
	"outer_prep",          # jury.gd, shared_ledger.gd, circumstantial.gd
	"pack_inputs",         # dictionary -> Packed*Array repacking & handle registration
	"world_domain",        # world_domain.gd + role_constraints.gd
	"live_activity",       # live_activity.gd route masks, trace likelihoods & movement scores
	"case_eval_compile",   # case_eval.gd equivalence classes
	"channel_sum_product", # case_eval.gd posterior pass + channel_sum_product.gd + factored_channels.gd
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

static func active_mode() -> int:
	if _mode == Mode.GDSCRIPT:
		return Mode.GDSCRIPT
	return _mode if _bridge() != null else Mode.GDSCRIPT

static func clear_context() -> void:
	_universe_handles.clear()
	var b = _bridge()
	if b != null:
		b.ClearContext()

static func get_verify_calls() -> int:
	var b = _bridge()
	return int(b.GetVerifyCalls()) if b != null else 0

static func get_verify_mismatches() -> int:
	var b = _bridge()
	return int(b.GetVerifyMismatches()) if b != null else 0

# --- Compact 8-Byte WorldEntry Packing & Handle Registry ---

static func modifier_code(world: Dictionary) -> int:
	if not world.has("modifier"):
		return -2
	match str(world.modifier):
		"delusional":
			return 0
		"marked":
			return 1
		"lovers":
			return 2
		"sleepwalker":
			return 3
		"muddler":
			return 4
		_:
			return -1

static func pack_world(world: Dictionary) -> int:
	var evil: int = int(world.get("evil", 0)) & 0x3FFFF
	var holders: int = int(world.get("holders", 0)) & 0x3FFFF
	var marked: int = (int(world.get("marked", -1)) + 2) & 0x3F
	var mod_c: int = (modifier_code(world) + 2) & 0xF
	var demon_raw: int = ((int(world.demon) if world.has("demon") else -2) + 2) & 0x3F
	var conv_raw: int = ((int(world.converted) if world.has("converted") else -2) + 2) & 0x3F
	return evil | (holders << 18) | (marked << 36) | (mod_c << 42) | (demon_raw << 46) | (conv_raw << 52)

static func pack_worlds(universe: Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	var n: int = universe.size()
	out.resize(n)
	for i in range(n):
		out[i] = pack_world(universe[i])
	return out

static func get_universe_handle(u_key: String, universe: Array) -> int:
	if active_mode() == Mode.GDSCRIPT or u_key == "":
		return -1
	if _universe_handles.has(u_key):
		return int(_universe_handles[u_key])
	var t0: int = Time.get_ticks_usec() if profiling_enabled else 0
	var packed: PackedInt64Array = pack_worlds(universe)
	var pack_u: int = (Time.get_ticks_usec() - t0) if profiling_enabled else 0
	record_boundary_call("SolverContext.RegisterPackedUniverse", pack_u)
	var h: int = int(_bridge().RegisterPackedUniverse(u_key, packed))
	_universe_handles[u_key] = h
	return h

static func get_sub_universe_handle(sub_key: String, base_handle: int, indices: PackedInt32Array) -> int:
	if active_mode() == Mode.GDSCRIPT or base_handle < 0 or sub_key == "":
		return -1
	if _universe_handles.has(sub_key):
		return int(_universe_handles[sub_key])
	record_boundary_call("SolverContext.RegisterIndexedSubUniverse", 0)
	var h: int = int(_bridge().RegisterIndexedSubUniverse(sub_key, base_handle, indices))
	if h >= 0:
		_universe_handles[sub_key] = h
	return h

# --- Re-Entrant Exclusive / Inclusive Profiling Helpers ---

static func reset_profile() -> void:
	_stage_usec.clear()
	_stage_incl_usec.clear()
	_stage_calls.clear()
	_stage_stack.clear()
	_boundary_calls.clear()
	_boundary_pack_usec.clear()
	for s in STAGES:
		_stage_usec[s] = 0
		_stage_incl_usec[s] = 0
		_stage_calls[s] = 0

static func begin_stage(stage: String) -> int:
	if not profiling_enabled:
		return -1
	_stage_stack.append([stage, Time.get_ticks_usec(), 0])
	return _stage_stack.size() - 1

static func end_stage(token: int) -> void:
	if token < 0 or _stage_stack.is_empty():
		return
	var now: int = Time.get_ticks_usec()
	var frame: Array = _stage_stack.pop_back()
	var stage: String = str(frame[0])
	var incl: int = maxi(0, now - int(frame[1]))
	var self_u: int = maxi(0, incl - int(frame[2]))
	_stage_usec[stage] = int(_stage_usec.get(stage, 0)) + self_u
	var same_on_stack: bool = false
	for ancestor in _stage_stack:
		if ancestor[0] == stage:
			same_on_stack = true
			break
	if not same_on_stack:
		_stage_incl_usec[stage] = int(_stage_incl_usec.get(stage, 0)) + incl
	_stage_calls[stage] = int(_stage_calls.get(stage, 0)) + 1
	if not _stage_stack.is_empty():
		_stage_stack[-1][2] = int(_stage_stack[-1][2]) + incl

static func record_stage(stage: String, elapsed_usec: int, calls: int = 1) -> void:
	if not profiling_enabled:
		return
	var dur: int = maxi(0, elapsed_usec)
	_stage_usec[stage] = int(_stage_usec.get(stage, 0)) + dur
	_stage_incl_usec[stage] = int(_stage_incl_usec.get(stage, 0)) + dur
	_stage_calls[stage] = int(_stage_calls.get(stage, 0)) + calls
	if not _stage_stack.is_empty() and _stage_stack[-1][0] != stage:
		_stage_stack[-1][2] = int(_stage_stack[-1][2]) + dur

static func record_boundary_call(fn_name: String, pack_usec: int = 0) -> void:
	if not profiling_enabled:
		return
	_boundary_calls[fn_name] = int(_boundary_calls.get(fn_name, 0)) + 1
	if pack_usec > 0:
		_boundary_pack_usec[fn_name] = int(_boundary_pack_usec.get(fn_name, 0)) + pack_usec
		record_stage("pack_inputs", pack_usec, 1)

static func get_stage_stats() -> Dictionary:
	var out: Dictionary = {}
	for s in STAGES:
		out[s] = {
			"self_usec": int(_stage_usec.get(s, 0)),
			"incl_usec": int(_stage_incl_usec.get(s, 0)),
			"calls": int(_stage_calls.get(s, 0)),
		}
	return out

static func get_boundary_stats() -> Dictionary:
	var out: Dictionary = {}
	for fn_name in _boundary_calls:
		out[fn_name] = {
			"calls": int(_boundary_calls[fn_name]),
			"pack_usec": int(_boundary_pack_usec.get(fn_name, 0)),
		}
	return out

static func format_profile_report(label: String = "Solver Profile") -> String:
	var total_usec: int = 0
	for s in STAGES:
		total_usec += int(_stage_usec.get(s, 0))
	var lines: Array[String] = []
	lines.append("=== %s (Total Self: %.2f ms) ===" % [label, total_usec / 1000.0])
	lines.append("%-22s %10s %10s %10s %10s %8s" % ["Stage", "Self (ms)", "Incl (ms)", "Calls", "us/Call", "Share"])
	for s in STAGES:
		var u: int = int(_stage_usec.get(s, 0))
		var inc_u: int = int(_stage_incl_usec.get(s, 0))
		var c: int = int(_stage_calls.get(s, 0))
		var ms: float = u / 1000.0
		var inc_ms: float = inc_u / 1000.0
		var per_call: float = float(u) / float(max(c, 1))
		var pct: float = (100.0 * float(u) / float(total_usec)) if total_usec > 0 else 0.0
		lines.append("%-22s %10.2f %10.2f %10d %10.1f %7.1f%%" % [s, ms, inc_ms, c, per_call, pct])
	if not _boundary_calls.is_empty():
		lines.append("--- Boundary Calls ---")
		lines.append("%-40s %10s %10s %10s" % ["Function", "Calls", "Pack (ms)", "Pack us"])
		var names: Array = _boundary_calls.keys()
		names.sort()
		for fn_name in names:
			var calls: int = int(_boundary_calls[fn_name])
			var p_u: int = int(_boundary_pack_usec.get(fn_name, 0))
			lines.append("%-40s %10d %10.2f %10.1f" % [
				str(fn_name), calls, p_u / 1000.0, float(p_u) / float(max(calls, 1))
			])
	return "\n".join(lines)
