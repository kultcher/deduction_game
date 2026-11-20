## Present a case about the nominee (option (b), Michael, Nov 19): on a nomination the player's
## one word is a filed case about the nominee, judged as at the podium. There's no bare
## "accuse" or "defend", no free nudge to the vote, no trust change for speaking, and it
## doesn't spend the meeting's Present. The town answers it aloud, summarised as at the
## meeting's floor (game/response_bundles.gd).
##   godot --headless --path . --script res://tools/test_nomination_case.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var g = _meeting_game(8105)
	var t = g.w.living_good()[0]
	var other = g.w.living_good()[1]
	var against: int = _file_case(g, t.id, "evil", _evidence_cards(g, 2))
	var elsewhere: int = _file_case(g, other.id, "evil", _evidence_cards(g, 2))
	var plain: int = _evidence_cards(g, 1)[0]
	_check(GameMeeting.nomination_cases(g, t.id).map(func(c): return int(c.n)) == [against], "only the live case about the nominee can be put")
	g.command("nominate %s raw" % t.name.to_lower())
	_check(g.state == "nomination", "the nomination opens")
	var nominee_trust: float = t.trust

	# The old bare statements are gone.
	var old: String = g.command("accuse")
	_check(not g.statement_used and "case <case#>" in old, "'accuse' is no longer a command; the error offers 'case' (%s)" % old)
	_check(not g.statement_used and not ("Cannot" in g.command("defend %d" % against)) and not g.statement_used, "'defend' isn't either")

	# Only a filed case about the nominee.
	var r1: String = g.command("case %d" % plain)
	_check(not g.statement_used and "Only a filed case" in r1, "a plain card is refused (%s)" % r1)
	var r2: String = g.command("case %d" % elsewhere)
	_check(not g.statement_used and "isn't about %s" % t.name in r2, "a case about someone else is refused (%s)" % r2)

	# The case is put and judged.
	g.workshop_deliveries.clear()
	g.command("case %d" % against)
	_check(g.statement_used, "putting the case uses the player's one word on the nomination")
	# The town answers aloud, summarised as at the meeting's floor (Michael, Nov 19): every
	# listener but the nominee is heard once, as a representative, a bundled log line or alone.
	var said: Array = g.last_events.filter(func(e): return e.get("k", "") == "speech")
	var ids: Array = said.map(func(e): return str(e.speaker))
	var hearers: Array = g.w.living().filter(func(v): return v != t and not v.silenced).map(func(v): return v.id)
	_check(not hearers.is_empty() and hearers.all(func(id): return ids.has(id)), "every listener's answer to the case is said (%d answers for %d listeners)" % [said.size(), hearers.size()])
	var reps: Array = said.filter(func(e): return not e.get("agree", []).is_empty())
	var agreed: Array = []
	var more: int = 0
	for rp in reps:
		agreed.append_array(rp.agree.map(func(a): return a.speaker))
		more += int(rp.get("agree_more", 0))
	var bundled: Array = said.filter(func(e): return e.get("bundled", false)).map(func(e): return e.speaker)
	_check(agreed.all(func(id): return bundled.has(id)) and agreed.size() + more == bundled.size(), "those shown agreeing are exactly the bundled lines (%s, +%d)" % [str(agreed), more])
	_check(not reps.is_empty() and not bundled.is_empty(), "(fixture) some answered alike, so the answers were summarised (%d rows)" % (said.size() - bundled.size()))
	_check(not g.presented_today, "it doesn't spend the meeting's Present")
	_check(g.public_presentations.has(against), "the case is now public")
	_check(g.w.meeting.pending.get("statement", "") == "", "no stance reaches the vote as a free nudge")
	_check(is_equal_approx(t.trust, nominee_trust), "speaking costs no trust with the nominee")
	var logged: Array = g.w.dlog.entries.filter(func(e): return e.get("type", "") == "player_statement")
	_check(logged.size() == 1 and logged[0].data.statement == "accuse" and logged[0].data.case, "the log records a case against them")
	var heard = g.w.living().filter(func(v): return v != t)[0]
	_check(heard.claim_record.has(t.id) and str(heard.claim_record[t.id].type) == "evil", "the town records the player's stance from the case")
	var again: String = g.command("case %d" % against)
	_check("already put a case" in again, "only once per nomination (%s)" % again)
	g.command("vote no")
	_check(g.state == "meeting", "the vote follows as before")

	# A case that clears the nominee speaks for them.
	var g2 = _meeting_game(8106)
	var t2 = g2.w.living_good()[0]
	var clears: int = _file_case(g2, t2.id, "good", _evidence_cards(g2, 2))
	_check(GameMeeting.case_direction(g2.board[clears - 1], t2.id) == "defend", "a case that says they're good speaks for them")
	g2.command("nominate %s raw" % t2.name.to_lower())
	g2.command("case %d" % clears)
	var logged2: Array = g2.w.dlog.entries.filter(func(e): return e.get("type", "") == "player_statement")
	_check(g2.statement_used and logged2.size() == 1 and logged2[0].data.statement == "defend", "and is logged as a defence")
	print("Nomination case: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _meeting_game(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	if g.state == "approach":
		g.command("decline")
	g.w.day = 2
	g.w.phase = C.EVENING
	g.stream_meeting = false
	GameMeeting._start_meeting(g)
	return g

func _file_case(g, target_id: String, type: String, board_numbers: Array) -> int:
	var view: Dictionary = WorkshopCanvas.view(g)
	var model = CanvasModel.new(view)
	var root: String = model.selected
	model.nodes[root].conclusion = {"type": type, "target": target_id, "at": view.alignment_epoch}
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
