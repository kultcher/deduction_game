## The town meeting, shown in place of the map while the town meets. The living townsfolk
## stand in a ring (you at the bottom), the nominee's portrait is in the middle, and when
## a vote is taken a hand sweeps clockwise from the seat after the nominee (BotC order; the
## nominee votes last), counting each vote as it passes. Those voting to execute step in;
## those against pull back. Click anywhere to finish the count at once; click a person to
## show them in the profile.
extends Control

signal person_clicked(id)

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")

const STEP = 0.5          # seconds per seat as the hand goes round
const IN = 0.24           # how far a yes voter steps in (fraction of the ring radius)
const OUT = 0.1           # how far a no voter pulls back

var g
var _res: Dictionary = {}    # the vote being shown (or last shown)
var _seen_results = 0
var _pending_key = ""
var _vote_hint = ""   # captured before the count: never infer it from the final result
var _t = -1.0                # hand position in seats along the order; -1 = idle
var _counted = 0             # how many seats along the order have been counted
var _offset = {}             # id -> current step (-1 back .. +1 in)
var _target = {}
var _hits: Array = []        # {rect, id}
var _font: Font

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = UITheme.serif()

func set_game(game) -> void:
	g = game
	_res = {}
	_seen_results = 0
	_pending_key = ""
	_vote_hint = ""
	_t = -1.0
	_counted = 0
	_offset = {}
	_target = {}
	set_process(false)
	queue_redraw()

func animating() -> bool:
	return _t >= 0.0

## Called after every command: start counting a new vote, or reset for a new nomination.
func refresh() -> void:
	if g == null:
		return
	var m: Dictionary = g.w.meeting
	var results: Array = m.get("results", [])
	if results.size() < _seen_results:
		_seen_results = 0  # a new meeting
		_res = {}
		_reset_steps()
	var pend: Dictionary = m.get("pending", {})
	var pk = "" if pend.is_empty() else "%s>%s" % [pend.get("by", ""), pend.get("nominee", "")]
	if pk != "" and pk != _pending_key:
		_vote_hint = g.vote_requirement_text()
		_res = {}
		_reset_steps()
		_t = -1.0
	_pending_key = pk
	if results.size() > _seen_results:
		_seen_results = results.size()
		_start(results.back())
	queue_redraw()

func finish() -> void:
	if not animating():
		return
	while _counted < _res["order"].size():
		_count_next()
	for id in _target:
		_offset[id] = _target[id]
	_t = -1.0
	set_process(false)
	queue_redraw()

func _reset_steps() -> void:
	_offset = {}
	_target = {}
	_counted = 0

func _start(res: Dictionary) -> void:
	_res = res
	_reset_steps()
	if not res.has("order"):
		return
	_t = 0.0
	set_process(true)

func _count_next() -> void:
	var id: String = _res["order"][_counted]
	_counted += 1
	var yes = _res["player_yes"] if id == "player" else id in _res["yes"]
	_target[id] = 1.0 if yes else -1.0

func _process(delta: float) -> void:
	if animating():
		_t += delta / STEP
		while _counted < _res["order"].size() and _t >= _counted:
			_count_next()
		if _t >= _res["order"].size() + 0.6:
			_t = -1.0
	var moving = false
	for id in _target:
		var cur: float = _offset.get(id, 0.0)
		var nxt = move_toward(cur, _target[id], delta * 4.0)
		_offset[id] = nxt
		moving = moving or not is_equal_approx(nxt, _target[id])
	if not animating() and not moving:
		set_process(false)
	queue_redraw()

# ---------------------------------------------------------------- geometry

func _seats() -> Array:
	return g.w.seats()  # nobody dies mid-meeting, so the ring holds still through a count

func _center() -> Vector2:
	return Vector2(size.x / 2.0, size.y * 0.52)

func _radii() -> Vector2:
	return Vector2(size.x * 0.4, size.y * 0.31)

func _angle_of(i: int, n: int) -> float:
	return PI / 2.0 + i * TAU / float(n)  # seat 0 (you) at the bottom; clockwise on screen

