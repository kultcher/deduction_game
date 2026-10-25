## Standalone F6 scene. No changes to the running game's evidence or NPC systems.
extends Control

const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const C = preload("res://sim/content.gd")
const WorkshopSkin = preload("res://ui/theme.gd")
const TYPES = ["evil", "suspicious", "good", "marked", "conflict", "demon", "minion"]
const TYPE_NAMES = ["is evil", "is suspicious", "is good", "is Marked", "these reports conflict", "is the Demon", "is a Minion"]

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
var active_line = ""
var reasoning_comparisons: Dictionary = {}

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
	var examples = _option(toolbar, ["Load exampleâ€¦", "Surveyor only", "Add Rumormonger", "Three core readings", "Repeated night outings", "Conflicting reports", "Converging lines (test factor)", "Insight comparison"])
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
	_button(toolbar, "Save experimentâ€¦", _save_dialog)
	_button(toolbar, "Open experimentâ€¦", _open_dialog)
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
	status.text = "Case v%d Â· %d selected cards Â· jury responses update when you present." % [session.case_data.version, session.case_data.cards.size()]

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
				if not _active_choices().is_empty() and active_line != "":
					_active_choices().cards.append(card.id)
				focus_card = card.id
			else:
				session.case_data.cards.erase(card.id)
				for line in session.case_data.lines:
					line.cards.erase(card.id)
				session.case_data.conflict_scope.erase(card.id)
			_edit())
		row.add_child(check)
		var title: String = C.role_name(card.role) if card.kind == "report" else {"alibi": "Home alibi", "claim": "Gift explanation", "sighting": "Your vigil"}.get(card.kind, card.kind)
		var inspect = _button(row, title + ("  â—‚" if focus_card == card.id else ""), func():
			focus_card = card.id
			_refresh_case()
			_refresh_evidence())
		inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(box, card.text, 16)
		if card.kind == "report":
			_button(box, "Inspect associated role claim", func():
				focus_card = card.claim_id
				_refresh_case())
		var time_text: String = C.night_name(int(card.observed_at.day)) if card.observed_at.phase == "night" else "day %d" % card.observed_at.day
		_label(box, "%s Â· learned day %d" % [time_text.capitalize(), card.acquired_day], 14, "muted")
	var town = _box(evidence_box)
	_label(town, "Town & timeline", 19, "accent")
	for p in session.scenario.public_view.people:
		_label(town, "%s Â· %s%s" % [p.name, C.block_name(p.home), " Â· dead" if not p.alive else ""], 15)
	for event in session.scenario.public_view.history:
		_label(town, event, 15, "muted")

