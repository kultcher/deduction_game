## The case board: one view (Places & sightings, Statements or Process) laid out as rows
## (people or places) against time, drawn with _draw(). Pan by dragging the background,
## zoom with the wheel; three levels of detail (dots and chips, one-line cards, full text).
## Hover or click a card to see its strings: who said it, whom it's about, what a
## deduction rests on. Cards can be dragged out (to the working set); deductions dragged in
## from the tray are pinned where they're dropped.
##
## Reads the layout from BoardModel and the filters from the shared CaseState, so the board
## always shows what the card list shows.
extends Control

signal card_activated(num)          # double-click: add to the working set
signal row_clicked(kind, id)        # a row label: person | place
signal view_changed                # pan/zoom or the initial fit changed
signal person_context_requested(id) # right-click a person's row label
signal card_context_requested(num, at)

const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")
const BoardModel = preload("res://game/board_model.gd")
const UITheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/board_icons.gd")
const EvidenceContext = preload("res://ui/evidence_context.gd")

const HEAD_W = 132.0     # row labels (screen pixels, not zoomed)
const HEAD_H = 34.0      # time labels
const COL_W = 176.0      # world units
const CARD_W = 158.0
const CARD_H = 58.0
const GAP = 7.0
const DOT = 30.0
const ROW_PAD = 10.0
const MIN_ROW = 46.0
const MIN_ROW_SCREEN = 30.0  # rows never get thinner than this on screen, so labels stay readable
const ZOOM_MIN = 0.25
const ZOOM_MAX = 2.6

var g
var state
var lay: Dictionary = {}
var zoom = 1.0
var pan = Vector2.ZERO           # world point shown at the content area's top-left
var row_y = {}                   # row id -> world y
var row_h = {}                   # row id -> world height
var col_x = {}                   # col key -> world x
var world_size = Vector2.ZERO
var _items: Array = []           # drawn items: {rect (screen), n, item index, pinned}
var _row_hits: Array = []        # {rect, row}
var context_numbers: Dictionary = {}
var _hover = 0                   # card number under the mouse
var _panning = false
var _moving_pin = 0
var _press_pos = Vector2.ZERO
var _font: Font
var _ink: Color
var _cards_tex: Array = []
var _role_tex = {}
var _fitted = false
var _fit_pending = false

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	tooltip_text = " "   # non-empty so _get_tooltip is asked
	_font = UITheme.serif()
	_ink = UITheme.color("ink")
	for i in range(1, 17):
		var t = UITheme.tex("ui/cards/card_%02d" % i, 0.5)
		if t != null:
			_cards_tex.append(t)

func setup(game, st) -> void:
	g = game
	state = st
	_fitted = false
	rebuild()

func board_view() -> String:
	return state.view if state.view in CardModel.VIEWS else "places"

## Recompute the layout from the current filters (call when cards, view or filters change).
func rebuild() -> void:
	if g == null:
		return
	context_numbers = EvidenceContext.numbers(g)
	var cards: Array = state.apply(g)
	cards += g.board.filter(func(c): return c.get("kind", "") == "deduction" and not c.get("deleted", false) and (g.show_hidden or not c.get("hidden", false)) and c.get("pins", {}).has(board_view()))
	var ctx = {"day": g.w.day, "phase": g._phase_now(), "rows_by": state.rows_by,
		"people": g.w.npcs.map(func(n): return {"id": n.id, "name": n.name, "alive": n.alive}),
		"blocks": C.BLOCKS.keys(), "selected_people": state.people.keys(),
		"selected_blocks": state.places.keys().map(func(key): return key if C.BLOCKS.has(key) else g.w.loc_block(key))}
	lay = BoardModel.layout(cards, board_view(), ctx)
	_measure()
	_schedule_initial_fit()
	queue_redraw()

func _schedule_initial_fit() -> void:
	if g == null or _fitted or _fit_pending or not is_visible_in_tree():
		return
	_fit_pending = true
	_fit_after_layout.call_deferred()

func _fit_after_layout() -> void:
	await get_tree().process_frame
	_fit_pending = false
	if g != null and not _fitted and is_visible_in_tree() and size.x > HEAD_W:
		fit_day(g.w.day)

