## Editorial fixtures only. Nothing here selects disclosures or registers live voices.
extends RefCounted

static func read() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://tools/dialogue_voice_sketches.json"))
	if not parsed is Dictionary:
		push_error("Cannot read dialogue voice sketches")
		return {}
	return parsed
