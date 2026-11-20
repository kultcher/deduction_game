## The pressure of silence (Michael, Nov 20). In a meeting's first pass a good NPC needs at
## least GOOD_ACCUSE_MIN_SUSP suspicion to accuse. If the whole meeting turns up fewer than
## SILENCE_USEFUL_MIN useful things, the speaking order runs once more; in that pass the floor
## is waived and good NPCs get SILENCE_SPEAK_BONUS x (1 - Composure) toward speaking. Evil gets
## no bonus. Whoever speaks first in the second pass opens with a voiced silence-breaker.
extends SceneTree
const Game = preload("res://game/game.gd")
const Tuning = preload("res://sim/tuning.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_constants()
	_bonus()
	_floor()
	_second_pass()
	print("Pressure of silence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _case():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 1
	g.w.begin_meeting()
	return g

func _set_testimony(w, second: bool) -> void:
	w.meeting["testimony"] = {"reactive": {}, "substantive_turns": 0, "done": false, "second_pass": second}

func _constants() -> void:
	_check(is_equal_approx(Tuning.Meeting.GOOD_ACCUSE_MIN_SUSP, 0.2), "the first-pass accusation floor is 0.2 (approved)")
	_check(Tuning.Meeting.SILENCE_USEFUL_MIN == 3, "a second pass when fewer than 3 useful things came out (approved)")
	_check(is_equal_approx(Tuning.Meeting.SILENCE_SPEAK_BONUS, 0.6), "the push to speak is 0.6 x (1 - Composure) (approved)")

func _bonus() -> void:
	var g = _case()
	var w = g.w
	var n = w.living_good()[0]
	n.traits["composure"] = 0.25
	_set_testimony(w, false)
	_check(is_zero_approx(MindMeeting._silence_bonus(w, n)), "no push to speak in the first pass")
	_set_testimony(w, true)
	_check(is_equal_approx(MindMeeting._silence_bonus(w, n), 0.6 * 0.75), "in the second pass, a jittery good NPC is pushed to speak")
	var e = w.npcs.filter(func(m): return m.is_evil())[0]
	e.traits["composure"] = 0.0
	_check(is_zero_approx(MindMeeting._silence_bonus(w, e)), "evil gets no push: its speech is planned")

func _accusations(w, n, tries: int) -> int:
	var said: int = 0
	for i in tries:
		w.meeting["accusations"] = []
		if MindMeeting._public_accusation(w, n) != null:
			said += 1
	return said

func _focus(w, n, t, s: float) -> void:
	for m in w.living():
		if m != n:
			n.suspicion[m.id] = 0.05
	n.suspicion[t.id] = s

func _floor() -> void:
	var g = _case()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	n.traits["composure"] = 0.0
	n.traits["confidence"] = 1.0
	_set_testimony(w, false)
	_focus(w, n, t, 0.15)
	_check(_accusations(w, n, 20) == 0, "in the first pass, a good NPC never accuses from suspicion under the floor")
	_focus(w, n, t, 0.95)
	_check(_accusations(w, n, 20) > 0, "control: the same NPC accuses when it is truly suspicious")
	_set_testimony(w, true)
	_focus(w, n, t, 0.15)
	_check(_accusations(w, n, 40) > 0, "in the second pass the floor is waived: a nervous NPC may fill the silence")

func _second_pass() -> void:
	var g = _case()
	var w = g.w
	var st: Dictionary = MindMeeting.testimony_start(w)
	st["speakers"].insert(3, st["speakers"][0])  # an interjection: a second turn in the first pass
	st["i"] = st["speakers"].size()
	st["useful"] = 0
	var step: Dictionary = MindMeeting.testimony_step(w, st)
	_check(st.get("second_pass", false), "a meeting with nothing useful runs its speaking order once more")
	var ids: Dictionary = {}
	for m in st["speakers"]:
		ids[m.id] = true
	_check(ids.size() == st["speakers"].size() and ids.size() == w.living().filter(func(m): return not m.silenced).size(), "each living speaker gets one turn in the second pass, interjections or not")
	_check(w.meeting["testimony"].get("second_pass", false), "and the meeting knows it is in the second pass")
	var opener: String = ""
	var expected: String = ""
	var guard: int = 0
	while not st.get("done", false) and guard < 40:
		guard += 1
		if step.has("lines") and not step["lines"].is_empty():
			opener = str(step["lines"][0].get("text", ""))
			expected = str(step["lines"][0].get("statement", ""))
			break
		step = MindMeeting.testimony_step(w, st)
	if expected != "":
		_check(expected == "Well, someone ought to say something." and opener != "", "whoever speaks first in the second pass opens by breaking the silence, in their own voice (\"%s\")" % opener)
	var w2 = _case().w
	var st3: Dictionary = MindMeeting.testimony_start(w2)
	st3["i"] = st3["speakers"].size()
	st3["useful"] = Tuning.Meeting.SILENCE_USEFUL_MIN
	MindMeeting.testimony_step(w2, st3)
	_check(not st3.get("second_pass", false), "a meeting that turned up enough doesn't go round again")
	MindMeeting.testimony_step(w2, st3)
	_check(st3.get("silence_checked", false), "and the check runs once per meeting")
