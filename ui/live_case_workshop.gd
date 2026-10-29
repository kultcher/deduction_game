## Live editor reuses canvas interactions and supported reading answer controls.
## No fixture jury, hidden roles, or fixture movement weights enter this screen.
extends "res://ui/case_workshop_canvas.gd"
signal filed
signal cards_dropped(numbers: Array)
signal contents_changed
const Live = preload("res://game/workshop_canvas.gd")
const WorkshopSolver = preload("res://workshop/solver.gd")
var g
var case_world
var support_label: Label
var context_label: Label
var result_output: RichTextLabel
var debug_menu: MenuButton
var filed_row: HFlowContainer
var undo_button: Button
var _undo: Dictionary = {}
var _numbers_key = []
var _numbers: Array = []
var field_menu: PopupMenu
var _field_target: Dictionary = {}     # {id, field, values}
var juror_timer: Timer
var _last_juror: Dictionary = {}   # premise id -> {cards, lr}: to say why adding a card weakened it
enum DebugItem { EFFECTS, PREVIEW, SUPPORT, WITHDRAW }
var files: Dictionary = {}
var execute: Callable
var progress_window: Window
var progress_label: Label
var presenting = false

func premise_types() -> Array:
	return TYPES + ["notdemon", "secret_mod", "role", "notrole", "lied", "truthful", "misled", "unreliable"]

func premise_names() -> Array:
	return TYPE_NAMES + ["is not the Demon", "has a secret modifier", "holds their claimed gift", "is bluffing their claimed gift", "lied about a reading", "did not lie about a reading", "was misled by a reading", "gave an unreliable reading"]

