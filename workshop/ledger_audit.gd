## Diagnose overlapping ownership before a shared belief ledger can replace old effects.
## Coarse source/night links identify potential overlap, never permission to delete it.
extends RefCounted

static func inspect(snapshot: Dictionary) -> Dictionary:
	var readings = {}
	for card in snapshot.get("evidence", []):
		if card.kind != "info":
			continue
		var legacy_id = "info:%s:%d:%s" % [card.source, card.observed_at.day, card.content.role]
		if not readings.has(legacy_id):
			readings[legacy_id] = []
		readings[legacy_id].append(card.id)
	var result = {"reading_entries": [], "potential_arguments": [], "aliases": [],
		"safe_to_apply_additively": false,
		"note": "The old ledger can already include these reports and dependent arguments. Overlap must be replaced, not added again; coarse source/night links cannot safely identify every original contribution."}
	for id in readings:
		if readings[id].size() > 1:
			result.aliases.append({"legacy_id": id, "facts": readings[id]})
	for entry in snapshot.get("listener", {}).get("legacy_evidence", []):
		if entry.kind == "reading" and readings.has(entry.id):
			result.reading_entries.append({"legacy_id": entry.id, "facts": readings[entry.id]})
		elif entry.kind in ["arg", "tell"]:
			var supports: Array = entry.supports.duplicate()
			if not entry.rel.is_empty():
				supports.append(entry.rel)
			var matches: Array = []
			for support in supports:
				if support.size() < 2:
					continue
				if support.size() > 2 and support[2] != "reading":
					continue
				for card in snapshot.get("evidence", []):
					if card.kind == "info" and card.source == support[0] and (support[1] == -1 or card.observed_at.day == support[1]) and card.id not in matches:
						matches.append(card.id)
			if not matches.is_empty():
				result.potential_arguments.append({"legacy_id": entry.id, "facts": matches, "certainty": "coarse_dependency"})
	return result
