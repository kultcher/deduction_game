## Nonmodal presentation only. Settings overrides: [headline.dawn], size=44,
## colour=Color(1, .8, .3, 1), duration=5.0 (and the same keys for every kind).
extends Control
const DEFAULT_STYLES = {
	"dawn": {"size": 44, "colour": Color("e9bc55"), "duration": 5.0},
	"nightfall": {"size": 44, "colour": Color("8dbaf1"), "duration": 5.0},
	"phase": {"size": 26, "colour": Color("e9bc55"), "duration": 3.0},
	"death": {"size": 36, "colour": Color("ec7373"), "duration": 5.0},
	"quiet": {"size": 36, "colour": Color("91cfa4"), "duration": 5.0},
	"nomination": {"size": 32, "colour": Color("eeb55d"), "duration": 5.0},
	"block": {"size": 32, "colour": Color("eeb55d"), "duration": 5.0},
	"execution": {"size": 40, "colour": Color("e65065"), "duration": 5.0},
	"martyr": {"size": 40, "colour": Color("e9bc55"), "duration": 5.0},
	"curse": {"size": 40, "colour": Color("c493eb"), "duration": 5.0},
	"totem": {"size": 36, "colour": Color("91cfa4"), "duration": 5.0},
	"ward": {"size": 36, "colour": Color("91cfa4"), "duration": 5.0},
	"ending": {"size": 44, "colour": Color("e9bc55"), "duration": 7.0}}
var styles: Dictionary = DEFAULT_STYLES.duplicate(true)
var pending: Array = []
var current: Dictionary = {}
var remaining = 0.0
var title: Label
var subtitle: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_styles()
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.offset_left = 35
	box.offset_right = -35
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	title = Label.new()
	subtitle = Label.new()
	for label in [title, subtitle]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		box.add_child(label)
	subtitle.add_theme_font_size_override("font_size", 22)
	visible = false

func load_styles(path: String = "user://settings.cfg") -> void:
	styles = DEFAULT_STYLES.duplicate(true)
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for kind in styles:
		var section: String = "headline." + kind
		var font_size = cfg.get_value(section, "size", styles[kind].size)
		var seconds = cfg.get_value(section, "duration", styles[kind].duration)
		var colour = cfg.get_value(section, "colour", styles[kind].colour)
		if font_size is int or font_size is float:
			styles[kind].size = clampi(int(font_size), 8, 100)
		if seconds is int or seconds is float:
			styles[kind].duration = clampf(float(seconds), 0.05, 60.0)
		if colour is Color:
			styles[kind].colour = colour
		elif colour is String:
			styles[kind].colour = Color.from_string(colour, styles[kind].colour)

func enqueue(event: Dictionary) -> void:
	pending.append(event.duplicate(true))
	if current.is_empty():
		skip()

func clear() -> void:
	pending.clear()
	current = {}
	remaining = 0.0
	visible = false

func skip() -> void:
	if pending.is_empty():
		clear()
		return
	current = pending.pop_front()
	var style: Dictionary = styles.get(current.get("kind", "phase"), styles.phase)
	remaining = style.duration
	title.text = current.text
	title.add_theme_font_size_override("font_size", style.size)
	title.add_theme_color_override("font_color", style.colour)
	subtitle.text = current.get("subtitle", "")
	subtitle.visible = not subtitle.text.is_empty()
	subtitle.add_theme_color_override("font_color", style.colour)
	visible = true

func _process(delta: float) -> void:
	if current.is_empty():
		return
	var duration: float = styles.get(current.get("kind", "phase"), styles.phase).duration
	# Keep the queue moving, but give a default notice at least three real seconds.
	# Shorter explicit settings overrides remain shorter.
	var speed = minf(2.0, maxf(1.0, duration / 3.0)) if pending.size() > 2 else 1.0
	remaining -= delta * speed
	if remaining <= 0.0:
		skip()

func _input(event: InputEvent) -> void:
	if not current.is_empty() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip() # Never accept the event: its ordinary target still receives the click.
