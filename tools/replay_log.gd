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
const Replay = preload("res://tools/log_replay.gd")
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
	var hooks := {
		"before_command": func(g, e):
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
	print("REPLAY done steps=%d diverged=%s votes_match=%s day=%d state=%s" % [run.steps, str(run.diverged), str(vt[0] == vt[1]), g.w.day, g.state])
	quit()
