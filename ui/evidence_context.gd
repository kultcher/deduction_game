## Presentation of the live adapter's existing context/location classification.
## Ward/sigil are explicitly context pending Claude's adapter (batch 3). No evaluator runs here.
extends RefCounted
const Live = preload("res://game/workshop_canvas.gd")
const EXPLANATION = "Context: background or location information. This card cannot establish guilt on its own."

static func is_context(adapter: Dictionary) -> bool:
	return adapter.get("kind", "") in ["context", "location", "ward", "scorched_sigil"]

## Once per library refresh, never once per card or draw frame.
static func numbers(g) -> Dictionary:
	var originals = {}
	for card in g.board:
		if card.get("kind", "") != "deduction" and not card.get("deleted", false):
			originals[Live.Evidence.normalize_card(card).id] = card.n
	var result = {}
	for adapter in Live.view(g).cards:
		if is_context(adapter) and originals.has(adapter.id):
			result[originals[adapter.id]] = true
	return result

static func draw_border(canvas: CanvasItem, rect: Rect2, color: Color, width: float = 1.2) -> void:
	var r = rect.grow(-1.0)
	var corners = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		canvas.draw_dashed_line(corners[i], corners[(i + 1) % 4], color, width, 5.0)

static func draw_tag(canvas: CanvasItem, rect: Rect2, font: Font, ink: Color, scale: float = 1.0) -> void:
	var fs = clampi(roundi(10 * scale), 1, 14)
	var size = font.get_string_size("context", HORIZONTAL_ALIGNMENT_LEFT, -1, fs) + Vector2(4, 2)
	if size.x > rect.size.x - 2:
		fs = maxi(1, floori(fs * maxf(rect.size.x - 2, 1) / size.x))
		size = font.get_string_size("context", HORIZONTAL_ALIGNMENT_LEFT, -1, fs) + Vector2(4, 2)
	var tag = Rect2(rect.end - size - Vector2(1, 1), size)
	canvas.draw_rect(tag, Color("e8dfc8"))
	canvas.draw_string(font, tag.position + Vector2(2, size.y - 3), "context", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
