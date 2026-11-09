@tool
## A building's lot on the map layout: the node sits at the lot's centre; `size` is the lot.
## The node's name is the place (tavern, smithy, ...).
extends Node2D
const Geo = preload("res://ui/map_layout/map_geometry.gd")

@export var size: Vector2 = Vector2(200, 100):
	set(v):
		size = v
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()   # the roof clamp near the map's top edge depends on where the lot is

func _ready() -> void:
	set_notify_transform(true)
## The lot art under the building, relative to res://assets/art/ (empty: none drawn).
@export var lot_art: String = "":
	set(v):
		lot_art = v
		queue_redraw()

func _draw() -> void:
	if not Geo.previewing():
		return
	var root = owner if owner != null else get_parent()
	# The geometry needs the real position (roofs near the top edge are kept on the map).
	var pad := [position.x, position.y, size.x, size.y, lot_art]
	var lot := Rect2(-size / 2.0, size)
	if lot_art != "" and root.get("show_art"):
		var t = Geo.art(lot_art, 0.5)
		if t != null:
			draw_texture_rect(t, lot, false)
	var art = Geo.art("buildings_paper/" + String(name), 0.5) if root.get("show_art") else null
	if art != null:
		var box: Rect2 = Geo.building_art_box(pad)
		box.position -= position
		draw_texture_rect(art, Geo.contain(art, box), false)
	draw_rect(lot, Color(1, 0.55, 0.1, 0.9), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-size.x / 2.0 + 4, -size.y / 2.0 - 4), String(name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.6, 0.2))
