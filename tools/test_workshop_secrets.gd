## A confessed private errand is a dated alternative, not an innocence guarantee.
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Editor = preload("res://ui/live_case_workshop.gd")
var checks = 0
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(692, 7)
	g.w.day = 2
	for real in g.w.npcs:
		for n in [real, real.shadow]:
			if n == null:
				continue
			n.info_log = []
			n.known_claims = {}
			n.ledger = {}
			n.beliefs = []
			n.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	var listener = g.w.living_good()[0]
	var target = g.w.npcs.filter(func(n): return n != listener)[0]
	var teller = g.w.npcs.filter(func(n): return n != target and n != listener)[0]
	var out = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id], "day": 1, "phase": 3, "block": "market", "text": "Seen out on night 1"})
	var confession = {"kind": "secret", "source": target.id, "subject": [target.id], "owner": target.id,
		"secret_kind": "debt", "day": 1, "phase": 3, "block": "market", "text": "A confessed private errand"}
	var number = g.add_card(confession)
	var out_id: String = Live.Evidence.normalize_card(g.board[out - 1]).id
	var secret_id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	var value = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": target.id, "at": "Original alignment"}
	value.cards = [out_id]
	var plain = Live.Assess.prepare(Live.snapshot(g, value, listener.id))
	var prior = CaseEval.evaluate(plain.view, plain.case, plain.listener)
	value.cards.append(secret_id)
	value.reasons[target.id + ":1"] = "secret"
	value.citations[target.id + ":1"] = secret_id
	var prepared = Live.Assess.prepare(Live.snapshot(g, value, listener.id))
	check(prepared.ready, "a dated secret can explain the matching person's outing: " + str(prepared.issues))
	var result = CaseEval.evaluate(prepared.view, prepared.case, prepared.listener)
	check(result.people[target.id].posterior < prior.people[target.id].posterior, "a private errand makes the same outing less incriminating")
	check(result.people[target.id].posterior > 0 and result.people[target.id].posterior < 1, "a confession does not establish innocence or guilt")
	var alone = value.duplicate(true)
	alone.cards = [secret_id]
	alone.citations = {}
	var context = Live.Assess.prepare(Live.snapshot(g, alone, listener.id))
	var neutral = CaseEval.evaluate(context.view, context.case, context.listener)
	check(neutral.people.values().all(func(p): return is_equal_approx(p.prior, p.posterior)), "a secret alone adds no alignment evidence")
	check(Activity.routes(context.view, context.view.cards).nights.is_empty(), "confessing an explanation does not assert a night outing")
	await _ui(g, out, number, target.id)
	var repeated = confession.duplicate(true)
	repeated.source = teller.id
	repeated.text = "Another teller repeats the same private explanation"
	var second = g.add_card(repeated)
	var duplicate = value.duplicate(true)
	duplicate.cards.append(Live.Evidence.normalize_card(g.board[second - 1]).id)
	var dupe = Live.Assess.prepare(Live.snapshot(g, duplicate, listener.id))
	check(CaseEval.evaluate(dupe.view, dupe.case, dupe.listener).people == result.people, "retellings do not create independent private-errand awards")
	var lover = confession.duplicate(true)
	lover.secret_kind = "lover"
	lover["mod"] = "lovers"
	var lover_number = g.add_card(lover)
	var lover_case = value.duplicate(true)
	lover_case.cards = [out_id, Live.Evidence.normalize_card(g.board[lover_number - 1]).id]
	lover_case.citations = {}
	var lover_context = Live.Assess.prepare(Live.snapshot(g, lover_case, listener.id))
	check(CaseEval.evaluate(lover_context.view, lover_context.case, lover_context.listener).people == result.people, "a claimed lover story supplies an errand alternative without asserting the Lovers modifier")
	var new_out = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id], "day": 2, "phase": 3, "block": "market", "text": "Seen out on night 2"})
	var later = value.duplicate(true)
	later.cards = [Live.Evidence.normalize_card(g.board[new_out - 1]).id]
	later.citations = {}
	later.reasons = {}
	var later_plain = Live.Assess.prepare(Live.snapshot(g, later, listener.id))
	var later_effect = CaseEval.evaluate(later_plain.view, later_plain.case, later_plain.listener)
	later.cards.append(secret_id)
	var later_context = Live.Assess.prepare(Live.snapshot(g, later, listener.id))
	check(CaseEval.evaluate(later_context.view, later_context.case, later_context.listener).people == later_effect.people, "a night-1 confession cannot change night-2 activity likelihoods")
	var wrong = value.duplicate(true)
	wrong.citations = {target.id + ":2": secret_id}
	check(not Live.Assess.prepare(Live.snapshot(g, wrong, listener.id)).ready, "an inapplicable night citation is rejected explicitly")
	wrong.citations = {teller.id + ":1": secret_id}
	check(not Live.Assess.prepare(Live.snapshot(g, wrong, listener.id)).ready, "another person's secret cannot explain this person's outing")
	var raw = g.workshop_snapshot([out], listener.id)
	for edit in [{"owner": teller.id}, {"secret_kind": "invented"}, {"block": "unknown"}]:
		var invalid = confession.duplicate(true)
		invalid.merge(edit, true)
		check(Live.Assess.activity_card(Live.Evidence.normalize_card(invalid), raw).is_empty(), "incomplete secret semantics receive no guessed explanation")
	var filed = Live.file(g, value)
	check(filed > 0, "the supported explanation files as an ordinary case")
	g.strict_evaluator = true
	g.set_workshop_effects(true)
	var heard = g._evaluate_deduction(listener, g.board[filed - 1], 1.0, false)
	check(heard.get("workshop", false) and secret_id in listener.workshop_state.facts, "an actual strict presentation retains the secret's exact shared root")
	var before = listener.suspicion.duplicate(true)
	g._evaluate_deduction(listener, g.board[filed - 1], 1.0, false)
	check(before == listener.suspicion, "repeating the explanation does not add another innocence award")
	print("Secret claims: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _ui(g, out: int, secret: int, person: String) -> void:
	var editor = Editor.new()
	editor.g = g
	root.add_child(editor)
	# A fresh Workshop starts blank; these checks argue the old preset premise.
	editor.set_premise_field(editor.case_root, "type", "evil")
	editor.set_premise_field(editor.case_root, "person", editor.board._default_target())
	await process_frame
	var root_id: String = editor.board.selected
	editor.add_evidence(out)
	var outing: String = editor.board.selected
	editor.board.connect_cards(outing, root_id)
	editor.add_evidence(secret)
	var explanation: String = editor.board.selected
	editor.board.connect_cards(explanation, root_id)
	editor.board.nodes[outing].reasons[person + ":1"] = "secret"
	editor._open_answer(outing)
	await process_frame
	var citation = editor.find_child("Citation_%s_1" % person, true, false)
	check(citation != null and citation.item_count == 2, "the actual live answer picker offers the secret claim: " + str(citation.item_count if citation != null else -1))
	if citation != null and citation.item_count > 1:
		citation.select(1)
		citation.item_selected.emit(1)
		check(editor.board.compile(root_id).citations.get(person + ":1", "") == editor.board.nodes[explanation].card, "the answer signal stores the exact explanation receipt")
	editor.queue_free()
	await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
