## Freeform cards and strings. Input only edits the separate canvas model.
extends Control
signal selected(id: String)
signal answer_requested(id: String)
signal link_requested(id: String)
signal context_requested(id: String)
signal layout_changed
signal cards_dropped(numbers: Array)     # board cards dragged onto the Workshop
signal removal_requested(id: String)     # a card dragged out past the left edge
signal field_requested(id: String, field: String)  # a field on a card was clicked
const CanvasSkin = preload("res://ui/theme.gd")
const Solver = preload("res://workshop/solver.gd")
const C = preload("res://sim/content.gd")
var model
var zoom = 0.85
var pan = Vector2(50, 10)
var linking = ""
var hit: Dictionary = {}
var drag = ""
var panning = false
var last_mouse = Vector2.ZERO
var drag_out = false   # the dragged card is past the left edge: release removes it
var fields: Dictionary = {}   # id -> [{rect, field}] clickable fields, in screen space
var tips: Array = []          # [{rect, text}] tooltips for drawn badges and fields
var answer_buttons: Dictionary = {}   # id -> screen rect of the card's Details/Assume button
var badges: Dictionary = {}   # id -> {category, text, reason, ready, issues} from the test juror
var detail_label: Callable    # (node) -> {text, icon}: the premise's extra field, if any
const PREMISE_H = 236.0
const STRENGTH_COLORS = {"empty": Color("8a8378"), "contradicts": Color("b55a4c"), "none": Color("8a8378"), "weak": Color("c98a3d"), "moderate": Color("c9b03d"), "strong": Color("5f9a55")}
const STRENGTH_TEXT = {"empty": "No evidence", "contradicts": "Argues against", "none": "Doesn't support", "weak": "Weak", "moderate": "Moderate", "strong": "Strong"}
var font: Font = CanvasSkin.serif()
const WIDTH = 300.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	queue_redraw()

func body(id: String) -> Array:
	var node: Dictionary = model.nodes[id]
	if node.kind == "premise":
		var count: int = model.links.filter(func(e): return e.to == id).size()
		var result: Array = ["%d incoming connections" % count, "Select this premise to present its case."]
		if (model.view.has("chronology") or model.view.get("live", false)) and not node.conclusion.is_empty():
			result.append("At: " + node.conclusion.at)
		for person in node.positions:
			result.append("Assume %s: %s" % [Solver.person_name(model.view, person), node.positions[person]])
		return result
	if node.kind == "contradiction":
		var home = Solver.card_by_id(model.view, node.dispute.challenged)
		var observation = Solver.card_by_id(model.view, node.dispute.preferred)
		return [home.text, observation.text, "If the observation is accurate, the home alibi is false.", "Circumstantial; does not prove evil."]
	if node.kind == "modifier":
		return [Solver.card_by_id(model.view, node.card).text, "Player hypothesis: " + node.mode, "Link supporting evidence here. The jury may reject your explanation."]
	var card = Solver.card_by_id(model.view, node.card)
	var result: Array = [card.text]
	if card.has("support_note"):
		result.append(card.support_note)
	if card.kind == "event" and card.get("event") == "curse":
		var chosen: Array = node.answers.get(card.id, {}).get("positive", [])
		result.append("Converted voter: " + ("?" if chosen.is_empty() else Solver.person_name(model.view, chosen[0])))
	for fault in node.get("faults", {}).values():
		result.append("Possible poison: %s (%s)" % [fault.window, "unsupported" if fault.get("basis", "") == "" else "cites " + fault.basis])
	var slots: Array = node.answers.get(card.id, {}).get("slots", node.answers.get(card.id, {}).get("positive", []))
	if card.kind == "report" and card.role in ["surveyor", "rumormonger", "dowser", "lamplighter", "clerk", "archivist", "seer"]:
		var count: int = (1 if card.data.yes else 0) if card.role == "seer" else (1 if card.role in ["rumormonger", "clerk", "archivist"] else clampi(int(card.data.get("count", 0)), 0, model.view.people.size()))
		for i in range(count):
			var prefix: String = C.block_name(C.BLOCKS.keys()[i]) if card.role == "surveyor" and count == 4 else (str(card.data.get("secret", "marked")).capitalize() if card.role == "rumormonger" else "Slot %d" % (i + 1))
			result.append("%s: %s" % [prefix, Solver.person_name(model.view, slots[i]) if i < slots.size() and slots[i] is String and slots[i] != "" else "?"])
		if card.role == "seer":
			result.append("Registration: " + str(node.answers.get(card.id, {}).get("registration", "? Any valid cause")).replace("_", " ").capitalize())
	for edge in model.links:
		if edge.to == id and edge.kind == "explains_outing":
			result.append("Linked role claim could explain this outing.")
	return result

