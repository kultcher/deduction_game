## Premises pass step 3 (docs/premises_plan.md): graded reading challenges. A challenge
## lands as far as the rest of the evidence, against chance, says the reading is wrong; a
## neutral one does nothing; one the evidence contradicts backfires and costs trust; the
## cause decides the blame (a lie raises the reader, a failed gift points at whoever was
## out that night); and "these readings from one person don't fit together" works the same
## way on the group.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_neutral_and_strong()
	_backfire()
	_impaired()
	_inconsistent()
	_script_without_poisoner()
	_content_only()
	print("Premises step 3: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.credibility = 0.7
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = 0.5
	n.traits.confidence = 0.5
	n.workshop_state["reasoning_mode"] = "full"
	g.w.day = 2
	return g

func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	return g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if role == "seer" else 0, "data": data, "text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})

func _node(model, view, number: int) -> String:
	var card_id: String = ""
	for c in view.cards:
		if c.get("number", -1) == number or c.get("n", -1) == number:
			card_id = c.id
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and (nd.card == card_id or Solver.card_by_id(view, nd.card).get("text", "") == _text_of(view, number)):
			return id
	return ""

var _texts: Dictionary = {}
func _text_of(_view, number: int) -> String:
	return str(_texts.get(number, ""))

func _remember(g, number: int) -> int:
	_texts[number] = g.board[number - 1].text
	return number

## Build and present a case: premise (type, target) with `support` cards linked to it and,
## optionally, a challenge (mode) on `challenged` grounded by `grounds`. Returns the
## presentation result and the listener.
func _present(g, type: String, target: String, support: Array, challenged: int = 0, mode: String = "", grounds: Array = [], extra: Dictionary = {}) -> Dictionary:
	var n = g.w.npcs[0]
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, type, Vector2(400, 40))
	for k in extra:
		model.nodes[premise].conclusion[k] = extra[k]
	for number in support:
		model.connect_cards(_node(model, view, number), premise)
	if challenged > 0:
		var report_node: String = _node(model, view, challenged)
		check(model.add_modifier(report_node, mode) == "", "the %s challenge attaches" % mode)
		var challenge: String = model.selected
		for number in grounds:
			model.connect_cards(_node(model, view, number), challenge)
		model.connect_cards(challenge, premise)
	var value: Dictionary = model.compile(premise)
	var filed: int = Live.file(g, value)
	check(filed > 0, "the %s case files (%s)" % [type, g.last_error])
	var trust0: float = n.trust
	var r = g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
	return {"r": r, "n": n, "trust": n.trust - trust0, "results": r.get("assessment", {}).get("reading_challenges", [])}

func _result_for(results: Array, mode: String) -> Dictionary:
	for res in results:
		if res.get("mode", "") == mode:
			return res
	return {}

func _neutral_and_strong() -> void:
	# Neutral: a lie alleged against a Seer reading with nothing else in the case.
	var g = _game()
	var p: Array = g.w.npcs
	var seer = _remember(g, _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true}))
	var neutral: Dictionary = _present(g, "evil", p[2].id, [seer], seer, "lying")
	var nr: Dictionary = _result_for(neutral.results, "lying")
	print("neutral: ", nr.get("graded", {}))
	check(not nr.is_empty() and float(nr.get("graded", {}).get("effect", 1.0)) < 0.05 and float(nr.multiplier) > 0.95 and not nr.backfire, "a challenge with nothing behind it changes nothing")
	check(is_equal_approx(neutral.trust, 0.0), "and costs nothing")
	# Strong: two Dowsers clear both people the Seer named. Not impossible (a Red Herring
	# can still ping), but the rest of the evidence argues against the reading.
	var g2 = _game()
	var q: Array = g2.w.npcs
	var seer2 = _remember(g2, _read(g2, q[2], "seer", 1, {"pair": [q[3].id, q[4].id], "yes": true}))
	var d1 = _remember(g2, _read(g2, q[5], "dowser", 1, {"group": [q[3].id], "count": 0}))
	var d2 = _remember(g2, _read(g2, q[6], "dowser", 1, {"group": [q[4].id], "count": 0}))
	var base: Dictionary = _present(g2, "evil", q[2].id, [seer2, d1, d2])
	var before_susp: float = base.n.suspicion[q[2].id]
	var g3 = _game()
	var t: Array = g3.w.npcs
	var seer3 = _remember(g3, _read(g3, t[2], "seer", 1, {"pair": [t[3].id, t[4].id], "yes": true}))
	var d3 = _remember(g3, _read(g3, t[5], "dowser", 1, {"group": [t[3].id], "count": 0}))
	var d4 = _remember(g3, _read(g3, t[6], "dowser", 1, {"group": [t[4].id], "count": 0}))
	var strong: Dictionary = _present(g3, "evil", t[2].id, [seer3, d3, d4], seer3, "lying", [d3, d4])
	var sr: Dictionary = _result_for(strong.results, "lying")
	var gr: Dictionary = sr.get("graded", {})
	print("strong: ", gr, " multiplier ", sr.get("multiplier"), " agreement ", sr.get("agreement"), "; reader suspicion without %.3f, with %.3f" % [before_susp, strong.n.suspicion[t[2].id]])
	check(float(gr.get("effect", 0.0)) > 0.2 and float(sr.multiplier) < 0.9, "two clears of the Seer's pair make a lying challenge land, though nothing is impossible")
	check(float(gr.get("wrong", 0.0)) > float(gr.get("wrong_prior", 1.0)), "the chance the reading is wrong rises above its prior")
	check(strong.n.suspicion[t[2].id] >= before_susp, "and the reader is no less suspected than without the challenge")

