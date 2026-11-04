## Tooltip body for traces: one row per trace, its icon beside its text. Returned from a
## Control's `_make_custom_tooltip`; Godot wraps it in the usual tooltip panel.
extends RefCounted

const UITheme = preload("res://ui/theme.gd")
const TraceArt = preload("res://ui/trace_art.gd")

const ICON = 72
const TEXT_W = 380


## rows: [{trace: Dictionary (anything TraceArt.icon accepts), text: String}]
static func build(rows: Array, heading: String = "", footer: String = "") -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	if heading != "":
		box.add_child(_label(heading, 16, UITheme.color("ink"), true))
	for r in rows:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var art: Texture2D = TraceArt.icon(r.get("trace", {}))
		if art != null:
			var pic = TextureRect.new()
			pic.texture = art
			pic.custom_minimum_size = Vector2(ICON, ICON)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(pic)
		var text = _label(str(r.get("text", "")), 15, UITheme.color("ink"))
		text.custom_minimum_size.x = TEXT_W
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
		box.add_child(row)
	if footer != "":
		box.add_child(_label(footer, 13, UITheme.color("muted")))
	return box


static func _label(t: String, size: int, col: Color, bold: bool = false) -> Label:
	var l = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = TEXT_W + ICON + 10
	l.add_theme_font_override("font", UITheme.serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
