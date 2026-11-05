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
const EXPRESSIONS = ["neutral", "warm", "harsh", "concerned", "sorrowful"]
const CONSTANCE_EXPRESSIONS = {
	"neutral": "res://assets/art/portraits_vn_poc/constance-vn-poc-v1.png",
	"warm": "res://assets/art/portrait_expression_poc/constance-warm-v1.png",
	"harsh": "res://assets/art/portrait_expression_poc/constance-harsh-v2.png",
	"concerned": "res://assets/art/portrait_expression_poc/constance-worried-v1.png",
	"sorrowful": "res://assets/art/portrait_expression_poc/constance-sorrowful-v1.png",
}
const FADE_SECONDS = 0.15
const PORTRAIT_FRAME = [0.01, 0.02, 0.48, 1.0]   # anchors: left, top, right, bottom
const ITEM_FRAME = [0.07, 0.12, 0.42, 0.72]      # an object sits level with the speech bubble
# Line boil test (ui/line_boil.gdshader): rotoscope-style redrawn ink on these portraits,
# flaring on expression changes. Layers come from tools/make_line_boil_layers.py.
const LINE_BOIL = preload("res://ui/line_boil.gdshader")
const LINE_BOIL_IDS = ["edda"]
const LINE_BOIL_DIR = "res://assets/art/line_boil_poc/%s/%s"
const BOIL_REST = 0.3
const BOIL_FLARE = {"harsh": 1.0, "neutral": 0.45}   # others: BOIL_FLARE_DEFAULT
const BOIL_FLARE_DEFAULT = 0.65
const BOIL_DECAY_SECONDS = 1.0
static var line_boil_enabled = true
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
var boil = BOIL_REST
var current_expression = "neutral"
var boil_materials = {}   # base texture path -> ShaderMaterial
var boil_warp: NoiseTexture2D
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

func _boil_warp() -> NoiseTexture2D:
	if boil_warp == null:
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 2
		boil_warp = NoiseTexture2D.new()
		boil_warp.width = 512
		boil_warp.height = 512
		boil_warp.seamless = true
		boil_warp.noise = noise
	return boil_warp

func _boil_dir(id: String, expression: String) -> String:
	if not line_boil_enabled or id not in LINE_BOIL_IDS:
		return ""
	var dir = LINE_BOIL_DIR % [id, expression]
	return dir if ResourceLoader.exists(dir + "-base.png") else ""

func _boil_material(texture: Texture2D) -> ShaderMaterial:
	if texture == null or not texture.resource_path.ends_with("-base.png") or "line_boil_poc" not in texture.resource_path:
		return null
	var key = texture.resource_path
	if not boil_materials.has(key):
		var dir = key.trim_suffix("-base.png")
		var m = ShaderMaterial.new()
		m.shader = LINE_BOIL
		for v in ["a", "b", "c"]:
			m.set_shader_parameter("lines_" + v, load("%s-lines-%s.png" % [dir, v]))
		m.set_shader_parameter("warp_tex", _boil_warp())
		boil_materials[key] = m
	return boil_materials[key]

func _sync_portrait_materials() -> void:
	portrait.material = _boil_material(portrait.texture)
	previous_portrait.material = _boil_material(previous_portrait.texture)
	for r in [portrait, previous_portrait]:
		if r.material != null:
			r.material.set_shader_parameter("boil", boil)

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
	current_expression = "neutral"
	boil = BOIL_REST
	_sync_portrait_materials()
	if portrait.material != null:
		print("line boil on for %s (B toggles, Shift+B flares)" % id)
	elif id in LINE_BOIL_IDS:
		print("line boil: no layers found for %s at %s" % [id, LINE_BOIL_DIR % [id, "neutral"]])
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
	_sync_portrait_materials()
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
	var fallback: Texture2D = LARGE.get(id, UITheme.tex("art/portraits/" + id))
	if expression not in EXPRESSIONS:
		expression = "neutral"
	var boil_dir = _boil_dir(id, expression)
	if not boil_dir.is_empty():
		return load(boil_dir + "-base.png")
	var path: String = CONSTANCE_EXPRESSIONS.get(expression, "") if id == "constance" else "res://assets/art/cast_expressions/%s/%s-v1.png" % [id, expression]
	if ResourceLoader.exists(path):
		return load(path)
	if expression != "neutral":
		return _expression_texture(id, "neutral")
	return fallback

## Presentation only: callers supply a public expression cue, not hidden game state.
func set_expression(expression: String) -> void:
	_build()
	current_expression = expression
	var texture = _expression_texture(person_id, expression)
	if portrait.texture == texture:
		return
	_stop_portrait_fade()
	previous_portrait.texture = portrait.texture
	portrait.texture = texture
	boil = maxf(boil, BOIL_FLARE.get(expression, BOIL_FLARE_DEFAULT))
	_sync_portrait_materials()
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
	if portrait != null and portrait.material != null and boil > BOIL_REST:
		boil = BOIL_REST + (boil - BOIL_REST) * exp(-delta / BOIL_DECAY_SECONDS)
		_sync_portrait_materials()
	if is_visible_in_tree() and speech != null and speech.visible_characters >= 0 and speech.visible_characters < reveal_total:
		reveal_position = minf(float(reveal_total), reveal_position + delta * REVEAL_PER_SECOND)
		speech.visible_characters = int(reveal_position)
		if speech.visible_characters >= reveal_total:
			reveal_hint.hide()

## Line boil test, in a conversation: B flips between boiling ink and the plain portrait,
## Shift+B fires a flare (as an expression change would).
func _unhandled_key_input(event: InputEvent) -> void:
	if person_id.is_empty() or not (is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B):
		return
	if event.shift_pressed:
		boil = 1.0
		_sync_portrait_materials()
	else:
		line_boil_enabled = not line_boil_enabled
		print("line boil ", "on" if line_boil_enabled else "off")
		_stop_portrait_fade()
		portrait.texture = _expression_texture(person_id, current_expression)
		boil = BOIL_FLARE_DEFAULT
		_sync_portrait_materials()
	get_viewport().set_input_as_handled()

func reveal_all() -> void:
	_build()
	reveal_position = float(reveal_total)
	speech.visible_characters = -1
	reveal_hint.hide()

func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		reveal_all()
