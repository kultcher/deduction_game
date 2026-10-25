extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	var w = g.w
	var lamp = w.living_good()[0]
	for n in w.npcs:
		n.secret_mod = ""
		n.secret = {}
	lamp.home_block = "square"
	var found = {}
	var correct = true
	for night in range(1000):
		w.day = night
		w.dropped.clear()
		w._night_movement("", "", null, "", null, "", null, "", lamp)
		var count = 0
		for loc in w.dropped:
			found[C.loc_block(loc)] = true
			count += w.dropped[loc].size()
			correct = correct and C.LOCATIONS.has(loc) and w.dropped[loc][0].who == lamp.id
		correct = correct and count <= 1
	check(found.size() == 4, "Lamplighter drops can occur on every block of its actual route")
	check(correct, "one ordinary drop roll uses only public locations and the correct walker")
	check(lamp.night_path == C.BLOCKS.keys() and w.night_walkers[0].path == lamp.night_path, "drop sampling and sightings use the same completed lamp route")
	var ordinary = true
	for night in range(1000):
		w.day = night
		w.dropped.clear()
		w.night_walkers.clear()
		w._walk(lamp, "market", "ordinary trip")
		for loc in w.dropped:
			ordinary = ordinary and C.loc_block(loc) in ["square", "market"]
	check(ordinary and lamp.night_path == C.route("square", "market"), "ordinary walkers still drop only along their shortest route")
	print("Lamplighter drops: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		fails += 1
		push_error("FAIL: " + label)