## Row heights grow with the busiest cell; places rows hold dots, others hold cards.
func _measure() -> void:
	row_y.clear()
	row_h.clear()
	col_x.clear()
	var x = 0.0
	for c in lay["cols"]:
		col_x[c["key"]] = x
		x += COL_W
	var per_line = maxi(1, int((COL_W - 8.0) / (DOT + 6.0)))
	var y = 0.0
	for r in lay["rows"]:
		var most = 0
		for c in lay["cols"]:
			most = maxi(most, lay["cells"].get("%s|%s" % [r["id"], c["key"]], []).size())
		var h = maxf(MIN_ROW, MIN_ROW_SCREEN / zoom)
		if lay["view"] == "places":
			h = maxf(h, ceil(float(most) / per_line) * (DOT + 18.0) + ROW_PAD)
		else:
			h = maxf(h, most * (CARD_H + GAP) + ROW_PAD)
		row_y[r["id"]] = y
		row_h[r["id"]] = h
		y += h
	world_size = Vector2(x, y)

# ---------------------------------------------------------------- navigation

func _content_rect() -> Rect2:
	return Rect2(Vector2(HEAD_W, HEAD_H), size - Vector2(HEAD_W, HEAD_H))

func to_screen(p: Vector2) -> Vector2:
	return Vector2(HEAD_W, HEAD_H) + (p - pan) * zoom

func to_world(s: Vector2) -> Vector2:
	return (s - Vector2(HEAD_W, HEAD_H)) / zoom + pan

func _clamp_pan() -> void:
	var view = _content_rect().size / zoom
	pan.x = clampf(pan.x, -view.x * 0.5, maxf(0.0, world_size.x - view.x * 0.5))
	pan.y = clampf(pan.y, -view.y * 0.25, maxf(0.0, world_size.y - view.y * 0.5))

func zoom_at(screen: Vector2, factor: float) -> void:
	_fitted = true
	var before = to_world(screen)
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_measure()
	pan = before - (screen - Vector2(HEAD_W, HEAD_H)) / zoom
	_clamp_pan()
	queue_redraw()
	view_changed.emit()

## Show a day's four time slots (morning to night) across the board.
func fit_day(d: int) -> void:
	_fitted = true
	# A day, with the night before it (where last night's readings and sightings sit).
	var keys: Array = lay.get("cols", []).filter(func(c): return c["day"] == d or (c["day"] == d - 1 and c["phase"] == C.NIGHT)).map(func(c): return c["key"])
	if keys.is_empty():
		fit_all()
		return
	var x0: float = col_x[keys[0]]
	var span = COL_W * maxf(5.0, keys.size())
	var cr = _content_rect()
	zoom = clampf(cr.size.x / (span + 20.0), ZOOM_MIN, ZOOM_MAX)
	_measure()
	pan = Vector2(x0 - 10.0, 0)
	_clamp_pan()
	queue_redraw()
	view_changed.emit()

func fit_all() -> void:
	_fitted = true
	var cr = _content_rect()
	if world_size.x <= 0:
		return
	zoom = clampf(minf(cr.size.x / (world_size.x + 20.0), cr.size.y / (world_size.y + 20.0)), ZOOM_MIN, ZOOM_MAX)
	_measure()
	zoom = clampf(minf(cr.size.x / (world_size.x + 20.0), cr.size.y / (world_size.y + 20.0)), ZOOM_MIN, ZOOM_MAX)
	_measure()
	pan = Vector2(-10, -10)
	queue_redraw()
	view_changed.emit()

## Fit the selected card (all its places on the board).
func fit_selection() -> void:
	_fitted = true
	var n: int = state.selected_card
	var pts: Array = []
	for it in lay.get("items", []):
		if it["card"] == n:
			pts.append(Vector2(col_x.get(it["col"], 0.0), row_y.get(it["row"], 0.0)))
	if pts.is_empty():
		return
	var r = Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	r = r.grow(COL_W * 0.6)
	var cr = _content_rect()
	zoom = clampf(minf(cr.size.x / r.size.x, cr.size.y / maxf(r.size.y, 1.0)), ZOOM_MIN, 1.6)
	_measure()
	pan = r.position
	queue_redraw()
	view_changed.emit()