func _lines(text_value: String, width: float, fs: int) -> Array:
	var lines: Array = []
	var current = ""
	for word in text_value.split(" "):
		var next: String = word if current == "" else current + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and current != "":
			lines.append(current)
			current = word
		else:
			current = next
	lines.append(current)
	return lines

func world_rect(id: String) -> Rect2:
	if model.nodes[id].kind == "premise":
		return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, PREMISE_H + (24.0 if not model.nodes[id].positions.is_empty() else 0.0)))
	if model.nodes[id].kind in ["evidence", "modifier"] and not _evidence_card(id).is_empty():
		return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, evidence_layout(id).h))
	var lines = 0
	for paragraph in body(id):
		lines += _lines(paragraph, WIDTH - 32, 16).size()
	return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, 96 + lines * 20))

func _screen(rect: Rect2) -> Rect2:
	return Rect2(rect.position * zoom + pan, rect.size * zoom)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("171f29"))
	var spacing = 40.0 * zoom
	for x in range(int(fposmod(pan.x, spacing)), int(size.x), maxi(1, int(spacing))):
		for y in range(int(fposmod(pan.y, spacing)), int(size.y), maxi(1, int(spacing))):
			draw_circle(Vector2(x, y), 1.0, Color("2b3540"))
	if model == null:
		return
	hit.clear()
	fields.clear()
	tips.clear()
	answer_buttons.clear()
	for id in model.nodes:
		if not model.nodes[id].has("merged"):
			hit[id] = _screen(world_rect(id))
	for edge in model.links:
		if not hit.has(edge.from) or not hit.has(edge.to):
			continue
		var a: Rect2 = hit[edge.from]
		var b: Rect2 = hit[edge.to]
		var up = a.get_center().y > b.get_center().y
		var start = Vector2(a.get_center().x, a.position.y if up else a.end.y)
		var end = Vector2(b.get_center().x, b.end.y if up else b.position.y)
		var color = Color("c5a869") if edge.kind == "supports" else Color("6aabb1")
		var points = PackedVector2Array()
		for i in range(25):
			var t = float(i) / 24.0
			points.append(start.bezier_interpolate(start + Vector2(0, -65 if up else 65), end + Vector2(0, 65 if up else -65), end, t))
		draw_polyline(points, color, 2.0, true)
		var direction = (end - points[23]).normalized()
		draw_colored_polygon(PackedVector2Array([end, end - direction * 10 + direction.orthogonal() * 5, end - direction * 10 - direction.orthogonal() * 5]), color)
		if edge.kind == "explains_outing":
			draw_string(font, points[12], "could explain outing", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		elif edge.kind == "read_together":
			draw_string(font, points[12], "read together", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	for id in hit:
		_draw_card(id, hit[id])
	if linking != "" and hit.has(linking):
		draw_line(hit[linking].get_center(), get_local_mouse_position(), Color("f3d484"), 2, true)
	if drag_out:
		draw_rect(Rect2(Vector2.ZERO, Vector2(10, size.y)), Color(0.85, 0.3, 0.25, 0.9))
		draw_string(font, Vector2(18, 30), "Release to remove from the Workshop", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.75, 0.7))

func _draw_card(id: String, rect: Rect2) -> void:
	var node: Dictionary = model.nodes[id]
	if node.kind == "premise":
		_draw_premise(id, rect)
		return
	if node.kind in ["evidence", "modifier"] and not _evidence_card(id).is_empty():
		_draw_evidence(id, rect)
		return
	var paper = Color("e8dfc8")
	var header = Color("c4b185")
	if node.kind == "premise":
		paper = Color("e4c598")
		header = Color("c39154")
	elif node.kind == "contradiction":
		paper = Color("e6c5bb")
		header = Color("b46b60")
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("665c4c"), 3 if id == model.selected else 1, 6, 0), rect)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 43 * zoom)), header)
	var title = model.title(id)
	if node.kind == "evidence":
		var card = Solver.card_by_id(model.view, node.card)
		if card.source != "player":
			title = Solver.person_name(model.view, card.source) + " · " + title
	var ink = Color("2c2720")
	draw_string(font, rect.position + Vector2(14, 27) * zoom, title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28 * zoom, maxi(1, roundi(18 * zoom)), ink)
	var y = 64.0
	for paragraph in body(id):
		for line in _lines(paragraph, WIDTH - 32, 16):
			draw_string(font, rect.position + Vector2(16, y) * zoom, line, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(16 * zoom)), ink)
			y += 20
	var answer = _answer_rect(rect)
	var link = _link_rect(rect)
	draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), answer)
	draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), link)
	answer_buttons[id] = answer
	draw_string(font, answer.position + Vector2(12, 20) * zoom, "Inspect" if node.kind == "contradiction" else "Answer", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(15 * zoom)), ink)
	draw_string(font, link.position + Vector2(19, 20) * zoom, "Link", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(15 * zoom)), ink)

