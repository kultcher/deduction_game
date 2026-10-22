## Developer inspector for live evidence. Proposed effects are never applied.
extends Control
var g
var cases: OptionButton
var listeners: OptionButton
var automatic: CheckBox
var inspect_button: Button
var output: RichTextLabel
var heading: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	var column = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	heading = Label.new()
	heading.text = "Live Workshop comparison"
	heading.add_theme_font_size_override("font_size", 25)
	column.add_child(heading)
	var explanation = Label.new()
	explanation.text = "Compare a filed deduction against the new reading model. Proposed belief changes are not applied. Surveyor, Rumormonger and Dowser reports are supported; other mechanics are flagged."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(explanation)
	automatic = CheckBox.new()
	automatic.text = "Record comparisons when I present deductions (may add a pause)"
	automatic.toggled.connect(func(on): g.workshop_compare = on)
	column.add_child(automatic)
	var row = HBoxContainer.new()
	column.add_child(row)
	cases = OptionButton.new()
	cases.clip_text = true
	cases.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cases.custom_minimum_size.x = 400
	row.add_child(cases)
	listeners = OptionButton.new()
	listeners.custom_minimum_size.x = 150
	row.add_child(listeners)
	inspect_button = Button.new()
	inspect_button.text = "Inspect now"
	inspect_button.pressed.connect(_inspect)
	row.add_child(inspect_button)
	var actions = HBoxContainer.new()
	column.add_child(actions)
	var refresh_button = Button.new()
	refresh_button.text = "Refresh cases"
	refresh_button.pressed.connect(refresh)
	actions.add_child(refresh_button)
	var records_button = Button.new()
	records_button.text = "Recorded presentations"
	records_button.pressed.connect(_records)
	actions.add_child(records_button)
	output = RichTextLabel.new()
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.selection_enabled = true
	output.add_theme_font_size_override("normal_font_size", 17)
	column.add_child(output)
	refresh()

func refresh() -> void:
	cases.clear()
	listeners.clear()
	for card in g.board:
		if card.get("kind") == "deduction" and not card.get("deleted", false):
			cases.add_item("#%d · %s" % [card.n, card.text])
			cases.set_item_metadata(cases.item_count - 1, card.n)
	for n in g.w.living():
		listeners.add_item(n.name)
		listeners.set_item_metadata(listeners.item_count - 1, n.id)
	automatic.set_pressed_no_signal(g.workshop_compare)
	inspect_button.disabled = cases.item_count == 0 or listeners.item_count == 0 or not g.debug_overlay
	output.text = "Enable Debug in the main window to inspect private NPC responses. Debug inspection leaves identification unscored." if not g.debug_overlay else "Choose a filed deduction and a listener. Inspection costs no game time. Recorded presentations keep the original response alongside the new proposal."
	if cases.item_count == 0:
		output.text += "\n\nThere are no filed deductions in this case yet."

func _inspect() -> void:
	if not g.debug_overlay or cases.item_count == 0 or listeners.item_count == 0:
		return
	var number: int = cases.get_item_metadata(cases.selected)
	var listener: String = listeners.get_item_metadata(listeners.selected)
	var captured_game = g
	inspect_button.disabled = true
	output.text = "Assessing the selected evidence…"
	await get_tree().process_frame
	if g != captured_game:
		return # A new case replaced the selected game while the status was rendering.
	var result = g.workshop_preview(number, listener)
	output.text = "Card #%d · %s\n\n%s" % [number, g.w.by_id[listener].name, describe(result)]
	inspect_button.disabled = false

func _records() -> void:
	if not g.debug_overlay:
		output.text = "Enable Debug to inspect private comparisons."
		return
	var lines = PackedStringArray()
	for result in g.workshop_comparisons:
		lines.append("Card #%d · %s · %s\nOriginal agreement %.3f\n%s" % [result.card,
			g.w.by_id[result.listener].name if g.w.by_id.has(result.listener) else result.listener,
			result.venue, result.legacy.agreement, describe(result)])
	output.text = "\n\n————————————————\n\n".join(lines) if not lines.is_empty() else "No presentations recorded. Enable recording, then present a deduction in a conversation or meeting."

static func describe(result: Dictionary) -> String:
	if not result.ready:
		return "No numeric comparison:\n• " + "\n• ".join(PackedStringArray(result.issues))
	var proposal: Dictionary = result.proposal
	var lines = PackedStringArray(["New model: %s · agreement %.3f · %d ms" % [proposal.stance, proposal.support_model.agreement, result.elapsed_ms],
		proposal.response, "", "Proposed changes relative to the captured beliefs (not applied):"])
	for person in proposal.effects:
		var effect: Dictionary = proposal.effects[person]
		if not is_zero_approx(effect.requested):
			lines.append("%s: %+.3f" % [person.capitalize(), effect.requested])
	for claim in proposal.claims:
		lines.append("Claim about %s: %s. %s" % [claim.conclusion.target.capitalize(), claim.stance, claim.note])
	var audit: Dictionary = result.get("ledger_audit", {})
	if not audit.is_empty():
		lines.append("\nExisting evidence: %d reading entries, %d potentially overlapping arguments, %d ambiguous legacy identities.\n%s" % [audit.reading_entries.size(), audit.potential_arguments.size(), audit.aliases.size(), audit.note])
	lines.append("\n" + result.scope)
	return "\n".join(lines)
