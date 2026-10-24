## Versioned transport contract. No World/NPC access and no belief mutations.
## A future interpreter can consume the same receipts without using Workshop fixtures.
extends RefCounted

const FORMAT = "demonologist-live-evidence-1"
const REPORT_FIELDS = {
	"surveyor": ["count"], "dowser": ["group", "count", "block"],
	"hearthwitch": ["nbrs", "count"], "rumormonger": ["pair", "secret"],
	"nightwatch": ["block", "seen"], "lamplighter": ["count"],
	"seer": ["pair", "yes"], "archivist": ["pair", "role"], "clerk": ["pair", "role"],
	"gravedigger": ["executed", "role"], "psychologist": ["subject", "trusts", "suspects"],
	"veteran": ["attacked", "block"], "martyr": ["target", "chosen", "evil"],
	"sexton": ["night"],
}
const FIELDS = ["block", "loc", "locs", "home", "night", "role", "secret_kind", "fear", "withheld", "package", "roles", "duty_claim", "duty", "vigil", "dropped",
	"nominee", "by", "yes", "no", "player_yes", "count", "threshold", "outcome", "alive_before", "owner", "material", "crime_night", "scene", "scene_block", "victim", "ward", "guard_claim", "watch_claim"]
const KINDS = ["home", "haunt", "info", "claim", "sighting", "conversation", "vigil", "alibi",
	"trace", "dropped", "totem", "death", "execution", "quiet", "vote", "martyr", "curse",
	"curse_lifted", "silenced", "knell", "secret", "hint", "refusal", "opinion", "accusation", "case"]

## Raw public cards, including bounded Medium retellings. Hearing an opinion
## through a gift does not turn it into independent evidence of alignment.
static func contains_opinion(card: Dictionary, depth: int = 0) -> bool:
	if card.get("kind", "info") in ["opinion", "accusation"]:
		return true
	if depth >= 64 or card.get("role", "") != "medium":
		return false
	var data = card.get("data", {})
	if not data is Dictionary or not data.get("item", {}) is Dictionary:
		return false
	var item: Dictionary = data.get("item", {})
	return item.get("type", "") == "suspicion" or (item.get("type", "") == "reading" and item.get("entry") is Dictionary and contains_opinion(item.entry, depth + 1))

static func social_reading(card: Dictionary, depth: int = 0) -> bool:
	if card.get("role", "") == "psychologist":
		return true
	if depth >= 64 or card.get("role", "") != "medium":
		return false
	var data = card.get("data", {})
	if not data is Dictionary or not data.get("item", {}) is Dictionary:
		return false
	var item: Dictionary = data.get("item", {})
	return item.get("type", "") == "reading" and item.get("entry") is Dictionary and social_reading(item.entry, depth + 1)

static func normalize(input: Dictionary) -> Dictionary:
	var result = {"format": FORMAT, "case_id": input.case_id, "now": stamp(input.now),
		"rules": input.rules.duplicate(true), "people": input.people.duplicate(true),
		"venue": input.venue, "evidence": [], "selected": [], "board_map": {},
		"private_evidence": [], "public_events": input.public_events.duplicate(true),
		"arguments": [], "root": input.get("root", 0), "listener": input.get("listener", {}).duplicate(true),
		"issues": input.get("issues", []).duplicate(true), "assessment_ready": false}
	var by_id = {}
	for receipt in input.get("receipts", []):
		var card = normalize_card(receipt.card)
		var id: String = card.id
		if not by_id.has(id):
			by_id[id] = card
			result.evidence.append(card)
		if card.provenance not in by_id[id].provenance_paths:
			by_id[id].provenance_paths.append(card.provenance.duplicate(true))
		for disclosure in receipt.card.get("learned", []):
			var learned = {"at": stamp(disclosure), "via": disclosure.get("via", ""), "public": disclosure.get("public", false)}
			if learned not in by_id[id].disclosures:
				by_id[id].disclosures.append(learned)
		if by_id[id].learned_at == null and card.learned_at != null:
			by_id[id].learned_at = card.learned_at
		if by_id[id].reported_at == null and card.reported_at != null:
			by_id[id].reported_at = card.reported_at
		var number: int = receipt.card.get("n", 0)
		if receipt.get("private", false):
			if id not in result.private_evidence:
				result.private_evidence.append(id)
		else:
			result.board_map[str(number)] = id
			if number in input.get("selected", []) and id not in result.selected:
				result.selected.append(id)
		for issue in card.issues:
			_issue(result.issues, issue, id)
	for argument in input.get("arguments", []):
		result.arguments.append(argument.duplicate(true))
	# These are capability declarations, not guesses about this world's hidden state.
	_issue(result.issues, "modifier_alternatives", "", "Live setup permits Marked, Delusional, Lovers or Sleepwalker; the fixture solver assumes one Marked.")
	if result.public_events.any(func(e): return e.kind in ["curse", "curse_lifted", "execution"]):
		_issue(result.issues, "live_chronology", "", "Live event histories need an adapter; fixed fixture chronology is not sufficient.")
	if result.evidence.any(func(c): return c.kind in ["trace", "dropped", "vigil", "sighting", "alibi"]):
		_issue(result.issues, "live_movement", "", "Fixture activity priors and eligible routes have not been derived for this live case.")
	return result