## Premise card: who, what claim, any detail the claim needs, the test juror's
## strength and whether the case can be judged. Each field is clicked to change it.
func _draw_premise(id: String, rect: Rect2) -> void:
	var node: Dictionary = model.nodes[id]
	var conclusion: Dictionary = node.conclusion
	var draft: bool = node.get("draft", false)
	var paper = Color("e4c598")
	var header = Color("c39154")
	var ink = Color("2c2720")
	var muted = Color("6f6350")
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("665c4c"), 3 if id == model.selected else 1, 6, 0), rect)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 38 * zoom)), header)
	var label: String = "Premise" if draft or not conclusion.is_empty() else "Supporting premise"
	draw_string(font, rect.position + Vector2(14, 25) * zoom, label, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	# Strength chip (test juror) on the header, right-aligned.
	var badge: Dictionary = badges.get(id, {})
	if not conclusion.is_empty():
		var chip_text: String = "…"
		var chip_color = Color("8a8378")
		var tip: String = "The test juror (public facts, default trust) is judging this case…"
		if badge.get("ready", true) == false:
			chip_text = "Can't judge"
			chip_color = Color("b55a4c")
			tip = "The test juror can't judge this case yet:\n• " + "\n• ".join(PackedStringArray(badge.get("issues", []).slice(0, 6)))
		elif badge.has("category"):
			chip_text = STRENGTH_TEXT.get(badge.category, badge.category)
			chip_color = STRENGTH_COLORS.get(badge.category, chip_color)
			tip = "Test juror: " + badge.get("text", "") + ("\n" + badge.reason if badge.get("reason", "") != "" else "") + "\nPublic facts and default trust: how well the case holds together, not how any one person will react."
		var cw: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18
		var chip = Rect2(rect.position + Vector2(rect.size.x - (cw + 10) * zoom, 7 * zoom), Vector2(cw, 24) * zoom)
		draw_style_box(CanvasSkin.flat(chip_color, chip_color.darkened(0.3), 1, 10, 0), chip)
		draw_string(font, chip.position + Vector2(9, 17) * zoom, chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), Color("fbf6ea"))
		tips.append({"rect": chip, "text": tip})
	var rows: Array = []
	# Who: portrait and name.
	var shown: Dictionary = node.get("pick", {}) if draft else conclusion
	var person: String = shown.get("target", "")
	var who = Rect2(rect.position + Vector2(12, 48) * zoom, Vector2(WIDTH - 24, 58) * zoom)
	if shown.get("type", "") != "conflict":
		_field_box(who, id == model.selected)
		var center: Vector2 = who.position + Vector2(31, 29) * zoom
		if person != "":
			_draw_face(person, center, 23 * zoom)
			draw_string(font, who.position + Vector2(64, 36) * zoom, Solver.person_name(model.view, person), HORIZONTAL_ALIGNMENT_LEFT, who.size.x - 90 * zoom, _fs(19), ink)
		else:
			draw_circle(center, 23 * zoom, Color("d8c7a6"))
			draw_string(font, center + Vector2(-6, 7) * zoom, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(20), muted)
			draw_string(font, who.position + Vector2(64, 36) * zoom, "Choose a person", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(17), muted)
		_caret(who)
		fields[id] = [{"rect": who, "field": "person"}]
		tips.append({"rect": who, "text": "Who this premise is about. Click to choose."})
	else:
		fields[id] = []
	# What: the claim.
	var what = Rect2(rect.position + Vector2(12, 114) * zoom, Vector2(WIDTH - 24, 34) * zoom)
	_field_box(what, false)
	var picked_type: String = shown.get("type", "")
	var claim_text: String = ("Choose a claim" if picked_type == "" else model.PREMISE_TEXT.get(picked_type, picked_type)) if draft else ("Supporting evidence (no claim)" if conclusion.is_empty() else model.PREMISE_TEXT.get(conclusion.type, conclusion.type))
	draw_string(font, what.position + Vector2(12, 23) * zoom, claim_text, HORIZONTAL_ALIGNMENT_LEFT, what.size.x - 40 * zoom, _fs(16), muted if draft and picked_type == "" else ink)
	_caret(what)
	fields[id].append({"rect": what, "field": "type"})
	tips.append({"rect": what, "text": "What you're arguing about them. Click to choose."})
	# Detail: the gift, modifier, reading or time the claim needs.
	var detail: Dictionary = detail_label.call(node) if detail_label.is_valid() else {}
	if not detail.is_empty():
		var extra = Rect2(rect.position + Vector2(12, 156) * zoom, Vector2(WIDTH - 24, 32) * zoom)
		_field_box(extra, false)
		var x: float = 10.0
		if detail.get("icon") != null:
			draw_texture_rect(detail.icon, Rect2(extra.position + Vector2(8, 4) * zoom, Vector2(24, 24) * zoom), false)
			x = 38.0
		draw_string(font, extra.position + Vector2(x, 22) * zoom, detail.text, HORIZONTAL_ALIGNMENT_LEFT, extra.size.x - (x + 30) * zoom, _fs(15), muted if detail.get("missing", false) else ink)
		_caret(extra)
		fields[id].append({"rect": extra, "field": detail.get("field", "detail")})
		tips.append({"rect": extra, "text": detail.get("tip", "Click to choose.")})
	# Assumptions: small portraits with their assumed alignment.
	var y: float = 196.0
	if not node.positions.is_empty():
		var ax: float = 16.0
		for pid in node.positions:
			var c: Vector2 = rect.position + Vector2(ax + 11, y + 11) * zoom
			_draw_face(pid, c, 10 * zoom)
			var mark: String = {"good": "G", "evil": "E", "marked": "M"}.get(node.positions[pid], "?")
			draw_string(font, c + Vector2(13, 6) * zoom, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), ink)
			tips.append({"rect": Rect2(c - Vector2(11, 11) * zoom, Vector2(36, 22) * zoom), "text": "Assumed %s: %s" % [Solver.person_name(model.view, pid), node.positions[pid]]})
			ax += 40.0
			if ax > WIDTH - 40:
				break
		y += 24.0
	var answer = _answer_rect(rect)
	answer_buttons[id] = answer
	var link = _link_rect(rect)
	draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), answer)
	draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), link)
	draw_string(font, answer.position + Vector2(9, 20) * zoom, "Assume…", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	draw_string(font, link.position + Vector2(19, 20) * zoom, "Link", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	tips.append({"rect": answer, "text": "Assumptions for this line of argument: who you take as good, evil or Marked. Hypotheses, not facts."})

func _fs(base: int) -> int:
	return maxi(1, roundi(base * zoom))

func _field_box(r: Rect2, strong: bool) -> void:
	draw_style_box(CanvasSkin.flat(Color("f3e9d2"), Color("9c8662") if not strong else Color("7c6440"), 1, 5, 0), r)

func _caret(r: Rect2) -> void:
	var c = Vector2(r.end.x - 16 * zoom, r.get_center().y)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3) * zoom, c + Vector2(5, -3) * zoom, c + Vector2(0, 3) * zoom]), Color("6f6350"))

