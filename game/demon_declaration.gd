## The demon-type declaration (Project doc belief-model-direction, Phase 2): the player tells
## the town which kind of Demon it faces, "walker" (walks at night to kill) or "hexer" (marks
## by day, kills without walking). It's the Demonologist's expertise, so NPCs don't judge it:
## the whole town weighs evidence as if it were true (LiveActivity.day_demon_share).
## - Its own meeting action, at most once a day.
## - Only on scripts that deal both kinds. A one-kind script starts declared.
## - Changing it is a straight credibility penalty with every living NPC, about what one
##   failed case costs, and it stays in their track-record target (Credibility.dawn).
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Mind = preload("res://sim/mind.gd")

const TYPES = ["walker", "hexer"]
const LABEL = {"walker": "a walking Demon", "hexer": "a Hexer"}

static func type_of(role: String) -> String:
	return "hexer" if C.is_day_demon(role) else "walker"

## The kinds of Demon this script may deal ("walker", "hexer"), in that order.
static func script_types(w) -> Array:
	var demons: Array = ["demon"]
	if w.case_script != null and not w.case_script.demons.is_empty():
		demons = w.case_script.demons
	var out: Array = []
	for t in TYPES:
		if demons.any(func(d): return type_of(str(d)) == t):
			out.append(t)
	return out

## Case start: a script that deals one kind starts with it declared.
static func setup(w) -> void:
	var kinds: Array = script_types(w)
	w.declared_demon_type = kinds[0] if kinds.size() == 1 else ""

## Can the player declare today? "" when they can, else why not.
static func blocked(w) -> String:
	if script_types(w).size() < 2:
		return "Only one kind of Demon is on this case's script; the town already knows it's %s." % LABEL[w.declared_demon_type]
	if w.declaration_day == w.day:
		return "You have already declared the Demon's kind today."
	return ""

static func parse(rest: String) -> String:
	var r: String = rest.strip_edges().to_lower()
	if r in ["walker", "walking", "walks", "demon", "night"]:
		return "walker"
	if r in ["hexer", "hex", "day", "daykiller"]:
		return "hexer"
	return ""

## Returns "" on success, else the error to show.
static func declare(g, rest: String) -> String:
	var w = g.w
	var why: String = blocked(w)
	if why != "":
		return why
	var kind: String = parse(rest)
	if kind == "":
		return "Declare which kind? 'declare walker' (it walks at night to kill) or 'declare hexer' (it marks by day and kills without walking)."
	if kind == w.declared_demon_type:
		return "The town already takes it as %s." % LABEL[kind]
	var changed: bool = w.declared_demon_type != ""
	var before: String = w.declared_demon_type
	w.declared_demon_type = kind
	w.declaration_day = w.day
	if changed:
		w.declaration_changes += 1
		for n in w.living():
			_penalise(n)
	w.dlog.add("declaration", "player", "", {"type": kind, "from": before, "changes": w.declaration_changes},
		"The Demonologist declares the Demon %s." % LABEL[kind])
	if changed:
		g._narr("You stand and correct yourself: it isn't %s after all, it's %s. A few faces harden; the town will take your word a little less readily." % [LABEL[before], LABEL[kind]])
	else:
		g._narr("You stand and tell the town what you've concluded: they're dealing with %s. Heads nod; they'll weigh what they've seen in that light." % LABEL[kind])
	# Every belief rests on the town's mix, so everyone re-reads what they hold.
	for n in w.living():
		Mind.refresh_beliefs(w, n, " (demon-type declaration)")
	Mind.refresh_all_consensus(w)
	return ""

static func _penalise(n) -> void:
	var p: float = Tuning.Trust.CRED_DECLARATION_CHANGE
	n.credibility = clampf(n.credibility - p, Tuning.Trust.CRED_MIN, Tuning.Trust.CRED_MAX)
	if n.shadow != null:
		n.shadow.credibility = clampf(n.shadow.credibility - p, Tuning.Trust.CRED_MIN, Tuning.Trust.CRED_MAX)

## The standing offset in every NPC's track-record target (Credibility.dawn).
static func dawn_offset(w) -> float:
	return Tuning.Trust.CRED_DECLARATION_CHANGE * float(w.declaration_changes)
