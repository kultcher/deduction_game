## The Workshop canvas: the board, the answer window, the context menu and the subwindows.
## The base of the live Workshop (ui/live_case_workshop.gd), which builds the screen itself.
extends "res://ui/case_workshop.gd"
const CanvasModel = preload("res://workshop/canvas_model.gd")
const CanvasView = preload("res://ui/workshop_canvas_view.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const ComparisonText = preload("res://ui/workshop_comparison.gd")
var board
var canvas
var answer_window: Window
var context_menu: PopupMenu
var context_id = ""
var answer_id = ""
var case_root = ""
var premise_person: OptionButton
var premise_type: OptionButton
var present_button: Button
var selection_label: Label
var preview_window: Window

func _configure_subwindows() -> void:
	# Own the dialog layer inside the Workshop window. Otherwise nested windows
	# can share the game's outer stack and be covered when Workshop regains focus.
	get_window().gui_embed_subwindows = true

func _add_subwindow(window: Window) -> void:
	window.visible = false
	window.transient = true
	window.transient_to_focused = false
	add_child(window)

func _window_body(window: Window) -> VBoxContainer:
	var background = ColorRect.new()
	background.color = WorkshopSkin.color("bg")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	window.add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return body

func _select_card(id: String) -> void:
	if canvas.linking != "":
		var from: String = canvas.linking
		canvas.linking = ""
		var error: String = board.connect_cards(from, id)
		_session_changed()
		status.text = error if error != "" else "Connected. The link's evidence is shared, not counted again."
		return
	board.selected = id
	if board.nodes[id].kind == "premise" and not board.nodes[id].conclusion.is_empty():
		case_root = id
	_sync()
	canvas.queue_redraw()

func _begin_link(id: String) -> void:
	canvas.linking = id
	canvas.queue_redraw()
	status.text = "Linking from %s. Click a destination card; Esc cancels." % board.title(id)

func _open_answer(id: String) -> void:
	answer_id = id
	focus_card = board.nodes[id].get("card", "")
	active_line = ""
	_refresh_case()
	answer_window.popup_centered_clamped()

func _active_choices() -> Dictionary:
	return board.nodes[answer_id] if board != null and board.nodes.has(answer_id) else session.case_data

func _card_available(card: Dictionary) -> bool:
	return board != null and board.nodes.has("e:" + card.id)

func _context(id: String) -> void:
	context_id = id
	context_menu.clear()
	context_menu.add_item("Answer / inspect", 0)
	context_menu.add_item("Link to another card", 1)
	if board.nodes[id].kind == "evidence":
		var report = _report(board.nodes[id].card)
		if report.has("relay_source"):
			# A Medium's relay names its side (Quill, Nov 17): the passing-on, or the original.
			for entry in [[210, "transmission"], [211, "original"]]:
				context_menu.add_item("Challenge: " + board.RELAY_SIDE_TEXT[entry[1]], entry[0])
				context_menu.set_item_disabled(context_menu.get_item_index(entry[0]), report.kind != "report" or report.get("testimony_only", false))
		else:
			for entry in [[200, preload("res://workshop/reading_challenges.gd").HONEST_LABEL.to_lower(), "misled"], [201, "lying", "lying"], [202, "unlikely reading", "unlikely"]]:
				context_menu.add_item("Challenge: " + entry[1], entry[0])
				context_menu.set_item_disabled(context_menu.get_item_index(entry[0]), report.kind != "report" or report.get("unweighable", false) or (entry[2] == "unlikely" and (report.get("role", "") != "surveyor" or not report.get("data", {}).has("count"))))
	if board.nodes[id].kind == "modifier":
		context_menu.add_item("Remove modifier (keep evidence and links)", 203)
	if board.nodes[id].kind == "contradiction":
		context_menu.add_item("Unlink merged contradiction", 2)
	if board.nodes[id].kind == "premise":
		context_menu.add_item("Remove premise (keep its evidence)", 3)
	var edges: Array = board.links.filter(func(e): return e.from == id or e.to == id)
	if edges.size() > 1:
		context_menu.add_item("Unlink all (%d)" % edges.size(), 4)
	for i in range(edges.size()):
		var other: String = edges[i].to if edges[i].from == id else edges[i].from
		context_menu.add_item("Unlink: " + board.title(other), 10 + i)
		if board._gift_link(board.nodes[edges[i].from], board.nodes[edges[i].to]):
			context_menu.add_item(("Use as context: " if edges[i].kind == "explains_outing" else "Use as gift explanation: ") + board.title(other), 1000 + i)
	_extend_context(id)
	context_menu.position = Vector2i(get_viewport().get_mouse_position())
	context_menu.popup()

func _context_action(action: int) -> void:
	if action in [200, 201, 202]:
		var error = board.add_modifier(context_id, ["misled", "lying", "unlikely"][action - 200])
		_session_changed()
		if error != "":
			status.text = error
	elif action in [210, 211]:
		# The passing-on starts as a lie, the original as an honest mistake; the card's chips change it.
		var error_r = board.add_modifier(context_id, "lying" if action == 210 else "misled", "transmission" if action == 210 else "original")
		_session_changed()
		if error_r != "":
			status.text = error_r
	elif action == 203:
		board.remove_modifier(context_id)
		_session_changed()
	elif action == 0:
		_open_answer(context_id)
	elif action == 1:
		_begin_link(context_id)
	elif action == 2:
		board.unmerge(context_id)
		_session_changed()
	elif action == 4:
		# Unlink this card from every card it's linked to (Nov 10).
		for edge in board.links.filter(func(e): return e.from == context_id or e.to == context_id):
			board.unlink(edge.from, edge.to)
		_session_changed()
	elif action == 3:
		board.remove_premise(context_id)
		if not board.nodes.has(case_root):
			case_root = board.selected
		_session_changed()
	elif action >= 1000:
		var edges: Array = board.links.filter(func(e): return e.from == context_id or e.to == context_id)
		var edge: Dictionary = edges[action - 1000]
		edge.kind = "read_together" if edge.kind == "explains_outing" else "explains_outing"
		board.version += 1
		_session_changed()
	elif action >= 10:
		var edges: Array = board.links.filter(func(e): return e.from == context_id or e.to == context_id)
		var edge: Dictionary = edges[action - 10]
		board.unlink(edge.from, edge.to)
		_session_changed()

# ---- Declared for the canvas helpers above; ui/live_case_workshop.gd overrides them.

func _session_changed() -> void:
	pass

func _sync() -> void:
	pass

func _extend_context(_id: String) -> void:
	pass
