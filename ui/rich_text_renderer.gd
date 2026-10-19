## Styled spans -> native RichTextLabel operations. Append-only; balances only its own
## pushes so callers can wrap a passage in an existing card link, bold or italic style.
extends RefCounted

var _textures: Dictionary = {}

func append_to(label: RichTextLabel, spans: Array) -> void:
	for span in spans:
		label.push_font_size(span["font_size"])
		if span.get("bold", false):
			label.push_bold()
		var hint: String = span["tooltip"]
		if not hint.is_empty():
			label.push_hint(hint)
		var texture = _texture(span["icon_path"])
		if texture != null:
			var height: int = span["icon_size"]
			var width = maxi(1, roundi(height * float(texture.get_width()) / texture.get_height()))
			label.add_image(texture, width, height, icon_color(span), INLINE_ALIGNMENT_CENTER, Rect2(), null, false, hint)
			label.add_text("\u00a0")
		label.push_color(text_color(span))
		label.add_text(span["text"]) # add_text treats brackets and BBCode-looking input literally.
		label.pop()
		if not hint.is_empty():
			label.pop()
		if span.get("bold", false):
			label.pop()
		label.pop()

## The same opacity rule can be used by the later custom board/list renderers.
static func text_color(span: Dictionary) -> Color:
	var color: Color = span["color"]
	color.a *= span["opacity"]
	return color

static func icon_color(span: Dictionary) -> Color:
	return Color(1, 1, 1, span["opacity"])

func _texture(path: String):
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	return _textures[path]
