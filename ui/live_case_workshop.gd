## Live editor reuses canvas interactions and supported reading answer controls.
## No fixture jury, hidden roles, or fixture movement weights enter this screen.
extends "res://ui/case_workshop_canvas.gd"
signal filed
const Live = preload("res://game/workshop_canvas.gd")
var g
var case_world
var support_label: Label
var context_label: Label
var result_output: RichTextLabel
var effects_toggle: CheckBox
var files: Dictionary = {}
var execute: Callable
var progress_window: Window
var progress_label: Label
var presenting = false

func _ready() -> void:
	_configure_subwindows()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = WorkshopSkin.make()
	theme.default_font_size = 17
	var background = ColorRect.new()
	background.color = WorkshopSkin.color("bg")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var page = VBoxContainer.new()
	margin.add_child(page)
	_label(page, "Make a Case · live evidence", 28, "accent")
	var tools = HFlowContainer.new()
	page.add_child(tools)
	premise_person = _option(tools, [])
	premise_type = _option(tools, TYPE_NAMES + ["Supporting evidence (no claim)"])
	_button(tools, "Add premise", _add_premise)
	_button(tools, "Refresh evidence", refresh)
	_button(tools, "Fit case", func(): canvas.fit_case())
	_button(tools, "All evidence", func(): canvas.fit_case(true))
	effects_toggle = CheckBox.new()
	effects_toggle.text = "Experimental reading evaluator"
	effects_toggle.tooltip_text = "Opt in for this case. NPC Insight limits attention and alternative searches; confidence sustains revisable theories. Supports Surveyor, Rumormonger, Dowser, Clerk, Archivist and Seer readings, role claims and night alibi challenges. Other cases use the existing argument rules."
	effects_toggle.toggled.connect(func(on):
		g.set_workshop_effects(on)
		_session_changed())
	page.add_child(effects_toggle)
	context_label = _label(page, "", 16)
	_label(page, "Add cards from the Case Board using Add to Case Workshop · drag cards or empty space · wheel to zoom · Link, then choose a destination. Drafts are kept for this case only.", 14, "muted")
	canvas = CanvasView.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(canvas)
	canvas.selected.connect(_select_card)
	canvas.answer_requested.connect(_open_answer)
	canvas.link_requested.connect(_begin_link)
	canvas.context_requested.connect(_context)
	canvas.layout_changed.connect(_store)
	var actions = HFlowContainer.new()
	page.add_child(actions)
	selection_label = _label(actions, "", 17)
	present_button = _button(actions, "Present in current conversation", _present)
	present_button.name = "PresentLiveCase"
	_button(actions, "File / update case", _file)
	_button(actions, "Preview effectiveness", _preview_effectiveness)
	_button(actions, "Review evaluator support", _support_details)
	_button(actions, "Withdraw endorsement…", _withdraw_window)
	support_label = _label(page, "", 15, "accent")
	support_label.name = "EvaluatorSupport"
	support_label.custom_minimum_size.y = 75
	status = _label(page, "", 15, "muted")
	context_menu = PopupMenu.new()
	_add_subwindow(context_menu)
	context_menu.id_pressed.connect(_context_action)
	answer_window = Window.new()
	answer_window.title = "Answer this live card"
	answer_window.size = Vector2i(650, 700)
	answer_window.visible = false
	answer_window.close_requested.connect(func():
		answer_window.hide()
		answer_id = ""
		_session_changed())
	_add_subwindow(answer_window)
	case_box = _window_body(answer_window)
	preview_window = Window.new()
	preview_window.title = "Live case · preview and presentation feedback"
	preview_window.size = Vector2i(760, 720)
	preview_window.visible = false
	preview_window.close_requested.connect(func(): preview_window.hide())
	_add_subwindow(preview_window)
	result_output = RichTextLabel.new()
	result_output.custom_minimum_size = Vector2(660, 610)
	result_output.selection_enabled = true
	_window_body(preview_window).add_child(result_output)
	progress_window = Window.new()
	progress_window.title = "Presenting the case"
	progress_window.size = Vector2i(600, 200)
	progress_window.visible = false
	progress_window.exclusive = true
	_add_subwindow(progress_window)
	progress_label = _label(_window_body(progress_window), "", 18)
	refresh()

