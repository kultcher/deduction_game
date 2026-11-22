## "Call on" (docs/design/withheld_readings.md, Michael, Nov 22): the Demonologist asks one
## person at the meeting to share what they haven't told the town. Once per meeting, outside a
## nomination; a silenced voice can't answer. What they say is MindCallOn's (Beadle); this
## covers the command, the button and the plumbing.
##   godot --headless --path . --script res://tools/test_call_on.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const MainActions = preload("res://ui/main_actions.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _meeting_game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 10)
	if g.state == "approach":
		g.command("decline")
	g.w.day = 2
	g.w.phase = C.EVENING
	g.stream_meeting = false
	GameMeeting._start_meeting(g)
	return g

func _kinds(g, k: String) -> Array:
	return g.last_events.filter(func(e): return e.get("k", "") == k)

func _run() -> void:
	var g = _meeting_game()
	var n = g.w.living().filter(func(x): return not x.silenced)[0]
	var rng = g.w.rng.state
	check(not GameMeeting.called_on_today(g) and GameMeeting.call_on_rejection(g, n) == "", "at a fresh meeting anyone who can speak can be called on")
	g.command("call " + n.name)
	var said: Array = _kinds(g, "speech")
	check(_kinds(g, "narration").any(func(e): return n.name in str(e.text) and "call on" in str(e.text)), "the log says who you called on")
	check(said.size() >= 1 and said[0].speaker == n.id, "and they answer")
	check(g.w.meeting.get("called_on", "") == n.id and GameMeeting.called_on_today(g), "it's spent for this meeting")
	check(g.w.rng.state == rng, "the stub's answer moves no RNG")
	var other = g.w.living().filter(func(x): return x.id != n.id and not x.silenced)[0]
	g.command("call " + other.name)
	check(_kinds(g, "error").any(func(e): return str(e.text) == GameMeeting.CALLED_ALREADY) and _kinds(g, "speech").is_empty(), "once per meeting: a second call is refused")
	g.command("call nobody-of-that-name")
	check(not _kinds(g, "error").is_empty(), "an unknown name is refused")

	# A silenced voice can't answer, and that doesn't spend the call.
	var g2 = _meeting_game()
	var s = g2.w.living()[0]
	s.silenced = true
	g2.command("call " + s.name)
	check(_kinds(g2, "error").any(func(e): return "voice has been stolen" in str(e.text)) and not GameMeeting.called_on_today(g2), "a silenced voice can't be called on, and the call isn't spent")

	# A new meeting brings a new call.
	g2.w.meeting["called_on"] = s.id
	g2.w.day = 3
	GameMeeting._start_meeting(g2)
	check(not GameMeeting.called_on_today(g2), "a new meeting, a new call")

	# The button: there at the meeting, greyed once spent.
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	scene.pacing_enabled = false
	root.add_child(scene)
	await process_frame
	var g3 = _meeting_game()
	scene.g = g3
	MainActions.refresh(scene)
	var btn = _button(scene, "Call on…")
	check(btn != null and not btn.disabled and "Once per meeting" in btn.tooltip_text, "the meeting offers Call on…, with its tooltip")
	g3.w.meeting["called_on"] = g3.w.living()[0].id
	MainActions.refresh(scene)
	btn = _button(scene, "Call on…")
	check(btn != null and btn.disabled and btn.tooltip_text == GameMeeting.CALLED_ALREADY, "once spent, it's greyed and says why")
	var terms = preload("res://ui/text_terms.gd").new()
	check(terms.find_matches("Call on is once per meeting.").any(func(r): return str(r.get("id", "")) == "mechanic:call_on"), "Call on is a glossary term (Michael's wording)")
	scene.queue_free()
	print("Call on: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _button(scene, text: String):
	for b in scene.actions.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null
