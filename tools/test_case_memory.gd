## Verifies that playing consecutive cases in one process does not leak Godot objects,
## GDScript static heap, or C# SolverContext handles across Game.new_case() resets.
extends SceneTree

const Game = preload("res://game/game.gd")
const SolverBackend = preload("res://workshop/solver_backend.gd")
const WorkshopCaches = preload("res://workshop/caches.gd")

var _checks := 0
var _fails := 0

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: " + msg)

func _play_one(seed_v: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://logs/test_case_memory"
	g.new_case(seed_v, 7)
	var guard := 0
	while g.state != "over" and guard < 60:
		guard += 1
		match g.state:
			"day": g.command("wait")
			"approach": g.command("decline")
			"talk": g.command("bye")
			"meeting": g.command("wait")
			"nomination": g.command("no")
			"night": g.command("sleep")
			_: break

func _init() -> void:
	var bridge = SolverBackend._bridge()
	_check(bridge != null, "C# SolverBridge loads")
	if bridge == null:
		quit(1)
		return

	var gd_after: Array[float] = []
	var objs_after: Array[int] = []
	var cs_after: Array[float] = []

	for i in range(4):
		_play_one(42 + i)
		WorkshopCaches.clear_all()
		var m: PackedInt64Array = bridge.GetMemoryStats(true)
		var gd_mb: float = OS.get_static_memory_usage() / 1048576.0
		var objs: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var cs_mb: float = float(m[1]) / 1048576.0
		gd_after.append(gd_mb)
		objs_after.append(objs)
		cs_after.append(cs_mb)
		_check(int(m[3]) == 0 and int(m[4]) == 0 and int(m[5]) == 0 and int(m[6]) == 0,
			"game %d: SolverContext handles cleared to 0 (u=%d mf=%d cc=%d cu=%d)" % [i + 1, m[3], m[4], m[5], m[6]])

	var gd_growth: float = gd_after[3] - gd_after[0]
	var obj_growth: int = objs_after[3] - objs_after[0]
	var cs_growth: float = cs_after[3] - cs_after[0]
	print("Case memory (after clear): GD=%.1f->%.1f MB (%+.1f) | objs=%d->%d (%+d) | CS_GC=%.1f->%.1f MB (%+.1f)" % [
		gd_after[0], gd_after[3], gd_growth, objs_after[0], objs_after[3], obj_growth, cs_after[0], cs_after[3], cs_growth])

	_check(gd_growth <= 20.0, "Godot static heap growth across 4 cases <= 20 MB (got %+.1f MB)" % gd_growth)
	_check(obj_growth <= 50, "Godot object count growth across 4 cases <= 50 (got %+d)" % obj_growth)
	_check(cs_growth <= 10.0, "C# GC heap growth across 4 cases <= 10 MB (got %+.1f MB)" % cs_growth)

	print("Case memory: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
