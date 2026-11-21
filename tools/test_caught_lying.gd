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
	# A Night Watch's route names who was out, not who's evil (Codex on #506).
	var watcher = goods[6]
	me.npc_trust[watcher.id] = 0.6
	var route_out: Dictionary = {"role": "nightwatch", "day": 0, "data": {"seen": [me.id], "block": "market"}, "text": "x"}
	_check(not Social.caught_lying(w, me, watcher.id, "reading", {"entry": route_out}), "a Night Watch truly seeing it out is no lie")
	var route_home: Dictionary = {"role": "nightwatch", "day": 1, "data": {"seen": [me.id], "block": "market"}, "text": "x"}
	_check(Social.caught_lying(w, me, watcher.id, "reading", {"entry": route_home}), "but one placing it out on a night it was home is")
	# A Night Watch route naming several, one of them home that night (Codex on #506).
	var other2 = goods[7] if goods.size() > 7 else goods[5]
	var watcher2 = goods[5] if other2 != goods[5] else goods[4]
	me.dialogue_memory.erase("caught:%s:sighting:1" % watcher2.id)
	var route_many: Dictionary = {"role": "nightwatch", "day": 1, "data": {"seen": [other2.id, me.id], "block": "market"}, "text": "x"}
	_check(Social.caught_lying(w, me, watcher2.id, "reading", {"entry": route_many}), "a route naming several still catches the one it puts out wrongly")
	# A Registrar's yes says it holds a listed role, good ones included: no evil asserted.
	var reg: Dictionary = {"role": "registrar", "day": 1, "data": {"target": me.id, "yes": true, "roles": ["clerk", "poisoner"]}, "text": "x"}
	_check(not Social.caught_lying(w, me, goods[6].id, "reading", {"entry": reg}), "a Registrar's yes isn't an evil reading")
	# A Medium's relay passes on what it heard: it asserts nothing itself (Codex on #506).
	var med: Dictionary = {"role": "medium", "day": 1, "data": {"item": {"type": "reading", "entry": e}}, "text": "x"}
	_check(not Social.caught_lying(w, me, goods[6].id, "reading", {"entry": med}), "a Medium's relayed reading never counts against the Medium")
	# Evil isn't caught out by a true evil reading of it.
	var ev = w.npcs.filter(func(m): return m.is_evil())[0]
	var e2: Dictionary = {"role": "martyr", "day": 1, "data": {"target": ev.id, "evil": true}, "text": "x"}
	_check(not Social.caught_lying(w, ev, reader.id, "reading", {"entry": e2}), "an evil NPC knows a reading naming it evil is true")
	# An evil NPC knows its own nights too: told it was out when it was home (Codex on #506).
	var ev2 = w.npcs.filter(func(m): return m.is_evil())[0]
	ev2.history[w.time_key(1, C.NIGHT)] = "home:" + ev2.home_block
	Social._deliver(w, teller, ev2, {"kind": "sighting", "about": ev2.id, "block": "market", "day": 1, "from": teller.id, "key": "sighting:%s:1" % ev2.id})
	_check(_caught(w, ev2, teller) == 1, "an evil NPC told it was out on a night it spent at home trusts the teller less too")
	# The player's own word never counts here.
	_check(not Social.caught_lying(w, me, "player", "sighting", {"day": 1}), "the player's own card isn't an NPC's lie")
	print("Caught lying about me: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