func _premise_details(node: Dictionary) -> void:
	var conclusion: Dictionary = node.get("conclusion", {})
	if not conclusion.is_empty() and board.view.get("chronology", {}).has("curse"):
		var epochs: Array = board.view.chronology.epochs.keys()
		var epoch = _option(case_box, epochs)
		epoch.select(epochs.find(conclusion.at))
		epoch.item_selected.connect(func(i): conclusion.at = epochs[i]; _edit())
	if conclusion.get("type") == "secret_mod":
		var kinds: Array = Live.Assess.C.SECRET_MOD_LIST
		var choice = _option(case_box, kinds.map(func(kind): return Live.Assess.C.secret_name(kind)))
		if not conclusion.has("mod"):
			conclusion["mod"] = kinds[0]
		choice.select(kinds.find(conclusion.mod))
		choice.item_selected.connect(func(i): conclusion.mod = kinds[i]; _edit())
	if conclusion.get("type") in ["role", "notrole"]:
		var roles: Array = Live.Assess.C.GOOD_ROLES
		var choice = _option(case_box, roles.map(func(role): return Live.Assess.C.role_name(role)))
		if not conclusion.has("role"):
			var claims: Array = board.view.cards.filter(func(card): return card.source == conclusion.target and card.get("role", "") in roles)
			conclusion["role"] = claims[0].role if not claims.is_empty() else roles[0]
		choice.select(roles.find(conclusion.role))
		choice.item_selected.connect(func(i): conclusion.role = roles[i]; _edit())
		_label(case_box, "Judges this person's included gift declaration. It does not assign an unclaimed role.", 16)
	if conclusion.get("type") in ["lied", "truthful", "misled", "unreliable"]:
		var reports: Array = board.view.cards.filter(func(card): return card.kind == "report" and card.source == conclusion.target and not card.has("relay_source") and not card.get("testimony_only", false))
		var choice = _option(case_box, ["Choose the report being questioned"] + reports.map(func(card): return card.text))
		choice.select(1 + reports.find(reports.filter(func(card): return card.id == conclusion.get("report", ""))[0]) if reports.any(func(card): return card.id == conclusion.get("report", "")) else 0)
		choice.item_selected.connect(func(i):
			if i == 0:
				conclusion.erase("report")
			else:
				conclusion["report"] = reports[i - 1].id
			_edit())
		_label(case_box, "Link that original report and the grounds for questioning it. Lying and impairment remain different explanations.", 16)

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
	var title_row = HBoxContainer.new()
	page.add_child(title_row)
	var title = _label(title_row, "Case Workshop", 28, "accent")
	title.tooltip_text = "Build a case: add a premise, bring in cards from the board (double-click or drag them here), link them, answer their questions, then file and present it.\nDrag a card back out to the left, or right-click it, to remove it. Drafts are kept for this case only."
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	var title_space = Control.new()
	title_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_space)
	debug_menu = MenuButton.new()
	debug_menu.text = "Debug ▾"
	debug_menu.flat = false
	debug_menu.tooltip_text = "Developer tools (shown while Debug is on)."
	var dp: PopupMenu = debug_menu.get_popup()
	dp.add_check_item("Shared evidence evaluator", DebugItem.EFFECTS)
	dp.add_item("Preview effectiveness (test juror)", DebugItem.PREVIEW)
	dp.add_item("Review evaluator support", DebugItem.SUPPORT)
	dp.add_item("Withdraw endorsement…", DebugItem.WITHDRAW)
	dp.id_pressed.connect(_debug_action)
	title_row.add_child(debug_menu)
	var tools = HFlowContainer.new()
	page.add_child(tools)
	# Kept off-screen for callers that still set a person/type before _add_premise.
	premise_person = OptionButton.new()
	premise_type = OptionButton.new()
	for name_value in premise_names():
		premise_type.add_item(name_value)
	premise_type.select(-1)
	var add_button = _button(tools, "Add premise", _add_premise)
	add_button.tooltip_text = "Adds a blank premise. Click its fields to choose who and what you're arguing."
	var add_profile_btn = _button(tools, "Add Townsfolk Profile Info", _open_add_profile_menu)
	add_profile_btn.name = "AddProfileInfo"
	add_profile_btn.tooltip_text = "Adds a townsfolk profile card with selectable Home & Work, Haunts, Personality, and Bonds facets."

	_button(tools, "Fit case", func(): canvas.fit_case())
	_button(tools, "All cards", func(): canvas.fit_case(true))
	undo_button = _button(tools, "Undo remove", _undo_remove)
	undo_button.disabled = true
	context_label = _label(page, "", 16)
	filed_row = HFlowContainer.new()
	page.add_child(filed_row)
	canvas = CanvasView.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(canvas)
	canvas.selected.connect(_select_card)
	canvas.answer_requested.connect(_open_answer)
	canvas.link_requested.connect(_begin_link)
	canvas.context_requested.connect(_context)
	canvas.layout_changed.connect(_store)
	canvas.cards_dropped.connect(func(numbers): cards_dropped.emit(numbers))
	canvas.removal_requested.connect(remove_node)
	canvas.field_requested.connect(_field_popup)
	canvas.detail_label = _detail_label
	canvas.tooltip_text = "Case Workshop"
	field_menu = PopupMenu.new()
	_add_subwindow(field_menu)
	field_menu.id_pressed.connect(_field_chosen)
	juror_timer = Timer.new()
	juror_timer.one_shot = true
	juror_timer.wait_time = 0.45
	juror_timer.timeout.connect(_run_test_juror)
	add_child(juror_timer)
	var actions = HFlowContainer.new()
	page.add_child(actions)
	selection_label = _label(actions, "", 17)
	present_button = _button(actions, "Present in current conversation", _present)
	present_button.name = "PresentLiveCase"
	_button(actions, "File / update case", _file)
	support_label = _label(page, "", 15, "accent")
	support_label.name = "EvaluatorSupport"
	support_label.custom_minimum_size.y = 24
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
		else:
			# A fresh Workshop starts with one blank premise, not a preset accusation.
			var preset: String = board.selected
			var at: Array = board.nodes[preset].at
			board.nodes.erase(preset)
			board.selected = board.add_blank_premise(Vector2(at[0], at[1]))
		case_root = g.workshop_draft.get("root", board.selected)
	# Retain missing transferred originals; they block filing until unlinked.
	# Refreshing the library must never add new evidence copies to the canvas.
	var referenced_profile_ids = {}
	for node in board.nodes.values():
		if node.get("kind") == "profile_info":
			for rid in node.get("receipt_ids", []):
				referenced_profile_ids[rid] = true
	for old in board.view.cards:
		if (board.nodes.has("e:" + old.id) or referenced_profile_ids.has(old.id)) and not next_view.cards.any(func(c): return c.id == old.id):
			var missing: Dictionary = old.duplicate(true)
			missing.support_note = "BLOCKED: original evidence is missing or changed"
			next_view.cards.append(missing)
	board.view = next_view
	session.scenario = {"public_view": next_view}
	canvas.model = board
	premise_person.clear()
	for person in next_view.people:
		premise_person.add_item(person.name)
	premise_person.select(-1)
	_session_changed()
	if reset:
		_fit_after_layout()

