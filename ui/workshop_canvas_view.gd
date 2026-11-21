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
signal group_removal_requested(ids: Array)   # Delete with a box selection (Nov 10)
signal background_context_requested(at: Vector2)   # a right-click (not a drag) on empty canvas
const CardLayout = preload("res://ui/workshop_card_layout.gd")
const CanvasSkin = preload("res://ui/theme.gd")
const EvidenceContext = preload("res://ui/evidence_context.gd")
const Solver = preload("res://workshop/solver.gd")
const Live = preload("res://game/workshop_canvas.gd")
const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const TraceSolver = preload("res://workshop/trace_solver.gd")
const LocationSolver = preload("res://workshop/location_solver.gd")
const TraceTooltip = preload("res://ui/trace_tooltip.gd")
var model
var zoom = 0.85
var pan = Vector2(50, 10)
var linking = ""
var hit: Dictionary = {}
var drag = ""
var panning = false
var last_mouse = Vector2.ZERO
var drag_out = false   # the dragged card is past the left edge: release removes it

## Box selection (Nov 10; plain left-drag since triage 8.1, Nov 16): left-drag on empty
## canvas draws a box; the cards inside move together when one is dragged, and Delete
## removes them. No group linking. Right-drag (or middle-drag) on empty canvas pans.
var group: Array = []
var box_from = null     # screen point where the box started, or null
var box_to: Vector2 = Vector2.ZERO

## Cards just added (Michael, Nov 19): a soft glow until each is first moved.
var fresh: Dictionary = {}

## Where a right press on empty canvas began: released without dragging, it opens the menu.
var _right_from = null

## The off-screen markers drawn this frame: [{rect, ids}], one per direction.
var edge_marks: Array = []
var fields: Dictionary = {}   # id -> [{rect, field}] clickable fields, in screen space
var tips: Array = []          # [{rect, text}] tooltips for drawn badges and fields
var answer_buttons: Dictionary = {}   # id -> screen rect of the card's Details/Assume button
var badges: Dictionary = {}   # id -> {category, text, reason, ready, issues} from the test juror
var clashing: Dictionary = {} # card ids the test juror says clash with the chosen explanation
var detail_label: Callable    # (node) -> {text, icon}: the premise's extra field, if any
const PREMISE_H = 236.0
const STRENGTH_COLORS = {"empty": Color("8a8378"), "contradicts": Color("b55a4c"), "none": Color("8a8378"), "weak": Color("c98a3d"), "moderate": Color("c9b03d"), "strong": Color("5f9a55"), "damning": Color("3e7f47")}
const STRENGTH_TEXT = {"empty": "No evidence", "contradicts": "Argues against", "none": "Negligible", "weak": "Weak", "moderate": "Moderate", "strong": "Strong", "damning": "Damning"}

## The top tier (Michael, Nov 19): "Damning" on an accusing premise, "Conclusive" on any other,
## a deeper green with the gold of the portrait ring around it.
const TOP_RING = Color("c9a24a")
const DAMNING_LINE = "This case is damning: an ordinary townsperson would vote for %s over anyone else."
const CONCLUSIVE_LINE = "This case is conclusive: an ordinary townsperson would take it as settled that %s."

