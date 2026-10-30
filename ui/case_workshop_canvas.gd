## Canvas front end for the existing, isolated 692 Workshop interpreter.
extends "res://ui/case_workshop.gd"
const CanvasModel = preload("res://workshop/canvas_model.gd")
const CanvasView = preload("res://ui/workshop_canvas_view.gd")
const Fixtures = preload("res://workshop/fixtures.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const ComparisonText = preload("res://ui/workshop_comparison.gd")
var board
var canvas
var answer_window: Window
var jury_window: Window
var context_menu: PopupMenu
var context_id = ""
var answer_id = ""
var case_root = ""
var premise_person: OptionButton
var premise_type: OptionButton
var present_button: Button
var selection_label: Label
var experiment_picker: OptionButton
var preview_window: Window
var preview_output: RichTextLabel

func _ready() -> void:
	_configure_subwindows()
	theme = WorkshopSkin.make()
	theme.default_font_size = 17
	board = CanvasModel.new(session.scenario.public_view)
	case_root = board.selected
	var bg = ColorRect.new()
	bg.color = WorkshopSkin.color("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var heading = HBoxContainer.new()
	page.add_child(heading)
	_label(heading, "Make a Case", 30).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experiment_picker = _option(heading, Fixtures.NAMES)
	experiment_picker.name = "WorkshopExperiment"
	experiment_picker.item_selected.connect(_load_fixture)
	var tools = HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 10)
	page.add_child(tools)
	var premise_caption = _label(tools, "Add Case Premise", 18, "accent")
	premise_caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	premise_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	premise_caption.custom_minimum_size.x = 155
	premise_person = _person_option(tools, "constance")
	premise_person.custom_minimum_size.x = 140
	premise_person.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	premise_type = _option(tools, premise_names())
	premise_type.custom_minimum_size.x = 220
	premise_type.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_button(tools, "Add", _add_premise).name = "AddPremise"
	_button(tools, "Load mockup", func():
		board.mockup()
		case_root = board.selected
		_session_changed()
		canvas.fit_case()).name = "LoadMockup"
	_button(tools, "Fit case", func(): canvas.fit_case())
	_button(tools, "All evidence", func(): canvas.fit_case(true))
	_button(tools, "Save…", _save_dialog)
	_button(tools, "Open…", _open_dialog)
	_button(tools, "Mock jury", _show_jury)
	_label(page, "Drag cards to arrange · drag empty space to pan · wheel to zoom · Link, then click a destination · right-click to unlink · Esc cancels linking", 15, "muted")
	canvas = CanvasView.new()
	canvas.name = "FreeformCanvas"
	canvas.model = board
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(canvas)
	canvas.selected.connect(_select_card)
	canvas.answer_requested.connect(_open_answer)
	canvas.link_requested.connect(_begin_link)
	canvas.context_requested.connect(_context)
	var actions = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 12)
	page.add_child(actions)
	selection_label = _label(actions, "", 17)
	selection_label.custom_minimum_size.x = 330
	present_button = _button(actions, "Present selected premise", _present)
	present_button.name = "PresentPremise"
	_button(actions, "Preview effectiveness", _preview_effectiveness).name = "PreviewEffectiveness"
	_button(actions, "Answer selected", func(): _open_answer(board.selected))
	_button(actions, "Cancel link", func():
		canvas.linking = ""
		canvas.queue_redraw()
		status.text = "Link cancelled.")
	status = _label(page, "", 15, "muted")
	_build_windows()
	context_menu = PopupMenu.new()
	_add_subwindow(context_menu)
	context_menu.id_pressed.connect(_context_action)
	export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.add_filter("*.json", "Workshop canvas")
	export_dialog.file_selected.connect(_save)
	_add_subwindow(export_dialog)
	import_dialog = FileDialog.new()
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.add_filter("*.json", "Workshop canvas")
	import_dialog.file_selected.connect(_open)
	_add_subwindow(import_dialog)
	_session_changed()
	if "--workshop-smoke" in OS.get_cmdline_user_args():
		call_deferred("_smoke")

func _configure_subwindows() -> void:
	# Own the dialog layer inside the Workshop window. Otherwise nested windows
	# can share the game's outer stack and be covered when Workshop regains focus.
	get_window().gui_embed_subwindows = true

func _add_subwindow(window: Window) -> void:
	window.visible = false
	window.transient = true
	window.transient_to_focused = false
	add_child(window)

