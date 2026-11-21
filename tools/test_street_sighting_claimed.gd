## No street sighting evil's claimed role can't explain (Michael, Nov 20). A made-up sighting
## seen "while out" is told only once the teller has claimed a night-walking gift that took it
## out; until then it is held back, with a logged reason. A window sighting is told as before.
extends SceneTree
const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
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
	w.day = 2
	var e = w.npcs.filter(func(m): return m.is_evil() and m.alive)[0]
	var sg = w.living_good()[0]
	var block: String = sg.home_block
	w.evil_plan["scapegoat"] = sg.id
	w.evil_plan["daily_planter"] = e.id
	var street: Dictionary = {"kind": "saw", "who": sg.id, "loc": "", "block": block, "day": 1, "phase": C.NIGHT, "how": "street", "detail": "street"}
	w.evil_plan["planter_sighting"] = street.duplicate(true)
	w.evil_plan["fake_sightings"]["%s:1" % e.id] = street.duplicate(true)
	e.claimed_role = ""
	e.claim_public = false
	_check(not Evil.street_story_fits(e, street), "a street sighting doesn't fit a teller with no walking claim")
	_check(Evil.fake_night_sighting(w, e, 1) == null, "so the planter holds its street frame back")
	var held: Array = w.dlog.entries.filter(func(x): return x["type"] == "think" and x["actor"] == e.id and "Holds back its made-up sighting" in str(x.get("reason", "")))
	_check(held.size() == 1, "and logs why, once")
	Evil.fake_night_sighting(w, e, 1)
	held = w.dlog.entries.filter(func(x): return x["type"] == "think" and x["actor"] == e.id and "Holds back its made-up sighting" in str(x.get("reason", "")))
	_check(held.size() == 1, "asked again, it doesn't log it twice")
	e.claimed_role = "clerk"
	_check(Evil.fake_night_sighting(w, e, 1) == null, "a claimed gift that doesn't walk explains nothing")
	e.claimed_role = "nightwatch"
	var told = Evil.fake_night_sighting(w, e, 1)
	_check(told is Dictionary and str(told.get("who", "")) == sg.id, "once it has claimed the Night Watch, it tells the sighting")
	var window: Dictionary = street.duplicate(true)
	window["how"] = "window"
	window["block"] = e.home_block
	_check(Evil.street_story_fits(e, window), "a window sighting always fits")
	e.claimed_role = ""
	w.evil_plan["planter_sighting"] = window.duplicate(true)
	w.evil_plan["fake_sightings"]["%s:1" % e.id] = window.duplicate(true)
	var told_w = Evil.fake_night_sighting(w, e, 1)
	_check(told_w is Dictionary and str(told_w.get("how", "")) == "window", "and is told without any claim")
	print("Street sighting needs a claim: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
