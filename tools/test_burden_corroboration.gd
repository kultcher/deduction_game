## Burdens prototype: corroboration (Michael, Nov 21). A holder's private telling is dated, and
## a confidant who passes it on keeps the claimant as the source and the original telling's
## date, with the confidant as the relayer. The judge dates a later public claim from the
## earliest telling the listener holds (Lantern's burden_claim_factors).
extends SceneTree
const Game = preload("res://game/game.gd")
const Burdens = preload("res://sim/burdens.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	var w = g.w
	var goods: Array = w.living_good()
	var o = goods[0]
	var friend = goods[1]
	var third = goods[2]
	o.secret_mod = "marked"
	w.day = 1
	w.phase = C.EVENING
	var told: Dictionary = Burdens.claim(w, o, "marked", false, "trusting %s" % friend.name, friend.id)
	_check(told["fact"].get("observed_at", {}) == {"day": 1, "phase": "day"}, "a private telling is dated when it's said")
	_check(w.burden_told.get("%s|%s" % [o.id, friend.id], {}) == {"day": 1, "phase": "day"}, "and the world remembers when that listener heard it")
	friend.known_secrets[o.id] = o.id
	w.day = 3
	Burdens.claim(w, o, "marked", false, "trusting %s again" % friend.name, friend.id)
	_check(w.burden_told["%s|%s" % [o.id, friend.id]]["day"] == 1, "telling the same listener again keeps the first date")
	var relay: Dictionary = Burdens.relay_fact(w, friend, o, Burdens.phrase(o))
	_check(relay["source"] == o.id and relay["relay_source"] == friend.id, "a relay keeps the claimant as source, the confidant as relayer")
	_check(relay["observed_at"]["day"] == 1, "and the original telling's date, not the day it's passed on")
	third.known_secrets[o.id] = friend.id
	var second: Dictionary = Burdens.relay_fact(w, third, o, Burdens.phrase(o))
	_check(second["observed_at"]["day"] == 1 and second["relay_source"] == third.id, "second-hand, it still dates from the holder's own telling")
	var pub: Dictionary = Burdens.claim(w, o, "marked", true, "being plain with the town from the start")
	_check(pub["fact"]["observed_at"]["day"] == 3 and not w.burden_told.has("%s|town" % o.id), "a public claim is dated too, and isn't a private telling")
	print("Burden corroboration: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
