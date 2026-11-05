## Shared replay of a playtest dev log for the developer tools (replay_log.gd,
## explain_case.gd): rebuild the case from the log's seed, size and script, then run
## player commands and Workshop filings in order.
extends RefCounted
const Game = preload("res://game/game.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const ScriptDef = preload("res://sim/script_def.gd")

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
			var out: String = g.command(str(e.data.cmd))
			step += 1
			var want: String = str(e.data.get("output", "")).strip_edges()
			# The UI splits some output (meeting testimony) into separate log records, so a
			# replay output that contains the logged text still matches.
			if not diverged and want != "" and not (want in out):
				diverged = true
				if hooks.has("on_diverge"):
					hooks.on_diverge.call(e, step, out)
		elif e.type == "workshop_canvas_filed":
			var n = Canvas.file(g, e.data.case, 0)
			if hooks.has("on_filed"):
				hooks.on_filed.call(e, n)
	return {"g": g, "steps": step, "diverged": diverged}

## The log's vote tallies against the replay's: [logged, replayed], as "nominee:yes,yes".
static func votes(events: Array, g, stop_seq: int = 1 << 30) -> Array:
	var logged: Array = events.filter(func(e): return e.type == "vote_tally" and int(e.seq) < stop_seq).map(func(e): return "%s:%s" % [e.target, ",".join(e.data.yes)])
	var replayed: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "vote_tally").map(func(e): return "%s:%s" % [e["target"], ",".join(e["data"]["yes"])])
	return [logged, replayed]