## The day whose columns are mostly in view.
func day_in_view() -> int:
	var mid = to_world(_content_rect().get_center()).x
	for c in lay.get("cols", []):
		if col_x[c["key"]] <= mid and mid < col_x[c["key"]] + COL_W:
			return c["day"]
	return g.w.day if g != null else 1

# ---------------------------------------------------------------- drawing

func _lod() -> int:
	return 0 if zoom < 0.55 else (1 if zoom < 1.3 else 2)

func _draw() -> void:
	_items = []
	_row_hits = []
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.color("bg"))
	if lay.is_empty():
		return
	var cr = _content_rect()
	# Related day tints, darker nights, and clear boundaries for every timeframe.
	for r in lay["rows"]:
		var y0 = to_screen(Vector2(0, row_y[r["id"]])).y
		var hh = row_h[r["id"]] * zoom
		if y0 + hh < cr.position.y or y0 > size.y:
			continue
		if lay["rows"].find(r) % 2 == 1:
			draw_rect(Rect2(cr.position.x, y0, cr.size.x, hh), UITheme.color("panel_alt"))
		if state.selected_person == r["id"] or (state.people.has(r["id"]) or state.places.has(r["id"])):
			draw_rect(Rect2(cr.position.x, y0, cr.size.x, hh), Color(0.95, 0.83, 0.52, 0.06))
	for c in lay["cols"]:
		var x0 = to_screen(Vector2(col_x[c["key"]], 0)).x
		var w = COL_W * zoom
		if x0 + w < cr.position.x or x0 > size.x:
			continue
		draw_rect(Rect2(x0, cr.position.y, w, cr.size.y), Icons.phase_shade(c["phase"]))
		var day_start = c["phase"] == C.MORNING or c["key"] == lay["cols"][0]["key"]
		draw_line(Vector2(x0, cr.position.y), Vector2(x0, size.y), UITheme.color("border").darkened(0.2) if day_start else Color(0.67, 0.64, 0.56, 0.42), 2.0 if day_start else 1.2)
		if c["key"] == lay["cols"].back()["key"]:
			draw_line(Vector2(x0 + w, cr.position.y), Vector2(x0 + w, size.y), Color(0.67, 0.64, 0.56, 0.42), 1.2)
	# Items.
	var by_cell: Dictionary = lay["cells"]
	for key in by_cell:
		var parts = key.split("|")
		var row: String = parts[0]
		var col: String = parts[1]
		if not row_y.has(row) or not col_x.has(col):
			continue
		var idxs: Array = by_cell[key]
		for k in range(idxs.size()):
			var it: Dictionary = lay["items"][idxs[k]]
			if lay["view"] == "places":
				_draw_dot(it, row, col, k)
			else:
				_draw_card_item(it, row, col, k)
	# Deductions pinned to this view.
	for n in lay.get("pinned", []):
		_draw_pinned(n)
	# Headers over the content, then the strings on top (they run to the row labels).
	_draw_headers()
	var focus_n = _hover if _hover > 0 else state.selected_card
	if focus_n > 0:
		_draw_strings(focus_n)
	if lay["items"].is_empty() and lay.get("pinned", []).is_empty():
		var msg = state.status_text(g, 0) if state.is_filtered() else "Nothing on this board yet."
		draw_multiline_string(_font, cr.position + Vector2(20, 40), msg, HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 40, 15, -1, UITheme.color("accent"))

func _item_rect(row: String, col: String, k: int) -> Rect2:
	var p = Vector2(col_x[col] + (COL_W - CARD_W) / 2.0, row_y[row] + ROW_PAD / 2.0 + k * (CARD_H + GAP))
	return Rect2(to_screen(p), Vector2(CARD_W, CARD_H) * zoom)

func _card_tex(n: int):
	return _cards_tex[(n * 7) % _cards_tex.size()] if not _cards_tex.is_empty() else null

func _draw_paper(r: Rect2, n: int, tint: Color = Color.WHITE) -> void:
	var t = _card_tex(n)
	if t != null:
		draw_texture_rect(t, r, false, tint)
	else:
		draw_rect(r, UITheme.color("paper") * tint)

