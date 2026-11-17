## A relayed lie is the original teller's, not the relayer's (playtest 26532: Greta, good,
## passed on Edda's fake Clerk reading, and "grimoire lies" listed it as Greta's lie).
## The relayer is logged as lying only when they're evil (they know an ally's fabrication).
extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _lies_by(w, actor: String, since: int) -> int:
	var n := 0
	for i in range(since, w.dlog.entries.size()):
		var e: Dictionary = w.dlog.entries[i]
		if e["type"] == "think" and e["data"].get("topic", "") == "lie" and e["actor"] == actor:
			n += 1
	return n

func _last_share(w, speaker: String, listener: String) -> Dictionary:
	for i in range(w.dlog.entries.size() - 1, -1, -1):
		var e: Dictionary = w.dlog.entries[i]
		if e["type"] == "npc_share" and e["actor"] == speaker and e["target"] == listener:
			return e
	return {}

func _init() -> void:
	var g = Game.new()
	g.new_case(44814, 10)
	var w = g.w
	w.day = 2
	var evils: Array = w.npcs.filter(func(n): return n.alive and n.is_evil())
	var goods: Array = w.living_good()
	var liar = evils[0]
	var ally = evils[1]
	var relayer = goods[0]
	var listener = goods[1]
	var subject = goods[2]
	var fake_e: Dictionary = {"day": 1, "role": "clerk", "data": {"who": subject.id, "yes": true}, "text": "I learned something.", "fake": true, "true": false}
	var told: Dictionary = {"kind": "reading", "entry": fake_e, "about": "", "from": liar.id, "key": "reading:1:clerk", "lie": true}
	var mark: int = w.dlog.entries.size()
	Social._deliver(w, liar, relayer, told.duplicate(true))
	check(_lies_by(w, liar.id, mark) == 1, "the evil teller's own fabrication is logged as their lie")
	var hs: Dictionary = relayer.hearsay.back()
	check(hs.get("lie", false), "the relayer's hearsay still records that the item was a lie at its source")
	var relay: Dictionary = hs.duplicate(true)
	relay["key"] = "relay:" + str(hs["key"])
	relay["relay"] = true
	mark = w.dlog.entries.size()
	Social._deliver(w, relayer, listener, relay.duplicate(true))
	check(_lies_by(w, relayer.id, mark) == 0, "a good relayer passing on a lie isn't logged as lying")
	var share: Dictionary = _last_share(w, relayer.id, listener.id)
	check(not share.is_empty() and not share["data"].get("lie", true), "grimoire talk doesn't mark the good relayer's share [LIE]")
	check(share["data"].get("relayed_lie", false), "the share records that it passed on someone else's lie")
	check(str(share["reason"]).find("heard from %s" % liar.name) >= 0, "the share still names the original teller")
	mark = w.dlog.entries.size()
	Social._deliver(w, ally, listener, relay.duplicate(true))
	check(_lies_by(w, ally.id, mark) == 1, "an evil relayer passing on an ally's fabrication is still logged as lying")
	print("relay lie attribution: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
