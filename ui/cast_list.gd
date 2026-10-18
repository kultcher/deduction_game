## The townsfolk list on the town screen: one paper plaque per person with their portrait
## in a ring, their colour, what they claim and your guess (pencilled, with a "?"), and where
## they are if you can see them. Dead townsfolk are greyed with a cross. Click to show them
## in the profile.
extends Control

signal person_clicked(id)

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")

const ROW_H = 62.0
const GAP = 6.0

var g
var selected = ""
var _rows: Array = []   # {rect, id}
var _hover = ""
var _font: Font

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "
	_font = UITheme.serif()

func setup(game) -> void:
	g = game
	custom_minimum_size = Vector2(0, g.w.npcs.size() * (ROW_H + GAP))
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	_rows = []
	if g == null:
		return
	var y = 0.0
	for n in g.w.npcs:
		var r = Rect2(0, y, size.x, ROW_H)
		y += ROW_H + GAP
		_rows.append({"rect": r, "id": n.id})
		var sel = n.id == selected
		var plaque = UITheme.nine("ui/plaque_red" if sel else ("ui/plaque_gold" if n.id == _hover else "ui/plaque_cream"), ROW_H - 8, [12, 10, 12, 10])
		var pr = Rect2(r.position + Vector2(ROW_H * 0.55, 4), Vector2(r.size.x - ROW_H * 0.55, ROW_H - 8))
		if plaque != null:
			draw_style_box(plaque, pr)
		else:
			draw_rect(pr, UITheme.color("paper"))
		var tint = Color.WHITE if n.alive else Color(0.5, 0.48, 0.48)
		# Portrait in a gold ring.
		var c = r.position + Vector2(ROW_H / 2.0, ROW_H / 2.0)
		var rad = ROW_H / 2.0 - 2
		draw_circle(c, rad, C.npc_color(n.id).darkened(0.35))
		var tex = UITheme.tex("art/portraits/" + n.id, 0.18)
		if tex != null:
			var s = rad * 2.0 - 6
			var src_h = minf(tex.get_height(), tex.get_width() * 1.0)
			draw_texture_rect_region(tex, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), Rect2(0, 0, tex.get_width(), src_h), tint)
		var ring = UITheme.tex("ui/ring_gold", 0.3)
		if ring != null:
			draw_texture_rect(ring, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false)
		else:
			draw_arc(c, rad, 0, TAU, 32, UITheme.color("border"), 2.0)
		# Name, colour dot, status.
		var ink = UITheme.color("paper") if sel else UITheme.ink_of(C.npc_color(n.id))
		var tx = r.position.x + ROW_H + 6
		draw_circle(Vector2(tx + 4, pr.position.y + 16), 5, C.npc_color(n.id))
		draw_string(_font, Vector2(tx + 14, pr.position.y + 22), n.name + ("" if n.alive else "  †"), HORIZONTAL_ALIGNMENT_LEFT, pr.end.x - tx - 50, 18, ink if (n.alive or sel) else UITheme.color("ink_soft"))
		var sub = _sub_line(n)
		draw_string(_font, Vector2(tx, pr.end.y - 12), sub, HORIZONTAL_ALIGNMENT_LEFT, pr.end.x - tx - 40, 13, UITheme.color("paper_dim") if sel else UITheme.color("ink_soft"))
		# Claim icon (their word) and your guess (pencilled, with a question mark).
		var ix = pr.end.x - 30
		var claim = _claimed(n)
		if claim != "":
			var ct = UITheme.tex("ui/roles/" + claim, 0.06)
			if ct != null:
				draw_texture(ct, Vector2(ix - 26, pr.position.y + (pr.size.y - ct.get_height()) / 2.0))
		var gs: String = g.guesses.get(n.id, {}).get("guess", "?")
		if gs != "?":
			var gt = UITheme.tex("ui/roles/" + gs, 0.05) if C.ROLES.has(gs) else null
			var gp = Vector2(ix + 2, pr.position.y + 8)
			if gt != null:
				draw_texture(gt, gp, Color(1, 1, 1, 0.75))
			else:
				draw_string(_font, gp + Vector2(0, 14), gs, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UITheme.color("red"))
			draw_string(_font, gp + Vector2(14, 30), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.color("red"))

func _claimed(n) -> String:
	if n.claim_public or n.max_tier >= 3:
		return n.claimed_role if C.ROLES.has(n.claimed_role) else ""
	if n.claimed_role == "none":
		return "none"
	return ""

func _sub_line(n) -> String:
	if not n.alive:
		return "killed, night %d" % n.death_day if n.death_cause == "demon" else "executed, day %d" % n.death_day
	var parts: Array = []
	if n.claim_public:
		parts.append("claims " + C.role_name(n.claimed_role))
	elif n.max_tier >= 3 and C.ROLES.has(n.claimed_role):
		parts.append("told you: " + C.role_name(n.claimed_role))
	if g.state != "night" and g.can_see(n):
		parts.append(("at home" if n.at_home() else g.w.loc_name(n.loc).trim_prefix("the ")))
	return " · ".join(PackedStringArray(parts)) if not parts.is_empty() else n.occupation

func _row_at(p: Vector2) -> String:
	for r in _rows:
		if r["rect"].has_point(p):
			return r["id"]
	return ""

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id = _row_at(ev.position)
		if id != "":
			selected = id
			person_clicked.emit(id)
			queue_redraw()
	elif ev is InputEventMouseMotion:
		var h = _row_at(ev.position)
		if h != _hover:
			_hover = h
			queue_redraw()

func _get_tooltip(at: Vector2) -> String:
	var id = _row_at(at)
	if id == "" or g == null:
		return ""
	var n = g.w.by_id[id]
	var gs: String = g.guesses.get(id, {}).get("guess", "?")
	return "%s the %s. %s%s" % [n.name, n.occupation, _sub_line(n), (" · your guess: %s?" % (C.role_name(gs) if C.ROLES.has(gs) else gs)) if gs != "?" else ""]