func _draw_card_item(it: Dictionary, row: String, col: String, k: int) -> void:
	var n: int = it["card"]
	var card: Dictionary = g.board[n - 1]
	var r = _item_rect(row, col, k)
	var fade = UITheme.card_color(card)
	if not r.intersects(Rect2(Vector2.ZERO, size)):
		return
	_items.append({"rect": r, "n": n})
	var selected = n == state.selected_card
	var hovered = n == _hover
	var lod = _lod()
	var src: String = card.get("source", "")
	var src_col = C.npc_color(src) if g.w.by_id.has(src) else UITheme.color("border")
	if lod == 0:
		# Overview: a chip in the speaker's colour (process: red for a nomination, dark for a death).
		var chip = UITheme.color("paper").darkened(0.05)
		match it["mark"]:
			"nominated":
				chip = UITheme.color("red")
			"voted_yes":
				chip = UITheme.color("paper_dim")
		if card.get("kind", "") in ["death", "execution"]:
			chip = Color(0.25, 0.22, 0.24)
		draw_rect(r, chip * fade)
		draw_rect(Rect2(r.position, Vector2(maxf(3.0, 6.0 * zoom), r.size.y)), src_col * fade)
	else:
		draw_rect(Rect2(r.position + Vector2(3, 4) * zoom, r.size), Color(0, 0, 0, 0.35) * fade)  # shadow
		_draw_paper(r, n, fade)
		draw_rect(Rect2(r.position + Vector2(6, 5) * zoom, Vector2(4, r.size.y - 10 * zoom) * Vector2(zoom, 1)), UITheme.ink_of(src_col) * fade)
		var icon = _icon_for(card, it)
		var kind = Icons.kind_for(card)
		var kind_icon = Icons.texture(kind)
		var icon_count = 1 if icon != null or kind_icon != null else 0
		var tx = r.position.x + 14 * zoom
		var icon_x = r.end.x - 26 * zoom
		if icon != null:
			var s = 20.0 * zoom
			draw_texture_rect(icon, Rect2(Vector2(icon_x, r.position.y + 6 * zoom), Vector2(s, s * icon.get_height() / icon.get_width())), false, fade)
		if kind_icon != null:
			var kind_y = r.end.y - 26 * zoom if icon != null else r.position.y + 6 * zoom
			draw_texture_rect(kind_icon, Rect2(Vector2(icon_x, kind_y), Vector2(20, 20) * zoom), false,
				(UITheme.color("red").darkened(0.1) if kind == "accusation" else _ink) * fade)
		var fs = int(clampf(13.5 * zoom, 12, 28))
		var names = {}
		for m in g.w.npcs:
			names[m.id] = m.name
		var text = CardModel.short_text(card, names) if lod == 1 else card.get("text", "")
		if it["mark"] == "voted_yes":
			text = "Voted to hang %s" % names.get(card.get("nominee", ""), "?") if lod >= 1 else text
		var lines = 2 if lod == 1 else 5
		draw_multiline_string(_font, Vector2(tx, r.position.y + fs + 6 * zoom), text, HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 22 * zoom - 24 * zoom * icon_count, fs, lines, _ink * fade)
		if lod == 2:
			var heard = _heard_line(card)
			if heard != "":
				draw_string(_font, Vector2(tx, r.end.y - 6 * zoom), heard, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - (44 if kind_icon != null else 20) * zoom, int(fs * 0.8), UITheme.color("ink_soft") * fade)
		if it["mark"] == "nominated":
			var seal = UITheme.tex("ui/wax_seal", 0.25)
			if seal != null:
				var ss = 18.0 * zoom
				draw_texture_rect(seal, Rect2(r.end - Vector2(ss + 4 * zoom, ss + 4 * zoom), Vector2(ss, ss)), false, fade)
	if context_numbers.has(n):
		EvidenceContext.draw_border(self, r, _ink * fade)
		EvidenceContext.draw_tag(self, r, _font, _ink * fade, zoom)
	if selected or hovered:
		draw_rect(r.grow(2), UITheme.color("string") if selected else UITheme.color("accent"), false, 2.0)
	if n in _staged():
		draw_circle(r.position + Vector2(r.size.x - 4, 4), 4, UITheme.color("accent"))

