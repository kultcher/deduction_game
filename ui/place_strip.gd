## A person's three places for container layouts (the profile header): workplace and two
## haunts as icons (ui/place_icons.gd), with a caption under each.
extends Control

const UITheme = preload("res://ui/theme.gd")
const PlaceIconsRef = preload("res://ui/place_icons.gd")

var g
var n
var side: float = 38.0
var gap: float = 10.0
var _font: Font

func _init() -> void:
	_font = UITheme.serif()
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = " "
	custom_minimum_size = Vector2(3 * side + 2 * gap, side + 16)

func show_person(game, person) -> void:
	g = game
	n = person
	queue_redraw()

func _draw() -> void:
	if n == null:
		return
	var sl: Array = PlaceIconsRef.slots(g, n)
	var ink: Color = UITheme.color("ink_soft")
	PlaceIconsRef.draw_slots(self, _font, Vector2.ZERO, side, gap, sl, ink, not n.alive)
	for i in range(sl.size()):
		var cap: String = "Works" if sl[i].kind == "work" else "Haunt"
		draw_string(_font, Vector2(i * (side + gap) - 6, side + 13), cap, HORIZONTAL_ALIGNMENT_CENTER, side + 12, 11, ink)

func _get_tooltip(_at: Vector2) -> String:
	return PlaceIconsRef.tooltip(g, n) if n != null else ""
