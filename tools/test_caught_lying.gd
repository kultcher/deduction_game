## "Caught lying about me" (Michael, Nov 21; BACKLOG "Rapport and Warden-credit leftovers" (a)).
## Told something about itself that its own knowledge proves false (a sighting of it out on a
## night it spent at home, or a reading that names it alone as evil when it's good), an NPC
## trusts the teller less, by the public-accusation loss. Only the teller, never a relayer;
## once per teller and claim; only what it knows is false.
extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _caught_entries(w, me, t) -> Array:
	return w.dlog.entries.filter(func(x): return x["type"] == "npc_trust" and x["actor"] == me.id and x["target"] == t.id and x.get("data", {}).get("why", "") == "caught_lying")

func _caught(w, me, t) -> int:
	return _caught_entries(w, me, t).size()

func _drop(w, me, t) -> Array:
	return _caught_entries(w, me, t).map(func(x): return snappedf(float(x["data"]["from"]) - float(x["data"]["to"]), 0.01))

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	var w = g.w
	w.day = 2
	var goods: Array = w.living_good()
	var me = goods[0]
	var teller = goods[1]
	var relayer = goods[2]
	me.history[w.time_key(1, C.NIGHT)] = "home:" + me.home_block
	me.history[w.time_key(0, C.NIGHT)] = "night:market"
	me.npc_trust[teller.id] = 0.6
	me.npc_trust[relayer.id] = 0.6
	var loss: float = Tuning.Social.TRUST_ACCUSED_ME
	# A sighting of it on a night it was home, told to it. (Each private share also moves the
	# teller's rapport by the gossip bond, so the logged reasons are what's compared.)
	Social._deliver(w, teller, me, {"kind": "sighting", "about": me.id, "block": "market", "day": 1, "from": teller.id, "key": "sighting:%s:1" % me.id})
	_check(_caught(w, me, teller) == 1, "told it was out on a night it spent at home, it trusts the teller less")
	_check(_drop(w, me, teller) == [loss], "by the public-accusation loss")
	Social._deliver(w, teller, me, {"kind": "sighting", "about": me.id, "block": "market", "day": 1, "from": teller.id, "key": "sighting:%s:1" % me.id})
	_check(_caught(w, me, teller) == 1, "the same lie counts once")
	# A sighting of a night it really was out: no lie it can prove.
	Social._deliver(w, teller, me, {"kind": "sighting", "about": me.id, "block": "market", "day": 0, "from": teller.id, "key": "sighting:%s:0" % me.id})
	_check(_caught(w, me, teller) == 1, "a sighting of a night it really was out costs nothing")
	# Relayed: the teller (the original source) pays, not the relayer.
	var other = goods[3]
	Social._deliver(w, relayer, me, {"kind": "sighting", "about": me.id, "block": "docks", "day": 1, "from": other.id, "relay": true, "key": "relay:sighting:%s:1:b" % me.id})
	_check(_caught(w, me, other) == 1 and _caught(w, me, relayer) == 0, "passed on, only the one who first said it loses trust")
	# A reading that names it alone as evil, when it's good.
	var reader = goods[4]
	me.npc_trust[reader.id] = 0.6
	var e: Dictionary = {"role": "martyr", "day": 1, "data": {"target": me.id, "evil": true}, "text": "x", "shared": true}
	_check(Social.caught_lying(w, me, reader.id, "reading", {"entry": e}), "a reading naming it alone as evil, when it's good, is a lie it knows")
	_check(is_equal_approx(me.npc_trust[reader.id], 0.6 - loss), "and costs the reader its trust")
	# A reading that names it among others proves nothing to it.
	var pair: Dictionary = {"role": "seer", "day": 1, "data": {"pair": [me.id, goods[5].id], "yes": true}, "text": "x"}
	_check(not Social.caught_lying(w, me, goods[5].id, "reading", {"entry": pair}), "one naming it among others proves nothing")
	# Evil isn't caught out by a true evil reading of it.
	var ev = w.npcs.filter(func(m): return m.is_evil())[0]
	var e2: Dictionary = {"role": "martyr", "day": 1, "data": {"target": ev.id, "evil": true}, "text": "x"}
	_check(not Social.caught_lying(w, ev, reader.id, "reading", {"entry": e2}), "an evil NPC knows a reading naming it evil is true")
	# The player's own word never counts here.
	_check(not Social.caught_lying(w, me, "player", "sighting", {"day": 1}), "the player's own card isn't an NPC's lie")
	print("Caught lying about me: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
