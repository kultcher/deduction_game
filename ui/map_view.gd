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

# ---------------------------------------------------------------- bespoke base map (mock, Nov 7)
# One painted map (assets/art/map/town.png, 1536 x 1024) with fixed pads: the large pads take
# the buildings, the small ones the cottages. Coordinates below are image pixels.
const BESPOKE = true
const MAP_PX = Vector2(1536, 1024)
const MAP_TOP = 16.6          # the image spans the full 1000 wide, centred vertically in 700
const MAP_IMAGE = "map/town_open"   # the lot-less map: lots are drawn from assets/art/terrain
const MAP_BLOCKS = {          # each block's area on the image (for zoom, hits and highlights)
	"market": Rect2(0, 20, 600, 400),
	"hill": Rect2(880, 0, 656, 420),
	"square": Rect2(830, 400, 706, 420),
	"docks": Rect2(0, 640, 860, 384),
}
const MAP_PADS = {            # building lots: centre x, centre y, width, height, lot art ("" = painted on the map)
	"smithy": [440, 165, 230, 105, "terrain/dirt_b"], "bakery": [215, 300, 250, 115, "terrain/dirt_a"],
	"chapel": [1355, 268, 230, 125, "terrain/dirt_c"], "graveyard": [1160, 128, 290, 115, "terrain/grass_dirt"],
	"tavern": [1345, 548, 275, 161, ""], "town_hall": [1045, 715, 231, 171, ""], "well": [1180, 625, 120, 80, ""],
	"mill": [190, 775, 270, 130, "terrain/dirt_a"], "wharf": [615, 872, 280, 105, "terrain/dirt_b"],
}
const MAP_COTTAGES = {        # cottage lots per block: centre x, centre y
	"market": [[150, 140], [285, 132], [415, 300], [90, 330]],
	"hill": [[1010, 112], [1200, 262], [1360, 95]],
	"square": [[975, 470], [1080, 535], [1285, 745], [1385, 735]],
	"docks": [[405, 740], [300, 845], [90, 850]],
}
const MAP_STREETS = {         # a stretch of path on each block, for people out and about
	"market": Rect2(80, 175, 320, 50),
	"hill": Rect2(1180, 165, 200, 40),
	"square": Rect2(1120, 440, 300, 50),
	"docks": Rect2(60, 600, 300, 50),
}
const MAP_SIGNS = {           # where each block's name sign sits
	"market": Vector2(330, 30), "hill": Vector2(1110, 170), "square": Vector2(1260, 420), "docks": Vector2(400, 612),
}
const PAPER_ART = {
	"bakery": "buildings_paper/bakery", "smithy": "buildings_paper/smithy",
	"tavern": "buildings_paper/tavern", "well": "buildings_paper/well",
	"chapel": "buildings_paper/chapel", "graveyard": "buildings_paper/graveyard",
	"wharf": "buildings_paper/wharf", "mill": "buildings_paper/mill",
	"town_hall": "buildings_paper/town_hall",
}

static func _px(v: Vector2) -> Vector2:
	return Vector2(v.x * 1000.0 / MAP_PX.x, MAP_TOP + v.y * 1000.0 / MAP_PX.x)

static func _px_rect(r: Rect2) -> Rect2:
	return Rect2(_px(r.position), r.size * 1000.0 / MAP_PX.x)

static func _block_rect(b: String) -> Rect2:
	return _px_rect(MAP_BLOCKS[b]) if BESPOKE else BLOCK_RECTS[b]
const BUILDING_ART = {"tavern": "tavern", "well": "well", "smithy": "smithy", "bakery": "bakery",
	"wharf": "wharf", "mill": "mill", "chapel": "chapel", "graveyard": "graveyard", "town_hall": "town_hall"}
## Shorter signs for blocks with three buildings (the Square with the Town Hall), so
## neighbouring signs don't overlap. Hover labels keep the full name.
const SHORT_SIGNS = {"tavern": "Tavern"}

