## Fixes from playtest 1709 (Nov 8): reason wording, no repeated accusations, vote lines that
## don't invent the Demonologist's case, the silenced in conversation, wards shown for free,
## and gossip / Town Hall results in the conversation view.
##   godot --headless --path . --script res://tools/test_playtest_1709.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")

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


func _fresh(seed_v: int = 4242, n: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://playtest_1709_tests"
	g.new_case(seed_v, n)
	return g


func _run() -> void:
	_test_surveyor_wording()
	_test_no_repeat_accusation()
	_test_vote_line_names_the_nominator()
	_test_silenced_conversation()
	await _test_place_readings_in_view()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_surveyor_wording() -> void:
	var view: Dictionary = {"people": [{"id": "a", "name": "A", "home": "docks"}, {"id": "b", "name": "B", "home": "market"}, {"id": "s", "name": "S", "home": "hill"}]}
	var card: Dictionary = {"source": "s", "role": "surveyor", "data": {"block": "docks", "same": true}}
	var on_block: Array = ReasonAttribution._report_why_pair(view, card, "a", "x")
	var off_block: Array = ReasonAttribution._report_why_pair(view, card, "b", "x")
	_check("and they live there" in str(on_block[1]), "a Surveyor reason about someone on the block still says they live there")
	_check(not "they live there" in str(off_block[1]) and "the evil has to be somewhere else" in str(off_block[1]), "off a one-sided block, it says the evil is elsewhere (%s)" % off_block[1])
	var bad: Dictionary = {"source": "b", "role": "archivist", "data": {"role": "scion", "pair": ["a", "s"]}}
	var own: Array = ReasonAttribution._report_why_pair(view, bad, "b", "x")
	_check("as I know them" in str(own[1]) and not "what we know" in str(own[1]), "an impossible report 'doesn't fit the facts as I know them' (%s)" % own[1])


func _test_no_repeat_accusation() -> void:
	var g = _fresh()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	w.meeting = {"accusations": [{"by": n.id, "target": t.id}]}
	_check(MindMeeting.already_accused(w, n, t.id), "an accusation made at this meeting is remembered")
	_check(not MindMeeting.already_accused(w, w.living_good()[2], t.id), "someone else's accusation doesn't count as theirs")
	# A supporter who already accused the nominee doesn't pile on again.
	n.suspicion[t.id] = 0.95
	var MindSupport = preload("res://sim/mind_support.gd")
	var choice: Dictionary = MindSupport.choose(w, n, t, {"accused": 0, "for_ids": [], "case_facts": []})
	_check(choice.get("move", "") != "pile_on", "a speaker who already accused them doesn't pile on at the same meeting")


func _test_vote_line_names_the_nominator() -> void:
	var g = _fresh()
	var w = g.w
	var v = w.living_good()[0]
	var t = w.living_good()[1]
	var nom = w.living_good()[2]
	var by_npc: Dictionary = MindMeeting._resistance_line(w, v, t, "vote_no_short_of_rope", {"by": nom.id, "prev_block": ""})
	var by_player: Dictionary = MindMeeting._resistance_line(w, v, t, "vote_no_short_of_rope", {"by": "player", "prev_block": ""})
	_check(not "Demonologist" in str(by_npc.get("text", "")) and nom.name in str(by_npc.get("text", "")), "a no-vote on an NPC's nomination doesn't hand the Demonologist a case (%s)" % by_npc.get("text", ""))
	_check("Your case" in str(by_player.get("text", "")), "a no-vote on the Demonologist's nomination still answers them")


func _test_silenced_conversation() -> void:
	var g = _fresh()
	var n = g.w.living_good()[0]
	n.silenced = true
	g.state = "day"
	g.moved = true
	g.loc = n.loc if not n.at_home() else n.work
	n.loc = g.loc
	n.busy_with = ""
	g.command("talk " + n.id)
	var spoke: bool = g.last_events.any(func(e): return e.get("k", "") == "speech" and e.get("speaker", "") == n.id)
	_check(g.state == "talk" and not spoke, "a silenced townsperson gives no greeting")
	var before: int = g.questions_left
	g.command("ask gift")
	_check(g.questions_left == before, "asking a silenced townsperson costs nothing (they can't answer)")
	var other = g.w.living_good()[1]
	var num: int = g.add_card({"kind": "sighting", "source": "player", "subject": [other.id], "block": "market", "day": 1, "phase": C.MORNING, "text": "A sighting to show"})
	g.command("present %d against %s" % [num, other.id])
	var spoke2: bool = g.last_events.any(func(e): return e.get("k", "") == "speech" and e.get("speaker", "") == n.id)
	_check(g.questions_left == before - 1 and not spoke2, "showing them a card costs a question, and they don't answer (%d left)" % g.questions_left)


func _test_place_readings_in_view() -> void:
	root.size = Vector2i(1920, 1080)
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	var g = _fresh()
	scene.g = g
	scene.map.set_game(g)
	scene.cast_list.setup(g)
	scene.profile.setup(g, scene.case_state)
	scene.case_view.set_game(g)
	scene.meeting_view.set_game(g)
	g.state = "day"
	g.moved = true
	g.loc = "town_hall"
	g.w.phase = C.MORNING
	scene._run("records")
	_check(not scene.inspect_pages.is_empty() and "Town Hall" in str(scene.inspect_pages[0].title), "Town Hall records come up in the conversation view")
	_check(scene.conversation_view.visible and "either the" in str(scene.inspect_pages[0].text), "the page shows what the records said")
	scene._inspect_next()
	_check(scene.inspect_pages.is_empty(), "Done closes the page")
	# The evening's last question opens the meeting: the log waits until they leave.
	g.state = "day"
	g.moved = true
	g.w.phase = C.EVENING
	var n = g.w.living_good()[3]
	n.silenced = false
	n.busy_with = ""
	g.loc = n.loc if not n.at_home() else n.work
	n.loc = g.loc
	scene._run("talk " + n.id)
	g.questions_left = 1
	var before: String = scene.out.get_parsed_text()
	scene._run("ask night")
	var during: String = scene.out.get_parsed_text().substr(before.length())
	_check(scene.conversation_finished and not "town meeting" in during, "the meeting's header isn't in the log while the finished conversation is still up")
	scene._leave_finished_conversation()
	for i in range(3): await process_frame
	var after: String = scene.out.get_parsed_text().substr(before.length())
	_check("town meeting" in after or scene.meeting_view.presenting() or scene.meeting_view.stage_busy(), "leaving the conversation hands the meeting to the stage")
	_check(scene._deferred_meeting_events.is_empty() and scene._deferred_log_events.is_empty(), "nothing is left waiting")
	for i in range(3): await process_frame
	scene.free()
