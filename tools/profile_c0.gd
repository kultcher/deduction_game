## Slice C0b stage breakdown & boundary marshaling profiler.
## Plays Seed 42 (7 NPCs) to Day 4 by default and prints SolverBackend.format_profile_report.
##
## Usage:
##   godot --headless --path . --script res://tools/profile_c0.gd -- \
##       [--seed 42] [--size 7] [--day 4] [--mode all|gdscript|csharp|verify]
extends SceneTree

const Game = preload("res://game/game.gd")
const Caches = preload("res://workshop/caches.gd")
const Ownership = preload("res://game/workshop_ownership.gd")

var _refreshes: int = 0

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sd: int = 42
	var size: int = 7
	var day_limit: int = 4
	var mode_arg: String = "all"
	if "--seed" in args:
		sd = int(args[args.find("--seed") + 1])
	if "--size" in args:
		size = int(args[args.find("--size") + 1])
	if "--day" in args:
		day_limit = int(args[args.find("--day") + 1])
	if "--mode" in args:
		mode_arg = str(args[args.find("--mode") + 1]).to_lower()

	var modes: Array = []
	if mode_arg == "gdscript":
		modes = [SolverBackend.Mode.GDSCRIPT]
	elif mode_arg == "csharp":
		modes = [SolverBackend.Mode.CSHARP]
	elif mode_arg == "verify":
		modes = [SolverBackend.Mode.VERIFY]
	else:
		modes = [SolverBackend.Mode.GDSCRIPT]
		if SolverBackend.is_csharp_available():
			modes.append(SolverBackend.Mode.CSHARP)
			modes.append(SolverBackend.Mode.VERIFY)

	var gd_snapshot: Dictionary = {}
	var failures: int = 0

	for m in modes:
		if m != SolverBackend.Mode.GDSCRIPT and not SolverBackend.is_csharp_available():
			print("SKIP mode %d: C# SolverBridge unavailable" % m)
			continue
		var m_name: String = "GDSCRIPT" if m == SolverBackend.Mode.GDSCRIPT else ("CSHARP" if m == SolverBackend.Mode.CSHARP else "VERIFY")
		var run_info: Dictionary = _run_seed(sd, size, day_limit, m, m_name)
		if m == SolverBackend.Mode.GDSCRIPT:
			gd_snapshot = run_info
		elif not gd_snapshot.is_empty():
			if run_info.rng != gd_snapshot.rng or run_info.suspicions != gd_snapshot.suspicions:
				push_error("FAIL: %s mode diverged from GDSCRIPT on seed %d size %d" % [m_name, sd, size])
				failures += 1
			if m == SolverBackend.Mode.VERIFY and int(run_info.verify_mismatches) != 0:
				push_error("FAIL: VERIFY mode recorded %d mismatches" % int(run_info.verify_mismatches))
				failures += 1

	SolverBackend.profiling_enabled = false
	SolverBackend.set_mode(SolverBackend.Mode.GDSCRIPT)
	Caches.clear_all()
	quit(1 if failures > 0 else 0)

func _run_seed(sd: int, size: int, day_limit: int, mode: int, mode_name: String) -> Dictionary:
	Caches.clear_all()
	SolverBackend.set_mode(mode)
	SolverBackend.reset_profile()
	SolverBackend.profiling_enabled = true

	var t0_ms: int = Time.get_ticks_msec()
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://profile_c0"
	g.new_case(sd, size)

	_refreshes = 0
	var inner: Callable = g.w.workshop_refresh
	g.w.workshop_refresh = func(n, phase):
		inner.call(n, phase)
		if phase == "after":
			_refreshes += 1

	var steps: int = 0
	while g.w.day < day_limit and not g.w.game_over and steps < 400:
		if g.state == "meeting":
			# Exercise lazy meeting reason attribution once per living NPC when entering a meeting step.
			for npc in g.w.npcs:
				if npc.alive:
					Ownership.reasons_for(g, npc)
		var cmd: String = _passive_command(g)
		g.command(cmd)
		steps += 1

	var wall_ms: int = Time.get_ticks_msec() - t0_ms
	var label: String = "Seed %d (%d NPCs, to Day %d) [%s] wall=%d ms steps=%d refreshes=%d" % [
		sd, size, day_limit, mode_name, wall_ms, steps, _refreshes
	]
	print(SolverBackend.format_profile_report(label))
	if mode == SolverBackend.Mode.VERIFY:
		print("VERIFY summary: calls=%d mismatches=%d" % [
			SolverBackend.get_verify_calls(), SolverBackend.get_verify_mismatches()
		])
	print("")

	var sus: Dictionary = {}
	for npc in g.w.npcs:
		sus[npc.id] = npc.suspicion.duplicate(true)

	SolverBackend.profiling_enabled = false
	return {
		"wall_ms": wall_ms,
		"steps": steps,
		"refreshes": _refreshes,
		"rng": str(g.w.rng.state),
		"suspicions": sus,
		"verify_calls": SolverBackend.get_verify_calls(),
		"verify_mismatches": SolverBackend.get_verify_mismatches(),
	}

func _passive_command(g) -> String:
	match g.state:
		"day":
			return "wait"
		"approach":
			return "decline"
		"talk":
			return "bye"
		"meeting":
			return "done" if g.town_quiet else "wait"
		"nomination":
			return "vote no"
		"night":
			return "sleep"
	return "look"
