## A vote is public procedure, never another accusation or guilt by association.
extends SceneTree
const Game = preload("res://game/game.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Evil = preload("res://sim/evil.gd")
var checks = 0
var fails = 0

func _init() -> void:
	for size in [7, 10]:
		_run(size)
	print("Public votes: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _run(size: int) -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = false
	g.new_case(692, size)
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.known_claims = {}
			listener.beliefs = []
			listener.ledger = {}
			listener.workshop_state = {"enabled": false, "reasoning_mode": "full", "confidence_mode": "scale"}
	g.w.day = 2
	g.w.phase = 2
	g.w.meeting = {"block": "", "block_count": 0, "nominated": [], "nominators": [], "results": [], "pending": {}}
	var nominee = g.w.living_good()[0]
	var nominator = g.w.living_good()[1]
	g.w.open_nomination(nominator.id, nominee.id)
	var tally = g.w.vote_pending(false)
	var aggregate = g.w.public_log.filter(func(e): return e.kind == "vote")
	check(aggregate.size() == 1 and aggregate[0].by == "town" and aggregate[0].data.yes == tally.yes and aggregate[0].data.no == tally.no, "the actual vote emits one complete public process receipt")
	var with_receipt = g.w.public_log.duplicate(true)
	var social_before: Array = g.w.npcs.map(func(n): return [Evil.public_hostility(g.w, n), Evil.public_heat(g.w, n), Evil.exposure(g.w, n)])
	g.w.public_log = g.w.public_log.filter(func(e): return e.kind != "vote")
	check(social_before == g.w.npcs.map(func(n): return [Evil.public_hostility(g.w, n), Evil.public_heat(g.w, n), Evil.exposure(g.w, n)]), "the aggregate receipt does not duplicate nomination/voter hostility or heat")
	g.w.public_log = with_receipt
	g.w.public_log[-1].data["private_victim"] = "not-public"
	var number = g.add_card({"kind": "vote", "source": "player", "subject": tally.yes + [nominee.id], "day": 2, "phase": 2,
		"nominee": nominee.id, "by": nominator.id, "yes": tally.yes.duplicate(), "no": tally.no.duplicate(), "player_yes": tally.player_yes,
		"count": tally.count, "threshold": tally.threshold, "outcome": tally.outcome, "text": "The public vote tally"})
	var raw: Dictionary = g.board[number - 1]
	var fact = Evidence.normalize_card(raw)
	var rng = g.w.rng.state
	var input = g.workshop_snapshot([], nominator.id)
	check(rng == g.w.rng.state and not JSON.stringify(input).contains("not-public"), "snapshot transport copies only public vote fields and uses no RNG")
	var adapted = Assess.activity_card(fact, input)
	check(adapted.get("context_kind") == "vote" and adapted.data.nominee == nominee.id and adapted.data.yes == tally.yes and adapted.data.no == tally.no, "the vote adapter retains nominee and individual votes as neutral context")
	var ded = g.file_deduction({"type": "suspicious", "a": nominee.id}, [number])
	var prepared = Assess.prepare(g.workshop_snapshot([ded], nominator.id))
	check(prepared.ready, "a vote card is supported without turning the tally into evidence of guilt")
	if prepared.ready:
		var result = Eval.evaluate(prepared.view, prepared.case)
		check(result.people.values().all(func(p): return is_equal_approx(p.prior, p.posterior)), "votes alone have no alignment likelihood")
	g.set_workshop_effects(true)
	g.strict_evaluator = true
	for n in g.w.living():
		var heard = g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
		var listener = n.shadow if n.is_evil() else n
		check(heard.get("workshop", false) and fact.id in listener.workshop_state.facts, "strict public-vote presentation retains its receipt for " + n.id)
	var missing = input.duplicate(true)
	missing.public_events = []
	check(Assess.activity_card(fact, missing).is_empty(), "a card cannot invent an unannounced public vote")
	for changes in [{"nominee": "outsider"}, {"count": tally.count + 1}, {"by": "outsider"}, {"yes": tally.yes + ["outsider"]}, {"no": tally.no + [tally.no[0] if not tally.no.is_empty() else nominator.id]}, {"player_yes": "no"}, {"phase": 3}, {"day": 1}, {"outcome": "invented"}]:
		var bad = raw.duplicate(true)
		bad.erase("when")
		bad.merge(changes, true)
		check(Assess.activity_card(Evidence.normalize_card(bad), input).is_empty(), "an invalid or mismatched tally is rejected")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