var g
var zoom_block = ""
var selected_npc = ""        # persistent highlight owned by the townsfolk panel
var selected_block = ""
var _hits: Array = []        # [{rect (screen), kind, id, label, hint}]
var _hover: Dictionary = {}
var _label_obstacles: Array = [] # Screen-space signs/accepted names, rebuilt per draw.
var _name_labels: Array = [] # Visible name rectangles, also used by layout checks.
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
		return _block_rect(zoom_block).grow(24)
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

func _map_buildings_on(b: String) -> Array:
	var locs: Array = C.LOCATIONS.keys().filter(func(x): return C.LOCATIONS[x]["block"] == b)
	for pb in C.PLAYER_BUILDINGS.keys():
		if C.PLAYER_BUILDINGS[pb]["block"] == b:
			locs.append(pb)
	return locs

func _loc_rect(l: String) -> Rect2:
	if BESPOKE and MAP_PADS.has(l):
		var p: Array = MAP_PADS[l]
		var w: float = p[2] * 0.78
		var bottom: float = p[1] + p[3] * 0.32
		var h: float = minf(p[3] * 1.35, bottom - 8.0)   # pads at the top edge: keep the roof on the map
		return _px_rect(Rect2(p[0] - w / 2.0, bottom - h, w, h))
	var b: String = C.loc_block(l)
	var R: Rect2 = BLOCK_RECTS[b]
	var locs: Array = _map_buildings_on(b)
	var i = locs.find(l)
	if locs.size() >= 3:
		return Rect2(R.position.x + R.size.x * (0.04 + 0.31 * i), R.position.y + R.size.y * 0.12, R.size.x * 0.28, R.size.y * 0.46)
	return Rect2(R.position.x + R.size.x * (0.06 + 0.48 * i), R.position.y + R.size.y * 0.12, R.size.x * 0.42, R.size.y * 0.46)

## Which location a layout rect belongs to (if it's a building).
func _loc_of_rect(rect: Rect2) -> String:
	for l in C.LOCATIONS.keys() + C.PLAYER_BUILDINGS.keys():
		if _loc_rect(l) == rect:
			return l
	return ""

func _street_rect(b: String) -> Rect2:
	if BESPOKE:
		return _px_rect(MAP_STREETS[b])
	var R: Rect2 = BLOCK_RECTS[b]
	return Rect2(R.position.x + R.size.x * 0.08, R.position.y + R.size.y * 0.6, R.size.x * 0.84, R.size.y * 0.14)

func _home_rect(n) -> Rect2:
	if BESPOKE:
		var slots: Array = MAP_COTTAGES[n.home_block]
		var mine: Array = g.w.npcs.filter(func(x): return x.home_block == n.home_block)
		var k: int = mine.find(n)
		var c: Array = slots[k % slots.size()]
		var over: float = 40.0 * (k / slots.size())   # more residents than pads: nudge the extras
		var sz: float = 78.0
		return _px_rect(Rect2(c[0] - sz / 2.0 + over, c[1] + 22 - sz - over * 0.4, sz, sz))
	var b: String = n.home_block
	var R: Rect2 = BLOCK_RECTS[b]
	var residents: Array = g.w.npcs.filter(func(x): return x.home_block == b)
	var i = residents.find(n)
	var hs = minf(R.size.y * 0.2, 46.0)
	var gap = hs * 0.35
	# One row along the bottom; a crowded block (bigger towns) shrinks the cottages, then
	# starts a second row above.
	var per_row = maxi(1, int((R.size.x * 0.92 + gap) / (hs + gap)))
	if residents.size() > per_row:
		hs = minf(hs, (R.size.x * 0.92) / (residents.size() * 1.35))
		gap = hs * 0.35
		hs = maxf(hs, 30.0)
		gap = hs * 0.35
		per_row = maxi(1, int((R.size.x * 0.92 + gap) / (hs + gap)))
	var row = i / per_row
	var in_row = mini(per_row, residents.size() - row * per_row)
	var total = in_row * hs + (in_row - 1) * gap
	var x0 = R.position.x + (R.size.x - total) / 2.0
	return Rect2(x0 + (i % per_row) * (hs + gap), R.position.y + R.size.y - hs - 8 - row * (hs + 4), hs, hs)

