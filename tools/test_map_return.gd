## The map during a conversation or meeting (Michael, Nov 17; the breadcrumbs, Nov 28):
##   - while the player looks at the map in a conversation, the conversation's options are
##     hidden; they go back to the conversation to carry on;
##   - the breadcrumb row takes them back: the person's crumb to the conversation, Meeting to
##     the circle. The old "Return to conversation/meeting" button and the "Look at the map"
##     toggles are retired (Michael, Nov 28).
##   godot --headless --path . --script res://tools/test_map_return.gd
extends SceneTree

var _checks: int = 0
var _fails: int = 0

func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1

func _initialize() -> void:
	call_deferred("_run")

const Crumbs = preload("res://ui/nav_crumbs.gd")

func _press(scene, label: String) -> void:
	for c in Crumbs.crumbs(scene):
		if c.label == label and c.go.is_valid():
			c.go.call()
			return

func _labels(scene, box) -> Array:
	return box.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion()).map(func(b): return b.text)

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 25923
	scene._new_case()
	scene.roles_win.hide()
	var g = scene.g
	if g.state == "approach":
		g.command("decline")
	# A conversation.
	var n = g.w.living()[0]
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	scene.conversation_show_map = false
	scene._refresh_all()
	var talk_opts: Array = _labels(scene, scene.conversation_view.controls)
	_check(talk_opts.size() > 0 and Crumbs.crumbs(scene).back().label == n.name and Crumbs.crumbs(scene).back().current, "in the conversation view: its options, and its crumb is current (%s)" % str(talk_opts))
	_check(scene.get_node_or_null("MapReturn") == null, "the old 'Return to …' button is gone")
	scene.conversation_show_map = true
	scene._refresh_all()
	var lower: Array = _labels(scene, scene.actions)
	_check(not talk_opts.any(func(t): return t in lower), "on the map: none of the conversation's options are offered (%s)" % str(lower))
	_check(not "Look at the map" in lower and not "Look at conversation" in lower, "and no 'Look at …' toggle: the crumbs do that now")
	_check(not scene.conversation_view.visible, "...and the conversation view, with its own options, is put away")
	_press(scene, n.name)
	_check(not scene.conversation_show_map and scene.conversation_view.visible, "the person's crumb brings the conversation back")
	_check(_labels(scene, scene.conversation_view.controls).size() > 0, "...with its options")
	# A meeting.
	g.state = "meeting"
	g.talk_with = null
	scene.meeting_show_map = true
	scene._refresh_all()
	_check(not _labels(scene, scene.actions).any(func(t): return t in ["Back to the meeting", "Look at the map"]), "on the map during a meeting: no old toggle")
	_press(scene, "Meeting")
	_check(not scene.meeting_show_map and scene.meeting_view.visible, "the Meeting crumb brings the meeting circle back")
	print("Map return: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails else 0)
