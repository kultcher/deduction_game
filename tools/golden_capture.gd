## Golden behaviour capture: plays fixed seeds with a passive player and writes, as
## JSON lines, every belief refresh and the full game state after every command.
## Recorded once from a known-good commit, it is the baseline a port or refactor is
## diffed against (tools/golden_diff.py). Capturing must not change behaviour: the
## refresh hook only reads, and logging stays at the default (untraced) level.
##
##   godot --headless --path . --script res://tools/golden_capture.gd -- \
##       --out /abs/dir [--seeds 900:7,42:7,54875:10] [--day 4]
##
## Output per seed: <out>/seed_<seed>_<npcs>.jsonl. Record kinds:
##   {"k": "meta", ...}      seed, size, day limit, engine version
##   {"k": "refresh", ...}   one per shared belief refresh ("after" phase)
##   {"k": "step", ...}      one per command: the command, its reply, full state
##   {"k": "end", ...}       final summary
extends SceneTree

const Game = preload("res://game/game.gd")
const DevLog = preload("res://sim/devlog.gd")

const DEFAULT_SEEDS = [[900, 7], [42, 7], [54875, 10], [692, 10], [98933, 10]]

var _file: FileAccess
var _refreshes: int = 0
var _g = null


func _init() -> void:
	var args = OS.get_cmdline_user_args()
	var out: String = ""
	var seeds: Array = DEFAULT_SEEDS
	var day_limit: int = 4
	if "--out" in args:
		out = args[args.find("--out") + 1]
	if "--day" in args:
		day_limit = int(args[args.find("--day") + 1])
	if "--seeds" in args:
		seeds = []
		for part in args[args.find("--seeds") + 1].split(","):
			var bits = part.split(":")
			seeds.append([int(bits[0]), int(bits[1])])
	if out == "":
		push_error("golden_capture: --out <absolute dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	for cfg in seeds:
		var started: int = Time.get_ticks_msec()
		_capture(out, int(cfg[0]), int(cfg[1]), day_limit)
		print("GOLDEN seed %d size %d: %d refreshes, %d ms" % [cfg[0], cfg[1], _refreshes, Time.get_ticks_msec() - started])
	quit(0)


func _write(record: Dictionary) -> void:
	# sort_keys gives a stable text form; full_precision keeps every double exact.
	_file.store_line(JSON.stringify(record, "", true, true))


func _capture(out: String, sd: int, size: int, day_limit: int) -> void:
	_file = FileAccess.open("%s/seed_%d_%d.jsonl" % [out, sd, size], FileAccess.WRITE)
	_refreshes = 0
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://golden_capture"
	g.new_case(sd, size)
	_g = g
	_write({"k": "meta", "seed": sd, "npcs": size, "day_limit": day_limit,
		"engine": Engine.get_version_info().get("string", ""), "rng": str(g.w.rng.state)})
	# Wrap the shared-refresh hook (read-only observer after the real refresh).
	var inner: Callable = g.w.workshop_refresh
	g.w.workshop_refresh = func(n, phase):
		inner.call(n, phase)
		if phase == "after":
			_on_refresh(n)
	_write(_step_record(g, -1, "", ""))
	var steps: int = 0
	while g.w.day < day_limit and not g.w.game_over and steps < 400:
		var cmd: String = _passive_command(g)
		var reply: String = g.command(cmd)
		_write(_step_record(g, steps, cmd, reply))
		steps += 1
	_write({"k": "end", "steps": steps, "day": g.w.day, "phase": g.w.phase, "over": g.w.game_over,
		"winner": g.w.winner, "refreshes": _refreshes, "fallbacks": g.shared_fallbacks.duplicate(true),
		"executions": g.w.executions.duplicate(true)})
	_file.close()
	_g = null


func _on_refresh(n) -> void:
	var st: Dictionary = n.workshop_state
	_write({"k": "refresh", "i": _refreshes, "npc": n.id, "shadow": n.is_shadow,
		"day": _g.w.day, "phase": _g.w.phase,
		"suspicion": n.suspicion.duplicate(true),
		"active": st.get("active", false),
		"outside": st.get("outside", {}).duplicate(true),
		"requested": st.get("requested", {}).duplicate(true),
		"applied": st.get("applied", {}).duplicate(true),
		"circumstantial_applied": st.get("circumstantial_applied", {}).duplicate(true),
		"source_doubt": st.get("source_doubt", {}).duplicate(true),
		"owned": st.get("owned", {}).keys(),
		"issues": st.get("issues", []).duplicate(true),
		"resentments": n.resentments.duplicate(true),
		"npc_trust": n.npc_trust.duplicate(true),
		"trust": n.trust})
	_refreshes += 1


func _step_record(g, step: int, cmd: String, reply: String) -> Dictionary:
	var npcs = {}
	for n in g.w.npcs:
		npcs[n.id] = {"real": DevLog.npc_state(n)}
		if n.shadow != null:
			npcs[n.id]["shadow"] = DevLog.npc_state(n.shadow)
			npcs[n.id]["shadow_rng"] = str(n.shadow.shadow_rng.state)
	return {"k": "step", "step": step, "cmd": cmd, "reply": reply,
		"rng": str(g.w.rng.state), "day": g.w.day, "phase": g.w.phase, "state": g.state,
		"over": g.w.game_over, "winner": g.w.winner, "refreshes_so_far": _refreshes,
		"public_log": g.w.public_log.duplicate(true), "executions": g.w.executions.duplicate(true),
		"meeting": g.w.meeting.duplicate(true), "board": g.board.duplicate(true), "npcs": npcs}


## Same passive player as test_trace's parity check.
func _passive_command(g) -> String:
	match g.state:
		"day": return "wait"
		"approach": return "decline"
		"talk": return "bye"
		"meeting": return "done" if g.town_quiet else "wait"
		"nomination": return "vote no"
		"night": return "sleep"
	return "look"
