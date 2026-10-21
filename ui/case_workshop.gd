## Standalone F6 scene. No changes to the running game's evidence or NPC systems.
extends Control

const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const C = preload("res://sim/content.gd")
const WorkshopSkin = preload("res://ui/theme.gd")
const TYPES = ["evil", "suspicious", "good", "marked", "conflict"]
const TYPE_NAMES = ["is evil", "is suspicious", "is good", "is Marked", "these reports conflict"]

var session = Session.new()
var evidence_box: VBoxContainer
var case_box: VBoxContainer
var jury_box: VBoxContainer
var status: Label
var seed_input: SpinBox
var remember: CheckBox
var venue: OptionButton
var export_dialog: FileDialog
var import_dialog: FileDialog
var focus_card = "survey"
var developer_truth = false
var details_open = false
var positions_open = false
var analysis: Dictionary = {}
var stale = true

func _ready() -> void:
	theme = WorkshopSkin.make()
	# A restrained, readable variation of the main game's dark paper palette.
	theme.default_font_size = 17
	var bg = ColorRect.new()
	bg.color = WorkshopSkin.color("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var heading = HBoxContainer.new()
	page.add_child(heading)
	var title = _label(heading, "Case Workshop", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(heading, "DAY 3  /  FROZEN SCENARIO", 16, "accent")
	_label(page, "Build an explanation. Hear the objection. Revise the case.", 18, "muted")
	var toolbar = HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 12)
	page.add_child(toolbar)
	var seed_label = _label(toolbar, "Seed", 16)
	seed_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	seed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	seed_label.custom_minimum_size.x = 40
	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 2147483647
	seed_input.value = 692
	seed_input.custom_minimum_size.x = 130
	toolbar.add_child(seed_input)
	_button(toolbar, "Generate", func():
		session.generate(int(seed_input.value))
		focus_card = "survey"
		_changed(true))
	var examples = _option(toolbar, ["Load example…", "Surveyor only", "Add Rumormonger", "Three core readings", "Repeated night outings", "Conflicting reports"])
	examples.item_selected.connect(func(i):
		if i > 0:
			_load_example(i)
			examples.select(0))
	_button(toolbar, "Clear case", func():
		var version: int = session.case_data.version + 1
		session.case_data = Solver.empty_case()
		session.case_data.conclusion.target = _report("survey").source
		session.case_data.version = version
		_changed(true))
	_button(toolbar, "Save experiment…", _save_dialog)
	_button(toolbar, "Open experiment…", _open_dialog)
	var truth_check = CheckBox.new()
	truth_check.text = "Developer truth"
	truth_check.toggled.connect(func(on):
		developer_truth = on
		_refresh_case())
	toolbar.add_child(truth_check)
	var columns_scroll = ScrollContainer.new()
	columns_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(columns_scroll)
	var columns = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	columns_scroll.add_child(columns)
	evidence_box = _column(columns, "01  Evidence", 300, 0.85)
	case_box = _column(columns, "02  Your case", 410, 1.2)
	jury_box = _column(columns, "03  Mock jury", 390, 1.1)
	var actions = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 14)
	page.add_child(actions)
	_button(actions, "Present case", _present)
	remember = CheckBox.new()
	remember.text = "Continue remembered discussion"
	remember.tooltip_text = "Off: every presentation starts from identical jury settings. On: replace the previous case's effect and show the actual change."
	actions.add_child(remember)
	venue = _option(actions, ["Private", "Meeting floor", "Speak for / against"])
	venue.tooltip_text = "All venues use the same interpreter and evidence identity. No extra voting pressure is simulated."
	_button(actions, "Reset discussion", func():
		session.reset_discussion()
		_refresh_jury()
		status.text = "Discussion reset. Your case and jury settings are retained.")
	status = _label(page, "", 16, "muted")
	export_dialog = FileDialog.new()
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.add_filter("*.json", "Workshop experiment")
	export_dialog.file_selected.connect(_save)
	add_child(export_dialog)
	import_dialog = FileDialog.new()
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.add_filter("*.json", "Workshop experiment")
	import_dialog.file_selected.connect(_open)
	add_child(import_dialog)
	_changed(true)
	if "--workshop-smoke" in OS.get_cmdline_user_args():
		call_deferred("_smoke")

