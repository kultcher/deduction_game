## A painted X over a portrait: the red X of a night kill and the blue X of an execution
## (Michael, Nov 22). Each stroke draws on with its own progress, so the X can be slashed in
## one stroke after the other. Presentation only; nothing per frame beyond a redraw.
extends Control

var color: Color = Color(0.78, 0.07, 0.06)
## How much of each stroke is drawn, 0 to 1.
var p1: float = 1.0
var p2: float = 1.0
## Stroke width as a share of the mark's size.
var width_frac: float = 0.15

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_progress(a: float, b: float) -> void:
	if not is_equal_approx(a, p1) or not is_equal_approx(b, p2):
		p1 = a
		p2 = b
		queue_redraw()

func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size / 2.0
	var h: float = s * 0.36
	var w: float = s * width_frac
	_stroke(c + Vector2(-h, -h), c + Vector2(h, h), p1, w)
	_stroke(c + Vector2(h, -h), c + Vector2(-h, h), p2, w)

func _stroke(a: Vector2, b: Vector2, p: float, w: float) -> void:
	if p <= 0.0:
		return
	var e: Vector2 = a.lerp(b, clampf(p, 0.0, 1.0))
	var drop: Vector2 = Vector2(w * 0.12, w * 0.18)
	_line(a + drop, e + drop, Color(0, 0, 0, 0.35 * color.a), w)
	_line(a, e, Color(color.darkened(0.45), color.a), w + maxf(3.0, w * 0.18))
	_line(a, e, color, w)
	# A paler streak down the stroke, so it reads as paint rather than a flat bar.
	var n: Vector2 = (b - a).normalized().orthogonal() * w * 0.18
	_line(a - n, e - n, Color(color.lightened(0.3), color.a * 0.6), w * 0.22)

func _line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, col, w)
	draw_circle(a, w / 2.0, col)
	draw_circle(b, w / 2.0, col)