## A lie call the town weighs as one word against another (Lantern's draw; Michael, Nov 19).
## A weak or contrary accusation whose evidence points more at someone else (Michael, Nov 20).
const POINTS_ELSEWHERE_TIP = "This evidence may say more about someone else than about %s."
const STAND_OFF = "Stand-off"
const STAND_OFF_TIP = "One word against another. Most will wait for more, but a few may take your side."
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
		# Where each assumption comes from: this premise (yours), or a supporting premise.
		for person in node.positions:
			result.append("Assume %s: %s (yours)" % [Solver.person_name(model.view, person), node.positions[person]])
		if not node.conclusion.is_empty():
			var shown: Dictionary = node.positions.duplicate()
			for line in model.compile(id).get("lines", []):
				for positions in [line.get("positions", {})] + line.get("assumption_sets", []):
					for person in positions:
						if not shown.has(person):
							shown[person] = positions[person]
							result.append("Assume %s: %s (from \"%s\")" % [Solver.person_name(model.view, person), positions[person], line.label])
		return result
	if node.kind == "contradiction":
		var home = Solver.card_by_id(model.view, node.dispute.challenged)
		var observation = Solver.card_by_id(model.view, node.dispute.preferred)
		var lines: Array = [home.text, observation.text, "If the observation is accurate, the home alibi is false.", "Circumstantial; does not prove evil."]
		if model.report_doubtable(id):
			lines.append("Or the report is false: Inspect to doubt it instead.")
		return lines
	if node.kind == "modifier":
		return [Solver.card_by_id(model.view, node.card).text, "Player hypothesis: " + node.mode, "Link supporting evidence here. The jury may reject your explanation."]
	var card = Solver.card_by_id(model.view, node.card)
	var result: Array = [card.text]
	if str(card.get("support_note", "")) != "":
		result.append(str(card.support_note))
	if card.kind == "event" and card.get("event") == "curse":
		var chosen: Array = node.answers.get(card.id, {}).get("positive", [])
		result.append("Converted voter: " + ("?" if chosen.is_empty() else Solver.person_name(model.view, chosen[0])))
	if card.kind == "town_hall":
		var th_pick: String = str(node.answers.get(card.id, {}).get("in_play_role", ""))
		result.append("In town: " + ("? Either role" if th_pick == "" else C.role_name(th_pick)))
	for fault in node.get("faults", {}).values():
		result.append("Possible poison: %s (%s)" % [fault.window, "unsupported" if fault.get("basis", "") == "" else "cites " + fault.basis])
	var slots: Array = node.answers.get(card.id, {}).get("slots", node.answers.get(card.id, {}).get("positive", []))
	if card.kind == "report" and card.role in ["surveyor", "rumormonger", "dowser", "lamplighter", "clerk", "archivist", "seer", "chronicler", "magistrate", "augur"]:
		var count: int = 0
		if card.role in ["seer", "augur"]:
			count = 1 if card.data.get("yes", false) else 0
		elif card.role in ["rumormonger", "clerk", "archivist", "chronicler"]:
			count = 1
		elif card.role == "magistrate":
			count = 0 if card.data.get("same", false) else 1
		elif card.role == "surveyor" and card.data.has("block"):
			var s_res_n: int = CardLayout.people_home(self, str(card.data.get("block", ""))).size()
			count = 0 if card.data.get("same", false) else maxi(1, s_res_n - 1)
		else:
			count = clampi(int(card.data.get("count", 0)), 0, model.view.people.size())
		for i in range(count):
			var prefix: String = C.block_name(C.BLOCKS.keys()[i]) if card.role == "surveyor" and card.data.has("count") and count == 4 else ("Minion" if card.role == "chronicler" else (C.secret_name(str(card.data.get("secret", "marked"))) if card.role == "rumormonger" else "Slot %d" % (i + 1)))
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
	if model.nodes[id].kind == "profile_info":
		return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, CardLayout.profile_layout(self, id).h))
	if model.nodes[id].kind == "circumstantial":
		return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, CardLayout.circumstantial_layout(self, id).h))
	if model.nodes[id].kind == "trace_chain":
		return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, CardLayout.trace_chain_layout(self, id).h))
	if model.nodes[id].kind == "whereabouts":
		return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, CardLayout.whereabouts_layout(self, id).h))
	if model.nodes[id].kind in ["evidence", "modifier"] and not _evidence_card(id).is_empty():
		return Rect2(Vector2(model.nodes[id].at[0], model.nodes[id].at[1]), Vector2(WIDTH, CardLayout.evidence_layout(self, id).h))
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
	var link_labels: Array = []
	for edge in model.links:
		if not hit.has(edge.from) or not hit.has(edge.to):
			continue
		var a: Rect2 = hit[edge.from]
		var b: Rect2 = hit[edge.to]
		var up = a.get_center().y > b.get_center().y
		var start = Vector2(a.get_center().x, a.position.y if up else a.end.y)
		var end = Vector2(b.get_center().x, b.end.y if up else b.position.y)
		var color = Color("c5a869") if edge.kind == "supports" else (Color("c0392b") if edge.kind == "contradicts" else Color("6aabb1"))
		var points = PackedVector2Array()
		for i in range(25):
			var t = float(i) / 24.0
			points.append(start.bezier_interpolate(start + Vector2(0, -65 if up else 65), end + Vector2(0, 65 if up else -65), end, t))
		draw_polyline(points, color, 2.0, true)
		var direction = (end - points[23]).normalized()
		draw_colored_polygon(PackedVector2Array([end, end - direction * 10 + direction.orthogonal() * 5, end - direction * 10 - direction.orthogonal() * 5]), color)
		if edge.kind == "explains_outing":
			link_labels.append({"at": points[12], "text": "could explain outing", "fs": 14, "color": color})
		elif edge.kind == "read_together":
			link_labels.append({"at": points[12], "text": "read together", "fs": 13, "color": color})
		elif edge.kind == "contradicts":
			link_labels.append({"at": points[12], "text": "contradicts", "fs": 13, "color": color})
		elif edge.kind == "given":
			link_labels.append({"at": points[12], "text": "given " + model.title(edge.from), "fs": 13, "color": color})
	for id in hit:
		_draw_card(id, hit[id])
	for lbl in link_labels:
		var lfs: int = int(lbl["fs"])
		var lw: float = font.get_string_size(lbl["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x + 12.0
		var lh: float = lfs + 6.0
		var lrect = Rect2(lbl["at"] - Vector2(lw / 2.0, lh / 2.0), Vector2(lw, lh))
		draw_style_box(CanvasSkin.flat(Color(0.09, 0.12, 0.16, 0.9), lbl["color"].darkened(0.35), 1, 6, 0), lrect)
		draw_string(font, Vector2(lrect.position.x + 6.0, lrect.position.y + lfs + 1.0), lbl["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, lbl["color"])
	if linking != "" and hit.has(linking):
		draw_line(hit[linking].get_center(), get_local_mouse_position(), Color("f3d484"), 2, true)
	for gid in group:
		if hit.has(gid):
			draw_rect(hit[gid].grow(5.0), Color("7fc4ff"), false, 2.0)
	for fid in fresh:
		if hit.has(fid):
			draw_rect(hit[fid].grow(7.0), Color(0.96, 0.83, 0.45, 0.22), false, 6.0)
			draw_rect(hit[fid].grow(4.0), Color(0.96, 0.83, 0.45, 0.75), false, 1.5)
	_draw_edge_marks()
	if box_from != null:
		var br := Rect2(box_from, Vector2.ZERO).expand(box_to)
		draw_rect(br, Color(0.5, 0.77, 1.0, 0.12))
		draw_rect(br, Color("7fc4ff"), false, 1.5)
	if drag_out:
		draw_rect(Rect2(Vector2.ZERO, Vector2(10, size.y)), Color(0.85, 0.3, 0.25, 0.9))
		draw_string(font, Vector2(18, 30), "Release to remove from the Workshop", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.75, 0.7))

func _draw_card(id: String, rect: Rect2) -> void:
	var node: Dictionary = model.nodes[id]
	if node.kind == "premise":
		_draw_premise(id, rect)
		return
	if node.kind == "profile_info":
		_draw_profile_info(id, rect)
		return
	if node.kind == "circumstantial":
		_draw_circumstantial(id, rect)
		return
	if node.kind == "trace_chain":
		_draw_trace_chain(id, rect)
		return
	if node.kind == "whereabouts":
		_draw_whereabouts(id, rect)
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
		var ring = null
		var tip: String = "The test juror (public facts, default trust) is judging this case…"
		if badge.get("ready", true) == false:
			chip_text = "Can't judge"
			chip_color = Color("b55a4c")
			tip = "The test juror can't judge this case yet:\n• " + "\n• ".join(PackedStringArray(badge.get("issues", []).slice(0, 6)))
		elif badge.has("category"):
			chip_text = STRENGTH_TEXT.get(badge.category, badge.category)
			chip_color = STRENGTH_COLORS.get(badge.category, chip_color)
			var juror_text: String = badge.get("text", "")
			if badge.category == "damning":
				var top: Dictionary = top_tier(id)
				if top.is_empty():
					# The tier the evidence itself earns, without the top tier's chance cut.
					var CaseEval = preload("res://workshop/case_eval.gd")
					var earned: String = CaseEval.category(float(badge.get("lr", 1.0)))
					chip_text = STRENGTH_TEXT.get(earned, earned)
					chip_color = STRENGTH_COLORS.get(earned, chip_color)
					juror_text = CaseEval.category_text(earned)
				else:
					chip_text = top.label
					juror_text = top.line
					ring = TOP_RING
			var notes: Array = []
			if badge.get("headline", "") != "":
				chip_text = "Doesn't fit"
				chip_color = Color("b55a4c")
				notes.append(badge.headline + " The clashing cards are outlined in red.")
			notes.append("Test juror: " + juror_text + ("\n" + badge.reason if badge.get("reason", "") != "" else ""))
			for c in badge.get("listener", {}).get("challenges", []):
				notes.append(Live.lie_call_line(c, func(pid): return Solver.person_name(model.view, pid)))
			if badge.get("change", "") != "":
				notes.append(badge.change)
			if badge.get("points_elsewhere", false) and badge.get("headline", "") == "":
				chip_text += " · points elsewhere"
				notes.append(POINTS_ELSEWHERE_TIP % Solver.person_name(model.view, str(conclusion.get("target", ""))))
			if badge.get("town_note", "") != "":
				# The one warning shown beside the strength itself (connections model only).
				chip_text += " · " + {"refresh": "Refresh", "presses": "No new belief"}.get(badge.get("town_note_kind", ""), "No new info")
				notes.append(badge.town_note)
			if badge.get("raises_text", "") != "":
				notes.append(badge.raises_text)
			for gl in badge.get("guard_lines", []):
				notes.append(gl)
			for who in badge.get("idle", []):
				notes.append("Assuming %s %s isn't changing anything in this case." % [Solver.person_name(model.view, who), node.positions.get(who, "")])
			notes.append("As an average townsperson would take it, hearing these cards from you: not how any one person will react.")
			tip = "\n".join(PackedStringArray(notes))
		var cw: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18
		var chip = Rect2(rect.position + Vector2(rect.size.x - (cw + 10) * zoom, 7 * zoom), Vector2(cw, 24) * zoom)
		draw_style_box(CanvasSkin.flat(chip_color, ring if ring != null else chip_color.darkened(0.3), 2 if ring != null else 1, 10, 0), chip)
		draw_string(font, chip.position + Vector2(9, 17) * zoom, chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(13), Color("fbf6ea"))
		tips.append({"rect": chip, "text": tip, "chip": chip_text})
	var rows: Array = []
	# Who: portrait and name.
	var shown: Dictionary = node.get("pick", {}) if draft else conclusion
	var person: String = shown.get("target", "")
	var who = Rect2(rect.position + Vector2(12, 48) * zoom, Vector2(WIDTH - 24, 58) * zoom)
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
	# What: the claim.
	var what = Rect2(rect.position + Vector2(12, 114) * zoom, Vector2(WIDTH - 24, 34) * zoom)
	_field_box(what, false)
	var picked_type: String = shown.get("type", "")
	var claim_text: String = ("Choose a claim" if picked_type == "" else model.premise_text(picked_type, str(shown.get("target", "")))) if draft else ("Supporting evidence (no claim)" if conclusion.is_empty() else model.premise_text(str(conclusion.type), str(conclusion.get("target", ""))))
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

## Cards wholly off-screen, gathered by direction from the view's centre (eight ways), each
## direction drawn once at the edge with a count: not one marker per card (Michael, Nov 19).
## Clicking a marker brings those cards into view.
func _draw_edge_marks() -> void:
	edge_marks = []
	var view := Rect2(Vector2.ZERO, size)
	var centre: Vector2 = size / 2.0
	var buckets: Dictionary = {}
	for id in hit:
		if view.intersects(hit[id]):
			continue
		var d: Vector2 = hit[id].get_center() - centre
		var b: int = posmod(int(round(d.angle() / (PI / 4.0))), 8)
		buckets[b] = buckets.get(b, []) + [id]
	var inner := view.grow(-22.0)
	for b in buckets:
		var dir := Vector2.from_angle(b * PI / 4.0)
		# Where the ray from the centre leaves the inner rectangle.
		var tx: float = INF if is_zero_approx(dir.x) else (inner.size.x / 2.0) / absf(dir.x)
		var ty: float = INF if is_zero_approx(dir.y) else (inner.size.y / 2.0) / absf(dir.y)
		var at: Vector2 = centre + dir * minf(tx, ty)
		var ink := Color(0.96, 0.83, 0.45, 0.85)
		var tip: Vector2 = at + dir * 12.0
		draw_circle(at, 14.0, Color(0.09, 0.12, 0.16, 0.85))
		draw_colored_polygon(PackedVector2Array([tip, at - dir * 4.0 + dir.orthogonal() * 8.0, at - dir * 4.0 - dir.orthogonal() * 8.0]), ink)
		var n: int = buckets[b].size()
		if n > 1:
			draw_string(font, at - dir * 22.0 + Vector2(-6, 5), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		var r := Rect2(at - Vector2(16, 16), Vector2(32, 32))
		edge_marks.append({"rect": r, "ids": buckets[b]})
		tips.append({"rect": r, "text": "%d card%s this way. Click to look." % [n, "" if n == 1 else "s"]})

## Bring these cards into view, centred, keeping the zoom unless they won't fit.
func centre_on(ids: Array) -> void:
	var bounds = Rect2()
	var first = true
	for id in ids:
		if not model.nodes.has(id) or model.nodes[id].has("merged"):
			continue
		bounds = world_rect(id) if first else bounds.merge(world_rect(id))
		first = false
	if first:
		return
	if size.x > 0.0 and size.y > 0.0:
		var fit: float = minf((size.x - 100) / bounds.size.x, (size.y - 60) / bounds.size.y)
		if fit < zoom:
			zoom = clampf(fit, 0.35, 1.5)
	pan = size / 2.0 - bounds.get_center() * zoom
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseButton:
		if is_inside_tree():
			grab_focus()
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var world = (event.position - pan) / zoom
			zoom = clampf(zoom * (1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.1), 0.35, 1.5)
			pan = event.position - world * zoom
			queue_redraw()
			accept_event()
			return
		if not event.pressed and box_from != null and event.button_index == MOUSE_BUTTON_LEFT:
			var br := Rect2(box_from, Vector2.ZERO).expand(event.position)
			group = []
			for gid in hit:
				var nk: String = str(model.nodes[gid].get("kind", ""))
				if br.intersects(hit[gid]) and nk != "":
					group.append(gid)
			box_from = null
			queue_redraw()
			accept_event()
			return
		if not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and _right_from != null:
			var still: bool = (event.position - _right_from).length() < 5.0
			_right_from = null
			if still:
				panning = false
				background_context_requested.emit(event.position)
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
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Markers are drawn over the cards, so they take the click first.
			for mark in edge_marks:
				if mark.rect.has_point(event.position):
					centre_on(mark.ids)
					accept_event()
					return
		# Empty space: left-drag pans, shift+left-drag draws a selection box (Michael, Nov 17).
		if event.button_index == MOUSE_BUTTON_LEFT and chosen == "":
			if event.shift_pressed:
				box_from = event.position
				box_to = event.position
			else:
				group = []
				panning = true
			queue_redraw()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not (chosen in group):
			group = []
		if event.button_index == MOUSE_BUTTON_RIGHT and chosen != "":
			context_requested.emit(chosen)
		elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			panning = true
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_right_from = event.position
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
		if box_from != null:
			box_to = event.position
		elif panning:
			pan += event.position - last_mouse
		elif drag != "":
			var movers: Array = group if drag in group else [drag]
			for mid in movers:
				fresh.erase(mid)
				if not model.nodes.has(mid):
					continue
				var node: Dictionary = model.nodes[mid]
				var next = Vector2(node.at[0], node.at[1]) + (event.position - last_mouse) / zoom
				node.at = [next.x, next.y]
			drag_out = event.position.x < 0.0 and movers.size() == 1
		last_mouse = event.position
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		linking = ""
		group = []
		box_from = null
		queue_redraw()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_DELETE, KEY_BACKSPACE] and not group.is_empty():
		var ids_g: Array = group.duplicate()
		group = []
		group_removal_requested.emit(ids_g)
		accept_event()
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

## The Trace Chain under the pointer, when that's what the tooltip is about.
var _tip_chain: String = ""

func _get_tooltip(at: Vector2) -> String:
	_tip_chain = ""
	var context = false
	for id in hit:
		if hit[id].has_point(at) and EvidenceContext.is_context(_evidence_card(id)):
			context = true
	for i in range(tips.size() - 1, -1, -1):
		if tips[i].rect.has_point(at):
			return tips[i].text + ("\n" + EvidenceContext.EXPLANATION if context else "")
	for id in hit:
		if hit[id].has_point(at) and model.nodes.has(id) and model.nodes[id].kind == "trace_chain":
			var traces: Array = CardLayout.chain_traces(self, id)
			if not traces.is_empty():
				_tip_chain = id
				return "\n".join(PackedStringArray(traces.map(func(tr): return CardLayout.chain_trace_text(self, tr))))
	return EvidenceContext.EXPLANATION if context else ""

## A Trace Chain's tooltip lists every trace it bundles, each with its artwork.
func _make_custom_tooltip(for_text: String) -> Object:
	if _tip_chain == "" or not model.nodes.has(_tip_chain):
		return null
	var rows: Array = CardLayout.chain_traces(self, _tip_chain).map(func(tr): return {"trace": tr, "text": CardLayout.chain_trace_text(self, tr)})
	return TraceTooltip.build(rows, model.title(_tip_chain))
# ------------------------------------------------------------ evidence cards

const PAIR_ROLES = ["seer", "clerk", "archivist", "rumormonger"]
const FACE_R = 22.0
const FACE_STEP = 54.0

func _evidence_card(id: String) -> Dictionary:
	var node: Dictionary = model.nodes[id]
	return Solver.card_by_id(model.view, node.card) if node.kind in ["evidence", "modifier"] else {}

## Clearing premises the top tier can call settled: the juror's chance is the target's chance
## of being good, which settles these and no other clearing premise (Codex, #358). Being good
## doesn't settle "is Marked", "holds a secret" and the like.
const CONCLUSIVE_TYPES = ["good", "notdemon"]

## The top tier's chip and reason line for premise `id`: Damning when it accuses someone by
## name, Conclusive on a premise their being good settles ({label, line}), or {} where the
## top tier can't be claimed and the chip stays at Strong.
func top_tier(id: String) -> Dictionary:
	var conclusion: Dictionary = model.nodes[id].get("conclusion", {})
	var type: String = str(conclusion.get("type", ""))
	var target: String = str(conclusion.get("target", ""))
	if target != "" and type not in Live.PREMISE_CLEARS:
		return {"label": "Damning", "line": DAMNING_LINE % Solver.person_name(model.view, target)}
	if type in CONCLUSIVE_TYPES:
		return {"label": "Conclusive", "line": CONCLUSIVE_LINE % model.title(id)}
	return {}

## How the test juror weighed a lie call on the card with Workshop id `card_id`, from any
## premise's badge ({} when no badge carries it).
func lie_call(card_id: String) -> Dictionary:
	for b in badges.values():
		for c in b.get("listener", {}).get("challenges", []):
			if str(c.get("reading", "")) == card_id:
				return c
	return {}

func _draw_profile_info(id: String, rect: Rect2) -> void:
	var node: Dictionary = model.nodes[id]
	var person: String = node.get("person", "")
	var lay: Dictionary = CardLayout.profile_layout(self, id)
	var paper = Color("e8dfc8")
	var header = Color("c4b185")
	var ink = Color("2c2720")
	var accent: Color = C.npc_color(person).darkened(0.15)
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("665c4c"), 3 if id == model.selected else 1, 6, 0), rect)
	var head = Rect2(rect.position, Vector2(rect.size.x, 40 * zoom))
	draw_rect(head, header)
	draw_rect(Rect2(rect.position + Vector2(0, 37 * zoom), Vector2(rect.size.x, 3.5 * zoom)), accent)
	_draw_face(person, rect.position + Vector2(24, 20) * zoom, 14 * zoom)
	var picker = Rect2(rect.position + Vector2(44, 6) * zoom, Vector2(WIDTH - 54, 28) * zoom)
	draw_style_box(CanvasSkin.flat(Color("f3e9d2"), Color("8c795c"), 1, 5, 0), picker)
	draw_string(font, picker.position + Vector2(8, 19) * zoom, "%s's Profile" % Solver.person_name(model.view, person), HORIZONTAL_ALIGNMENT_LEFT, picker.size.x - 28 * zoom, _fs(15), ink)
	_caret(picker)
	fields[id] = [{"rect": picker, "field": "profile_person"}]
	tips.append({"rect": picker, "text": "Click to switch which townsperson's profile this card cites."})
	for el in lay.els:
		_draw_element(id, rect.position, el)
	var sy: float = 122.0
	for line in lay.summaries:
		draw_string(font, rect.position + Vector2(16, sy + 11) * zoom, line, HORIZONTAL_ALIGNMENT_LEFT, (WIDTH - 32) * zoom, _fs(13), ink)
		sy += 17.0
	var answer = _answer_rect(rect)
	answer_buttons[id] = answer
	draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), answer)
	draw_string(font, answer.position + Vector2(14, 20) * zoom, "Details", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	var link = _link_rect(rect)
	draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 3, 0), link)
	draw_string(font, link.position + Vector2(19, 20) * zoom, "Link", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)

