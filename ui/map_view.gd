## The town map, drawn with _draw(). Overview of the four blocks and the roads between them;
## click a block to zoom in. In a block: buildings (locations), homes, crime scenes, and
## people as coloured dots. Emits `clicked(kind, id)` for the main UI to turn into commands:
## kind = "block" | "location" | "home" | "scene" | "npc" | "back".
##
## Visibility follows the game's rules (Game.can_see): people at work or in conversation are
## shown at their exact spot from anywhere; anyone else (out, or at home) only once you're on
## their block this phase. At night everyone is home.
extends Control

signal clicked(kind, id)

const C = preload("res://sim/content.gd")

# Layout in a virtual 1000 x 600 space.
const BLOCK_RECTS = {
	"market": Rect2(40, 30, 390, 230),
	"hill": Rect2(570, 30, 390, 230),
	"square": Rect2(300, 300, 400, 150),
	"docks": Rect2(220, 480, 560, 110),
}
const BLOCK_TINT = {
	"market": Color(0.20, 0.15, 0.12), "hill": Color(0.17, 0.17, 0.20),
	"square": Color(0.16, 0.18, 0.14), "docks": Color(0.12, 0.15, 0.20),
}
const OVERVIEW = Rect2(0, 0, 1000, 600)

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
	return int(clampf(base * _scale, 9.0, 30.0))

func _loc_rect(l: String) -> Rect2:
	var b: String = C.LOCATIONS[l]["block"]
	var R: Rect2 = BLOCK_RECTS[b]
	var locs: Array = C.LOCATIONS.keys().filter(func(x): return C.LOCATIONS[x]["block"] == b)
	var i = locs.find(l)
	return Rect2(R.position.x + R.size.x * (0.05 + 0.48 * i), R.position.y + R.size.y * 0.27, R.size.x * 0.42, R.size.y * 0.38)

## Which location a layout rect belongs to (if it's a building).
func _loc_of_rect(rect: Rect2) -> String:
	for l in C.LOCATIONS:
		if _loc_rect(l) == rect:
			return l
	return ""

func _street_rect(b: String) -> Rect2:
	var R: Rect2 = BLOCK_RECTS[b]
	return Rect2(R.position.x + R.size.x * 0.05, R.position.y + R.size.y * 0.63, R.size.x * 0.9, R.size.y * 0.10)

func _home_rect(n) -> Rect2:
	var b: String = n.home_block
	var R: Rect2 = BLOCK_RECTS[b]
	var residents: Array = g.w.npcs.filter(func(x): return x.home_block == b)
	var i = residents.find(n)
	var hs = minf(R.size.y * 0.2, 34.0)
	var gap = hs * 0.5
	var total = residents.size() * hs + (residents.size() - 1) * gap
	var x0 = R.position.x + (R.size.x - total) / 2.0
	return Rect2(x0 + i * (hs + gap), R.position.y + R.size.y - hs - 8, hs, hs)