func _column(parent: Node, title: String, minimum: int, ratio: float) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.custom_minimum_size.x = minimum
	panel.add_theme_stylebox_override("panel", WorkshopSkin.flat(WorkshopSkin.color("panel"), WorkshopSkin.color("border"), 1, 8, 16))
	parent.add_child(panel)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	_label(body, title, 22, "accent")
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return content

func _label(parent: Node, text_value: String, size_value: int = 17, color: String = "text") -> Label:
	var label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", WorkshopSkin.color(color))
	parent.add_child(label)
	return label

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _option(parent: Node, labels: Array) -> OptionButton:
	var option = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	for label in labels:
		option.add_item(str(label))
	parent.add_child(option)
	return option

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _box(parent: Node) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", WorkshopSkin.flat(WorkshopSkin.color("panel_alt"), Color.TRANSPARENT, 0, 6, 12))
	parent.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box

func _changed(rebuild_jury: bool = false) -> void:
	stale = true
	analysis = Solver.analyze(session.scenario.public_view, session.case_data)
	_refresh_evidence()
	_refresh_case()
	if rebuild_jury:
		_refresh_jury()
	status.text = "Case v%d · %d selected cards · jury responses update when you present." % [session.case_data.version, session.case_data.cards.size()]

func _edit() -> void:
	session.revise()
	_changed()

func _refresh_evidence() -> void:
	_clear(evidence_box)
	_label(evidence_box, "Select reports to accept for this argument. Click a title to answer its question.", 16, "muted")
	for card in session.scenario.public_view.cards:
		var box = _box(evidence_box)
		var row = HBoxContainer.new()
		box.add_child(row)
		var check = CheckBox.new()
		check.button_pressed = card.id in session.case_data.cards
		check.tooltip_text = "Include / remove this premise"
		check.toggled.connect(func(on):
			if on:
				session.case_data.cards.append(card.id)
				focus_card = card.id
			else:
				session.case_data.cards.erase(card.id)
			_edit())
		row.add_child(check)
		var title: String = C.role_name(card.role) if card.kind == "report" else {"alibi": "Home alibi", "claim": "Gift explanation", "sighting": "Your vigil"}.get(card.kind, card.kind)
		var inspect = _button(row, title + ("  ◂" if focus_card == card.id else ""), func():
			focus_card = card.id
			_refresh_case()
			_refresh_evidence())
		inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(box, card.text, 16)
		var time_text: String = C.night_name(int(card.observed_at.day)) if card.observed_at.phase == "night" else "day %d" % card.observed_at.day
		_label(box, "%s · learned day %d" % [time_text.capitalize(), card.acquired_day], 14, "muted")
	var town = _box(evidence_box)
	_label(town, "Town & timeline", 19, "accent")
	for p in session.scenario.public_view.people:
		_label(town, "%s · %s%s" % [p.name, C.block_name(p.home), " · dead" if not p.alive else ""], 15)
	for event in session.scenario.public_view.history:
		_label(town, event, 15, "muted")

