## Standalone presentation checkpoint: no World, Game, roles or case state is created.
extends Control

const ThemeSkin = preload("res://ui/theme.gd")
const View = preload("res://ui/day_conversation_view.gd")
const InkPlayer = preload("res://ui/portrait_ink_player.gd")
const Assets = preload("res://ui/portrait_ink_assets.gd")
const LEGACY = preload("res://ui/line_boil.gdshader")
const EXPRESSIONS = ["neutral", "warm", "harsh", "concerned", "sorrowful"]
const SAMPLE = "Jory says the Seer saw someone near the well. I'd hear the whole story before naming anyone the Demon. A few dark marks don't make a whole picture, do they?"

var expression = "neutral"
var player = InkPlayer.new()
var still_player = InkPlayer.new()
var legacy_mats: Array[ShaderMaterial] = []
var legacy_noise: NoiseTexture2D
var legacy = false
var expression_opt: OptionButton
var layout_opt: OptionButton
var look_opt: OptionButton
var reading_mode_opt: OptionButton
var pause_check: CheckBox
var pulse_button: Button
var controls: Dictionary = {}
var compare: HBoxContainer
var stage: Control
var reading: Control
var reading_frame: Control
var conversation
var portraits: Array[TextureRect] = []
var previous: Array[TextureRect] = []
var tweens: Array[Tween] = []
var caption: Label
var status: Label
var crossfade = true
var last_texture: Texture2D

