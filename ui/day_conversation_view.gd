## Daytime conversation presentation, layered over the live map.
extends Control

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const Formatter = preload("res://ui/text_formatter.gd")
const Renderer = preload("res://ui/rich_text_renderer.gd")
const FormattedLabel = preload("res://ui/formatted_text_label.gd")
const LARGE = {
	"agnes": preload("res://assets/art/portraits_vn_poc/agnes-vn-poc-v1.png"),
	"bart": preload("res://assets/art/portraits_vn_poc/bartholomew-vn-poc-v1.png"),
	"constance": preload("res://assets/art/portraits_vn_poc/constance-vn-poc-v1.png"),
	"dorian": preload("res://assets/art/portraits_vn_cast/dorian-vn-v1.png"),
	"edda": preload("res://assets/art/portraits_vn_cast/edda-vn-v1.png"),
	"fenwick": preload("res://assets/art/portraits_vn_cast/fenwick-vn-v1.png"),
	"greta": preload("res://assets/art/portraits_vn_cast/greta-vn-v1.png"),
	"hollis": preload("res://assets/art/portraits_vn_cast/hollis-vn-v1.png"),
	"isolde": preload("res://assets/art/portraits_vn_cast/isolde-vn-v1.png"),
	"jory": preload("res://assets/art/portraits_vn_cast/jory-vn-v1.png"),
	"kiran": preload("res://assets/art/portraits_vn_cast/kiran-vn-v1.png"),
	"lian": preload("res://assets/art/portraits_vn_cast/lian-vn-v1.png"),
	"merrin": preload("res://assets/art/portraits_vn_cast/merrin-vn-v1.png"),
	"nisha": preload("res://assets/art/portraits_vn_cast/nisha-vn-v1.png"),
	"odette": preload("res://assets/art/portraits_vn_cast/odette-vn-v1.png"),
}

var formatter = Formatter.new()
var renderer = Renderer.new()
var portrait: TextureRect
var speaker: Label
var speech: RichTextLabel
var controls: HFlowContainer
var person_id = ""
var lines: Array = []

func _ready() -> void:
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
	content.add_child(speech)
	var control_scroll = ScrollContainer.new()
	control_scroll.anchor_left = 0.47
	control_scroll.anchor_top = 0.71
	control_scroll.anchor_right = 0.98
	control_scroll.anchor_bottom = 0.99
	control_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(control_scroll)
	controls = HFlowContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("h_separation", 6)
	controls.add_theme_constant_override("v_separation", 5)
	control_scroll.add_child(controls)

func begin(id: String, name: String) -> void:
	person_id = id
	lines.clear()
	portrait.texture = LARGE.get(id, UITheme.tex("art/portraits/" + id))
	speaker.text = name
	speaker.add_theme_color_override("font_color", UITheme.ink_of(C.npc_color(id)))
	_render()

func consume(events: Array) -> void:
	var spoken: Array = []
	for event in events:
		if event.get("k") == "speech" and event.get("speaker") == person_id:
			spoken.append(str(event.get("text", "")))
	if not spoken.is_empty():
		lines = spoken
		_render()

func _render() -> void:
	speech.clear()
	var text = "\n\n".join(PackedStringArray(lines)) if not lines.is_empty() else "Choose a question to begin."
	renderer.append_to(speech, formatter.format_text(text, {
		"surface": "paper", "speaker_id": person_id, "font_size": 20, "icon_size": 20}))