static func normalize_card(card: Dictionary) -> Dictionary:
	var kind: String = card.get("kind", "unknown")
	var observed = stamp(card.get("when", {"day": card.get("day", -1), "phase": card.get("phase", 3 if kind == "info" else -1)}))
	var content = {"kind": kind, "source": card.get("source", ""),
		"subjects": card.get("subject", []).duplicate(), "observed_at": observed}
	if kind == "info" and card.get("anonymous", false):
		content.source = ""
		content["anonymous"] = true
		content["teller"] = card.get("via", "")
	if kind == "martyr" and content.subjects.size() == 2:
		# Public subject order is actor, saved. Preserve those roles before the
		# generic person set is sorted for stable receipt identity.
		content["martyr"] = card.get("martyr", content.subjects[0])
		content["saved"] = card.get("saved", content.subjects[1])
	content.subjects.sort()
	for field in FIELDS:
		if card.has(field):
			content[field] = card[field].duplicate(true) if card[field] is Array or card[field] is Dictionary else card[field]
	var issues: Array = []
	if kind == "info":
		content["data"] = report_data(card.get("role", ""), card.get("data", {}))
		# The reading's payload identifies its subjects, regardless of whether it was
		# collected from a board card or the listener's private reading log.
		content.subjects = []
		for field in ["pair", "group", "nbrs", "seen"]:
			for person in content.data.get(field, []):
				if person not in content.subjects:
					content.subjects.append(person)
		for field in ["executed", "subject", "trusts", "suspects", "target"]:
			if content.data.has(field) and content.data[field] not in content.subjects:
				content.subjects.append(content.data[field])
		content.subjects.sort()
		if card.get("role", "") not in REPORT_FIELDS and card.get("role") != "medium":
			issues.append("report_semantics_unsupported")
		issues.append("original_report_time_unknown")
	if kind not in KINDS:
		issues.append("evidence_kind_unsupported")
	if kind not in ["info", "claim", "sighting", "alibi", "conversation", "home", "dropped", "martyr"] or "report_semantics_unsupported" in issues:
		# Several legacy cards carry semantics only in their visible text. Retain that
		# receipt; do not invent a structured interpretation or merge distinct scenes.
		content["statement"] = card.get("text", "")
		issues.append("structured_payload_incomplete")
	if observed.phase == "unknown" or observed.day < 0:
		issues.append("observation_time_unknown")
	var id = "fact:" + JSON.stringify(canonical(content)).sha256_text()
	var incidents: Array = []
	if observed.phase == "night":
		for person in content.subjects:
			if kind in ["sighting", "alibi"]:
				incidents.append("outing:%s:%d" % [person, observed.day])
		if kind == "info" and card.get("role") == "nightwatch":
			for person in content.data.get("seen", []):
				incidents.append("outing:%s:%d" % [person, observed.day])
	var result = {"id": id, "kind": kind, "source": content.source, "subjects": content.subjects,
		"observed_at": observed, "reported_at": null, "learned_at": null, "disclosures": [],
		"fact_id": id, "incident_ids": incidents, "content": content, "issues": issues, "provenance_paths": [],
		"text": card.get("text", ""), "provenance": {"original_source": content.source,
			"via": card.get("via", content.source), "origin_certainty": "legacy_receipt"}}
	if content.get("anonymous", false):
		result.provenance.origin_certainty = "anonymous"
	if not card.get("learned", []).is_empty():
		result.learned_at = stamp(card.learned[0])
	# A non-relayed statement's first receipt is its first witnessed report. Relay time
	# cannot stand in for the original speaker's report time.
	if card.get("via", content.source) == content.source and result.learned_at != null:
		result.reported_at = result.learned_at.duplicate(true)
	return result

## Canonical ledger key for an original reading, independently of hearing paths.
static func reading_key(receipt: Dictionary) -> String:
	return "info:%s:%d:%s:%s" % [receipt.source, receipt.observed_at.day, receipt.content.role, receipt.id.trim_prefix("fact:")]

static func report_data(role: String, data: Dictionary) -> Dictionary:
	var result = {}
	if role == "medium":
		result["dead"] = data.get("dead", "")
		var item: Dictionary = data.get("item", {}) if data.get("item") is Dictionary else {}
		result["item"] = {"type": item.get("type", "")}
		for field in ["who", "block", "night", "about"]:
			if item.has(field):
				result.item[field] = item[field]
		if item.get("type") == "reading" and item.get("entry") is Dictionary:
			var entry: Dictionary = item.entry
			var nested_role: String = entry.get("role", "")
			# Nested Medium chains require a bounded transmission-chain adapter.
			if nested_role != "medium":
				result.item["entry"] = {"role": nested_role, "day": entry.get("day", -1),
					"data": report_data(nested_role, entry.get("data", {})), "text": entry.get("text", "")}
				if entry.has("phase"):
					result.item.entry["phase"] = entry.phase
		return result
	for key in REPORT_FIELDS.get(role, []):
		if data.has(key):
			result[key] = data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key]
			if key in ["pair", "group", "nbrs", "seen"]:
				result[key].sort()
	return result

static func stamp(value: Dictionary) -> Dictionary:
	var phase = value.get("phase", -1)
	return {"day": int(value.get("day", -1)), "phase": ["morning", "afternoon", "evening", "night"][phase] if phase is int and phase >= 0 and phase < 4 else "unknown"}

static func canonical(value):
	if value is Dictionary:
		var result = {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = canonical(value[key])
		return result
	if value is Array:
		return value.map(func(item): return canonical(item))
	return value

static func _issue(issues: Array, code: String, fact: String = "", detail: String = "") -> void:
	var item = {"code": code, "fact": fact, "detail": detail}
	if item not in issues:
		issues.append(item)
