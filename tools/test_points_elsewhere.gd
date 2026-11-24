## The test juror flags an accusation whose evidence points more at someone else (Michael,
## Nov 20): the chip reads "<band> · points elsewhere", by the rule a listener uses to say
## "present_points_elsewhere" (sim/dialogue_presentations.gd points_elsewhere). Here three
## seers each read the subject with one person as evil and with another as not: a case that
## the subject is evil argues against itself, and says the most about the seers.
##   godot --headless --path . --script res://tools/test_points_elsewhere.gd
extends SceneTree

const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const CaseEval = preload("res://workshop/case_eval.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _judge(g, premise_type: String, subject, readings: Array) -> Dictionary:
	var texts: Array = []
	for r in readings:
		var n: int = GameBoard.add_card(g, {"kind": "info", "source": r[3].id, "role": "seer", "day": 1, "phase": 3,
			"data": {"pair": [r[0].id, r[1].id], "yes": r[2]},
			"text": "%s seer day 1: %s and %s %s (%d)" % [r[3].id, r[0].id, r[1].id, "yes" if r[2] else "no", g.board.size()]})
		texts.append(g.board[n - 1].text)
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(subject.id, premise_type, Vector2(400, 40))
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and Solver.card_by_id(view, nd.card).get("text", "") in texts:
			model.connect_cards(id, premise)
	var value: Dictionary = model.compile(premise)
	var r: Dictionary = Live.test_juror(g, value)
	var juror: Dictionary = Live.juror_case(g, value)
	r["rivals"] = CaseEval.evaluate(juror.prepared.view, juror.case).get("rivals", [])
	r["cards"] = value.get("cards", []).size()
	return r


func _fresh() -> Object:
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 10)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
	g.w.day = 2
	return g


func _init() -> void:
	var g = _fresh()
	var p: Array = g.w.npcs
	var s = p[3]
	var seers: Array = [p[2], p[7], p[8]]
	var misframed: Array = [[s, p[4], true, seers[0]], [s, p[5], false, seers[0]], [s, p[4], true, seers[1]],
		[s, p[6], false, seers[1]], [s, p[4], true, seers[2]], [s, p[0], false, seers[2]]]
	var r: Dictionary = _judge(g, "evil", s, misframed)
	check(r.get("ready", false) and r.cards == misframed.size(), "(fixture) the juror weighs all six readings (%s)" % str(r.get("issues", [])))
	check(r.get("category", "") in Live.POINTS_ELSEWHERE_BANDS, "the case doesn't carry the accusation (%s)" % r.get("category", ""))
	var top: Dictionary = r.rivals[0] if not r.rivals.is_empty() else {}
	check(float(top.get("shift", 0.0)) > 0.2 and float(top.get("posterior", 0.0)) > 0.5, "it raises someone else past a half (%s)" % str(top))
	check(r.get("points_elsewhere", false), "so the juror flags it: points elsewhere")

	# The same readings behind "is good" clear the subject: no flag on a clearing premise.
	var g2 = _fresh()
	p = g2.w.npcs
	var cleared: Dictionary = _judge(g2, "good", p[3], [[p[3], p[4], true, p[2]], [p[3], p[5], false, p[2]], [p[3], p[4], true, p[7]],
		[p[3], p[6], false, p[7]], [p[3], p[4], true, p[8]], [p[3], p[0], false, p[8]]])
	check(cleared.get("ready", false) and not cleared.get("points_elsewhere", false), "a clearing premise is never flagged (%s)" % cleared.get("category", ""))

	# One seer's reading alone leaves nobody else above a half: no flag.
	var g3 = _fresh()
	p = g3.w.npcs
	var plain: Dictionary = _judge(g3, "evil", p[3], [[p[3], p[4], true, p[2]]])
	check(plain.get("ready", false) and not plain.get("points_elsewhere", false), "a single pairing reading isn't flagged (%s)" % plain.get("category", ""))

	# Case #21798 regression: evidence that moderately supports the target in full-weight shape
	# (`CaseEval`), dampened to weak/negligible for an average listener, must not be flagged as
	# "points elsewhere" even when a rival also clears the full-weight rival bar.
	var g4 = _fresh()
	p = g4.w.npcs
	var s4 = p[3]
	var rival4 = p[4]
	var t1: int = GameBoard.add_card(g4, {"kind": "info", "source": p[2].id, "role": "archivist", "day": 0, "phase": 3,
		"data": {"pair": [s4.id, p[9].id], "role": "poisoner"},
		"text": "%s archivist night 0: one of %s and %s is the poisoner" % [p[2].id, s4.id, p[9].id]})
	var t2: int = GameBoard.add_card(g4, {"kind": "info", "source": p[7].id, "role": "dowser", "day": 1, "phase": 0,
		"data": {"block": "docks", "count": 1, "group": [rival4.id, p[5].id]},
		"text": "%s dowser day 1: 1 evil among %s and %s" % [p[7].id, rival4.id, p[5].id]})
	var t3: int = GameBoard.add_card(g4, {"kind": "info", "source": p[7].id, "role": "dowser", "day": 2, "phase": 0,
		"data": {"block": "square", "count": 1, "group": [s4.id, p[6].id, p[5].id]},
		"text": "%s dowser day 2 morning: 1 evil among %s, %s, %s" % [p[7].id, s4.id, p[6].id, p[5].id]})
	var t4: int = GameBoard.add_card(g4, {"kind": "info", "source": p[7].id, "role": "dowser", "day": 2, "phase": 1,
		"data": {"block": "hill", "count": 1, "group": [rival4.id, p[8].id]},
		"text": "%s dowser day 2 afternoon: 1 evil among %s and %s" % [p[7].id, rival4.id, p[8].id]})
	var texts4: Array = [g4.board[t1 - 1].text, g4.board[t2 - 1].text, g4.board[t3 - 1].text, g4.board[t4 - 1].text]
	var view4: Dictionary = Live.view(g4)
	var model4 = CanvasModel.new(view4)
	model4.contradiction_links = true
	model4.marked_answers = false
	var prem4: String = model4.add_premise(s4.id, "evil", Vector2(400, 40))
	for id in model4.nodes:
		var nd = model4.nodes[id]
		if nd.kind == "evidence" and Solver.card_by_id(view4, nd.card).get("text", "") in texts4:
			model4.connect_cards(id, prem4)
	var val4: Dictionary = model4.compile(prem4)
	var r4: Dictionary = Live.test_juror(g4, val4)
	var j4: Dictionary = Live.juror_case(g4, val4)
	var ev4: Dictionary = CaseEval.evaluate(j4.prepared.view, j4.case)
	var top4: Dictionary = ev4.rivals[0] if not ev4.get("rivals", []).is_empty() else {}
	check(r4.get("ready", false) and r4.get("category", "") in Live.POINTS_ELSEWHERE_BANDS and not (str(ev4.get("category", "")) in Live.POINTS_ELSEWHERE_BANDS),
		"(fixture) heard band is dampened (%s) while full-weight shape supports target (%s)" % [r4.get("category", ""), ev4.get("category", "")])
	check(float(top4.get("shift", 0.0)) > 0.2 and float(top4.get("posterior", 0.0)) > 0.5,
		"(fixture) a rival still clears the full-weight bar (%s)" % str(top4))
	check(not r4.get("points_elsewhere", false), "a case whose shape supports its target is not flagged points elsewhere")
	print("Points elsewhere: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