func _backfire() -> void:
	# The Seer named two people; a Dowser says one of them is evil. Calling the Seer a liar
	# argues against what the rest of the evidence backs up.
	var g = _game()
	var p: Array = g.w.npcs
	var seer = _remember(g, _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true}))
	var dowse = _remember(g, _read(g, p[5], "dowser", 1, {"group": [p[3].id, p[4].id], "count": 2}))
	var res: Dictionary = _present(g, "evil", p[3].id, [seer, dowse], seer, "lying", [dowse])
	var br: Dictionary = _result_for(res.results, "lying")
	var g0 = _game()
	var p0: Array = g0.w.npcs
	var seer0 = _remember(g0, _read(g0, p0[2], "seer", 1, {"pair": [p0[3].id, p0[4].id], "yes": true}))
	var dowse0 = _remember(g0, _read(g0, p0[5], "dowser", 1, {"group": [p0[3].id, p0[4].id], "count": 2}))
	var plain: Dictionary = _present(g0, "evil", p0[3].id, [seer0, dowse0])
	print("backfire: ", br.get("graded", {}), " trust %+.3f (without the challenge %+.3f)" % [res.trust, plain.trust])
	check(br.get("backfire", false), "a challenge the rest of the evidence contradicts backfires")
	check(is_equal_approx(res.trust, plain.trust - Tuning.Trust.PRESENTATION_WRONG_COST), "and costs the presenter trust, on top of how the case itself went")

func _impaired() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer = _remember(g, _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true}))
	var d1 = _remember(g, _read(g, p[5], "dowser", 1, {"group": [p[3].id], "count": 0}))
	var d2 = _remember(g, _read(g, p[6], "dowser", 1, {"group": [p[4].id], "count": 0}))
	var seen = _remember(g, g.add_card({"kind": "sighting", "subject": [p[1].id], "day": 1, "phase": 3, "source": p[6].id, "block": p[1].home_block,
		"text": "%s saw %s out on night 1." % [p[6].name, p[1].name]}))
	var res: Dictionary = _present(g, "evil", p[1].id, [seer, d1, d2, seen], seer, "impaired", [d1, d2])
	var ir: Dictionary = _result_for(res.results, "impaired")
	var roles: Array = g.w.case_script.minions if g.w.case_script != null else []
	print("impaired: script minions %s, candidates %s, graded %s" % [roles, ir.get("candidates", {}), ir.get("graded", {})])
	check(not ir.is_empty(), "a failed-gift challenge is assessed")
	var possible: bool = Challenges.poisoner_possible({"script_minions": g.w.case_script.minions if g.w.case_script != null else []})
	if possible:
		check(ir.get("candidates", {}).has(p[1].id), "someone seen out that night with no reason is a Poisoner candidate")
		check(not ir.get("candidates", {}).has(p[3].id), "nobody without such a sighting is")
	check(not Challenges.poisoner_possible({"script_minions": ["scion", "brute"]}), "with no Poisoner in the script, the cause can't hold")
	check(Challenges.poisoner_possible({"script_minions": ["poisoner", "scion"]}), "with one, it can")