func _draw_circumstantial(id: String, rect: Rect2) -> void:
	var lay: Dictionary = CardLayout.circumstantial_layout(self, id)
	var paper = Color("cde0dc")
	var header = Color("7ea69f")
	var ink = Color("1f2d2b")
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("52736d"), 3 if id == model.selected else 1, 6, 0), rect)
	var head = Rect2(rect.position, Vector2(rect.size.x, 40 * zoom))
	draw_rect(head, header)
	var orphan: bool = model.hub_premise_targets(id).is_empty()
	var chip_text: String = "Needs a premise" if orphan else ("Stage 2 · %d" % lay.incoming_count)
	var chip_col: Color = Color("c98a3d") if orphan else Color("3e665f")
	var cw: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
	draw_string(font, rect.position + Vector2(12, 25) * zoom, "Circumstantial Hub", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - (cw + 22) * zoom, _fs(15), ink)
	var chip = Rect2(rect.position + Vector2(WIDTH - cw - 8, 9) * zoom, Vector2(cw, 22) * zoom)
	draw_style_box(CanvasSkin.flat(chip_col, chip_col.darkened(0.25), 1, 9, 0), chip)
	draw_string(font, chip.position + Vector2(7, 16) * zoom, chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), Color("fbf6ea"))
	tips.append({"rect": chip, "text": "Link this hub into an accusatory Premise card so its supporting material is evaluated." if orphan else "Connected to a Premise: logical cards keep full Stage 1 weight; social framing adds up to +0.015 per incident (+0.045 cap)."})
	var y: float = 54.0
	for ln in lay.lines:
		draw_string(font, rect.position + Vector2(16, y + 11) * zoom, ln, HORIZONTAL_ALIGNMENT_LEFT, (WIDTH - 32) * zoom, _fs(13), ink)
		y += 17.0
	fields[id] = []
	var answer = _answer_rect(rect)
	answer_buttons[id] = answer
	draw_style_box(CanvasSkin.flat(Color("e6f0ee"), Color("5b7f79"), 1, 3, 0), answer)
	draw_string(font, answer.position + Vector2(14, 20) * zoom, "Details", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	var link = _link_rect(rect)
	draw_style_box(CanvasSkin.flat(Color("e6f0ee"), Color("5b7f79"), 1, 3, 0), link)
	draw_string(font, link.position + Vector2(19, 20) * zoom, "Link", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)

func _draw_whereabouts(id: String, rect: Rect2) -> void:
	var lay: Dictionary = CardLayout.whereabouts_layout(self, id)
	var paper = Color("e2e6d6")
	var header = Color("6f8a6a")
	var ink = Color("26291f")
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("4f6249"), 3 if id == model.selected else 1, 6, 0), rect)
	var head = Rect2(rect.position, Vector2(rect.size.x, 40 * zoom))
	draw_rect(head, header)
	draw_rect(Rect2(rect.position + Vector2(0, 37 * zoom), Vector2(rect.size.x, 3.0 * zoom)), Color("475a43"))
	var chip_text: String = "%d fit · %d ?" % [int(lay.fit_count), int(lay.unk_count)]
	var chip_col: Color = Color("497552") if int(lay.fit_count) > 0 else Color("8a6a3b")
	var cw: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
	draw_string(font, rect.position + Vector2(12, 25) * zoom, model.title(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - (cw + 22) * zoom, _fs(15), Color("fbf6ea"))
	var chip = Rect2(rect.position + Vector2(WIDTH - cw - 8, 9) * zoom, Vector2(cw, 22) * zoom)
	draw_style_box(CanvasSkin.flat(chip_col, chip_col.darkened(0.25), 1, 9, 0), chip)
	draw_string(font, chip.position + Vector2(7, 16) * zoom, chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), Color("fbf6ea"))
	tips.append({"rect": chip, "text": "Your record of who was where that day, as one card. Link it into a Premise: the town hears your watches through it."})
	var y: float = 52.0
	for ln in lay.lines:
		draw_string(font, rect.position + Vector2(16, y + 11) * zoom, ln, HORIZONTAL_ALIGNMENT_LEFT, (WIDTH - 32) * zoom, _fs(13), ink)
		y += 17.0
	fields[id] = []
	for el in lay.els:
		_draw_element(id, rect.position, el)
	var answer = _answer_rect(rect)
	answer_buttons[id] = answer
	draw_style_box(CanvasSkin.flat(Color("eef1e6"), Color("62785c"), 1, 3, 0), answer)
	draw_string(font, answer.position + Vector2(14, 20) * zoom, "Details", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	var link = _link_rect(rect)
	draw_style_box(CanvasSkin.flat(Color("eef1e6"), Color("62785c"), 1, 3, 0), link)
	draw_string(font, link.position + Vector2(19, 20) * zoom, "Link", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)

func _draw_trace_chain(id: String, rect: Rect2) -> void:
	var lay: Dictionary = CardLayout.trace_chain_layout(self, id)
	var paper = Color("e8dec8")
	var header = Color("a68456")
	var ink = Color("2b241c")
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("6b563a"), 3 if id == model.selected else 1, 6, 0), rect)
	var head = Rect2(rect.position, Vector2(rect.size.x, 40 * zoom))
	draw_rect(head, header)
	draw_rect(Rect2(rect.position + Vector2(0, 37 * zoom), Vector2(rect.size.x, 3.0 * zoom)), Color("6e5230"))
	var chip_text: String = "%d fit · %d ?" % [int(lay.fit_count), int(lay.unk_count)]
	var chip_col: Color = Color("497552") if int(lay.fit_count) > 0 else Color("8a6a3b")
	var cw: float = font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
	draw_string(font, rect.position + Vector2(12, 25) * zoom, model.title(id), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - (cw + 22) * zoom, _fs(15), Color("fbf6ea"))
	var chip = Rect2(rect.position + Vector2(WIDTH - cw - 8, 9) * zoom, Vector2(cw, 22) * zoom)
	draw_style_box(CanvasSkin.flat(chip_col, chip_col.darkened(0.25), 1, 9, 0), chip)
	draw_string(font, chip.position + Vector2(7, 16) * zoom, chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), Color("fbf6ea"))
	tips.append({"rect": chip, "text": "Bundled physical trace chain + discovered workplace/haunt receipts. Link into a Premise (and link night sightings here or to the Premise on 2-trace scenes)."})
	var y: float = 52.0
	for ln in lay.lines:
		draw_string(font, rect.position + Vector2(16, y + 11) * zoom, ln, HORIZONTAL_ALIGNMENT_LEFT, (WIDTH - 32) * zoom, _fs(13), ink)
		y += 17.0
	fields[id] = []
	for el in lay.els:
		_draw_element(id, rect.position, el)
	var answer = _answer_rect(rect)
	answer_buttons[id] = answer
	draw_style_box(CanvasSkin.flat(Color("f3ead7"), Color("8c7250"), 1, 3, 0), answer)
	draw_string(font, answer.position + Vector2(14, 20) * zoom, "Details", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)
	var link = _link_rect(rect)
	draw_style_box(CanvasSkin.flat(Color("f3ead7"), Color("8c7250"), 1, 3, 0), link)
	draw_string(font, link.position + Vector2(19, 20) * zoom, "Link", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(15), ink)