func _refresh_case() -> void:
	_clear(case_box)
	var conclusion_box = _box(case_box)
	_label(conclusion_box, "What are you arguing?", 20)
	var person = _person_option(conclusion_box, session.case_data.conclusion.target)
	person.item_selected.connect(func(i):
		session.case_data.conclusion.target = session.scenario.public_view.people[i].id
		_edit())
	var kind = _option(conclusion_box, TYPE_NAMES)
	kind.select(TYPES.find(session.case_data.conclusion.type))
	kind.item_selected.connect(func(i):
		session.case_data.conclusion.type = TYPES[i]
		_edit())
	_label(conclusion_box, "Alignment / secret at: opening through day 3. Individual reports retain their own dates.", 14, "muted")
	var card = _report(focus_card)
	if not card.is_empty():
		_question(card)
	_button(case_box, ("▾" if positions_open else "▸") + " Assumed alignments & Marked", func():
		positions_open = not positions_open
		_refresh_case())
	if positions_open:
		var positions = _box(case_box)
		_label(positions, "Your choices describe a proposed world. They do not become evidence by being selected.", 15, "muted")
		for p in session.scenario.public_view.people:
			var row = HBoxContainer.new()
			positions.add_child(row)
			_label(row, p.name, 16)
			var options = ["?", "good", "evil", "marked"]
			var choice = _option(row, ["? Unresolved", "Good", "Evil", "Good · Marked"])
			choice.select(options.find(session.case_data.positions.get(p.id, "?")))
			choice.item_selected.connect(func(i):
				if i == 0:
					session.case_data.positions.erase(p.id)
				else:
					session.case_data.positions[p.id] = options[i]
				_edit())
	var summary = _box(case_box)
	_label(summary, "Case check · v%d" % session.case_data.version, 20, "accent")
	var status_text = "These choices conflict." if analysis.status == "conflicting" else "A coherent explanation; unanswered choices are allowed."
	_label(summary, status_text, 18)
	var meanings = {"forced": "The selected reports force this conclusion, if their premises are accepted.", "possible": "The conclusion is possible. Another explanation still fits.", "unsupported": "The selected reports do not support this conclusion.", "conflicting": "The selected premises cannot all be accepted together."}
	_label(summary, meanings[analysis.entailment], 16)
	_label(summary, "%d compatible alignment/Marked assignments before your choices; %d after. Counts are not probabilities." % [analysis.compatible, analysis.proposed], 15, "muted")
	for error in analysis.errors:
		_label(summary, error, 16, "accent")
	_button(case_box, ("▾" if details_open else "▸") + " Premises, alternatives & consequences", func():
		details_open = not details_open
		_refresh_case())
	if details_open:
		var detail = _box(case_box)
		for premise in analysis.assumptions:
			_label(detail, premise, 15)
		if not analysis.alternative.is_empty():
			_label(detail, "One alternative: %s evil; %s Marked." % [_names(analysis.alternative.evil), _name(analysis.alternative.marked)], 16, "accent")
		_label(detail, "Unresolved alignment: " + _names(analysis.unresolved), 15)
		for night in analysis.movement:
			var movement: Dictionary = analysis.movement[night]
			_label(detail, "Night %s: %d outing assignments. Must be out: %s." % [night, movement.compatible, _names(movement.forced_out)], 15)
		_label(detail, session.scenario.public_view.scope, 14, "muted")
	if developer_truth:
		var truth = _box(case_box)
		_label(truth, "Developer truth · not used by the jury", 18, "accent")
		for p in session.scenario.truth:
			_label(truth, "%s: %s, %s%s" % [_name(p.id), p.role, p.alignment, " · " + p.secret if p.secret != "" else ""], 15)

func _question(card: Dictionary) -> void:
	var box = _box(case_box)
	_label(box, "Answer this card", 20, "accent")
	_label(box, card.text, 17)
	if card.id not in session.case_data.cards:
		_button(box, "Use this card", func():
			session.case_data.cards.append(card.id)
			_edit())
		_label(box, "Answers on a card outside the case have no effect.", 14, "muted")
	var role: String = card.get("role", "")
	if card.kind == "report" and role in ["surveyor", "dowser", "rumormonger", "lamplighter"]:
		var prompt: String = {"surveyor": "Which residents account for the positive blocks? A positive may be evil or Marked.", "dowser": "Who registered as evil in this reading? Marked is a possible explanation.", "rumormonger": "Which person is Marked in your explanation?", "lamplighter": "Who were the other people out? The Lamplighter is excluded."}[role]
		_label(box, prompt, 16)
		var count: int = 1 if role == "rumormonger" else card.data.count
		var answer: Dictionary = session.case_data.answers.get(card.id, {})
		var slots: Array = answer.get("slots", answer.get("positive", []))
		for i in range(count):
			var choices: Array = session.scenario.public_view.people.map(func(p): return p.id)
			if role == "rumormonger":
				choices = card.data.pair
			elif role == "surveyor" and count == 4:
				var block: String = C.BLOCKS.keys()[i]
				_label(box, C.block_name(block), 15, "muted")
				choices = session.scenario.public_view.people.filter(func(p): return p.home == block).map(func(p): return p.id)
			elif role == "dowser":
				choices = card.data.group
			elif role == "lamplighter":
				choices = choices.filter(func(id): return id != card.source)
			var slot = _option(box, ["? Unresolved slot %d" % (i + 1)] + choices.map(func(id): return _name(id)))
			slot.name = "Answer_%s_%d" % [card.id, i]
			if i < slots.size() and slots[i] in choices:
				slot.select(choices.find(slots[i]) + 1)
			slot.item_selected.connect(func(index):
				var values: Array = session.case_data.answers.get(card.id, {}).get("slots", []).duplicate()
				values.resize(count)
				values[i] = "" if index == 0 else choices[index - 1]
				session.case_data.answers[card.id] = {"slots": values, "positive": values.filter(func(v): return v is String and v != "")}
				_edit())
	elif role == "nightwatch" or card.kind == "sighting":
		_label(box, "Why were they out? An unanswered reason is allowed. A gift explanation needs supporting testimony.", 16)
		var seen: Array = card.data.seen if role == "nightwatch" else [card.subject]
		for id in seen:
			_label(box, _name(id), 16)
			var key = "%s:%d" % [id, card.night]
			var option = _option(box, ["? Unexplained", "Night gift (cite the claim)", "Possibly evil activity"])
			var reasons = ["unexplained", "gift", "evil"]
			option.select(reasons.find(session.case_data.reasons.get(key, "unexplained")))
			option.item_selected.connect(func(i):
				session.case_data.reasons[key] = reasons[i]
				_edit())
	else:
		_label(box, "This statement can support an explanation or conflict with another report. No additional answer is required.", 16, "muted")