func _seat_pos(i: int, n: int, step: float) -> Vector2:
	var a = _angle_of(i, n)
	var k = 1.0 - IN * step if step > 0 else 1.0 - OUT * step
	return _center() + Vector2(cos(a), sin(a)) * _radii() * k

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_hits = []
	if g == null:
		return
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, UITheme.color("bg"))
	var bgt = UITheme.tex("art/blocks/square", 0.5)
	if bgt != null:
		var ts = Vector2(bgt.get_width(), bgt.get_height())
		var k = maxf(size.x / ts.x, size.y / ts.y)
		var src = size / k
		draw_texture_rect_region(bgt, rect, Rect2((ts - src) / 2.0, src), Color(0.62, 0.55, 0.5))
	draw_rect(rect, Color(0.35, 0.15, 0.05, 0.18))  # evening light
	var c = _center()
	var rad = _radii()
	# The ring on the ground.
	_ellipse(c, rad, Color(0.95, 0.85, 0.6, 0.35), 3.0)
	_ellipse(c, rad * (1.0 - IN), Color(0.62, 0.2, 0.17, 0.25), 2.0)
	var seats: Array = _seats()
	var n = seats.size()
	var pend: Dictionary = g.w.meeting.get("pending", {})
	var nominee: String = pend.get("nominee", _res.get("nominee", ""))
	var nominator: String = pend.get("by", _res.get("by", ""))
	# The hand.
	if animating() and _res.has("order"):
		var start = seats.find(_res["order"][0])
		var a = _angle_of(start, n) + clampf(_t, 0.0, n - 1.0) * TAU / float(n)
		_draw_hand(c, a, rad)
	# Standees, back to front.
	var order: Array = []
	for i in range(n):
		var id: String = seats[i]
		order.append({"i": i, "id": id, "pos": _seat_pos(i, n, _offset.get(id, 0.0) * (0.45 if id == "player" else 1.0))})
	order.sort_custom(func(x, y): return x["pos"].y < y["pos"].y)
	var h = clampf(size.y * 0.22, 60.0, 150.0) * minf(1.0, 8.0 / float(n))  # a bigger ring stands closer
	for e in order:
		_draw_person(e["id"], e["pos"], h, e["id"] == nominee, e["id"] == nominator)
	# The nominee in the middle.
	_draw_center(c, nominee, nominator)
	_draw_tally()

func _ellipse(c: Vector2, r: Vector2, col: Color, w: float) -> void:
	var pts = PackedVector2Array()
	for k in range(65):
		var a = k * TAU / 64.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, w, true)

func _draw_hand(c: Vector2, a: float, rad: Vector2) -> void:
	var d = Vector2(cos(a), sin(a))
	var r0 = c + d * rad * 0.42
	var r1 = c + d * rad * 0.66
	var side = Vector2(-d.y, d.x)
	var gold = UITheme.color("border")
	draw_line(r0, r1 - d * 10, Color(0.1, 0.07, 0.04, 0.8), 7.0)
	draw_line(r0, r1 - d * 10, gold, 4.0)
	var tip = PackedVector2Array([r1 + d * 8, r1 - d * 12 + side * 11, r1 - d * 12 - side * 11])
	draw_colored_polygon(tip, gold)
	draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[0]]), Color(0.1, 0.07, 0.04, 0.9), 2.0)

