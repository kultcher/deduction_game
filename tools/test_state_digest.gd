## The state digest (World.state_digest; the 16010 replay drift, Nov 18): the dev log carries
## a full-precision fingerprint of every mind and the world's random stream after each command,
## and the replay reports the first command where its own differs (LogReplay.digest_hooks).
##   godot --headless --path . --script res://tools/test_state_digest.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Replay = preload("res://tools/log_replay.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const LiveCanvas = preload("res://game/workshop_canvas.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _events(g) -> Array:
	# The log as the game writes it, read back the way the replay reads a file (JSON).
	return g.w.dlog.entries.map(func(e): return JSON.parse_string(JSON.stringify(e)))


func _init() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	for i in range(6):
		g.command("wait")
	var events: Array = _events(g)
	var digests: Array = events.filter(func(e): return e.type == "state_digest")
	check(digests.size() >= 6, "a digest is logged after every command (%d)" % digests.size())
	var a: Dictionary = g.w.state_digest()
	check(a == g.w.state_digest(), "taking a digest changes nothing")
	var nisha = g.w.npcs[1]
	var was: float = float(nisha.suspicion.values()[0]) if not nisha.suspicion.is_empty() else 0.0
	if not nisha.suspicion.is_empty():
		var k = nisha.suspicion.keys()[0]
		nisha.suspicion[k] = was + 1e-9
		check(g.w.state_digest().minds[nisha.id] != a.minds[nisha.id], "a change of a billionth in one suspicion changes that mind's digest")
		nisha.suspicion[k] = was
	# The replay of a faithful log matches every digest.
	var report: Dictionary = {}
	Replay.replay(events, 1 << 30, Replay.digest_hooks(events, {}, report))
	check(int(report.get("checked", 0)) >= 6 and not report.has("first"), "a replay of the log matches every digest (%d checked; %s)" % [int(report.get("checked", 0)), str(report.get("first", {}))])
	# A log whose state differed after one command: the replay names that command and mind.
	var tampered: Array = events.duplicate(true)
	var at: int = -1
	var who: String = ""
	var seen := 0
	for i in range(tampered.size()):
		if tampered[i].type == "state_digest":
			seen += 1
			if seen == 3:
				who = str(tampered[i].data.minds.keys()[2])
				tampered[i].data.minds[who] = "0"
				at = i
				break
	var cmd_seq: int = -1
	for j in range(at - 1, -1, -1):
		if tampered[j].type != "state_digest":
			cmd_seq = int(tampered[j].seq)
			break
	var report2: Dictionary = {}
	Replay.replay(tampered, 1 << 30, Replay.digest_hooks(tampered, {}, report2))
	var first: Dictionary = report2.get("first", {})
	check(int(first.get("seq", -1)) == cmd_seq and first.get("minds", []) == [who] and not bool(first.get("rng", true)), "a log that differs after one command is caught there, naming the mind (%s)" % str(first))
	_revision()
	print("State digest: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## A case updated in the Workshop replaces the one it revises (16010: the player retargeted a
## filed case, and the log called every filing new, so the replay kept the old case standing).
## The log names the case replaced, and the replay files the update the same way.
func _revision() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(692, 7)
	for i in range(4):
		g.command("wait")
	var canvas = Canvas.new(LiveCanvas.view(g))
	var people: Array = g.w.npcs
	var original: int = -1
	for card in g.board:
		var ev = Shared.Evidence.normalize_card(card)
		if ev == null or str(ev.get("id", "")) == "":
			continue
		canvas.connect_cards("e:" + str(ev.id), canvas.selected)
		canvas.nodes[canvas.selected].conclusion.target = people[0].id
		original = LiveCanvas.file(g, canvas.compile(canvas.selected))
		if original > 0:
			break
	canvas.nodes[canvas.selected].conclusion.target = people[1].id
	var revised: int = LiveCanvas.file(g, canvas.compile(canvas.selected), original) if original > 0 else -1
	check(original > 0 and revised > original and int(g.board[original - 1].get("superseded_by", 0)) == revised, "a retargeted case revises the one filed from the same premise (#%d -> #%d)" % [original, revised])
	g.command("wait")
	var events: Array = _events(g)
	var filed: Array = events.filter(func(e): return e.type == "workshop_canvas_filed")
	check(filed.size() == 2 and int(filed[1].data.get("revises", 0)) == original and bool(filed[1].data.get("revision", false)) and int(filed[0].data.get("revises", -1)) == 0, "the log names the case each filing replaces (%s)" % str(filed.map(func(e): return e.data.get("revises", "none"))))
	var report: Dictionary = {}
	var r: Dictionary = Replay.replay(events, 1 << 30, Replay.digest_hooks(events, {}, report))
	var rb: Array = r.g.board
	check(rb.size() >= revised and int(rb[original - 1].get("superseded_by", 0)) == revised and int(rb[revised - 1].get("revises", 0)) == original and not report.has("first"), "the replay files the update as a revision too, and every digest matches (%s)" % str(report.get("first", {})))
