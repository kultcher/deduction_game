## Papercraft art for places and homes (Nov 8, with Michael):
##   - every town building and the Town Hall has an interior that daytime talks sit in;
##   - homes and crime scenes have none, so those talks keep the blurred map;
##   - every townsperson in the cast has their own cottage on the map.
##   godot --headless --path . --script res://tools/test_location_art.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const ConversationView = preload("res://ui/day_conversation_view.gd")
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


func _exists(rel: String) -> bool:
	return ResourceLoader.exists("res://assets/" + rel + ".png")


func _run() -> void:
	var places: Array = C.LOCATIONS.keys() + C.PLAYER_BUILDINGS.keys()
	for l in places:
		var rel: String = ConversationView.scenery_path(l)
		_check(rel != "" and _exists(rel), "%s has an interior (%s)" % [l, rel])
	_check(ConversationView.scenery_path("home_agnes") == "", "a home has no interior")
	_check(ConversationView.scenery_path("scene_agnes") == "", "a crime scene has no interior")
	_check(ConversationView.scenery_path("") == "", "nowhere has no interior")

	for p in C.CAST:
		var rel: String = MapView.cottage_art(p)
		_check(_exists("art/" + rel), "%s has a cottage (%s)" % [p["name"], rel])

	# People out on a block's street stand inside that block: the street sits in the block
	# with room above it for a standee (about 90 image px), so zooming in doesn't dim them.
	for b in MapView.MAP_STREETS:
		var street: Rect2 = MapView.MAP_STREETS[b]
		var block: Rect2 = MapView.MAP_BLOCKS[b]
		_check(block.encloses(street) and street.end.y - 90.0 >= block.position.y,
			"%s street standees fit inside the %s block" % [b, b])

	# The view swaps between the room and the blurred map.
	var view = ConversationView.new()
	root.add_child(view)
	await process_frame
	view.set_location("tavern")
	_check(view.scenery.visible and view.scenery.texture != null, "a talk in the tavern shows the tavern")
	_check(not view.map_blur.visible, "the map blur is off in a room")
	view.set_location("home_agnes")
	_check(not view.scenery.visible, "a talk at someone's home has no room")
	_check(view.map_blur.visible, "a talk at someone's home keeps the map blur")
	view.set_location("town_hall")
	_check(view.scenery.visible, "the Town Hall has its room")
	view.queue_free()

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
