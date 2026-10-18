## The town map, drawn with _draw() from the art in assets/art: each block is its painted
## base, with building sprites for the places, cottages for homes, sandy roads between
## blocks, trees and lamps for dressing, and townsfolk as paper standees. Overview of the four
## blocks; click a block to zoom in. Emits `clicked(kind, id)` for the main UI to turn into commands:
## kind = "block" | "location" | "home" | "scene" | "npc" | "back".
##
## Visibility follows the game's rules (Game.can_see): people at work or in conversation are
## shown at their exact spot from anywhere; anyone else (out, or at home) only once you're on
## their block this phase. At night everyone is home.
extends Control

signal clicked(kind, id)

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")

# Layout in a virtual 1000 x 700 space. The Square sits in the middle, joined to the
# others; the Market and Chapel Hill are also joined across the top.
const BLOCK_RECTS = {
	"market": Rect2(30, 30, 300, 280),
	"hill": Rect2(670, 30, 300, 280),
	"square": Rect2(350, 200, 300, 260),
	"docks": Rect2(290, 480, 420, 205),
}
# Trees and lamps around the blocks (virtual coordinates; drawn behind the blocks).
const DECOR = [
	["tree_pine", Vector2(18, 335), 70], ["tree_oak", Vector2(80, 360), 80], ["tree_autumn", Vector2(150, 345), 70],
	["tree_pine", Vector2(220, 380), 75], ["bush", Vector2(270, 330), 40], ["tree_oak", Vector2(860, 350), 85],
	["tree_pine", Vector2(930, 330), 80], ["tree_autumn", Vector2(780, 370), 72], ["bush", Vector2(700, 335), 40],
	["tree_pine", Vector2(455, 30), 70], ["tree_oak", Vector2(520, 60), 80], ["tree_pine", Vector2(585, 25), 65],
	["tree_autumn", Vector2(60, 520), 75], ["tree_pine", Vector2(140, 560), 80], ["tree_oak", Vector2(200, 620), 70],
	["tree_pine", Vector2(800, 520), 80], ["tree_oak", Vector2(880, 590), 85], ["tree_autumn", Vector2(950, 520), 70],
	["flowers", Vector2(760, 640), 30], ["flowers", Vector2(230, 470), 26], ["bush", Vector2(940, 660), 40],
]
const BLOCK_TINT = {
	"market": Color(0.20, 0.15, 0.12), "hill": Color(0.17, 0.17, 0.20),
	"square": Color(0.16, 0.18, 0.14), "docks": Color(0.12, 0.15, 0.20),
}
const OVERVIEW = Rect2(0, 0, 1000, 700)
const BUILDING_ART = {"tavern": "tavern", "well": "well", "smithy": "smithy", "bakery": "bakery",
	"wharf": "wharf", "mill": "mill", "chapel": "chapel", "graveyard": "graveyard"}

var g
var zoom_block = ""
var selected_npc = ""
var selected_block = ""
var _hits: Array = []        # [{rect (screen), kind, id, label, hint}]
var _hover: Dictionary = {}
var _scale = 1.0
var _offset = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func set_game(game) -> void:
	g = game
	zoom_block = ""
	selected_npc = ""
	selected_block = ""
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func zoom_to(block: String) -> void:
	zoom_block = block
	queue_redraw()

# ---------------------------------------------------------------- geometry

func _view_rect() -> Rect2:
	if zoom_block != "" and BLOCK_RECTS.has(zoom_block):
		return BLOCK_RECTS[zoom_block].grow(24)
	return OVERVIEW

func _fit() -> void:
	var vr = _view_rect()
	_scale = minf(size.x / vr.size.x, size.y / vr.size.y)
	_offset = (size - vr.size * _scale) / 2.0 - vr.position * _scale

func _p(v: Vector2) -> Vector2:
	return v * _scale + _offset

func _r(r: Rect2) -> Rect2:
	return Rect2(_p(r.position), r.size * _scale)

func _fs(base: float) -> int:
	return int(clampf(base * _scale * 1.25, 13.0, 32.0))

func _loc_rect(l: String) -> Rect2:
	var b: String = C.LOCATIONS[l]["block"]
	var R: Rect2 = BLOCK_RECTS[b]
	var locs: Array = C.LOCATIONS.keys().filter(func(x): return C.LOCATIONS[x]["block"] == b)
	var i = locs.find(l)
	return Rect2(R.position.x + R.size.x * (0.06 + 0.48 * i), R.position.y + R.size.y * 0.12, R.size.x * 0.42, R.size.y * 0.46)

## Which location a layout rect belongs to (if it's a building).
func _loc_of_rect(rect: Rect2) -> String:
	for l in C.LOCATIONS:
		if _loc_rect(l) == rect:
			return l
	return ""

