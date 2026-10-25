extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	var g = Game.new()
	g.new_case(7350, 10)
	g.w.dlog.detailed = false
	g.w.day = 4
	var goods: Array = g.w.living_good()
	var d = goods[0]
	var accuser = goods[1]
	var listener = goods[2]
	for n in g.w.npcs:
		for mind in [n, n.shadow]:
			if mind == null:
				continue
			mind.info_log = []
			mind.known_claims = {}
			mind.ledger = {}
			mind.beliefs = []
	d.role = "lamplighter"
	d.claimed_role = "lamplighter"
	d.claim_public = true
	Mind.ledger_hear(g.w, accuser, "test:out", [[d.id, 0.1, false, "seen out at night", "seen out"]], 1.0)
	var result = Mind.defend_self(g.w, d, accuser.id)
	var entries: Array = listener.ledger.values().filter(func(e): return e.meta.get("kind") == "defence")
	check(result.moves == ["reveal"] and entries.size() == 1 and listener.workshop_state.owned.has(entries[0].eid), "gift defence becomes an owned claim; its native bonus is parked")
	var plan = Shared.prepare(g.workshop_snapshot([], listener.id), {}, listener.ledger)
	var claims: Array = plan.prepared.view.cards.filter(func(card): return card.kind == "claim" and card.source == d.id and card.role == "lamplighter")
	check(plan.ready and claims.size() == 1 and is_equal_approx(claims[0].hearing_weight, entries[0].weight), "legacy defence strength and regard become claim hearing weight")
	var first: Array = listener.workshop_state.facts.duplicate()
	g.w.day += 1
	Mind.defend_self(g.w, d, accuser.id)
	check(listener.workshop_state.facts == first, "daily defence repeats retain the first receipt identity")
	d.claim_public = false
	d.role = "surveyor"
	d.secret = {}
	accuser.ledger = {}
	Mind.defend_self(g.w, d, "player")
	entries = listener.ledger.values().filter(func(e): return e.meta.get("kind") == "defence" and e.meta.scope.type == "plea")
	check(entries.size() == 1 and listener.workshop_state.owned.has(entries[0].eid), "plea remains speech and adds no native evidence discount")
	_seer_error()
	print("Defence mechanics: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)

func _seer_error() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var cards: Array = []
	for night in [0, 1]:
		cards.append({"id": "seer:%d" % night, "kind": "report", "source": "a", "role": "seer", "night": night, "observed_at": {"day": night, "phase": "night"}, "data": {"pair": ["b", "c"], "yes": night == 0}})
	var view = {"people": people, "cards": cards, "evil_count": 2, "alignment_epoch": "Original alignment", "world_options": {"modifiers": ["delusional"], "roles": true, "identities": true}}
	var value = Solver.empty_case()
	value.cards = cards.map(func(c): return c.id)
	value.conclusion = {"type": "evil", "target": "b", "at": view.alignment_epoch}
	var listener = Eval.neutral_listener(view)
	listener.knowledge = {"good": ["a"], "self": "a", "own_role": "seer"}
	var result = Eval.evaluate(view, value, listener)
	check(not result.impossible and is_finite(result.posterior), "contradictory own Seer contents use report error instead of voiding the whole view")
	var lone_claim = {"id": "impossible-identity", "kind": "claim", "source": "a", "role": "surveyor", "observed_at": {"day": 1, "phase": "morning"}, "data": {}}
	view.cards = [lone_claim]
	value.cards = [lone_claim.id]
	check(Eval.evaluate(view, value, listener).impossible, "an actual private role-identity contradiction is not softened as report contents")