func _open_add_profile_menu() -> void:
	if board == null or board.view.people.is_empty():
		return
	field_menu.clear()
	var values: Array = []
	for person in board.view.people:
		var face = WorkshopSkin.tex("art/portraits/" + person.id, 0.08)
		var dead: bool = g != null and g.w.by_id.has(person.id) and not g.w.by_id[person.id].alive
		var text: String = person.name + (" (dead)" if dead else "")
		if face != null:
			field_menu.add_icon_item(face, text, values.size())
		else:
			field_menu.add_item(text, values.size())
		values.append(person.id)
	_field_target = {"id": "", "field": "new_profile_person", "values": values}
	field_menu.position = Vector2i(get_viewport().get_mouse_position())
	field_menu.reset_size()
	field_menu.popup()

func add_profile_info(person_id: String, facet: String = "home_work") -> String:
	if g == null:
		return ""
	refresh()
	var at: Vector2 = (canvas.size / 2.0 - canvas.pan) / maxf(canvas.zoom, 0.1) - Vector2(150, 90)
	if canvas.size.x <= 10.0:
		var idx: int = board.nodes.values().filter(func(n): return n.kind in ["evidence", "profile_info"]).size()
		at = Vector2(60.0 + (idx % 4) * 320.0, 400.0 + (idx / 4) * 300.0)
	var id: String = board.add_profile_info(person_id, [facet] if facet != "" else ["home_work"], at)
	_session_changed()
	canvas.fit_case(true)
	return id

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

func _support_warning(check: Dictionary) -> String:
	if not g.workshop_effects:
		return "Existing rules are explicitly selected. Canvas answers, assumptions and intermediate claims do not gain shared interpretation in this mode."
	if not check.ready:
		return "Unsupported evidence submissions are blocked in ordinary play; they are not silently judged by existing rules. Remove or replace unsupported links. Bare opinions and mercy/protection preferences remain social speech."
	return "The shared evaluator checks this case. Answers and assumptions are hypotheses, not extra evidence."

func _sync() -> void:
	if board == null or not board.nodes.has(board.selected):
		return
	session.case_data = board.compile(case_root)
	selection_label.text = "Selected: " + board.title(board.selected)
	present_button.disabled = board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].get("conclusion", {}).is_empty()
	if not present_button.disabled:
		var check = Live.status(g, board.compile(board.selected))
		var issues: Array = check.issues.duplicate()
		if not g.workshop_effects:
			support_label.text = "Debug: the shared evaluator is switched off; the legacy rules will judge this."
		elif check.ready and check.get("audience_ready", false):
			support_label.text = "Ready: everyone present can judge this case."
		elif check.ready:
			support_label.text = "Some listeners can't judge this case yet (hover for why)."
		else:
			support_label.text = "This case can't be judged yet (hover for why)."
		var reasons: String = "\n".join(PackedStringArray(issues.map(func(i): return "• " + i)))
		support_label.tooltip_text = (reasons + "\n\n" if reasons != "" else "") + _support_warning(check)
		support_label.mouse_filter = Control.MOUSE_FILTER_PASS
		present_button.disabled = check.blocked or g.state not in ["talk", "meeting", "nomination"] or g.w.game_over
	else:
		support_label.text = ""
		support_label.tooltip_text = ""
	context_label.text = "Context: " + g.state + (" · speaking with " + g.talk_with.name if g.state == "talk" and g.talk_with != null else "")
	present_button.text = "Present privately" if g.state == "talk" else "Take meeting floor" if g.state == "meeting" else "Speak on nomination" if g.state == "nomination" else "Start a conversation or meeting to present"
	debug_menu.visible = g.debug_overlay
	var dp: PopupMenu = debug_menu.get_popup()
	dp.set_item_checked(dp.get_item_index(DebugItem.EFFECTS), g.workshop_effects)
	_refresh_filed()
	_store()

func _session_changed() -> void:
	_sync()
	canvas.queue_redraw()
	contents_changed.emit()
	if juror_timer != null and is_inside_tree():
		juror_timer.start()

