## The UI's skin in one place: palette, fonts, and the art for frames, plaques and cards.
## The look is "dark papercraft": navy boards, cream paper, gold edges, red accents.
## Art comes from assets/ui (cut from the sheets in assets/ui/source by
## tools/slice_sheets.py). Every piece is optional: missing art falls back to flat colour.
extends RefCounted

const UI = "res://assets/ui/"

## Palette. Character colours stay in content.gd (C.npc_color); on paper use ink_of().
const COLORS = {
	"bg": Color(0.09, 0.11, 0.17),          # the board behind everything (navy)
	"panel": Color(0.07, 0.09, 0.14, 0.98), # inset panels
	"panel_alt": Color(0.11, 0.14, 0.21),   # alternate rows, raised strips
	"popup": Color(0.1, 0.12, 0.19),
	"border": Color(0.78, 0.6, 0.27),       # gold edging
	"paper": Color(0.94, 0.89, 0.77),
	"paper_dim": Color(0.82, 0.76, 0.63),
	"ink": Color(0.17, 0.13, 0.09),
	"ink_soft": Color(0.38, 0.31, 0.23),
	"red": Color(0.62, 0.2, 0.17),
	"accent": Color(0.95, 0.83, 0.52),      # headings and active filters, on navy
	"text": Color(0.93, 0.89, 0.8),         # body text on navy
	"muted": Color(0.66, 0.65, 0.68),
	"heard": Color(0.76, 0.74, 0.78),       # cards someone told you
	"role_good": Color(0.25, 0.60, 0.90),   # deeper blue than Nisha; reserved for role words
	"role_evil": Color(0.94, 0.28, 0.28),   # reserved red for evil role words
	"deduction": Color(0.95, 0.8, 0.45),
	"hidden": Color(0.45, 0.45, 0.5),
	"string": Color(0.78, 0.13, 0.12),      # red string on the board
}

static func color(name: String) -> Color:
	return COLORS.get(name, Color.WHITE)

const HIDDEN_CARD_ALPHA = 0.42

static func card_color(card: Dictionary, tint: Color = Color.WHITE) -> Color:
	return tint * Color(1, 1, 1, HIDDEN_CARD_ALPHA if card.get("hidden", false) else 1.0)

## A character colour made dark enough to read on cream paper.
static func ink_of(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.1 + 0.25), 0.42)

static var _cache = {}

