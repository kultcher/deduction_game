## Freeform cards and strings. Input only edits the separate canvas model.
extends Control
signal selected(id: String)
signal answer_requested(id: String)
signal link_requested(id: String)
signal context_requested(id: String)
signal layout_changed
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
		result.append(str(card.support_note).replace("FALLBACK:", "UNSUPPORTED:"))
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

func _draw_card(id: String, rect: Rect2) -> void:
	var node: Dictionary = model.nodes[id]
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
			if drag != "" or panning:
				layout_changed.emit()
			drag = ""
			panning = false
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
