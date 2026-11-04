## Replays a playtest dev log: player commands in order, Workshop filings at their logged point.
## godot --headless --path . --script res://tools/replay_log.gd -- <log.jsonl> [stop_seq]
extends SceneTree
const Game = preload("res://game/game.gd")
const Canvas = preload("res://game/workshop_canvas.gd")

func _init():
	var args = OS.get_cmdline_user_args()
	var path: String = args[0]
	var stop_seq: int = int(args[1]) if args.size() > 1 else 1 << 30
	var lines = FileAccess.get_file_as_string(path).split("\n")
	var events = []
	for l in lines:
		if l.strip_edges() != "":
			events.append(JSON.parse_string(l))
	var setup = events[0]
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(int(setup.data.seed), int(setup.data.npcs))
	var diverged = false
	var step = 0
	for e in events:
		if int(e.seq) >= stop_seq:
			break
		if e.type in ["player_command", "player_testimony"]:
			var cmd: String = str(e.data.get("cmd", ""))
			if cmd == "":
				continue
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
	print("REPLAY done steps=%d diverged=%s day=%d state=%s" % [step, str(diverged), g.w.day, g.state])
	quit()