func _support_details() -> void:
	if board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].conclusion.is_empty():
		return
	var check = Live.status(g, board.compile(board.selected))
	result_output.text = "Selected case: " + board.title(board.selected)
	result_output.text += "\nSHARED EVALUATOR: this case is supported." if check.ready else "\nUNSUPPORTED: shared assessment is unavailable for this case."
	if not g.workshop_effects:
		result_output.text += "\nEXISTING RULES: the shared evaluator is switched off."
	for issue in check.issues:
		result_output.text += "\n• " + issue
	result_output.text += "\n\n" + _support_warning(check)
	result_output.text += "\n\nThis review covers the whole connected case and its current audience. Card labels describe individual interpretations; they do not guarantee that every connected case is supported. Review the listed issues before presenting."
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
		_label(case_box, card.support_note.replace("FALLBACK:", "UNSUPPORTED:"), 17, "accent")
		var editable: bool = (card.kind == "report" and card.role in Live.Assess.ROLES) or card.kind in ["sighting", "secret_claim"] or card.get("context_kind", "") == "psychologist"
		if editable and not card.support_note.begins_with("FALLBACK"):
			_question(card)
		elif not card.support_note.begins_with("FALLBACK"):
			_label(case_box, card.text, 18)
			_label(case_box, "Link this testimony into your argument. Role claims remain conditional on honesty; sightings and alibi discrepancies are circumstantial.", 16)
		else:
			_label(case_box, card.text, 18)
			_label(case_box, "You can inspect this receipt, but it has no supported shared interpretation. Including unsupported evidence blocks an ordinary shared submission; remove it or replace it with supported evidence.", 16)
		_button(case_box, "Done", func(): answer_window.hide(); _session_changed())
	elif node.kind == "profile_info":
		_clear(case_box)
		_label(case_box, board.title(answer_id), 22, "accent")
		_label(case_box, "Select which unlocked profile categories to cite in this case. Newly learned haunts or traits stay out of already-filed cases until you update and re-file.", 16)
		var info: Dictionary = board.view.get("profile_facets", {}).get(node.get("person", ""), {})
		for f in board.PROFILE_FACETS:
			var fdata: Dictionary = info.get(f, {})
			var cb = CheckBox.new()
			cb.text = "%s — %s" % [board.PROFILE_FACET_NAMES[f], fdata.get("summary", "Unknown")]
			cb.button_pressed = f in node.get("facets", [])
			cb.disabled = not fdata.get("unlocked", false)
			var facet_key: String = f
			cb.toggled.connect(func(_on):
				board.toggle_profile_facet(answer_id, facet_key)
				_edit())
			case_box.add_child(cb)
		var available_ids: Array = board._resolve_profile_receipts(node.get("person", ""), node.get("facets", []))
		if available_ids != node.get("receipt_ids", []):
			_button(case_box, "Include newly learned profile details", func():
				board.sync_profile_node(answer_id)
				_edit())
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
		var doubtable: bool = board.report_doubtable(answer_id)
		_label(case_box, ("The report challenges the home alibi: one of them is false. As linked, the alibi is the false one; a report is someone's word, so you can doubt it instead." if doubtable
			else "The sighting challenges the home alibi. Both originals are retained; this is circumstantial evidence, not proof of evil."), 18, "accent")
		for child in node.children:
			_label(case_box, _report(board.nodes[child].card).text, 17)
		if doubtable:
			_button(case_box, "Doubt the report instead (suspected lie)", func():
				var why: String = board.doubt_report(answer_id)
				answer_window.hide()
				_session_changed()
				if why != "":
					status.text = why)
		_button(case_box, "Restore separate cards", func(): board.unmerge(answer_id); answer_window.hide(); _session_changed())
	else:
		# Reuse identity choices, but never display a fixture solver verdict for
		# unsupported live evidence. The live gate below covers the entire case.
		_clear(case_box)
		_label(case_box, board.title(answer_id), 22)
		_label(case_box, "Assumed identities in this line. These are hypotheses, not facts the jury must accept.", 16)
		_premise_details(node)
		if not node.get("conclusion", {}).is_empty():
			var tsum: Dictionary = Live.trace_summary(g, board.compile(answer_id))
			if tsum.get("has_traces", false):
				_label(case_box, tsum.text, 16, "accent")
			var premise_id: String = answer_id
			var found = VBoxContainer.new()
			_button(case_box, "Connections: board cards that bear on this…", func(): _show_connections(premise_id, found))
			case_box.add_child(found)
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
	var compiled_case: Dictionary = board.compile(board.selected)
	var result = Ghost.live(input)
	result_output.text = ComparisonText.describe(result)
	var tsum: Dictionary = Live.trace_summary(g, compiled_case)
	if tsum.get("has_traces", false):
		result_output.text += "\n\n" + tsum.text
	var readiness = Live.status(g, board.compile(board.selected))
	result_output.text += "\n\nEvery current listener can evaluate this case." if readiness.get("audience_ready", false) else "\n\nSome listeners cannot evaluate this case:\n• " + "\n• ".join(PackedStringArray(readiness.issues))
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
		lines.append("%s · %s" % [delivery.name, "Shared evaluator" if delivery.model == "shared" else "Existing rules (explicit route)"])
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