func refresh() -> void:
	if canvas == null:
		return
	var next_view = Live.view(g)
	var reset: bool = case_world != g.w
	if reset:
		case_world = g.w
		answer_window.hide()
		preview_window.hide()
		answer_id = ""
		# The public library stays current for receipt lookup and answer controls;
		# only explicitly transferred cards get a copy on the live canvas.
		var empty_view = next_view.duplicate()
		empty_view.cards = []
		board = CanvasModel.new(empty_view)
		files = g.workshop_draft.get("files", {}).duplicate(true)
		if g.workshop_draft.has("canvas"):
			var saved: Dictionary = g.workshop_draft.canvas
			board.nodes = saved.nodes.duplicate(true)
			board.links = saved.links.duplicate(true)
			board.selected = saved.selected
			board.serial = saved.serial
			board.version = saved.version
		case_root = g.workshop_draft.get("root", board.selected)
	# Retain missing transferred originals; they block filing until unlinked.
	# Refreshing the library must never add new evidence copies to the canvas.
	for old in board.view.cards:
		if board.nodes.has("e:" + old.id) and not next_view.cards.any(func(c): return c.id == old.id):
			var missing: Dictionary = old.duplicate(true)
			missing.support_note = "BLOCKED: original evidence is missing or changed"
			next_view.cards.append(missing)
	board.view = next_view
	session.scenario = {"public_view": next_view}
	canvas.model = board
	premise_person.clear()
	for person in next_view.people:
		premise_person.add_item(person.name)
	effects_toggle.set_pressed_no_signal(g.workshop_effects)
	_session_changed()
	if reset:
		_fit_after_layout()

func add_evidence(number: int) -> void:
	if number < 1 or number > g.board.size():
		return
	var receipt: Dictionary = g.board[number - 1]
	if receipt.kind == "deduction" or receipt.get("deleted", false):
		return
	refresh()
	var card_id: String = Live.Evidence.normalize_card(receipt).id
	var id: String = "e:" + card_id
	if not board.nodes.has(id):
		var i: int = board.nodes.values().filter(func(n): return n.kind == "evidence").size()
		board.nodes[id] = {"id": id, "kind": "evidence", "card": card_id,
			"at": [60.0 + (i % 4) * 320.0, 400.0 + (i / 4) * 300.0], "answers": {}, "reasons": {}, "citations": {}}
		board.version += 1
	board.selected = id
	_session_changed()
	canvas.fit_case(true)

func _fit_after_layout() -> void:
	await get_tree().process_frame
	if is_instance_valid(canvas):
		canvas.fit_case()

func _store() -> void:
	if board != null and case_world == g.w:
		g.workshop_draft = {"canvas": board.export_data(), "files": files.duplicate(true), "root": case_root}

func _sync() -> void:
	if board == null or not board.nodes.has(board.selected):
		return
	session.case_data = board.compile(case_root)
	selection_label.text = "Selected: " + board.title(board.selected)
	present_button.disabled = board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].get("conclusion", {}).is_empty()
	if not present_button.disabled:
		var check = Live.status(g, board.compile(board.selected))
		var caption = "NEW EVALUATOR · reading logic supported" if check.ready else "FALLBACK · new evaluator cannot fully handle this case"
		if not g.workshop_effects:
			caption = "EXISTING RULES · experimental evaluator is switched off"
		support_label.text = caption
		for issue in check.issues.slice(0, 3):
			support_label.text += "\n• " + issue
		if check.issues.size() > 3:
			support_label.text += "\n%d more support issues — use Review evaluator support for the full list." % (check.issues.size() - 3)
		if not check.ready or not g.workshop_effects:
			support_label.text += "\n" + check.warning
		else:
			support_label.text += "\nAnswers and assumptions are hypotheses, not extra evidence. Listener knowledge, ownership or workload limits can still require fallback; actual results are reported after presentation."
		present_button.disabled = check.blocked or g.state not in ["talk", "meeting", "nomination"] or g.w.game_over
	else:
		support_label.text = "Select a premise to see support for the entire connected case. Card labels describe individual evidence only."
	context_label.text = "Context: " + g.state + (" · speaking with " + g.talk_with.name if g.state == "talk" and g.talk_with != null else "")
	present_button.text = "Present privately" if g.state == "talk" else "Take meeting floor" if g.state == "meeting" else "Speak on nomination" if g.state == "nomination" else "Start a conversation or meeting to present"
	_store()