func _draw_evidence(id: String, rect: Rect2) -> void:
	var node: Dictionary = model.nodes[id]
	var card: Dictionary = _evidence_card(id)
	var lay: Dictionary = CardLayout.evidence_layout(self, id)
	var paper = Color("e8dfc8") if node.kind == "evidence" else Color("e3d6e6")
	var header = Color("c4b185") if node.kind == "evidence" else Color("a98fb0")
	var ink = Color("2c2720")
	var muted = Color("6f6350")
	draw_style_box(CanvasSkin.flat(paper, Color("f7d988") if id == model.selected or id == linking else Color("665c4c"), 3 if id == model.selected else 1, 6, 0), rect)
	var contradicted_by: String = model.contradicted_by(id) if node.kind == "evidence" else ""
	if clashing.has(card.get("id", "")) or contradicted_by != "":
		draw_rect(rect.grow(4 * zoom), Color("c0392b"), false, 3.0 * zoom)
	var head = Rect2(rect.position, Vector2(rect.size.x, 40 * zoom))
	draw_rect(head, header)
	if contradicted_by != "" and model.nodes.has(contradicted_by):
		# Premises step 2: both cards stay; the contradicted one says what contradicts it.
		var tag_text: String = "Contradicted by " + model.title(contradicted_by)
		var tag = Rect2(rect.position + Vector2(0, -24) * zoom, Vector2(rect.size.x, 22) * zoom)
		draw_style_box(CanvasSkin.flat(Color("c0392b"), Color("7d2a20"), 1, 6, 0), tag)
		draw_string(font, tag.position + Vector2(8, 16) * zoom, tag_text, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 16 * zoom, _fs(13), Color("fbf6ea"))
		tips.append({"rect": tag, "text": tag_text + ". If that card is accurate, this one is false. Inspect this card to doubt the other instead, or to remove the contradiction."})
	if node.kind == "modifier" and str(lie_call(str(card.get("id", ""))).get("kind", "")) == "draw" and contradicted_by == "":
		var so = Rect2(rect.position + Vector2(0, -24) * zoom, Vector2(rect.size.x, 22) * zoom)
		draw_style_box(CanvasSkin.flat(Color("8c795c"), TOP_RING, 1, 6, 0), so)
		draw_string(font, so.position + Vector2(8, 16) * zoom, STAND_OFF, HORIZONTAL_ALIGNMENT_LEFT, so.size.x - 16 * zoom, _fs(13), Color("fbf6ea"))
		tips.append({"rect": so, "text": STAND_OFF_TIP})
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
	var time_text: String = CardLayout.time_text(self, card)
	var tw: float = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14 if time_text != "" else 0.0
	draw_string(font, rect.position + Vector2(x, 26) * zoom, title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - (x + tw + 14) * zoom, _fs(16), ink)
	if time_text != "":
		var chip = Rect2(rect.position + Vector2(WIDTH - tw - 8, 10) * zoom, Vector2(tw, 20) * zoom)
		draw_style_box(CanvasSkin.flat(Color("f1e9d6"), Color("8c795c"), 1, 8, 0), chip)
		draw_string(font, chip.position + Vector2(7, 15) * zoom, time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), ink)
	var note: String = str(card.get("support_note", ""))
	tips.append({"rect": head, "text": card.get("text", "") + ("\n" + note if note != "" else "")})
	if CardLayout.unsupported(self, card):
		var bad = Rect2(rect.position + Vector2(0, 40) * zoom, Vector2(rect.size.x, 4) * zoom)
		draw_rect(bad, Color("b55a4c"))
		var badge = Rect2(rect.position + Vector2(WIDTH - 118, 46) * zoom, Vector2(110, 20) * zoom)
		draw_style_box(CanvasSkin.flat(Color("b55a4c"), Color("7d3a30"), 1, 8, 0), badge)
		draw_string(font, badge.position + Vector2(8, 15) * zoom, "Can't be judged", HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(12), Color("fbf6ea"))
		tips.append({"rect": badge, "text": "The shared model can't read this card yet, so a case that uses it can't be presented:\n" + note})
	var y: float = 50.0
	for line in lay.text:
		_draw_named(line, rect.position + Vector2(16, y + 12) * zoom, _fs(14), ink)
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
			draw_string(font, origin + el.at * zoom, el.text, HORIZONTAL_ALIGNMENT_LEFT, (WIDTH - el.at.x - 10) * zoom, _fs(int(el.get("fs", 14))), Color("5a4c38"))
			if el.get("tip", "") != "":
				tips.append({"rect": Rect2(origin + (el.at - Vector2(0, 14)) * zoom, Vector2(WIDTH - el.at.x - 10, 18) * zoom), "text": el.tip})
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