func _debug_action(id: int) -> void:
	match id:
		DebugItem.EFFECTS:
			g.set_workshop_effects(not g.workshop_effects)
			_session_changed()
		DebugItem.PREVIEW:
			_preview_effectiveness()
		DebugItem.SUPPORT:
			_support_details()
		DebugItem.WITHDRAW:
			_withdraw_window()

## Filed cases, newest last: click one to select its premise on the canvas.
func _refresh_filed() -> void:
	if filed_row == null:
		return
	for child in filed_row.get_children():
		child.queue_free()
	var shown: Array = files.keys().filter(func(id): return board.nodes.has(id) and files[id] > 0)
	if shown.is_empty():
		return
	_label(filed_row, "Filed:", 15, "muted")
	for id in shown:
		var key: String = id
		var b = _button(filed_row, "#%d %s" % [files[id], board.title(id)], func():
			_select_card(key)
			canvas.fit_case())
		b.tooltip_text = "Case #%d. Present it from here, or with `present %d` at the meeting." % [files[id], files[id]]
		if id == board.selected:
			b.add_theme_color_override("font_color", WorkshopSkin.color("accent"))

## Remove a card from the canvas (drag out, or right-click). One step of undo.
func remove_node(id: String) -> void:
	if board == null or not board.nodes.has(id):
		return
	var node: Dictionary = board.nodes[id]
	var title_text: String = board.title(id)
	_undo = {"canvas": board.export_data(), "root": case_root, "files": files.duplicate(true)}
	match node.kind:
		"evidence":
			board.remove_evidence(id)
		"profile_info":
			board.remove_profile_info(id)
		"modifier":
			board.remove_modifier(id)
		"contradiction":
			board.unmerge(id)
		"premise":
			board.remove_premise(id)
			files.erase(id)
	if not board.nodes.has(case_root):
		case_root = board.selected
	undo_button.disabled = false
	_session_changed()
	status.text = "Removed %s from the Workshop. The original stays on the case board." % title_text

func _undo_remove() -> void:
	if _undo.is_empty():
		return
	var saved: Dictionary = _undo.canvas
	board.nodes = saved.nodes.duplicate(true)
	board.links = saved.links.duplicate(true)
	board.selected = saved.selected
	board.serial = saved.serial
	board.version = saved.version + 1
	case_root = _undo.root
	files = _undo.files.duplicate(true)
	_undo = {}
	undo_button.disabled = true
	_session_changed()
	status.text = "Restored."

func _extend_context(id: String) -> void:
	if board.nodes.has(id) and board.nodes[id].kind in ["evidence", "profile_info", "modifier"]:
		context_menu.add_separator()
		context_menu.add_item("Remove from Workshop", 204)

func _context_action(action: int) -> void:
	if action == 204:
		remove_node(context_id)
		return
	super(action)

## Board card numbers whose evidence is on this canvas (cached per canvas version).
func board_numbers() -> Array:
	if board == null or g == null:
		return []
	var key = [board.version, board.nodes.size(), g.board.size(), case_world == g.w]
	if key == _numbers_key:
		return _numbers
	_numbers_key = key
	_numbers = []
	for receipt in g.board:
		if receipt.kind == "deduction" or receipt.get("deleted", false):
			continue
		if board.nodes.has("e:" + Live.Evidence.normalize_card(receipt).id):
			_numbers.append(receipt.n)
	return _numbers

# ------------------------------------------------------------ premises on the card

## Add a premise. Blank unless a claim type was preselected (scripted callers).
func _add_premise() -> void:
	if board.nodes.values().filter(func(n): return n.kind == "premise").size() >= 12:
		status.text = "A case board holds up to twelve premises."
		return
	var at: Vector2 = (canvas.size / 2.0 - canvas.pan) / canvas.zoom - Vector2(150, 110)
	if premise_type.selected >= 0:
		var people: Array = session.scenario.public_view.people
		var target: String = people[maxi(premise_person.selected, 0)].id
		board.selected = board.add_premise(target, (premise_types() + ["support"])[premise_type.selected], at)
		if not board.nodes[board.selected].conclusion.is_empty():
			case_root = board.selected
	else:
		board.selected = board.add_blank_premise(at)
	_session_changed()

