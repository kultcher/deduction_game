## Social readings retain public content without making opinions alignment evidence.
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Mind = preload("res://sim/mind.gd")
var checks = 0
var fails = 0

func _init() -> void:
	for size in [7, 10]:
		_family(size)
	print("Psychologist context: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _family(size: int) -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(692, size)
	for real in g.w.npcs:
		for n in [real, real.shadow]:
			if n == null:
				continue
			n.info_log = []
			n.known_claims = {}
			n.beliefs = []
			n.ledger = {}
			n.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	var source = g.w.npcs[0]
	var subject = g.w.npcs[1]
	var target = g.w.npcs[2]
	var reading = {"role": "psychologist", "day": 1, "phase": 3,
		"data": {"subject": subject.id, "trusts": target.id, "suspects": source.id}, "text": "Publicly reported social preferences"}
	var number = g.add_card({"kind": "info", "source": source.id, "role": reading.role, "day": reading.day,
		"phase": reading.phase, "data": reading.data, "text": reading.text})
	var fact: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	var value = Solver.empty_case()
	value.cards = [fact]
	value.conclusion = {"type": "evil", "target": target.id, "at": "Original alignment"}
	var filed = Live.file(g, value)
	check(filed > 0, "a Psychologist context case files for a %d-person town" % size)
	g.strict_evaluator = true
	g.set_workshop_effects(true)
	for real in g.w.living():
		var n = real.shadow if real.is_evil() else real
		var prepared = Live.Assess.prepare(g.workshop_snapshot([filed], real.id))
		check(prepared.ready and prepared.view.cards.any(func(c): return c.id == fact and c.kind == "context" and c.data == reading.data), "every listener receives the same structured context: " + real.id)
		if not prepared.ready:
			continue
		var ev = CaseEval.evaluate(prepared.view, prepared.case, prepared.listener)
		check(ev.people.values().all(func(p): return is_equal_approx(p.prior, p.posterior)), "social preferences alone change no alignment posterior: " + real.id)
		var before = n.suspicion.duplicate(true)
		var result = g._evaluate_deduction(n, g.board[filed - 1], 1.0, false)
		check(result.get("workshop", false) and n.workshop_state.active and fact in n.workshop_state.facts and n.suspicion == before, "shared ownership preserves the context without a guilt award: " + real.id)
	var listener = g.w.living_good()[0]
	Mind.apply_info(g.w, listener, source, reading, 1.0)
	check(fact in listener.workshop_state.facts and listener.workshop_state.owned.has(Mind.info_eid(source.id, reading)), "learned Psychologist receipts use the same owner as player presentations")
	var input = g.workshop_snapshot([filed], listener.id)
	for edit in [{"subject": "unknown"}, {"trusts": subject.id}, {"suspects": ""}]:
		var bad = input.duplicate(true)
		bad.evidence.filter(func(e): return e.id == fact)[0].content.data.merge(edit, true)
		check(not Live.Assess.prepare(bad).ready, "malformed social-reading identities are not guessed")
	# The same social observation remains context when a Medium faithfully relays it.
	g.w.day = 3
	g.add_card({"kind": "death", "source": "player", "subject": [source.id], "night": 1, "text": "Public death"})
	var medium = g.w.npcs[3]
	number = g.add_card({"kind": "info", "source": medium.id, "role": "medium", "day": 2, "phase": 3,
		"data": {"dead": source.id, "item": {"type": "reading", "entry": reading}}, "text": "Medium relays the social reading"})
	value.cards = [Live.Evidence.normalize_card(g.board[number - 1]).id]
	var prepared = Live.Assess.prepare(Live.snapshot(g, value, listener.id))
	check(prepared.ready and prepared.view.cards.any(func(c): return c.id in value.cards and c.kind == "context" and c.get("original_source", "") == source.id and not c.has("relay_source")), "a Medium preserves social-reading provenance without inventing an alignment likelihood")
	if prepared.ready:
		var ev = CaseEval.evaluate(prepared.view, prepared.case, prepared.listener)
		var without_social = prepared.case.duplicate(true)
		without_social.cards = []
		var public_only = CaseEval.evaluate(prepared.view, without_social, prepared.listener)
		check(ev.people == public_only.people, "a faithful relay of social preferences adds no alignment evidence beyond the public death")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
