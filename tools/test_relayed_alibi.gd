## A relayed alibi is the relayer's word too (Beadle's seed 100027, Nov 17). An evil Medium
## bluffer can invent "at their hearth I learned only that they were home": in a world where
## the relayer is evil it says nothing about the dead. Before, the movement model read it as
## the dead person's own word, so a good person seen out that night was impossible and the
## dead were convicted instead of the relayer (Kiran, a Demon victim, at 0.88; the relayer
## Agnes at 0.25). Now the relayed alibi is contested by its relayer, like a relayed
## sighting (LiveActivity._sighting_contests).
## Built on a controlled deal (Seneschal, Nov 21): a search on played games kept finding cases
## that tested something else (the victim's own kill night, a sighter already suspected), and
## with those left out it found none in 120 seeds. So the case is built, as test_relay_bluff
## builds its own: an evil Medium bluffer relays that a good victim was home on night 0, a
## night before the one they were killed; they were in fact out on the sighter's block, and
## the sighter, a good townsperson at home, saw them from the window. The listener holds the
## relay, then hears the sighting.
##   godot --headless --path . --script res://tools/test_relayed_alibi.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const GameBoard = preload("res://game/game_board.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")

var checks := 0
var fails := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1

const DEALS: Array = [692, 900, 42, 54875, 98933]

func _init() -> void:
	for deal in DEALS:
		var built: Dictionary = _built(deal)
		if not built.is_empty():
			_case(built)
			_finish()
			return
	check(false, "built the case on one of the deals %s" % [DEALS])
	_finish()

## The deal, set up: an evil Medium bluffer (no good Medium on the script, so its claim stands),
## a good victim killed on night 1, a good listener, and a good sighter at home on night 0 on a
## block other than the victim's. {} if the deal lacks the people.
func _built(deal: int) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(deal, 7)
	var w = g.w
	var team: Array = w.evil_team()
	if team.is_empty():
		return {}
	var medium = team[0]
	for n in w.living_good():
		if n.role == "medium":
			n.role = "clerk"
	if "medium" not in w.case_script.town:
		w.case_script.town.append("medium")
	var goods: Array = w.living_good()
	if goods.size() < 3:
		return {}
	var dead = goods[0]
	var listener = goods[1]
	var sighters: Array = goods.filter(func(n): return n != dead and n != listener and n.home_block != dead.home_block)
	if sighters.is_empty():
		return {}
	var sighter = sighters[0]
	# Night 0: the victim was out on the sighter's block; the sighter stayed home.
	dead.history[w.time_key(0, 3)] = "night:" + sighter.home_block
	sighter.history[w.time_key(0, 3)] = "home:" + sighter.home_block
	w.day = 1
	w._kill(dead)
	w.day = 2
	GameBoard._facts(g, [{"kind": "death", "subject": [dead.id], "block": dead.home_block, "source": "player", "night": 1, "text": "%s was killed by the demon on night 1." % dead.name}])
	var entry: Dictionary = {"day": 2, "phase": 3, "role": "medium", "shared": true, "true": false,
		"data": {"dead": dead.id, "item": {"type": "home", "night": 0, "block": dead.home_block, "lie": true}},
		"text": "communing with the dead at %s's hearth, I learned only that they were home the night before you arrived" % dead.name}
	medium.info_log.append(entry)
	Mind.apply_info(w, listener, medium, entry, 0.8)
	return {"g": g, "deal": deal, "listener": listener.id, "teller": medium.id, "dead": dead.id, "sighter": sighter.id, "night": 0}

func _case(found: Dictionary) -> void:
	var g = found.g
	var w = g.w
	var l = w.by_id[found.listener]
	var dead = w.by_id[found.dead]
	var tag: String = "deal %d: %s hears %s's relay that %s was home on night %d" % [int(found.deal), l.id, found.teller, dead.id, found.night]
	var before: Dictionary = _posteriors(g, l)
	# The honest sighting of the dead out that night, from the sighter's window.
	var block: String = w.by_id[found.sighter].home_block
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
	check(t0 >= 0.0, "%s: the listener holds the relay and weighs the relayer" % tag)
	check(d1 >= 0.0 and d1 < 0.5, "%s: a sighting the relay contradicts doesn't convict the dead (%.2f)" % [tag, d1])
	check(t1 > t0, "%s: it counts against the relayer instead (%.2f -> %.2f)" % [tag, t0, t1])

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
