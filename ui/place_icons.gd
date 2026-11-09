## A person's three places as you know them: their workplace (public from the start) and
## their two haunts, each an icon once you've learned it and a "?" until then. Shared by
## the cast list (small, on the name line) and the profile header (larger, with captions).
extends RefCounted

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")


static func icon(loc: String):
	return UITheme.tex("ui/workplaces/" + loc, 0.25) if loc != "" else null


## [{loc, kind: "work"|"haunt", known}] for the three slots, from what the player knows:
## the public workplace and `g.known_haunts`.
static func slots(g, n) -> Array:
	var out: Array = [{"loc": str(n.work), "kind": "work", "known": str(n.work) != ""}]
	var known: Array = g.known_haunts.get(n.id, []) if g != null else []
	for i in range(2):
		var l: String = str(known[i]) if i < known.size() else ""
		out.append({"loc": l, "kind": "haunt", "known": l != ""})
	return out


static func tooltip(g, n) -> String:
	var parts: Array = []
	for s in slots(g, n):
		if s.kind == "work":
			parts.append("Works at %s" % C.loc_name(s.loc) if s.known else "Workplace unknown")
		elif s.known:
			parts.append("Haunt: %s" % C.loc_name(s.loc))
		else:
			parts.append("Haunt: unknown (ask around, or watch where they spend free time)")
	return "\n".join(PackedStringArray(parts))


## Draws the slots left to right from `origin`, each `side` square, onto `ci` (call from
## its _draw). Unknown slots are a faint ring with a "?".
static func draw_slots(ci: CanvasItem, font: Font, origin: Vector2, side: float, gap: float, slot_list: Array, ink: Color, dim: bool = false) -> float:
	var x: float = origin.x
	for s in slot_list:
		var r := Rect2(Vector2(x, origin.y), Vector2(side, side))
		var t = icon(s.loc) if s.known else null
		if t != null:
			var ts := Vector2(t.get_width(), t.get_height())
			var k: float = minf(side / ts.x, side / ts.y)
			var sz: Vector2 = ts * k
			ci.draw_texture_rect(t, Rect2(r.get_center() - sz / 2.0, sz), false, Color(1, 1, 1, 0.55) if dim else Color.WHITE)
		else:
			var c: Vector2 = r.get_center()
			var rad: float = side * 0.42
			ci.draw_arc(c, rad, 0.0, TAU, 24, Color(ink, 0.45), maxf(1.0, side / 18.0))
			ci.draw_string(font, Vector2(r.position.x, c.y + side * 0.2), "?", HORIZONTAL_ALIGNMENT_CENTER, side, int(side * 0.6), Color(ink, 0.6))
		x += side + gap
	return x - origin.x - gap