## A texture from assets (path relative to res://assets/, no extension), or null. Loads the
## imported resource when there is one, else the PNG directly (headless runs, fresh art).
static func tex(rel: String, scale: float = 1.0):
	var key = "%s@%.3f" % [rel, scale]
	if _cache.has(key):
		return _cache[key]
	var path = "res://assets/" + rel + ".png"
	var t = null
	if scale == 1.0 and ResourceLoader.exists(path):
		t = load(path)
	if t == null:
		var img: Image = null
		if ResourceLoader.exists(path):
			var r = load(path)
			if r is Texture2D:
				img = r.get_image()
		if img == null and FileAccess.file_exists(path):
			img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			if scale != 1.0:
				img.resize(maxi(1, int(img.get_width() * scale)), maxi(1, int(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
			t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## A nine-slice box from a piece of art, scaled so it's `height` pixels tall (0 = native),
## with corner margins given in pixels of the scaled art. Null if the art is missing.
static var _nine_cache = {}

static func nine(rel: String, height: float, margins: Array, content: Array = []):
	var ck = "%s|%s|%s|%s" % [rel, height, str(margins), str(content)]
	if _nine_cache.has(ck):
		return _nine_cache[ck]
	var sb = _make_nine(rel, height, margins, content)
	_nine_cache[ck] = sb
	return sb

static func _make_nine(rel: String, height: float, margins: Array, content: Array):
	var full = tex(rel)
	if full == null:
		return null
	var s = 1.0 if height <= 0 else height / float(full.get_height())
	var t = tex(rel, s)
	var sb = StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = margins[0]
	sb.texture_margin_top = margins[1]
	sb.texture_margin_right = margins[2]
	sb.texture_margin_bottom = margins[3]
	var cm: Array = content if not content.is_empty() else margins
	sb.content_margin_left = cm[0]
	sb.content_margin_top = cm[1]
	sb.content_margin_right = cm[2]
	sb.content_margin_bottom = cm[3]
	return sb

static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 4, margin: int = 8) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

## Panel styles by role.
static func panel(name: String = "panel") -> StyleBox:
	match name:
		"popup":
			return flat(color("popup"), color("border"), 1, 4, 10)
		"paper":
			# A framed sheet of paper (profile, notes): the ornate frame if we have it.
			var f = nine("ui/frame_wide", 200, [34, 34, 34, 34], [30, 28, 30, 28])
			return f if f != null else flat(color("paper"), color("border"), 2, 6, 14)
		"titled":
			var t = nine("ui/frame_titled", 320, [30, 46, 30, 30], [20, 42, 20, 18])
			return t if t != null else flat(color("paper"), color("border"), 2, 6, 14)
		"inset":
			return flat(color("panel"), color("border").darkened(0.35), 1, 6, 8)
		"header":
			var h = nine("ui/plaque_red", 34, [12, 10, 12, 10], [16, 4, 16, 4])
			return h if h != null else flat(color("red"), color("border"), 1, 4, 6)
		_:
			return flat(color("panel"), Color(0, 0, 0, 0), 0, 0, 10)

static var _serif: Font = null

static func serif() -> Font:
	if _serif != null:
		return _serif
	var f = SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Garamond", "Times New Roman", "DejaVu Serif", "serif"])
	_serif = f
	return f

## Native rich text needs matching bold/italic faces when its normal font is overridden.
static func font_face(font: Font, bold: bool = false, italic: bool = false) -> Font:
	if font is SystemFont:
		var face = font.duplicate() as SystemFont
		face.font_weight = 700 if bold else 400
		face.font_italic = italic
		return face
	return font

static func rich_text_fonts(label: RichTextLabel, font: Font) -> void:
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_override("bold_font", font_face(font, true))
	label.add_theme_font_override("italics_font", font_face(font, false, true))
	label.add_theme_font_override("bold_italics_font", font_face(font, true, true))

## The Theme set on the root of each screen.
static func make(mono: Font = null) -> Theme:
	var th = Theme.new()
	th.default_font = serif()
	th.default_font_size = 17
	if mono != null:
		th.set_font("font", "Tree", mono)
	var ink = color("ink")
	var text = color("text")
	# Buttons are cream paper plaques with ink lettering; pressed ones turn red.
	var normal = nine("ui/plaque_cream", 34, [11, 9, 11, 9], [14, 5, 14, 5])
	var hover = nine("ui/plaque_gold", 34, [11, 9, 11, 9], [14, 5, 14, 5])
	var pressed = nine("ui/plaque_red", 34, [11, 9, 11, 9], [14, 5, 14, 5])
	var disabled = nine("ui/plaque_grey", 34, [11, 9, 11, 9], [14, 5, 14, 5])
	if normal == null:
		normal = flat(color("paper"), color("border"), 1, 4, 6)
		hover = flat(color("paper").lightened(0.1), color("border"), 2, 4, 6)
		pressed = flat(color("red"), color("border"), 1, 4, 6)
		disabled = flat(color("paper_dim"), color("muted"), 1, 4, 6)
	for type in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", type, normal)
		th.set_stylebox("hover", type, hover)
		th.set_stylebox("pressed", type, pressed)
		th.set_stylebox("hover_pressed", type, pressed)
		th.set_stylebox("disabled", type, disabled)
		th.set_stylebox("focus", type, StyleBoxEmpty.new())
		th.set_color("font_color", type, ink)
		th.set_color("font_hover_color", type, ink)
		th.set_color("font_focus_color", type, ink)
		th.set_color("font_pressed_color", type, color("paper"))
		th.set_color("font_hover_pressed_color", type, color("paper"))
		th.set_color("font_disabled_color", type, color("ink_soft"))
		th.set_constant("h_separation", type, 6)
	# Checkboxes and plain labels sit on the navy board.
	th.set_color("font_color", "CheckBox", text)
	th.set_color("font_hover_color", "CheckBox", color("accent"))
	th.set_color("font_pressed_color", "CheckBox", color("accent"))
	th.set_color("font_hover_pressed_color", "CheckBox", color("accent"))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		th.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	th.set_color("font_color", "Label", text)
	# Text fields: cream with a gold edge.
	var field = flat(color("paper"), color("border"), 1, 3, 6)
	for type in ["LineEdit", "TextEdit"]:
		th.set_stylebox("normal", type, field)
		th.set_stylebox("focus", type, flat(color("paper"), color("accent"), 2, 3, 6))
		th.set_color("font_color", type, ink)
		th.set_color("font_placeholder_color", type, color("ink_soft"))
		th.set_color("caret_color", type, ink)
		th.set_color("selection_color", type, Color(0.78, 0.6, 0.27, 0.45))
	th.set_stylebox("normal", "SpinBox", field)
	# Popups and menus: navy with gold edging.
	th.set_stylebox("panel", "PopupPanel", panel("popup"))
	th.set_stylebox("panel", "PopupMenu", panel("popup"))
	th.set_color("font_color", "PopupMenu", text)
	th.set_color("font_hover_color", "PopupMenu", color("accent"))
	th.set_stylebox("hover", "PopupMenu", flat(color("panel_alt"), color("border"), 1, 3, 4))
	th.set_stylebox("panel", "PanelContainer", panel("panel"))
	# Lists (the card library): an inset navy well.
	th.set_stylebox("panel", "Tree", panel("inset"))
	th.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	th.set_color("font_color", "Tree", text)
	th.set_color("font_selected_color", "Tree", color("ink"))
	th.set_stylebox("selected", "Tree", flat(color("accent"), Color(0, 0, 0, 0), 0, 3, 2))
	th.set_stylebox("selected_focus", "Tree", flat(color("accent"), Color(0, 0, 0, 0), 0, 3, 2))
	th.set_color("guide_color", "Tree", Color(1, 1, 1, 0.06))
	th.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	th.set_color("default_color", "RichTextLabel", text)
	# Tooltips: a slip of paper.
	th.set_stylebox("panel", "TooltipPanel", flat(color("paper"), color("border"), 1, 3, 8))
	th.set_color("font_color", "TooltipLabel", ink)
	th.set_stylebox("grabber_area", "HSlider", flat(color("border")))
	return th
