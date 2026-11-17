## A relayed alibi is the relayer's word too (Beadle's seed 100027, Nov 17). An evil Medium
## bluffer can invent "at their hearth I learned only that they were home": in a world where
## the relayer is evil it says nothing about the dead. Before, the movement model read it as
## the dead person's own word, so a good person seen out that night was impossible and the
## dead were convicted instead of the relayer (Kiran, a Demon victim, at 0.88; the relayer
## Agnes at 0.25). Now the relayed alibi is contested by its relayer, like a relayed
## sighting (LiveActivity._sighting_contests).
## Found by search (an evil Medium bluffer's home relay of a dead person held by a good
## listener), then the listener hears an honest third person's sighting of the dead out
## that night, which the relay contradicts.
##   godot --headless --path . --script res://tools/test_relayed_alibi.gd
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Connections = preload("res://workshop/connections.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks := 0
var fails := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var found: Dictionary = {}
	for day in [3, 4]:
		found = Seeds.search(day, func(g):
			var w = g.w
			for l in w.living_good():
				for c in Seeds.held_readings(l, func(x): return str(x.get("role", "")) == "medium" and x.get("data", {}) is Dictionary and str(x.data.get("item", {}).get("type", "")) == "home"):
					var teller = w.by_id.get(str(c.get("source", "")))
					var dead = w.by_id.get(str(c.data.get("dead", "")))
					if teller == null or dead == null or not teller.is_evil() or not teller.alive or dead.alive or dead.is_evil():
						continue
					for s in w.living_good():
						if s != l and s != dead:
							return {"listener": l.id, "teller": teller.id, "dead": dead.id, "sighter": s.id, "night": int(c.data.item.get("night", -1))}
			return {})
		if not found.is_empty():
			break
	check(not found.is_empty(), "found a good listener holding an evil Medium bluffer's home relay of a good dead person")
	if found.is_empty():
		_finish()
		return
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	var g = found.g
	var w = g.w
	var l = w.by_id[found.listener]
	var dead = w.by_id[found.dead]
	var tag: String = "seed %d: %s hears %s's relay that %s was home on night %d" % [int(found.seed), l.id, found.teller, dead.id, found.night]
	var before: Dictionary = _posteriors(g, l)
	# An honest sighting of the dead out that night, away from home.
	var block: String = ""
	for b in C.BLOCKS:
		if b != dead.home_block:
			block = b
			break
	var card: Dictionary = {"kind": "sighting", "source": found.sighter, "via": found.sighter, "subject": [dead.id], "block": block, "day": found.night, "phase": C.NIGHT,
		"learned": [{"day": w.day, "phase": w.phase, "via": found.sighter}], "text": "test sighting"}
	var receipt: Dictionary = Mind.WorkshopLedger.Evidence.normalize_card(card)
	Mind.ledger_hear(w, l, "heard:" + receipt.id, [], 1.0, [found.sighter, found.night, "report"],
		{"kind": "tell", "workshop_card": receipt, "workshop_teller": found.sighter, "workshop_origin": found.sighter, "workshop_public": false})
	var after: Dictionary = _posteriors(g, l)
	var d0: float = float(before.get(dead.id, -1.0))
	var d1: float = float(after.get(dead.id, -1.0))
	var t0: float = float(before.get(found.teller, -1.0))
	var t1: float = float(after.get(found.teller, -1.0))
	print("%s: the dead %.2f -> %.2f, the relayer %.2f -> %.2f, the sighter %.2f -> %.2f" % [tag, d0, d1, t0, t1, float(before.get(found.sighter, -1.0)), float(after.get(found.sighter, -1.0))])
	check(d1 >= 0.0 and d1 < 0.5, "%s: a sighting the relay contradicts doesn't convict the dead (%.2f)" % [tag, d1])
	check(t1 > t0, "%s: it counts against the relayer instead (%.2f -> %.2f)" % [tag, t0, t1])
	_finish()

func _posteriors(g, n) -> Dictionary:
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was
	var out: Dictionary = {}
	var eff: Dictionary = g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {})
	for id in eff:
		out[id] = float(eff[id].get("posterior", -1.0))
	return out

func _finish() -> void:
	print("Relayed alibi: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