## A person's face in a circle (portrait art cropped to the face), ringed in their ink.
func _draw_face(person: String, center: Vector2, radius: float) -> void:
	var color: Color = C.npc_color(person)
	draw_circle(center, radius + 2.0, color.darkened(0.3))
	var tex = CanvasSkin.tex("art/portraits/" + person, 0.25)
	if tex == null:
		draw_circle(center, radius, color)
		var initial: String = Solver.person_name(model.view, person).substr(0, 1)
		draw_string(font, center + Vector2(-radius * 0.35, radius * 0.35), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, int(radius)), Color("fbf6ea"))
		return
	var dims: Vector2 = tex.get_size()
	var span: float = 1.08 * dims.x
	var origin = Vector2(0.5 * dims.x, 0.58 * dims.x) - Vector2(span, span) / 2.0
	var points = PackedVector2Array()
	var uvs = PackedVector2Array()
	for i in range(32):
		var a: float = TAU * i / 32.0
		var d = Vector2(cos(a), sin(a))
		points.append(center + d * radius)
		uvs.append((origin + (d * 0.5 + Vector2(0.5, 0.5)) * span) / dims)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, tex)

func _answer_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(15 * zoom, rect.size.y - 39 * zoom), Vector2(98, 28) * zoom)

func _link_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(rect.size.x - 98 * zoom, rect.size.y - 39 * zoom), Vector2(82, 28) * zoom)

