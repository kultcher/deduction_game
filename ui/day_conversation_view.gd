## Daytime conversation presentation, layered over the live map.
extends Control

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")
const FormattedLabel = preload("res://ui/formatted_text_label.gd")
const VNPortraits = preload("res://ui/vn_portraits.gd")
const EXPRESSIONS = VNPortraits.EXPRESSIONS
const FADE_SECONDS = 0.15
const PORTRAIT_FRAME = [0.01, 0.02, 0.48, 1.0]   # anchors: left, top, right, bottom
const ITEM_FRAME = [0.07, 0.12, 0.42, 0.72]      # an object sits level with the speech bubble
const REVEAL_PER_SECOND = 90.0

var formatter = Formatter.new()
var renderer = Renderer.new()
var portrait: TextureRect
var previous_portrait: TextureRect
var portrait_tween: Tween
var speaker: Label
var speech: RichTextLabel
var reveal_hint: Label
var reveal_position = 0.0
var reveal_total = 0
var controls: HFlowContainer
var action_hint: Label
var person_id = ""
var lines: Array = []

var _built: bool = false

func _ready() -> void:
	_build()

## Build the child nodes once. Public entry points call this too, so the view works even
## before it enters a running tree (headless tests, or a caller that begins it early).
func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 sum = vec3(0.0);
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			sum += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 3.0).rgb;
		}
	}
	COLOR = vec4(sum / 49.0 * 0.57, 1.0);
}"""
	var material = ShaderMaterial.new()
	material.shader = shader
	backdrop.material = material
	add_child(backdrop)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.anchor_left = 0.01
	portrait.anchor_top = 0.02
	portrait.anchor_right = 0.48
	portrait.anchor_bottom = 1.0
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	previous_portrait = TextureRect.new()
	previous_portrait.expand_mode = portrait.expand_mode
	previous_portrait.stretch_mode = portrait.stretch_mode
	previous_portrait.anchor_left = portrait.anchor_left
	previous_portrait.anchor_top = portrait.anchor_top
	previous_portrait.anchor_right = portrait.anchor_right
	previous_portrait.anchor_bottom = portrait.anchor_bottom
	previous_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	previous_portrait.hide()
	add_child(previous_portrait)
	var bubble = PanelContainer.new()
	bubble.anchor_left = 0.47
	bubble.anchor_top = 0.12
	bubble.anchor_right = 0.98
	bubble.anchor_bottom = 0.69
	var style = StyleBoxFlat.new()
	style.bg_color = Color("f3e4c2")
	style.border_color = Color("bd8748")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	bubble.add_theme_stylebox_override("panel", style)
	bubble.gui_input.connect(_on_dialogue_input)
	add_child(bubble)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	bubble.add_child(content)
	speaker = Label.new()
	speaker.add_theme_font_size_override("font_size", 24)
	content.add_child(speaker)
	speech = FormattedLabel.new()
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.scroll_active = true
	speech.gui_input.connect(_on_dialogue_input)
	content.add_child(speech)
	reveal_hint = Label.new()
	reveal_hint.text = "Click dialogue to show all"
	reveal_hint.add_theme_font_size_override("font_size", 14)
	reveal_hint.add_theme_color_override("font_color", Color("795b42"))
	reveal_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(reveal_hint)
	var control_scroll = ScrollContainer.new()
	control_scroll.anchor_left = 0.47
	control_scroll.anchor_top = 0.71
	control_scroll.anchor_right = 0.98
	control_scroll.anchor_bottom = 0.99
	control_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(control_scroll)
	var action_content = VBoxContainer.new()
	action_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control_scroll.add_child(action_content)
	action_hint = Label.new()
	action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_hint.add_theme_font_size_override("font_size", 15)
	action_hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	action_hint.hide()
	action_content.add_child(action_hint)
	controls = HFlowContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("h_separation", 6)
	controls.add_theme_constant_override("v_separation", 5)
	action_content.add_child(controls)

func set_action_hint(text: String) -> void:
	_build()
	action_hint.text = text
	action_hint.visible = not text.is_empty()

func begin(id: String, name: String) -> void:
	_build()
	person_id = id
	lines.clear()
	_stop_portrait_fade()
	_portrait_frame(PORTRAIT_FRAME)
	portrait.texture = _expression_texture(id, "neutral")
	speaker.text = name
	speaker.add_theme_color_override("font_color", UITheme.ink_of(C.npc_color(id)))
	_render()

## Item mode: an object (a crime-scene trace) where the portrait goes, with its text in the
## speech bubble. No speaker, so expressions and speech events are ignored until `begin`.
## A null texture leaves the portrait slot empty (art not drawn yet).
func show_item(title: String, texture: Texture2D, text: String) -> void:
	_build()
	person_id = ""
	_stop_portrait_fade()
	_portrait_frame(ITEM_FRAME)
	portrait.texture = texture
	speaker.text = title
	speaker.add_theme_color_override("font_color", UITheme.color("ink"))
	lines = [text]
	_render()

func _portrait_frame(frame: Array) -> void:
	for r in [portrait, previous_portrait]:
		if r == null:
			continue
		r.anchor_left = frame[0]
		r.anchor_top = frame[1]
		r.anchor_right = frame[2]
		r.anchor_bottom = frame[3]

func _expression_texture(id: String, expression: String) -> Texture2D:
	return VNPortraits.texture(id, expression)

## Presentation only: callers supply a public expression cue, not hidden game state.
func set_expression(expression: String) -> void:
	_build()
	var texture = _expression_texture(person_id, expression)
	if portrait.texture == texture:
		return
	_stop_portrait_fade()
	previous_portrait.texture = portrait.texture
	portrait.texture = texture
	if not is_visible_in_tree() or previous_portrait.texture == null:
		return
	previous_portrait.modulate.a = 1.0
	previous_portrait.show()
	portrait_tween = create_tween()
	portrait_tween.tween_property(previous_portrait, "modulate:a", 0.0, FADE_SECONDS)
	portrait_tween.tween_callback(previous_portrait.hide)

func _stop_portrait_fade() -> void:
	if portrait_tween != null and portrait_tween.is_valid():
		portrait_tween.kill()
	if previous_portrait != null:
		previous_portrait.hide()

func consume(events: Array) -> void:
	_build()
	var spoken: Array = []
	var expression = "neutral"
	var strength = 0
	for event in events:
		if event.get("k") == "speech" and event.get("speaker") == person_id:
			spoken.append(str(event.get("text", "")))
			var cue: String = event.get("expression", "")
			var cue_strength = int(event.get("expression_strength", 1))
			if cue in EXPRESSIONS and cue != "neutral" and cue_strength > 0 and cue_strength >= strength:
				expression = cue
				strength = cue_strength
	if not spoken.is_empty():
		lines = spoken
		set_expression(expression)
		_render()

func _render() -> void:
	speech.clear()
	var text = "\n\n".join(PackedStringArray(lines))
	renderer.append_to(speech, formatter.format_text(text, {
		"surface": "paper", "speaker_id": person_id, "font_size": 20, "icon_size": 20}))
	reveal_total = speech.get_total_character_count()
	reveal_position = 0.0
	if lines.is_empty():
		reveal_all()
	else:
		speech.visible_characters = 0
		reveal_hint.visible = reveal_total > 0

func _process(delta: float) -> void:
	if is_visible_in_tree() and speech != null and speech.visible_characters >= 0 and speech.visible_characters < reveal_total:
		reveal_position = minf(float(reveal_total), reveal_position + delta * REVEAL_PER_SECOND)
		speech.visible_characters = int(reveal_position)
		if speech.visible_characters >= reveal_total:
			reveal_hint.hide()

func reveal_all() -> void:
	_build()
	reveal_position = float(reveal_total)
	speech.visible_characters = -1
	reveal_hint.hide()

func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		reveal_all()
