## Meeting plan M2d (docs/meeting_flow_plan.md section 3, Steps 5-6): the player's turn
## after the town, and the selective vote resistance lines.
##   - 'hear' lets the bystanders speak, then offers the player's turn; the town only speaks once.
##   - The vote records each voter's parts, and flushes beliefs first.
##   - After the tally, at most two voters say why: someone who accepted the Demonologist's
##     case and still voted no gives the reason their vote actually had; an evil voter
##     never voices its override.
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_hear()
	_test_voter_parts()
	_test_resistance()
	print("Meeting M2d: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _meeting_game(sd: int, day: int = 2):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	if g.state == "approach":
		g.command("decline")
	g.w.day = day
	g.w.phase = C.EVENING
	g.stream_meeting = false
	g._start_meeting()
	return g


func _nominee(g):
	return g.w.living().filter(func(n): return not n.silenced and g.w.can_nominate("player", n.id) == "")[0]


func _test_hear() -> void:
	var g = _meeting_game(9501)
	var t = _nominee(g)
	g.command("nominate %s raw" % t.name.to_lower())
	var out: String = g.command("hear")
	_check(g.w.meeting.pending.get("supporters_done", false) and "Your turn" in out, "'hear' lets the town speak, then offers the player's turn")
	var again: String = g.command("hear")
	_check("had its say" in again, "the town speaks once per nomination")
	_check(g.w.meeting.pending.get("press", "") != "open", "once the town has spoken, the press is behind you")


func _test_voter_parts() -> void:
	var g = _meeting_game(9502)
	var t = _nominee(g)
	g.command("nominate %s raw" % t.name.to_lower())
	g.command("vote no")
	var res: Dictionary = g.w.meeting["results"].back()
	var voters: Array = res.get("yes", []) + res.get("no", [])
	var missing: Array = voters.filter(func(id): return id != t.id and not res.get("voter_parts", {}).has(id) and not g.w.by_id[id].is_evil())
	_check(missing.is_empty(), "every good voter's vote parts are recorded (%d voters)" % voters.size())
	_check(res.has("prev_block") and res.has("prev_block_count"), "the result records the block as it stood before the vote")
	_check(not g.w.meeting.has("vote_parts"), "the per-vote scratch record is cleared after the tally")


## A synthetic tally: v voted no on t; v accepted the player's case against t today.
func _res(g, v, t, vp: Dictionary, block: String = "") -> Dictionary:
	v.dialogue_memory["accepted_cases"] = {t.id: {"day": g.w.day, "key": "test"}}
	return {"nominee": t.id, "by": "player", "yes": [], "no": [v.id], "count": 1, "threshold": 4, "outcome": "fails",
		"prev_block": block, "prev_block_count": 4 if block != "" else 0, "voter_parts": {v.id: vp}}


func _test_resistance() -> void:
	var g = _meeting_game(9503)
	var good: Array = g.w.living().filter(func(n): return not n.is_evil())
	var v = good[0]
	var t = good[1]
	var blk = good[2]
	var lines: Array = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, {"parts": {"prefers_block": -0.4}, "margin": -0.2, "yes": false}, blk.id))
	_check(lines.size() == 1 and blk.name in str(lines[0].get("statement", "")), "a voter who'd sooner hang the one on the block says so")
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, {"parts": {"persuaded_to_spare": -0.3}, "margin": -0.6, "yes": false}))
	_check(lines.size() == 1 and "not ready to put a rope" in str(lines[0].get("statement", "")), "a voter persuaded to spare them says they aren't ready")
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, {"parts": {"martyr_reluctance": -0.5}, "margin": -0.6, "yes": false}))
	_check(lines.size() == 1 and "not ready to put a rope" in str(lines[0].get("statement", "")), "a role's own reluctance is voiced as reluctance")
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, {"parts": {}, "margin": -0.1, "yes": false}))
	_check(lines.size() == 1 and "just not enough" in str(lines[0].get("statement", "")), "a near miss with no other reason is 'short of rope'")
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, {"parts": {}, "margin": -1.5, "yes": false}))
	_check(lines.is_empty(), "a no that wasn't close and had no reason stays unexplained")
	var r: Dictionary = _res(g, v, t, {"parts": {"prefers_block": -0.4}, "margin": -0.2, "yes": false}, blk.id)
	v.dialogue_memory["accepted_cases"][t.id]["day"] = g.w.day - 1
	lines = MindMeeting.vote_resistance_lines(g.w, r)
	_check(lines.is_empty(), "only a case accepted today counts")
	r = _res(g, v, t, {"parts": {"prefers_block": -0.4}, "margin": -0.2, "yes": false}, blk.id)
	v.silenced = true
	_check(MindMeeting.vote_resistance_lines(g.w, r).is_empty(), "the silenced don't explain their vote")
	v.silenced = false
	# Cap: three who accepted and voted no; two speak.
	var many: Dictionary = {"nominee": t.id, "by": "player", "yes": [], "no": [], "count": 1, "threshold": 4, "outcome": "fails",
		"prev_block": "", "prev_block_count": 0, "voter_parts": {}}
	for n in good.slice(2, 5):
		n.dialogue_memory["accepted_cases"] = {t.id: {"day": g.w.day, "key": "test"}}
		many.no.append(n.id)
		many.voter_parts[n.id] = {"parts": {}, "margin": -0.1, "yes": false}
	_check(MindMeeting.vote_resistance_lines(g.w, many).size() == Tuning.Meeting.MAX_VOTE_RESISTANCE_SPEAKERS, "at most %d voters explain themselves" % Tuning.Meeting.MAX_VOTE_RESISTANCE_SPEAKERS)
	# Evil: its good self would have voted yes; the no came from the override and is never voiced as such.
	var evil = g.w.living().filter(func(n): return n.is_evil())[0]
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, evil, t, {"parts": {"suspicion": 0.7}, "margin": 0.3, "yes": true}, blk.id))
	_check(lines.size() == 1 and blk.name in str(lines[0].get("statement", "")), "an evil voter covering a no gives an ordinary townsperson's reason")