func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseButton:
		grab_focus()
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var world = (event.position - pan) / zoom
			zoom = clampf(zoom * (1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.1), 0.35, 1.5)
			pan = event.position - world * zoom
			queue_redraw()
			accept_event()
			return
		if not event.pressed:
			var removing: String = drag if drag_out and event.button_index == MOUSE_BUTTON_LEFT else ""
			if drag != "" or panning:
				layout_changed.emit()
			drag = ""
			drag_out = false
			panning = false
			if removing != "":
				removal_requested.emit(removing)
			queue_redraw()
			return
		last_mouse = event.position
		var chosen = ""
		var ids = hit.keys()
		ids.reverse()
		for id in ids:
			if hit[id].has_point(event.position):
				chosen = id
				break
		if event.button_index == MOUSE_BUTTON_RIGHT and chosen != "":
			context_requested.emit(chosen)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and chosen == ""):
			panning = true
		elif event.button_index == MOUSE_BUTTON_LEFT and chosen != "":
			var was_linking: bool = linking != ""
			selected.emit(chosen)
			if was_linking:
				return
			for f in fields.get(chosen, []):
				if f.rect.has_point(event.position):
					field_requested.emit(chosen, f.field)
					accept_event()
					return
			if event.double_click or (answer_buttons.has(chosen) and answer_buttons[chosen].has_point(event.position)):
				answer_requested.emit(chosen)
			elif _link_rect(hit[chosen]).has_point(event.position):
				link_requested.emit(chosen)
			else:
				drag = chosen
		accept_event()
	elif event is InputEventMouseMotion:
		if panning:
			pan += event.position - last_mouse
		elif drag != "":
			var node: Dictionary = model.nodes[drag]
			var next = Vector2(node.at[0], node.at[1]) + (event.position - last_mouse) / zoom
			node.at = [next.x, next.y]
			drag_out = event.position.x < 0.0
		last_mouse = event.position
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		linking = ""
		queue_redraw()

func fit_case(all_evidence: bool = false) -> void:
	var ids: Array = model.nodes.keys() if all_evidence else model.ancestors(model.selected)
	var bounds = Rect2()
	var first = true
	for id in ids:
		if model.nodes[id].has("merged"):
			continue
		bounds = world_rect(id) if first else bounds.merge(world_rect(id))
		first = false
	if not first:
		zoom = clampf(minf((size.x - 100) / bounds.size.x, (size.y - 60) / bounds.size.y), 0.35, 1.1)
		pan = (size - bounds.size * zoom) / 2 - bounds.position * zoom
	queue_redraw()

func _can_drop_data(_at: Vector2, data) -> bool:
	return data is Dictionary and data.has("cards")

func _drop_data(_at: Vector2, data) -> void:
	cards_dropped.emit(data["cards"])

func _get_tooltip(at: Vector2) -> String:
	for i in range(tips.size() - 1, -1, -1):
		if tips[i].rect.has_point(at):
			return tips[i].text
	return ""

# ------------------------------------------------------------ evidence cards

const PAIR_ROLES = ["seer", "clerk", "archivist", "rumormonger"]
const FACE_R = 22.0
const FACE_STEP = 54.0

func _evidence_card(id: String) -> Dictionary:
	var node: Dictionary = model.nodes[id]
	return Solver.card_by_id(model.view, node.card) if node.kind in ["evidence", "modifier"] else {}

func _unsupported(card: Dictionary) -> bool:
	var note: String = card.get("support_note", "")
	return note.begins_with("FALLBACK") or note.begins_with("BLOCKED")

func _time_text(card: Dictionary) -> String:
	var at: Dictionary = card.get("observed_at", {})
	if at.is_empty():
		return ""
	var phase: String = str(at.get("phase", ""))
	if phase == "night":
		return "N%d" % int(at.get("day", 0))
	return "D%d %s" % [int(at.get("day", 0)), phase.substr(0, 1).to_upper() + phase.substr(1, 2)]

func _people_home(block: String) -> Array:
	return model.view.people.filter(func(p): return p.get("home", "") == block).map(func(p): return p.id)