func _session_changed() -> void:
	_sync()
	canvas.queue_redraw()

func _support_details() -> void:
	if board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].conclusion.is_empty():
		return
	var check = Live.status(g, board.compile(board.selected))
	result_output.text = "Selected case: " + board.title(board.selected)
	result_output.text += "\nReading interpretation supported." if check.ready else "\nFALLBACK: this case is not fully handled by the new evaluator."
	if not g.workshop_effects:
		result_output.text += "\nExperimental reading effects are switched off."
	for issue in check.issues:
		result_output.text += "\n• " + issue
	result_output.text += "\n\n" + check.warning
	result_output.text += "\n\nSupports reading constraints, night movement and trace comparisons, quiet-night support, and supported single Medium relays. Card labels describe each available interpretation. Old traces without scene metadata, dated Martyr failures, nested relays, and conversion histories still require fallback. Medium cause modifiers need a choice of which source to question. Listener knowledge and workload limits can also require fallback."
	preview_window.popup_centered_clamped()

func _edit() -> void:
	board.version += 1
	_session_changed()
	_refresh_case()
	status.text = "Draft updated. File and present it again to replace the previous argument for that listener."

func _refresh_case() -> void:
	if answer_id == "" or not board.nodes.has(answer_id):
		return
	var node: Dictionary = board.nodes[answer_id]
	if node.kind == "evidence":
		_clear(case_box)
		var card: Dictionary = _report(node.card)
		_label(case_box, card.support_note, 17, "accent")
		if card.kind == "report" and card.role in ["surveyor", "rumormonger", "dowser", "clerk", "archivist", "seer", "nightwatch", "gravedigger", "veteran", "lamplighter", "martyr", "sexton"] and not card.support_note.begins_with("FALLBACK"):
			_question(card)
		elif not card.support_note.begins_with("FALLBACK"):
			_label(case_box, card.text, 18)
			_label(case_box, "Link this testimony into your argument. Role claims remain conditional on honesty; sightings and alibi discrepancies are circumstantial.", 16)
		else:
			_label(case_box, card.text, 18)
			_label(case_box, "You can link this card and present the case using existing rules. A live answer/relationship evaluator for this evidence has not been implemented; it contributes no new-model inference.", 16)
		_button(case_box, "Done", func(): answer_window.hide(); _session_changed())
	elif node.kind == "modifier":
		_clear(case_box)
		_label(case_box, board.title(answer_id), 22)
		_label(case_box, "Link grounds to this modifier. It asks the listener to assess your explanation; selecting it does not prove error or deception.", 17)
		var option = _option(case_box, ["Misled reading", "Suspected lie", "Unlikely reading"])
		option.select(["misled", "lying", "unlikely"].find(node.mode))
		option.set_item_disabled(2, _report(node.card).get("role") != "surveyor")
		option.item_selected.connect(func(i): node.mode = ["misled", "lying", "unlikely"][i]; _edit())
	elif node.kind == "contradiction":
		_clear(case_box)
		_label(case_box, "The sighting challenges the home alibi. Both originals are retained; this is circumstantial evidence, not proof of evil.", 18, "accent")
		for child in node.children:
			_label(case_box, _report(board.nodes[child].card).text, 17)
		_button(case_box, "Restore separate cards", func(): board.unmerge(answer_id); answer_window.hide(); _session_changed())
	else:
		# Reuse identity choices, but never display a fixture solver verdict for
		# unsupported live evidence. The live gate below covers the entire case.
		_clear(case_box)
		_label(case_box, board.title(answer_id), 22)
		_label(case_box, "Assumed identities in this line. These are hypotheses, not facts the jury must accept.", 16)
		for person in board.view.people:
			var row = HBoxContainer.new()
			case_box.add_child(row)
			_label(row, person.name, 17).custom_minimum_size.x = 170
			var option = _option(row, ["? Unresolved", "Good", "Evil", "Good · Marked"])
			option.select(["", "good", "evil", "marked"].find(node.positions.get(person.id, "")))
			option.item_selected.connect(func(i):
				if i == 0:
					node.positions.erase(person.id)
				else:
					node.positions[person.id] = ["", "good", "evil", "marked"][i]
				_edit())

