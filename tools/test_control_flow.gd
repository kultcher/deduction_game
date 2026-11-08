## UI control flow (Nov 7, with Michael): nothing moves on while something is being shown.
##   - An approach waits for an answer: a wait (or anything else) doesn't get past it.
##   - While the stage speaks or the vote is counted, the action pane offers only Continue
##     (or finishing the count), the command box is off, and map clicks don't act.
##   - The log follows the stage: a speaker's lines reach it when they come forward.
##   - Traces from a search that ends the evening are read before the meeting starts.
##   - Before you move, the pane examines blocks, then visits the one you're looking at;
##     nobody's offered for a talk until you've clicked them.
##   - "Ask seen" never covers this phase; someone who sought you out to tell you their
##     gift shares every sighting they remember.
##   godot --headless --path . --script res://tools/test_control_flow.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")

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


func _labels(scene) -> Array:
	return scene.actions.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion()).map(func(b): return b.text)


func _press(scene, label: String) -> bool:
	for b in scene.actions.get_children():
		if b is Button and not b.is_queued_for_deletion() and b.text == label:
			b.pressed.emit()
			return true
	return false


func _speech(id: String, name: String, text: String) -> Dictionary:
	return {"k": "speech", "speaker": id, "name": name, "text": text, "statement": text, "expression": "neutral", "expression_strength": 1}


func _log(scene) -> String:
	return scene.out.get_parsed_text()


func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 25923
	scene._new_case()
	scene.roles_win.hide()
	await process_frame
	await _test_approach(scene)
	await _test_day_pane(scene)
	await _test_lock(scene)
	await _test_meeting_log(scene)
	await _test_traces_before_meeting(scene)
	_test_sightings()
	print("Control flow: %d checks, %d failures" % [_checks, _fails])
	scene.queue_free()
	await process_frame
	quit(1 if _fails > 0 else 0)


func _fresh(scene, seed_v: int) -> void:
	scene.seed_box.value = seed_v
	scene._new_case()
	scene.roles_win.hide()
	await process_frame


func _test_approach(scene) -> void:
	await _fresh(scene, 25923)
	var g = scene.g
	if g.state == "approach":
		g.command("decline")
	var n = g.w.living_good()[0]
	for agenda in ["gossip", "protect"]:
		g.state = "approach"
		g.moved = false
		g.approach = {"npc": n, "agenda": agenda, "what": "vigil"}
		var ph: int = g.w.phase
		scene._run("wait")
		_check(g.state == "approach" and g.w.phase == ph, "a %s approach waits for an answer: 'wait' doesn't get past it" % agenda)
		scene._run("go tavern")
		_check(g.state == "approach" and not g.moved, "nor does walking off (%s)" % agenda)
		scene._refresh_actions()
		_check(not _labels(scene).any(func(t): return t.begins_with("Wait")), "the pane offers only the answers (%s)" % str(_labels(scene)))
	g.command("no")
	_check(g.state == "day", "an answer moves on")


func _test_day_pane(scene) -> void:
	await _fresh(scene, 25923)
	var g = scene.g
	if g.state == "approach":
		scene._run("decline")
	scene._refresh_all()
	var labels: Array = _labels(scene)
	_check(not labels.any(func(t): return t.begins_with("Talk to ")), "before you've clicked anyone, nobody's offered for a talk (%s)" % str(labels))
	var blocks: Array = C.BLOCKS.keys()
	_check(blocks.all(func(b): return ("Examine " + C.block_name(b)) in labels), "the pane examines each block")
	var b0: String = blocks[0]
	_press(scene, "Examine " + C.block_name(b0))
	labels = _labels(scene)
	_check(scene.map.zoom_block == b0 and ("Visit " + C.block_name(b0)) in labels and "Back to town view" in labels and not labels.any(func(t): return t.begins_with("Examine ")),
		"examining a block zooms in and offers Visit and Back (%s)" % str(labels))
	_press(scene, "Back to town view")
	_check(scene.map.zoom_block == "" and _labels(scene).any(func(t): return t.begins_with("Examine ")), "Back returns to the town view")
	var someone = g.w.living().filter(func(n): return g.can_see_ui(n) and n.busy_with == "")
	if not someone.is_empty():
		scene._on_map_clicked("npc", someone[0].id)
		_check(_labels(scene).has("Talk to " + someone[0].name), "a clicked person is offered for a talk")
	_press(scene, "Examine " + C.block_name(b0))
	_press(scene, "Visit " + C.block_name(b0))
	_check(g.moved and g.w.loc_block(g.loc) == b0, "Visit goes to the block (%s)" % g.loc)