func _draw_person(id: String, foot: Vector2, h: float, is_nominee: bool, is_nominator: bool) -> void:
	var step: float = _offset.get(id, 0.0)
	var counted = _target.has(id)
	var yes = counted and _target[id] > 0
	var fs = int(clampf(h * 0.15, 13, 19))
	if id == "player":
		# Your seat: a candle and a plaque.
		var ct = UITheme.tex("ui/candle", 0.25)
		var cr = Rect2(foot - Vector2(h * 0.2, h * 0.55), Vector2(h * 0.4, h * 0.55))
		draw_circle(foot, h * 0.22, Color(0, 0, 0, 0.3))
		if ct != null:
			var ts = Vector2(ct.get_width(), ct.get_height())
			var k = minf(cr.size.x / ts.x, cr.size.y / ts.y)
			draw_texture_rect(ct, Rect2(Vector2(foot.x - ts.x * k / 2.0, foot.y - ts.y * k), ts * k), false)
		_label(foot + Vector2(0, fs + 4), "You", fs, yes and counted, counted and not yes)
		if yes:
			_token(foot + Vector2(h * 0.38, -h * 0.25), _yes_number(id), fs)  # beside the candle, clear of the nominee
		_hits.append({"rect": cr, "id": ""})
		return
	var n = g.w.by_id[id]
	var t = UITheme.tex("art/standees/" + id, 0.3)
	var rr = Rect2(foot - Vector2(h * 0.4, h), Vector2(h * 0.8, h))
	draw_circle(foot + Vector2(0, -2), h * 0.26, Color(0, 0, 0, 0.35))
	var tint = Color.WHITE if (not counted or yes) else Color(0.8, 0.78, 0.78)
	if t != null:
		var ts = Vector2(t.get_width(), t.get_height())
		var k = minf(rr.size.x / ts.x, rr.size.y / ts.y)
		var sz = ts * k
		rr = Rect2(Vector2(foot.x - sz.x / 2.0, foot.y - sz.y), sz)
		draw_texture_rect(t, rr, false, tint)
	else:
		draw_circle(rr.get_center(), h * 0.3, C.npc_color(id))
	if is_nominee:
		draw_rect(rr.grow(4), UITheme.color("red"), false, 3.0)
	elif is_nominator:
		draw_rect(rr.grow(3), UITheme.color("accent"), false, 2.0)
	_label(foot + Vector2(0, fs + 4), n.name, fs, yes, counted and not yes, C.npc_color(id))
	if yes:
		_token(rr.position + Vector2(rr.size.x / 2.0, -fs * 0.6), _yes_number(id), fs)
	_hits.append({"rect": rr, "id": id})

## The order in which a yes vote was counted (1, 2, 3 ...), as BotC tallies go.
func _yes_number(id: String) -> int:
	var k = 0
	for j in range(_counted):
		var o: String = _res["order"][j]
		if (o == "player" and _res["player_yes"]) or o in _res["yes"]:
			k += 1
		if o == id:
			return k
	return k

func _token(c: Vector2, num: int, fs: int) -> void:
	var r = fs * 0.85
	draw_circle(c, r, UITheme.color("red"))
	draw_arc(c, r, 0, TAU, 24, UITheme.color("border"), 2.0)
	draw_string(_font, Vector2(c.x - r, c.y + fs * 0.35), str(num), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, UITheme.color("paper"))

func _label(c: Vector2, text: String, fs: int, yes: bool, no: bool, col: Color = Color.WHITE) -> void:
	var w = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 1.2
	var hgt = fs * 1.6
	var r = Rect2(c - Vector2(w / 2.0, hgt * 0.75), Vector2(w, hgt))
	var plaque = UITheme.nine("ui/plaque_red" if yes else ("ui/plaque_grey" if no else "ui/plaque_cream"), hgt, [hgt * 0.3, hgt * 0.25, hgt * 0.3, hgt * 0.25])
	if plaque != null:
		draw_style_box(plaque, r)
	else:
		draw_rect(r, UITheme.color("paper"))
	var ink = UITheme.color("paper") if yes else (UITheme.color("ink_soft") if no else UITheme.ink_of(col))
	draw_string(_font, Vector2(r.position.x, r.position.y + hgt * 0.7), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, ink)

