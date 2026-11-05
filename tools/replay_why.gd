## Why did the town vote that way? Replays a playtest dev log (player commands in order,
## Workshop filings at their logged point) and, just before each logged vote, prints every
## good mind's view: P(evil) per person from the shared model, the suspicion the vote reads,
## its likeliest evil teams (worlds) and its likeliest Demon.
##
## godot --headless --path . --script res://tools/replay_why.gd -- <log.jsonl> [--at SEQ,...] [--worlds N] [--json OUT]
##
## With no --at, it stops before every vote_tally in the log. Reads state only: the views are
## taken on copies, so the replay itself is unchanged.
extends SceneTree
const Game = preload("res://game/game.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Mind = preload("res://sim/mind.gd")
const Views = preload("res://tools/belief_views.gd")

func _init():
	var args = OS.get_cmdline_user_args()
	var path: String = args[0]
	var stops: Array = []
	var n_worlds := 5
	var json_out := ""
	var i := 1
	while i < args.size():
		match args[i]:
			"--at":
				for s in str(args[i + 1]).split(","):
					stops.append(int(s))
				i += 1
			"--worlds":
				n_worlds = int(args[i + 1])
				i += 1
			"--json":
				json_out = args[i + 1]
				i += 1
		i += 1
	var events: Array = []
	for l in FileAccess.get_file_as_string(path).split("\n"):
		if l.strip_edges() != "":
			events.append(JSON.parse_string(l))
	var setup = events[0]
	var script = null
	var labels := {}
	for e in events:
		if e.type == "case_script":
			script = ScriptDef.from_dict(e.data.script)
		elif e.type == "vote_tally":
			if stops.is_empty() or int(e.seq) in stops:
				labels[int(e.seq)] = "vote on %s (by %s): %d yes" % [e.target, e.data.get("by", "?"), int(e.data.get("count", 0))]
	if stops.is_empty():
		stops = labels.keys()
	stops.sort()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(int(setup.data.seed), int(setup.data.npcs), script)
	var diverged := false
	var dumps: Array = []
	var next_stop := 0
	for e in events:
		# Dump at the first logged event after the last player command before the vote:
		# the vote itself runs inside that command, so stop just before it.
		while next_stop < stops.size() and _command_runs_vote(events, e, stops[next_stop]):
			var v = Views.town(g, n_worlds)
			v["seq"] = stops[next_stop]
			v["label"] = labels.get(stops[next_stop], "seq %d" % stops[next_stop])
			dumps.append(v)
			print(Views.render(v))
			next_stop += 1
		if e.type in ["player_command", "player_testimony"]:
			var cmd: String = str(e.data.get("cmd", ""))
			if cmd == "":
				continue
			var out: String = g.command(cmd)
			var want: String = str(e.data.get("output", "")).strip_edges()
			if not diverged and want != "" and not (want in out):
				diverged = true
				print("DIVERGE at seq %d cmd=%s\n--- log:\n%s\n--- replay:\n%s" % [int(e.seq), cmd, want.substr(0, 600), out.substr(0, 600)])
		elif e.type == "workshop_canvas_filed":
			Canvas.file(g, e.data.case, 0)
	if json_out != "":
		var f = FileAccess.open(json_out, FileAccess.WRITE)
		for d in dumps:
			f.store_line(JSON.stringify(d))
		f.close()
	# Text can differ where the UI splits output (meeting testimony); the votes must not.
	var logged: Array = events.filter(func(e): return e.type == "vote_tally").map(func(e): return "%s:%s" % [e.target, ",".join(e.data.yes)])
	var replayed: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "vote_tally").map(func(e): return "%s:%s" % [e["target"], ",".join(e["data"]["yes"])])
	print("VOTES logged   %s" % str(logged))
	print("VOTES replayed %s" % str(replayed))
	print("REPLAY done text_diverged=%s votes_match=%s day=%d" % [str(diverged), str(logged == replayed), g.w.day])
	quit()

## True when `e` is the player command whose output contains the vote at `stop_seq`:
## the last player command logged before that vote.
func _command_runs_vote(events: Array, e, stop_seq: int) -> bool:
	if not e.type in ["player_command", "player_testimony"] or str(e.data.get("cmd", "")) == "":
		return false
	if int(e.seq) > stop_seq:
		return false
	for later in events:
		if int(later.seq) > int(e.seq) and int(later.seq) < stop_seq and later.type in ["player_command", "player_testimony"] and str(later.data.get("cmd", "")) != "":
			return false
	return true