## What the card asks and how its answer is drawn, in card-local world units:
## {h, els: [{t: face|tile|chip|label, ...}], details: bool}. Shared by sizing and drawing.
func evidence_layout(id: String) -> Dictionary:
	var node: Dictionary = model.nodes[id]
	var card: Dictionary = _evidence_card(id)
	var els: Array = []
	var y: float = 50.0
	var all_lines: Array = _lines(card.get("text", ""), WIDTH - 32, 14)
	var text_lines: Array = all_lines.slice(0, 2)
	if all_lines.size() > 2:
		text_lines[1] = text_lines[1] + " …"
	y += text_lines.size() * 18.0 + 6.0
	var details = false
	if node.kind == "modifier":
		y += 4.0
		var x: float = 16.0
		for mode in ["misled", "lying", "unlikely"]:
			var label: String = {"misled": "Misled", "lying": "Lying", "unlikely": "Unlikely"}[mode]
			var w: float = 84.0
			var disabled: bool = mode == "unlikely" and card.get("role", "") != "surveyor"
			els.append({"t": "chip", "rect": Rect2(x, y, w, 26), "text": label, "on": node.mode == mode, "disabled": disabled, "field": "mode:" + mode,
				"tip": {"misled": "Honest but wrong: impaired, or a misleading registration.", "lying": "The reader is lying about this result.", "unlikely": "The reading is possible but unlikely as stated (Surveyor counts)."}[mode]})
			x += w + 8.0
		y += 36.0
		return {"h": y + 44.0, "els": els, "text": text_lines, "details": false}
	var answer: Dictionary = node.answers.get(card.get("id", ""), {})
	var positive: Array = answer.get("positive", [])
	var marked: Array = answer.get("marked", [])
	var role: String = card.get("role", "")
	if card.kind == "report" and role in PAIR_ROLES and card.get("data", {}).has("pair"):
		var pair: Array = card.data.pair
		var subject: String = ""
		var icon = null
		if role == "seer":
			subject = "Yes: the Demon is in this pair" if card.data.get("yes", false) else "No: no Demon in this pair"
		elif role == "clerk" or role == "archivist":
			subject = "One of them is the " + C.role_name(card.data.get("role", ""))
			icon = CanvasSkin.tex("ui/roles/" + card.data.get("role", ""), 0.05)
		else:
			subject = "One of them is " + C.secret_name(card.data.get("secret", "marked"))
			icon = CanvasSkin.tex("ui/roles/" + card.data.get("secret", "marked"), 0.05)
		els.append({"t": "label", "at": Vector2(16 + (26 if icon != null else 0), y + 14), "text": subject, "icon": icon})
		y += 26.0
		var answerable: bool = role != "seer" or card.data.get("yes", false)
		var x0: float = WIDTH / 2.0 - (pair.size() - 1) * FACE_STEP * 0.75
		for i in range(pair.size()):
			var p: String = pair[i]
			els.append({"t": "face", "p": p, "at": Vector2(x0 + i * FACE_STEP * 1.5, y + FACE_R + 2), "r": FACE_R,
				"state": "on" if p in positive else "", "field": "pick:" + p if answerable else "",
				"tip": Solver.person_name(model.view, p) + (": click to say this one explains the reading" if answerable else "")})
		y += FACE_R * 2 + 22.0
		if role == "seer" and card.data.get("yes", false):
			var x: float = 16.0
			for reg in [["", "Any"], ["demon", "Demon"], ["red_herring", "Red Herring"], ["marked", "Marked"]]:
				var w: float = 58.0 if reg[0] == "" else (64.0 if reg[0] != "red_herring" else 96.0)
				els.append({"t": "chip", "rect": Rect2(x, y, w, 24), "text": reg[1], "on": answer.get("registration", "") == reg[0], "field": "reg:" + reg[0],
					"tip": "Why the Seer got a yes: " + {"": "any valid explanation", "demon": "the Demon is the one you picked", "red_herring": "the one you picked is the Red Herring", "marked": "the one you picked is Marked"}[reg[0]]})
				x += w + 6.0
			y += 32.0
	elif card.kind == "report" and role in ["dowser", "lamplighter"]:
		var group: Array = card.data.get("group", []) if role == "dowser" else model.view.people.map(func(p): return p.id).filter(func(p): return p != card.source)
		var count: int = int(card.data.get("count", 0))
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": ("%d evil among them" % count) if role == "dowser" else ("%d others out that night" % count)})
		y += 26.0
		var per_row: int = 5
		for i in range(group.size()):
			var p: String = group[i]
			var state: String = ("marked" if p in marked else "on") if p in positive else ""
			els.append({"t": "face", "p": p, "at": Vector2(36 + (i % per_row) * FACE_STEP, y + FACE_R + 2 + (i / per_row) * (FACE_R * 2 + 16)), "r": FACE_R, "state": state,
				"field": "pick:" + p, "tip": Solver.person_name(model.view, p) + (": click to mark as registering evil; again for \"registered as Marked\"; again to clear" if role == "dowser" else ": click to say they were out")})
		y += ceili(group.size() / float(per_row)) * (FACE_R * 2 + 16) + 8.0
	elif card.kind == "report" and role == "surveyor":
		var count: int = int(card.data.get("count", 0))
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "%d of 4 blocks have an evil resident" % count})
		y += 26.0
		var blocks: Array = answer.get("blocks", [])
		var keys: Array = C.BLOCKS.keys()
		for i in range(keys.size()):
			var b: String = keys[i]
			var residents: Array = _people_home(b)
			var chosen: bool = b in blocks or residents.any(func(p): return p in positive)
			var tile = Rect2(12 + (i % 2) * 140, y + (i / 2) * 84, 134, 78)
			els.append({"t": "tile", "rect": tile, "text": C.block_name(b), "on": chosen, "field": "block:" + b,
				"tip": C.block_name(b) + ": click to say an evil (or Marked) resident lives here"})
			for j in range(residents.size()):
				var p: String = residents[j]
				els.append({"t": "face", "p": p, "at": tile.position + Vector2(22 + j * 36, 52), "r": 14.0,
					"state": ("marked" if p in marked else "on") if p in positive else "", "field": "resident:" + p,
					"tip": Solver.person_name(model.view, p) + ": click to name them as the reason; again for \"registered as Marked\"; again to clear"})
		y += 172.0
	elif (card.kind == "report" and role == "nightwatch") or (card.kind == "sighting" and card.get("night", -1) >= 0):
		var seen: Array = card.data.get("seen", []) if role == "nightwatch" else card.get("subjects", [card.get("subject", "")])
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Why were they out?" if not seen.is_empty() else "Nobody seen"})
		y += 26.0
		for i in range(seen.size()):
			var p: String = seen[i]
			if p == "":
				continue
			var reason: String = node.reasons.get("%s:%d" % [p, card.get("night", -1)], "unexplained")
			els.append({"t": "face", "p": p, "at": Vector2(36 + (i % 5) * FACE_STEP, y + FACE_R + 2 + (i / 5) * (FACE_R * 2 + 28)), "r": FACE_R,
				"state": "reason:" + reason, "field": "why:" + p, "tip": Solver.person_name(model.view, p) + ": click to say why they were out"})
		y += maxf(1.0, ceili(seen.size() / 5.0)) * (FACE_R * 2 + 28) + 6.0
	elif card.kind == "event" and card.get("event") == "curse":
		var eligible: Array = card.get("data", {}).get("eligible", [])
		els.append({"t": "label", "at": Vector2(16, y + 14), "text": "Who turned?"})
		y += 26.0
		for i in range(eligible.size()):
			var p: String = eligible[i]
			els.append({"t": "face", "p": p, "at": Vector2(36 + (i % 5) * FACE_STEP, y + FACE_R + 2 + (i / 5) * (FACE_R * 2 + 16)), "r": FACE_R,
				"state": "on" if p in positive else "", "field": "pick:" + p, "tip": Solver.person_name(model.view, p) + ": click if you think they turned"})
		y += ceili(eligible.size() / 5.0) * (FACE_R * 2 + 16) + 8.0
	else:
		details = card.kind == "report" and role in ["warden", "gravedigger", "veteran", "martyr", "sexton"]
	return {"h": y + 44.0, "els": els, "text": text_lines, "details": details}