func _draw_center(c: Vector2, nominee: String, nominator: String) -> void:
	var rad = clampf(size.y * 0.12, 36.0, 90.0)
	var fs = int(clampf(rad * 0.3, 14, 22))
	if nominee == "":
		var blk: String = g.w.meeting.get("block", "")
		var msg = "The town meets" if blk == "" else "%s is on the block" % g.w.by_id[blk].name
		_label(c, msg, fs + 2, blk != "", false)
		return
	var nn = g.w.by_id[nominee]
	draw_circle(c, rad + 6, Color(0, 0, 0, 0.35))
	draw_circle(c, rad, C.npc_color(nominee).darkened(0.35))
	var tex = UITheme.tex("art/portraits/" + nominee, 0.3)
	if tex != null:
		# Clip the portrait to a circle. A square crop pokes through the ring's corners.
		var portrait_radius = rad - 4.0
		var src_h = minf(tex.get_height(), tex.get_width())
		var points = PackedVector2Array()
		var uvs = PackedVector2Array()
		for i in range(64):
			var direction = Vector2.from_angle(i * TAU / 64.0)
			points.append(c + direction * portrait_radius)
			uvs.append(Vector2((direction.x + 1.0) * 0.5, (direction.y + 1.0) * 0.5 * src_h / tex.get_height()))
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, tex)
	var ring = UITheme.tex("ui/ring_gold", 0.4)
	if ring != null:
		draw_texture_rect(ring, Rect2(c - Vector2(rad, rad) * 1.08, Vector2(rad, rad) * 2.16), false)
	else:
		draw_arc(c, rad, 0, TAU, 48, UITheme.color("border"), 3.0)
	_label(c + Vector2(0, rad + fs + 6), nn.name, fs, true, false)
	var by = "you" if nominator == "player" else (g.w.by_id[nominator].name if g.w.by_id.has(nominator) else "")
	if by != "":
		_label(c - Vector2(0, rad + fs * 0.6), "nominated by " + by, int(fs * 0.8), false, false)

func _draw_tally() -> void:
	var m: Dictionary = g.w.meeting
	var fs = 17
	var lines: Array = []
	if not _res.is_empty() and _res.has("order"):
		var count = 0
		for j in range(_counted):
			var o: String = _res["order"][j]
			if (o == "player" and _res["player_yes"]) or o in _res["yes"]:
				count += 1
		lines.append("Votes to execute: %d" % count)
		lines.append(_vote_hint if _vote_hint != "" else "Minimum votes: %d" % _res["threshold"])
		if not animating():
			lines.append({"on_block": "%s goes on the block." % g.w.by_id[_res["nominee"]].name,
				"tie": "A tie with the block: nobody is on the block.",
				"short_of_block": "Not enough to take the block.",
				"fails": "The nomination fails."}.get(_res["outcome"], ""))
		else:
			lines.append("Counting... (click to finish)")
	else:
		lines.append(g.vote_requirement_text())
	var blk: String = m.get("block", "")
	if animating():
		pass  # don't give the count away before the hand gets there
	elif blk != "":
		lines.append("On the block: %s (%d)" % [g.w.by_id[blk].name, m.get("block_count", 0)])
	elif m.get("block_count", 0) > 0:
		lines.append("Block empty after a tie at %d" % m["block_count"])
	# Wrap explanatory counts inside the panel instead of clipping a long one-line strip.
	var txt = "\n".join(PackedStringArray(lines.filter(func(x): return x != "")))
	var width = maxf(1.0, size.x - 44.0)
	var height = _font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, width, fs).y
	var r = Rect2(14, size.y - height - 18, width + 16, height + 12)
	draw_rect(r, Color(0.07, 0.09, 0.14, 0.85))
	draw_rect(r, UITheme.color("border").darkened(0.2), false, 1.0)
	draw_multiline_string(_font, r.position + Vector2(8, fs + 6), txt, HORIZONTAL_ALIGNMENT_CENTER, width, fs, -1, UITheme.color("accent"))

# ---------------------------------------------------------------- input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if animating():
			finish()
			accept_event()
			return
		for i in range(_hits.size() - 1, -1, -1):
			var hit = _hits[i]
			if hit["id"] != "" and hit["rect"].has_point(ev.position):
				person_clicked.emit(hit["id"])
				accept_event()
				return
