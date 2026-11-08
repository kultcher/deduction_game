## The meeting's courtroom stage (meeting plan M3a, section 5.2): a VN overlay over the
## dimmed seat ring. Speakers come forward one at a time, with their portrait and
## expression, while the town meets: opening testimony, the nominator's case, the defence,
## the press, the supporters, the voters who explain themselves and the gallows' last words.
## Presentation only; it reads the speech events the game already emits.
##
## Each line reveals at REVEAL_PER_SECOND and waits for Continue (Nov 7, with Michael): a
## click on the speech finishes the line, a second click (or Continue) brings the next
## speaker on, and "Back to the circle" clears the stage. Consecutive lines from one speaker
## share a window when they fit. The "Auto-advance" toggle under the controls brings the
## next speaker on by itself after a hold (kept between sessions). `finished` fires when the
## stage empties.
##
## The log follows the stage: each entry carries the events that lead up to it, and
## `logged` fires with them as the entry comes forward (or, for entries with nothing to
## show, as soon as the stage reaches them). Clearing the stage logs what's left at once.
extends Control

signal finished
signal logged(events: Array)

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const VNPortraits = preload("res://ui/vn_portraits.gd")
const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")
const FormattedLabel = preload("res://ui/formatted_text_label.gd")

const REVEAL_PER_SECOND = 90.0
const FADE_SECONDS = 0.15
const HOLD_BASE = 2.0          # auto-advance: seconds a fully shown line stays before the next speaker
const HOLD_PER_CHAR = 0.03
const HOLD_MAX = 9.0
const MERGE_MAX = 420          # one speaker's consecutive lines share a window up to this many characters
const SETTINGS_PATH = "user://settings.cfg"

var formatter = Formatter.new()
var renderer = Renderer.new()
var portrait: TextureRect
var previous_portrait: TextureRect
var portrait_tween: Tween
var speaker_label: Label
var speech: RichTextLabel
var muted_banner: Label
var status_pill: Label
var continue_button: Button
var clear_button: Button
var auto_toggle: CheckBox