func _block_center(b: String) -> Vector2:
	return _block_rect(b).get_center()

## A road's course in virtual coordinates. The outer roads to the Docks run down the
## sides of the map and in along the bottom, clear of the Square.
func _road_points(a: String, b: String) -> Array:
	var key = [a, b]
	key.sort()
	if key == ["docks", "market"] or key == ["docks", "hill"]:
		var top: String = key[1]
		var tr: Rect2 = BLOCK_RECTS[top]
		var dr: Rect2 = BLOCK_RECTS["docks"]
		var x: float = tr.get_center().x
		var y: float = dr.get_center().y
		var dx: float = dr.position.x if top == "market" else dr.end.x
		return [tr.get_center(), Vector2(x, y), Vector2(dx + (40.0 if top == "market" else -40.0), y)]
	return [_block_center(a), _block_center(b)]

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

func _sign(font, text: String, center: Vector2, fs: int, active: bool = false, is_obstacle: bool = true) -> Rect2:
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
	if is_obstacle:
		_label_obstacles.append(r)
	return r

func _draw() -> void:
	_hits = []
	_label_obstacles.clear()
	_name_labels.clear()
	if g == null:
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.color("bg"))
		return
	_fit()
	var font = get_theme_default_font()
	var w = g.w
	var night = g.state == "night"
	var tint = Color(0.5, 0.55, 0.85) if night else Color.WHITE
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.14) if night else Color(0.12, 0.16, 0.18))
	if BESPOKE:
		var base_map = _art(MAP_IMAGE, 1.0)
		if base_map != null:
			draw_texture_rect(base_map, _r(_px_rect(Rect2(Vector2.ZERO, MAP_PX))), false, tint)
		# Lots: dirt under the buildings and the cottages.
		for l in MAP_PADS:
			var pad: Array = MAP_PADS[l]
			if pad[4] != "":
				var lt = _art(pad[4], 0.5)
				if lt != null:
					draw_texture_rect(lt, _r(_px_rect(Rect2(pad[0] - pad[2] / 2.0, pad[1] - pad[3] / 2.0, pad[2], pad[3]))), false, tint)
		var cot_lot = _art("terrain/dirt_c", 0.3)
		for b in MAP_COTTAGES:
			for c in MAP_COTTAGES[b]:
				if cot_lot != null:
					draw_texture_rect(cot_lot, _r(_px_rect(Rect2(c[0] - 48, c[1] - 26, 96, 56))), false, tint)
	# Dressing behind everything.
	for d in ([] if BESPOKE else DECOR):
		var t = _art("decor/" + d[0], 0.4)
		if t != null:
			var hh: float = d[2]
			var ww = hh * t.get_width() / t.get_height()
			_draw_art(t, _r(Rect2(d[1] - Vector2(ww / 2.0, 0), Vector2(ww, hh))), "contain", tint)
	# Roads: sandy paths with a dark edge, and a lamp halfway along.
	for road in ([] if BESPOKE else C.ROADS):
		var pts: Array = _road_points(road[0], road[1])
		for i in range(pts.size() - 1):
			var a = _p(pts[i])
			var b2 = _p(pts[i + 1])
			draw_line(a, b2, Color(0.2, 0.17, 0.12), 26.0 * _scale)
			draw_line(a, b2, Color(0.78, 0.66, 0.45) * tint, 20.0 * _scale)
		for i in range(1, pts.size() - 1):
			draw_circle(_p(pts[i]), 10.0 * _scale, Color(0.78, 0.66, 0.45) * tint)
		var lamp = _art("decor/lamp", 0.3)
		if lamp != null:
			var mid: Vector2 = pts[1] if pts.size() > 2 else (pts[0] + pts[1]) / 2.0
			mid += Vector2(18, -10)
			_draw_art(lamp, _r(Rect2(mid - Vector2(10, 48), Vector2(20, 48))), "contain", Color(1, 1, 1) if not night else Color(1, 0.95, 0.75))
	var unseen_badges: Array = []
	# Blocks.
	for b in BLOCK_RECTS:
		var R: Rect2 = _r(_block_rect(b))
		var here = not night and g.moved and w.loc_block(g.loc) == b
		if not BESPOKE:
			var base = _art("blocks/" + b, 0.6)
			if base != null:
				_draw_art(base, R, "cover", tint)
			else:
				draw_rect(R, BLOCK_TINT[b] if not night else BLOCK_TINT[b].darkened(0.45))
			var border = UITheme.color("accent") if (b == selected_block or here) else Color(0.12, 0.1, 0.08, 0.8)
			draw_rect(R, border, false, 3.0 if (b == selected_block or here) else 2.0)
		elif b == selected_block or here:
			draw_rect(R, UITheme.color("accent"), false, 3.0)
		if zoom_block == "":
			_hits.append({"rect": R, "kind": "block", "id": b, "label": C.block_name(b), "hint": "Click to look closer" if not night else "Click to choose it for your vigil"})
		# Locations and player-only buildings (the Town Hall): building sprites with a name sign.
		for l in _map_buildings_on(b):
			var LR: Rect2 = _r(_loc_rect(l))
			var art = _art(PAPER_ART[l], 0.5) if BESPOKE and PAPER_ART.has(l) else _art("buildings/" + BUILDING_ART.get(l, "cottage_red"), 0.5)
			var drawn = _draw_art(art, LR.grow_individual(0, LR.size.y * 0.1, 0, 0), "contain", tint) if art != null else LR
			if art == null:
				draw_rect(LR, Color(0.3, 0.26, 0.22) * tint)
				draw_rect(LR, UITheme.color("border"), false, 1.5)
			var here_l = g.moved and g.loc == l and not night
			var sign_r = drawn
			if zoom_block != "" or _scale > 0.9:
				var sign_txt: String = C.loc_name(l).trim_prefix("the ").capitalize()
				if _map_buildings_on(b).size() >= 3:
					sign_txt = SHORT_SIGNS.get(l, sign_txt)
				sign_r = _sign(font, sign_txt, Vector2(drawn.get_center().x, drawn.end.y - 4), _fs(11), here_l, false)
			elif here_l:
				draw_rect(drawn.grow(2), UITheme.color("accent"), false, 2.0)
			# Someone's there you can't see yet: a count, not a name.
			var unseen = g.unseen_at_ui(l) if g.state in ["day", "talk", "approach"] else 0
			if unseen > 0:
				unseen_badges.append({"center": Vector2(sign_r.end.x + 6, sign_r.position.y - 2), "count": unseen})
			if zoom_block != "":
				var hint = "Click to spend the phase here" if not g.moved else ("Click to step over (free move)" if not g.free_move_used and w.loc_block(g.loc) == b and g.loc != l else "")
				if g.state != "day":
					hint = ""
				var un = g.unseen_at_ui(l)
				var lbl = C.loc_name(l) + ((" (%d more there you can't see from here)" % un) if un > 0 else "")
				_hits.append({"rect": LR, "kind": "location", "id": l, "label": lbl, "hint": hint})
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
			elif not n.alive:
				draw_line(hd.position, hd.end, Color(0.2, 0.55, 0.95), 3.0)
				draw_line(hd.position + Vector2(hd.size.x, 0), hd.position + Vector2(0, hd.size.y), Color(0.2, 0.55, 0.95), 3.0)
			if zoom_block != "":
				if w.scenes.has(sid):
					_hits.append({"rect": HR, "kind": "scene", "id": sid, "label": w.scenes[sid]["name"] + " (crime scene)", "hint": "Click to go and search it" if g.state == "day" else ""})
				else:
					var home_hint = ""
					if g.state == "day":
						if not (n.alive and n.at_home()):
							home_hint = "nobody's in; you can only call on someone who's home"
						elif g.moved and (g.free_move_used or w.loc_block(g.loc) != b):
							home_hint = "they're in, but you've already chosen where to spend this phase"
						else:
							home_hint = "click to call on them" + (" (free move)" if g.moved else "")
					_hits.append({"rect": HR, "kind": "home", "id": n.id, "label": "%s's home" % n.name, "hint": home_hint})
		# The block's name on a sign.
		var sign_at: Vector2 = _p(_px(MAP_SIGNS[b])) + Vector2(0, _fs(16)) if BESPOKE else Vector2(R.get_center().x, R.position.y + _fs(16))
		_sign(font, C.block_name(b).trim_prefix("the "), sign_at, _fs(15), b == selected_block)
	if night:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.1, 0.25))
	_draw_selection_marks()
	# Reserve the back control before placing names (it is painted afterwards).
	if zoom_block != "": _label_obstacles.append(Rect2(0, 0, 150, 46))
	# People.
	_draw_people(font)
	# Draw unseen (+N) location badges above standees so they are never tucked behind sprites.
	for bdg in unseen_badges:
		var bc: Vector2 = bdg["center"]
		var br = maxf(9.0, 11.0 * _scale)
		draw_circle(bc, br, UITheme.color("red"))
		draw_arc(bc, br, 0, TAU, 20, UITheme.color("border"), 1.5)
		draw_string(font, Vector2(bc.x - br, bc.y + br * 0.4), "+%d" % bdg["count"], HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, int(br * 1.1), UITheme.color("paper"))
	# Zoomed in: dim everything outside the block in view.
	if zoom_block != "" and BLOCK_RECTS.has(zoom_block):
		var Z: Rect2 = _r(_block_rect(zoom_block))
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
		var tw = font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24
		var tr = Rect2(Vector2(8, size.y - 32), Vector2(minf(size.x - 16, tw), 26))
		draw_style_box(UITheme.flat(UITheme.color("paper"), UITheme.color("border"), 1, 3, 4), tr)
		draw_string(font, tr.position + Vector2(9, 18), t2, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x - 12, 16, UITheme.color("ink"))