## Choose one field of a premise: "person", "type", "role", "mod", "report", "epoch".
func set_premise_field(id: String, field: String, value) -> void:
	if not board.nodes.has(id) or board.nodes[id].kind != "premise":
		return
	var node: Dictionary = board.nodes[id]
	if node.get("draft", false):
		var pick: Dictionary = node.get("pick", {})
		if field == "person":
			pick["target"] = value
		elif field == "type":
			pick["type"] = value
		node["pick"] = pick
		var type: String = pick.get("type", "")
		if type == "support":
			node.erase("draft")
			node.erase("pick")
			node.conclusion = {}
		elif type != "" and (pick.has("target") or type == "conflict"):
			node.erase("draft")
			node.erase("pick")
			node.conclusion = {"type": type, "target": pick.get("target", board._default_target()), "at": board.view.alignment_epoch}
			_default_detail(node)
			case_root = id
	elif field == "type" and value == "support":
		node.conclusion = {}
	elif field == "type":
		var target: String = node.conclusion.get("target", board._default_target())
		node.conclusion = {"type": value, "target": target, "at": node.conclusion.get("at", board.view.alignment_epoch)}
		_default_detail(node)
		case_root = id
	elif field == "person":
		if node.conclusion.is_empty():
			return
		node.conclusion.target = value
		node.conclusion.erase("report")
		_default_detail(node)
	elif field == "epoch":
		node.conclusion.at = value
	elif field in ["role", "mod", "report"]:
		node.conclusion[field] = value
	board.selected = id
	_edit()

func _default_detail(node: Dictionary) -> void:
	var conclusion: Dictionary = node.conclusion
	match conclusion.get("type", ""):
		"role", "notrole":
			if not conclusion.has("role"):
				var roles: Array = C.GOOD_ROLES
				var claims: Array = board.view.cards.filter(func(card): return card.source == conclusion.target and card.get("role", "") in roles)
				conclusion["role"] = claims[0].role if not claims.is_empty() else roles[0]
		"secret_mod":
			if not conclusion.has("mod"):
				conclusion["mod"] = C.SECRET_MOD_LIST[0]

func _reports_for(person: String) -> Array:
	return board.view.cards.filter(func(card): return card.kind == "report" and card.source == person and not card.has("relay_source") and not card.get("testimony_only", false))

## The premise's third field, when its claim needs one (or the time, in curse games).
func _detail_label(node: Dictionary) -> Dictionary:
	var conclusion: Dictionary = node.get("conclusion", {})
	if node.get("draft", false) or conclusion.is_empty():
		return {}
	match conclusion.type:
		"role", "notrole":
			return {"field": "role", "text": C.role_name(conclusion.get("role", "")), "icon": WorkshopSkin.tex("ui/roles/" + conclusion.get("role", ""), 0.06),
				"tip": "The gift this premise is about. It judges the person's own declaration; it doesn't assign an unclaimed role."}
		"secret_mod":
			return {"field": "mod", "text": C.secret_name(conclusion.get("mod", "")), "icon": WorkshopSkin.tex("ui/roles/" + conclusion.get("mod", ""), 0.06),
				"tip": "Which secret modifier you're arguing they hold."}
		"lied", "truthful", "misled", "unreliable":
			var report: Dictionary = {}
			for card in _reports_for(conclusion.target):
				if card.id == conclusion.get("report", ""):
					report = card
			return {"field": "report", "text": report.text if not report.is_empty() else "Choose the reading", "missing": report.is_empty(),
				"icon": WorkshopSkin.tex("ui/roles/" + report.role, 0.06) if not report.is_empty() and report.has("role") else null,
				"tip": "The reading this premise questions. Link that reading and your grounds to the premise. Lying and impairment are different explanations."}
	if board.view.get("chronology", {}).has("curse"):
		return {"field": "epoch", "text": "When: " + str(conclusion.at), "tip": "Which time this premise is about (before, during or after the curse)."}
	return {}