var queue: Array = []          # {speaker, name, text, expression, log}; log-only entries have speaker ""
var current: Dictionary = {}
var auto_advance: bool = false
var status_for: Callable       # speaker id -> the status pill's text
var _reveal_position: float = 0.0
var _reveal_total: int = 0
var _hold: float = 0.0
var _delay: float = 0.0        # a beat before the first speaker (the dusk arrival)
var _built: bool = false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	# The day view's blur, a little lighter and warmer: the circle stays perceptible behind.
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 sum = vec3(0.0);
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 3.0).rgb;
		}
	}
	COLOR = vec4(sum / 49.0 * 0.68 * vec3(1.06, 0.95, 0.82), 1.0);
}"""
	var material = ShaderMaterial.new()
	material.shader = shader
	backdrop.material = material
	add_child(backdrop)
	portrait = _portrait_rect()
	add_child(portrait)
	previous_portrait = _portrait_rect()
	previous_portrait.hide()
	add_child(previous_portrait)
	muted_banner = Label.new()
	muted_banner.text = "Their voice has been stolen"
	muted_banner.anchor_left = 0.05
	muted_banner.anchor_right = 0.42
	muted_banner.anchor_top = 0.86
	muted_banner.anchor_bottom = 0.93
	muted_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	muted_banner.add_theme_font_size_override("font_size", 18)
	muted_banner.add_theme_color_override("font_color", Color("f3e4c2"))
	var banner_style = StyleBoxFlat.new()
	banner_style.bg_color = Color(0.25, 0.08, 0.1, 0.85)
	banner_style.set_corner_radius_all(8)
	banner_style.set_content_margin_all(6)
	muted_banner.add_theme_stylebox_override("normal", banner_style)
	muted_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	muted_banner.hide()
	add_child(muted_banner)
	status_pill = Label.new()
	status_pill.anchor_left = 0.46
	status_pill.anchor_right = 0.98
	status_pill.anchor_top = 0.02
	status_pill.anchor_bottom = 0.12
	status_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_pill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_pill.add_theme_font_size_override("font_size", 16)
	status_pill.add_theme_color_override("font_color", Color("f3e4c2"))
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.07, 0.09, 0.14, 0.85)
	pill_style.border_color = Color("bd8748")
	pill_style.set_border_width_all(1)
	pill_style.set_corner_radius_all(14)
	pill_style.set_content_margin_all(8)
	status_pill.add_theme_stylebox_override("normal", pill_style)
	status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_pill)
	var bubble = PanelContainer.new()
	bubble.anchor_left = 0.46
	bubble.anchor_top = 0.14
	bubble.anchor_right = 0.98
	bubble.anchor_bottom = 0.68
	var style = StyleBoxFlat.new()
	style.bg_color = Color("f3e4c2")
	style.border_color = Color("bd8748")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	bubble.add_theme_stylebox_override("panel", style)
	bubble.gui_input.connect(_on_input)
	add_child(bubble)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	bubble.add_child(content)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 24)
	content.add_child(speaker_label)
	speech = FormattedLabel.new()
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.scroll_active = true
	speech.gui_input.connect(_on_input)
	content.add_child(speech)
	var controls = HFlowContainer.new()
	controls.anchor_left = 0.46
	controls.anchor_top = 0.70
	controls.anchor_right = 0.98
	controls.anchor_bottom = 0.98
	controls.add_theme_constant_override("h_separation", 6)
	add_child(controls)
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(advance)
	controls.add_child(continue_button)
	clear_button = Button.new()
	clear_button.text = "Back to the circle"
	clear_button.tooltip_text = "Skip the rest of what's being said (it's all in the log)."
	clear_button.pressed.connect(clear)
	controls.add_child(clear_button)
	auto_toggle = CheckBox.new()
	auto_toggle.text = "Auto-advance"
	auto_toggle.tooltip_text = "Bring the next speaker on by itself after a pause."
	auto_advance = _load_auto()
	auto_toggle.button_pressed = auto_advance
	auto_toggle.toggled.connect(set_auto_advance)
	controls.add_child(auto_toggle)
	gui_input.connect(_on_input)
	hide()


func _portrait_rect() -> TextureRect:
	var r = TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.anchor_left = 0.01
	r.anchor_top = 0.02
	r.anchor_right = 0.46
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Queue `events`: townsfolk speech comes forward, everything else rides along to the log.
## Returns how many speeches were queued.
func push(events: Array) -> int:
	_build()
	var added: int = 0
	var chunk: Array = []
	var last: Dictionary = {}     # the entry the next card events attach to
	for e in events:
		var k: String = str(e.get("k", ""))
		if k == "card" and not last.is_empty() and chunk.is_empty():
			last.log.append(e)
			continue
		chunk.append(e)
		last = {}
		if k != "speech":
			continue
		var id: String = str(e.get("speaker", ""))
		if id == "" or id == "player":
			continue
		var text: String = str(e.get("text", ""))
		var expr: String = str(e.get("expression", "neutral")) if int(e.get("expression_strength", 1)) > 0 else "neutral"
		var tail: Dictionary = queue.back() if not queue.is_empty() else {}
		if not tail.is_empty() and tail.speaker == id and chunk.size() == 1 and not _silent(tail.text) and not _silent(text) \
				and tail.text.length() + text.length() + 1 <= MERGE_MAX:
			tail.text += "\n" + text
			tail.expression = expr
			tail.log.append_array(chunk)
			last = tail
		else:
			last = {"speaker": id, "name": str(e.get("name", id)), "text": text, "expression": expr, "log": chunk}
			queue.append(last)
			added += 1
		chunk = []
	if not chunk.is_empty():
		queue.append({"speaker": "", "log": chunk})
	if current.is_empty():
		_drain_log()
		if not queue.is_empty() and _delay <= 0.0:
			_next()
	return added


## Events for the log only, in order with the stage.
func push_log(events: Array) -> void:
	if events.is_empty():
		return
	queue.append({"speaker": "", "log": events.duplicate()})
	if current.is_empty():
		_drain_log()


## Log-only entries at the head of the queue go out at once.
func _drain_log() -> void:
	while not queue.is_empty() and queue[0].speaker == "":
		logged.emit(queue.pop_front().log)


func _silent(text: String) -> bool:
	return text.strip_edges() in ["...", "…"]


func set_auto_advance(on: bool) -> void:
	auto_advance = on
	_hold = 0.0
	if auto_toggle != null and auto_toggle.button_pressed != on:
		auto_toggle.set_pressed_no_signal(on)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("vn", "auto_advance", on)
	cfg.save(SETTINGS_PATH)


func _load_auto() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return false
	return bool(cfg.get_value("vn", "auto_advance", false))


## Speeches still to come after the one on stage.
func waiting() -> int:
	return queue.filter(func(q): return q.speaker != "").size()


## The phase, the block and what the vote needs, top right ("" hides it).
func set_status(text: String) -> void:
	_build()
	status_pill.text = text
	status_pill.visible = text != ""


## Wait `seconds` before the first speaker comes forward (the meeting's dusk arrival).
func hold_for(seconds: float) -> void:
	_build()
	_delay = maxf(_delay, seconds)


func busy() -> bool:
	return not current.is_empty() or not queue.is_empty()


## Finish the line, or (once it's shown) bring on the next speaker.
func advance() -> void:
	if current.is_empty():
		return
	if speech.visible_characters >= 0 and speech.visible_characters < _reveal_total:
		_reveal_all()
		return
	_next()


## A new case: drop everything, logging nothing.
func reset() -> void:
	queue = []
	current = {}
	_delay = 0.0
	_hold = 0.0
	hide()


## Everything still to be said is skipped; the log gets it at once.
func clear() -> void:
	var was_busy: bool = busy()
	var rest: Array = queue
	queue = []
	_delay = 0.0
	for q in rest:
		logged.emit(q.log)
	_finish(was_busy)


func _next() -> void:
	var prev_speaker: String = str(current.get("speaker", ""))
	var was_busy: bool = not current.is_empty()
	current = {}
	_drain_log()
	if queue.is_empty():
		_finish(was_busy)
		return
	current = queue.pop_front()
	logged.emit(current.log)
	_hold = 0.0
	var id: String = current.speaker
	var silent: bool = _silent(current.text)
	var expr: String = current.expression
	if silent and expr == "neutral":
		expr = "concerned"
	_set_portrait(VNPortraits.texture(id, expr), prev_speaker != id)
	muted_banner.visible = silent
	speaker_label.text = current.name
	if status_for.is_valid():
		set_status(status_for.call(id))
	speaker_label.add_theme_color_override("font_color", UITheme.ink_of(C.npc_color(id)))
	speech.clear()
	renderer.append_to(speech, formatter.format_text(current.text, {"surface": "paper", "speaker_id": id, "font_size": 20, "icon_size": 20}))
	_reveal_total = speech.get_total_character_count()
	_reveal_position = 0.0
	speech.visible_characters = 0
	continue_button.text = "Continue" if waiting() > 0 else "Done"
	show()


func _finish(was_busy: bool) -> void:
	current = {}
	_hold = 0.0
	hide()
	if was_busy:
		finished.emit()


func _set_portrait(tex: Texture2D, new_speaker: bool) -> void:
	if portrait_tween != null and portrait_tween.is_valid():
		portrait_tween.kill()
	previous_portrait.hide()
	if portrait.texture == tex:
		return
	previous_portrait.texture = portrait.texture
	portrait.texture = tex
	if new_speaker or previous_portrait.texture == null or not is_visible_in_tree():
		return
	# Same speaker, new expression: crossfade.
	previous_portrait.modulate.a = 1.0
	previous_portrait.show()
	portrait_tween = create_tween()
	portrait_tween.tween_property(previous_portrait, "modulate:a", 0.0, FADE_SECONDS)
	portrait_tween.tween_callback(previous_portrait.hide)


func _reveal_all() -> void:
	_reveal_position = float(_reveal_total)
	speech.visible_characters = -1


func _process(delta: float) -> void:
	# Nothing moves on while the stage can't be seen (the day's last conversation still up).
	if get_parent() is CanvasItem and not get_parent().is_visible_in_tree():
		return
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0 and current.is_empty() and not queue.is_empty():
			_next()
		return
	if current.is_empty() or speech == null:
		return
	if speech.visible_characters >= 0 and speech.visible_characters < _reveal_total:
		_reveal_position = minf(float(_reveal_total), _reveal_position + delta * REVEAL_PER_SECOND)
		speech.visible_characters = int(_reveal_position)
		return
	if auto_advance:
		_hold += delta
		if _hold >= minf(HOLD_MAX, HOLD_BASE + HOLD_PER_CHAR * float(_reveal_total)):
			_next()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		accept_event()
