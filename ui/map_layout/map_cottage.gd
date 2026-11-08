@tool
## A cottage spot on the map layout: the node sits at the centre of the cottage's lot. Spots
## fill in child order, one per resident of the block.
extends Node2D
const Geo = preload("res://ui/map_layout/map_geometry.gd")

## Which townsperson's cottage to show in the editor preview (art only; who lives where is
## dealt each case).
@export var preview_cottage: String = "agnes":
	set(v):
		preview_cottage = v
		queue_redraw()

func _draw() -> void:
	if not Geo.previewing():
		return
	var root = owner if owner != null else get_parent().get_parent()
	if root.get("show_art"):
		var lot = Geo.art("terrain/dirt_c", 0.3)
		if lot != null:
			draw_texture_rect(lot, Geo.cottage_lot(Vector2.ZERO), false)
		var art = Geo.art("cottages_poc/%s-cottage-papercraft-v1" % preview_cottage, 0.25)
		if art != null:
			draw_texture_rect(art, Geo.contain(art, Geo.cottage_art_box(Vector2.ZERO)), false)
	draw_rect(Geo.cottage_box(Vector2.ZERO), Color(0.3, 0.8, 1.0, 0.9), false, 2.0)
	draw_circle(Vector2.ZERO, 4, Color(0.3, 0.8, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(-36, 40), "%s %d" % [get_parent().name, get_index() + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 0.8, 1.0))