func _inconsistent() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var yes = _remember(g, _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true}))
	var no = _remember(g, _read(g, p[2], "seer", 2, {"pair": [p[3].id, p[4].id], "yes": false}))
	var res: Dictionary = _present(g, "inconsistent", p[2].id, [yes, no], 0, "", [], {"cause": "lying"})
	var results: Array = res.results
	var grouped: Array = results.filter(func(r_i): return r_i.get("group", []).size() == 2)
	print("inconsistent: ", grouped.map(func(r_i): return [r_i.mode, r_i.multiplier, r_i.get("graded", {}).get("effect")]))
	check(not grouped.is_empty(), "a source's readings that don't fit together are challenged as a group")
	if not grouped.is_empty():
		check(grouped[0].mode == "lying" and float(grouped[0].multiplier) < 1.0, "a yes and then a no on the same pair: the group lands, with the named cause")

## Review fix (Codex, PR #95): the Poisoner check reads the case script's minions, not the
## solver's possible roles (every ready role, whatever the script).
func _script_without_poisoner() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	g.w.case_script.minions = g.w.case_script.minions.filter(func(r): return r != "poisoner")
	check(not ("poisoner" in Bridge.capture(g, []).rules.get("minions", [])), "the snapshot carries the script's minions")
	check("poisoner" in Bridge.capture(g, []).rules.roles, "while the solver's roles still list every ready role")
	var seer = _remember(g, _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true}))
	var d1 = _remember(g, _read(g, p[5], "dowser", 1, {"group": [p[3].id], "count": 0}))
	var d2 = _remember(g, _read(g, p[6], "dowser", 1, {"group": [p[4].id], "count": 0}))
	var res: Dictionary = _present(g, "evil", p[2].id, [seer, d1, d2], seer, "impaired", [d1, d2])
	var ir: Dictionary = _result_for(res.results, "impaired")
	check(not ir.is_empty() and float(ir.get("graded", {}).get("cause", 1.0)) == 0.0 and float(ir.get("agreement", 1.0)) == 0.0,
		"with no Poisoner on the script, a failed-gift challenge carries no blame (%s)" % ir.get("graded", {}))

## Review fix (Codex, PR #95): "the content holds" is about the content, not the source.
## A Dowser's clear holds wherever its subject is good, even if the Dowser is evil, and
## two readings that can both be true never "don't fit together".
func _content_only() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	_read(g, p[5], "dowser", 1, {"group": [p[3].id], "count": 0})
	_read(g, p[5], "dowser", 2, {"group": [p[4].id], "count": 0})
	var view: Dictionary = Live.view(g)
	var reps: Array = view.cards.filter(func(c): return c.get("kind", "") == "report" and c.get("source", "") == p[5].id and c.get("role", "") == "dowser")
	check(reps.size() == 2, "both readings are on the board")
	if reps.size() != 2:
		return
	var epoch = view.get("alignment_epoch", "")
	var worlds: Array = Solver.universe(view)
	var evil = func(w, id): return Solver.holds(view, w, {"type": "evil", "target": id, "at": epoch})
	var holds: PackedByteArray = CaseEval._premise_mask(view, {"type": "holds", "report": reps[0].id, "target": p[5].id, "at": epoch})
	var odd: PackedByteArray = CaseEval._premise_mask(view, {"type": "inconsistent", "reports": [reps[0].id, reps[1].id], "target": p[5].id, "at": epoch})
	var evil_src_clear: int = 0
	var bad_holds: int = 0
	var bad_odd: int = 0
	for i in range(worlds.size()):
		var w = worlds[i]
		var clear3: bool = not evil.call(w, p[3].id)
		if evil.call(w, p[5].id) and clear3:
			evil_src_clear += 1
		if (holds[i] != 0) != clear3:
			bad_holds += 1
		if (odd[i] != 0) != (evil.call(w, p[3].id) or evil.call(w, p[4].id)):
			bad_odd += 1
	check(evil_src_clear > 0, "some worlds have an evil Dowser and a good subject (%d)" % evil_src_clear)
	check(bad_holds == 0, "the clear holds exactly where its subject is good, whoever the Dowser is (%d worlds off)" % bad_holds)
	check(bad_odd == 0, "two clears only fail to fit where one of them is wrong, not wherever the Dowser is evil (%d worlds off)" % bad_odd)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