func _refresh_case() -> void:
	_clear(case_box)
	var conclusion_box = _box(case_box)
	_label(conclusion_box, "What are you arguing?", 20)
	var person = _person_option(conclusion_box, session.case_data.conclusion.target)
	person.name = "ConclusionTarget"
	person.visible = session.case_data.conclusion.type != "conflict"
	person.item_selected.connect(func(i):
		session.case_data.conclusion.target = session.scenario.public_view.people[i].id
		_edit())
	var kind = _option(conclusion_box, TYPE_NAMES)
	kind.select(TYPES.find(session.case_data.conclusion.type))
	kind.item_selected.connect(func(i):
		session.case_data.conclusion.type = TYPES[i]
		_edit())
	_label(conclusion_box, "Alignment / secret at: opening through day 3. Individual reports retain their own dates.", 14, "muted")
	_reasoning_lines()
	if session.case_data.conclusion.type == "conflict":
		_conflict_controls()
	var card = _report(focus_card)
	if not card.is_empty():
		_question(card)
	_button(case_box, ("â–¾" if positions_open else "â–¸") + " Assumed alignments & Marked", func():
		positions_open = not positions_open
		_refresh_case())
	if positions_open:
		var positions = _box(case_box)
		_label(positions, "Your choices describe a proposed world. They do not become evidence by being selected.", 15, "muted")
		var current = _active_choices()
		for p in session.scenario.public_view.people:
			var row = HBoxContainer.new()
			positions.add_child(row)
			_label(row, p.name, 16)
			var options = ["?", "good", "evil", "marked"]
			var choice = _option(row, ["? Unresolved", "Good", "Evil", "Good Â· Marked"])
			choice.select(options.find(current.positions.get(p.id, "?")))
			choice.item_selected.connect(func(i):
				if i == 0:
					current.positions.erase(p.id)
				else:
					current.positions[p.id] = options[i]
				_edit())
	var summary = _box(case_box)
	_label(summary, "Case check Â· v%d" % session.case_data.version, 20, "accent")
	var status_text = "These choices conflict." if analysis.status == "conflicting" else "A coherent explanation; unanswered choices are allowed."
	_label(summary, status_text, 18)
	var meanings = {"forced": "The selected reports force this conclusion, if their premises are accepted.", "possible": "The conclusion is possible. Another explanation still fits.", "unsupported": "The selected reports do not support this conclusion.", "conflicting": "The selected premises cannot all be accepted together."}
	_label(summary, meanings[analysis.entailment], 16)
	_label(summary, "%d compatible alignment/Marked assignments before your choices; %d after. Counts are not probabilities." % [analysis.compatible, analysis.proposed], 15, "muted")
	for error in analysis.errors:
		_label(summary, error, 16, "accent")
	for conflict in analysis.conflicts:
		_label(summary, "Cannot all be accurate: " + ", ".join(PackedStringArray(conflict)), 16, "accent")
		if session.case_data.derived.size() < 8:
			_button(summary, "Keep this conflict as a question", func():
				var number = 1
				while session.case_data.derived.any(func(q): return q.id == "question_%d" % number):
					number += 1
				var id = "question_%d" % number
				session.case_data.derived.append({"id": id, "supports": conflict.duplicate(), "text": "Which account is wrong?"})
				session.case_data.cards.append(id)
				_edit())
	_button(case_box, ("â–¾" if details_open else "â–¸") + " Premises, alternatives & consequences", func():
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
		_label(truth, "Developer truth Â· not used by the jury", 18, "accent")
		for p in session.scenario.truth:
			_label(truth, "%s: %s, %s%s" % [_name(p.id), p.role, p.alignment, " Â· " + p.secret if p.secret != "" else ""], 15)

func _question(card: Dictionary) -> void:
	var box = _box(case_box)
	_label(box, "Answer this card", 20, "accent")
	_label(box, card.text, 17)
	_label(box, "Observed %s %s Â· reported day %s Â· learned day %s" % [card.observed_at.phase, card.observed_at.day, card.reported_at.day, card.learned_at.day], 14, "muted")
	if card.kind == "event" and card.get("event") == "curse":
		_label(box, "Who became evil when the Revenant was executed? This answer is a dated hypothesis, not proof of their identity.", 16)
		var current = _active_choices()
		var candidates: Array = card.data.eligible
		var choice = _option(box, ["? Unknown converted voter"] + candidates.map(func(id): return _name(id)))
		choice.name = "ConvertedVoter"
		var selected: Array = current.answers.get(card.id, {}).get("positive", [])
		choice.select(0 if selected.is_empty() else candidates.find(selected[0]) + 1)
		choice.item_selected.connect(func(i):
			current.answers[card.id] = {"positive": [] if i == 0 else [candidates[i - 1]]}
			_edit())
	if card.kind == "claim":
		_label(box, "An implicit role assertion from %s; accepting the claim does not accept the reading." % card.get("origin", "testimony") if card.get("implicit", false) else "This is a role claim, not proof that the gift works.", 15, "muted")
	if not _card_available(card):
		_button(box, "Use in this line" if active_line != "" else "Use this card", func():
			if card.id not in session.case_data.cards:
				session.case_data.cards.append(card.id)
			if active_line != "":
				_active_choices().cards.append(card.id)
			_edit())
		_label(box, "Answers on a card outside this case or line have no effect.", 14, "muted")
	var role: String = card.get("role", "")
	if card.kind == "secret_claim":
		_label(box, "This claims a private errand that could explain an outing. It does not prove innocence, a particular secret modifier, or that the person was out.", 16, "muted")
	elif card.kind == "context" and card.get("context_kind", "") == "psychologist":
		_label(box, "This reports whom someone trusts and suspects. Those opinions do not establish anyone's alignment.", 16, "muted")
	elif card.kind == "report" and role in ["surveyor", "dowser", "rumormonger", "lamplighter", "clerk", "archivist", "seer"]:
		var prompt: String = {"surveyor": "Which blocks or residents account for the positives? A positive may be evil or Marked.", "dowser": "Who registered as evil in this reading? Marked is a possible explanation.", "rumormonger": "Which person is Marked in your explanation?", "lamplighter": "Who were the other people out? The Lamplighter is excluded.", "clerk": "If this reading is accurate, who holds the named good gift?", "archivist": "If this reading is accurate, who holds the named minion gift?", "seer": "What explains this Demon reading? A negative reading does not clear minions."}[role]
		if role == "rumormonger":
			prompt = "Which person has the named secret (%s) in your explanation?" % card.data.get("secret", "marked")
		_label(box, prompt, 16)
		var count: int = (1 if card.data.yes else 0) if role == "seer" else (1 if role in ["rumormonger", "clerk", "archivist"] else card.data.count)
		var current = _active_choices()
		var answer: Dictionary = current.answers.get(card.id, {})
		var fallback_slots: Array = answer.get("positive", []).duplicate()
		for block in answer.get("blocks", []):
			fallback_slots.append("block:" + str(block))
		if role == "surveyor" and count == 4:
			var by_block = {}
			for choice in fallback_slots:
				if str(choice).begins_with("block:"):
					by_block[str(choice).trim_prefix("block:")] = choice
				else:
					for person in session.scenario.public_view.people:
						if person.id == choice:
							by_block[person.home] = choice
			fallback_slots = C.BLOCKS.keys().map(func(block): return by_block.get(block, ""))
		var slots: Array = answer.get("slots", fallback_slots)
		for i in range(count):
			var choices: Array = session.scenario.public_view.people.map(func(p): return p.id)
			if role in ["rumormonger", "clerk", "archivist", "seer"]:
				choices = card.data.pair
			elif role == "surveyor":
				if count == 4:
					var block: String = C.BLOCKS.keys()[i]
					_label(box, C.block_name(block), 15, "muted")
					choices = ["block:" + block] + session.scenario.public_view.people.filter(func(p): return p.home == block).map(func(p): return p.id)
				else:
					choices = C.BLOCKS.keys().map(func(block): return "block:" + block) + choices
			elif role == "dowser":
				choices = card.data.group
			elif role == "lamplighter":
				choices = choices.filter(func(id): return id != card.source)
			var slot = _option(box, ["? Unresolved slot %d" % (i + 1)] + choices.map(func(id): return "Someone on " + C.block_name(str(id).trim_prefix("block:")) if str(id).begins_with("block:") else _name(id)))
			slot.name = "Answer_%s_%d" % [card.id, i]
			if i < slots.size() and slots[i] in choices:
				slot.select(choices.find(slots[i]) + 1)
			slot.item_selected.connect(func(index):
				var values: Array = current.answers.get(card.id, {}).get("slots", []).duplicate()
				values.resize(count)
				values[i] = "" if index == 0 else choices[index - 1]
				var chosen: Array = values.filter(func(v): return v is String and v != "")
				if chosen.size() != _unique(chosen).size():
					status.text = "That answer already fills a slot. Leave this slot unknown or choose another."
					_refresh_case()
					return
				var updated: Dictionary = current.answers.get(card.id, {}).duplicate(true)
				var positive: Array = chosen.filter(func(v): return not v.begins_with("block:"))
				updated.merge({"slots": values, "positive": positive}, true)
				if role == "surveyor":
					updated["blocks"] = chosen.filter(func(v): return v.begins_with("block:")).map(func(v): return v.trim_prefix("block:"))
				current.answers[card.id] = updated
				_edit())
		if role in ["surveyor", "dowser"]:
			_label(box, _identity_hint(), 15, "muted")
		if role == "seer" and card.data.yes:
			var reasons: Array = ["", "demon", "red_herring", "marked"]
			var reason = _option(box, ["? Any valid explanation", "Demon", "Red Herring", "Marked"])
			reason.select(reasons.find(answer.get("registration", "")))
			reason.item_selected.connect(func(i):
				var updated: Dictionary = current.answers.get(card.id, {}).duplicate(true)
				updated["registration"] = reasons[i]
				current.answers[card.id] = updated
				_edit())
	elif (card.kind == "report" and role == "nightwatch") or card.kind == "sighting":
		_label(box, "Why were they out? An unanswered reason is allowed. A gift explanation needs supporting testimony.", 16)
		var current = _active_choices()
		var seen: Array = card.data.seen if role == "nightwatch" else card.get("subjects", [card.subject])
		for id in seen:
			_label(box, _name(id), 16)
			var key = "%s:%d" % [id, card.night]
			var labels: Array = ["? Unexplained", "Night gift â€” choose supporting claim", "Possibly evil activity"]
			var reasons = ["unexplained", "gift", "evil"]
			if session.scenario.public_view.has("movement_experiment") or session.scenario.public_view.get("live_activity", false):
				labels.append("Private errand â€” choose supporting claim")
				reasons.append("secret")
			var option = _option(box, labels)
			option.select(reasons.find(current.reasons.get(key, "unexplained")))
			option.item_selected.connect(func(i):
				current.reasons[key] = reasons[i]
				_edit())
			if current.reasons.get(key, "unexplained") in ["gift", "secret"]:
				var private_errand: bool = current.reasons[key] == "secret"
				var claims: Array = session.scenario.public_view.cards.filter(func(c): return c.kind == ("secret_claim" if private_errand else "claim") and c.subject == id)
				var citation = _option(box, ["? No supporting claim"] + claims.map(func(c): return "%s Â· %s Â· day %s" % [_name(c.subject), C.role_name(c.role), c.acquired_day]))
				citation.name = "Citation_%s_%d" % [id, card.night]
				citation.select(claims.map(func(c): return c.id).find(current.citations.get(key, "")) + 1)
				citation.item_selected.connect(func(i):
					if i == 0:
						current.citations.erase(key)
					else:
						current.citations[key] = claims[i - 1].id
					_edit())
				var support = Graph.valid_citation(session.scenario.public_view, current, id, card.night)
				if private_errand:
					support = claims.filter(func(c): return c.id == current.citations.get(key, ""))[0] if claims.any(func(c): return c.id == current.citations.get(key, "")) else {}
				_label(box, "Cited: %s. This could explain the outing; accuracy and activity are still assumptions." % support.text if not support.is_empty() else "No applicable walking-gift claim is cited; this explanation receives no discount.", 14, "muted")
	elif card.kind == "report" and role in ["warden", "gravedigger", "veteran", "martyr", "sexton"]:
		var explanation: String = {
			"warden": "This claims a guard at the named door on that night. Movement, public deaths and quiet nights weigh it together; a quiet night alone does not prove a successful protection.",
			"gravedigger": "This names the executed person's role at that execution. An evil-role result can also come from a good Marked person. No additional answer is required.",
			"veteran": "This claims the first survived Demon attack and its approach block. It can constrain the attacker's route if the report is sound. No additional answer is required.",
			"martyr": "This records a claimed choice; choosing someone does not establish that they are good. Comparing an earlier promise with a later hanging still needs a dated outcome adapter." if card.data.get("chosen", false) else "This claims the chosen person was hanged without substitution. If the gift was healthy, they registered evil; Marked remains an explanation.",
			"sexton": "A healthy toll stops gifts that need walking that night. Secret outings may continue. Hearing the bell alone does not establish that the gift worked."
		}[role]
		_label(box, explanation, 16, "muted")
	else:
		_label(box, "This statement can support an explanation or conflict with another report. No additional answer is required.", 16, "muted")

func _card_available(card: Dictionary) -> bool:
	return card.id in session.case_data.cards and (active_line == "" or card.id in _active_choices().cards)

func _identity_hint() -> String:
	return "Why did they register? Optional: assign Good Â· Marked or Evil under assumptions below. Those choices remain hypotheses."

func _active_choices() -> Dictionary:
	for line in session.case_data.lines:
		if line.id == active_line:
			for field in ["positions", "answers", "reasons", "citations"]:
				if not line.has(field):
					line[field] = {}
			return line
	active_line = ""
	return session.case_data

func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value not in result:
			result.append(value)
	return result

func _reasoning_lines() -> void:
	var box = _box(case_box)
	_label(box, "Lines supporting this case", 20, "accent")
	_label(box, "Each line groups evidence and optional assumptions. Intermediate claims are checked, never counted as extra evidence.", 15, "muted")
	_button(box, "Edit whole-case assumptions" + (" â—‚" if active_line == "" else ""), func():
		active_line = ""
		_refresh_case())
	for line in session.case_data.lines:
		var row = HBoxContainer.new()
		box.add_child(row)
		_button(row, line.label + (" â—‚" if line.id == active_line else ""), func():
			active_line = line.id
			_refresh_case())
		_button(row, "Remove", func():
			session.case_data.lines.erase(line)
			active_line = ""
			_edit())
	if session.case_data.lines.size() < 6:
		var add = _button(box, "Add reasoning line", func():
			var number = 1
			while session.case_data.lines.any(func(line): return line.id == "line_%d" % number):
				number += 1
			var line = {"id": "line_%d" % number, "label": "Line %d" % number, "relation": "supports", "cards": [], "positions": {}, "answers": {}}
			session.case_data.lines.append(line)
			active_line = line.id
			_edit())
		add.name = "AddReasoningLine"
	var current = _active_choices()
	if active_line != "":
		var label = LineEdit.new()
		label.text = current.label
		label.max_length = 120
		label.placeholder_text = "What does this line explain?"
		box.add_child(label)
		label.text_changed.connect(func(value):
			current.label = value
			session.revise()
			stale = true)
		var relation = _option(box, ["Supports the combined case", "Alternative explanation (check separately)"])
		relation.name = "LineRelation"
		relation.select(0 if current.relation == "supports" else 1)
		relation.item_selected.connect(func(i):
			current.relation = ["supports", "alternative"][i]
			_edit())
		_label(box, "Evidence in this line", 16)
		for id in session.case_data.cards:
			var card = _report(id)
			var choice = CheckBox.new()
			choice.text = ("Question: " + id) if card.is_empty() else (id + " Â· " + _name(card.source))
			choice.name = "LineEvidence_" + id
			choice.button_pressed = id in current.cards
			box.add_child(choice)
			choice.toggled.connect(func(on):
				if on:
					current.cards.append(id)
				else:
					current.cards.erase(id)
				_edit())
		var claim_check = CheckBox.new()
		claim_check.text = "Give this line an intermediate claim"
		claim_check.button_pressed = current.has("conclusion")
		box.add_child(claim_check)
		claim_check.toggled.connect(func(on):
			if on:
				current.conclusion = session.case_data.conclusion.duplicate(true)
				if current.conclusion.type == "conflict":
					current.conclusion.type = "suspicious"
			else:
				current.erase("conclusion")
			_edit())
		if current.has("conclusion"):
			var target = _person_option(box, current.conclusion.target)
			target.item_selected.connect(func(i):
				current.conclusion.target = session.scenario.public_view.people[i].id
				_edit())
			var type = _option(box, TYPE_NAMES.slice(0, 4))
			type.select(TYPES.find(current.conclusion.type))
			type.item_selected.connect(func(i):
				current.conclusion.type = TYPES[i]
				_edit())
		var isolated = Solver.empty_case()
		isolated.cards = Graph.roots(session.case_data, current.cards)
		isolated.positions = current.positions
		isolated.answers = current.answers
		isolated.conclusion = current.get("conclusion", session.case_data.conclusion)
		var result = Solver.analyze(session.scenario.public_view, isolated)
		_label(box, "This line alone: %s; %d possible assignments. Its answers are hypotheses." % [result.entailment, result.compatible], 15, "muted")
		var test = CheckBox.new()
		test.text = "Developer experiment: supply a soft test factor"
		test.button_pressed = current.has("test_factor")
		box.add_child(test)
		test.toggled.connect(func(on):
			if on:
				current.test_factor = {"target": session.case_data.conclusion.target, "log2_ratio": 0.0}
			else:
				current.erase("test_factor")
			_edit())
		if current.has("test_factor"):
			_label(box, "TEST INPUT ONLY. This does not infer an outing or trace likelihood. 1Ã— is neutral; below 1 favors good, above 1 favors evil.", 14, "accent")
			var target = _person_option(box, current.test_factor.target)
			target.item_selected.connect(func(i):
				current.test_factor.target = session.scenario.public_view.people[i].id
				_edit())
			var factor = SpinBox.new()
			factor.name = "TestFactorRatio"
			factor.min_value = 0.0625
			factor.max_value = 16
			factor.step = 0.25
			factor.value = pow(2.0, current.test_factor.log2_ratio)
			box.add_child(factor)
			_label(box, "Supplied evil/good evidence ratio: %.2fÃ—" % pow(2.0, current.test_factor.log2_ratio), 14)
			factor.value_changed.connect(func(value):
				current.test_factor.log2_ratio = log(value) / log(2.0)
				_edit())
	for question in session.case_data.derived:
		_label(box, "%s: %s Â· originals: %s" % [question.id, question.text, ", ".join(PackedStringArray(question.supports))], 15)
		_button(box, "Remove " + question.id, func():
			session.case_data.derived.erase(question)
			session.case_data.cards.erase(question.id)
			for line in session.case_data.lines:
				line.cards.erase(question.id)
			_edit())

func _conflict_controls() -> void:
	var box = _box(case_box)
	_label(box, "Which reports conflict?", 18)
	_label(box, "Select the specific accounts. Merely questioning a report does not establish that it is false.", 15, "muted")
	var roots = Graph.roots(session.case_data, session.case_data.cards)
	for id in roots:
		var card = _report(id)
		if card.is_empty() or card.kind == "claim":
			continue
		var check = CheckBox.new()
		check.name = "ConflictScope_" + id
		check.text = id + " Â· " + _name(card.source)
		check.button_pressed = id in session.case_data.conflict_scope
		box.add_child(check)
		check.toggled.connect(func(on):
			if on:
				session.case_data.conflict_scope.append(id)
			else:
				session.case_data.conflict_scope.erase(id)
			_edit())
	var candidates: Array = analysis.conflicts.reduce(func(all, ids): return _unique(all + ids), [])
	if not candidates.is_empty():
		_label(box, "Optional: which report do you question? The objection remains a hypothesis.", 15)
		var question = _option(box, ["? Leave unresolved"] + candidates)
		var chosen: Array = session.case_data.challenges.keys()
		question.select(candidates.find(chosen[0]) + 1 if not chosen.is_empty() else 0)
		question.item_selected.connect(func(i):
			session.case_data.challenges.clear()
			if i > 0:
				session.case_data.challenges[candidates[i - 1]] = session.case_data.conflict_scope.duplicate()
			_edit())

func _refresh_jury() -> void:
	_clear(jury_box)
	_label(jury_box, "Four jurors after restoration. Their own alignment knowledge is dated; the converted voter's identity is not supplied to the assessor." if session.scenario.public_view.get("chronology", {}).has("curse") else "Four living good townsfolk. Each knows their own gift reports and their own alignment.", 16, "muted")
	if stale and not session.last_results.is_empty():
		_label(jury_box, "Responses below are from the last presentation.", 15, "accent")
	for i in range(session.baseline.size()):
		var juror: Dictionary = session.baseline[i]
		var box = _box(jury_box)
		_label(box, juror.name + " Â· " + juror.preset, 20, "accent")
		if session.last_results.size() > i:
			var r: Dictionary = session.last_results[i]
			_label(box, r.response, 18)
			_label(box, r.objection, 16, "muted")
			var thought: Dictionary = r.reasoning
			_label(box, "%s reasoning Â· %s\nExplanation checks: %d (rivals: %d). Unattended: %s." % [thought.profile, thought.status.replace("_", " "), thought.tested, thought.rivals_tested, ", ".join(PackedStringArray(thought.ignored)) if not thought.ignored.is_empty() else "none"], 15, "accent")
			if not thought.ignored_lines.is_empty():
				_label(box, "Lines not connected to this argument: " + ", ".join(PackedStringArray(thought.ignored_lines)), 15, "muted")
			if r.theory.mode == "persistence":
				_label(box, "Working theory: %s Â· %s" % [r.theory.position if r.theory.position != "" else "unsettled", r.theory.status], 15, "accent")
			_label(box, "Suspicion %.3f â†’ %.3f (%+.3f)\nTrust in you %.2f â†’ %.2f" % [r.before_suspicion, r.after_suspicion, r.suspicion_delta, r.before_trust, r.after_trust], 16)
			_label(box, "Effects on everyone", 16, "accent")
			var effect_lines: Array = []
			for person in session.scenario.public_view.people:
				var e: Dictionary = r.effects[person.id]
				if not is_zero_approx(e.applied) or not is_zero_approx(e.delta):
					effect_lines.append("%s: %.3f â†’ %.3f (%+.3f) Â· %s" % [person.name, e.before, e.after, e.delta, e.route])
			var effects_label = _label(box, "\n".join(PackedStringArray(effect_lines)) if not effect_lines.is_empty() else "No additional suspicion changes from this evidence.", 15)
			effects_label.name = "CaseEffects_%d" % i
			if r.claims.size() > 1:
				var claims_check = CheckBox.new()
				claims_check.text = "Claims and their connections"
				claims_check.button_pressed = true
				box.add_child(claims_check)
				var claims_box = VBoxContainer.new()
				claims_box.name = "CaseClaims_%d" % i
				box.add_child(claims_box)
				claims_check.toggled.connect(func(on): claims_box.visible = on)
				for claim in r.claims:
					_label(claims_box, "%s Â· %s (%.3f)" % [claim.label, claim.stance, claim.agreement], 15, "accent")
					_label(claims_box, claim.note, 15)
					if not claim.ignored.is_empty():
						_label(claims_box, "Not attended in this branch: " + ", ".join(PackedStringArray(claim.ignored)), 14, "muted")
					for link in claim.links:
						_label(claims_box, "To %s: %s" % [link.parent_label, link.note], 14, "muted")
			var show_calc = CheckBox.new()
			show_calc.text = "Show calculation & accepted path"
			box.add_child(show_calc)
			var calculation = _label(box, "Headline agreement %.2f; premise quality %.3f (conviction diagnostics).\nEffect multipliers: player %.2f Ã— confidence %.2f\nPath: %s (%s)\nPrevious headline-target effect %.3f; replacement %.3f. %s.\nPrivate compatible worlds: %d. These counts are not probabilities." % [r.agreement, r.quality, r.calculation.player_factor, r.calculation.confidence_factor, ", ".join(PackedStringArray(r.path)), r.path_kind, r.calculation.old_case_effect, r.calculation.new_case_effect, r.stance, r.assessment.compatible], 14, "muted")
			calculation.text += "\nCombined support %.3f; old strongest-path score %.3f. Forced-assumption weight %.3f across %d credibility states.\nSupport routes: %s\n%s" % [r.support_model.agreement, r.legacy_path.weight, r.support_model.forced_mass, r.support_model.states, str(r.support_model.paths), r.support_model.model]
			for comparison in r.support_model.get("movement_comparison", []):
				calculation.text += "\n%s: P(observations | evil hypotheses) %.6f; P(observations | good hypotheses) %.6f; ratio %.3fx. These are conditional fixture likelihoods, not guilt probabilities." % [_name(comparison.target), comparison.evil_likelihood, comparison.good_likelihood, pow(2.0, comparison.log2_ratio)]
			if not r.support_model.get("faults", []).is_empty():
				calculation.text += "\nShared health uncertainty: " + str(r.support_model.faults) + ". Removing a cited basis removes that support; other periods retain their own reliability."
			calculation.text += "\nThe agreement calculation above describes the headline assessment. Actual suspicion uses the signed evil/good evidence comparison below, with the private-evidence reference subtracted.\n" + r.effect_rule
			for person in session.scenario.public_view.people:
				var e: Dictionary = r.effects[person.id]
				calculation.text += "\n%s: evil change %.4f; good change %.4f; alignment %.4f; pattern %.4f; requested %+.4f; applied %+.4f (previous %+.4f)." % [person.name, e.evil_change, e.good_change, e.alignment_signal, e.pattern_signal, e.requested, e.applied, e.previous]
			calculation.text += "\nConsidered: %s\nGranted for search: %s\nDoubted: %s\nOwn reports (outside attention limit): %s\n%s\nReferee: %s; NPC: %s. A limited search is never a proof." % [str(thought.considered), str(thought.accepted), str(thought.doubted), str(thought.private_reports), thought.assumption_note, r.assessment.entailment, thought.status]
			calculation.text += "\nConfidence mode: %s; theory %s â†’ %s (%s); revision comparison threshold %.2fÃ—.\n%s" % [r.theory.mode, r.theory.before, r.theory.position, r.theory.status, r.theory.threshold, r.theory.guardrail]
			for id in r.support_model.report_acceptance:
				var card = _report(id)
				if id in r.support_model.quoted_cards:
					calculation.text += "\n%s: quoted testimony; contents challenged, not accepted as accurate." % id
				elif card.kind != "claim":
					calculation.text += "\n%s: retained credibility weight %.3f" % [id, r.support_model.report_acceptance[id]]
			calculation.visible = false
			show_calc.toggled.connect(func(on): calculation.visible = on)
		else:
			_label(box, "Waiting to hear your case.", 17, "muted")
		var compare = _button(box, "Compare Insight levels", func():
			reasoning_comparisons[i] = session.compare_reasoning(i)
			_refresh_jury())
		compare.name = "CompareInsight_%d" % i
		if reasoning_comparisons.has(i):
			_label(box, "Same juror and starting attitudes; confidence uses its original scale. Snapshot: compare again after changing the case or settings.", 14, "muted")
			for compared in reasoning_comparisons[i]:
				_label(box, "%s: %s; conviction %.3f; suspicion change %+.3f; %d checks." % [compared.reasoning.profile, compared.reasoning.status.replace("_", " "), compared.agreement, compared.suspicion_delta, compared.reasoning.tested], 15)
		var settings_check = CheckBox.new()
		settings_check.text = "Adjust this juror"
		box.add_child(settings_check)
		var settings = VBoxContainer.new()
		settings.visible = false
		box.add_child(settings)
		settings_check.toggled.connect(func(on): settings.visible = on)
		_slider(settings, "Trust in you", juror.trust, func(value): _set_juror(i, "trust", value))
		_slider(settings, "Confidence", juror.confidence, func(value): _set_juror(i, "confidence", value))
		var confidence_mode = _option(settings, ["Confidence scales change (original)", "Confidence sustains a theory (experiment)"])
		confidence_mode.name = "ConfidenceMode_%d" % i
		confidence_mode.select(0 if juror.confidence_mode == "scale" else 1)
		confidence_mode.item_selected.connect(func(index): _set_juror(i, "confidence_mode", ["scale", "persistence"][index]))
		_label(settings, "Theory persistence uses a change multiplier of 1. Reset discussion to start a fresh theory; use remembered discussion to test revisions.", 14, "muted")
		var mode = _option(settings, ["Full reasoning (comparison)", "Bounded reasoning (Insight)"])
		mode.name = "ReasoningMode_%d" % i
		mode.select(0 if juror.reasoning_mode == "full" else 1)
		mode.item_selected.connect(func(index): _set_juror(i, "reasoning_mode", ["full", "bounded"][index]))
		_slider(settings, "Insight", juror.insight, func(value): _set_juror(i, "insight", value))
		_label(settings, "Their view ofâ€¦", 15)
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
		_label(settings, "Reliability of one reading (separate from source trust)", 15)
		var reports: Array = session.scenario.public_view.cards.filter(func(c): return c.kind == "report")
		var reading = _option(settings, reports.map(func(c): return c.id + " Â· " + _name(c.source)))
		var reliability_box = VBoxContainer.new()
		settings.add_child(reliability_box)
		var rebuild_reliability = func(index):
			_clear(reliability_box)
			var key: String = reports[index].get("accuracy_origin", Solver.semantic_key(reports[index]))
			_slider(reliability_box, "Reading accuracy", juror.reading_reliability[key], func(value):
				session.baseline[i].reading_reliability[key] = value
				session.listeners[i].reading_reliability[key] = value
				stale = true
				status.text = "Reading reliability changed. Other reports and testimony keep their own weights.")
		reading.item_selected.connect(rebuild_reliability)
		rebuild_reliability.call(0)
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

func _set_juror(index: int, field: String, value) -> void:
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
	reasoning_comparisons.clear()
	session.present(remember.button_pressed, ["private", "meeting", "nomination"][venue.selected])
	stale = false
	_refresh_jury()
	status.text = "Presented v%d Â· %s Â· %d recorded presentations. Trust is held fixed; actual suspicion changes are shown." % [session.case_data.version, "remembered discussion" if remember.button_pressed else "identical starting attitudes", session.history.size()]

func _load_example(index: int) -> void:
	reasoning_comparisons.clear()
	var target: String = session.scenario.slots.demon
	var version: int = session.case_data.version + 1
	session.case_data = Solver.empty_case()
	active_line = ""
	session.case_data.version = version
	session.case_data.conclusion.target = target
	session.case_data.cards = [["survey"], ["survey", "rumor"], ["survey", "rumor", "dowse"], ["watch1", "watch2"], ["watch1", "alibi1"], ["survey", "rumor", "dowse", "watch1", "watch2"], ["survey", "rumor", "dowse"]][index - 1].duplicate()
	if index == 4:
		session.case_data.conclusion.type = "suspicious"
		focus_card = "watch2"
	elif index == 5:
		session.case_data.conclusion.type = "conflict"
		session.case_data.conflict_scope = ["watch1", "alibi1"]
		focus_card = "alibi1"
	elif index == 6:
		session.case_data.lines = [
			{"id": "readings", "label": "The readings narrow the candidates", "relation": "supports", "cards": ["survey", "rumor", "dowse"], "positions": {}, "answers": {}},
			{"id": "movement", "label": "Movement comparison â€” supplied TEST factor", "relation": "supports", "cards": ["watch1", "watch2"], "positions": {}, "answers": {}, "test_factor": {"target": target, "log2_ratio": 2.0}}]
		active_line = "movement"
		focus_card = "watch2"
	elif index == 7:
		focus_card = "survey"
		_changed()
		reasoning_comparisons[0] = session.compare_reasoning(0)
		_refresh_jury()
		return
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
	if not value is Dictionary or value.get("format", "") not in ["demonologist-case-workshop-1", "demonologist-case-workshop-2", "demonologist-case-workshop-3", "demonologist-case-workshop-4", "demonologist-case-workshop-5"]:
		status.text = "This is not a Case Workshop experiment."
		return
	var result = session.restore(value)
	if result != "":
		status.text = result
		return
	reasoning_comparisons.clear()
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
	for i in range(session.baseline.size()):
		session.baseline[i].reasoning_mode = "bounded" if i < 3 else "full"
		session.baseline[i].insight = [0.1, 0.5, 0.9, 0.9][i]
	session.baseline[0].confidence_mode = "persistence"
	remember.button_pressed = false
	_present()
	reasoning_comparisons[0] = session.compare_reasoning(0)
	_refresh_jury()
	for frame in range(6):
		await get_tree().process_frame
	var args = OS.get_cmdline_user_args()
	var screenshot_index = args.find("--screenshot")
	if screenshot_index >= 0 and screenshot_index + 1 < args.size() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[screenshot_index + 1])
	print("Workshop UI smoke passed: 5 presentations, example switching, remembered repetition.")
	get_tree().quit()