func _field_popup(id: String, field: String) -> void:
	var node: Dictionary = board.nodes[id]
	if node.kind == "profile_info":
		if field == "profile_person":
			board.selected = id
			field_menu.clear()
			var p_values: Array = []
			for person in board.view.people:
				var face = WorkshopSkin.tex("art/portraits/" + person.id, 0.08)
				var dead: bool = g != null and g.w.by_id.has(person.id) and not g.w.by_id[person.id].alive
				var p_text: String = person.name + (" (dead)" if dead else "")
				if face != null:
					field_menu.add_icon_item(face, p_text, p_values.size())
				else:
					field_menu.add_item(p_text, p_values.size())
				p_values.append(person.id)
			_field_target = {"id": id, "field": "profile_person", "values": p_values}
			_sync()
			canvas.queue_redraw()
			field_menu.position = Vector2i(get_viewport().get_mouse_position())
			field_menu.reset_size()
			field_menu.popup()
		elif field.begins_with("facet:"):
			board.toggle_profile_facet(id, field.trim_prefix("facet:"))
			_edit()
		elif field == "sync_profile":
			board.sync_profile_node(id)
			_edit()
		return
	if node.kind != "premise":
		set_evidence_field(id, field)
		return
	board.selected = id
	field_menu.clear()
	var values: Array = []
	match field:
		"person":
			for person in board.view.people:
				var face = WorkshopSkin.tex("art/portraits/" + person.id, 0.08)
				var dead: bool = g != null and g.w.by_id.has(person.id) and not g.w.by_id[person.id].alive
				var text: String = person.name + (" (dead)" if dead else "")
				if face != null:
					field_menu.add_icon_item(face, text, values.size())
				else:
					field_menu.add_item(text, values.size())
				values.append(person.id)
		"type":
			var types: Array = premise_types()
			for i in range(types.size()):
				field_menu.add_item(board.PREMISE_TEXT.get(types[i], types[i]), values.size())
				values.append(types[i])
		"role":
			for role in C.GOOD_ROLES:
				var icon = WorkshopSkin.tex("ui/roles/" + role, 0.06)
				if icon != null:
					field_menu.add_icon_item(icon, C.role_name(role), values.size())
				else:
					field_menu.add_item(C.role_name(role), values.size())
				values.append(role)
		"mod":
			for kind in C.SECRET_MOD_LIST:
				field_menu.add_item(C.secret_name(kind), values.size())
				values.append(kind)
		"report":
			for card in _reports_for(node.conclusion.get("target", "")):
				field_menu.add_item(card.text, values.size())
				values.append(card.id)
			if values.is_empty():
				field_menu.add_item("No readings from this person on the canvas yet", 999)
				field_menu.set_item_disabled(0, true)
		"epoch":
			for epoch in board.view.chronology.epochs.keys():
				field_menu.add_item(str(epoch), values.size())
				values.append(epoch)
	_field_target = {"id": id, "field": field, "values": values}
	_sync()
	canvas.queue_redraw()
	field_menu.position = Vector2i(get_viewport().get_mouse_position())
	field_menu.reset_size()
	field_menu.popup()

func _field_chosen(index: int) -> void:
	if _field_target.is_empty() or index < 0 or index >= _field_target.values.size():
		return
	var target: Dictionary = _field_target
	_field_target = {}
	if target.field == "new_profile_person":
		add_profile_info(target.values[index], "home_work")
		return
	if target.field == "profile_person":
		board.set_profile_person(target.id, target.values[index])
		_edit()
		return
	if target.field == "why":
		var node: Dictionary = board.nodes[target.id]
		var choice: Array = target.values[index]
		node.reasons[target.key] = choice[0]
		if choice[1] != "":
			node.citations[target.key] = choice[1]
		else:
			node.citations.erase(target.key)
		board.selected = target.id
		_edit()
		return
	set_premise_field(target.id, target.field, target.values[index])

## Run the test juror on every premise with a claim (after a pause in editing).
func _run_test_juror() -> void:
	if board == null or g == null or case_world != g.w:
		return
	var badges: Dictionary = {}
	for id in board.nodes:
		var node: Dictionary = board.nodes[id]
		if node.kind != "premise" or node.get("draft", false) or node.conclusion.is_empty():
			continue
		var value: Dictionary = board.compile(id)
		if value.cards.is_empty():
			badges[id] = {"ready": true, "category": "empty", "text": "No evidence is linked to this premise yet.", "reason": "Link cards to it to build the case."}
			continue
		var badge: Dictionary = Live.test_juror(g, value)
		if badge.get("ready", false):
			_explain_change(id, value, badge)
			_idle_assumptions(node, value, badge)
		badges[id] = badge
	canvas.badges = badges
	var clashing: Dictionary = {}
	for id in badges:
		for card in badges[id].get("clashing", []):
			clashing[card] = true
	canvas.clashing = clashing
	canvas.queue_redraw()

## "Connections": up to five board cards that would move this premise most (one click adds
## a card and links it). Runs on demand: one test-juror pass per candidate.
func _show_connections(premise: String, box: VBoxContainer) -> void:
	_clear(box)
	_label(box, "Looking through the board…", 15)
	await get_tree().process_frame
	var found: Array = Live.connections(g, board.compile(premise))
	_clear(box)
	if found.is_empty():
		_label(box, "No other card on the board moves this premise.", 15)
		return
	for c in found:
		var row = HBoxContainer.new()
		box.add_child(row)
		var number: int = c.number
		var card_id: String = c.id
		_button(row, "Add", func():
			add_evidence(number)
			board.connect_cards("e:" + card_id, premise)
			_session_changed()
			_show_connections(premise, box))
		var text: Label = _label(row, "#%d %s (%s)" % [number, c.text, "strengthens it" if c.helps else "argues against it"], 15)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not c.helps:
			text.add_theme_color_override("font_color", Color("c0392b"))