func _draw_evidence(id: String, rect: Rect2) -> void:
	var node: Dictionary = model.nodes[id]
	var card: Dictionary = _evidence_card(id)
	var lay: Dictionary = evidence_layout(id)
	var paper = Color("e8dfc8") if node.kind == "evidence" else Color("e3d6e6")
	var header = Color("c4b185") if node.kind == "evidence" else Color("a98fb0")
	var ink = Color("2c2720")
	var muted = Color("6f6350")
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("665c4c"), 3 if id == model.selected else 1, 6, 0), rect)
	var head = Rect2(rect.position, Vector2(rect.size.x, 40 * zoom))
	draw_rect(head, header)
	var x: float = 10.0
	if model.view.people.any(func(p): return p.id == card.get("source", "")):
		_draw_face(card.source, rect.position + Vector2(24, 20) * zoom, 14 * zoom)
		x = 44.0
	var role_icon = CanvasSkin.tex("ui/roles/" + card.get("role", ""), 0.05) if card.get("role", "") != "" else null
	if role_icon != null:
		draw_texture_rect(role_icon, Rect2(rect.position + Vector2(x, 8) * zoom, Vector2(24, 24) * zoom), false)
		x += 28.0
	var title: String = ("Challenge · " if node.kind == "modifier" else "") + model.title(id).trim_prefix("Misled reading").trim_prefix("Suspected lie").trim_prefix("Unlikely reading")
	if node.kind == "modifier":
		title = "Challenge"
	var time_text: String = _time_text(card)
	var tw: float = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14 if time_text != "" else 0.0
	draw_string(font, rect.position + Vector2(x, 26) * zoom, title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - (x + tw + 14) * zoom, _fs(16), ink)
	if time_text != "":
		var chip = Rect2(rect.position + Vector2(WIDTH - tw - 8, 10) * zoom, Vector2(tw, 20) * zoom)
		draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 8, 0), chip)
		draw_string(font, chip.position + Vector2(7, 15) * zoom, time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), ink)
	tips.append({"rect": head, "text": card.get("text", "") + ("\n" + card.support_note if card.get("support_note", "") != "" else "")})
	if _unsupported(card):
		var bad = Rect2(rect.position + Vector2(0, 40) * zoom, Vector2(rect.size.x, 4) * zoom)
		draw_rect(bad, Color("b55a4c"))
		var badge = Rect2(rect.position + Vector2(WIDTH - 118, 46) * zoom, Vector2(110, 20) * zoom)
		draw_style_box(CanvasSkin.flat(Color("b55a4c"), Color("7d3a30"), 1, 8, 0), badge)
		draw_string(font, badge.position + Vector2(8, 15) * zoom, "Can't be judged", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), Color("fbf6ea"))
		tips.append({"rect": badge, "text": "The shared model can't read this card yet, so a case that uses it can't be presented:\n" + card.get("support_note", "")})
	var y: float = 50.0
	for line in lay.text:
		draw_string(font, rect.position + Vector2(16, y + 12) * zoom, line, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(14), ink)
		y += 18.0
	tips.append({"rect": Rect2(rect.position + Vector2(0, 46) * zoom, Vector2(WIDTH, maxf(y - 46, 4)) * zoom), "text": card.get("text", "")})
	fields[id] = []
	for el in lay.els:
		_draw_element(id, rect.position, el)
	var link = _link_rect(rect)
	draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), link)
	draw_string(font, link.position + Vector2(19, 20) * zoom, "Link", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	if lay.details:
		var answer = _answer_rect(rect)
		answer_buttons[id] = answer
		draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), answer)
		draw_string(font, answer.position + Vector2(14, 20) * zoom, "Details", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)

