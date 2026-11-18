## Shared replay of a playtest dev log for the developer tools (replay_log.gd,
## explain_case.gd): rebuild the case from the log's seed, size and script, then run
## player commands and Workshop filings in order.
extends RefCounted
const Game = preload("res://game/game.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Connections = preload("res://workshop/connections.gd")

## A tool's explicit belief-model choice for the replay: -1 the log's own, 0 off, 1 on.
static var model_override: int = -1

static func load_events(path: String) -> Array:
	var events: Array = []
	for l in FileAccess.get_file_as_string(path).split("\n"):
		if l.strip_edges() != "":
			events.append(JSON.parse_string(l))
	return events

static func is_command(e) -> bool:
	return e.type in ["player_command", "player_testimony"] and str(e.data.get("cmd", "")) != ""

static func new_game(events: Array):
	var setup = events[0]
	# A log replays faithfully only on the code it was played on (random rolls shift as the
	# game changes). case_start records that commit since Nov 6.
	var logged: String = str(setup.data.get("build", ""))
	var here: String = preload("res://sim/build_info.gd").commit()
	if logged.length() >= 7 and here != "" and not here.begins_with(logged) and not logged.begins_with(here):
		print("NOTE: this log was played on commit %s; this checkout is %s. To replay it exactly: git worktree add ../replay_%s %s" % [logged.substr(0, 12), here.substr(0, 12), logged.substr(0, 7), logged.substr(0, 12)])
	elif logged == "" or logged == "dev":
		print("NOTE: this log doesn't record its commit (logs before Nov 6); if the replay diverges, replay it on the commit it was played on.")
	# A log played with the connections belief model on says so (sim/world.gd, case_start), and
	# one without the field was played with it off (the earlier model, or --legacy-model since
	# it went on by default, Nov 16): the replay uses the recorded model (Codex on #160). A
	# tool's explicit choice (`model_override`: replay_log --connections, for logs from before
	# the field was recorded) wins.
	var recorded: bool = bool(setup.data.get("connections", false))
	var use: bool = recorded if model_override < 0 else model_override == 1
	if use != Connections.enabled:
		Connections.enabled = use
		print("NOTE: this log was played with the connections model %s; it is %s for this replay." % ["on" if recorded else "off", "on" if use else "off"])
	var script = null
	for e in events:
		if e.type == "case_script":
			script = ScriptDef.from_dict(e.data.script)
			break
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(int(setup.data.seed), int(setup.data.npcs), script)
	return g

## Replays every event with seq < stop_seq. hooks (all optional):
##   before_command(g, e)  called before each player command
##   on_diverge(e, step, out)  the first command whose output lacks the logged text
##   on_filed(e, n)  after each Workshop filing
##   after_command(g, e, msec)  after each player command, with how long it took
## Returns {"g", "steps", "diverged"}.
static func replay(events: Array, stop_seq: int = 1 << 30, hooks: Dictionary = {}) -> Dictionary:
	var g = new_game(events)
	var diverged := false
	var step := 0
	for e in events:
		if int(e.seq) >= stop_seq:
			break
		if is_command(e):
			if hooks.has("before_command"):
				hooks.before_command.call(g, e)
			var began: int = Time.get_ticks_msec()
			var out: String = g.command(str(e.data.cmd))
			step += 1
			if hooks.has("after_command"):
				hooks.after_command.call(g, e, Time.get_ticks_msec() - began)
			var want: String = str(e.data.get("output", "")).strip_edges()
			# The UI splits some output (meeting testimony) into separate log records, so a
			# replay output that contains the logged text still matches.
			if not diverged and want != "" and not (want in out):
				diverged = true
				if hooks.has("on_diverge"):
					hooks.on_diverge.call(e, step, out)
		elif e.type == "workshop_canvas_filed":
			# Logs from before Nov 18 don't say which case a filing replaced, so they replay
			# every filing as a new case.
			var n = Canvas.file(g, e.data.case, int(e.data.get("revises", 0)))
			if hooks.has("on_filed"):
				hooks.on_filed.call(e, n)
	return {"g": g, "steps": step, "diverged": diverged}

## The state digests (World.state_digest, logged after each command and Workshop filing)
## against the replay's: `hooks` wrapped so that after each replayed command or filing the
## replay's digest is compared with the one logged after it. `report` gets "checked" (how
## many compared) and, at the first difference, "first": {"seq", "what", "minds" (whose
## state differs), "rng" (whether the world's random stream does)}. Logs from before Nov 18
## have no digests, and nothing is compared.
static func digest_hooks(events: Array, hooks: Dictionary, report: Dictionary) -> Dictionary:
	var logged: Dictionary = {}
	var last: int = -1
	for e in events:
		if e.type == "state_digest":
			if last >= 0:
				logged[last] = e.data
		else:
			last = int(e.seq)
	report["checked"] = 0
	var held := {"g": null}
	var compare := func(g, e, what: String) -> void:
		if g == null or report.has("first") or not logged.has(int(e.seq)):
			return
		report.checked += 1
		var now: Dictionary = g.w.state_digest()
		var want: Dictionary = logged[int(e.seq)]
		if now == want:
			return
		var minds: Array = []
		for id in now.minds:
			if str(now.minds[id]) != str(want.get("minds", {}).get(id, "")):
				minds.append(id)
		report["first"] = {"seq": int(e.seq), "what": what, "minds": minds, "rng": str(now.rng) != str(want.get("rng", ""))}
	var out: Dictionary = hooks.duplicate()
	out["before_command"] = func(g, e):
		held.g = g
		if hooks.has("before_command"):
			hooks.before_command.call(g, e)
	out["after_command"] = func(g, e, msec: int):
		held.g = g
		if hooks.has("after_command"):
			hooks.after_command.call(g, e, msec)
		compare.call(g, e, "command " + str(e.data.get("cmd", "")))
	out["on_filed"] = func(e, n):
		if hooks.has("on_filed"):
			hooks.on_filed.call(e, n)
		compare.call(held.g, e, "filing of case #%d" % int(e.data.get("card", 0)))
	return out

## The log's vote tallies against the replay's: [logged, replayed], as "nominee:yes,yes".
static func votes(events: Array, g, stop_seq: int = 1 << 30) -> Array:
	var logged: Array = events.filter(func(e): return e.type == "vote_tally" and int(e.seq) < stop_seq).map(func(e): return "%s:%s" % [e.target, ",".join(e.data.yes)])
	var replayed: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "vote_tally").map(func(e): return "%s:%s" % [e["target"], ",".join(e["data"]["yes"])])
	return [logged, replayed]
