## A streamed meeting (the UI shows testimony speaker by speaker) ends in exactly the same
## state as the same meeting computed in one go: same lines, cards, beliefs and trust.
##   godot --headless --path . --script res://tools/test_meeting_stream.gd
extends SceneTree
const Game = preload("res://game/game.gd")
var fails = 0

func _init() -> void:
	for sd in [42, 7104, 54875]:
		var a = _play(sd, false)
		var b = _play(sd, true)
		_check(a.text == b.text, "seed %d: the same testimony, in the same order" % sd)
		_check(a.state == b.state, "seed %d: the same cards, beliefs and trust after %d meetings" % [sd, a.meetings])
		_check(b.steps > b.meetings, "seed %d: testimony arrived in steps (%d steps over %d meetings)" % [sd, b.steps, b.meetings])
	print("MEETING STREAM FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _play(sd: int, stream: bool) -> Dictionary:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_logs"
	g.stream_meeting = stream
	g.new_case(sd, 10)
	var text = ""
	var steps = 0
	var meetings = 0
	for i in range(200):
		if g.state == "over" or g.w.day > 3:
			break
		var cmd = "wait"
		match g.state:
			"approach": cmd = "decline"
			"talk": cmd = "bye"
			"meeting": cmd = "done" if g.town_quiet else "wait"
			"nomination": cmd = "vote no"
			"night": cmd = "sleep"
		var out: String = g.command(cmd)
		if g.meeting_streaming():
			_check(g.command("wait") == "The town is still speaking.", "commands wait while the town speaks") if steps == 0 else null
			while g.meeting_streaming():
				out += "\n" + g.testimony_step()
				steps += 1
		if "the town meeting ===" in out:
			meetings += 1
		text += _strip(out) + "\n"
	var state = []
	for c in g.board:
		state.append(c.get("text", ""))
	for n in g.w.npcs:
		state.append([n.id, snappedf(n.trust, 0.0001), n.suspicion.keys().map(func(k): return [k, snappedf(n.suspicion[k], 0.0001)])])
	return {"text": text, "state": str(state), "steps": steps, "meetings": meetings}

## Streaming splits a meeting's output across steps; compare the words, not the blank lines.
func _strip(s: String) -> String:
	return "\n".join(PackedStringArray(Array(s.split("\n")).filter(func(l): return l.strip_edges() != "")))

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1
