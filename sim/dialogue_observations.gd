## Bounded presentation descriptors, constructed only AFTER disclosure is approved.
## Scene keys describe the expressed account, including fabricated accounts. No prose
## parsing, truth flags, world objects, or deductions belong at this boundary.
extends RefCounted

static func presence(source: String, subject_id: String, subject: String, place_id: String, day: int, phase: int, place: String, time: String) -> Dictionary:
	return {"kind": "report", "form": "presence", "event_id": JSON.stringify([source, subject_id, place_id, day, phase]),
		"statement": "I saw %s at %s %s." % [subject, place, time],
		"observation": {"subject_id": subject_id, "subject": subject, "place": place, "time": time,
			"scene": {"source": source, "place_id": place_id, "day": day, "phase": phase, "how": "direct", "predicate": "presence"}}}

static func valid_presence(intent: Dictionary) -> bool:
	if intent.get("kind", "") != "report" or intent.get("form", "") != "presence": return false
	if not intent.get("observation", null) is Dictionary: return false
	var o: Dictionary = intent.get("observation", {})
	if not o.get("scene", null) is Dictionary: return false
	var scene: Dictionary = o.get("scene", {})
	for key in ["subject_id", "subject", "place", "time"]:
		if not o.get(key, null) is String or o[key].is_empty(): return false
	for key in ["source", "place_id"]:
		if not scene.get(key, null) is String or scene[key].is_empty(): return false
	if not scene.get("day", null) is int or scene.day < 0: return false
	if not scene.get("phase", null) is int or scene.phase not in [0, 1, 2]: return false
	# Unsupported provenance/qualifications retain their complete approved sentence.
	if scene.size() != 6 or o.size() != 5 or scene.get("how", "") != "direct" or scene.get("predicate", "") != "presence": return false
	return intent.get("statement", "") == "I saw %s at %s %s." % [o.subject, o.place, o.time]

static func same_presence(a: Dictionary, b: Dictionary) -> bool:
	return valid_presence(a) and valid_presence(b) and a.observation.scene == b.observation.scene \
		and a.observation.place == b.observation.place and a.observation.time == b.observation.time

## Other observation predicates retain their authored slots (window, departure,
## stayed home, conversation partner, slip). Equal prose alone never merges them.
static func add(groups: Array, kind: String, scene: Dictionary, subject: String, before: String, after: String) -> void:
	var complete = scene.get("day", null) is int and scene.day >= 0 and scene.get("phase", null) is int and scene.phase in [0, 1, 2, 3]
	for key in ["source", "how", "predicate"]:
		complete = complete and scene.get(key, null) is String and not str(scene.get(key, "")).is_empty()
	complete = complete and (not str(scene.get("place_id", "")).is_empty() or not str(scene.get("block", "")).is_empty())
	for group in groups:
		if complete and group.kind == kind and group.scene == scene and group.before == before and group.after == after and subject not in group.names:
			group.names.append(subject)
			return
	groups.append({"kind": kind, "scene": scene.duplicate(true), "before": before, "after": after, "names": [subject]})

static func spoken_list(items: Array) -> String:
	if items.size() < 3: return " and ".join(PackedStringArray(items))
	return ", ".join(PackedStringArray(items.slice(0, -1))) + ", and " + items[-1]