func _street_rect(b: String) -> Rect2:
	var R: Rect2 = BLOCK_RECTS[b]
	return Rect2(R.position.x + R.size.x * 0.08, R.position.y + R.size.y * 0.6, R.size.x * 0.84, R.size.y * 0.14)

func _home_rect(n) -> Rect2:
	var b: String = n.home_block
	var R: Rect2 = BLOCK_RECTS[b]
	var residents: Array = g.w.npcs.filter(func(x): return x.home_block == b)
	var i = residents.find(n)
	var hs = minf(R.size.y * 0.2, 46.0)
	var gap = hs * 0.35
	var total = residents.size() * hs + (residents.size() - 1) * gap
	var x0 = R.position.x + (R.size.x - total) / 2.0
	return Rect2(x0 + i * (hs + gap), R.position.y + R.size.y - hs - 8, hs, hs)

func _block_center(b: String) -> Vector2:
	return BLOCK_RECTS[b].get_center()

# ---------------------------------------------------------------- drawing

func _art(rel: String, scale: float = 0.5):
	return UITheme.tex("art/" + rel, scale)

## Draw a texture inside a rect, keeping its aspect: "contain" (fit, aligned to the bottom)
## or "cover" (fill, cropping the overflow from the centre).
func _draw_art(tex, rect: Rect2, mode: String = "contain", tint: Color = Color.WHITE) -> Rect2:
	if tex == null:
		return rect
	var ts = Vector2(tex.get_width(), tex.get_height())
	if mode == "cover":
		var k = maxf(rect.size.x / ts.x, rect.size.y / ts.y)
		var src = Vector2(rect.size.x / k, rect.size.y / k)
		draw_texture_rect_region(tex, rect, Rect2((ts - src) / 2.0, src), tint)
		return rect
	var k2 = minf(rect.size.x / ts.x, rect.size.y / ts.y)
	var sz = ts * k2
	var r = Rect2(Vector2(rect.get_center().x - sz.x / 2.0, rect.end.y - sz.y), sz)
	draw_texture_rect(tex, r, false, tint)
	return r

func _sign(font, text: String, center: Vector2, fs: int, active: bool = false) -> Rect2:
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 1.6
	var h = fs * 1.9
	var r = Rect2(center - Vector2(w / 2.0, h / 2.0), Vector2(w, h))
	var plaque = UITheme.nine("ui/plaque_red" if active else "ui/plaque_cream", h, [h * 0.3, h * 0.25, h * 0.3, h * 0.25])
	if plaque != null:
		draw_style_box(plaque, r)
	else:
		draw_rect(r, UITheme.color("paper"))
	draw_string(font, Vector2(r.position.x, r.position.y + h * 0.68), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs,
		UITheme.color("paper") if active else UITheme.color("ink"))
	return r

