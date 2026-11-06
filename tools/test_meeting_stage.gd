## Meeting plan M3a (docs/meeting_flow_plan.md section 5.2): the courtroom stage.
##   - Townsfolk speech comes forward one speaker at a time; the player's own lines don't.
##   - A line reveals, holds, and moves on; a click finishes it, a second brings the next.
##   - A vote waits for the speakers before it, and what's said after the tally waits for
##     the count; finishing the count skips the wait.
##   - Last words keep the circle up after the meeting closes; the map returns after.
##   godot --headless --path . --script res://tools/test_meeting_stage.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const VNPortraits = preload("res://ui/vn_portraits.gd")
const CourtroomStage = preload("res://ui/courtroom_stage.gd")

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


func _speech(id: String, name: String, text: String, expression: String = "neutral") -> Dictionary:
	return {"k": "speech", "speaker": id, "name": name, "text": text, "statement": text, "expression": expression, "expression_strength": 1}


func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 25923
	scene._new_case()
	scene.roles_win.hide()
	await process_frame
	_test_portraits(scene)
	await _test_stage()
	await _test_meeting(scene)
	print("Meeting stage: %d checks, %d failures" % [_checks, _fails])
	scene.queue_free()
	await process_frame
	quit(1 if _fails > 0 else 0)


func _test_portraits(scene) -> void:
	var same: bool = true
	for cast_member in C.CAST:
		for expr in VNPortraits.EXPRESSIONS:
			same = same and VNPortraits.texture(cast_member.id, expr) == scene.conversation_view._expression_texture(cast_member.id, expr)
	_check(same, "the stage and the day conversation share one set of portraits")
	_check(VNPortraits.texture("isolde", "nonsense") == VNPortraits.texture("isolde", "neutral"), "an unknown expression falls back to neutral")


func _test_stage() -> void:
	var holder = Control.new()
	holder.size = Vector2(1200, 700)
	root.add_child(holder)
	var stage = CourtroomStage.new()
	holder.add_child(stage)
	await process_frame
	var done: Array = [0]
	stage.finished.connect(func(): done[0] += 1)
	var n: int = stage.push([{"k": "narration", "text": "The town gathers."}, _speech("player", "You", "I have a case."),
		_speech("isolde", "Isolde", "I was at the chapel all night.", "concerned"), _speech("bart", "Bart", "Hm.")])
	_check(n == 2 and stage.busy() and stage.visible, "townsfolk speech comes forward; narration and your own lines stay in the log")
	_check(stage.speaker_label.text == "Isolde" and stage.portrait.texture == VNPortraits.texture("isolde", "concerned"), "the speaker comes forward wearing the line's expression")
	_check(stage.speech.visible_characters == 0, "the line starts unrevealed")
	stage.advance()
	_check(stage.speech.visible_characters == -1 and stage.speaker_label.text == "Isolde", "a click finishes the line")
	stage.advance()
	_check(stage.speaker_label.text == "Bart" and stage.continue_button.text == "Done", "a second click brings on the next speaker")
	# Left alone, the line reveals and the stage moves on by itself.
	stage._process(10.0)
	stage._process(10.0)
	_check(not stage.busy() and not stage.visible and done[0] == 1, "left alone, the last line reveals, holds and clears the stage")
	stage.push([_speech("agnes", "Agnes", "...")])
	_check(stage.muted_banner.visible, "a silenced speaker shows the stolen-voice banner")
	stage.clear()
	_check(not stage.busy() and done[0] == 2, "'Back to the circle' clears the stage")
	stage.hold_for(1.2)
	stage.push([_speech("agnes", "Agnes", "Good evening.")])
	_check(stage.busy() and not stage.visible, "during the dusk arrival the ring shows first")
	stage._process(1.3)
	_check(stage.visible and stage.speaker_label.text == "Agnes", "then the first speaker comes forward")
	stage.clear()
	holder.queue_free()
	await process_frame


func _test_meeting(scene) -> void:
	var g = scene.g
	var mv = scene.meeting_view
	# Into the meeting: play the day out.
	for i in range(40):
		if g.state == "meeting":
			break
		match g.state:
			"approach":
				scene._run("decline")
			"talk":
				scene._run("bye")
			_:
				scene._run("wait")
		scene.finish_streaming()
		if scene.conversation_finished:
			scene._leave_finished_conversation()
			scene.finish_streaming()
	_check(g.state == "meeting", "the day ends in a meeting")
	if g.state != "meeting":
		return
	mv.stage.clear()
	var t = g.w.living().filter(func(n): return not n.silenced and g.w.can_nominate("player", n.id) == "")[0]
	scene._run("nominate %s raw" % t.name.to_lower())
	_check(mv.visible and mv.stage_busy() and mv.stage.queue.size() + 1 >= 1, "a nomination's defence comes forward on the stage")
	_check(mv.stage.status_pill.text.begins_with("Nominee's Defence") or mv.stage.status_pill.text.begins_with("Accuser's Case"), "the status pill names the trial step (%s)" % mv.stage.status_pill.text)
	scene._run("vote no")
	var res: Dictionary = g.w.meeting["results"].back()
	_check(mv.stage_busy() == (not mv._deferred.is_empty()) and mv.animating(), "the vote waits for the speakers before it, and counts as animating")
	mv.finish()
	_check(not mv.animating() and mv._target.size() == res["order"].size(), "finishing skips to the full count")
	_check(mv._after_count.is_empty(), "what was said after the tally comes forward once the count is done")
	mv.stage.clear()
	# Synthetic: a vote waiting on the stage starts the moment the stage clears.
	mv._seen_results = 0
	mv.stage.push([_speech(t.id, t.name, "Spare me.")])
	mv.refresh()
	_check(not mv._deferred.is_empty() and mv._t < 0.0, "a vote doesn't count over a speaker")
	mv.stage.clear()
	_check(mv._deferred.is_empty() and mv._t >= 0.0, "the hand starts once the stage clears")
	mv.finish()
	# Close the meeting: whatever the gallows says keeps the circle up until it's heard.
	for i in range(60):
		if g.state not in ["meeting", "nomination"]:
			break
		scene._run("vote no" if g.state == "nomination" else ("done" if g.town_quiet else "wait"))
		scene.finish_streaming()
		mv.finish()
	_check(g.state not in ["meeting", "nomination"], "the meeting closes")
	mv.stage.push([_speech(t.id, t.name, "You'll regret this.")])
	scene._refresh_all()
	_check(mv.visible and not scene.map_stage.visible, "last words keep the circle up after the meeting closes")
	_check(mv.stage.status_pill.text == "Last Words", "the status pill reads Last Words")
	mv.stage.clear()
	await process_frame
	_check(not mv.visible and scene.map_stage.visible, "once they're heard, the map comes back")
