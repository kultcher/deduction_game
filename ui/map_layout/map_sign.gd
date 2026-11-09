@tool
## A block's name plaque on the map layout: the plaque is centred a little below this point.
extends Node2D
const Geo = preload("res://ui/map_layout/map_geometry.gd")

func _draw() -> void:
	if not Geo.previewing():
		return
	var text := String(name).capitalize()
	var font := ThemeDB.fallback_font
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 24
	var r := Rect2(Vector2(-w / 2.0, 6), Vector2(w, 34))
	draw_rect(r, Color(0.94, 0.89, 0.77, 0.85))
	draw_rect(r, Color(0.78, 0.6, 0.27), false, 2.0)
	draw_string(font, Vector2(r.position.x, r.position.y + 25), text, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(0.17, 0.13, 0.09))
	draw_circle(Vector2.ZERO, 5, Color(1, 0.3, 0.8))
