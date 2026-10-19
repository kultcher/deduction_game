## The case-board card model: what time a card belongs to, which board view it lives in,
## which rows it appears on, and the markers it puts on the Places & sightings view.
## Pure functions over card dictionaries, so the board layout can be tested headless.
##
## Times:
##   card["when"]    = {day, phase}: the canonical time, when the thing happened (a Seer
##                     reading on night 1 sits at N1 however late you heard of it). Things
##                     that are themselves acts of speech (a claim, an opinion) happened
##                     when they were said.
##   card["learned"] = [{day, phase, via, public}]: every time you heard of it, in order
##                     (the same fact told privately and then to the whole town is one card
##                     with two disclosures).
extends RefCounted

const Gifts = preload("res://sim/gifts.gd")

const C = preload("res://sim/content.gd")

## Board views. "theory" (your deductions) lives in the tray and can be pinned to any view.
const VIEWS = ["places", "statements", "process"]
const VIEW_NAMES = {"places": "Places & sightings", "statements": "Statements", "process": "Process", "all": "All cards"}

## Kinds the filter menus offer in each view.
const VIEW_KINDS = {
	"places": ["sighting", "conversation", "vigil", "alibi", "trace", "dropped", "totem"],
	"statements": ["home", "haunt", "info", "claim", "hint", "refusal", "opinion", "accusation", "secret", "case"],
	"process": ["vote", "execution", "death", "quiet", "martyr", "curse", "curse_lifted", "silenced", "knell"],
	"all": ["home", "haunt", "sighting", "conversation", "vigil", "alibi", "trace", "dropped", "totem", "info", "claim", "hint", "refusal",
		"opinion", "accusation", "secret", "vote", "execution", "death", "quiet", "martyr", "curse", "curse_lifted", "silenced", "knell", "deduction"],
}

## Facts that can reach you more than once (told privately, then publicly; relayed by
## someone else): repeats add a disclosure to the existing card instead of a new card.
const MERGE_KINDS = ["claim", "info", "sighting", "alibi"]

static func view_of(card: Dictionary) -> String:
	var k: String = card.get("kind", "")
	if k == "deduction":
		return "theory"
	for v in VIEWS:
		if k in VIEW_KINDS[v]:
			return v
	return "statements"

## The canonical time: when it happened.
static func when(card: Dictionary, learned_day: int, learned_phase: int) -> Dictionary:
	var k: String = card.get("kind", "")
	if k == "death":
		return {"day": card.get("night", card.get("day", learned_day) - 1), "phase": C.NIGHT}
	if k in ["info", "quiet"] and not (k == "info" and card.has("phase")):
		return {"day": card.get("night", card.get("day", learned_day)), "phase": C.NIGHT}
	if card.has("phase") and card.get("phase", -1) >= 0 and card.has("day"):
		return {"day": card["day"], "phase": card["phase"]}
	return {"day": learned_day, "phase": learned_phase}

## Sort key / column key for a time.
static func time_key(t: Dictionary) -> String:
	return "%d:%d" % [t["day"], t["phase"]]

static func time_order(t: Dictionary) -> int:
	return t["day"] * 10 + t["phase"]

static func time_label(t: Dictionary) -> String:
	if t["phase"] == C.NIGHT:
		return "N%d" % t["day"]
	return "D%d%s" % [t["day"], ["M", "A", "E"][clampi(t["phase"], 0, 2)]]

## People a card is about (not who said it): subjects, plus everyone a reading names.
static func about(card: Dictionary) -> Array:
	var out: Array = card.get("subject", []).duplicate()
	var d: Dictionary = card.get("data", {})
	for key in ["pair", "nbrs", "seen"]:
		for x in d.get(key, []):
			if not (x in out):
				out.append(x)
	if d.has("executed") and not (d["executed"] in out):
		out.append(d["executed"])
	if card.has("nominee") and not (card["nominee"] in out):
		out.append(card["nominee"])
	return out

## Where people were, as markers for the Places & sightings view:
## [{who, block, loc, time, mark}] with mark "solid" (you saw it), "hollow" (someone told
## you), "ability" (a gift's report: a Night Watch's list of who passed), "trace" (physical
## evidence, no person).
static func place_markers(card: Dictionary, learned_day: int = -1, learned_phase: int = -1) -> Array:
	var k: String = card.get("kind", "")
	var t: Dictionary = card.get("when", when(card, learned_day, learned_phase))
	var src: String = card.get("source", "")
	var out: Array = []
	var firsthand = src in ["player", "evidence", ""]
	match k:
		"sighting", "conversation":
			for who in card.get("subject", []):
				out.append({"who": who, "block": card.get("block", ""), "loc": card.get("loc", ""), "time": t,
					"mark": "solid" if firsthand else "hollow"})
		"alibi":
			var who2: String = card.get("subject", [""])[0]
			out.append({"who": who2, "block": card.get("block", ""), "loc": "home_" + who2, "time": t, "mark": "solid" if firsthand else "hollow", "home": true})
		"vigil":
			out.append({"who": "", "block": card.get("block", ""), "loc": "", "time": t, "mark": "solid"})
		"trace", "dropped", "totem":
			out.append({"who": "", "block": card.get("block", ""), "loc": card.get("loc", ""), "time": t, "mark": "trace"})
		"info":
			var d: Dictionary = card.get("data", {})
			if card.get("role", "") == "nightwatch" and d.has("block"):
				for who3 in d.get("seen", []):
					out.append({"who": who3, "block": d["block"], "loc": "", "time": t, "mark": "ability"})
			elif card.get("role", "") == "dowser" and d.has("block"):
				# The Dowser names who stood on that block with them.
				for who4 in d.get("group", []) + [src]:
					out.append({"who": who4, "block": d["block"], "loc": "", "time": t, "mark": "ability"})
	return out

## The rows a card appears on in a view (row ids: person ids, or block ids in Places
## when rows are places). "town" = a row for events about nobody in particular.
static func rows_for(card: Dictionary, view: String, rows_by: String = "place") -> Array:
	match view:
		"places":
			var out: Array = []
			for m in place_markers(card):
				var r: String = m["who"] if rows_by == "person" else m["block"]
				if r != "" and not (r in out):
					out.append(r)
			if out.is_empty() and rows_by == "person":
				out.append("town")
			return out
		"statements":
			var ab: Array = about(card)
			return ab if not ab.is_empty() else ["town"]
		"process":
			var out2: Array = about(card)
			for x in card.get("yes", []):
				if not (x in out2):
					out2.append(x)
			return out2 if not out2.is_empty() else ["town"]
	return []

## A one-line summary for the board's day-level zoom.
static func short_text(card: Dictionary, names: Dictionary) -> String:
	var k: String = card.get("kind", "")
	var nm = func(id): return names.get(id, id)
	var src: String = nm.call(card.get("source", ""))
	match k:
		"info":
			return Gifts.short_text(card.get("role", ""), card.get("data", {}), src, nm)
		"claim":
			return "%s claims %s" % [src, C.role_name(card.get("role", ""))]
		"vote":
			return "Vote on %s: %d for (%s)" % [nm.call(card.get("nominee", "")), card.get("yes", []).size(), card.get("outcome", "")]
	var t: String = card.get("text", "")
	return t if t.length() <= 60 else t.substr(0, 57) + "..."