func _draw() -> void:
	_hits = []
	if g == null:
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.color("bg"))
		return
	_fit()
	var font = get_theme_default_font()
	var w = g.w
	var night = g.state == "night"
	var tint = Color(0.5, 0.55, 0.85) if night else Color.WHITE
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.14) if night else Color(0.12, 0.16, 0.18))
	# Dressing behind everything.
	for d in DECOR:
		var t = _art("decor/" + d[0], 0.4)
		if t != null:
			var hh: float = d[2]
			var ww = hh * t.get_width() / t.get_height()
			_draw_art(t, _r(Rect2(d[1] - Vector2(ww / 2.0, 0), Vector2(ww, hh))), "contain", tint)
	# Roads: sandy paths with a dark edge, and a lamp halfway along.
	for road in C.ROADS:
		var a = _p(_block_center(road[0]))
		var b2 = _p(_block_center(road[1]))
		draw_line(a, b2, Color(0.2, 0.17, 0.12), 26.0 * _scale)
		draw_line(a, b2, Color(0.78, 0.66, 0.45) * tint, 20.0 * _scale)
		var lamp = _art("decor/lamp", 0.3)
		if lamp != null:
			var mid = (_block_center(road[0]) + _block_center(road[1])) / 2.0 + Vector2(18, -10)
			_draw_art(lamp, _r(Rect2(mid - Vector2(10, 48), Vector2(20, 48))), "contain", Color(1, 1, 1) if not night else Color(1, 0.95, 0.75))
	# Blocks.
	for b in BLOCK_RECTS:
		var R: Rect2 = _r(BLOCK_RECTS[b])
		var base = _art("blocks/" + b, 0.6)
		if base != null:
			_draw_art(base, R, "cover", tint)
		else:
			draw_rect(R, BLOCK_TINT[b] if not night else BLOCK_TINT[b].darkened(0.45))
		var here = not night and g.moved and w.loc_block(g.loc) == b
		var border = UITheme.color("accent") if (b == selected_block or here) else Color(0.12, 0.1, 0.08, 0.8)
		draw_rect(R, border, false, 3.0 if (b == selected_block or here) else 2.0)
		if zoom_block == "":
			_hits.append({"rect": R, "kind": "block", "id": b, "label": C.block_name(b), "hint": "Click to look closer" if not night else "Click to choose it for your vigil"})
		# Locations: building sprites with a name sign.
		for l in C.LOCATIONS:
			if C.LOCATIONS[l]["block"] != b:
				continue
			var LR: Rect2 = _r(_loc_rect(l))
			var art = _art("buildings/" + BUILDING_ART.get(l, "cottage_red"), 0.5)
			var drawn = _draw_art(art, LR.grow_individual(0, LR.size.y * 0.1, 0, 0), "contain", tint) if art != null else LR
			if art == null:
				draw_rect(LR, Color(0.3, 0.26, 0.22))
			var here_l = g.moved and g.loc == l and not night
			if zoom_block != "" or _scale > 0.9:
				_sign(font, C.loc_name(l).trim_prefix("the ").capitalize(), Vector2(drawn.get_center().x, drawn.end.y - 4), _fs(11), here_l)
			elif here_l:
				draw_rect(drawn.grow(2), UITheme.color("accent"), false, 2.0)
			if zoom_block != "":
				var hint = "Click to spend the phase here" if not g.moved else ("Click to step over (free move)" if not g.free_move_used and w.loc_block(g.loc) == b and g.loc != l else "")
				if g.state != "day":
					hint = ""
				_hits.append({"rect": LR, "kind": "location", "id": l, "label": C.loc_name(l), "hint": hint})
		# Homes (and crime scenes): small cottages with the owner's colour on the door.
		for n in w.npcs:
			if n.home_block != b:
				continue
			var HR: Rect2 = _r(_home_rect(n))
			var cot = _art("buildings/" + ("cottage_red" if n.id.hash() % 2 == 0 else "cottage_blue"), 0.25)
			var hd = _draw_art(cot, HR.grow(HR.size.x * 0.15), "contain", tint) if cot != null else HR
			if cot == null:
				draw_rect(HR, Color(0.22, 0.2, 0.18))
			draw_circle(Vector2(hd.get_center().x, hd.end.y - hd.size.y * 0.12), maxf(3.0, 5.0 * _scale), C.npc_color(n.id))
			var sid = "scene_" + n.id
			if w.scenes.has(sid):
				draw_line(hd.position, hd.end, Color(0.85, 0.15, 0.15), 3.0)
				draw_line(hd.position + Vector2(hd.size.x, 0), hd.position + Vector2(0, hd.size.y), Color(0.85, 0.15, 0.15), 3.0)
			if zoom_block != "":
				if w.scenes.has(sid):
					_hits.append({"rect": HR, "kind": "scene", "id": sid, "label": w.scenes[sid]["name"] + " (crime scene)", "hint": "Click to go and search it" if g.state == "day" else ""})
				else:
					_hits.append({"rect": HR, "kind": "home", "id": n.id, "label": "%s's home" % n.name, "hint": ("Click to call on them" if n.alive and n.at_home() else "Click to knock") if g.state == "day" else ""})
		# The block's name on a sign.
		_sign(font, C.block_name(b).trim_prefix("the "), Vector2(R.get_center().x, R.position.y + _fs(16)), _fs(15), b == selected_block)
	if night:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.1, 0.25))
	# People.
	_draw_people(font)
	# Zoomed in: dim everything outside the block in view.
	if zoom_block != "" and BLOCK_RECTS.has(zoom_block):
		var Z: Rect2 = _r(BLOCK_RECTS[zoom_block])
		var dim = Color(0.04, 0.05, 0.08, 0.72)
		draw_rect(Rect2(0, 0, size.x, Z.position.y), dim)
		draw_rect(Rect2(0, Z.end.y, size.x, size.y - Z.end.y), dim)
		draw_rect(Rect2(0, Z.position.y, Z.position.x, Z.size.y), dim)
		draw_rect(Rect2(Z.end.x, Z.position.y, size.x - Z.end.x, Z.size.y), dim)
	# Back button and status.
	if zoom_block != "":
		var br = _sign(font, "◀ Whole town", Vector2(70, 24), 13)
		_hits.push_front({"rect": br, "kind": "back", "id": "", "label": "Back to the whole town", "hint": ""})
	if not _hover.is_empty():
		var t2 = _hover["label"] + ((" — " + _hover["hint"]) if _hover.get("hint", "") != "" else "")
		var tw = font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18
		var tr = Rect2(Vector2(8, size.y - 32), Vector2(minf(size.x - 16, tw), 26))
		draw_style_box(UITheme.flat(UITheme.color("paper"), UITheme.color("border"), 1, 3, 4), tr)
		draw_string(font, tr.position + Vector2(9, 18), t2, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x - 12, 16, UITheme.color("ink"))