func _heard_line(card: Dictionary) -> String:
	var ls: Array = card.get("learned", [])
	if ls.is_empty():
		return ""
	var parts: Array = []
	for d in ls.slice(0, 3):
		var who: String = d.get("via", "")
		var nm: String = g.w.by_id[who].name if g.w.by_id.has(who) else ("you" if who in ["player", "evidence", ""] else who)
		parts.append("%s %s%s" % [CardModel.time_label({"day": d["day"], "phase": d["phase"]}), nm, " (public)" if d.get("public", false) else ""])
	return "heard: " + "; ".join(PackedStringArray(parts))

func _icon_for(card: Dictionary, it: Dictionary):
	var role: String = ""
	match card.get("kind", ""):
		"info", "claim":
			role = card.get("role", "")
		"hint":
			return UITheme.tex("ui/roles/unknown", 0.12)
		"death":
			return UITheme.tex("ui/raven", 0.15)
		"quiet":
			return UITheme.tex("ui/moon", 0.18)
		"execution":
			return UITheme.tex("ui/wax_seal", 0.2)
	if role != "" and C.ROLES.has(role):
		return UITheme.tex("ui/roles/" + role, 0.1)
	return null

func _draw_dot(it: Dictionary, row: String, col: String, k: int) -> void:
	var per_line = maxi(1, int((COL_W - 8.0) / (DOT + 6.0)))
	var cx = col_x[col] + 4.0 + (k % per_line) * (DOT + 6.0) + DOT / 2.0 + 2.0
	var cy = row_y[row] + ROW_PAD / 2.0 + (k / per_line) * (DOT + 18.0) + DOT / 2.0
	var c = to_screen(Vector2(cx, cy))
	var rad = DOT / 2.0 * zoom
	var hit = Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
	if not hit.intersects(Rect2(Vector2.ZERO, size)):
		return
	var n: int = it["card"]
	var fade = UITheme.card_color(g.board[n - 1])
	_items.append({"rect": hit, "n": n})
	var who: String = it["who"]
	var mark: String = it["mark"]
	var col_c = (C.npc_color(who) if g.w.by_id.has(who) else UITheme.color("paper_dim")) * fade
	draw_circle(c + Vector2(1.5, 2.5) * zoom, rad, Color(0, 0, 0, 0.4) * fade)
	match mark:
		"solid":
			draw_circle(c, rad, col_c)
		"hollow":
			draw_circle(c, rad, UITheme.color("bg") * fade)
			draw_arc(c, rad - 2 * zoom, 0, TAU, 28, col_c, maxf(2.0, 4.0 * zoom))
		"ability":
			draw_circle(c, rad, col_c.darkened(0.15))
			draw_arc(c, rad + 2 * zoom, 0, TAU, 28, UITheme.color("border") * fade, maxf(1.5, 2.5 * zoom))
		"trace":
			var t = UITheme.tex("ui/wax_seal", 0.18)
			if t != null:
				draw_texture_rect(t, hit, false, fade)
			else:
				draw_rect(hit, UITheme.color("red") * fade)
	if who != "" and g.w.by_id.has(who):
		var initial: String = g.w.by_id[who].name.substr(0, 1)
		var fs = int(clampf(15 * zoom, 7, 30))
		draw_string(_font, c + Vector2(-rad, fs * 0.35), initial, HORIZONTAL_ALIGNMENT_CENTER, rad * 2, fs,
			UITheme.color("ink") * fade if mark != "hollow" else col_c)
		if _lod() >= 2 and not context_numbers.has(n):
			var card: Dictionary = g.board[n - 1]
			var where = C.loc_name(card["loc"]).trim_prefix("the ") if C.LOCATIONS.has(card.get("loc", "")) else ""
			var lab = g.w.by_id[who].name if state.rows_by == "place" else (where if where != "" else C.block_name(card.get("block", "")))
			if card.get("kind", "") == "alibi":
				lab = "home"
			var lw = (DOT + 6.0) * zoom
			draw_string(_font, c + Vector2(-lw / 2, rad + 11 * zoom), lab, HORIZONTAL_ALIGNMENT_CENTER, lw, int(clampf(8 * zoom, 7, 16)), UITheme.color("text") * fade)
	if context_numbers.has(n):
		EvidenceContext.draw_border(self, hit, UITheme.color("text") * fade)
		EvidenceContext.draw_tag(self, Rect2(hit.position + Vector2(-3, DOT) * zoom, Vector2(DOT + 6, 16) * zoom), _font, _ink * fade, zoom)
	if n == state.selected_card or n == _hover:
		draw_arc(c, rad + 4 * zoom, 0, TAU, 28, UITheme.color("string") if n == state.selected_card else UITheme.color("accent"), 2.0)

