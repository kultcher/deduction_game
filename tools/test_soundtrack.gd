## Background music (Nov 8): the two town-square tracks play whole, A then B then A,
## overlapping through each track's fade-out. Headless runs stay silent.
##   godot --headless --path . --script res://tools/test_soundtrack.gd
extends SceneTree

const Soundtrack = preload("res://ui/soundtrack.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Playlist order.
	_check(Soundtrack.next_track(0, 2) == 1, "A is followed by B")
	_check(Soundtrack.next_track(1, 2) == 0, "B is followed by A again")
	# Hand-off timing.
	_check(not Soundtrack.should_start_next(280.0, 290.85, 6.0), "no hand-off before the overlap window")
	_check(Soundtrack.should_start_next(285.0, 290.85, 6.0), "the next track starts inside the last six seconds")
	_check(not Soundtrack.should_start_next(0.0, 0.0, 6.0), "a stream with no length never hands off")

	# Both tracks load and are whole tracks, not short loops.
	for path in Soundtrack.TRACKS:
		var s := load(path) as AudioStream
		_check(s != null, "loads " + path.get_file())
		if s != null:
			var length := s.get_length()
			_check(length > 280.0 and length < 300.0, "%s is a full track (%.1fs)" % [path.get_file(), length])
			_check(length > Soundtrack.OVERLAP * 10.0, "%s is much longer than the overlap" % path.get_file())

	# Headless: the node stays silent and creates no players.
	var node: Node = Soundtrack.new()
	root.add_child(node)
	await process_frame
	_check(node.players.is_empty(), "headless runs create no players")
	_check(node.current == -1, "headless runs play nothing")
	_check(not node.is_processing(), "headless runs don't poll")
	node.queue_free()

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
