## The UI's skin in one place: colours, fonts and the frames of panels, popups and buttons.
## With no art in res://assets/ui the game keeps its current flat look; drop textures in and
## they take over without touching layout code.
##
## Art (all optional, PNG, drawn as nine-slice: corners stay fixed, edges and centre stretch):
##   assets/ui/panel.png          large panels (case view background, side panels)
##   assets/ui/popup.png          popup menus and pickers
##   assets/ui/frame.png          framed boxes (profile, notes, board cards)
##   assets/ui/button.png         buttons: normal
##   assets/ui/button_hover.png   buttons: hovered
##   assets/ui/button_pressed.png buttons: pressed
##   assets/ui/field.png          text fields
##   assets/ui/slices.json        optional: {"panel": [left, top, right, bottom], ...} slice
##                                margins in pixels (default 12 on every side)
extends RefCounted

const DIR = "res://assets/ui/"

## Colour tokens. Character colours stay in content.gd (C.npc_color).
const COLORS = {
	"bg": Color(0.07, 0.07, 0.08),
	"panel": Color(0.06, 0.06, 0.08, 0.98),
	"popup": Color(0.1, 0.1, 0.13),
	"border": Color(0.45, 0.42, 0.35),
	"accent": Color(0.95, 0.88, 0.6),      # headings, active filters
	"text": Color(0.9, 0.9, 0.9),
	"muted": Color(0.65, 0.65, 0.7),
	"heard": Color(0.72, 0.72, 0.78),      # cards someone told you
	"deduction": Color(0.95, 0.8, 0.45),
	"hidden": Color(0.45, 0.45, 0.5),
}

static func color(name: String) -> Color:
	return COLORS.get(name, Color.WHITE)

static var _slices = null

static func _slice(name: String) -> Array:
	if _slices == null:
		_slices = {}
		var path = DIR + "slices.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_slices = parsed
	var m = _slices.get(name, [12, 12, 12, 12])
	return m if m is Array and m.size() == 4 else [12, 12, 12, 12]

## The art for a slot, as a nine-slice style box, or null if there's no art for it.
static func textured(name: String):
	var path = DIR + name + ".png"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var tex = load(path) if ResourceLoader.exists(path) else null
	if tex == null:
		# Not imported yet (e.g. a headless run): read the PNG directly.
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null or img.is_empty():
			return null
		tex = ImageTexture.create_from_image(img)
	var m: Array = _slice(name)
	var sb = StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.set_content_margin_all(maxf(8.0, float(m[0])))
	return sb

## A panel style: the art if present, else the current flat look.
static func panel(name: String = "panel") -> StyleBox:
	var t = textured(name)
	if t != null:
		return t
	var sb = StyleBoxFlat.new()
	match name:
		"popup":
			sb.bg_color = color("popup")
			sb.border_color = color("border")
			sb.set_border_width_all(1)
			sb.set_content_margin_all(10)
		"frame":
			sb.bg_color = Color(0.09, 0.09, 0.11)
			sb.border_color = color("border")
			sb.set_border_width_all(1)
			sb.set_content_margin_all(8)
		_:
			sb.bg_color = color("panel")
			sb.set_content_margin_all(10)
	return sb

## The Theme set on the root of each screen. Only slots with art are overridden, so without
## art Godot's default controls look exactly as before.
static func make(font: Font = null) -> Theme:
	var th = Theme.new()
	if font != null:
		th.set_font("font", "CodeFont", font)
	var pairs = {"button": "normal", "button_hover": "hover", "button_pressed": "pressed"}
	for art in pairs:
		var sb = textured(art)
		if sb != null:
			for type in ["Button", "OptionButton", "MenuButton", "CheckBox"]:
				th.set_stylebox(pairs[art], type, sb)
				if art == "button_pressed":
					th.set_stylebox("focus", type, StyleBoxEmpty.new())
	var fld = textured("field")
	if fld != null:
		th.set_stylebox("normal", "LineEdit", fld)
		th.set_stylebox("normal", "TextEdit", fld)
	var pop = textured("popup")
	if pop != null:
		th.set_stylebox("panel", "PopupPanel", pop)
		th.set_stylebox("panel", "PopupMenu", pop)
	var pan = textured("panel")
	if pan != null:
		th.set_stylebox("panel", "PanelContainer", pan)
	return th
