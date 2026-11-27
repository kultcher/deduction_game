## The Day/Phase plaque on every screen (Michael, Nov 27): the map, a conversation, the town
## meeting and the Case board, placed where it covers nothing. And the whole-town hint
## (Michael, Nov 27: "Examine a block to look closer.").
##   godot --headless --path . --script res://tools/test_day_plaque.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const GameMeeting = preload("res://game/game_meeting.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int = 3) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	scene.pacing_enabled = false
	root.add_child(scene)
	await _frames()
	var g = scene.g
	if g.state == "approach":
		scene._run("decline")
	scene._refresh_all()
	await _frames()
	var p: Control = scene.day_panel
	check(p.get_parent() == scene, "the plaque sits on the main screen, not inside the map")
	check(p.visible and scene.day_label.text.begins_with("Day 1"), "on the map it shows the day (%s)" % scene.day_label.text.replace("\n", " / "))
	check(scene.map_stage.get_global_rect().encloses(p.get_global_rect()), "at the top of the map")
	check(scene.actions.find_children("*", "Label", true, false).any(func(l): return l.text == "Examine a block to look closer."), "the whole-town hint is Michael's short one")
	# A conversation covers the map; the plaque stays above it.
	var n = g.w.living().filter(func(x): return g.can_see(x))[0]
	scene._run("go " + n.id)
	scene._run("talk " + n.id)
	await _frames()
	await _frames(30)
	check(g.state == "talk" and scene.conversation_view.visible and p.visible, "in a conversation it still shows (state %s, view %s, plaque %s)" % [g.state, scene.conversation_view.visible, p.visible])
	check(p.get_index() > scene.case_view.get_index(), "and it's drawn above the screens")
	scene._run("bye")
	await _frames()
	# The Case board.
	scene._open_case_view()
	await _frames()
	var back: Rect2 = scene.case_view.back_button.get_global_rect()
	check(p.visible and p.get_global_rect().position.x >= back.end.x and not p.get_global_rect().intersects(back), "on the Case board it sits beside Back to town")
	scene.case_view.visible = false
	# The meeting.
	g.w.day = 2
	g.w.phase = C.EVENING
	g.stream_meeting = false
	GameMeeting._start_meeting(g)
	scene._refresh_all()
	scene.meeting_view.finish()
	await _frames()
	var mr: Rect2 = scene.meeting_view.get_global_rect()
	check(p.visible and scene.meeting_view.visible and mr.encloses(p.get_global_rect()) and p.get_global_rect().position.x < mr.position.x + mr.size.x * 0.25, "at the meeting it takes the circle's top-left corner")
	check(scene.day_label.text.ends_with("Town meeting"), "and says Town meeting (%s)" % scene.day_label.text.replace("\n", " / "))
	scene.queue_free()
	print("Day plaque: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
