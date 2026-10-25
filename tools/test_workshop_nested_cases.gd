## A filed canvas can support another question without promoting its label to fact.
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(692, 7)
	for n in g.w.npcs:
		n.info_log = []
		n.known_claims = {}
		n.ledger = {}
		n.beliefs = []
		n.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	var listener = g.w.living_good()[0]
	var source = g.w.npcs.filter(func(n): return n != listener)[0]
	var target = g.w.npcs.filter(func(n): return n != listener and n != source)[0]
	var read = g.add_card({"kind": "info", "source": source.id, "role": "surveyor", "day": 0,
		"data": {"count": 2}, "text": "Surveyor reports two blocks"})
	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": target.id, "at": "Original alignment"}
	var intermediate: String = board.add_premise(source.id, "good", Vector2.ZERO)
	var fact: String = Live.Evidence.normalize_card(g.board[read - 1]).id
	board.nodes["e:" + fact].answers = {fact: {"positive": [], "blocks": [target.home_block]}}
	board.connect_cards("e:" + fact, intermediate)
	board.connect_cards(intermediate, root)
	var child = Live.file(g, board.compile(root))
	check(child > 0, "a canvas with an intermediate claim files normally")
	var parent = g.file_deduction({"type": "good", "a": target.id}, [child])
	var input = g.workshop_snapshot([parent], listener.id)
	var prepared = Live.Assess.prepare(input)
	check(prepared.ready, "a canvas cited by a native parent has a complete shared adapter: " + str(prepared.issues))
	if prepared.ready:
		check(prepared.case.cards == [fact], "the parent cites the original receipt exactly once")
		check(Solver.Graph.compile_case(prepared.view, prepared.case).answers.get(fact, {}).get("blocks", []) == [target.home_block], "a child case retains its supplied Surveyor hypothesis")
		check(prepared.case.arguments.any(func(a): return a.id.begins_with("canvas:") and a.case.conclusion.target == source.id), "nested intermediate questions retain their scoped evidence")
		check(prepared.case.arguments.all(func(a): return a.parents.all(func(id): return prepared.case.arguments.any(func(p): return p.id == id))), "namespaced links point to actual parent questions")
		var flat = Solver.empty_case()
		flat.cards = [fact]
		flat.conclusion = prepared.case.conclusion.duplicate(true)
		check(CaseEval.evaluate(prepared.view, flat, prepared.listener).people == CaseEval.evaluate(prepared.view, prepared.case, prepared.listener).people, "a child's conclusion creates no extra alignment evidence")
		var twice = g.file_deduction({"type": "good", "a": target.id}, [parent, child, read])
		var repeated = Live.Assess.prepare(g.workshop_snapshot([twice], listener.id))
		check(repeated.ready and repeated.case.cards == [fact], "diamond-shaped citations retain one original fact: " + str(repeated.issues) + " / " + str(repeated.case.get("cards", [])))
		check(repeated.case.arguments.map(func(a): return a.id).size() == _unique(repeated.case.arguments.map(func(a): return a.id)).size(), "shared descendants do not duplicate question identities")
		g.set_workshop_effects(true)
		var response = g._evaluate_deduction(listener, g.board[parent - 1], 1.0, false)
		check(response.get("workshop", false) and listener.workshop_state.active and fact in listener.workshop_state.facts, "actual nested presentations use shared ownership")
	# Stored graph roots are checked against the child's real board supports, not
	# against the superset of receipts selected by its parent.
	var corrupt = input.duplicate(true)
	var stored: Dictionary = corrupt.arguments.filter(func(a): return a.board_number == child)[0].workshop_case
	stored.cards = []
	check(not Live.Assess.prepare(corrupt).ready, "a child graph cannot silently omit one of its original receipts")
	_challenges(g, listener, target, fact)
	_claims(g, listener, source)
	print("Nested cases: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _challenges(g, listener, target, fact: String) -> void:
	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": target.id, "at": "Original alignment"}
	board.add_modifier("e:" + fact, "unlikely")
	board.connect_cards(board.selected, root)
	var child = Live.file(g, board.compile(root))
	var parent = g.file_deduction({"type": "evil", "a": target.id}, [child])
	var input = g.workshop_snapshot([parent], listener.id)
	var prepared = Live.Assess.prepare(input)
	check(prepared.ready and prepared.case.reading_challenges.get(fact, {}).get("mode", "") == "unlikely", "nested reading challenges retain their exact source and scope")
	var corrupt = input.duplicate(true)
	corrupt.arguments.filter(func(a): return a.board_number == child)[0].workshop_case.reading_challenges[fact].mode = "invented"
	check(not Live.Assess.prepare(corrupt).ready, "an invalid child challenge cannot hide behind a supported parent")
	var home = g.add_card({"kind": "alibi", "source": target.id, "subject": [target.id], "day": 1, "phase": 3, "block": target.home_block, "text": "Home"})
	var out = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id], "day": 1, "phase": 3, "block": "market", "text": "Out"})
	board = Canvas.new(Live.view(g))
	root = board.selected
	board.nodes[root].conclusion = {"type": "suspicious", "target": target.id, "at": "Original alignment"}
	var home_id: String = Live.Evidence.normalize_card(g.board[home - 1]).id
	board.connect_cards("e:" + home_id, "e:" + Live.Evidence.normalize_card(g.board[out - 1]).id)
	board.connect_cards(board.selected, root)
	child = Live.file(g, board.compile(root))
	parent = g.file_deduction({"type": "suspicious", "a": target.id}, [child])
	prepared = Live.Assess.prepare(g.workshop_snapshot([parent], listener.id))
	check(prepared.ready and prepared.case.disputes.size() == 1, "nested home-alibi disputes retain their linked observation")
	if prepared.ready:
		var selected = Solver.selected(prepared.view, Solver.Graph.compile_case(prepared.view, prepared.case))
		check(selected.any(func(c): return c.id == home_id and c.get("quoted", false)), "the child alibi stays quoted rather than endorsed alongside its contradiction")

func _claims(g, listener, source) -> void:
	var number = g.add_card({"kind": "claim", "source": source.id, "subject": [source.id], "role": "gravedigger", "text": "I am the Gravedigger"})
	var value = Solver.empty_case()
	value.cards = [Live.Evidence.normalize_card(g.board[number - 1]).id]
	value.conclusion = {"type": "good", "target": source.id, "at": "Original alignment"}
	var prepared = Live.Assess.prepare(Live.snapshot(g, value, listener.id))
	check(prepared.ready, "a Gravedigger role claim does not require a reading's execution payload: " + str(prepared.issues))

func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value not in result:
			result.append(value)
	return result

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
