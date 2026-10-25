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
			if event.double_click or _answer_rect(hit[chosen]).has_point(event.position):
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