## The selected person's places: home and workplace in their colour, the haunts you've been
## told about in a fainter version of it.
func _draw_selection_marks() -> void:
	if selected_npc == "" or not g.w.by_id.has(selected_npc):
		return
	var n = g.w.by_id[selected_npc]
	var col: Color = C.npc_color(n.id)
	var w2 = maxf(2.0, 3.0 * _scale)
	draw_rect(_r(_home_rect(n)).grow(4), col, false, w2)
	if C.LOCATIONS.has(n.work):
		draw_rect(_r(_loc_rect(n.work)).grow(3), col, false, w2)
	for l in g.known_haunts.get(n.id, []):
		if C.LOCATIONS.has(l):
			draw_rect(_r(_loc_rect(l)).grow(3), Color(col.r, col.g, col.b, 0.45), false, maxf(1.5, 2.0 * _scale))

## Where each living person is drawn, following what the player can actually see: a paper
## standee of them at their building, in the street, or at their home.
func _draw_people(font) -> void:
	var w = g.w
	var night = g.state == "night"
	var groups = {}  # virtual rect key -> [npc]
	var rects = {}
	for n in w.living():
		if not g.can_see_ui(n):
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
		# A crowd at one spot spreads a little wider than the building and shrinks to fit in
		# one row, rather than stacking standees on top of each other.
		var hh = h
		var avail = maxf(sr.size.x * 1.5, h * 1.8)
		if members.size() * hh * 0.78 > avail:
			hh = maxf(h * 0.55, avail / (members.size() * 0.78))
		var step = hh * 0.78
		var per_row = maxi(1, int(avail / step))
		var base_y = sr.end.y - (hh * 0.1 if C.LOCATIONS.has(_loc_of_rect(rect)) else -hh * 0.15)
		for i in range(members.size()):
			var n = members[i]
			var row = i / per_row
			var in_row = mini(per_row, members.size() - row * per_row)
			var x0 = sr.get_center().x - (in_row - 1) * step / 2.0
			var foot = Vector2(x0 + (i % per_row) * step, base_y - row * hh * 0.55)
			var t = _art("standees/" + n.id, 0.3)
			var rr = Rect2(foot - Vector2(hh * 0.4, hh), Vector2(hh * 0.8, hh))
			draw_circle(foot + Vector2(0, -2), hh * 0.3, Color(0, 0, 0, 0.35))
			if t != null:
				rr = _draw_art(t, rr, "contain", Color(0.75, 0.78, 1.0) if night else Color.WHITE)
			else:
				draw_circle(rr.get_center(), hh * 0.3, C.npc_color(n.id))
			if n.busy_with != "":
				draw_arc(rr.position + Vector2(rr.size.x * 0.85, rr.size.y * 0.15), hh * 0.12, 0, TAU, 12, Color(1, 1, 1, 0.9), 2.0)
			if n.id == selected_npc:
				draw_rect(rr.grow(3), C.npc_color(n.id), false, 3.0)
				draw_rect(rr.grow(1), Color(1, 1, 1, 0.9), false, 1.5)
			var person_block: String = n.home_block if night or n.at_home() else w.loc_block(n.loc)
			if zoom_block != "" and person_block == zoom_block:
				var lfs = lf if members.size() <= 2 else maxi(11, int(lf * 0.85))
				var width: float = font.get_string_size(n.name, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 8
				var desired = Rect2(Vector2(foot.x - width / 2.0, foot.y + 2 + (lfs if (i % 2 == 1 and members.size() > 2) else 0)), Vector2(width, lfs + 5))
				var label_bounds = Rect2(Vector2(4, 4), size - Vector2(8, 40))
				if BLOCK_RECTS.has(zoom_block): label_bounds = label_bounds.intersection(_r(_block_rect(zoom_block)).grow(-4))
				var label = name_label_rect(desired, _label_obstacles, label_bounds)
				_label_obstacles.append(label)
				_name_labels.append({"id": n.id, "rect": label})
				draw_style_box(UITheme.flat(Color(0.06, 0.07, 0.1, 0.82), Color(0.25, 0.22, 0.18, 0.65), 1, 4, 2), label)
				draw_string(font, label.position + Vector2(0, lfs), n.name, HORIZONTAL_ALIGNMENT_CENTER, label.size.x, lfs, C.npc_color(n.id))
			var hint = ""
			if g.state == "day":
				hint = "busy talking; click to inspect their profile" if n.busy_with != "" else "click to inspect their profile"
			elif g.state == "night":
				hint = "click to choose them for your ward" if g.w.tools["ward"] > 0 else ""
			_hits.push_front({"rect": rr, "kind": "npc", "id": n.id, "label": "%s the %s" % [n.name, n.occupation], "hint": hint})

## Search nearest rows first, then columns, keeping names off place signs and
## preceding names. This uses screen geometry only; portraits/hit targets stay put.
static func name_label_rect(desired: Rect2, obstacles: Array, bounds: Rect2) -> Rect2:
	var width = minf(desired.size.x, bounds.size.x)
	var start = Vector2(clampf(desired.position.x, bounds.position.x, bounds.end.x - width), clampf(desired.position.y, bounds.position.y, bounds.end.y - desired.size.y))
	var step = desired.size.y + 4.0
	var rows = int(ceil(bounds.size.y / step))
	var columns = int(ceil(bounds.size.x / (width + 4.0)))
	for distance in range(rows + columns + 1):
		for column in range(-mini(distance, columns), mini(distance, columns) + 1):
			var row = distance - absi(column)
			for direction in ([1] if row == 0 else [1, -1]):
				var candidate = Rect2(start + Vector2(column * (width + 4.0), row * direction * step), Vector2(width, desired.size.y))
				if bounds.encloses(candidate) and not obstacles.any(func(r): return r.grow(2).intersects(candidate)):
					return candidate
	return Rect2(start, Vector2(width, desired.size.y)) # Extremely crowded/tiny view: retain the name.

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
			clicked.emit("back", "")
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
				clicked.emit("back", "")
			"block":
				if g.state == "night":
					selected_block = h["id"]
				zoom_block = h["id"]
				queue_redraw()
				clicked.emit("block", h["id"])
			_:
				clicked.emit(h["kind"], h["id"])
				queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = {}
		queue_redraw()
