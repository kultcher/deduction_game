## Explicit, presentation-only registrations. Nothing here reads a case or NPC state.
## A missing expression deliberately falls back to the original, unmodified portrait.
extends RefCounted

const ENTRIES = {
	"edda": {
		"neutral": {
			"source": "res://assets/art/cast_expressions/edda/neutral-v1.png",
			"lines": "res://assets/art/line_boil_poc/edda/neutral-lines-%s.png",
			# Centre and radii in portrait UVs. The feathered ellipse protects the
			# whole face, including the mouth and eyes, without moving the base art.
			"face": Vector4(0.465, 0.245, 0.225, 0.175),
			"seed": 27.0,
		},
	},
}

static func entry(id: String, expression: String) -> Dictionary:
	return ENTRIES.get(id, {}).get(expression, {})

static func for_texture(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	for cast in ENTRIES.values():
		for data in cast.values():
			if data.source == texture.resource_path:
				return data
	return {}
