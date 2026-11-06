## Premises pass, step 0b: one attended set for presentations. Naming the target outranks
## being a gift reading, a bounded listener keeps all of their own readings in view when a
## case is presented. The judging pass ranks against the premise's target; the belief
## update has none (step 0b revised: a premise moves beliefs only by conditioning, step 1).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	_salience_order()
	var tested := 0
	for seed_v in [42, 13910, 900]:
		tested += _seed(seed_v)
	_check(tested >= 2, "found bounded listeners holding their own readings to test (%d)" % tested)
	print("Attention 0b: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## The plan's worked example: an "Edda is evil" case presented to a listener.
func _salience_order() -> void:
	var listener := {"id": "me", "npc_trust": {}}
	var focus := {"target": "edda", "named": {"bram": true}}
	var sighting := {"id": "s", "kind": "sighting", "source": "x", "subjects": ["edda"], "data": {}}
	var named_sighting := {"id": "s2", "kind": "sighting", "source": "x", "subjects": ["bram"], "data": {}}
	var other_sighting := {"id": "s3", "kind": "sighting", "source": "x", "subjects": ["cole"], "data": {}}
	var seer_edda := {"id": "r1", "kind": "report", "role": "seer", "source": "x", "data": {"pair": ["edda", "cole"]}}
	var seer_other := {"id": "r2", "kind": "report", "role": "seer", "source": "x", "data": {"pair": ["cole", "dana"]}}
	var warden := {"id": "r3", "kind": "report", "role": "warden", "source": "x", "data": {"target": "dana"}}
	var sal := func(c, live := true): return Reasoner._salience(c, focus, listener, live)
	_check(sal.call(seer_edda) > sal.call(sighting), "a gift reading naming the target ranks first")
	_check(sal.call(sighting) > sal.call(seer_other), "a sighting of the target outranks an unrelated gift reading (%.2f vs %.2f)" % [sal.call(sighting), sal.call(seer_other)])
	_check(sal.call(seer_other) > sal.call(named_sighting), "a counted-group reading leaving the target out still earns the exclusion bump")
	_check(sal.call(named_sighting) > sal.call(other_sighting), "naming someone a presented card names counts")
	_check(sal.call(warden) > sal.call(other_sighting), "Warden readings count as gift readings in a live game")
	_check(not is_equal_approx(sal.call(warden, false), sal.call(warden, true)), "live-only gift roles only count live")
	_check(is_equal_approx(sal.call(seer_other) - sal.call(warden), Tuning.Workshop.SALIENCE_EXCLUSION), "the exclusion bump is only for counted-group readings")
	var trusted := listener.duplicate(true)
	trusted.npc_trust = {"x": 1.0}
	_check(Reasoner._salience(other_sighting, focus, trusted, true) - sal.call(other_sighting) < Tuning.Workshop.SALIENCE_EXCLUSION, "trust only breaks ties")
	var view := {"cards": [named_sighting]}
	var f: Dictionary = Reasoner._focus(view, {"conclusion": {}}, {"id": "me", "knowledge": {"attention_target": "edda"}}, ["s2"])
	_check(f.target == "" and f.named.has("bram") and f.named.has("x"), "the belief update has no target (step 0b revised): it ranks by the presented cards' people and sources (%s)" % [f])
	var fj: Dictionary = Reasoner._focus(view, {"conclusion": {"target": "edda"}}, {"id": "me", "knowledge": {}}, ["s2"])
	_check(fj.target == "edda", "the judging pass still ranks against the premise's target")

## Play to Day 3's afternoon, then present each bounded good listener a case of cards they
## hold but didn't receive themselves, filling their whole budget.
func _seed(seed_v: int) -> int:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, 10)
	var guard := 0
	while g.state != "over" and (g.w.day < 3 or g.w.phase < 1) and guard < 300:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	var tested := 0
	for n in g.w.living_good():
		Mind.refresh_beliefs(g.w, n, " (0b test)")
		var plan: Dictionary = g._workshop_plans.get(n.id + ":good", {})
		if plan.is_empty() or str(plan.prepared.listener.get("reasoning_mode", "")) != "bounded":
			continue
		var view: Dictionary = plan.prepared.view
		var own: Array = view.cards.filter(func(c): return str(c.get("kind", "")) == "report" and str(c.get("source", "")) == n.id).map(func(c): return c.id)
		var others: Array = view.cards.filter(func(c): return c.id not in own).map(func(c): return c.id)
		if own.is_empty() or others.size() < 13:
			continue
		var listener: Dictionary = plan.prepared.listener.duplicate(true)
		listener.insight = 0.1 # Low: 4 cards
		var limit: int = Reasoner.profile(0.1).cards
		var presented: Array = others.slice(0, limit)
		listener.knowledge["presented_reports"] = presented.duplicate()
		listener.knowledge["attention_reports"] = own.duplicate()
		listener.knowledge["own_reports"] = view.cards.map(func(c): return c.id).filter(func(id): return id not in presented)
		var target: String = str(g.w.living_good().filter(func(p): return p.id != n.id)[0].id)
		var value: Dictionary = plan.prepared.case.duplicate(true)
		value.cards = presented.duplicate()
		value.lines = []
		value.derived = []
		value.conclusion = value.conclusion.duplicate(true)
		value.conclusion.type = "evil"
		value.conclusion.target = ""
		var res: Dictionary = Reasoner._prepare(view, value, listener)
		var missing: Array = own.filter(func(id): return id not in res.considered)
		_check(missing.is_empty(), "%s/%s: a full presentation keeps every own reading in view (missing %s)" % [seed_v, n.id, missing])
		_check(presented.all(func(id): return id in res.considered), "%s/%s: the presented cards are all read" % [seed_v, n.id])
		# The leftover budget is spent; only linked counterparts (disprovers) may ride along.
		var hearsay: Array = res.considered.filter(func(id): return id not in own and id not in presented)
		_check(hearsay.size() <= 2, "%s/%s: hearsay stays bounded (%d extra)" % [seed_v, n.id, hearsay.size()])
		# Without a presentation, own readings still sit outside the budget as before.
		var plain: Dictionary = listener.duplicate(true)
		plain.knowledge.erase("presented_reports")
		var value2: Dictionary = value.duplicate(true)
		value2.cards = others.duplicate()
		value2.conclusion.target = target
		var res2: Dictionary = Reasoner._prepare(view, value2, plain)
		_check(own.all(func(id): return id in res2.considered), "%s/%s: an unfocused refresh keeps own readings" % [seed_v, n.id])
		tested += 1
	return tested