func _draw_element(id: String, origin: Vector2, el: Dictionary) -> void:
	var ink = Color("2c2720")
	match el.t:
		"label":
			if el.get("icon") != null:
				draw_texture_rect(el.icon, Rect2(origin + (el.at - Vector2(26, 15)) * zoom, Vector2(20, 20) * zoom), false)
			draw_string(font, origin + el.at * zoom, el.text, HORIZONTAL_ALIGNMENT_LEFT, (WIDTH - el.at.x - 10) * zoom, _fs(14), Color("5a4c38"))
		"chip":
			var r = Rect2(origin + el.rect.position * zoom, el.rect.size * zoom)
			var on: bool = el.get("on", false)
			var off: bool = el.get("disabled", false)
			draw_style_box(CanvasSkin.flat(Color("7c5a2e") if on else (Color("e6dccb") if off else Color("f3e9d2")), Color("5c4630"), 1, 10, 0), r)
			draw_string(font, r.position + Vector2(9, 17) * zoom, el.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), Color("fbf6ea") if on else (Color("a89c88") if off else ink))
			if not off:
				fields[id].append({"rect": r, "field": el.field})
			tips.append({"rect": r, "text": el.get("tip", "")})
		"tile":
			var r = Rect2(origin + el.rect.position * zoom, el.rect.size * zoom)
			draw_style_box(CanvasSkin.flat(Color("efd7a6") if el.on else Color("f3e9d2"), Color("b0662f") if el.on else Color("9c8662"), 2 if el.on else 1, 6, 0), r)
			draw_string(font, r.position + Vector2(8, 18) * zoom, el.text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12 * zoom, _fs(13), ink)
			if el.on:
				draw_string(font, r.position + Vector2(r.size.x / zoom - 22, 18) * zoom, "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), Color("b0662f"))
			fields[id].append({"rect": r, "field": el.field})
			tips.append({"rect": r, "text": el.get("tip", "")})
		"face":
			var center: Vector2 = origin + el.at * zoom
			var radius: float = el.r * zoom
			var state: String = el.get("state", "")
			if state == "on":
				draw_circle(center, radius + 5 * zoom, Color("c0392b"))
			elif state == "marked":
				draw_circle(center, radius + 5 * zoom, Color("8e44ad"))
			_draw_face(el.p, center, radius)
			var name_text: String = Solver.person_name(model.view, el.p)
			if el.r >= 18.0:
				# Small faces (Surveyor tiles) keep their names in the tooltip.
				var nw: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * zoom
				draw_string(font, center + Vector2(-nw / 2.0, radius + 14 * zoom), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), ink)
			if state == "marked":
				draw_string(font, center + Vector2(radius * 0.4, -radius * 0.55), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(14), Color("fbf6ea"))
			if state.begins_with("reason:"):
				var reason: String = state.trim_prefix("reason:")
				var tag: String = {"unexplained": "?", "gift": "gift", "evil": "evil", "secret": "errand"}.get(reason, reason)
				var color: Color = {"unexplained": Color("8a8378"), "gift": Color("3f7f9a"), "evil": Color("c0392b"), "secret": Color("6a8a3a")}.get(reason, Color("8a8378"))
				var tw: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10
				var tr = Rect2(center + Vector2(-tw / 2.0, radius + 18) * Vector2(1, 1) + Vector2(0, 0), Vector2(tw, 16) * zoom)
				tr.position = center + Vector2(-tw * zoom / 2.0, radius + 18 * zoom)
				draw_style_box(CanvasSkin.flat(color, color.darkened(0.3), 1, 7, 0), tr)
				draw_string(font, tr.position + Vector2(5, 12) * zoom, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(11), Color("fbf6ea"))
			var hit_rect = Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2)
			if el.get("field", "") != "":
				fields[id].append({"rect": hit_rect, "field": el.field})
			tips.append({"rect": hit_rect, "text": el.get("tip", name_text)})
