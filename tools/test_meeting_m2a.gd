## Meeting plan M2a (docs/meeting_flow_plan.md section 2, Steps 1-2, Nov 4 design):
##   - 'nominate <name>' rests on the on-deck case (latest live filed case accusing them),
##     '#N' picks another, 'raw' rests on the player's word; a not-yet-public case is put
##     to the town at the nomination and feeds the defence (case_facts).
##   - Exact repeats (same case or card already public) give an informational note only.
##   - An accusing card the listener already weighs against the nominee skips assessment.
##   - Block safety; reactive testimony (move-up, one interjection); crowd fading.
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_on_deck_and_anchored_nomination()
	_test_raw_nomination()
	_test_repeat_notes()
	_test_already_weighed_skip()
	_test_block_safety()
	_test_reactive_testimony()
	_test_crowd_fade()
	print("Meeting M2a: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _meeting_game(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	if g.state == "approach":
		g.command("decline")
	g.w.day = 2
	g.w.phase = C.EVENING
	g.stream_meeting = false
	g._start_meeting()
	return g


## File a real Workshop case ("target is evil") from board cards, as the canvas does.
func _file_case(g, target_id: String, board_numbers: Array) -> int:
	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var root: String = model.selected
	model.nodes[root].conclusion = {"type": "evil", "target": target_id, "at": view.alignment_epoch}
	for num in board_numbers:
		var node: String = "e:" + WorkshopCanvas.Evidence.normalize_card(g.board[int(num) - 1]).id
		if model.nodes.has(node):
			model.connect_cards(node, root)
	return WorkshopCanvas.file(g, model.compile(root), 0)


func _evidence_cards(g, n: int) -> Array:
	var out: Array = []
	for c in g.board:
		if c.get("kind", "") in ["sighting", "info", "claim", "alibi", "location", "evening"] and not c.get("deleted", false):
			out.append(int(c.n))
		if out.size() >= n:
			break
	return out


func _notes(g) -> Array:
	return g.last_events.filter(func(e): return e.get("k", "") == "note")


func _test_on_deck_and_anchored_nomination() -> void:
	var g = _meeting_game(8101)
	var t = g.w.living_good()[0]
	var cards: Array = _evidence_cards(g, 2)
	var first: int = _file_case(g, t.id, cards.slice(0, 1))
	var second: int = _file_case(g, t.id, cards)
	_check(first > 0 and second > 0, "setup: two cases against the target filed")
	var deck: Dictionary = g.on_deck_case(t.id)
	_check(int(deck.get("n", 0)) == second, "the latest live case naming them is on deck (#%d)" % int(deck.get("n", 0)))
	_check(g.cases_naming(t.id).size() >= 2, "both live cases are offered as choices")
	g.command("nominate " + t.name.to_lower())
	var nm: Dictionary = g.w.meeting.get("pending", {})
	_check(g.state == "nomination" and nm.get("nominee", "") == t.id and int(nm.get("case_card", 0)) == second,
		"'nominate <name>' rests on the on-deck case")
	_check(not nm.get("case_facts", []).is_empty(), "the defence answers the case's own cards (case_facts)")
	_check(g.public_presentations.has(second), "the case is now public")
	var other = g.w.living_good()[1]
	_check(g.on_deck_case(other.id).is_empty(), "nobody else has a case on deck")


func _test_raw_nomination() -> void:
	var g = _meeting_game(8102)
	var t = g.w.living_good()[0]
	g.command("nominate " + t.name.to_lower())
	_check(g.state == "nomination" and int(g.w.meeting.pending.get("case_card", 0)) == 0, "with no case, a plain nomination rests on the player's word")
	_check(_notes(g).any(func(e): return "File a case" in str(e.text)), "and the player is told how to nominate on a case")
	var g2 = _meeting_game(8103)
	var t2 = g2.w.living_good()[0]
	_file_case(g2, t2.id, _evidence_cards(g2, 1))
	g2.command("nominate %s raw" % t2.name.to_lower())
	_check(g2.state == "nomination" and int(g2.w.meeting.pending.get("case_card", 0)) == 0, "'raw' skips the on-deck case")
	var g3 = _meeting_game(8104)
	var t3 = g3.w.living_good()[0]
	var out: String = g3.command("nominate %s #1" % t3.name.to_lower())
	_check(g3.state == "meeting" and "isn't one of your filed cases" in out, "a card that isn't a filed case is refused without spending the nomination")


func _test_repeat_notes() -> void:
	var g = _meeting_game(8105)
	var t = g.w.living_good()[0]
	var cards: Array = _evidence_cards(g, 2)
	var case_n: int = _file_case(g, t.id, cards)
	g.command("present %d" % case_n)
	_check(g.public_presentations.has(case_n) and _notes(g).is_empty(), "a first presentation carries no note")
	g.command("nominate " + t.name.to_lower())
	_check(_notes(g).any(func(e): return "already public knowledge" in str(e.text)), "nominating on a case already presented notes it's public")
	_check(not _notes(g).any(func(e): return "voice still carries weight" in str(e.text)), "the nomination note doesn't claim a statement's voice")
	var g2 = _meeting_game(8105)
	var t2 = g2.w.living_good()[0]
	g2.command("nominate %s raw" % t2.name.to_lower())
	var c0: int = _evidence_cards(g2, 1)[0]
	g2.public_citations[c0] = true
	g2.command("accuse %d" % c0)
	_check(_notes(g2).any(func(e): return "your voice still carries weight" in str(e.text)), "accusing with a card already cited notes it, and that the voice still counts")
	var g3 = _meeting_game(8110)
	var t3 = g3.w.living_good()[0]
	g3.command("nominate %s raw" % t3.name.to_lower())
	var fresh: Array = g3.board.filter(func(c): return c.get("kind", "") in ["sighting", "info", "alibi"] and not GameMeeting.already_public(g3, c))
	if not fresh.is_empty():
		g3.command("accuse %d" % int(fresh[0].n))
		_check(not _notes(g3).any(func(e): return "already public" in str(e.text)), "a card cited for the first time, never heard at a meeting, carries no note")


func _test_already_weighed_skip() -> void:
	var g = _meeting_game(8106)
	var t = g.w.living_good()[0]
	var v = g.w.living_good()[1]
	var num: int = _evidence_cards(g, 1)[0]
	var card: Dictionary = g.board[num - 1]
	var rid: String = WorkshopCanvas.Evidence.normalize_card(card).id
	v.workshop_state["reasons"] = {t.id: [{"card_id": rid, "strength": 0.4, "root_ids": [rid]}]}
	_check(Mind.card_already_weighed(v, card, t.id), "a card among the listener's reasons against the nominee counts as already weighed")
	v.workshop_state["reasons"] = {}
	_check(not Mind.card_already_weighed(v, card, t.id), "otherwise it doesn't")


func _test_block_safety() -> void:
	var g = _meeting_game(8107)
	var w = g.w
	var a = w.living_good()[0]
	var d = w.living_good()[1]
	_check(MindMeeting.block_safety(w, d) == 0.0, "nobody on the block: no safety")
	w.meeting["block"] = a.id
	w.meeting["block_count"] = w.vote_threshold() + 2
	var calm: float = MindMeeting.block_safety(w, d)
	_check(calm > 0.0 and MindMeeting.block_safety(w, a) == 0.0, "someone else firmly on the block makes another nominee safer (%.2f), not the one on it" % calm)
	w.meeting["accusations"] = [{"by": "x", "target": d.id}, {"by": "y", "target": d.id}]
	_check(MindMeeting.block_safety(w, d) < calm, "public accusations of the nominee eat into that safety")
	w.meeting["block_count"] = w.vote_threshold() - 1
	_check(MindMeeting.block_safety(w, d) == 0.0, "a block short of the threshold gives no safety")


func _test_reactive_testimony() -> void:
	var g = _meeting_game(8108)
	var w = g.w
	var people: Array = w.living_good()
	var s = people[0]
	var rival = people[1]
	var named = people[2]
	var speakers: Array = [s, people[3], people[4], rival, named]
	var st: Dictionary = {"speakers": speakers, "i": 1, "done": false, "substantive_turns": 0, "reactive": {}, "interjected": {}, "spoken": {s.id: true}}
	w.meeting["testimony"] = st
	var facts: Array = [
		{"kind": "claim", "source": s.id, "subject": [s.id], "role": rival.role},
		{"kind": "accusation", "source": s.id, "subject": [named.id]},
	]
	MindMeeting._queue_reactions(w, st, s, facts)
	_check(st.speakers[1] == rival and st.speakers[2] == named, "a rival claimant, then the person named, move up to speak next")
	_check(int(st.reactive[rival.id].trigger) == 1 and int(st.reactive[named.id].trigger) == 2, "each gets a reactive context")
	_check(MindMeeting._testimony_openness(w, rival) == Tuning.Meeting.REACTIVE_OPENNESS_BONUS, "and an openness bonus on their next beat")
	# Someone who already spoke may interject once, for a rival claim or being named.
	var early = people[3]
	st.spoken[early.id] = true
	st.i = 3
	st.speakers = [s, early, people[4], rival, named]
	MindMeeting._queue_reactions(w, st, s, [{"kind": "accusation", "source": s.id, "subject": [early.id]}])
	_check(st.speakers[3] == early and st.interjected.has(early.id), "an earlier speaker named in an accusation interjects once")
	var before: int = st.speakers.size()
	MindMeeting._queue_reactions(w, st, s, [{"kind": "accusation", "source": s.id, "subject": [early.id]}])
	_check(st.speakers.size() == before, "but only once per meeting")


func _test_crowd_fade() -> void:
	var g = _meeting_game(8109)
	var w = g.w
	var n = w.living_good()[0]
	var st: Dictionary = {"speakers": [n], "i": 0, "done": false, "substantive_turns": 3, "reactive": {}, "interjected": {}, "spoken": {}}
	w.meeting["testimony"] = st
	n.traits["privacy"] = 0.9
	_check(MindMeeting._testimony_openness(w, n) < 0.0, "a private person fades once claims and accusations pile up")
	_check(MindMeeting._testimony_sighting_bar(w, n) > 0.0, "and needs more to volunteer a sighting")
	n.traits["privacy"] = 0.2
	_check(MindMeeting._testimony_openness(w, n) == 0.0, "an open person doesn't")
	st.done = true
	n.traits["privacy"] = 0.9
	_check(MindMeeting._testimony_openness(w, n) == 0.0, "nothing applies once testimony is over")
