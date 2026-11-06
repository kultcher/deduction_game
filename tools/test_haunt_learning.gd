## Two ways to learn a haunt firsthand (Nov 6):
##   - Searching a social spot turns up one of its regulars, once per place per game, told by
##     whoever works there (or heard around the place when nobody does).
##   - Seeing someone idle at one of their haunts, from the same block, on 2 different days
##     (3 for the tavern) teaches it.
##   godot --headless --path . --script res://tools/test_haunt_learning.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const GameDayNight = preload("res://game/game_day_night.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_search()
	_test_sightings()
	print("Haunt learning: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _game(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 10)
	if g.state == "approach":
		g.command("decline")
	return g


## A place some living townsperson haunts, and nobody's yet known to.
func _haunted_place(g) -> String:
	for l in ["bakery", "smithy", "mill", "chapel", "graveyard", "wharf", "well"]:
		if g.w.living().any(func(n): return l in n.haunts):
			return l
	return ""


func _test_search() -> void:
	var g = _game(7101)
	var l: String = _haunted_place(g)
	_check(l != "", "found a place someone haunts")
	g.loc = l
	g.moved = true
	var regulars: Array = g.w.living().filter(func(n): return l in n.haunts)
	var before: int = regulars.filter(func(n): return l in g.known_haunts.get(n.id, [])).size()
	g.events.clear()
	GameDayNight._search(g)
	var after: int = regulars.filter(func(n): return l in g.known_haunts.get(n.id, [])).size()
	_check(after == before + 1, "searching %s turns up one of its regulars (%d -> %d of %d)" % [l, before, after, regulars.size()])
	var text: String = g.events.filter(func(e): return e.get("k", "") == "narration").map(func(e): return str(e.text)).reduce(func(a, b): return a + " " + b, "")
	var workers: Array = g.w.living().filter(func(n): return n.work == l and not (l in n.haunts))
	if not workers.is_empty():
		_check(C.OCCUPATIONS[workers[0].occupation]["title"] in text, "whoever works there points them out (%s)" % text)
	var learned = regulars.filter(func(n): return l in g.known_haunts.get(n.id, []))
	_check(learned.any(func(n): return g.profile_receipts_for(n.id).any(func(c): return c.get("kind", "") == "haunt" and c.get("loc", "") == l)),
		"it's kept as a haunt receipt on their profile")
	GameDayNight._search(g)
	var again: int = regulars.filter(func(n): return l in g.known_haunts.get(n.id, [])).size()
	_check(again == after, "a place's regulars are asked about once per game")


func _test_sightings() -> void:
	var g = _game(7102)
	var x = null
	var hl: String = ""
	for n in g.w.living():
		for h in n.haunts:
			if h != "tavern":
				x = n
				hl = h
				break
		if x != null:
			break
	_check(x != null, "found someone with a non-tavern haunt")
	var spots: Array = g.w.locations_on(g.w.loc_block(hl)).filter(func(s): return s != hl)
	var watch: String = spots[0] if not spots.is_empty() else hl
	var see = func(day: int) -> void:
		g.w.day = day
		x.working = false
		x.loc = hl
		g.loc = watch
		g.moved = true
		GameDayNight._observe(g)
	see.call(1)
	_check(not (hl in g.known_haunts.get(x.id, [])), "one sighting isn't enough")
	see.call(1)
	_check(not (hl in g.known_haunts.get(x.id, [])), "two sightings on the same day count once")
	see.call(2)
	_check(hl in g.known_haunts.get(x.id, []), "seen idling there from the same block on two days, it's learned (%s at %s)" % [x.id, hl])
	# The tavern takes three days.
	var g2 = _game(7103)
	var y = g2.w.living()[0]
	if not ("tavern" in y.haunts):
		y.haunts = ["tavern", y.haunts[0] if y.haunts[0] != "tavern" else y.haunts[1]]
	for d in [1, 2]:
		g2.w.day = d
		y.working = false
		y.loc = "tavern"
		g2.loc = "tavern"
		g2.moved = true
		GameDayNight._observe(g2)
	_check(not ("tavern" in g2.known_haunts.get(y.id, [])), "two tavern days aren't enough")
	g2.w.day = 3
	y.loc = "tavern"
	GameDayNight._observe(g2)
	_check("tavern" in g2.known_haunts.get(y.id, []), "three tavern days are")
	# Working there doesn't count.
	var g3 = _game(7104)
	var z = g3.w.living()[0]
	var zh: String = z.haunts[0]
	for d in [1, 2]:
		g3.w.day = d
		z.working = true
		z.loc = zh
		g3.loc = zh
		g3.moved = true
		GameDayNight._observe(g3)
	_check(not (zh in g3.known_haunts.get(z.id, [])), "someone at work isn't idling at a haunt")
