## Taking a case back in public, as the player sees it (BACKLOG "Believable public
## revisions"; Michael's wording, Nov 18): the command and its narration, the refusals,
## the card list's mark, and the revision-with-new-evidence narration.
##   godot --headless --path . --script res://tools/test_withdraw_ui.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const GamePresentation = preload("res://game/game_presentation.gd")
const CardList = preload("res://ui/card_list.gd")

var checks = 0
var fails = 0
var _texts: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.detailed_logging = false
	g.new_case(692, 7)
	g.w.day = 2
	var goods: Array = g.w.living_good()
	var reader = goods[0]
	var other = goods[2]
	var accused = goods[1]
	var dowse: int = _read(g, reader, "dowser", 1, {"group": [accused.id], "count": 1})
	var case_n: int = _file(g, accused.id, [dowse])
	check(case_n > 0, "a case can be filed")
	if case_n <= 0:
		quit(1)
		return
	# A revision that cites a new card, after the town heard the first version.
	var second: int = _read(g, other, "dowser", 1, {"group": [accused.id], "count": 1})
	var rev_n: int = _file(g, accused.id, [dowse, second], case_n)
	check(rev_n > 0, "a revision can be filed")
	g.public_presentations[case_n] = 2
	var line: String = GamePresentation._revision_narration(g, g.board[rev_n - 1])
	check(line.begins_with("You stand and revise case #%d in light of something new: " % case_n) and line.ends_with("."),
		"a revision with new evidence is narrated, naming the new card (got %s)" % line)
	check(GamePresentation._revision_narration(g, g.board[case_n - 1]) == "", "a first filing isn't narrated as a revision")

	# The command, the narration, and the board's mark.
	g.command("withdraw %d" % case_n)
	var refused: String = _text(g, "error")
	check(refused.contains("replaced by case #%d. Take that one back instead." % rev_n), "a replaced case points to its revision (got %s)" % refused)
	g.command("withdraw %d" % rev_n)
	check(_text(g, "narration") == "You stand and take back case #%d." % rev_n, "taking a case back is narrated, with no claimed cost (got %s)" % _text(g, "narration"))
	check(g.board[rev_n - 1].get("withdrawn", false), "the case is marked withdrawn")
	check(CardList.line_for(g.board[rev_n - 1]).contains("withdrawn on day 2"), "the card list says when (got %s)" % CardList.line_for(g.board[rev_n - 1]))
	g.command("withdraw %d" % rev_n)
	check(_text(g, "error") == "You've already taken back case #%d." % rev_n, "twice is refused in plain words (got %s)" % _text(g, "error"))
	g.command("withdraw 999")
	check(_text(g, "error") == "There's no case #999.", "a missing case is named (got %s)" % _text(g, "error"))
	g.command("withdraw %d" % dowse)
	check(_text(g, "error") == "Only a case you've filed can be taken back.", "evidence can't be taken back (got %s)" % _text(g, "error"))
	print("Withdraw UI: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _text(g, kind: String) -> String:
	for e in g.last_events:
		if str(e.get("k", "")) == kind:
			return str(e.get("text", ""))
	return ""

func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	var number: int = g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 0, "data": data, "text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})
	_texts[number] = g.board[number - 1].text
	return number

func _file(g, target: String, support: Array, previous: int = 0) -> int:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, "evil", Vector2(400, 40))
	for number in support:
		for id in model.nodes:
			var nd = model.nodes[id]
			if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, "")):
				model.connect_cards(id, premise)
	var n: int = Live.file(g, model.compile(premise), previous)
	if n <= 0:
		print("FILE FAILED: %s" % g.last_error)
	return n
