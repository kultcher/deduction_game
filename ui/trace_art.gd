## Trace artwork lookup. Location traces (two-place tokens and three-place scents) map to
## baked icons in assets/art/trace_icons/ (tools/make_trace_icons.py); quarter, connection
## and street-material traces have no art yet and return null, so callers fall back to text.
extends RefCounted

const ROOT = "res://assets/art/trace_icons/%s/%s.png"

static var _cache: Dictionary = {}


## "large" (768 px, the dialogue window) or "small" (128 px, cards and tooltips).
static func icon(trace: Dictionary, size: String = "small") -> Texture2D:
	var key: String = icon_key(trace)
	if key == "":
		return null
	var path: String = ROOT % [size, key]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## Works on a scene trace, a trace board card, or a Trace Solver cell (anything with
## `locs`, or a `trace_key` like "locations:bakery:mill").
static func icon_key(trace: Dictionary) -> String:
	var locs: Array = trace.get("locs", [])
	if locs.is_empty():
		var tkey: String = str(trace.get("trace_key", ""))
		if not tkey.begins_with("locations:"):
			return ""
		locs = Array(tkey.trim_prefix("locations:").split(":"))
	if locs.size() < 2 or locs.size() > 3:
		return ""
	var sorted_locs: Array = locs.map(func(l): return str(l))
	sorted_locs.sort()
	return "_".join(PackedStringArray(sorted_locs))
