## Standalone comparison scene (F6). Does not touch main UI or a running case.
extends Control

const Dialogue = preload("res://sim/dialogue.gd")
const Voices = preload("res://sim/dialogue_voices.gd")
const Fixtures = preload("res://tools/dialogue_scenarios.gd")
const C = preload("res://sim/content.gd")
const ThemeSkin = preload("res://ui/theme.gd")

var scenario_opt: OptionButton
var trust_opt: OptionButton
var audience_opt: OptionButton
var speech_act_opt: OptionButton
var warmth_check: CheckBox
var pressure_check: CheckBox
var relationship_check: CheckBox
var private_check: CheckBox
var note: Label
var core: Label
var outputs = {}
var cues = {}
var memories = {}
var last_results = {}

func _ready() -> void:
	theme = ThemeSkin.make()
	var bg = ColorRect.new()
	bg.color = ThemeSkin.color("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll = ScrollContainer.new()
	margin.add_child(scroll)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	scroll.add_child(body)
	_label(body, "Dialogue workshop", 32)
	_label(body, "Three voices, standalone situations and full speaker turns. Synthetic examples; no live case or hidden roles are loaded.", 18)
	var selectors = HFlowContainer.new()
	selectors.add_theme_constant_override("h_separation", 18)
	body.add_child(selectors)
	var situations: Array = Fixtures.SCENARIOS + Fixtures.FLOW_SCENARIOS + Fixtures.EXCHANGE_SCENARIOS
	scenario_opt = _option(selectors, "Situation", situations.map(func(s): return s["title"]))
	scenario_opt.item_selected.connect(func(_i): _refresh(false))
	trust_opt = _option(selectors, "Trust in listener", ["Low", "Neutral", "High"])
	trust_opt.select(1)
	trust_opt.item_selected.connect(func(_i): _refresh(false))
	audience_opt = _option(selectors, "Audience", ["Player privately", "Town meeting", "Another listener"])
	audience_opt.item_selected.connect(func(_i): _refresh(false))
	speech_act_opt = _option(selectors, "Speech act", ["Scenario default", "Answering a question", "Volunteering information"])
	speech_act_opt.item_selected.connect(func(_i): _refresh(false))
	var toggles = HFlowContainer.new()
	body.add_child(toggles)
	pressure_check = _check(toggles, "Under pressure", false)
	relationship_check = _check(toggles, "Friendship is established", true)
	private_check = _check(toggles, "Requests confidentiality", false)
	warmth_check = _check(toggles, "Warm delivery", false)
	note = _label(body, "", 18)
	core = _label(body, "", 22)
	core.add_theme_color_override("font_color", ThemeSkin.color("accent"))
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	body.add_child(columns)
	for id in Fixtures.IDS:
		memories[id] = {}
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.0
		panel.add_theme_stylebox_override("panel", ThemeSkin.flat(ThemeSkin.color("panel"), C.npc_color(id), 2, 8, 20))
		columns.add_child(panel)
		var card = VBoxContainer.new()
		card.add_theme_constant_override("separation", 18)
		panel.add_child(card)
		var cast: Dictionary = C.CAST.filter(func(c): return c["id"] == id)[0]
		var title = _label(card, cast["name"], 28)
		title.add_theme_color_override("font_color", C.npc_color(id))
		_label(card, Voices.VOICES[id]["description"], 18)
		outputs[id] = _label(card, "", 24)
		outputs[id].custom_minimum_size.y = 240
		cues[id] = _label(card, "", 16)
	var actions = HBoxContainer.new()
	body.add_child(actions)
	var speak = Button.new()
	speak.text = "Speak / ask again"
	speak.pressed.connect(func(): _refresh(true))
	actions.add_child(speak)
	var reset = Button.new()
	reset.text = "Reset conversation memory"
	reset.pressed.connect(reset_memory)
	actions.add_child(reset)
	_label(body, "Changing controls previews the next line or entire turn. Speak records delivery; previews never consume memory.\nCanonical statements stay intact. Explicit shared scene/time slots allow concise speech. Speech act, pressure and optional warmth affect the opening; confidentiality applies only in private.", 17)
	_refresh(false)

func _label(parent: Node, text_value: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _option(parent: Node, title: String, items: Array) -> OptionButton:
	var box = VBoxContainer.new()
	parent.add_child(box)
	_label(box, title, 16)
	var option = OptionButton.new()
	for item in items:
		option.add_item(item)
	box.add_child(option)
	return option

func _check(parent: Node, text_value: String, selected: bool) -> CheckBox:
	var check = CheckBox.new()
	check.text = text_value
	check.button_pressed = selected
	check.toggled.connect(func(_v): _refresh(false))
	parent.add_child(check)
	return check

func reset_memory() -> void:
	for id in Fixtures.IDS:
		memories[id] = {}
	_refresh(false)

func _flow_render(id: String, scenario: Dictionary, context: Dictionary, memory: Dictionary) -> Dictionary:
	var parts: Array = Dialogue.compose_turn(id, Fixtures.flow_parts(id, scenario), context, memory, scenario.get("preceded", false))
	var spoken: Array = []
	if not str(scenario.get("lead_in", "")).is_empty():
		spoken.append(scenario["lead_in"])
	for part in parts:
		spoken.append(part["text"])
	return {"text": " ".join(PackedStringArray(spoken)), "intent": "turn",
		"parts": parts, "cue": " / ".join(PackedStringArray(parts.map(func(p): return p["cue"]))),
		"repeated": parts.any(func(p): return p["repeated"])}

func _exchange_render(id: String, scenario: Dictionary, memory: Dictionary) -> Dictionary:
	# A preview receives a copied memory; priming it cannot change real delivery.
	if not memory.has("conversation"):
		Dialogue.begin_conversation(memory)
		Dialogue.record_exchange(memory, scenario["previous_action"],
			id if scenario["mode"] == "gift" else scenario["subject_id"])
	var mode: String = scenario["mode"]
	var subject_id: String = id if mode == "gift" else scenario["subject_id"]
	var cue: String = Dialogue.exchange_cue(memory, "gift" if mode == "gift" else "opinion", subject_id)
	var said: String = scenario["statement"]
	if mode == "gift":
		var reveal: String = Dialogue.gift_reveal(id, scenario["role"], cue)
		if reveal != "":
			said = reveal
	elif mode == "refusal":
		said = Dialogue.repeated_opinion_refusal(id, scenario["subject_name"], cue, said)
		said = Dialogue.contextualize(id, said, cue if cue != "opinion_again" else "", scenario["subject_name"])
	else:
		said = Dialogue.contextualize(id, said, cue, scenario["subject_name"])
	Dialogue.record_exchange(memory, "gift" if mode == "gift" else "opinion", subject_id)
	return {"text": said, "statement": scenario["statement"], "intent": "exchange",
		"cue": cue, "repeated": false}

func _refresh(deliver: bool) -> void:
	var is_flow: bool = scenario_opt.selected >= Fixtures.SCENARIOS.size() and scenario_opt.selected < Fixtures.SCENARIOS.size() + Fixtures.FLOW_SCENARIOS.size()
	var is_exchange: bool = scenario_opt.selected >= Fixtures.SCENARIOS.size() + Fixtures.FLOW_SCENARIOS.size()
	var scenario: Dictionary
	if is_flow:
		scenario = Fixtures.FLOW_SCENARIOS[scenario_opt.selected - Fixtures.SCENARIOS.size()]
	elif is_exchange:
		scenario = Fixtures.EXCHANGE_SCENARIOS[scenario_opt.selected - Fixtures.SCENARIOS.size() - Fixtures.FLOW_SCENARIOS.size()]
	else:
		scenario = Fixtures.SCENARIOS[scenario_opt.selected]
	var context: Dictionary = scenario.get("context", {}).duplicate(true)
	context["trust"] = [0.15, 0.5, 0.85][trust_opt.selected]
	context["pressure"] = 1.0 if pressure_check.button_pressed else 0.0
	context["audience"] = ["player", "town", "other_listener"][audience_opt.selected]
	context["close"] = relationship_check.button_pressed
	context["request_privacy"] = private_check.button_pressed
	if speech_act_opt.selected > 0: context["speech_act"] = ["", "answer", "volunteer"][speech_act_opt.selected]
	context["warm"] = warmth_check.button_pressed
	note.text = scenario["note"]
	if is_flow:
		core.text = "Approved statements:\n" + "\n".join(PackedStringArray(scenario["parts"].map(func(p): return p["statement"])))
	else:
		core.text = "Approved statement: " + scenario["statement"]
	for id in Fixtures.IDS:
		var memory: Dictionary = memories[id] if deliver else memories[id].duplicate(true)
		var result: Dictionary
		if is_exchange:
			result = _exchange_render(id, scenario, memory)
		elif is_flow:
			result = _flow_render(id, scenario, context, memory)
		else:
			Fixtures.prime(id, scenario, context["audience"], memory)
			result = Dialogue.compose(id, scenario, context, memory)
		outputs[id].text = result["text"]
		cues[id].text = "%s · %s" % ["Delivered" if deliver else "Preview", result["cue"] if result["cue"] != "" else "unchanged fallback"]
		last_results[id] = result