func _refresh_jury() -> void:
	_clear(jury_box)
	_label(jury_box, "Four living good townsfolk. Each knows their own gift reports and their own alignment.", 16, "muted")
	if stale and not session.last_results.is_empty():
		_label(jury_box, "Responses below are from the last presentation.", 15, "accent")
	for i in range(session.baseline.size()):
		var juror: Dictionary = session.baseline[i]
		var box = _box(jury_box)
		_label(box, juror.name + " · " + juror.preset, 20, "accent")
		if session.last_results.size() > i:
			var r: Dictionary = session.last_results[i]
			_label(box, r.response, 18)
			_label(box, r.objection, 16, "muted")
			_label(box, "Suspicion %.3f → %.3f (%+.3f)\nTrust in you %.2f → %.2f" % [r.before_suspicion, r.after_suspicion, r.suspicion_delta, r.before_trust, r.after_trust], 16)
			var show_calc = CheckBox.new()
			show_calc.text = "Show calculation & accepted path"
			box.add_child(show_calc)
			var calculation = _label(box, "Agreement %.2f × premise quality %.3f × player %.2f × confidence %.2f\nPath: %s (%s)\nPrevious case effect %.3f; replacement %.3f. %s.\nPrivate compatible worlds: %d. These counts are not probabilities." % [r.agreement, r.quality, r.calculation.player_factor, r.calculation.confidence_factor, ", ".join(PackedStringArray(r.path)), r.path_kind, r.calculation.old_case_effect, r.calculation.new_case_effect, r.stance, r.assessment.compatible], 14, "muted")
			calculation.visible = false
			show_calc.toggled.connect(func(on): calculation.visible = on)
		else:
			_label(box, "Waiting to hear your case.", 17, "muted")
		var settings_check = CheckBox.new()
		settings_check.text = "Adjust this juror"
		box.add_child(settings_check)
		var settings = VBoxContainer.new()
		settings.visible = false
		box.add_child(settings)
		settings_check.toggled.connect(func(on): settings.visible = on)
		_slider(settings, "Trust in you", juror.trust, func(value): _set_juror(i, "trust", value))
		_slider(settings, "Confidence", juror.confidence, func(value): _set_juror(i, "confidence", value))
		_label(settings, "Their view of…", 15)
		var relation = _person_option(settings, session.case_data.conclusion.target)
		var relation_box = VBoxContainer.new()
		settings.add_child(relation_box)
		var rebuild = func(index):
			_clear(relation_box)
			var id: String = session.scenario.public_view.people[index].id
			_slider(relation_box, "Trust in person", juror.npc_trust[id], func(value): _set_relation(i, id, "npc_trust", value))
			_slider(relation_box, "Baseline suspicion", juror.suspicion[id], func(value): _set_relation(i, id, "suspicion", value))
		relation.item_selected.connect(rebuild)
		rebuild.call(relation.selected)
	_button(jury_box, "Restore generated jury settings", func():
		session.baseline = session.scenario.jury.duplicate(true)
		session.reset_discussion()
		_refresh_jury())

func _slider(parent: Node, title: String, value: float, action: Callable) -> void:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var caption = _label(row, "%s  %.2f" % [title, value], 15)
	caption.custom_minimum_size.x = 180
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	slider.value_changed.connect(func(v):
		caption.text = "%s  %.2f" % [title, v]
		action.call(v))

