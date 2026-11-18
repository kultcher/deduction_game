## Believable public revisions (BACKLOG, Michael, Nov 18, option c): withdrawing a case in
## public, and what a withdrawal or a revision does to the player's track record.
##   godot --headless --path . --script res://tools/test_public_revisions.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Credibility = preload("res://game/credibility.gd")
const GamePresentation = preload("res://game/game_presentation.gd")

var checks = 0
var fails = 0
var _texts: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	_public_withdrawal()
	_revisions()
	_new_evidence_rule()
	print("Public revisions: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.detailed_logging = false
	g.new_case(692, 7)
	g.w.day = 2
	return g

func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	var number: int = g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 0, "data": data, "text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})
	_texts[number] = g.board[number - 1].text
	return number

func _file(g, type: String, target: String, support: Array, previous: int = 0) -> int:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, type, Vector2(400, 40))
	for number in support:
		for id in model.nodes:
			var nd = model.nodes[id]
			if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, "")):
				model.connect_cards(id, premise)
	var n: int = Live.file(g, model.compile(premise), previous)
	if n <= 0:
		print("FILE FAILED: %s" % g.last_error)
	return n

func _present(g, listeners: Array, number: int) -> void:
	for n in listeners:
		g._evaluate_deduction(n, g.board[number - 1], 1.0, false)

func _public_withdrawal() -> void:
	var g = _game()
	var goods: Array = g.w.living_good()
	var reader = goods[0]
	var accused = goods[1]
	var listeners: Array = g.w.living().filter(func(p): return p != reader and p != accused)
	var dowse: int = _read(g, reader, "dowser", 1, {"group": [accused.id], "count": 1})
	var case_n: int = _file(g, "evil", accused.id, [dowse])
	check(case_n > 0, "a case can be filed")
	if case_n <= 0:
		return
	_present(g, listeners, case_n)
	var l = listeners[0]
	check(int(l.claim_record.get(accused.id, {}).get("case", 0)) == case_n, "the track record notes which case argued the claim")
	check(not g.on_deck_case(accused.id).is_empty(), "before: the case is on deck against %s" % accused.name)
	var err: String = g.workshop_withdraw_public(case_n)
	check(err == "", "the case can be taken back in public (%s)" % err)
	check(g.board[case_n - 1].get("withdrawn", false) and not g.board[case_n - 1].get("deleted", false), "the board keeps the case, marked withdrawn")
	var all_out: bool = true
	for n in listeners:
		var mind = n.shadow if n.is_evil() and n.shadow != null else n
		if mind.workshop_state.get("presentations", {}).has(str(case_n)) or float(mind.ledger.get("arg:workshop:%d" % case_n, {}).get("weight", 0.0)) > 0.0:
			all_out = false
	check(all_out, "everyone who heard it drops the argument")
	check(l.claim_record.get(accused.id, {}).get("withdrawn", false), "its claim waits in the track record for the next dawn")
	check(g.on_deck_case(accused.id).is_empty() and g.cases_naming(accused.id).is_empty(), "a withdrawn case is no longer on deck or offered for a nomination")
	check(g._presentation_rejection(g.board[case_n - 1]) != "", "and can't be presented again")
	check(g.workshop_withdraw_public(case_n) != "", "taking it back twice is refused")
	Credibility.dawn(g)
	var cleared: bool = true
	for n in g.w.npcs:
		if n.claim_record.has(accused.id) and int(n.claim_record[accused.id].get("case", 0)) == case_n:
			cleared = false
	check(cleared, "after one dawn's check, the withdrawn claim leaves every track record")
	# A claim restated by a later argument before dawn stands.
	var g2 = _game()
	var goods2: Array = g2.w.living_good()
	var r2 = goods2[0]
	var a2 = goods2[1]
	var ls2: Array = g2.w.living().filter(func(p): return p != r2 and p != a2)
	var d2: int = _read(g2, r2, "dowser", 1, {"group": [a2.id], "count": 1})
	var c2: int = _file(g2, "evil", a2.id, [d2])
	if c2 > 0:
		_present(g2, ls2, c2)
		g2.workshop_withdraw_public(c2)
		Credibility.record(ls2[0], "evil", a2.id, g2.w.day)
		Credibility.dawn(g2)
		check(ls2[0].claim_record.has(a2.id), "a claim restated after the withdrawal (a nomination) stays in the record")

