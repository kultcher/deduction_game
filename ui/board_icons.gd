## Small engraved-style line icons. SVG keeps them crisp at each board zoom level;
## white strokes are tinted to match parchment ink or the time-of-day palette.
extends RefCounted

const C = preload("res://sim/content.gd")
const PATHS = {
	"statement": '<path d="M5 4h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H9l-5 4v-4H3a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M6 9h10M6 13h7"/>',
	"reading": '<path d="M1 12Q12-1 23 12Q12 25 1 12Z"/><circle cx="12" cy="12" r="3.5"/>',
	"accusation": '<path d="M5 4h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H9l-5 4v-4H3a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M12 7v5"/><circle cx="12" cy="15" r=".8" fill="white" stroke="none"/>',
	"sunrise": '<path d="M2 18h20M5 15a7 7 0 0 1 14 0M2 11l2 1M22 11l-2 1M5 5l2 2M19 5l-2 2M12 1v8M9 4l3-3 3 3M4 21h16"/>',
	"sunset": '<path d="M2 18h20M5 15a7 7 0 0 1 14 0M2 11l2 1M22 11l-2 1M5 5l2 2M19 5l-2 2M12 1v8M9 6l3 3 3-3M4 21h16"/>',
}
static var _textures: Dictionary = {}

static func texture(kind: String):
	if not PATHS.has(kind):
		return null
	if not _textures.has(kind):
		var img = Image.new()
		var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><g fill="none" stroke="white" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + PATHS[kind] + '</g></svg>'
		if img.load_svg_from_string(svg) != OK:
			return null
		_textures[kind] = ImageTexture.create_from_image(img)
	return _textures[kind]

static func kind_for(card: Dictionary) -> String:
	match card.get("kind", ""):
		"info":
			return "reading"
		"accusation":
			return "accusation"
		"home", "haunt", "claim", "hint", "refusal", "opinion", "secret", "case":
			return "statement"
	return ""

static func phase_shade(phase: int) -> Color:
	match phase:
		C.MORNING:
			return Color(0.95, 0.78, 0.48, 0.045)
		C.AFTERNOON:
			return Color(0.85, 0.9, 1.0, 0.025)
		C.EVENING:
			return Color(0.65, 0.61, 0.8, 0.065)
	return Color(0, 0, 0, 0.3)
