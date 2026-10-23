## Developer inspector for live evidence. Proposed effects are never applied.
extends Control
var g
var cases: OptionButton
var listeners: OptionButton
var automatic: CheckBox
var inspect_button: Button
var preview_button: Button
var effects_toggle: CheckBox
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
	effects_toggle = CheckBox.new()
	effects_toggle.text = "Experimental shared reading effects (Debug; unsupported cases use legacy beliefs)"
	effects_toggle.toggled.connect(func(on):
		if g.debug_overlay:
			g.set_workshop_effects(on)
			effects_toggle.set_pressed_no_signal(g.workshop_effects)
		else:
			effects_toggle.set_pressed_no_signal(false))
	column.add_child(effects_toggle)
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
	preview_button = Button.new()
	preview_button.text = "Preview effectiveness"
	preview_button.pressed.connect(_preview)
	actions.add_child(preview_button)
	var retract_button = Button.new()
	retract_button.text = "Withdraw selected endorsement"
	retract_button.pressed.connect(func():
		if not g.debug_overlay or cases.item_count == 0 or listeners.item_count == 0:
			return
		var id: String = listeners.get_item_metadata(listeners.selected)
		g.workshop_retract(cases.get_item_metadata(cases.selected), id)
		output.text = "Case endorsement withdrawn for %s. Independently learned reports remain.\n%s" % [id.capitalize(), _ownership(id)])
	actions.add_child(retract_button)
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
	effects_toggle.set_pressed_no_signal(g.workshop_effects)
	effects_toggle.disabled = not g.debug_overlay
	preview_button.disabled = cases.item_count == 0
	inspect_button.disabled = cases.item_count == 0 or listeners.item_count == 0 or not g.debug_overlay
	output.text = "Enable Debug in the main window to inspect private NPC responses. Debug inspection leaves identification unscored." if not g.debug_overlay else "Choose a filed deduction and a listener. Inspection costs no game time. Recorded presentations keep the original response alongside the new proposal."
	if cases.item_count == 0:
		output.text += "\n\nThere are no filed deductions in this case yet."
	else:
		output.text += "\n\nPreview effectiveness uses a neutral ghost with player-held evidence only; Debug is not required."

func _preview() -> void:
	if cases.item_count == 0:
		return
	var number: int = cases.get_item_metadata(cases.selected)
	var captured_game = g
	preview_button.disabled = true
	output.text = "Calculating neutral reference response…"
	await get_tree().process_frame
	if g != captured_game:
		return
	output.text = "Effectiveness preview · neutral ghost\n\n" + describe(g.workshop_ghost_preview(number))
	preview_button.disabled = false

func _ownership(id: String) -> String:
	var real = g.w.by_id[id]
	var n = real.shadow if real.is_evil() else real
	if n == null or n.workshop_state.is_empty():
		return "Shared reading ownership is inactive."
	var state: Dictionary = n.workshop_state
	return "Shared owner active: %s. %d endorsed facts; %d quoted reports; %d replaced entries.\n%s" % [str(state.get("active", false)), state.get("facts", []).size(), state.get("quoted", []).size(), state.get("owned", {}).size(), "\n".join(PackedStringArray(state.get("issues", [])))]

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
	output.text += "\n\n" + _ownership(listener)
	inspect_button.disabled = false

func _records() -> void:
	if not g.debug_overlay:
		output.text = "Enable Debug to inspect private comparisons."
		return
	var lines = PackedStringArray()
	for result in g.workshop_comparisons:
		var actual: Dictionary = result.get("actual", result.get("legacy", {}))
		var label = "Applied shared assessment" if actual.get("model") == "shared" else "Original agreement"
		lines.append("Card #%d · %s · %s\n%s %.3f\n%s" % [result.card,
			g.w.by_id[result.listener].name if g.w.by_id.has(result.listener) else result.listener,
			result.venue, label, actual.get("agreement", 0.0), describe(result)])
	output.text = "\n\n————————————————\n\n".join(lines) if not lines.is_empty() else "No presentations recorded. Enable recording, then present a deduction in a conversation or meeting."

static func describe(result: Dictionary) -> String:
	if not result.ready:
		return "No numeric comparison:\n• " + "\n• ".join(PackedStringArray(result.issues))
	var proposal: Dictionary = result.proposal
	var lines = PackedStringArray(["New model: %s · agreement %.3f · %d ms" % [proposal.stance, proposal.support_model.agreement, result.elapsed_ms],
		proposal.response, "", "Evidence strength (not applied to the game):"])
	lines.insert(2, "Conditional worlds: %d compatible; %d fit your answers. These are assignments, not odds of guilt." % [proposal.assessment.compatible, proposal.assessment.proposed])
	var reasoning: Dictionary = proposal.get("reasoning", {})
	if not reasoning.is_empty():
		lines.insert(3, "Reasoning: %s · %d reports considered, %d set aside · %d support checks, %d alternative checks · %s." % [reasoning.profile, reasoning.considered.size(), reasoning.ignored.size(), reasoning.support_tested, reasoning.rivals_tested, reasoning.status])
	var theory: Dictionary = proposal.get("theory", {})
	if theory.get("mode") == "persistence":
		lines.insert(4, "Working theory: %s. %s" % [theory.status, theory.note])
	for person in proposal.effects:
		var effect: Dictionary = proposal.effects[person]
		if not is_zero_approx(effect.requested):
			var clamped = " (clamped change %+.3f)" % effect.delta if not is_equal_approx(effect.delta, effect.requested) else ""
			lines.append("%s: %+.3f%s" % [person.capitalize(), effect.requested, clamped])
	for claim in proposal.claims:
		lines.append("Claim about %s: %s. %s" % [claim.conclusion.target.capitalize(), claim.stance, claim.note])
	var audit: Dictionary = result.get("ledger_audit", {})
	if not audit.is_empty():
		lines.append("\nExisting evidence: %d reading entries, %d potentially overlapping arguments, %d ambiguous legacy identities.\n%s" % [audit.reading_entries.size(), audit.potential_arguments.size(), audit.aliases.size(), audit.note])
	lines.append("\n" + result.scope)
	return "\n".join(lines)