func _block_center(b: String) -> Vector2:
	return BLOCK_RECTS[b].get_center()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_hits = []
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.07))
	if g == null:
		return
	_fit()
	var font = get_theme_default_font()
	var w = g.w
	var night = g.state == "night"
	# Roads.
	for road in C.ROADS:
		draw_line(_p(_block_center(road[0])), _p(_block_center(road[1])), Color(0.32, 0.28, 0.22), 14.0 * _scale)
		draw_line(_p(_block_center(road[0])), _p(_block_center(road[1])), Color(0.42, 0.37, 0.28), 6.0 * _scale)
	# Blocks.
	for b in BLOCK_RECTS:
		var R: Rect2 = _r(BLOCK_RECTS[b])
		var tint: Color = BLOCK_TINT[b]
		if night:
			tint = tint.darkened(0.45)
		draw_rect(R, tint)
		var border = Color(0.95, 0.85, 0.5) if (b == selected_block or (not night and g.moved and w.loc_block(g.loc) == b)) else Color(0.35, 0.35, 0.38)
		draw_rect(R, border, false, 2.0)
		draw_string(font, R.position + Vector2(8, 4 + _fs(17)), C.block_name(b).trim_prefix("the ").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(17), Color(0.85, 0.82, 0.7))
		if zoom_block == "":
			_hits.append({"rect": R, "kind": "block", "id": b, "label": C.block_name(b), "hint": "Click to look closer" if not night else "Click to choose it for your vigil"})
		# Locations.
		for l in C.LOCATIONS:
			if C.LOCATIONS[l]["block"] != b:
				continue
			var LR: Rect2 = _r(_loc_rect(l))
			draw_rect(LR, Color(0.30, 0.26, 0.22) if not night else Color(0.14, 0.12, 0.11))
			draw_rect(LR, Color(0.55, 0.48, 0.38), false, 1.5)
			# A simple roof.
			draw_colored_polygon(PackedVector2Array([LR.position, LR.position + Vector2(LR.size.x, 0), LR.position + Vector2(LR.size.x / 2.0, -LR.size.y * 0.18)]), Color(0.42, 0.24, 0.18) if not night else Color(0.2, 0.12, 0.1))
			draw_string(font, LR.position + Vector2(5, _fs(12) + 3), C.loc_name(l).trim_prefix("the "), HORIZONTAL_ALIGNMENT_LEFT, LR.size.x - 8, _fs(12), Color(0.9, 0.88, 0.8))
			if g.moved and g.loc == l and not night:
				draw_rect(LR.grow(3), Color(1, 1, 1), false, 2.0)
			if zoom_block != "":
				var hint = "Click to spend the phase here" if not g.moved else ("Click to step over (free move)" if not g.free_move_used and w.loc_block(g.loc) == b and g.loc != l else "")
				if g.state != "day":
					hint = ""
				_hits.append({"rect": LR, "kind": "location", "id": l, "label": C.loc_name(l), "hint": hint})
		# Homes (and crime scenes).
		for n in w.npcs:
			if n.home_block != b:
				continue
			var HR: Rect2 = _r(_home_rect(n))
			var col = C.npc_color(n.id)
			draw_rect(HR, Color(0.22, 0.2, 0.18) if not night else Color(0.25, 0.22, 0.12))
			draw_rect(HR, col.darkened(0.2), false, 2.0)
			draw_colored_polygon(PackedVector2Array([HR.position, HR.position + Vector2(HR.size.x, 0), HR.position + Vector2(HR.size.x / 2.0, -HR.size.y * 0.45)]), col.darkened(0.45))
			var sid = "scene_" + n.id
			if w.scenes.has(sid):
				draw_line(HR.position, HR.end, Color(0.85, 0.15, 0.15), 3.0)
				draw_line(HR.position + Vector2(HR.size.x, 0), HR.position + Vector2(0, HR.size.y), Color(0.85, 0.15, 0.15), 3.0)
			if zoom_block != "":
				if w.scenes.has(sid):
					_hits.append({"rect": HR, "kind": "scene", "id": sid, "label": w.scenes[sid]["name"] + " (crime scene)", "hint": "Click to go and search it" if g.state == "day" else ""})
				else:
					_hits.append({"rect": HR, "kind": "home", "id": n.id, "label": "%s's home" % n.name, "hint": ("Click to call on them" if n.alive and n.at_home() else "Click to knock") if g.state == "day" else ""})
	# People.
	_draw_people(font)
	# Back button and status.
	if zoom_block != "":
		var br = Rect2(Vector2(8, 8), Vector2(110, 28))
		draw_rect(br, Color(0.15, 0.15, 0.18))
		draw_rect(br, Color(0.5, 0.5, 0.55), false, 1.0)
		draw_string(font, br.position + Vector2(10, 19), "◀ Whole town", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.9))
		_hits.push_front({"rect": br, "kind": "back", "id": "", "label": "Back to the whole town", "hint": ""})
	var status = "Day %d · %s" % [w.day, "Night" if night else ("Town meeting" if g.state in ["meeting", "nomination"] else C.PHASES[w.phase])]
	draw_string(font, Vector2(size.x - 220, 24), status, HORIZONTAL_ALIGNMENT_RIGHT, 210, 15, Color(0.95, 0.9, 0.7))
	if not _hover.is_empty():
		var t = _hover["label"] + ((" — " + _hover["hint"]) if _hover.get("hint", "") != "" else "")
		var tr = Rect2(Vector2(8, size.y - 30), Vector2(minf(size.x - 16, 14 + t.length() * 7.5), 24))
		draw_rect(tr, Color(0, 0, 0, 0.7))
		draw_string(font, tr.position + Vector2(7, 17), t, HORIZONTAL_ALIGNMENT_LEFT, tr.size.x - 10, 13, Color(1, 1, 1))

