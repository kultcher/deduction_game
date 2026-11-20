## A Rumormonger's word moves how unsure an NPC is that it is not the Sleepwalker
## (WorkshopBridge.sleepwalk_doubt): named for it by a teller it trusts, its home nights
## count for less; a reading that rules it out makes them count for more. In a real game, a
## Sleepwalker seen out by an honest sighter then holds the sighting less against them.
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")
const Mind = preload("res://sim/mind.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _guilt(g, n, teller: String) -> float:
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	return float(g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {}).get(teller, {}).get("posterior", -1.0))


func _rumour(n, teller, pair: Array, secret: String, trust: float) -> void:
	n.known_claims[teller.id] = {"role": "rumormonger", "via": "", "readings": [{"role": "rumormonger", "day": 0,
		"data": {"pair": pair, "secret": secret}, "text": "I heard that one of them is %s" % secret}]}
	n.npc_trust[teller.id] = trust


func _init() -> void:
	var found: Dictionary = Seeds.sleepwalker_sighting(2)
	if found.is_empty():
		check(false, "a Sleepwalker seen out by an honest sighter (no seed has the case)")
		quit(1)
		return
	var g = found.g
	var w = g.w
	var n = w.by_id[str(found.subject)]
	var sighter: String = str(found.sighter)
	var base: float = Tuning.Workshop.SLEEPWALK_SELF_DOUBT
	var saved_claims: Dictionary = n.known_claims.duplicate(true)
	var saved_trust: Dictionary = n.npc_trust.duplicate(true)
	print("seed %d: %s seen out by %s" % [int(found.seed), n.id, sighter])
	var teller = w.npcs.filter(func(m): return m != n and m.id != sighter and not n.known_claims.has(m.id))[0]
	var other = w.npcs.filter(func(m): return m != n and m != teller and m.id != sighter)[0]
	for id in n.known_claims.keys():
		if str(n.known_claims[id].get("role", "")) == "rumormonger":
			n.known_claims.erase(id)
	check(is_equal_approx(Bridge.sleepwalk_doubt(w, n), base), "with no Rumormonger reading, the doubt is SLEEPWALK_SELF_DOUBT")

	_rumour(n, teller, [n.id, other.id], "sleepwalker", 0.9)
	var named: float = Bridge.sleepwalk_doubt(w, n)
	check(named > base and named <= Tuning.Setup.SLEEPWALK_CHANCE, "named for the Sleepwalker by a trusted teller, it rises, to at most SLEEPWALK_CHANCE (%.3f)" % named)
	_rumour(n, teller, [n.id, other.id], "sleepwalker", 0.1)
	var faint: float = Bridge.sleepwalk_doubt(w, n)
	check(faint > base and faint < named, "a teller it hardly trusts moves it less (%.3f)" % faint)
	_rumour(n, teller, [n.id, other.id], "sleepwalker", 0.5)
	var direct: float = Bridge.sleepwalk_doubt(w, n)
	n.known_claims[teller.id]["via"] = other.id
	var other_trust = n.npc_trust.get(other.id, 0.5)
	n.npc_trust[other.id] = 0.0
	var relayed: float = Bridge.sleepwalk_doubt(w, n)
	n.npc_trust[other.id] = other_trust
	check(relayed > base and relayed < direct, "a half-trusted teller's reading, passed on by someone it distrusts, moves it less than told directly (%.3f against %.3f; Codex on #459)" % [relayed, direct])
	_rumour(n, teller, [other.id, sighter], "sleepwalker", 0.9)
	var elsewhere: float = Bridge.sleepwalk_doubt(w, n)
	check(elsewhere < base and elsewhere >= Tuning.Workshop.OWN_ERR, "the Sleepwalker named as someone else lowers it (%.3f)" % elsewhere)
	_rumour(n, teller, [n.id, other.id], "delusional", 0.9)
	check(Bridge.sleepwalk_doubt(w, n) < base, "another secret named on it lowers it too: a case has one secret")
	var input: Dictionary = Bridge.capture(g, [], n.id)
	var own: Dictionary = input.get("own_home", {})
	check(own.get("nights", {}).values().all(func(v): return is_equal_approx(float(v), Bridge.sleepwalk_doubt(w, n))) and is_equal_approx(float(own.get("sleep_doubt", -1.0)), Bridge.sleepwalk_doubt(w, n)),
		"its home nights and the role fits carry the same doubt")

	_rumour(n, teller, [n.id, other.id], "sleepwalker", 0.9)
	Bridge.rumour_moves_sleepwalk_doubt = false
	var held: float = _guilt(g, n, sighter)
	Bridge.rumour_moves_sleepwalk_doubt = true
	var moved: float = _guilt(g, n, sighter)
	check(held >= 0.0 and moved >= 0.0 and moved < held, "named for the Sleepwalker, it holds the honest sighting less against the sighter (%.3f, against %.3f with the doubt held)" % [moved, held])

	n.known_claims = saved_claims
	n.npc_trust = saved_trust
	print("Sleepwalk doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