func _ready() -> void:
	theme = ThemeSkin.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = ThemeSkin.color("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	var header = HBoxContainer.new()
	body.add_child(header)
	var title = _label(header, "Living ink — Edda", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Back to dialogue lab", _close)
	var selectors = HFlowContainer.new()
	selectors.add_theme_constant_override("h_separation", 12)
	body.add_child(selectors)
	expression_opt = _option(selectors, ["Neutral", "Warm", "Harsh", "Worried", "Sorrowful"])
	expression_opt.item_selected.connect(func(i): set_expression(EXPRESSIONS[i]))
	layout_opt = _option(selectors, ["Compare three views", "Read a conversation"])
	layout_opt.item_selected.connect(func(i): set_reading(i == 1))
	look_opt = _option(selectors, ["Protected interior ink", "Legacy reconstructed portrait"])
	look_opt.item_selected.connect(func(i):
		legacy = i == 1
		_update_portraits())
	reading_mode_opt = _option(selectors, ["Reading: animated ink", "Reading: ink held still", "Reading: original art"])
	reading_mode_opt.disabled = true
	reading_mode_opt.item_selected.connect(func(i): conversation.set_portrait_ink_mode(["animated", "still", "original"][i]))
	pause_check = _check(selectors, "Pause motion", false, func(v):
		player.paused = v
		conversation.ink_player.paused = v)
	_button(selectors, "Restart clock", reset_clock)
	_button(selectors, "Replay dialogue", _speak)
	pulse_button = _button(selectors, "Test pulse", func():
		player.pulse()
		conversation.ink_player.pulse())
	var sliders = HFlowContainer.new()
	sliders.add_theme_constant_override("h_separation", 18)
	body.add_child(sliders)
	_slider(sliders, "rate", "Redraws / second", 1, 12, 1, 6)
	_slider(sliders, "displacement", "Motion (source px)", 0, 4, 0.1, 1.2)
	_slider(sliders, "amount", "Added ink", 0, 1, 0.05, 0.6)
	var toggles = HFlowContainer.new()
	toggles.add_theme_constant_override("h_separation", 12)
	body.add_child(toggles)
	for spec in [["protect_face", "Protect face", true], ["protect_edge", "Protect silhouette", true],
		["show_protection", "Show protection mask", false], ["warp", "Deform hatching", true],
		["variants", "Cycle old ink variants", false], ["pressure", "Vary pen pressure", false]]:
		var key: String = spec[0]
		controls[key] = _check(toggles, spec[1], spec[2], func(v): _setting(key, v))
	_check(toggles, "Expression cross-fade", true, func(v):
		crossfade = v
		conversation.portrait_fade_enabled = v)
	caption = _label(body, "", 16)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage = Control.new()
	stage.custom_minimum_size.y = 260
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	compare = HBoxContainer.new()
	compare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	compare.add_theme_constant_override("separation", 12)
	stage.add_child(compare)
	for text in ["Original artwork", "Same ink · held still", "Same ink · animated"]:
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = 1.0
		compare.add_child(column)
		_label(column, text, 18)
		var panel = Control.new()
		panel.clip_contents = true
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(panel)
		var back = TextureRect.new()
		back.texture = preload("res://assets/art/blocks/square.png")
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		back.modulate = Color(0.48, 0.46, 0.43)
		back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(back)
		for is_previous in [false, true]:
			var r = TextureRect.new()
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(r)
			if is_previous:
				r.hide()
				previous.append(r)
			else:
				portraits.append(r)
	reading = Control.new()
	reading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(reading)
	reading_frame = Control.new()
	reading.add_child(reading_frame)
	stage.resized.connect(_fit_reading)
	var read_back = TextureRect.new()
	read_back.texture = preload("res://assets/art/blocks/square.png")
	read_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	read_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	read_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reading_frame.add_child(read_back)
	conversation = View.new()
	reading_frame.add_child(conversation)
	conversation.begin("edda", "Edda")
	conversation.set_portrait_ink_mode("animated")
	for text in ["Ask about last night", "Ask about Jory", "Leave preview"]:
		_button(conversation.controls, text, func():
			if text == "Leave preview":
				layout_opt.select(0)
				set_reading(false)
			else:
				_speak())
	conversation.set_process(false) # This lab advances its clock and reveal explicitly.
	conversation.set_process_unhandled_key_input(false)
	reading.hide()
	status = _label(body, "", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	still_player.mode = "still"
	_update_portraits()
	_speak()
	_fit_reading()

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	# Inline flow/HBox labels need their natural width; wrapping can collapse them
	# to a one-character column and stretch the entire control row vertically.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _option(parent: Node, labels: Array) -> OptionButton:
	var opt = OptionButton.new()
	for text in labels:
		opt.add_item(text)
	parent.add_child(opt)
	return opt

func _check(parent: Node, text: String, on: bool, callback: Callable) -> CheckBox:
	var check = CheckBox.new()
	check.text = text
	check.button_pressed = on
	check.toggled.connect(callback)
	parent.add_child(check)
	return check

func _slider(parent: Node, key: String, text: String, low: float, high: float, step: float, initial: float) -> void:
	var box = HBoxContainer.new()
	parent.add_child(box)
	_label(box, text, 16)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size.x = 120
	box.add_child(slider)
	var value_label = _label(box, "%.2f" % initial, 16)
	value_label.custom_minimum_size.x = 42
	slider.value_changed.connect(func(v):
		value_label.text = "%.2f" % v
		_setting(key, v))
	controls[key] = slider

func _setting(key: String, value: Variant) -> void:
	var change = {key: value}
	player.configure(change)
	still_player.configure(change)
	conversation.ink_player.configure(change)
	_sync_legacy()

func set_expression(value: String) -> void:
	expression = value if value in EXPRESSIONS else "neutral"
	_update_portraits()
	conversation.set_expression(expression)

func _update_portraits() -> void:
	if not reading.visible: look_opt.select(int(legacy))
	for tween in tweens:
		if tween.is_valid(): tween.kill()
	tweens.clear()
	var source: Texture2D = conversation._expression_texture("edda", expression)
	var old_source: Texture2D = load("res://assets/art/line_boil_poc/edda/%s-base.png" % expression)
	for i in range(3):
		previous[i].texture = portraits[i].texture
		previous[i].material = portraits[i].material
		portraits[i].texture = old_source if legacy and i > 0 else source
		portraits[i].material = null
		if crossfade and is_visible_in_tree() and previous[i].texture != null and last_texture != source:
			previous[i].modulate.a = 1.0
			previous[i].show()
			var tween = create_tween()
			tween.tween_property(previous[i], "modulate:a", 0.0, View.FADE_SECONDS)
			tween.tween_callback(previous[i].hide)
			tweens.append(tween)
		else:
			previous[i].hide()
	legacy_mats.clear()
	if legacy:
		for i in [1, 2]:
			var mat = ShaderMaterial.new()
			mat.shader = LEGACY
			for v in ["a", "b", "c"]:
				mat.set_shader_parameter("lines_" + v, load("res://assets/art/line_boil_poc/edda/%s-lines-%s.png" % [expression, v]))
			mat.set_shader_parameter("warp_tex", _noise())
			portraits[i].material = mat
			legacy_mats.append(mat)
		_sync_legacy()
	else:
		still_player.apply(portraits[1])
		player.apply(portraits[2])
	last_texture = source
	_refresh_caption()
	_sync_controls()

func _sync_controls() -> void:
	var historical = legacy and not reading.visible
	pulse_button.disabled = historical
	for key in controls:
		if key == "rate": continue
		var control: Control = controls[key]
		if control is HSlider: control.editable = not historical
		elif control is BaseButton: control.disabled = historical

func _refresh_caption() -> void:
	var ready = not Assets.entry("edda", expression).is_empty()
	caption.text = "Original at left. Middle and right use identical artwork: only the right-hand ink moves."
	if reading.visible:
		caption.text = "1024 × 680 conversation preview (scaled down if needed). Sample dialogue; click the bubble to reveal all."
		if not ready: caption.text += " This pose uses original art; ink is registered for Neutral only."
	elif legacy:
		caption.text = "Legacy comparison: reconstructed colour base and all-line animation. Its clock bug is corrected."
	elif not ready:
		caption.text = "This expression has no approved ink registration yet; all three show the original. Neutral is the visual checkpoint."

func _noise() -> NoiseTexture2D:
	if legacy_noise == null:
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 2
		legacy_noise = NoiseTexture2D.new()
		legacy_noise.noise = noise
		legacy_noise.seamless = true
	return legacy_noise

func _sync_legacy() -> void:
	for i in range(legacy_mats.size()):
		legacy_mats[i].set_shader_parameter("drawing_step", 0.0 if i == 0 else float(player.step_index % 4096))
		legacy_mats[i].set_shader_parameter("fps_rest", float(player.settings.rate))
		legacy_mats[i].set_shader_parameter("boil", 0.3)

func set_reading(value: bool) -> void:
	layout_opt.select(1 if value else 0)
	compare.visible = not value
	reading.visible = value
	look_opt.disabled = value
	reading_mode_opt.disabled = not value
	look_opt.select(0 if value else int(legacy))
	if not value:
		_update_portraits()
	_refresh_caption()
	_sync_controls()
	_fit_reading()

func _fit_reading() -> void:
	if reading_frame == null: return
	var reference = Vector2(1024, 680)
	var fit = minf(1.0, minf(stage.size.x / reference.x, stage.size.y / reference.y))
	reading_frame.size = reference * fit
	reading_frame.position = (stage.size - reading_frame.size) * 0.5

func _speak() -> void:
	conversation.consume([{"k": "speech", "speaker": "edda", "expression": expression, "text": SAMPLE}])

func reset_clock() -> void:
	player.reset_clock()
	still_player.reset_clock()
	conversation.ink_player.reset_clock()
	_sync_legacy()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	player.advance(delta, compare.visible)
	_sync_legacy()
	if reading.visible:
		conversation._process(delta)
	var active = conversation.ink_player if reading.visible else player
	var treatment = "historical reconstruction; face protection not applied" if legacy and not reading.visible else "original face and silhouette retained"
	status.text = "Step %d · %.1f redraws/s · %s" % [active.step_index, active.settings.rate, treatment]

func _close() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://ui/dialogue_lab.tscn")
	else:
		hide()
