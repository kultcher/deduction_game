## The five social traits as bars: the trait's name above, the two extremes either side,
## and the band you've read them at (low / mid / high) filled in. Unknown traits show an
## empty bar with a "?". Bands, not exact values: a reveal says "fairly private", not 0.83.
extends Control

const UITheme = preload("res://ui/theme.gd")

## [trait, label, left extreme, right extreme, colour, high trait value sits on the right?]
const ROWS = [
	["privacy", "Privacy", "Secretive", "Open Book", Color(0.86, 0.2, 0.2), false],
	["gossip", "Gossip", "Discreet", "Busybody", Color(0.27, 0.32, 0.8), true],
	["confidence", "Confidence", "Pliable", "Unwavering", Color(0.16, 0.6, 0.3), true],
	["composure", "Composure", "Skittish", "Coolheaded", Color(0.93, 0.5, 0.15), true],
	["insight", "Insight", "Uncritical", "Discerning", Color(0.1, 0.6, 0.85), true],
]
const ROW_H = 36.0

var revealed = {}   # trait -> "low" | "mid" | "high"

func _init() -> void:
	custom_minimum_size = Vector2(0, ROW_H * ROWS.size() + 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_traits(t: Dictionary) -> void:
	revealed = t.duplicate()
	queue_redraw()

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
		var tier: String = revealed.get(r[0], "")
		if tier in ["low", "mid", "high"]:
			var k = ["low", "mid", "high"].find(tier)
			if not r[5]:
				k = 2 - k
			var band = Rect2(bar.position.x + bar.size.x * k / 3.0, bar.position.y, bar.size.x / 3.0, bar.size.y)
			draw_rect(band, col)
		else:
			draw_string(font, Vector2(bar.position.x, bar.position.y + 12), "?", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, fs, soft)
		draw_rect(bar, col, false, 2.0)