func _pin_rect(n: int) -> Rect2:
	var p: Vector2 = g.board[n - 1].get("pins", {}).get(board_view(), Vector2.ZERO)
	return Rect2(to_screen(p), Vector2(CARD_W * 1.15, CARD_H * 1.3) * zoom)

func _draw_pinned(n: int) -> void:
	var card: Dictionary = g.board[n - 1]
	var fade = UITheme.card_color(card)
	var r = _pin_rect(n)
	_items.append({"rect": r, "n": n, "pinned": true})
	draw_rect(Rect2(r.position + Vector2(4, 5) * zoom, r.size), Color(0, 0, 0, 0.4) * fade)
	_draw_paper(r, n + 3, Color(1.0, 0.95, 0.85) * fade)
	var seal = UITheme.tex("ui/wax_seal", 0.2)
	if seal != null:
		var ss = 22.0 * zoom
		draw_texture_rect(seal, Rect2(r.position + Vector2(r.size.x / 2 - ss / 2, -ss * 0.4), Vector2(ss, ss)), false, fade)
	var fs = int(clampf(12.5 * zoom, 10, 28))
	draw_multiline_string(_font, r.position + Vector2(10 * zoom, fs + 14 * zoom), card.get("text", "").trim_prefix("Deduction: "),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18 * zoom, fs, 2 if _lod() < 2 else 6, UITheme.color("red").darkened(0.3) * fade)
	if n == state.selected_card or n == _hover:
		draw_rect(r.grow(2), UITheme.color("string"), false, 2.0)
	# A deduction's own strings to its supports are always shown, faintly.
	for s in card.get("supports", []):
		for rr in _rects_of(s):
			_string(r.get_center(), rr.get_center(), Color(UITheme.color("string"), 0.35) * fade, 1.5)

func _rects_of(n: int) -> Array:
	return _items.filter(func(x): return x["n"] == n).map(func(x): return x["rect"])

func _row_anchor(id: String) -> Vector2:
	if not row_y.has(id):
		return Vector2(-1, -1)
	return Vector2(HEAD_W - 4, to_screen(Vector2(0, row_y[id] + row_h[id] / 2.0)).y)

func _draw_strings(n: int) -> void:
	if n < 1 or n > g.board.size():
		return  # (a selection left over from an earlier case)
	var card: Dictionary = g.board[n - 1]
	var mine: Array = _rects_of(n)
	if mine.is_empty():
		return
	var from: Vector2 = mine[0].get_center()
	var lk: Dictionary = BoardModel.links(card)
	var red = UITheme.color("string")
	# Who said it, and whom it's about, as strings to their row labels (when rows are people).
	if lay["rows_by"] == "person":
		if lk["source"] != "":
			var a = _row_anchor(lk["source"])
			if a.y >= 0:
				_string(from, a, red, 2.5)
		for v in lk["via"]:
			var a2 = _row_anchor(v)
			if a2.y >= 0:
				_string(from, a2, Color(red, 0.55), 1.5)
	for s in lk["supports"]:
		for rr in _rects_of(s):
			_string(from, rr.get_center(), red, 2.5)
	# Its other appearances on the board (a reading on two people's rows).
	for i in range(1, mine.size()):
		_string(from, mine[i].get_center(), Color(red, 0.6), 1.5)

