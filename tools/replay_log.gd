## Replays a playtest dev log: player commands in order, Workshop filings at their logged point.
## godot --headless --path . --script res://tools/replay_log.gd -- <log.jsonl> [stop_seq] [options]
##
## stop_seq   stop replaying at this log seq (default: the whole log)
## --why      before each logged vote, print what every good mind believed: the suspicion the
##            vote reads, joint-world P(evil) and P(Demon), and the likeliest evil teams
##            (tools/belief_views.gd). Taking the views doesn't change the replay.
## --at S,..  with --why: only before the votes logged at these seqs
## --worlds N with --why: how many evil teams to list (default 5)
## --json OUT with --why: also write the views as JSONL
##
## The case is rebuilt from the log's seed, size and script (case_script), so dynamic and
## custom-script cases replay too. The first text divergence is printed; meeting testimony
## can differ in text because the UI splits it into separate records. The replay ends by
## comparing its vote tallies with the log's (votes_match): those must agree.
extends SceneTree
const Game = preload("res://game/game.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Views = preload("res://tools/belief_views.gd")

func _init():
	var args = OS.get_cmdline_user_args()
	var path: String = args[0]
	var stop_seq: int = 1 << 30
	var why := false
	var only: Array = []
	var n_worlds := 5
	var json_out := ""
	var i := 1
	while i < args.size():
		match args[i]:
			"--why":
				why = true
			"--at":
				for s in str(args[i + 1]).split(","):
					only.append(int(s))
				i += 1
			"--worlds":
				n_worlds = int(args[i + 1])
				i += 1
			"--json":
				json_out = args[i + 1]
				i += 1
			_:
				stop_seq = int(args[i])
		i += 1
	var events: Array = []
	for l in FileAccess.get_file_as_string(path).split("\n"):
		if l.strip_edges() != "":
			events.append(JSON.parse_string(l))
	events = events.filter(func(e): return int(e.seq) < stop_seq)
	var setup = events[0]
	var script = null
	for e in events:
		if e.type == "case_script":
			script = ScriptDef.from_dict(e.data.script)
	# --why: for each vote, the last player command before it (the vote runs inside it).
	var dump_before := {}
	if why:
		var last_cmd := -1
		for e in events:
			if _is_command(e):
				last_cmd = int(e.seq)
			elif e.type == "vote_tally" and last_cmd >= 0 and (only.is_empty() or int(e.seq) in only):
				dump_before[last_cmd] = dump_before.get(last_cmd, []) + [e]
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(int(setup.data.seed), int(setup.data.npcs), script)
	var diverged = false
	var step = 0
	var dumps: Array = []
	for e in events:
		if _is_command(e):
			for vote in dump_before.get(int(e.seq), []):
				var v = Views.town(g, n_worlds)
				v["seq"] = int(vote.seq)
				v["label"] = "vote on %s (by %s): %d yes" % [vote.target, vote.data.get("by", "?"), int(vote.data.get("count", 0))]
				dumps.append(v)
				print(Views.render(v))
			var cmd: String = str(e.data.get("cmd", ""))
			var out: String = g.command(cmd)
			step += 1
			var want: String = str(e.data.get("output", ""))
			# The UI splits some output (meeting testimony) into separate log records, so a replay
			# output that contains the logged text still matches.
			if not diverged and want.strip_edges() != "" and not (want.strip_edges() in out):
				diverged = true
				print("DIVERGE at seq %d step %d cmd=%s\n--- log:\n%s\n--- replay:\n%s" % [int(e.seq), step, cmd, want.substr(0, 900), out.substr(0, 900)])
		elif e.type == "workshop_canvas_filed":
			var n = Canvas.file(g, e.data.case, 0)
			print("FILED seq %d -> card %d (log %d)" % [int(e.seq), n, int(e.data.card)])
	if json_out != "":
		var f = FileAccess.open(json_out, FileAccess.WRITE)
		for d in dumps:
			f.store_line(JSON.stringify(d))
		f.close()
	var logged: Array = events.filter(func(e): return e.type == "vote_tally").map(func(e): return "%s:%s" % [e.target, ",".join(e.data.yes)])
	var replayed: Array = g.w.dlog.entries.filter(func(e): return e["type"] == "vote_tally").map(func(e): return "%s:%s" % [e["target"], ",".join(e["data"]["yes"])])
	if logged != replayed:
		print("VOTES logged   %s\nVOTES replayed %s" % [str(logged), str(replayed)])
	print("REPLAY done steps=%d diverged=%s votes_match=%s day=%d state=%s" % [step, str(diverged), str(logged == replayed), g.w.day, g.state])
	quit()

static func _is_command(e) -> bool:
	return e.type in ["player_command", "player_testimony"] and str(e.data.get("cmd", "")) != ""
