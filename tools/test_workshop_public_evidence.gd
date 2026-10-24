extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Public = preload("res://workshop/public_evidence.gd")
const Assess = preload("res://workshop/live_assessment.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_probabilities()
	_live()
	print("Public evidence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _probabilities() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d"]:
		people.append({"id": id, "name": id, "home": "square"})
	var event = {"kind": "demon_death", "subjects": ["a"], "at": {"day": 1, "phase": "night"}}
	var view = {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": ["delusional"]}, "timeline": Assess.History.from_events([])}
	var value = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": "a", "at": view.alignment_epoch}
	var before = Eval.evaluate(view, value)
	view.timeline = Assess.History.from_events([event])
	var after = Eval.evaluate(view, value)
	check(is_equal_approx(before.posterior, 0.5) and is_equal_approx(after.posterior, 0.05), "95:5 public evidence gives 95% innocence from even prior odds")
	check(after.posterior > 0.0 and not after.impossible, "Demon death does not exclude evil worlds")
	view.timeline = Assess.History.from_events([event, event.duplicate(true)])
	check(Eval.evaluate(view, value).posterior == after.posterior, "repeating the same death announcement cannot stack evidence")
	var listener = Eval.neutral_listener(view)
	listener.suspicion = {"a": 0.9, "b": 0.3, "c": 0.3, "d": 0.3}
	check(Eval.evaluate(view, value, listener).posterior > after.posterior, "prior counterevidence can outweigh some of the innocence signal")
	for night in [1, 2, 3]:
		var report = {"id": "report:%d" % night, "kind": "report", "source": "b", "role": "dowser", "night": night,
			"observed_at": {"day": night, "phase": "morning"}, "data": {"group": ["a"], "count": 1}}
		view.cards.append(report)
		value.cards.append(report.id)
	var challenged = Eval.evaluate(view, value)
	check(challenged.posterior > after.posterior and challenged.posterior < 1.0, "gift evidence can argue against a dead victim without an automatic veto (%.6f -> %.6f)" % [after.posterior, challenged.posterior])
	check(Public.demon_victims([{"kind": "demon_death", "subjects": ["outsider"], "at": {"day": 1}}], ["a"]).is_empty(), "an unknown victim supplies no factor")
	check(Public.demon_victims([{"kind": "demon_death", "subjects": ["a"], "at": {"day": -1}}], ["a"]).is_empty(), "an undated death supplies no factor")

func _live() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.known_claims = {}
			listener.beliefs = []
			listener.ledger = {}
			listener.workshop_state = {"enabled": true, "reasoning_mode": "full", "confidence_mode": "scale"}
			listener.role = "warden" if not listener.is_evil() else listener.role
			for id in listener.suspicion:
				listener.suspicion[id] = 0.8
	var victim = g.w.living_good()[1]
	var observer = g.w.living_good()[0]
	g.w.day = 1
	g.w.night_walkers = []
	g.w._kill(victim)
	check(g.w.public_log.any(func(e): return e.kind == "demon_death" and victim.id in e.subjects), "a kill publishes its public observation before belief refresh")
	for n in g.w.living():
		var listener = n.shadow if n.is_evil() else n
		if listener == null:
			continue
		var eid = "demon_death:" + victim.id
		check(listener.workshop_state.active and listener.workshop_state.owned.has(eid), "public death has one shared owner for " + listener.id)
		check(listener.ledger[eid].applied.values().all(func(v): return is_zero_approx(v)), "native death contribution is parked for " + listener.id)
		check(Mind.susp(listener, victim.id) > 0.0 and Mind.susp(listener, victim.id) < 0.8, "public death lowers suspicion without a reset for " + listener.id)
	var input = g.workshop_snapshot([], observer.id)
	var prepared_listener = Assess._listener(input, [])
	check(victim.id not in prepared_listener.knowledge.good, "a public victim is absent from hard known-good knowledge")
	var fixed = observer.suspicion.duplicate(true)
	var rng = g.w.rng.state
	Mind.recompute_beliefs(g.w, observer, "unchanged death")
	check(_close(fixed, observer.suspicion) and g.w.rng.state == rng, "unchanged death refresh is reversible and consumes no RNG")
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1,
		"block": victim.home_block, "text": "Another receipt of the public announcement"})
	Mind.recompute_beliefs(g.w, observer, "board announcement")
	check(_close(fixed, observer.suspicion), "world announcement and board receipt contribute once together")
	Mind.adjust(g.w, observer, victim.id, 0.12, "later counterevidence", "", false)
	check(is_equal_approx(observer.suspicion[victim.id], fixed[victim.id] + 0.12), "dead victims remain open to later counterevidence")
	# The transitional native path also has finite, retractable evidence.
	g.set_workshop_effects(false)
	var native_before = observer.suspicion.duplicate(true)
	Mind.recompute_beliefs(g.w, observer, "native repeat")
	check(_close(native_before, observer.suspicion) and Mind.susp(observer, victim.id) > 0.0, "native compatibility never reinstates a hard clear or stacks on recompute")
	g.set_workshop_effects(true)
	check(observer.workshop_state.active, "re-enabling shared effects restores ownership of public evidence")

func _close(a: Dictionary, b: Dictionary) -> bool:
	for id in a:
		if absf(float(a[id]) - float(b.get(id, INF))) > 0.000001:
			return false
	return true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
