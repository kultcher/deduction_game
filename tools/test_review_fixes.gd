## Fixes from the Nov 7-8 maintenance reports and Codex's #108 review: the stage button while
## the town is still speaking, relayed readings that name their night twice, the protect
## preference gated on agreement, Poisoner candidates over a whole group, and a silenced
## listener's trace reaction.
##   godot --headless --path . --script res://tools/test_review_fixes.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const CourtroomStage = preload("res://ui/courtroom_stage.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")

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
	await _test_stage_button()
	_test_relay_body()
	_test_poisoner_candidates_group()
	_test_silenced_trace()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _speech(id: String, name: String, text: String) -> Dictionary:
	return {"k": "speech", "speaker": id, "name": name, "text": text}


func _test_stage_button() -> void:
	var holder := Control.new()
	root.add_child(holder)
	var stage = CourtroomStage.new()
	holder.add_child(stage)
	await process_frame
	stage.push([_speech("isolde", "Isolde", "I have something to say.")])
	_check(stage.continue_button.text == "Done", "the only speaker so far: Done")
	stage.push([_speech("kiran", "Kiran", "And I.")])
	_check(stage.continue_button.text == "Continue", "once the next speaker is queued, the button says Continue")
	holder.queue_free()
	await process_frame


func _test_relay_body() -> void:
	var vet: String = MindMeeting.relay_body("the demon came for me on night 3 and I lived; it came by way of the Docks", 3, 4)
	_check(not "night 3" in vet and "and I lived" in vet, "the reading's own night isn't said twice (%s)" % vet)
	var med: String = MindMeeting.relay_body("I learned they saw Odette out on the Market on night 1", 3, 4)
	_check(not "night 1" in med and "on the" in med, "another night is said the spoken way (%s)" % med)
	var zero: String = MindMeeting.relay_body("I learned they saw Odette out on the Market on night 0", 3, 4)
	_check("before you arrived" in zero, "night 0 is 'the night before you arrived' (%s)" % zero)


func _test_poisoner_candidates_group() -> void:
	var view: Dictionary = {"people": [{"id": "src"}, {"id": "a"}, {"id": "b"}]}
	var r1: Dictionary = {"id": "r1", "kind": "report", "source": "src", "night": 1}
	var r2: Dictionary = {"id": "r2", "kind": "report", "source": "src", "night": 2}
	var cards: Array = [r1, r2, {"id": "s1", "kind": "sighting", "night": 1, "subjects": ["a"]}, {"id": "s2", "kind": "sighting", "night": 2, "subjects": ["b"]}]
	var one: Dictionary = ReadingChallenges.poisoner_candidates(view, r1, {}, cards)
	var both: Dictionary = {}
	for r in [r1, r2]:
		both.merge(ReadingChallenges.poisoner_candidates(view, r, {}, cards))
	_check(one.keys() == ["a"] and both.has("a") and both.has("b"), "each reading's night names its own candidates; a group takes them all (%s)" % str(both.keys()))


func _test_silenced_trace() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://review_fixes_tests"
	g.new_case(4242, 10)
	var n = g.w.living_good()[0]
	g.state = "day"
	g.moved = true
	g.loc = n.loc if not n.at_home() else n.work
	n.loc = g.loc
	n.busy_with = ""
	g.command("talk " + n.id)
	n.silenced = true
	var before: Dictionary = g.known_haunts.duplicate(true)
	var receipts: int = g.profile_receipts.size()
	var victim = g.w.living_good()[1]
	var t: int = g.add_card({"kind": "trace", "source": "evidence", "day": 1, "phase": C.EVENING, "crime_night": 1,
		"victim": victim.id, "scene": "scene_" + victim.id, "scene_block": victim.home_block,
		"trace_family": "locations", "trace_subtype": "token", "trace_slot": 0, "scene_trace_count": 1,
		"locs": ["bakery", "tavern"], "item_label": "a brass farthing", "text": "Scene trace: brass farthing (the Bakery or the Tavern)."})
	g.command("present %d" % t)
	_check(g.known_haunts == before and g.profile_receipts.size() == receipts, "a silenced listener shown a trace passes on no haunt")