func _set_juror(index: int, field: String, value: float) -> void:
	session.baseline[index][field] = value
	session.listeners[index][field] = value
	status.text = "Jury setting changed. Present again to compare the result."

func _set_relation(index: int, id: String, field: String, value: float) -> void:
	var delta: float = value - session.baseline[index][field][id]
	session.baseline[index][field][id] = value
	if field == "suspicion":
		session.listeners[index][field][id] += delta
	else:
		session.listeners[index][field][id] = value
	status.text = "Jury premise changed. Present again to reconsider."

func _person_option(parent: Node, id: String) -> OptionButton:
	var people: Array = session.scenario.public_view.people
	var option = _option(parent, people.map(func(p): return p.name))
	var index: int = people.map(func(p): return p.id).find(id)
	option.select(maxi(0, index))
	return option

func _name(id: String) -> String:
	return Solver.person_name(session.scenario.public_view, id)

func _names(ids: Array) -> String:
	return ", ".join(PackedStringArray(ids.map(func(id): return _name(id)))) if not ids.is_empty() else "none"

func _report(id: String) -> Dictionary:
	return Solver.card_by_id(session.scenario.public_view, id)

func _present() -> void:
	session.present(remember.button_pressed, ["private", "meeting", "nomination"][venue.selected])
	stale = false
	_refresh_jury()
	status.text = "Presented v%d · %s · %d recorded presentations. Trust is held fixed; actual suspicion changes are shown." % [session.case_data.version, "remembered discussion" if remember.button_pressed else "identical starting attitudes", session.history.size()]

func _load_example(index: int) -> void:
	var target: String = session.scenario.slots.demon
	var version: int = session.case_data.version + 1
	session.case_data = Solver.empty_case()
	session.case_data.version = version
	session.case_data.conclusion.target = target
	session.case_data.cards = [["survey"], ["survey", "rumor"], ["survey", "rumor", "dowse"], ["watch1", "watch2"], ["watch1", "alibi1"]][index - 1].duplicate()
	if index == 4:
		session.case_data.conclusion.type = "suspicious"
		focus_card = "watch2"
	elif index == 5:
		session.case_data.conclusion.type = "conflict"
		focus_card = "alibi1"
	else:
		focus_card = ["survey", "rumor", "dowse"][index - 1]
	_changed()

func _save_dialog() -> void:
	export_dialog.current_file = "workshop-%d-v%d.json" % [session.scenario.public_view.seed, session.case_data.version]
	export_dialog.popup_centered_ratio(0.7)

func _save(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "Could not save experiment: " + error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(session.export_data(developer_truth), "\t"))
	status.text = "Saved experiment: " + path

func _open_dialog() -> void:
	import_dialog.popup_centered_ratio(0.7)

func _open(path: String) -> void:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("format", "") != "demonologist-case-workshop-1":
		status.text = "This is not a Case Workshop experiment."
		return
	var result = session.restore(value)
	if result != "":
		status.text = result
		return
	seed_input.value = value.seed
	focus_card = "survey"
	stale = session.last_results.is_empty() or (not session.history.is_empty() and session.history[-1].case != session.case_data)
	if not session.history.is_empty():
		remember.button_pressed = session.history[-1].remember
		venue.select(["private", "meeting", "nomination"].find(session.history[-1].venue))
	analysis = Solver.analyze(session.scenario.public_view, session.case_data)
	_refresh_evidence()
	_refresh_case()
	_refresh_jury()
	status.text = "Experiment restored with %d recorded presentations." % session.history.size()

func _smoke() -> void:
	# Exercise the actual scene and render a reproducible review screenshot.
	_load_example(3)
	_present()
	remember.button_pressed = true
	_present()
	if not session.last_results.all(func(r): return is_zero_approx(r.suspicion_delta)):
		push_error("UI smoke: repetition changed suspicion")
		get_tree().quit(1)
		return
	_load_example(4)
	_present()
	_load_example(5)
	_present()
	_load_example(3)
	remember.button_pressed = false
	_present()
	for frame in range(6):
		await get_tree().process_frame
	var args = OS.get_cmdline_user_args()
	var screenshot_index = args.find("--screenshot")
	if screenshot_index >= 0 and screenshot_index + 1 < args.size() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[screenshot_index + 1])
	print("Workshop UI smoke passed: 5 presentations, example switching, remembered repetition.")
	get_tree().quit()