func _test_lock(scene) -> void:
	await _fresh(scene, 25923)
	var g = scene.g
	if g.state == "approach":
		scene._run("decline")
	scene._refresh_all()
	var n = g.w.living()[0]
	var stage = scene.meeting_view.stage
	stage.push([_speech(n.id, n.name, "Hear me out."), _speech(g.w.living()[1].id, g.w.living()[1].name, "And me.")])
	scene._refresh_all()
	_check(_labels(scene) == ["Continue"], "while someone speaks, the pane offers only Continue (%s)" % str(_labels(scene)))
	_check(not scene.input.editable, "and the command box is off")
	var ph: int = g.w.phase
	scene._on_submit("wait")
	scene._on_map_clicked("location", "tavern")
	_check(g.w.phase == ph and not g.moved, "typed commands and map clicks don't act meanwhile")
	_press(scene, "Continue")
	_press(scene, "Continue")
	_check(stage.speaker_label.text == g.w.living()[1].name, "Continue brings the next speaker on")
	_press(scene, "Continue")
	_press(scene, "Continue")
	await process_frame
	_check(not stage.busy() and not _labels(scene).any(func(t): return t.begins_with("Talk to ")) and _labels(scene).any(func(t): return t.begins_with("Examine ")) and scene.input.editable,
		"once it's all said, the actions come back (%s)" % str(_labels(scene)))
	# A count going round holds things too.
	var mv = scene.meeting_view
	mv._res = {"order": []}
	mv._t = 0.0
	scene._refresh_actions()
	_check(_labels(scene) == ["Finish the count"], "while the hand goes round, the pane offers only finishing the count")
	mv.finish()
	scene._refresh_all()
	_check(not _labels(scene).has("Finish the count"), "then the actions come back")


func _test_meeting_log(scene) -> void:
	await _fresh(scene, 25923)
	var g = scene.g
	for i in range(40):
		if g.state == "meeting":
			break
		match g.state:
			"approach": scene._run("decline")
			"talk": scene._run("bye")
			_: scene._run("wait")
		scene.finish_streaming()
		scene.meeting_view.stage.clear()
		if scene.conversation_finished:
			scene._leave_finished_conversation()
			scene.finish_streaming()
			scene.meeting_view.stage.clear()
	_check(g.state == "meeting", "the day ends in a meeting")
	if g.state != "meeting":
		return
	var t = g.w.living().filter(func(n): return not n.silenced and g.w.can_nominate("player", n.id) == "")[0]
	scene._run("nominate %s raw" % t.name.to_lower())
	var stage = scene.meeting_view.stage
	var later: Array = stage.queue.filter(func(q): return q.speaker != "")
	_check(stage.busy(), "a nomination's speakers come forward on the stage")
	if not later.is_empty():
		var last_line: String = str(later.back().text).split("\n")[0]
		_check(not (last_line in _log(scene)), "a speaker still waiting isn't in the log yet")
		stage.clear()
		_check(last_line in _log(scene), "skipping to the circle logs them")
	else:
		var said: String = str(stage.current.get("text", "")).split("\n")[0]
		_check(said in _log(scene), "the speaker on stage is in the log")
		stage.clear()


