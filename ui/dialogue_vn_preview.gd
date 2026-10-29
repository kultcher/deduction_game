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

var selected = "agnes"
var results: Dictionary = {}
var formatter = Formatter.new()
var renderer = Renderer.new()
var portrait: TextureRect
var speaker: Label
var speech: RichTextLabel
var status: Label
var choices: OptionButton

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

	var controls = HBoxContainer.new()
	controls.anchor_left = 0.48
	controls.anchor_top = 0.79
	controls.anchor_right = 0.96
	controls.anchor_bottom = 0.87
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)
	choices = OptionButton.new()
	for id in IDS:
		choices.add_item(NAMES[id])
	choices.item_selected.connect(func(index): selected = IDS[index]; _update_view())
	controls.add_child(choices)
	var speak = Button.new()
	speak.text = "Speak / ask again"
	speak.pressed.connect(func(): speak_requested.emit())
	controls.add_child(speak)
	var close = Button.new()
	close.text = "Back to dialogue lab"
	close.pressed.connect(hide)
	controls.add_child(close)

func show_results(new_results: Dictionary) -> void:
	results = new_results.duplicate(true)
	_update_view()
	show()

func _update_view() -> void:
	if portrait == null:
		return
	portrait.texture = PORTRAITS[selected]
	speaker.text = NAMES[selected]
	speaker.add_theme_color_override("font_color", UITheme.ink_of(C.npc_color(selected)))
	var result: Dictionary = results.get(selected, {})
	speech.clear()
	var spans = formatter.format_text(str(result.get("text", "")), {
		"surface": "paper", "speaker_id": selected, "font_size": 26, "icon_size": 26})
	renderer.append_to(speech, spans)
	status.text = "Dialogue lab preview · " + str(result.get("cue", ""))
