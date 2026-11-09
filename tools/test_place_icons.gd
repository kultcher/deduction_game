## Place icons (cast list and profile) and the building action markers on the map.
##   godot --headless --path . --script res://tools/test_place_icons.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const PlaceIcons = preload("res://ui/place_icons.gd")
const MapView = preload("res://ui/map_view.gd")

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
	for l in C.LOCATIONS:
		_check(PlaceIcons.icon(l) != null, "an icon for %s" % l)
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	var n = g.w.npcs[0]
	var s: Array = PlaceIcons.slots(g, n)
	_check(s.size() == 3 and s[0].kind == "work" and s[0].loc == n.work and s[0].known, "the workplace is known from the start")
	_check(not s[1].known and not s[2].known, "both haunts start unknown")
	g.known_haunts[n.id] = [n.haunts[1]]
	s = PlaceIcons.slots(g, n)
	_check(s[1].known and s[1].loc == n.haunts[1] and not s[2].known, "a learned haunt fills the first haunt slot")
	_check(n.haunts[1] in PlaceIcons.tooltip(g, n) or C.loc_name(n.haunts[1]) in PlaceIcons.tooltip(g, n), "the tooltip names it")

	var map = MapView.new()
	map.g = g
	g.state = "day"
	g.w.phase = C.MORNING
	_check(map._action_marker("town_hall") != "" and map._action_marker("tavern") == "", "morning: the records marker, no gossip")
	g.w.phase = C.EVENING
	_check(map._action_marker("tavern") != "" and map._action_marker("town_hall") == "", "evening: gossip, no records")
	g.w.phase = C.AFTERNOON
	g.w.town_hall_uses_left = 0
	_check(map._action_marker("town_hall") == "", "no records marker once the reads are used up")
	g.state = "night"
	g.w.phase = C.EVENING
	_check(map._action_marker("tavern") == "", "nothing at night")
	map.free()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
