## The townsfolk list on the town screen: one paper plaque per person with their portrait
## in a ring, their colour, what they claim and your guess (pencilled, with a "?"), and where
## they are if you can see them. Dead townsfolk are greyed with a cross. Click to show
## their profile and toggle the map highlight; only this panel owns that highlight.
extends Control

signal person_clicked(id)

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const PortraitBadge = preload("res://ui/portrait_badge.gd")

const ROW_H = 70.0
const GAP = 2.0

var g
var selected = ""
var _rows: Array = []   # {rect, id}
var _hover = ""
var _font: Font
var _portraits: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "
	_font = UITheme.serif()

func setup(game) -> void:
	g = game
	selected = ""
	_hover = ""
	for badge in _portraits.values():
		badge.hide()
		badge.queue_free()
	_portraits.clear()
	for n in g.w.npcs:
		var badge = PortraitBadge.new()
		add_child(badge)
		badge.show_person(n.id, n.alive)
		_portraits[n.id] = badge
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
		var plaque = UITheme.nine("ui/plaque_red" if sel else ("ui/plaque_gold" if n.id == _hover else "ui/plaque_cream"), ROW_H - 12, [12, 10, 12, 10])
		var pr = Rect2(r.position + Vector2(ROW_H * 0.55, 6), Vector2(r.size.x - ROW_H * 0.55, ROW_H - 12))
		if plaque != null:
			draw_style_box(plaque, pr)
		else:
			draw_rect(pr, UITheme.color("paper"))
		var badge = _portraits[n.id]
		badge.position = r.position + Vector2(2, 2)
		badge.size = Vector2(ROW_H - 4, ROW_H - 4)
		badge.show_person(n.id, n.alive)
		# Keep text inside the decorative edges; reserve only occupied role slots.
		var ink = UITheme.color("paper") if sel else UITheme.ink_of(C.npc_color(n.id))
		var tx = r.position.x + ROW_H + 12
		var slot = 24.0
		var claim = _claimed(n)
		var relayed = _relayed_claim(n) if not (n.claim_public or n.max_tier >= 3 or n.claimed_role == "none") else {}
		var gs: String = g.guesses.get(n.id, {}).get("guess", "?")
		var slot_count = int(claim != "") + int(gs != "?")
		var slots_x = pr.end.x - 20 - slot_count * (slot + 4)
		var text_w = maxf(0, slots_x - tx - (8 if slot_count > 0 else 0))
		draw_circle(Vector2(tx + 4, pr.position.y + 21), 4, C.npc_color(n.id))
		var name_w = maxf(0, text_w - 14)
		draw_string(_font, Vector2(tx + 14, pr.position.y + 26), _fit_text(n.name + ("" if n.alive else "  +"), name_w, 17), HORIZONTAL_ALIGNMENT_LEFT, name_w, 17, ink if (n.alive or sel) else UITheme.color("ink_soft"))
		draw_string(_font, Vector2(tx, pr.end.y - 12), _fit_text(_sub_line(n), text_w, 13), HORIZONTAL_ALIGNMENT_LEFT, text_w, 13, UITheme.color("paper_dim") if sel else UITheme.color("ink_soft"))
		var cy = pr.position.y + (pr.size.y - slot) / 2.0
		if claim != "":
			_role_mark(claim, Rect2(slots_x, cy, slot, slot), Color(1, 1, 1, 0.65) if not relayed.is_empty() else Color.WHITE, sel)
			if not relayed.is_empty():
				draw_string(_font, Vector2(slots_x + slot - 6, cy + slot + 2), "~", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
			slots_x += slot + 4
		if gs != "?":
			var gr = Rect2(slots_x, cy, slot, slot)
			_role_mark(gs, gr, Color(1, 1, 1, 0.75), sel)
			draw_string(_font, Vector2(gr.end.x - 6, gr.end.y + 2), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.color("red"))

func _fit_text(text: String, width: float, font_size: int) -> String:
	if width <= 0:
		return ""
	if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var clipped = text
	while not clipped.is_empty():
		clipped = clipped.left(-1)
		if _font.get_string_size(clipped + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
			return clipped + "…"
	return ""

## A role's icon in a square slot, or (for gifts without art yet, and good/evil guesses) a
## small tag with the first letters.
func _role_mark(role: String, rect: Rect2, tint: Color, sel: bool) -> void:
	var t = UITheme.tex("ui/roles/" + role, 0.06) if C.ROLES.has(role) or role == "none" else null
	if t != null:
		var ts = Vector2(t.get_width(), t.get_height())
		var k = minf(rect.size.x / ts.x, rect.size.y / ts.y)
		var sz = ts * k
		draw_texture_rect(t, Rect2(rect.get_center() - sz / 2.0, sz), false, tint)
		return
	var label = (C.role_name(role) if C.ROLES.has(role) else role).substr(0, 4)
	var col = UITheme.color("red") if role in ["evil", "demon"] or C.is_minion(role) else UITheme.color("ink_soft")
	draw_style_box(UITheme.flat(Color(1, 1, 1, 0.0), col, 1, 3, 1), rect.grow(-3))
	draw_string(_font, Vector2(rect.position.x, rect.get_center().y + 4), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, UITheme.color("paper") if sel else col)

func _claimed(n) -> String:
	if n.claim_public or n.max_tier >= 3:
		return n.claimed_role if C.ROLES.has(n.claimed_role) else ""
	if n.claimed_role == "none":
		return "none"
	return _relayed_claim(n).get("role", "")

## Only claims already on the player's board count; NPC private knowledge is not a UI source.
func _relayed_claim(n) -> Dictionary:
	for i in range(g.board.size() - 1, -1, -1):
		var card: Dictionary = g.board[i]
		if card.get("deleted", false) or card.get("kind", "") != "claim" or card.get("source", "") != n.id:
			continue
		var role: String = card.get("role", "")
		if not C.ROLES.has(role) and role != "none":
			continue
		var via: Array = []
		for disclosure in card.get("learned", []):
			var speaker: String = disclosure.get("via", "")
			if speaker != n.id and g.w.by_id.has(speaker) and speaker not in via:
				via.append(speaker)
		var speaker: String = card.get("via", "")
		if speaker != n.id and g.w.by_id.has(speaker) and speaker not in via:
			via.append(speaker)
		if not via.is_empty():
			return {"role": role, "via": via}
	return {}

func _sub_line(n) -> String:
	if not n.alive:
		if n.death_cause == "martyr":
			return "died in another's place, day %d" % n.death_day
		return "killed, night %d" % n.death_day if n.death_cause == "demon" else "executed, day %d" % n.death_day
	if g.state == "night" or not g.can_see(n):
		return "at Unknown"
	var place = "home" if n.at_home() else g.w.loc_name(n.loc).trim_prefix("the ")
	return "at " + place

func _row_at(p: Vector2) -> String:
	for r in _rows:
		if r["rect"].has_point(p):
			return r["id"]
	return ""

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id = _row_at(ev.position)
		if id != "":
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
	var claim = ""
	if not (n.claim_public or n.max_tier >= 3 or n.claimed_role == "none"):
		var relayed = _relayed_claim(n)
		if not relayed.is_empty():
			claim = " · ~ hearsay via %s: claims %s" % [", ".join(PackedStringArray(relayed.via.map(func(who): return g.w.by_id[who].name))), C.role_name(relayed.role)]
	return "%s the %s. %s%s%s" % [n.name, n.occupation, _sub_line(n), claim, (" · your guess: %s?" % (C.role_name(gs) if C.ROLES.has(gs) else gs)) if gs != "?" else ""]
