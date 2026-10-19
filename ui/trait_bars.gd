## Known social traits use their continuous scores, filled from the midpoint toward
## their value. Unlearned traits remain an empty track with a question mark.
extends Control

const UITheme = preload("res://ui/theme.gd")

## [trait, label, left extreme (0), right extreme (1), colour]
const ROWS = [
	["privacy", "Privacy", "Open Book", "Secretive", Color(0.86, 0.2, 0.2)],
	["gossip", "Gossip", "Discreet", "Busybody", Color(0.27, 0.32, 0.8)],
	["confidence", "Confidence", "Pliable", "Unwavering", Color(0.16, 0.6, 0.3)],
	["composure", "Composure", "Skittish", "Coolheaded", Color(0.93, 0.5, 0.15)],
	["insight", "Insight", "Uncritical", "Discerning", Color(0.1, 0.6, 0.85)],
]
const ROW_H = 36.0

var revealed = {}   # learned trait -> score in [0, 1]

func _init() -> void:
	custom_minimum_size = Vector2(0, ROW_H * ROWS.size() + 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_traits(t: Dictionary) -> void:
	revealed = t.duplicate()
	queue_redraw()

static func fill_rect(track: Rect2, value: float) -> Rect2:
	var middle = track.get_center().x
	var endpoint = track.position.x + track.size.x * clampf(value, 0.0, 1.0)
	if is_equal_approx(endpoint, middle):
		return Rect2(middle - 1, track.position.y, 2, track.size.y)
	return Rect2(minf(middle, endpoint), track.position.y, absf(endpoint - middle), track.size.y)

func _draw() -> void:
	var font = UITheme.serif()
	var fs = 13
	var side_w = 92.0
	var soft: Color = UITheme.color("ink_soft")
	for i in range(ROWS.size()):
		var r: Array = ROWS[i]
		var y0 = i * ROW_H
		var col: Color = r[4]
		# The name, centred over the bar.
		draw_string(font, Vector2(side_w, y0 + 12), r[1], HORIZONTAL_ALIGNMENT_CENTER, size.x - 2 * side_w, fs, col.darkened(0.15))
		var bar = Rect2(side_w, y0 + 16, size.x - 2 * side_w, 14)
		draw_string(font, Vector2(0, bar.position.y + 12), r[2], HORIZONTAL_ALIGNMENT_RIGHT, side_w - 8, fs, soft)
		draw_string(font, Vector2(bar.end.x + 8, bar.position.y + 12), r[3], HORIZONTAL_ALIGNMENT_LEFT, side_w - 8, fs, soft)
		draw_rect(bar, Color(1, 1, 1, 0.55))
		var value = revealed.get(r[0])
		if value is float or value is int:
			var inside = bar.grow(-2)
			draw_rect(fill_rect(inside, value), col)
			draw_line(Vector2(inside.get_center().x, inside.position.y), Vector2(inside.get_center().x, inside.end.y), col.darkened(0.25), 1)
		else:
			draw_string(font, Vector2(bar.position.x, bar.position.y + 12), "?", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, fs, soft)
		draw_rect(bar, col, false, 2.0)