func _revisions() -> void:
	var g = _game()
	var goods: Array = g.w.living_good()
	var reader = goods[0]
	var b = goods[1]
	var c = goods[2]
	var listeners: Array = g.w.living().filter(func(p): return p != reader and p != b and p != c)
	var d1: int = _read(g, reader, "dowser", 1, {"group": [b.id], "count": 1})
	var d2: int = _read(g, reader, "dowser", 2, {"group": [c.id], "count": 1})
	# A revision with nothing new: the old claim waits for the dawn.
	var first: int = _file(g, "evil", b.id, [d1])
	if first <= 0:
		check(false, "the first case can be filed")
		return
	_present(g, listeners, first)
	var same: int = _file(g, "evil", c.id, [d1], first)
	check(same > first and g.board[same - 1].get("revises", 0) == first, "a revision is filed against the first case")
	_present(g, listeners, same)
	var l = listeners[0]
	check(l.claim_record.get(b.id, {}).get("withdrawn", false), "a revision citing nothing new: the old claim is judged once more at dawn")
	check(int(l.claim_record.get(c.id, {}).get("case", 0)) == same, "and the revision's own claim is recorded")
	# A revision backed by new evidence: the old claim leaves at once.
	var g2 = _game()
	var goods2: Array = g2.w.living_good()
	var r2 = goods2[0]
	var b2 = goods2[1]
	var c2 = goods2[2]
	var ls2: Array = g2.w.living().filter(func(p): return p != r2 and p != b2 and p != c2)
	var e1: int = _read(g2, r2, "dowser", 1, {"group": [b2.id], "count": 1})
	var e2: int = _read(g2, r2, "dowser", 2, {"group": [c2.id], "count": 1})
	var f2: int = _file(g2, "evil", b2.id, [e1])
	if f2 <= 0:
		check(false, "the second game's case can be filed")
		return
	_present(g2, ls2, f2)
	var rev: int = _file(g2, "evil", c2.id, [e2], f2)
	_present(g2, ls2, rev)
	check(not ls2[0].claim_record.has(b2.id), "a revision citing new evidence: the old claim leaves the record at once")
	check(int(ls2[0].claim_record.get(c2.id, {}).get("case", 0)) == rev, "and the revision's claim stands")
	# A listener who never heard the revision keeps the old version.
	var g3 = _game()
	var goods3: Array = g3.w.living_good()
	var ls3: Array = g3.w.living().filter(func(p): return p != goods3[0] and p != goods3[1] and p != goods3[2])
	var h1: int = _read(g3, goods3[0], "dowser", 1, {"group": [goods3[1].id], "count": 1})
	var h2: int = _read(g3, goods3[0], "dowser", 2, {"group": [goods3[2].id], "count": 1})
	var f3: int = _file(g3, "evil", goods3[1].id, [h1])
	if f3 > 0:
		_present(g3, ls3, f3)
		var rev3: int = _file(g3, "evil", goods3[2].id, [h2], f3)
		_present(g3, ls3.slice(0, ls3.size() - 1), rev3)
		check(int(ls3[-1].claim_record.get(goods3[1].id, {}).get("case", 0)) == f3 and not ls3[-1].claim_record[goods3[1].id].get("withdrawn", false), "someone who hasn't heard the revision keeps the old claim as it was")

func _new_evidence_rule() -> void:
	check(GamePresentation.new_evidence({"supports": [3]}, {"supports": [3, 5]}), "citing a new original card is new evidence")
	check(not GamePresentation.new_evidence({"supports": [3, 5]}, {"supports": [5]}), "dropping a card is not")
	check(not GamePresentation.new_evidence({"supports": [3]}, {"supports": [3, -10001]}), "nor is adding only a premise")
