## The growing graveyard and the gallows on the town map (ui/map_view.gd, Limner Nov 22):
##   - the graveyard starts with one headstone and gains one for each death, hanging or murder;
##   - headstones come from the set in a shuffled order fixed by the case's seed, with no
##     repeat until the whole set is used, and never the same stone twice in a row;
##   - every headstone and the gallows has its art;
##   - the papercraft portraits are each person's neutral face (Michael's try-out).
## Headless: checks the choices, not pixels.
##   godot --headless --path . --script res://tools/test_map_graveyard.gd
extends SceneTree

const MapView = preload("res://ui/map_view.gd")
const VNPortraits = preload("res://ui/vn_portraits.gd")
const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")

var _checks: int = 0
var _fails: int = 0

func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var n: int = MapView.GRAVESTONES.size()
	var a: Array = MapView.gravestones(1234, 15)
	_check(a == MapView.gravestones(1234, 15), "the same case draws the same headstones")
	_check(a.slice(0, n).duplicate().all(func(s): return a.slice(0, n).count(s) == 1), "no repeat until the whole set of %d is used" % n)
	var twice = false
	for i in range(1, a.size()):
		if a[i] == a[i - 1]:
			twice = true
	_check(not twice, "never the same headstone twice in a row")
	_check(MapView.gravestones(1234, 3) == a.slice(0, 3), "a new death adds a stone and leaves the others as they were")
	var differ = false
	for s in range(1, 20):
		if MapView.gravestones(s, 3) != MapView.gravestones(0, 3):
			differ = true
	_check(differ, "different cases draw different headstones")
	_check(MapView.GRAVE_SLOTS.size() >= 11, "room for a headstone for every death in a 10-person town, and the first")
	_check(MapView.GRAVESTONES.all(func(s): return ResourceLoader.exists("res://assets/art/graveyard/%s.png" % s)), "every headstone has its art")
	_check(ResourceLoader.exists("res://assets/art/graveyard/gate.png") and ResourceLoader.exists("res://assets/art/decor/gallows.png"), "the gate and the gallows have their art")

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7, 10)
	var rng = g.w.rng.state
	_check(MapView.grave_count(g.w) == 1, "a new case's graveyard has one headstone")
	g.w.npcs[0].alive = false
	g.w.npcs[3].alive = false
	_check(MapView.grave_count(g.w) == 3, "two deaths, three headstones")
	MapView.gravestones(int(g.w.seed_value), 3)
	_check(g.w.rng.state == rng, "choosing headstones moves no game RNG")

	var all_paper = true
	for p in C.CAST:
		var t = VNPortraits.texture(p.id, "neutral")
		if t == null or not t.resource_path.begins_with("res://assets/art/portraits_paper/"):
			all_paper = false
			print("  not papercraft: ", p.id)
	_check(all_paper, "every cast member's neutral face is the papercraft portrait")
	_check(VNPortraits.texture("agnes", "warm") != null and not VNPortraits.texture("agnes", "warm").resource_path.contains("portraits_paper"), "other expressions are still the older art (Michael: mix for now)")
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
