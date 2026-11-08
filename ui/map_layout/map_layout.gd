@tool
## The town map's layout, editable in the Godot editor (open ui/map_layout/map_layout.tscn).
## Everything sits on the painted base map in image pixels (the map is 1536 x 1024, top-left
## at 0, 0). Drag nodes to move things; select one to change its size in the Inspector.
##   Blocks/<block>      each block's area: zoom, clicks and the highlight (top-left + size)
##   Streets/<block>     where people out and about stand on that block (top-left + size)
##   Signs/<block>       the block's name plaque (its centre sits just below this point)
##   Buildings/<place>   a building's lot (centre + size, plus the lot art)
##   Cottages/<block>/*  cottage spots, filled in child order. Duplicate one (Ctrl+D) to add
##                       a spot; a block needs as many as its residents (3 in a 10-person town).
## The preview draws the art the way the game does (MapGeometry), so what you see here is
## what the game shows. Save the scene, and the game picks it up on its next start.
extends Node2D

const MAP_PX = Vector2(1536, 1024)

## The painted base map, relative to res://assets/art/.
@export var map_image: String = "map/town_open":
	set(v):
		map_image = v
		_refresh_base()
## Show building and cottage art (off: outlines only, quicker to read).
@export var show_art: bool = true:
	set(v):
		show_art = v
		_redraw_all()
## Show the block and street areas.
@export var show_areas: bool = true:
	set(v):
		show_areas = v
		_redraw_all()

func _ready() -> void:
	_refresh_base()

func _refresh_base() -> void:
	var base: Sprite2D = get_node_or_null("BaseMap")
	if base != null and Engine.is_editor_hint():
		var path := "res://assets/art/%s.png" % map_image
		if ResourceLoader.exists(path):
			base.texture = load(path)

func _redraw_all() -> void:
	if not is_inside_tree():
		return
	for n in find_children("*", "Node2D", true, false):
		n.queue_redraw()

## The layout as plain data, in the shapes the map view uses.
func data() -> Dictionary:
	var out := {"image": map_image, "blocks": {}, "streets": {}, "signs": {}, "pads": {}, "cottages": {}}
	for n in get_node("Blocks").get_children():
		out.blocks[String(n.name)] = Rect2(n.position, n.size)
	for n in get_node("Streets").get_children():
		out.streets[String(n.name)] = Rect2(n.position, n.size)
	for n in get_node("Signs").get_children():
		out.signs[String(n.name)] = n.position
	for n in get_node("Buildings").get_children():
		out.pads[String(n.name)] = [n.position.x, n.position.y, n.size.x, n.size.y, n.lot_art]
	for b in get_node("Cottages").get_children():
		out.cottages[String(b.name)] = b.get_children().map(func(c): return [c.position.x, c.position.y])
	return out

## Loads the saved layout scene once and returns its data.
static var _cached: Dictionary = {}
static func load_data(path: String = "res://ui/map_layout/map_layout.tscn") -> Dictionary:
	if not _cached.is_empty():
		return _cached
	var scene: PackedScene = load(path)
	var root = scene.instantiate()
	_cached = root.data()
	root.free()
	return _cached
