## Slice C0b stage breakdown & boundary marshaling profiler.
## Plays Seed 42 (7 NPCs) to Day 4 by default and prints SolverBackend.format_profile_report.
##
## Usage:
##   godot --headless --path . --script res://tools/profile_c0.gd -- \
##       [--seed 42] [--size 7] [--day 4]   (C# solver; stage times and boundary calls)
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
	if "--seed" in args:
		sd = int(args[args.find("--seed") + 1])
	if "--size" in args:
		size = int(args[args.find("--size") + 1])
	if "--day" in args:
		day_limit = int(args[args.find("--day") + 1])

	_run_seed(sd, size, day_limit)
	SolverBackend.profiling_enabled = false
	Caches.clear_all()
	quit(0)

func _run_seed(sd: int, size: int, day_limit: int) -> Dictionary:
	Caches.clear_all()
	SolverBackend.reset_profile()
	SolverBackend.profiling_enabled = true

	var t0_ms: int = Time.get_ticks_msec()
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://profile_c0"
	g.new_case(sd, size)

	_refreshes = 0
	var inner: Callable = g.w.workshop_refresh
	g.w.workshop_refresh = func(n):
		inner.call(n)
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
	var label: String = "Seed %d (%d NPCs, to Day %d) wall=%d ms steps=%d refreshes=%d" % [
		sd, size, day_limit, wall_ms, steps, _refreshes
	]
	print(SolverBackend.format_profile_report(label))
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
