## "Call on" (docs/design/withheld_readings.md, Michael, Nov 22): what someone the Demonologist
## calls on at the meeting says. They are prompted to share what they haven't yet: readings,
## night sightings, and a late reader's readings they heard. The normal disclosure rules
## decide, with a light pressure bump (Tuning.Meeting.CALL_ON_PRESSURE_BUMP).
##
## respond(w, n) -> {
##   "lines":   spoken lines (say_voiced dictionaries), in order;
##   "facts":   board facts for the player, if any;
##   "outcome": "shared" | "nothing" | "deferred" | "deflected", as the town hears it;
##   "reason":  for a deferral, "friend" | "burden" | "distrust", else "";
##   "lie":     true when "nothing" is said over something unshared (logged with its reason).
## }
##
## - Something unshared and the rules say yes: "call_on_share", then the items as usual.
## - Nothing to tell: "call_on_nothing".
## - Holding back, good: a deferral with its reason (a reading naming a friend, a burden that
##   isn't theirs alone, distrust of the Demonologist), else a plain deflection. Both are
##   visibly refusals.
## - Holding back, evil: "I've told the town all I know", a lie (keeping its bluff back).
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const Gifts = preload("res://sim/gifts.gd")

static func _mind():
	return load("res://sim/mind.gd")

static func _meeting():
	return load("res://sim/mind_meeting.gd")

## What n hasn't yet told the town: its own readings (not disowned), and night sightings the
## meeting would let it volunteer. A late reader's readings are counted by _late_relay itself.
static func _unshared_readings(w, n) -> Array:
	return n.info_log.filter(func(e): return not e.get("shared", false) and not e.get("disowned", false))

static func respond(w, n) -> Dictionary:
	var M = _meeting()
	var bump: float = Tuning.Meeting.CALL_ON_PRESSURE_BUMP
	var held: Array = _unshared_readings(w, n)
	var lines: Array = []
	var facts: Array = []
	_mind().flush_beliefs(w, n)
	# Readings: already out with the gift, it shares them as at its turn; otherwise the usual
	# "say it before the town?" decision, pushed a little.
	if not held.is_empty():
		if n.claim_public or M._public_claim_decision(w, n, bump) != "":
			M._public_disclosure(w, n, lines, facts)
	M._late_relay(w, n, lines, facts)
	M._volunteer_night_sightings(w, n, lines, facts, bump)
	var still: Array = _unshared_readings(w, n)
	if not facts.is_empty():
		lines.insert(0, _mind().say_voiced(n, "call_on_share", "Since you ask, there's something I haven't said:"))
		w.dlog.think(n.id, "call_on", "Called on by the Demonologist: shares %d item(s)." % facts.size(), {"outcome": "shared"})
		return {"lines": lines, "facts": facts, "outcome": "shared", "reason": "", "lie": false}
	if still.is_empty():
		w.dlog.think(n.id, "call_on", "Called on by the Demonologist: has nothing more to tell.", {"outcome": "nothing"})
		return {"lines": [_mind().say_voiced(n, "call_on_nothing", "I've told the town all I know.")], "facts": [],
			"outcome": "nothing", "reason": "", "lie": false}
	if n.is_evil():
		var why: String = "keeps its %s bluff back for now" % str(w.evil_plan.get("bluffs", {}).get(n.id, "gift"))
		w.dlog.think(n.id, "lie", "Called on by the Demonologist: says it has told all it knows, though it %s." % why, {"lie": true, "why": why, "outcome": "nothing"})
		return {"lines": [_mind().say_voiced(n, "call_on_nothing", "I've told the town all I know.")], "facts": [],
			"outcome": "nothing", "reason": "", "lie": true}
	var reason: String = _defer_reason(w, n, still)
	var line: Dictionary
	match reason:
		"burden":
			line = _mind().say_voiced(n, "withheld_defer_burden", "It isn't mine alone to tell.")
		"friend":
			line = _mind().say_voiced(n, "withheld_defer_friend", "There's more, but it touches someone dear to me. Let me be sure before I say it.")
		"distrust":
			line = _mind().say_voiced(n, "withheld_defer_distrust", "I'll share it when I choose, Demonologist, not at your asking.", {"asker": "Demonologist"})
		_:
			line = _mind().say_voiced(n, "withheld_deflect", "Why single me out? Ask someone else.")
	var outcome: String = "deferred" if reason != "" else "deflected"
	w.dlog.think(n.id, "call_on", "Called on by the Demonologist: holds back (%s)." % (reason if reason != "" else "no reason given"), {"outcome": outcome, "reason": reason})
	return {"lines": [line], "facts": [], "outcome": outcome, "reason": reason, "lie": false}

## Why a good NPC holds back: a burden that isn't its alone (a Rumormonger's reading; with
## Burdens, also the Unrequited shielding its beloved), a reading naming a friend, or distrust
## of the Demonologist. "" for none.
static func _defer_reason(w, n, still: Array) -> String:
	for e in still:
		if str(e.get("role", "")) == "rumormonger":
			return "burden"
	for e in still:
		if Gifts.implicated(e).any(func(id): return id in n.friends):
			return "friend"
	if n.trust < Tuning.Trust.DISTRUST_EXPLAIN_THRESHOLD:
		return "distrust"
	return ""