func _build_windows() -> void:
	preview_window = Window.new()
	preview_window.title = "Effectiveness preview · neutral ghost"
	preview_window.size = Vector2i(720, 720)
	preview_window.visible = false
	preview_window.close_requested.connect(func(): preview_window.hide())
	_add_subwindow(preview_window)
	var preview_body = _window_body(preview_window)
	preview_output = RichTextLabel.new()
	preview_output.custom_minimum_size = Vector2(610, 610)
	preview_output.selection_enabled = true
	preview_body.add_child(preview_output)
	answer_window = Window.new()
	answer_window.title = "Answer this card"
	answer_window.size = Vector2i(650, 700)
	answer_window.min_size = Vector2i(440, 350)
	answer_window.visible = false
	answer_window.exclusive = true
	answer_window.close_requested.connect(func():
		answer_window.hide()
		answer_id = ""
		_sync())
	_add_subwindow(answer_window)
	case_box = _window_body(answer_window)
	jury_window = Window.new()
	jury_window.title = "Mock jury · test your selected case"
	jury_window.size = Vector2i(660, 820)
	jury_window.min_size = Vector2i(440, 400)
	jury_window.visible = false
	jury_window.close_requested.connect(func(): jury_window.hide())
	_add_subwindow(jury_window)
	var jury_body = _window_body(jury_window)
	_label(jury_body, "Mock jury", 26, "accent")
	_label(jury_body, "Present any premise on the canvas. Its connected evidence is evaluated; disconnected cards stay scratch work.", 16, "muted")
	remember = CheckBox.new()
	remember.text = "Continue remembered discussion"
	jury_body.add_child(remember)
	venue = _option(jury_body, ["Private", "Meeting floor", "Speak for / against"])
	_button(jury_body, "Reset discussion", func():
		session.reset_discussion()
		reasoning_comparisons.clear()
		_refresh_jury()
		status.text = "Discussion reset. Cards and jury settings retained.")
	jury_box = VBoxContainer.new()
	jury_body.add_child(jury_box)
	_refresh_jury()

func _load_fixture(index: int) -> void:
	answer_window.hide()
	answer_id = ""
	session.generate(692, Fixtures.KINDS[index])
	board = CanvasModel.new(session.scenario.public_view)
	canvas.model = board
	canvas.linking = ""
	case_root = board.selected
	if index == 0:
		board.mockup()
		case_root = board.selected
	elif index == 1:
		for id in ["survey", "rumor", "dowse", "vigil3", "soot2", "evening2", "soot3", "evening3"]:
			board.connect_cards("e:" + id, case_root)
	elif index == 2:
		board.nodes[case_root].conclusion.target = session.scenario.slots.scion
		for id in ["survey", "rumor", "dowse", "dowse_recovered", "vial1"]:
			board.connect_cards("e:" + id, case_root)
	else:
		board.nodes[case_root].conclusion.target = session.scenario.slots.rumormonger
		board.nodes[case_root].conclusion.at = "during curse"
		for id in ["survey", "rumor", "dowse", "curse_warning", "totem_found"]:
			board.connect_cards("e:" + id, case_root)
	board.selected = case_root
	remember.button_pressed = false
	_session_changed()
	_refresh_jury()
	canvas.fit_case()

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

func premise_types() -> Array:
	return TYPES

func premise_names() -> Array:
	return TYPE_NAMES

func _add_premise() -> void:
	if board.nodes.values().filter(func(n): return n.kind == "premise").size() >= 12:
		status.text = "This experiment supports twelve premise cards."
		return
	var at: Vector2 = (canvas.size / 2.0 - canvas.pan) / canvas.zoom
	board.selected = board.add_premise(session.scenario.public_view.people[premise_person.selected].id, (premise_types() + ["support"])[premise_type.selected], at)
	if not board.nodes[board.selected].conclusion.is_empty():
		case_root = board.selected
	_session_changed()

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

func _sync() -> void:
	session.case_data = board.compile(case_root)
	analysis = Solver.analyze(session.scenario.public_view, session.case_data)
	selection_label.text = "Selected: " + board.title(board.selected)
	var chosen: Dictionary = board.nodes[board.selected]
	present_button.disabled = chosen.kind != "premise" or chosen.get("conclusion", {}).is_empty()