func _test_traces_before_meeting(scene) -> void:
	# Find an evening with a crime scene to search, then search it as the evening's action.
	for seed_v in [25923, 4242, 7101, 9001, 31337]:
		await _fresh(scene, seed_v)
		var g = scene.g
		for i in range(60):
			if g.state == "day" and not g.moved and g.w.phase == C.EVENING and not g.w.scenes.is_empty():
				break
			match g.state:
				"approach": scene._run("decline")
				"talk": scene._run("bye")
				"meeting": scene._run("done" if g.town_quiet else "wait")
				"nomination": scene._run("vote no")
				"night": scene._run("sleep")
				"over": break
				_: scene._run("wait")
			scene.finish_streaming()
			scene.meeting_view.finish()
			scene.meeting_view.stage.clear()
			if scene.conversation_finished:
				scene._leave_finished_conversation()
				scene.finish_streaming()
				scene.meeting_view.stage.clear()
		if not (g.state == "day" and g.w.phase == C.EVENING and not g.w.scenes.is_empty()):
			continue
		var sid: String = g.w.scenes.keys()[0]
		scene._run("go " + sid)
		scene._run("search")
		if scene.inspect_pages.is_empty() or g.state != "meeting":
			continue
		await process_frame
		_check(not scene.meeting_view.visible and scene.conversation_view.visible, "the evening's traces show before the meeting")
		_check(not scene.meeting_view.stage.is_visible_in_tree(), "the meeting's stage waits meanwhile")
		_check(not _labels(scene).any(func(t): return t.begins_with("Let the town") or t.begins_with("Nominate")), "no meeting actions while you read")
		while not scene.inspect_pages.is_empty():
			scene._inspect_next()
		for i in range(5):
			await process_frame
		_check(scene.meeting_view.visible, "once you've read them, the meeting comes forward")
		scene.finish_streaming()
		scene.meeting_view.stage.clear()
		return
	_check(false, "found an evening crime-scene search that ends in a meeting")


func _test_sightings() -> void:
	var Game = preload("res://game/game.gd")
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7300, 7)
	if g.state == "approach":
		g.command("decline")
	var w = g.w
	var n = w.living_good()[0]
	var x = w.living_good()[1]
	var y = w.living_good()[2]
	var z = w.living_good()[3]
	# Day 1 morning: nothing earlier today to ask about.
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.events = []
	g.command("ask seen today")
	_check(g.last_events.any(func(e): return e.k == "error") and g.questions_left == 3, "first thing on day 1 there's no 'earlier today' to ask about")
	g.events = []
	g.command("ask seen morning")
	_check(g.last_events.any(func(e): return e.k == "error") and g.questions_left == 3, "nor can you ask about the phase you're in")
	# Openness: someone who sought you out to tell you their gift shares all they remember.
	w.day = 2
	w.phase = 1
	n.traits["gossip"] = 0.0
	n.traits["insight"] = 1.0
	n.pressure = 0.0
	n.beliefs = [
		{"kind": "saw", "who": x.id, "loc": "tavern", "block": "square", "day": 2, "phase": 0, "with": ""},
		{"kind": "saw", "who": y.id, "loc": "smithy", "block": "market", "day": 2, "phase": 0, "with": ""},
		{"kind": "saw", "who": z.id, "loc": "well", "block": "square", "day": 2, "phase": 0, "with": ""}]
	Mind.Dialogue.begin_conversation(n.dialogue_memory)
	var closed: Dictionary = Mind.answer_today(w, n, "", "")
	var named_closed: int = [x, y, z].filter(func(p): return closed.facts.any(func(f): return f.get("subject", []) == [p.id])).size()
	n.dialogue_memory["conversation"]["opened_up"] = true
	var opened: Dictionary = Mind.answer_today(w, n, "", "")
	var named_open: int = [x, y, z].filter(func(p): return opened.facts.any(func(f): return f.get("subject", []) == [p.id])).size()
	_check(named_open == 3 and named_open > named_closed, "someone who approached to tell you their gift shares every sighting they remember (%d vs %d)" % [named_open, named_closed])