## Where each living person is drawn, following what the player can actually see.
func _draw_people(font) -> void:
	var w = g.w
	var night = g.state == "night"
	var groups = {}  # virtual rect key -> [npc]
	var rects = {}
	for n in w.living():
		if not g.can_see(n):
			continue  # out of sight until the player is on their block
		var rect: Rect2
		var exact = true
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
		groups[key].append([n, exact])
	var r = maxf(5.0, 7.0 * _scale)
	for key in groups:
		var rect: Rect2 = rects[key]
		var members: Array = groups[key]
		# Space dots in screen units, wide enough for their labels when zoomed in, wrapping
		# into rows so a crowded building keeps everyone inside it.
		var sr: Rect2 = _r(rect)
		var lf = mini(_fs(12), 14)  # name label size under each dot
		var head = (minf(_fs(12), 30.0) + 6.0) if C.LOCATIONS.has(_loc_of_rect(rect)) else 0.0  # building name strip
		var area = Rect2(sr.position + Vector2(0, head), sr.size - Vector2(0, head))
		var step = maxf(2.0 * r + 8.0, (lf * 5.0) if zoom_block != "" else 2.0 * r + 8.0)
		var per_row = maxi(1, int(area.size.x / step))
		var rows = int(ceil(float(members.size()) / per_row))
		var row_h = (2.0 * r + lf + 6.0) if zoom_block != "" else 2.0 * r + 4.0
		var top_y = area.get_center().y - (rows - 1) * row_h / 2.0 - (float(lf) if zoom_block != "" else 0.0)
		for i in range(members.size()):
			var n = members[i][0]
			var exact: bool = members[i][1]
			var row = i / per_row
			var in_row = mini(per_row, members.size() - row * per_row)
			var x0 = sr.get_center().x - (in_row - 1) * step / 2.0
			var sp = Vector2(x0 + (i % per_row) * step, top_y + row * row_h)
			var col = C.npc_color(n.id)
			if not exact:
				col = col.darkened(0.25)
			draw_circle(sp, r + 2, Color(0, 0, 0, 0.6))
			draw_circle(sp, r, col)
			if n.busy_with != "":
				draw_arc(sp, r + 4, -0.6, 0.6, 8, Color(1, 1, 1, 0.8), 1.5)
			if n.id == selected_npc:
				draw_arc(sp, r + 5, 0, TAU, 24, Color(1, 1, 1), 2.0)
			if g.talk_with != null and g.talk_with == n:
				draw_arc(sp, r + 8, 0, TAU, 24, Color(0.95, 0.85, 0.4), 2.0)
			var label = n.name if zoom_block != "" else n.name.substr(0, 1)
			draw_string(font, sp + Vector2(-step / 2.0, r + lf + 1), label, HORIZONTAL_ALIGNMENT_CENTER, step, lf, col)
			var hint = ""
			if g.state == "day":
				hint = "busy talking" if n.busy_with != "" else ("click to talk" if not n.at_home() else "click to call on them")
			elif g.state == "night":
				hint = "click to choose them for your ward" if g.w.tools["ward"] > 0 else ""
			_hits.push_front({"rect": Rect2(sp - Vector2(r + 4, r + 4), Vector2(2 * r + 8, 2 * r + 8)), "kind": "npc", "id": n.id,
				"label": "%s the %s%s" % [n.name, n.occupation, "" if exact else " (somewhere on %s)" % C.block_name(w.loc_block(n.loc))], "hint": hint})

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
