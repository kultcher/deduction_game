## The Augur's reading (Michael, Nov 19): "I crossed paths with the Demon in the morning or
## afternoon of the second day", with the day as an ordinal. Reported at a meeting, it isn't led
## by "This evening", which read as when the paths crossed.
##   godot --headless --path . --script res://tools/test_augur_wording.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var augur = C.role_def("augur")
	check(augur._spoken_text(true, 2) == "I crossed paths with the Demon in the morning or afternoon of the second day", "a yes names the day and the part of it")
	check(augur._spoken_text(false, 3) == "I didn't cross paths with the Demon in the morning or afternoon of the third day", "a no too")
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(7300, 10)
	var w = g.w
	w.day = 2
	w.phase = C.EVENING
	var n = w.living_good()[0]
	var entry: Dictionary = {"role": "augur", "day": 2, "phase": C.EVENING, "data": {"yes": true}, "text": augur._spoken_text(true, 2)}
	var said: String = str(MindMeeting._info_intent(w, n, entry).statement)
	check(said == "I crossed paths with the Demon in the morning or afternoon of the second day.", "at the meeting it's said as is (%s)" % said)
	check(not ("evening" in said.to_lower()), "with no evening in it")
	w.day = 4
	said = str(MindMeeting._info_intent(w, n, entry).statement)
	check(said.begins_with("I crossed paths") and "the second day" in said, "days later it still names the second day (%s)" % said)
	var other: Dictionary = {"role": "dowser", "day": 2, "phase": C.EVENING, "data": {}, "text": "something"}
	check(str(MindMeeting._info_intent(w, n, other).statement).begins_with("On day 2, in the evening"), "other readings keep their lead")
	print("Augur wording: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