func _session_changed() -> void:
	stale = true
	reasoning_comparisons.clear()
	_sync()
	canvas.queue_redraw()
	var finding: String = analysis.errors[0] if not analysis.errors.is_empty() else ("These proposed accounts or choices conflict." if analysis.status == "conflicting" else analysis.entailment)
	if not session.case_data.get("faults", {}).is_empty() and analysis.proposed > 0:
		finding = "Fits conditionally on the selected impairment hypothesis"
	status.text = "%s · %d connected reports · %s. Disconnected cards are scratch work." % [board.title(case_root), session.case_data.cards.size(), finding]

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

func _identity_hint() -> String:
	return "Why did they register? Use Answer on a premise to assume Good · Marked or Evil. These choices remain hypotheses."

func _refresh_case() -> void:
	if answer_id == "" or not board.nodes.has(answer_id):
		return
	_clear(case_box)
	var node: Dictionary = board.nodes[answer_id]
	_label(case_box, board.title(answer_id), 24, "accent")
	if node.kind == "evidence":
		# Answers on disconnected copies are editable without enrolling those copies
		# into the selected case. Only the presentation graph chooses its evidence.
		_question(_report(node.card))
		var report: Dictionary = _report(node.card)
		if report.kind == "report" and session.scenario.public_view.get("chronology", {}).has("poison_windows"):
			var windows: Dictionary = session.scenario.public_view.chronology.poison_windows
			for key in windows:
				var window: Dictionary = windows[key]
				if report.source != window.subject or TimeModel.tick(report.observed_at) < window.from or TimeModel.tick(report.observed_at) >= window.until:
					continue
				_label(case_box, "Could this reading have been poisoned? The interval ends when the next night starts; a later recovered reading is separate.", 16)
				var fault = _option(case_box, ["No poisoning hypothesis", "Possible poisoning — unsupported hypothesis", "Possible poisoning — cite the vial observation"])
				fault.name = "PoisonExplanation"
				var existing: Dictionary = node.get("faults", {}).get(key, {})
				fault.select(0 if existing.is_empty() else (1 if existing.get("basis", "") == "" else 2))
				fault.item_selected.connect(func(i):
					if not node.has("faults"):
						node.faults = {}
					if i == 0:
						node.faults.erase(key)
					else:
						node.faults[key] = {"type": "poisoned", "window": key, "basis": "vial1" if i == 2 else ""}
					_edit())
				_label(case_box, "A bare hypothesis adds no evidence. Cited support opens one shared healthy/poisoned uncertainty for reports in this interval; it does not prove poison.", 15, "muted")
	elif node.kind == "modifier":
		_label(case_box, "Link supporting grounds to this modifier. It proposes an explanation; it does not establish error or dishonesty.", 17)
		var choice = _option(case_box, ["Misled reading", "Suspected lie", "Unlikely reading"])
		choice.select(["misled", "lying", "unlikely"].find(node.mode))
		choice.set_item_disabled(2, _report(node.card).get("role") != "surveyor")
		choice.item_selected.connect(func(i): node.mode = ["misled", "lying", "unlikely"][i]; _edit())
	elif node.kind == "contradiction":
		for child in node.children:
			_label(case_box, _report(board.nodes[child].card).text, 18)
		_label(case_box, "The linked observation challenges the alibi. Both reports remain as evidence, but you are not asserting that both contents are accurate.", 17)
		_label(case_box, "If the observation is believed, the alibi is false. Whether that was a deliberate lie, and whether it indicates evil, remain further inferences.", 16, "muted")
		_label(case_box, "This fixture uses the shared movement/trace likelihood. The old separate 2× alibi bonus is disabled." if board.view.has("movement_experiment") else "Workshop tuning: a fixed 2× evil/good comparison factor, gated by the linked observation's credibility. This is circumstantial and uncalibrated.", 15, "muted")
		_button(case_box, "Unlink and restore the originals", func():
			board.unmerge(answer_id)
			answer_window.hide()
			answer_id = ""
			_session_changed())
	else:
		var epochs: Array = TimeModel.epochs(session.scenario.public_view)
		if epochs.size() > 1 and not node.conclusion.is_empty():
			_label(case_box, "When is this claim about?", 17)
			var when = _option(case_box, epochs)
			when.name = "ClaimEpoch"
			when.select(epochs.find(node.conclusion.at))
			when.item_selected.connect(func(i):
				node.conclusion.at = epochs[i]
				_edit())
		_label(case_box, "Assumptions apply to this premise's argument. Supporting premises keep their own local assumptions. Chosen identities are hypotheses, not testimony.", 16, "muted")
		for person in session.scenario.public_view.people:
			var row = HBoxContainer.new()
			case_box.add_child(row)
			_label(row, person.name, 17).custom_minimum_size.x = 180
			var option = _option(row, ["? Unresolved", "Good", "Evil", "Marked (registration)" if board.view.get("chronology", {}).has("curse") else "Good · Marked"])
			option.name = "Assumption_" + person.id
			option.select(["", "good", "evil", "marked"].find(node.positions.get(person.id, "")))
			option.item_selected.connect(func(i):
				if i == 0:
					node.positions.erase(person.id)
				else:
					node.positions[person.id] = ["", "good", "evil", "marked"][i]
				_edit())
		if not node.conclusion.is_empty():
			var isolated = board.compile(answer_id)
			var result = Solver.analyze(board.view, isolated)
			_label(case_box, "Healthy-report check: %s (%d assignments). Proposed explanation: %s (%d assignments). Counts are not probabilities." % [result.entailment, result.compatible, result.status, result.proposed], 16)
			for error in result.errors:
				_label(case_box, error, 16, "accent")
	_button(case_box, "Done", func():
		answer_window.hide()
		answer_id = ""
		_sync())

