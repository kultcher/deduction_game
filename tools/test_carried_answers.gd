## A case filed with an answer picked for an earlier case names it (playtest 23973: a Dowser
## answer picked for case #38 rode along into case #78, and was easy to miss).
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Editor = preload("res://ui/live_case_workshop.gd")
var checks = 0
var fails = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var source = g.w.npcs[0]
	var others: Array = g.w.npcs.filter(func(n): return n != source)
	var a = others[0]
	var b = others[1]
	var c = others[2]
	var read = g.add_card({"kind": "info", "source": source.id, "subject": [a.id, b.id, c.id], "role": "dowser",
		"day": 1, "phase": 0, "data": {"group": [a.id, b.id, c.id], "count": 1}, "text": "Dowser read: one registration."})
	var view = Live.view(g)
	var board = Canvas.new(view)
	var report_id: String = Live.Evidence.normalize_card(g.board[read - 1]).id
	var root: String = board.selected
	board.nodes[root].conclusion.target = a.id
	board.connect_cards("e:" + report_id, root)
	board.nodes["e:" + report_id].answers[report_id] = {"positive": [b.id], "slots": [b.id]}
	var first: Dictionary = board.compile(root)
	var filed: Dictionary = {}

	# The first case carries nothing; record it as filed.
	check(board.carried_answers(first.answers, filed, 38).is_empty(), "the first filing carries no earlier answers")
	filed["38"] = first.answers.duplicate(true)
	# Refiling the same case doesn't count as carrying from itself.
	check(board.carried_answers(first.answers, filed, 38).is_empty(), "updating a case doesn't report its own answers as carried")

	# A second case on the same card keeps the answer: it's carried from #38.
	var second_root: String = board.add_premise(c.id, "evil", Vector2(400, 300))
	board.connect_cards("e:" + report_id, second_root)
	var second: Dictionary = board.compile(second_root)
	var carried: Array = board.carried_answers(second.answers, filed, 78)
	check(carried.size() == 1 and carried[0].card == report_id and carried[0].from == 38, "a second case on the card carries the answer from case #38")
	var text: String = board.carried_answer_text(carried[0])
	check(text == "%s's Dowser reading (%s)" % [source.name, b.name], "the carried answer reads as the source's reading and the person picked (got %s)" % text)

	# A changed answer is the player's new choice, not a carried one.
	board.nodes["e:" + report_id].answers[report_id] = {"positive": [c.id], "slots": [c.id]}
	check(board.carried_answers(board.compile(second_root).answers, filed, 78).is_empty(), "a changed answer isn't reported as carried")
	# A cleared answer carries nothing.
	board.nodes["e:" + report_id].answers.erase(report_id)
	check(board.carried_answers(board.compile(second_root).answers, filed, 78).is_empty(), "a cleared answer carries nothing")

	# The earliest earlier case is named when several share the answer.
	filed["12"] = first.answers.duplicate(true)
	check(board.carried_answers(first.answers, filed, 78)[0].from == 12, "the earliest earlier case is named")

	# The filing note (draft wording) names the card, the person picked and the case.
	var editor = Editor.new()
	editor.board = board
	var note: String = editor.carried_note(carried)
	check(note == "This case keeps your earlier answer: %s's Dowser reading (%s), picked for case #38. Clear it on the card if this case shouldn't use it." % [source.name, b.name], "the filing note names the carried answer (got %s)" % note)
	check(editor.carried_note([carried[0], carried[0]]).begins_with("This case keeps your earlier answers: ") and editor.carried_note([carried[0], carried[0]]).ends_with("Clear them on the card if this case shouldn't use them."), "two carried answers read in the plural")
	editor.free()

	print("Carried answers: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)
