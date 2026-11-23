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
	check("morning or afternoon of the second day" in said and not said.begins_with("This"), "at the meeting it names the morning or afternoon of the day, with no lead (%s)" % said)
	check(not ("evening" in said.to_lower()), "with no evening in it")
	# Each voice says it its own way, keeping the morning or afternoon of the day (Michael, Nov 19).
	var Dialogue = preload("res://sim/dialogue.gd")
	var voiced_ok: bool = true
	for voice in ["agnes", "bart", "constance", "dorian", "edda", "fenwick", "greta", "hollis", "isolde", "jory", "kiran", "lian", "merrin", "nisha", "odette"]:
		for key in ["augur_yes", "augur_no"]:
			var line: String = Dialogue.voice_line(voice, key, "", {"day": "the second day"})
			voiced_ok = voiced_ok and line != "" and "morning" in line.to_lower() and "afternoon" in line and "the second day" in line
	check(voiced_ok, "all fifteen voices have both lines, each with the morning or afternoon of the day")
	check(Dialogue.voice_line("hollis", "augur_yes", "", {"day": "the second day"}) == "My path converged with the Demon's during the morning or afternoon of the second day.", "Hollis says it in his own words")
	w.day = 4
	said = str(MindMeeting._info_intent(w, n, entry).statement)
	check("the second day" in said, "days later it still names the second day (%s)" % said)
	var other: Dictionary = {"role": "dowser", "day": 2, "phase": C.EVENING, "data": {}, "text": "something"}
	check(str(MindMeeting._info_intent(w, n, other).statement).begins_with("On the second day, in the evening"), "other readings keep their lead, the day spoken (Coroner, 51795)")
	print("Augur wording: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