func _edit() -> void:
	board.version += 1
	stale = true
	reasoning_comparisons.clear()
	canvas.queue_redraw()
	_refresh_case()
	status.text = "Answer updated. The card keeps its answer when you close this window. Present again to reassess."

func _show_jury() -> void:
	jury_window.popup_centered_clamped()

func _preview_effectiveness() -> void:
	if board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].conclusion.is_empty():
		status.text = "Select a premise with a claim to preview."
		return
	var compiled = board.compile(board.selected)
	var validation = session.validate_case(compiled)
	if validation != "":
		status.text = validation
		return
	preview_output.text = "Calculating neutral reference response…"
	preview_window.popup_centered_clamped()
	var preview_view = board.view.duplicate(true)
	await get_tree().process_frame
	var result = Ghost.evaluate(preview_view, compiled)
	preview_output.text = ComparisonText.describe(result)

func _present() -> void:
	if board.nodes[board.selected].kind != "premise" or board.nodes[board.selected].conclusion.is_empty():
		status.text = "Select a premise with a claim to present."
		return
	case_root = board.selected
	_sync()
	var error = session.validate_case(session.case_data)
	if error != "":
		status.text = error
		return
	reasoning_comparisons.clear()
	session.present(remember.button_pressed, ["private", "meeting", "nomination"][venue.selected])
	stale = false
	_refresh_jury()
	status.text = "Presented %s · %d reports · %d recorded presentations." % [board.title(case_root), session.case_data.cards.size(), session.history.size()]
	_show_jury()

func _context(id: String) -> void:
	context_id = id
	context_menu.clear()
	context_menu.add_item("Answer / inspect", 0)
	context_menu.add_item("Link to another card", 1)
	if board.nodes[id].kind == "evidence":
		var report = _report(board.nodes[id].card)
		for entry in [[200, "misled (honest but wrong)", "misled"], [201, "lying", "lying"], [202, "unlikely reading", "unlikely"]]:
			context_menu.add_item("Challenge: " + entry[1], entry[0])
			context_menu.set_item_disabled(context_menu.get_item_index(entry[0]), report.kind != "report" or report.has("relay_source") or report.get("support_note", "").begins_with("FALLBACK") or (entry[2] == "unlikely" and report.get("role") != "surveyor"))
	if board.nodes[id].kind == "modifier":
		context_menu.add_item("Remove modifier (keep evidence and links)", 203)
	if board.nodes[id].kind == "contradiction":
		context_menu.add_item("Unlink merged contradiction", 2)
	if board.nodes[id].kind == "premise":
		context_menu.add_item("Remove premise (keep its evidence)", 3)
	var edges: Array = board.links.filter(func(e): return e.from == id or e.to == id)
	for i in range(edges.size()):
		var other: String = edges[i].to if edges[i].from == id else edges[i].from
		context_menu.add_item("Unlink: " + board.title(other), 10 + i)
		if board._gift_link(board.nodes[edges[i].from], board.nodes[edges[i].to]):
			context_menu.add_item(("Use as context: " if edges[i].kind == "explains_outing" else "Use as gift explanation: ") + board.title(other), 1000 + i)
	_extend_context(id)
	context_menu.position = Vector2i(get_viewport().get_mouse_position())
	context_menu.popup()

## Subclasses add their own entries before the menu opens.
func _extend_context(_id: String) -> void:
	pass