## One line of card text with each townsperson's name in their colour, ink-darkened for
## the parchment as on the case board (Michael, Nov 19).
func _draw_named(line: String, at: Vector2, size: int, ink: Color) -> void:
	var spans: Array = []
	for p in model.view.get("people", []):
		var nm: String = str(p.get("name", ""))
		if nm == "":
			continue
		var from: int = 0
		while true:
			var i: int = line.find(nm, from)
			if i < 0:
				break
			var e: int = i + nm.length()
			if (i == 0 or not line[i - 1].is_valid_identifier()) and (e >= line.length() or not line[e].is_valid_identifier()):
				spans.append([i, e, UITheme.ink_of(C.npc_color(str(p.id)))])
			from = e
	if spans.is_empty():
		draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
		return
	spans.sort_custom(func(a, b): return a[0] < b[0])
	var x: float = 0.0
	var pos: int = 0
	for sp in spans:
		if sp[0] < pos:
			continue
		var plain: String = line.substr(pos, sp[0] - pos)
		draw_string(font, at + Vector2(x, 0), plain, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
		x += font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var named: String = line.substr(sp[0], sp[1] - sp[0])
		draw_string(font, at + Vector2(x, 0), named, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(sp[2], ink.a))
		x += font.get_string_size(named, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos = sp[1]
	draw_string(font, at + Vector2(x, 0), line.substr(pos), HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
