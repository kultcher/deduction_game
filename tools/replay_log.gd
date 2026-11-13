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
## --connections  replay with the connections belief model on (workshop/connections.gd).
##            Logs record it from Nov 13 (case_start) and turn it on by themselves.
## --time     print how long each command took (those over 100 ms), and the total
## --profile  with --time: under each such command, where the time went (the Workshop
##            profiler's spans, slowest first) and how many connections judgements it made
##
## The case is rebuilt from the log's seed, size and script (case_script), so dynamic and
## custom-script cases replay too. The first text divergence is printed; meeting testimony
## can differ in text because the UI splits it into separate records. The replay ends by
## comparing its vote tallies with the log's (votes_match): those must agree.
extends SceneTree
const Replay = preload("res://tools/log_replay.gd")
const Views = preload("res://tools/belief_views.gd")
const Connections = preload("res://workshop/connections.gd")
const Profiler = preload("res://workshop/profiler.gd")

func _init():
	var args = OS.get_cmdline_user_args()
	var path: String = args[0]
	var stop_seq: int = 1 << 30
	var why := false
	var only: Array = []
	var n_worlds := 5
	var json_out := ""
	var timed := false
	var profile := false
	var i := 1
	while i < args.size():
		match args[i]:
			"--why":
				why = true
			"--connections":
				Connections.enabled = true
			"--time":
				timed = true
			"--profile":
				timed = true
				profile = true
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
	var events: Array = Replay.load_events(path)
	# --why: for each vote, the player command it ran inside. A command's record is written
	# after it runs (Game._finish_command), so that's the first command record after the
	# tally, and the view is taken just before replaying it.
	var dump_before := {}
	if why:
		var waiting: Array = []
		for e in events:
			if Replay.is_command(e) and not waiting.is_empty():
				dump_before[int(e.seq)] = waiting
				waiting = []
			if int(e.seq) >= stop_seq:
				break
			if e.type == "vote_tally" and (only.is_empty() or int(e.seq) in only):
				waiting.append(e)
	var dumps: Array = []
	var spent := [0]
	var hooks := {
		"before_command": func(g, e):
			if profile:
				Profiler.start()
			for vote in dump_before.get(int(e.seq), []):
				var v = Views.town(g, n_worlds)
				v["seq"] = int(vote.seq)
				v["label"] = "vote on %s (by %s): %d yes" % [vote.target, vote.data.get("by", "?"), int(vote.data.get("count", 0))]
				dumps.append(v)
				print(Views.render(v)),
		"on_diverge": func(e, step, out):
			print("DIVERGE at seq %d step %d cmd=%s\n--- log:\n%s\n--- replay:\n%s" % [int(e.seq), step, e.data.cmd, str(e.data.get("output", "")).substr(0, 900), out.substr(0, 900)]),
		"on_filed": func(e, n):
			print("FILED seq %d -> card %d (log %d)" % [int(e.seq), n, int(e.data.card)]),
	}
	if timed:
		hooks["after_command"] = func(_g, e, msec: int):
			spent[0] += msec
			var report: Dictionary = Profiler.finish() if profile else {}
			if msec < 100:
				return
			print("TIME seq %d  %-28s %6d ms" % [int(e.seq), str(e.data.cmd), msec])
			if profile:
				_print_profile(report)
	var run: Dictionary = Replay.replay(events, stop_seq, hooks)
	var g = run.g
	if json_out != "":
		var f = FileAccess.open(json_out, FileAccess.WRITE)
		for d in dumps:
			f.store_line(JSON.stringify(d))
		f.close()
	var vt: Array = Replay.votes(events, g, stop_seq)
	if vt[0] != vt[1]:
		print("VOTES logged   %s\nVOTES replayed %s" % [str(vt[0]), str(vt[1])])
	if timed:
		print("TIME all commands %d ms%s" % [spent[0], " (connections on)" if Connections.enabled else ""])
	print("REPLAY done steps=%d diverged=%s votes_match=%s day=%d state=%s" % [run.steps, str(run.diverged), str(vt[0] == vt[1]), g.w.day, g.state])
	quit()

## One command's profile: each span summed over the listeners it ran for, slowest first by
## its own time, then the counters.
func _print_profile(report: Dictionary) -> void:
	var by: Dictionary = {}
	for r in report.get("rows", []):
		if not by.has(r.path):
			by[r.path] = {"calls": 0, "total": 0, "own": 0}
		by[r.path].calls += int(r.calls)
		by[r.path].total += int(r.total_us)
		by[r.path].own += int(r.self_us)
	var paths: Array = by.keys()
	paths.sort_custom(func(a, b): return by[a].own > by[b].own)
	for path in paths.slice(0, 12):
		if by[path].own < 5000:
			break
		print("    %-96s calls %4d  own %7.1f ms  total %7.1f ms" % [path, by[path].calls, by[path].own / 1000.0, by[path].total / 1000.0])
	var counts: Dictionary = {}
	for k in report.get("counters", {}):
		var label: String = str(k).split("|")[-1]
		counts[label] = int(counts.get(label, 0)) + int(report.counters[k])
	if not counts.is_empty():
		print("    counts: %s" % str(counts))