func _string(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	# A slightly sagging thread between two pins.
	var mid = (a + b) / 2.0 + Vector2(0, minf(40.0, a.distance_to(b) * 0.12))
	var pts = PackedVector2Array()
	for i in range(17):
		var t = i / 16.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(pts, col, width, true)
	draw_circle(a, width + 1.5, col)
	draw_circle(b, width + 1.5, col)

func _draw_headers() -> void:
	var text = UITheme.color("text")
	# Time header.
	draw_rect(Rect2(0, 0, size.x, HEAD_H), UITheme.color("panel"))
	for c in lay["cols"]:
		var x0 = to_screen(Vector2(col_x[c["key"]], 0)).x
		var w = COL_W * zoom
		if x0 + w < HEAD_W or x0 > size.x:
			continue
		var lab: String = c["label"]
		if zoom >= 0.7:
			lab = ("Night %d" % c["day"]) if c["phase"] == C.NIGHT else "Day %d · %s" % [c["day"], C.PHASES[c["phase"]]]
		var night = c["phase"] == C.NIGHT
		draw_rect(Rect2(x0, 0, w, HEAD_H), Icons.phase_shade(c["phase"]))
		var icon = Icons.texture("sunrise" if c["phase"] == C.MORNING else "sunset") if c["phase"] in [C.MORNING, C.EVENING] else UITheme.tex("ui/moon" if night else "ui/sun", 0.09)
		var tx = x0 + 8
		if icon != null and zoom >= 0.45:
			var tint = Color.WHITE
			if c["phase"] == C.MORNING:
				tint = Color(0.98, 0.76, 0.38)
			elif c["phase"] == C.EVENING:
				tint = Color(0.83, 0.8, 0.75)
			draw_texture_rect(icon, Rect2(x0 + 6, (HEAD_H - 20) / 2, 20, 20), false, tint)
			tx += 24
		draw_string(_font, Vector2(tx, HEAD_H - 11), lab, HORIZONTAL_ALIGNMENT_LEFT, maxf(10.0, w - (tx - x0) - 4), 13,
			UITheme.color("accent") if not night else text)
	draw_line(Vector2(0, HEAD_H), Vector2(size.x, HEAD_H), UITheme.color("border"), 1.5)
	# Row labels.
	draw_rect(Rect2(0, HEAD_H, HEAD_W, size.y - HEAD_H), UITheme.color("panel"))
	for r in lay["rows"]:
		var y0 = to_screen(Vector2(0, row_y[r["id"]])).y
		var hh = row_h[r["id"]] * zoom
		if y0 + hh < HEAD_H or y0 > size.y:
			continue
		var top = maxf(y0, HEAD_H)
		var box = Rect2(6, top + 3, HEAD_W - 12, minf(30.0, maxf(8.0, y0 + hh - top - 6)))
		var active = state.people.has(r["id"]) or state.places.has(r["id"])
		var plaque = UITheme.nine("ui/plaque_red" if active else "ui/plaque_cream", 30, [10, 8, 10, 8])
		if plaque != null:
			draw_style_box(plaque, box)
		else:
			draw_rect(box, UITheme.color("paper"))
		var col_c = UITheme.ink_of(C.npc_color(r["id"])) if r["kind"] == "person" else UITheme.color("ink")
		if active:
			col_c = UITheme.color("paper")
		if r["kind"] == "person":
			draw_circle(box.position + Vector2(13, box.size.y / 2.0), 5, C.npc_color(r["id"]))
		draw_string(_font, box.position + Vector2(22 if r["kind"] == "person" else 10, box.size.y / 2.0 + 5), r["label"], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 26, 15, col_c)
		_row_hits.append({"rect": box, "row": r})
	draw_line(Vector2(HEAD_W, HEAD_H), Vector2(HEAD_W, size.y), UITheme.color("border"), 1.5)
	draw_rect(Rect2(0, 0, HEAD_W, HEAD_H), UITheme.color("panel"))
	var corner = {"places": "Places" if state.rows_by == "place" else "People", "statements": "About", "process": "People"}
	draw_string(_font, Vector2(10, HEAD_H - 11), corner.get(lay["view"], ""), HORIZONTAL_ALIGNMENT_LEFT, HEAD_W - 14, 14, UITheme.color("muted"))

func _staged() -> Array:
	var p = get_parent()
	while p != null and not ("staged" in p):
		p = p.get_parent()
	return p.staged if p != null else []

# ---------------------------------------------------------------- input

func _hit(pos: Vector2) -> Dictionary:
	for i in range(_items.size() - 1, -1, -1):
		if _items[i]["rect"].has_point(pos):
			return _items[i]
	return {}

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mb.shift_pressed:
				pan.x += (-60.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 60.0) / zoom
				_clamp_pan()
				queue_redraw()
				view_changed.emit()
			else:
				zoom_at(mb.position, 1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				for rh in _row_hits:
					if rh["rect"].has_point(mb.position):
						row_clicked.emit(rh["row"]["kind"], rh["row"]["id"])
						return
				var h = _hit(mb.position)
				if h.is_empty():
					_panning = true
					if not mb.double_click:
						state.select_card(0)
						queue_redraw()
				elif h.get("pinned", false):
					_moving_pin = h["n"]
					state.select_card(h["n"])
				else:
					state.select_card(h["n"])
					if mb.double_click:
						card_activated.emit(h["n"])
					queue_redraw()
			else:
				_panning = false
				_moving_pin = 0
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			for rh in _row_hits:
				if rh["row"]["kind"] == "person" and rh["rect"].has_point(mb.position):
					person_context_requested.emit(rh["row"]["id"])
					accept_event()
					return
			var h2 = _hit(mb.position)
			if not h2.is_empty():
				card_context_requested.emit(h2["n"], Vector2i(get_screen_transform() * mb.position))
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
	elif ev is InputEventMouseMotion:
		var mm: InputEventMouseMotion = ev
		if _moving_pin > 0:
			var pins: Dictionary = g.board[_moving_pin - 1].get("pins", {})
			pins[board_view()] = pins.get(board_view(), Vector2.ZERO) + mm.relative / zoom
			queue_redraw()
			return
		if _panning:
			pan -= mm.relative / zoom
			_clamp_pan()
			queue_redraw()
			view_changed.emit()
			return
		var h3 = _hit(mm.position)
		var n: int = h3.get("n", 0)
		if n != _hover:
			_hover = n
			queue_redraw()

func _get_tooltip(at: Vector2) -> String:
	var h = _hit(at)
	if h.is_empty():
		for rh in _row_hits:
			if rh["rect"].has_point(at):
				var hint = "Click to show only cards %s %s." % ["about" if lay["view"] != "places" else "placing" if rh["row"]["kind"] == "person" else "at", rh["row"]["label"]]
				if rh["row"]["kind"] == "person":
					hint += " Right-click to open or minimize their profile."
				return hint
		return ""
	var card: Dictionary = g.board[h["n"] - 1]
	var t = "#%d  %s" % [card["n"], card.get("text", "")]
	if context_numbers.has(card.n):
		t += "\n" + EvidenceContext.EXPLANATION
	var heard = _heard_line(card)
	if heard != "":
		t += "\n" + heard
	t += "\n(double-click or drag to add to your working set; right-click for card actions)"
	return t

## Dragging a card off the board (to the working set). Pinned deductions move instead.
func _get_drag_data(at: Vector2):
	var h = _hit(at)
	if h.is_empty() or h.get("pinned", false):
		return null
	var l = Label.new()
	l.text = "#%d" % h["n"]
	l.add_theme_color_override("font_color", UITheme.color("ink"))
	var pc = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("paper"), UITheme.color("border"), 1, 3, 6))
	pc.add_child(l)
	set_drag_preview(pc)
	_panning = false
	return {"cards": [h["n"]]}

## Deductions dropped from the tray are pinned where they land.
func _can_drop_data(_at: Vector2, data) -> bool:
	return data is Dictionary and data.has("pin")

func _drop_data(at: Vector2, data) -> void:
	var n: int = data["pin"]
	var c: Dictionary = g.board[n - 1]
	var pins: Dictionary = c.get("pins", {})
	pins[board_view()] = to_world(at) - Vector2(CARD_W, CARD_H) * 0.5
	c["pins"] = pins
	state.select_card(n)
	rebuild()

func unpin(n: int) -> void:
	var c: Dictionary = g.board[n - 1]
	c.get("pins", {}).erase(board_view())
	rebuild()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_RESIZED, NOTIFICATION_VISIBILITY_CHANGED]:
		_schedule_initial_fit()
