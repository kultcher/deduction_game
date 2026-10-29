## A presentation experiment for the standalone dialogue lab.
extends Control

signal speak_requested

const PORTRAITS = {
	"agnes": preload("res://assets/art/portraits_vn_poc/agnes-vn-poc-v1.png"),
	"bart": preload("res://assets/art/portraits_vn_poc/bartholomew-vn-poc-v1.png"),
	"constance": preload("res://assets/art/portraits_vn_poc/constance-vn-poc-v1.png"),
}
const NAMES = {"agnes": "Agnes", "bart": "Bartholomew", "constance": "Constance"}
const IDS = ["agnes", "bart", "constance"]
const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")
const FormattedTextLabel = preload("res://ui/formatted_text_label.gd")
const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const EXPRESSIONS = {
	"Baseline": preload("res://assets/art/portraits_vn_poc/constance-vn-poc-v1.png"),
	"Warm": preload("res://assets/art/portrait_expression_poc/constance-warm-v1.png"),
	"Harsh": preload("res://assets/art/portrait_expression_poc/constance-harsh-v2.png"),
	"Worried": preload("res://assets/art/portrait_expression_poc/constance-worried-v1.png"),
	"Sorrowful": preload("res://assets/art/portrait_expression_poc/constance-sorrowful-v1.png"),
}
const REVEAL_PER_SECOND = 90.0
const FADE_SECONDS = 0.15

var selected = "agnes"
var results: Dictionary = {}
var formatter = Formatter.new()
var renderer = Renderer.new()
var portrait: TextureRect
var previous_portrait: TextureRect
var speaker: Label
var speech: RichTextLabel
var status: Label
var choices: OptionButton
var expression_choices: OptionButton
var fade_check: CheckBox
var portrait_tween: Tween
var reveal_position = 0.0
var reveal_total = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var background = TextureRect.new()
	background.texture = preload("res://assets/art/blocks/square.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 sum = vec4(0.0);
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * 0.003);
		}
	}
	COLOR = vec4((sum / 49.0).rgb * 0.53, 1.0);
}"""
	var material = ShaderMaterial.new()
	material.shader = shader
	background.material = material
	add_child(background)

	portrait = TextureRect.new()
	portrait.texture = PORTRAITS[selected]
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.anchor_left = 0.03
	portrait.anchor_top = 0.09
	portrait.anchor_right = 0.51
	portrait.anchor_bottom = 1.0
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	previous_portrait = TextureRect.new()
	previous_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	previous_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previous_portrait.anchor_left = portrait.anchor_left
	previous_portrait.anchor_top = portrait.anchor_top
	previous_portrait.anchor_right = portrait.anchor_right
	previous_portrait.anchor_bottom = portrait.anchor_bottom
	previous_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	previous_portrait.visible = false
	add_child(previous_portrait)

	var bubble = PanelContainer.new()
	bubble.anchor_left = 0.48
	bubble.anchor_top = 0.25
	bubble.anchor_right = 0.96
	bubble.anchor_bottom = 0.76
	var style = StyleBoxFlat.new()
	style.bg_color = Color("f3e4c2")
	style.border_color = Color("bd8748")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(26)
	bubble.add_theme_stylebox_override("panel", style)
	add_child(bubble)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	bubble.add_child(content)
	speaker = Label.new()
	speaker.add_theme_font_size_override("font_size", 32)
	speaker.add_theme_color_override("font_color", Color("743b27"))
	content.add_child(speaker)
	speech = FormattedTextLabel.new()
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.scroll_active = true
	content.add_child(speech)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("795b42"))
	content.add_child(status)

	var controls = VBoxContainer.new()
	controls.anchor_left = 0.48
	controls.anchor_top = 0.79
	controls.anchor_right = 0.96
	controls.anchor_bottom = 0.87
	controls.add_theme_constant_override("separation", 8)
	add_child(controls)
	var first_row = HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 12)
	controls.add_child(first_row)
	choices = OptionButton.new()
	for id in IDS:
		choices.add_item(NAMES[id])
	choices.item_selected.connect(_select_person)
	first_row.add_child(choices)
	expression_choices = OptionButton.new()
	for expression in EXPRESSIONS:
		expression_choices.add_item(expression)
	expression_choices.disabled = true
	expression_choices.tooltip_text = "Constance's experimental expressions"
	expression_choices.item_selected.connect(func(_index): _update_portrait())
	first_row.add_child(expression_choices)
	fade_check = CheckBox.new()
	fade_check.text = "Cross-fade"
	fade_check.button_pressed = true
	fade_check.toggled.connect(func(enabled):
		if not enabled:
			_stop_fade())
	first_row.add_child(fade_check)
	var second_row = HBoxContainer.new()
	second_row.add_theme_constant_override("separation", 12)
	controls.add_child(second_row)
	var speak = Button.new()
	speak.text = "Speak / ask again"
	speak.pressed.connect(func(): speak_requested.emit())
	second_row.add_child(speak)
	var reveal = Button.new()
	reveal.text = "Show all text"
	reveal.pressed.connect(reveal_all)
	second_row.add_child(reveal)
	var close = Button.new()
	close.text = "Back to dialogue lab"
	close.pressed.connect(hide)
	second_row.add_child(close)

func show_results(new_results: Dictionary) -> void:
	results = new_results.duplicate(true)
	_update_view()
	show()

func _update_view() -> void:
	if portrait == null:
		return
	_update_portrait()
	speaker.text = NAMES[selected]
	speaker.add_theme_color_override("font_color", UITheme.ink_of(C.npc_color(selected)))
	var result: Dictionary = results.get(selected, {})
	speech.clear()
	var spans = formatter.format_text(str(result.get("text", "")), {
		"surface": "paper", "speaker_id": selected, "font_size": 26, "icon_size": 26})
	renderer.append_to(speech, spans)
	reveal_total = speech.get_total_character_count()
	reveal_position = 0.0
	speech.visible_characters = 0
	status.text = "Dialogue lab preview · " + str(result.get("cue", ""))

func _select_person(index: int) -> void:
	selected = IDS[index]
	expression_choices.select(0)
	expression_choices.disabled = selected != "constance"
	_update_view()

func _update_portrait() -> void:
	var texture: Texture2D = PORTRAITS[selected]
	if selected == "constance":
		texture = EXPRESSIONS[expression_choices.get_item_text(expression_choices.selected)]
	if portrait.texture == texture:
		return
	_stop_fade()
	previous_portrait.texture = portrait.texture
	portrait.texture = texture
	if not visible or not fade_check.button_pressed or previous_portrait.texture == null:
		previous_portrait.hide()
		return
	previous_portrait.modulate.a = 1.0
	previous_portrait.show()
	portrait_tween = create_tween()
	portrait_tween.tween_property(previous_portrait, "modulate:a", 0.0, FADE_SECONDS)
	portrait_tween.tween_callback(previous_portrait.hide)

func _stop_fade() -> void:
	if portrait_tween != null and portrait_tween.is_valid():
		portrait_tween.kill()
	if previous_portrait != null:
		previous_portrait.hide()

func _process(delta: float) -> void:
	if visible and speech != null and speech.visible_characters >= 0 and speech.visible_characters < reveal_total:
		reveal_position = minf(float(reveal_total), reveal_position + delta * REVEAL_PER_SECOND)
		speech.visible_characters = int(reveal_position)

func reveal_all() -> void:
	reveal_position = float(reveal_total)
	speech.visible_characters = -1
