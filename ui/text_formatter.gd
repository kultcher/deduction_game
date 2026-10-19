## Plain text -> styled spans. No world state, markup parsing, layout or UI mutation.
extends RefCounted

const Terms = preload("res://ui/text_terms.gd")
const UITheme = preload("res://ui/theme.gd")

var terms

func _init(registry = null) -> void:
	terms = registry if registry != null else Terms.new()

## Context: speaker_id, surface (dark/paper), base_color, font_size, icon_size,
## opacity, icons, tooltips; enabled/kinds/role_context pass through to the registry.
## Color alpha is retained here; overall opacity is applied once by the renderer.
func format_text(text: String, context: Dictionary = {}) -> Array:
	if text.is_empty():
		return []
	var paper: bool = context.get("surface", "dark") == "paper"
	var base: Color = context.get("base_color", UITheme.color("ink" if paper else "text"))
	var speaker: Dictionary = terms.lookup("person:" + context.get("speaker_id", ""))
	if speaker.get("color") is Color:
		base = _readable(speaker["color"], paper)
	var style = {"color": base, "opacity": clampf(context.get("opacity", 1.0), 0.0, 1.0),
		"font_size": maxi(1, int(context.get("font_size", 16))),
		"icon_size": maxi(1, int(context.get("icon_size", context.get("font_size", 16))))}
	var result: Array = []
	var cursor = 0
	for hit in terms.find_matches(text, context):
		if hit["start"] > cursor:
			result.append(_span(text.substr(cursor, hit["start"] - cursor), cursor, style))
		var span = _span(hit["text"], hit["start"], style)
		var term: Dictionary = terms.lookup(hit["id"])
		span["entity_id"] = hit["id"]
		if term.get("color") is Color:
			span["color"] = _readable(term["color"], paper)
		if context.get("icons", true):
			span["icon_path"] = term.get("icon_path", "")
		if context.get("tooltips", true):
			span["tooltip"] = term.get("tooltip", "")
		result.append(span)
		cursor = hit["end"]
	if cursor < text.length():
		result.append(_span(text.substr(cursor), cursor, style))
	return result

static func _span(text: String, start: int, style: Dictionary) -> Dictionary:
	var span = style.duplicate()
	span.merge({"text": text, "start": start, "end": start + text.length(),
		"entity_id": "", "icon_path": "", "tooltip": ""})
	return span

static func _readable(color: Color, paper: bool) -> Color:
	var result = UITheme.ink_of(color) if paper else color
	result.a = color.a
	return result

## Copy/search/plain renderers use the original text, without inserted icon spacing.
static func plain_text(spans: Array) -> String:
	return "".join(PackedStringArray(spans.map(func(span): return span["text"])))