## Where each living person is drawn, following what the player can actually see: a paper
## standee of them at their building, in the street, or at their home.
func _draw_people(font) -> void:
	var w = g.w
	var night = g.state == "night"
	var groups = {}  # virtual rect key -> [npc]
	var rects = {}
	for n in w.living():
		if not g.can_see(n):
			continue  # out of sight until the player is on their block
		var rect: Rect2
		if night or n.at_home():
			rect = _home_rect(n)
		elif C.LOCATIONS.has(n.loc):
			rect = _loc_rect(n.loc)
		else:
			rect = _street_rect(w.loc_block(n.loc))
		var key = str(rect)
		if not groups.has(key):
			groups[key] = []
			rects[key] = rect
		groups[key].append(n)
	var h = clampf(54.0 * _scale, 22.0, 120.0)
	var lf = mini(_fs(12), 19)
	for key in groups:
		var rect: Rect2 = rects[key]
		var members: Array = groups[key]
		var sr: Rect2 = _r(rect)
		var step = h * 0.78
		var per_row = maxi(1, int(maxf(sr.size.x, step * 2) / step))
		var base_y = sr.end.y - (h * 0.1 if C.LOCATIONS.has(_loc_of_rect(rect)) else -h * 0.15)
		for i in range(members.size()):
			var n = members[i]
			var row = i / per_row
			var in_row = mini(per_row, members.size() - row * per_row)
			var x0 = sr.get_center().x - (in_row - 1) * step / 2.0
			var foot = Vector2(x0 + (i % per_row) * step, base_y - row * h * 0.55)
			var t = _art("standees/" + n.id, 0.3)
			var rr = Rect2(foot - Vector2(h * 0.4, h), Vector2(h * 0.8, h))
			draw_circle(foot + Vector2(0, -2), h * 0.3, Color(0, 0, 0, 0.35))
			if t != null:
				rr = _draw_art(t, rr, "contain", Color(0.75, 0.78, 1.0) if night else Color.WHITE)
			else:
				draw_circle(rr.get_center(), h * 0.3, C.npc_color(n.id))
			if n.busy_with != "":
				draw_arc(rr.position + Vector2(rr.size.x * 0.85, rr.size.y * 0.15), h * 0.12, 0, TAU, 12, Color(1, 1, 1, 0.9), 2.0)
			if n.id == selected_npc:
				draw_rect(rr.grow(2), Color(1, 1, 1, 0.9), false, 2.0)
			if g.talk_with != null and g.talk_with == n:
				draw_rect(rr.grow(4), UITheme.color("accent"), false, 3.0)
			if zoom_block != "":
				draw_string(font, Vector2(foot.x - step / 2.0 - 10, foot.y + lf + 2), n.name, HORIZONTAL_ALIGNMENT_CENTER, step + 20, lf, C.npc_color(n.id))
			var hint = ""
			if g.state == "day":
				hint = "busy talking" if n.busy_with != "" else ("click to talk" if not n.at_home() else "click to call on them")
			elif g.state == "night":
				hint = "click to choose them for your ward" if g.w.tools["ward"] > 0 else ""
			_hits.push_front({"rect": rr, "kind": "npc", "id": n.id, "label": "%s the %s" % [n.name, n.occupation], "hint": hint})

# ---------------------------------------------------------------- input

func _hit_at(pos: Vector2) -> Dictionary:
	for h in _hits:
		if h["rect"].has_point(pos):
			return h
	return {}

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h = _hit_at(ev.position)
		if h.get("rect", null) != _hover.get("rect", null) or h.get("id", "") != _hover.get("id", ""):
			_hover = h
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_RIGHT and zoom_block != "":
			zoom_block = ""
			queue_redraw()
			return
		if ev.button_index != MOUSE_BUTTON_LEFT:
			return
		var h = _hit_at(ev.position)
		if h.is_empty():
			return
		match h["kind"]:
			"back":
				zoom_block = ""
				queue_redraw()
			"block":
				if g.state == "night":
					selected_block = h["id"]
				zoom_block = h["id"]
				queue_redraw()
				clicked.emit("block", h["id"])
			_:
				if h["kind"] == "npc":
					selected_npc = h["id"]
				clicked.emit(h["kind"], h["id"])
				queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = {}
		queue_redraw()
