## The "too clean when an ally is involved" pass over every bluffer (BACKLOG, Michael,
## Nov 17): each bluff rule held to the Dowser's #160 guideline, stay close to the truth
## and let the situation set the room.
## - A bluffing Augur whose street held the Demon among a crowd of four or more says the
##   true "yes" (a "yes" there points at nobody in particular); with a smaller crowd it
##   still covers the Demon.
## - A bluffing Psychologist that heard a fellow evil lie that day doesn't swear nobody
##   lied when it has two good people's words to cast doubt on instead.
extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Registry = preload("res://sim/role_registry.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_augur_crowd()
	_psychologist_ally_lie()
	print("Too-clean bluffs: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## A fresh case, day 1 evening, with every history slot for the day cleared to home.
func _world(seed: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed, 10)
	var w = g.w
	w.day = 1
	w.phase = C.EVENING
	for m in w.npcs:
		for ph in [C.MORNING, C.AFTERNOON]:
			m.history[w.time_key(1, ph)] = "home:" + m.home_block
	return w

## A public location on some block, and that block.
func _public_spot(w) -> String:
	for l in C.LOCATIONS.keys():
		var b: String = w.loc_block(l)
		if b != "" and not l.begins_with("home"):
			return l
	return ""

## The Augur's made-up reading for a bluffer who spent the morning at `spot` with the
## Demon and `extra` other good people.
func _augur_yes(seed: int, extra: int) -> Dictionary:
	var w = _world(seed)
	var spot: String = _public_spot(w)
	var demon = w.by_id[w.demon_id]
	var n = null
	for m in w.evil_team():
		if m.id != w.demon_id:
			n = m
			break
	if n == null:
		return {}
	var key: String = w.time_key(1, C.MORNING)
	n.history[key] = spot
	demon.history[key] = spot
	var goods: Array = w.living_good()
	for i in range(extra):
		goods[i].history[key] = spot
	# A scapegoat away from the street, so only the crowd decides.
	var s: String = goods[goods.size() - 1].id
	var gen: Dictionary = Registry.get_def("augur").generate_bluff_reading(w, n, w.evil_plan, s, n, [])
	return gen

func _augur_crowd() -> void:
	var big_yes: int = 0
	var small_yes: int = 0
	var ran: int = 0
	for sd in range(12):
		var big: Dictionary = _augur_yes(9600 + sd, 3)
		var small: Dictionary = _augur_yes(9600 + sd, 1)
		if big.is_empty() or small.is_empty():
			continue
		ran += 1
		if bool(big["entry"]["data"]["yes"]):
			big_yes += 1
		if bool(small["entry"]["data"]["yes"]):
			small_yes += 1
	print("  Augur: %d cases; yes with the Demon among 4 others %d, among 2 others %d" % [ran, big_yes, small_yes])
	_check(ran >= 8, "enough cases with a minion to bluff (%d)" % ran)
	_check(big_yes == ran, "the Demon among a crowd of four: the bluffing Augur says the true yes")
	_check(small_yes <= ran / 3, "the Demon among two others: it still mostly covers the Demon (%d of %d said yes)" % [small_yes, ran])

## A heard statement record, as Psychologist.record_heard builds it.
func _heard(w, src: String, fid: String, is_false: bool) -> Dictionary:
	return {"day_heard": w.day, "fact_id": fid, "is_false": is_false, "false_why": "",
		"public_stmt": {"fact_id": fid, "kind": "info", "source": src, "subject": [], "day": w.day, "phase": 3, "role": "seer", "data": {}, "block": "", "home": false, "summary": "%s's reading" % src, "text": ""},
		"card_fact": {}}

func _psychologist_ally_lie() -> void:
	var none_with_lie: int = 0
	var none_without: int = 0
	var ran: int = 0
	for sd in range(40):
		for ally_lied in [true, false]:
			var w = _world(9700 + sd)
			var team: Array = w.evil_team()
			if team.size() < 2:
				continue
			var n = team[0]
			var mate = team[1]
			var goods: Array = w.living_good()
			# A scapegoat with nothing said today, so the reading turns on the allies' words.
			var s: String = goods[goods.size() - 1].id
			n.heard_statements = [
				_heard(w, mate.id, "f_ally", ally_lied),
				_heard(w, goods[0].id, "f_g0", false),
				_heard(w, goods[1].id, "f_g1", false),
			]
			var gen: Dictionary = Registry.get_def("psychologist").generate_bluff_reading(w, n, w.evil_plan, s, mate, [])
			if gen.is_empty():
				continue
			var none: bool = str(gen["entry"].get("data", {}).get("mode", "")) == "none_false"
			if ally_lied:
				ran += 1
				none_with_lie += 1 if none else 0
			else:
				none_without += 1 if none else 0
	print("  Psychologist: %d cases; swore nobody lied %d times after a fellow evil lied, %d times when none had" % [ran, none_with_lie, none_without])
	_check(ran >= 30, "enough cases (%d)" % ran)
	_check(none_with_lie == 0, "after a fellow evil's lie, with two good people's words to hand, it never swears nobody lied")
	_check(none_without >= 6, "with no ally's lie heard it still sometimes does (%d of 40)" % none_without)
