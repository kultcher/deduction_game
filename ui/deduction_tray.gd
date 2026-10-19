## The fold-up tray along the bottom of the case board that holds your deductions while
## they aren't pinned to the board. Folded, it shows a heading ("Deductions (3)") and the
## tops of the cards; click the heading to open it. Drag a card onto the board to pin it
## there, or onto the working set to use it; double-click to add it to the working set.
extends Control

signal card_activated(num)
signal card_context_requested(num, at)
signal toggled(open)

const UITheme = preload("res://ui/theme.gd")

const FOLDED_H = 46.0
const OPEN_H = 150.0
const CARD_W = 190.0
const CARD_H = 104.0

var g
var state
var open = false
var scroll = 0.0
var _rects: Array = []   # {rect, n}
var _font: Font
var _cards_tex: Array = []

func _init() -> void:
	custom_minimum_size = Vector2(0, FOLDED_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = " "
	_font = UITheme.serif()
	for i in range(1, 17):
		var t = UITheme.tex("ui/cards/card_%02d" % i, 0.6)
		if t != null:
			_cards_tex.append(t)

func setup(game, st) -> void:
	g = game
	state = st
	queue_redraw()

func deductions() -> Array:
	if g == null:
		return []
	return g.board.filter(func(c): return c.get("kind", "") == "deduction" and not c.get("deleted", false) and (g.show_hidden or not c.get("hidden", false)))

func set_open(v: bool) -> void:
	open = v
	custom_minimum_size = Vector2(0, OPEN_H if open else FOLDED_H)
	toggled.emit(open)
	queue_redraw()

func _draw() -> void:
	_rects = []
	var ds: Array = deductions()
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.color("panel"))
	draw_line(Vector2(0, 1), Vector2(size.x, 1), UITheme.color("border"), 2.0)
	var head = UITheme.nine("ui/tab_red", 30, [12, 10, 12, 6])
	var hr = Rect2(10, 4, 210, 28)
	if head != null:
		draw_style_box(head, hr)
	else:
		draw_rect(hr, UITheme.color("red"))
	draw_string(_font, hr.position + Vector2(14, 20), "Deductions (%d)  %s" % [ds.size(), "▼" if open else "▲"], HORIZONTAL_ALIGNMENT_LEFT, hr.size.x - 20, 14, UITheme.color("paper"))
	var view = state.view if state != null else "places"
	var x = 236.0 - scroll
	for c in ds:
		var r = Rect2(x, 10 if open else 18, CARD_W, CARD_H)
		x += CARD_W + 10
		if r.end.x < 0 or r.position.x > size.x:
			continue
		var pinned_here = c.get("pins", {}).has(view)
		var tint = Color(0.7, 0.7, 0.7) if pinned_here else Color.WHITE
		if not _cards_tex.is_empty():
			draw_texture_rect(_cards_tex[(c["n"] * 5) % _cards_tex.size()], r, false, tint)
		else:
			draw_rect(r, UITheme.color("paper") * tint)
		var seal = UITheme.tex("ui/wax_seal", 0.15)
		if seal != null:
			draw_texture(seal, r.position + Vector2(6, 6))
		draw_multiline_string(_font, r.position + Vector2(36, 22), c.get("text", "").trim_prefix("Deduction: "), HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 44, 12, 5 if open else 1, UITheme.color("red").darkened(0.3))
		if pinned_here:
			draw_string(_font, Vector2(r.position.x + 36, r.end.y - 10), "pinned", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.color("ink_soft"))
		if state != null and c["n"] == state.selected_card:
			draw_rect(r.grow(2), UITheme.color("string"), false, 2.0)
		_rects.append({"rect": r, "n": c["n"]})
	if ds.is_empty():
		draw_string(_font, Vector2(236, 26), "File a deduction and it will wait here until you pin it to the board.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 250, 13, UITheme.color("muted"))

func _hit(p: Vector2) -> int:
	for r in _rects:
		if r["rect"].has_point(p):
			return r["n"]
	return 0

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if Rect2(10, 4, 210, 28).has_point(ev.position):
				set_open(not open)
				return
			var n = _hit(ev.position)
			if n > 0:
				state.select_card(n)
				if ev.double_click:
					card_activated.emit(n)
				queue_redraw()
			elif not open:
				set_open(true)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			var n = _hit(ev.position)
			if n > 0:
				card_context_requested.emit(n, Vector2i(get_screen_transform() * ev.position))
				accept_event()
		elif ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var most = maxf(0.0, deductions().size() * (CARD_W + 10) + 246 - size.x)
			scroll = clampf(scroll + (-80.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 80.0), 0.0, most)
			queue_redraw()
			accept_event()

func _get_tooltip(at: Vector2) -> String:
	var n = _hit(at)
	if n == 0:
		return "Your deductions. Click to open; drag one onto the board to pin it." if Rect2(10, 4, 210, 28).has_point(at) else ""
	return g.board[n - 1].get("text", "") + "\n(drag onto the board to pin it; double-click to add to your working set; right-click for card actions)"

func _get_drag_data(at: Vector2):
	var n = _hit(at)
	if n == 0:
		return null
	var l = Label.new()
	l.text = "Deduction #%d" % n
	l.add_theme_color_override("font_color", UITheme.color("ink"))
	var pc = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("paper"), UITheme.color("red"), 2, 3, 6))
	pc.add_child(l)
	set_drag_preview(pc)
	return {"pin": n, "cards": [n]}
