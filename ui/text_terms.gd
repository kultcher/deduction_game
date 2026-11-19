## Public display terms only. Finds references in eligible PLAIN text; no BBCode or UI.
## The formatter/renderers will consume these ranges in later steps.
extends RefCounted

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const TermDefs = preload("res://ui/term_defs.gd")

## These names can also describe ordinary things or occupations. In prose, match their
## canonical capitalization only; a caller can opt into role_context for known gift text.
const AMBIGUOUS_ROLES = ["archivist", "augur", "chronicler", "clerk", "dowser", "executor", "gravedigger", "magistrate", "registrar",
	"martyr", "medium", "psychologist", "sexton", "surveyor", "veteran", "warden", "scion"]
const WORD_CHAR = "[\\p{L}\\p{N}\\p{M}_]"

var _terms: Dictionary = {}
var _patterns: Array = []

func _init(include_defaults: bool = true) -> void:
	if not include_defaults:
		return
	for person in C.CAST:
		register_term({"id": "person:" + person["id"], "kind": "person", "content_id": person["id"],
			"label": person["name"], "color": C.npc_color(person["id"]), "bold": true,
			"aliases": [person["name"]]})
	for role_id in C.ROLES:
		var role: Dictionary = C.ROLES[role_id]
		var path = "res://assets/ui/roles/%s.png" % role_id
		register_term({"id": "role:" + role_id, "kind": "role", "content_id": role_id,
			"color": UITheme.color("role_evil" if role["align"] == "evil" else "role_good"), "bold": true,
			"label": role["name"], "tooltip": role["name"] + "\n" + role["desc"],
			"icon_path": path if FileAccess.file_exists(path) else "",
			"aliases": [{"text": role["name"], "case_sensitive": role_id in AMBIGUOUS_ROLES},
				{"text": role["name"], "role_only": true}, {"text": role_id, "role_only": true}]})
	# Secrets, in violet with their icons. Their names are ordinary words too ("marked",
	# "delusional"), so prose matches only the capitalized name; role_context also takes the id.
	for secret_id in C.SECRET_MODS:
		var secret: Dictionary = C.SECRET_MODS[secret_id]
		var spath = "res://assets/ui/roles/%s.png" % secret_id
		register_term({"id": "secret:" + secret_id, "kind": "secret", "content_id": secret_id,
			"color": UITheme.color("role_secret"), "bold": true,
			"label": secret["name"], "tooltip": secret["name"] + " (secret)\n" + secret["desc"],
			"icon_path": spath if FileAccess.file_exists(spath) else "",
			"aliases": [{"text": secret["name"], "case_sensitive": true},
				{"text": secret["name"], "role_only": true}, {"text": secret_id, "role_only": true}]})

	# The mechanics (learning resources, layer 1): no colour of their own, a tooltip each.
	for term in TermDefs.MECHANICS:
		register_term({"id": "mechanic:" + term.id, "kind": "mechanic", "content_id": term.id,
			"label": term.label, "tooltip": term.tooltip, "aliases": term.aliases})

	# Mistaken: its tooltip lists the causes the case in play allows (honest_causes).
	register_term({"id": MISTAKEN_ID, "kind": "mechanic", "content_id": TermDefs.MISTAKEN.id,
		"label": TermDefs.MISTAKEN.label, "tooltip": TermDefs.mistaken_tip(causes()), "aliases": TermDefs.MISTAKEN.aliases})

const MISTAKEN_ID = "mechanic:mistaken"

## The honest-failure causes of the case in play, for the Mistaken tooltip; null (no case)
## means every cause. Static because each surface builds its own registry before any case
## starts; the UI sets it when a case starts (ui/main.gd), and the tooltip is read live.
static var honest_causes = null

static func set_honest_causes(list) -> void:
	honest_causes = list.duplicate() if list is Array else null

static func causes() -> Array:
	return honest_causes if honest_causes is Array else preload("res://workshop/reading_challenges.gd").HONEST_CAUSES