func _context_action(action: int) -> void:
	if action in [200, 201, 202]:
		var error = board.add_modifier(context_id, ["misled", "lying", "unlikely"][action - 200])
		_session_changed()
		if error != "":
			status.text = error
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

func _save(path: String) -> void:
	_sync()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Could not save this canvas."
		return
	file.store_string(JSON.stringify({"format": "demonologist-workshop-canvas-1", "experiment": session.export_data(), "canvas": board.export_data(), "root": case_root,
		"viewport": {"zoom": canvas.zoom, "pan": [canvas.pan.x, canvas.pan.y]}, "remember": remember.button_pressed, "venue": venue.selected}, "\t"))
	status.text = "Saved canvas, answers, jury settings and presentation history."

func _open(path: String) -> void:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("format") != "demonologist-workshop-canvas-1":
		status.text = "Choose a saved Workshop canvas. Earlier list experiments can be opened in case_workshop_lab.tscn."
		return
	var candidate = Session.new(692)
	if not value.get("experiment") is Dictionary or int(value.experiment.get("seed", 0)) != 692:
		status.text = "This canvas experiment uses fixture 692."
		return
	var error = candidate.restore(value.experiment)
	if error != "":
		status.text = error
		return
	var next_board = CanvasModel.new(candidate.scenario.public_view)
	error = next_board.restore(value.get("canvas"), candidate)
	if error != "" or not next_board.nodes.has(value.get("root")) or next_board.nodes[value.root].kind != "premise" or next_board.nodes[value.root].conclusion.is_empty():
		status.text = error if error != "" else "Invalid active premise."
		return
	var next_case = next_board.compile(value.root)
	if candidate.validate_case(next_case) != "" or next_case != candidate.case_data:
		status.text = "The canvas and saved case disagree."
		return
	var viewport_value = value.get("viewport", {})
	var saved_venue = value.get("venue")
	if not (saved_venue is float or saved_venue is int) or not is_finite(float(saved_venue)) or float(int(saved_venue)) != float(saved_venue) or saved_venue < 0 or saved_venue > 2:
		status.text = "Invalid presentation venue."
		return
	if not viewport_value is Dictionary or not viewport_value.get("pan") is Array or viewport_value.pan.size() != 2 or not viewport_value.pan.all(func(x): return (x is int or x is float) and is_finite(float(x))) or not (viewport_value.get("zoom") is int or viewport_value.get("zoom") is float) or not is_finite(float(viewport_value.zoom)) or viewport_value.zoom < 0.35 or viewport_value.zoom > 1.5 or not value.get("remember") is bool:
		status.text = "Invalid canvas view or presentation settings."
		return
	session = candidate
	experiment_picker.select(Fixtures.KINDS.find(session.scenario.fixture))
	board = next_board
	case_root = value.root
	canvas.model = board
	canvas.zoom = viewport_value.zoom
	canvas.pan = Vector2(viewport_value.pan[0], viewport_value.pan[1])
	canvas.linking = ""
	remember.button_pressed = value.remember
	venue.select(int(value.venue))
	reasoning_comparisons.clear()
	_sync()
	canvas.queue_redraw()
	_refresh_jury()
	status.text = "Opened canvas and replayed its discussion."

func _smoke() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var args = OS.get_cmdline_user_args()
	var fixture_index = args.find("--workshop-fixture")
	if fixture_index >= 0 and fixture_index + 1 < args.size() and args[fixture_index + 1] in Fixtures.KINDS:
		var selected_fixture: int = Fixtures.KINDS.find(args[fixture_index + 1])
		experiment_picker.select(selected_fixture)
		_load_fixture(selected_fixture)
	else:
		board.mockup()
		case_root = board.selected
	_session_changed()
	canvas.fit_case()
	_present()
	jury_window.hide()
	if "--workshop-answer-shot" in args:
		_open_answer(case_root if session.scenario.fixture == "revenant" else ("e:dowse" if session.scenario.fixture == "poison" else "e:survey"))
	elif "--workshop-jury-shot" in args:
		_show_jury()
	for frame in range(6):
		await get_tree().process_frame
	var screenshot_index = args.find("--screenshot")
	if screenshot_index >= 0 and screenshot_index + 1 < args.size() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[screenshot_index + 1])
	print("Workshop canvas smoke: %d cards; %d links; %d connected evidence cards; %d presentations." % [board.nodes.size(), board.links.size(), session.case_data.cards.size(), session.history.size()])
	get_tree().quit()
