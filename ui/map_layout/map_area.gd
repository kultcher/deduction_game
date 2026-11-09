@tool
## A rectangle on the map layout (a block's area, or a block's street): the node sits at the
## top-left corner; `size` is the rectangle.
extends Node2D
const Geo = preload("res://ui/map_layout/map_geometry.gd")

@export var size: Vector2 = Vector2(200, 100):
	set(v):
		size = v
		queue_redraw()
@export var color: Color = Color(1, 1, 0.3, 0.8):
	set(v):
		color = v
		queue_redraw()

func _draw() -> void:
	if not Geo.previewing():
		return
	var root = owner if owner != null else get_parent().get_parent()
	if root != null and not root.get("show_areas"):
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(color, 0.08))
	draw_rect(Rect2(Vector2.ZERO, size), color, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, 16), "%s: %s" % [get_parent().name, name], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