## A term's tooltip as it reads now (Mistaken's follows the case in play).
static func _tooltip_now(term: Dictionary) -> String:
	return TermDefs.mistaken_tip(causes()) if term.get("id", "") == MISTAKEN_ID else term.get("tooltip", "")

## Extend with any kind of term. Optional appearance: color (null inherits), icon_path,
## tooltip. Aliases are strings (case-insensitive) or {text, case_sensitive, role_only}.
## Reject duplicate IDs and incomplete definitions without altering the existing registry.
func register_term(definition: Dictionary) -> bool:
	for field in ["id", "kind", "label"]:
		if not definition.get(field) is String or definition[field].strip_edges() == "":
			return false
	if _terms.has(definition["id"]):
		return false
	var aliases = definition.get("aliases", [definition["label"]])
	if not aliases is Array or aliases.is_empty():
		return false
	var patterns: Array = []
	var seen = {}
	for alias in aliases:
		var rule: Dictionary = {"text": alias} if alias is String else alias if alias is Dictionary else {}
		if not rule.get("text") is String or rule["text"].strip_edges() == "":
			return false
		var literal: String = rule["text"]
		for ch in "\\.^$|?*+()[]{}":
			literal = literal.replace(ch, "\\" + ch)
		var pattern = ("" if rule.get("case_sensitive", false) else "(?i)") + "(?<!" + WORD_CHAR + ")" + literal + "(?!" + WORD_CHAR + ")"
		var key = pattern + str(rule.get("role_only", false))
		if seen.has(key):
			continue
		seen[key] = true
		var regex = RegEx.new()
		if regex.compile(pattern) != OK:
			return false
		patterns.append({"id": definition["id"], "regex": regex, "role_only": rule.get("role_only", false)})
	var term = definition.duplicate(true)
	for field in ["color", "icon_path", "tooltip", "bold"]:
		if not term.has(field):
			term[field] = null if field == "color" else false if field == "bold" else ""
	_terms[term["id"]] = term
	_patterns.append_array(patterns)
	return true

## Returns a copy, so a surface cannot accidentally change the other surfaces' terms.
func lookup(id: String) -> Dictionary:
	var term: Dictionary = _terms.get(id, {}).duplicate(true)
	if not term.is_empty():
		term["tooltip"] = _tooltip_now(term)
	return term

## Non-overlapping ranges in original String character offsets, ordered left-to-right.
## Options: enabled=false opts out; kinds limits eligible types; role_context permits
## ambiguous lowercase gift names and internal role IDs in already identified role text.
## At the same position, longest wins; equal lengths use stable ID order.
func find_matches(text: String, options: Dictionary = {}) -> Array:
	if not options.get("enabled", true) or text == "":
		return []
	var kinds: Array = options.get("kinds", [])
	var role_context: bool = options.get("role_context", false)
	var candidates: Array = []
	for entry in _patterns:
		if entry["role_only"] and not role_context:
			continue
		var term: Dictionary = _terms[entry["id"]]
		if not kinds.is_empty() and term["kind"] not in kinds:
			continue
		for m in entry["regex"].search_all(text):
			candidates.append({"start": m.get_start(), "end": m.get_end(), "text": m.get_string(),
				"id": term["id"], "kind": term["kind"], "content_id": term.get("content_id", ""),
				"color": term["color"], "bold": term["bold"],
				"icon_path": term["icon_path"], "tooltip": _tooltip_now(term)})
	candidates.sort_custom(func(a, b):
		if a["start"] != b["start"]:
			return a["start"] < b["start"]
		if (a["end"] - a["start"]) != (b["end"] - b["start"]):
			return (a["end"] - a["start"]) > (b["end"] - b["start"])
		return a["id"] < b["id"])
	var chosen: Array = []
	var cursor = 0
	for c in candidates:
		if c["start"] >= cursor:
			chosen.append(c)
			cursor = c["end"]
	return chosen