func _file() -> int:
	if g.w != case_world:
		refresh()
		return -1
	if board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].conclusion.is_empty():
		status.text = "Select a premise with a claim to file."
		return -1
	var value = board.compile(board.selected)
	var number = Live.file(g, value, files.get(board.selected, 0))
	if number > 0:
		files[board.selected] = number
		var originals: Array = Live.supports(g, value).numbers
		status.text = "Filed / updated case #%d with originals %s. %d disconnected evidence cards are scratch work. Nobody's beliefs change until presentation." % [number, str(originals), board.nodes.values().filter(func(n): return n.kind == "evidence" and n.card not in value.cards).size()]
		_store()
		filed.emit()
	else:
		status.text = g.last_error
	return number

func _preview_effectiveness() -> void:
	if board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].conclusion.is_empty():
		return
	var input = Live.snapshot(g, board.compile(board.selected))
	result_output.text = "Calculating neutral reference response…"
	preview_window.popup_centered_clamped()
	await get_tree().process_frame
	var result = Ghost.live(input)
	result_output.text = ComparisonText.describe(result)
	if not result.ready:
		result_output.text += "\n\nNo effectiveness estimate is available for the existing-rules fallback. " + Live.status(g, board.compile(board.selected)).warning

func _present() -> void:
	if present_button.disabled:
		return
	var number = _file()
	if number < 1:
		return
	if g.state == "nomination":
		var window = ConfirmationDialog.new()
		window.title = "Speak on this nomination"
		window.dialog_text = "Use your one statement to accuse or defend the current nominee. The case's headline stays as written; this choice also has the usual social effects."
		window.ok_button_text = "Accuse"
		window.cancel_button_text = "Cancel"
		window.add_button("Defend", true, "defend")
		window.confirmed.connect(func(): _send("accuse %d" % number); window.queue_free())
		window.custom_action.connect(func(_action): _send("defend %d" % number); window.queue_free())
		window.canceled.connect(window.queue_free)
		_add_subwindow(window)
		window.popup_centered_clamped()
	else:
		_send(("convince %d" if g.state == "talk" else "present %d") % number)

func _send(command: String) -> void:
	if presenting or not execute.is_valid():
		return
	presenting = true
	g.workshop_deliveries.clear()
	status.text = "Presenting case; calculating listener responses…"
	progress_label.text = "Calculating listener responses; completed assessments are reused when possible."
	progress_window.popup_centered_clamped()
	await get_tree().process_frame
	await execute.call(command, _progress)
	progress_window.hide()
	presenting = false
	var lines: Array = []
	for delivery in g.workshop_deliveries:
		lines.append("%s · %s" % [delivery.name, "New shared evaluator" if delivery.model == "shared" else "FALLBACK: existing rules"])
		for issue in delivery.issues:
			lines.append("  " + issue)
	if lines.is_empty():
		lines.append("No case assessment was delivered. Check the main conversation log for the current action limit or error.")
	result_output.text = "\n".join(PackedStringArray(lines))
	preview_window.popup_centered_clamped()
	refresh()

func _progress(name_value: String) -> void:
	progress_label.text = "Assessing %s's response…\n%d listener responses completed." % [name_value, g.workshop_deliveries.size()]
	await get_tree().process_frame

func _withdraw_window() -> void:
	var number: int = files.get(board.selected, 0)
	if number <= 0:
		status.text = "Select a filed premise to withdraw its endorsement."
		return
	var window = Window.new()
	window.title = "Developer withdrawal · case #%d" % number
	window.size = Vector2i(520, 360)
	window.close_requested.connect(window.queue_free)
	_add_subwindow(window)
	var body = _window_body(window)
	_label(body, "Testing tool: removes this case's endorsement. Independently learned reports stay known. This is not an in-character retraction conversation.", 17)
	var person = _option(body, g.w.npcs.map(func(n): return n.name))
	_button(body, "Withdraw for selected listener", func():
		g.workshop_retract(number, g.w.npcs[person.selected].id)
		status.text = "Endorsement withdrawn for " + g.w.npcs[person.selected].name
		window.queue_free())
	window.popup_centered_clamped()
