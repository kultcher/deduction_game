## Eligible rich-text surfaces share a bounded, wrapping paper tooltip for role hints.
extends RichTextLabel

const UITheme = preload("res://ui/theme.gd")

func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.strip_edges().is_empty():
		return null
	var tip = Label.new()
	tip.text = for_text
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = minf(480, get_viewport_rect().size.x * 0.75)
	tip.add_theme_font_override("font", UITheme.serif())
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", UITheme.color("ink"))
	return tip
