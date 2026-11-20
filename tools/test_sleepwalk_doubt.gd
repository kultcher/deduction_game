## A Rumormonger's word moves how unsure an NPC is that it is not the Sleepwalker
## (SourceDoubt.sleepwalk_doubt, applied in SharedLedger.prepare with each reading's route
## trust): named for it by a teller it trusts, its home nights count for less; a reading that
## rules it out makes them count for more. In a real game, a Sleepwalker seen out by an honest
## sighter then holds the sighting less against them.
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")
const Mind = preload("res://sim/mind.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _refresh(g, n) -> Dictionary:
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	return {"plan": g._workshop_plans.get(key, {}), "eval": g._workshop_evaluations.get(key, {})}


func _rumour(n, teller, pair: Array, secret: String, trust: float, via: String = "") -> void:
	n.known_claims[teller.id] = {"role": "rumormonger", "via": via, "readings": [{"role": "rumormonger", "day": 0,
		"data": {"pair": pair, "secret": secret}, "text": "I heard that one of them is %s" % secret}]}
	n.npc_trust[teller.id] = trust


func _init() -> void:
	_unit()
	_in_play()
	print("Sleepwalk doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _unit() -> void:
	var base: float = Tuning.Workshop.SLEEPWALK_SELF_DOUBT
	var people: Array = ["a", "b", "c", "d", "e", "f", "g"].map(func(id): return {"id": id})
	var view: Dictionary = {"people": people, "evil_count": 2, "world_options": {"modifiers": ["delusional", "sleepwalker"]}}
	check(is_equal_approx(SourceDoubt.sleepwalk_doubt(view, [], "a"), base), "with no Rumormonger reading, the doubt is SLEEPWALK_SELF_DOUBT")
	var named: float = SourceDoubt.sleepwalk_doubt(view, [{"pair": ["a", "b"], "secret": "sleepwalker", "trust": 0.9}], "a")
	check(named > base and named <= Tuning.Setup.SLEEPWALK_CHANCE, "named for the Sleepwalker by a trusted teller, it rises, to at most SLEEPWALK_CHANCE (%.3f)" % named)
	var faint: float = SourceDoubt.sleepwalk_doubt(view, [{"pair": ["a", "b"], "secret": "sleepwalker", "trust": 0.1}], "a")
	check(faint > base and faint < named, "a teller it hardly trusts moves it less (%.3f)" % faint)
	var elsewhere: float = SourceDoubt.sleepwalk_doubt(view, [{"pair": ["b", "c"], "secret": "sleepwalker", "trust": 0.9}], "a")
	check(elsewhere < base and elsewhere >= Tuning.Workshop.OWN_ERR, "the Sleepwalker named as someone else lowers it (%.3f)" % elsewhere)
	check(SourceDoubt.sleepwalk_doubt(view, [{"pair": ["a", "b"], "secret": "delusional", "trust": 0.9}], "a") < base, "another secret named on it lowers it too: a case has one secret")
	var own_view: Dictionary = view.duplicate(true)
	own_view["own_home"] = {"self": "a", "block": "x", "nights": {"0": base, "1": base}}
	SourceDoubt.apply_sleepwalk_doubt(own_view, [{"pair": ["a", "b"], "secret": "sleepwalker", "trust": 0.9}], "a")
	check(own_view.own_home.nights.values().all(func(v): return is_equal_approx(float(v), named)) and is_equal_approx(float(own_view.own_home.sleep_doubt), named),
		"its home nights and the role fits carry the same doubt")
	var plain: Dictionary = own_view.duplicate(true)
	plain.world_options.modifiers = ["delusional"]
	plain.own_home.nights = {"0": Tuning.Workshop.OWN_ERR}
	plain.own_home.erase("sleep_doubt")
	SourceDoubt.apply_sleepwalk_doubt(plain, [{"pair": ["a", "b"], "secret": "sleepwalker", "trust": 0.9}], "a")
	check(not plain.own_home.has("sleep_doubt") and is_equal_approx(float(plain.own_home.nights["0"]), Tuning.Workshop.OWN_ERR), "with no Sleepwalker on the script, nothing changes")


func _in_play() -> void:
	# A Sleepwalker seen out by an honest good sighter, in a game with a Rumormonger (so its
	# readings are supported on the script), who is neither of them.
	var found: Dictionary = Seeds.search(2, func(g):
		var w = g.w
		var rm: Array = w.npcs.filter(func(m): return m.role == "rumormonger")
		for s in w.living_good():
			if str(s.secret_mod) != "sleepwalker":
				continue
			for c in Seeds.held_cards(s, func(c): return str(c.get("kind", "")) == "sighting" and s.id in c.get("subjects", [c.get("subject", "")]) and not c.has("relay_source")):
				var sg = w.by_id.get(str(c.get("source", "")))
				var tellers: Array = rm.filter(func(m): return m != s and m != sg)
				if sg != null and sg.alive and not sg.is_evil() and not tellers.is_empty():
					return {"subject": s.id, "sighter": sg.id, "teller": tellers[0].id}
		return {}, 7, Seeds.SEEDS_FROM, 3 * Seeds.SEEDS_COUNT)
	if found.is_empty():
		check(false, "a Sleepwalker seen out by an honest sighter, with a Rumormonger (no seed has the case)")
		return
	var g = found.g
	var w = g.w
	var n = w.by_id[str(found.subject)]
	var sighter: String = str(found.sighter)
	var saved_claims: Dictionary = n.known_claims.duplicate(true)
	var saved_trust: Dictionary = n.npc_trust.duplicate(true)
	var tag: String = "seed %d: %s seen out by %s" % [int(found.seed), n.id, sighter]
	var teller = w.by_id[str(found.teller)]
	var other = w.npcs.filter(func(m): return m != n and m != teller and m.id != sighter)[0]
	for id in n.known_claims.keys():
		if str(n.known_claims[id].get("role", "")) == "rumormonger":
			n.known_claims.erase(id)

	_rumour(n, teller, [n.id, other.id], "sleepwalker", 0.5)
	var direct: Dictionary = _refresh(g, n)
	var d_direct: float = float(direct.plan.get("prepared", {}).get("view", {}).get("own_home", {}).get("sleep_doubt", -1.0))
	check(d_direct > Tuning.Workshop.SLEEPWALK_SELF_DOUBT, "%s: a heard reading naming it for the Sleepwalker raises the doubt in its weighing (%.3f)" % [tag, d_direct])
	var moved: float = float(direct.eval.get("proposal", {}).get("effects", {}).get(sighter, {}).get("posterior", -1.0))
	SourceDoubt.rumour_sleep_doubt = false
	var held: float = float(_refresh(g, n).eval.get("proposal", {}).get("effects", {}).get(sighter, {}).get("posterior", -1.0))
	SourceDoubt.rumour_sleep_doubt = true
	check(held >= 0.0 and moved >= 0.0 and moved < held, "%s: it holds the honest sighting less against the sighter (%.3f, against %.3f with the doubt held)" % [tag, moved, held])

	# Passed on by someone it distrusts: weighed by the card's route, as the reading is (Codex on #459).
	_rumour(n, teller, [n.id, other.id], "sleepwalker", 0.5, other.id)
	var other_trust = n.npc_trust.get(other.id, 0.5)
	n.npc_trust[other.id] = 0.0
	var relayed: Dictionary = _refresh(g, n)
	n.npc_trust[other.id] = other_trust
	var d_relayed: float = float(relayed.plan.get("prepared", {}).get("view", {}).get("own_home", {}).get("sleep_doubt", -1.0))
	check(d_relayed >= 0.0 and d_relayed <= d_direct, "%s: the same reading passed on by someone it distrusts moves it no more (%.3f against %.3f)" % [tag, d_relayed, d_direct])

	n.known_claims = saved_claims
	n.npc_trust = saved_trust
