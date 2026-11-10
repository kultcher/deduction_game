## Nov 9 small fixes (case 12926 follow-ups): board marks for alibis, Dowser readings and
## tavern gossip; the Breathstealer's crowd boost.
##   godot --headless --path . --script res://tools/test_small_fixes_1109.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const CardModel = preload("res://game/card_model.gd")
const Tuning = preload("res://sim/tuning.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var alibi = {"kind": "alibi", "subject": ["p"], "block": "hill", "day": 1, "phase": C.NIGHT, "source": "p", "text": "a"}
	var am: Array = CardModel.place_markers(alibi)
	_check(am.size() == 1 and am[0].mark == "home" and am[0].who == "p", "a home alibi is a 'home' (square) marker on the person")
	var dows = {"kind": "info", "role": "dowser", "source": "agnes", "day": 1, "data": {"block": "market", "group": ["odette", "lian"], "count": 1}, "text": "d"}
	var dm: Array = CardModel.place_markers(dows)
	_check(dm.size() == 1 and dm[0].mark == "dowser" and dm[0].who == "agnes", "a Dowser reading is one node on the Dowser, not a dot per person")
	var rum = {"kind": "info", "role": "nightwatch", "source": "rumour", "tavern_gossip": true, "day": 3, "data": {"block": "market", "seen": ["hollis"]}, "text": "r"}
	_check(CardModel.place_markers(rum).all(func(m): return m.mark == "dotted"), "a tavern rumour of a Night Watch reading is dotted (gossip, not evidence)")
	var nw = {"kind": "info", "role": "nightwatch", "source": "fenwick", "day": 3, "data": {"block": "market", "seen": ["hollis"]}, "text": "n"}
	_check(CardModel.place_markers(nw)[0].mark == "ability", "a Night Watch reading told to you keeps its ability marker")

	# The Breathstealer: a crowd of three or more others at their place adds the bonus.
	var Bs = load("res://sim/roles/breathstealer.gd").new()
	var Evil = load("res://sim/evil.gd")
	var rates: Array = []
	for crowd in [false, true]:
		var hits: int = 0
		for seed in range(9000, 9120):
			var g = Game.new()
			g.detailed_logging = false
			g.new_case(seed, 10)
			var w = g.w
			w.day = 1
			w.phase = C.MORNING
			var bs = w.npcs.filter(func(n): return n.is_evil() and n.id != w.demon_id)[0]
			var goods: Array = w.living_good()
			for n in w.npcs:
				n.loc = "home"
			bs.loc = "tavern"
			goods[0].loc = "tavern" if crowd else "well"
			if crowd:
				goods[1].loc = "tavern"
				goods[2].loc = "tavern"
			if Bs.breath_target(w, bs, Evil) != "":
				hits += 1
		rates.append(hits)
	_check(rates[1] > rates[0] + 15, "a crowd of three makes silencing likelier (%d vs %d of 120)" % [rates[1], rates[0]])
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