## Adding one card made the case weaker: say which card and who else it brings in, and
## what kind of card would explain their part.
func _explain_change(id: String, value: Dictionary, badge: Dictionary) -> void:
	var before: Dictionary = _last_juror.get(id, {})
	_last_juror[id] = {"cards": value.cards.duplicate(), "lr": badge.get("lr", 1.0)}
	if before.is_empty():
		return
	var added: Array = value.cards.filter(func(c): return c not in before.cards)
	if added.size() != 1 or before.cards.any(func(c): return c not in value.cards):
		return
	var lr: float = badge.get("lr", 1.0)
	if lr >= before.lr * 0.8 or before.lr <= 1.0:
		return
	var card: Dictionary = _report(added[0])
	var target: String = value.conclusion.get("target", "")
	var others: Array = []
	for who in card.get("subjects", [card.get("subject", "")]) + card.get("data", {}).get("seen", []) + card.get("data", {}).get("pair", []):
		if who is String and who != "" and who != target and who not in others and board.view.people.any(func(p): return p.id == who):
			others.append(who)
	var note: String = "Adding \"%s\" weakened this." % card.get("text", "that card")
	if not others.is_empty():
		var names: Array = others.map(func(who): return WorkshopSolver.person_name(board.view, who))
		note += " It also involves %s, and nothing here explains their part; a gift claim or an alibi of theirs could." % " and ".join(PackedStringArray(names))
	badge["change"] = note

## Assumptions on this premise that change nothing in the test juror's view.
func _idle_assumptions(node: Dictionary, value: Dictionary, badge: Dictionary) -> void:
	var idle: Array = []
	for person in node.get("positions", {}):
		var without: Dictionary = value.duplicate(true)
		without.positions.erase(person)
		var r: Dictionary = Live.test_juror(g, without)
		if r.get("ready", false) and absf(log(maxf(r.get("lr", 1.0), 0.000001)) - log(maxf(badge.get("lr", 1.0), 0.000001))) < 0.02:
			idle.append(person)
	if not idle.is_empty():
		badge["idle"] = idle

# ------------------------------------------------------------ answers on evidence cards

## A click on an evidence card's answer: "pick:<id>", "block:<b>", "resident:<id>",
## "reg:<reason>", "why:<id>" (opens a menu), "mode:<challenge>".
func set_evidence_field(id: String, field: String) -> void:
	var node: Dictionary = board.nodes[id]
	var card: Dictionary = _report(node.card)
	var kind: String = field.get_slice(":", 0)
	var value: String = field.substr(kind.length() + 1)
	board.selected = id
	if kind == "mode":
		if node.kind == "modifier" and not (value == "unlikely" and card.get("role", "") != "surveyor"):
			node.mode = value
			_edit()
		return
	if kind == "why":
		_reason_menu(id, card, value)
		return
	node.answers[card.id] = board.apply_answer(card, node.answers.get(card.id, {}), kind, value)
	_edit()

## Why someone seen at night was out: unexplained, a walking gift (citing their
## claim), an evil errand, or a private errand (citing their errand claim).
func _reason_menu(id: String, card: Dictionary, person: String) -> void:
	field_menu.clear()
	var key: String = "%s:%d" % [person, card.get("night", -1)]
	var options: Array = [["unexplained", ""]]
	field_menu.add_item("? Unexplained", 0)
	for claim in board.view.cards.filter(func(c): return c.kind == "claim" and c.subject == person):
		field_menu.add_item("Out on their gift: " + C.role_name(claim.role) + " claim", options.size())
		options.append(["gift", claim.id])
	field_menu.add_item("Evil errand", options.size())
	options.append(["evil", ""])
	if board.view.get("live_activity", false) or board.view.has("movement_experiment"):
		for claim in board.view.cards.filter(func(c): return c.kind == "secret_claim" and c.subject == person):
			field_menu.add_item("Private errand (their own account)", options.size())
			options.append(["secret", claim.id])
	_field_target = {"id": id, "field": "why", "values": options, "key": key}
	field_menu.position = Vector2i(get_viewport().get_mouse_position())
	field_menu.reset_size()
	field_menu.popup()
