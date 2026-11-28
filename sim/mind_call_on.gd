## "Call on" (docs/design/withheld_readings.md, Michael, Nov 22): what someone the Demonologist
## calls on at the meeting says. They are prompted to share what they haven't yet: readings,
## night sightings, and a late reader's readings they heard. The normal disclosure rules
## decide, with a light pressure bump (Tuning.Meeting.CALL_ON_PRESSURE_BUMP).
##
## respond(w, n, asker_id = "player") -> {
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
##   isn't theirs alone, distrust of the asker), else a plain deflection. Both are visibly
##   refusals, and each goes on the refusal record (MindWithheld.record_refusal).
##
## The asker is the Demonologist ("player") or an NPC pressing at the meeting
## (MindWithheld.meeting_press, Michael, Nov 28): the same rules, with distrust read from the
## claimant's trust in that NPC.
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

## Night sightings n could volunteer and hasn't told the town (the meeting's own eligibility).
static func _untold_sightings(w, n) -> Array:
	var M = _meeting()
	var out: Array = []
	for b in n.beliefs:
		if b.get("kind", "") != "saw" or b.get("phase", -1) != load("res://sim/content.gd").NIGHT or b.get("day", -1) < 0 or b.day >= w.day or not w.by_id.has(b.get("who", "")):
			continue
		if n.told_to.has(M._town_sighting_key(n, b)) or not M._public_sighting_allowed(w, n, b):
			continue
		out.append(b)
	return out

## A late reader's readings n heard and hasn't passed on to the town.
static func _untold_late(w, n) -> Array:
	var M = _meeting()
	var out: Array = []
	if n.is_evil():
		return out
	for src_id in n.known_claims:
		if not w.by_id.has(src_id) or w.by_id[src_id].alive or src_id == n.id:
			continue
		for e in n.known_claims[src_id].get("readings", []):
			if not e is Dictionary or M._reading_public(w, w.by_id[src_id], e):
				continue
			if n.told_to.has("town|late:%s:%d:%s" % [src_id, int(e.get("day", -1)), str(e.get("role", ""))]):
				continue
			out.append(e)
	return out

static func _withheld():
	return load("res://sim/mind_withheld.gd")

static func respond(w, n, asker_id: String = "player") -> Dictionary:
	var M = _meeting()
	var by: String = "the Demonologist" if asker_id == "player" else (w.by_id[asker_id].name if w.by_id.has(asker_id) else asker_id)
	var asker_name: String = "Demonologist" if asker_id == "player" else by
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
	# Everything still held after the attempt (Codex on #545): readings, a late reader's
	# readings, untold night sightings. Holding any back is a refusal, not "nothing".
	var still_late: Array = _untold_late(w, n)
	var still_seen: Array = _untold_sightings(w, n)
	if not facts.is_empty():
		lines.insert(0, _mind().say_voiced(n, "call_on_share", "Since you ask, there's something I haven't said:"))
		w.dlog.think(n.id, "call_on", "Called on by %s: shares %d item(s)." % [by, facts.size()], {"outcome": "shared", "asker": asker_id})
		return {"lines": lines, "facts": facts, "outcome": "shared", "reason": "", "lie": false}
	if still.is_empty() and still_late.is_empty() and still_seen.is_empty():
		w.dlog.think(n.id, "call_on", "Called on by %s: has nothing more to tell." % by, {"outcome": "nothing", "asker": asker_id})
		return {"lines": [_mind().say_voiced(n, "call_on_nothing", "I've told the town all I know.")], "facts": [],
			"outcome": "nothing", "reason": "", "lie": false}
	if n.is_evil():
		var why: String = "keeps its %s bluff back for now" % str(w.evil_plan.get("bluffs", {}).get(n.id, "gift"))
		w.dlog.think(n.id, "lie", "Called on by %s: says it has told all it knows, though it %s." % [by, why], {"lie": true, "why": why, "outcome": "nothing", "asker": asker_id})
		return {"lines": [_mind().say_voiced(n, "call_on_nothing", "I've told the town all I know.")], "facts": [],
			"outcome": "nothing", "reason": "", "lie": true}
	var reason: String = _defer_reason(w, n, still + still_late, still_seen, asker_id)
	var line: Dictionary = refusal_line(n, reason, asker_name)
	var outcome: String = "deferred" if reason != "" else "deflected"
	w.dlog.think(n.id, "call_on", "Called on by %s: holds back (%s)." % [by, reason if reason != "" else "no reason given"], {"outcome": outcome, "reason": reason, "asker": asker_id})
	# The claim dodged: the first reading held back (its night and gift), else a late
	# reader's reading, else a night sighting (no gift).
	var claim: Dictionary = {}
	if not still.is_empty():
		claim = {"day": int(still[0].get("day", -1)), "role": str(still[0].get("role", ""))}
	elif not still_late.is_empty():
		claim = {"day": int(still_late[0].get("day", -1)), "role": str(still_late[0].get("role", ""))}
	else:
		claim = {"day": int(still_seen[0].get("day", -1)), "role": ""}
	_withheld().record_refusal(w, asker_id, n, claim, "meeting", outcome, reason)
	return {"lines": [line], "facts": [], "outcome": outcome, "reason": reason, "lie": false}

## The spoken refusal for a reason ("" for a plain deflection), to `asker_name`.
static func refusal_line(n, reason: String, asker_name: String = "Demonologist") -> Dictionary:
	match reason:
		"burden":
			return _mind().say_voiced(n, "withheld_defer_burden", "It isn't mine alone to tell.")
		"friend":
			return _mind().say_voiced(n, "withheld_defer_friend", "There's more, but it touches someone dear to me. Let me be sure before I say it.")
		"distrust":
			return _mind().say_voiced(n, "withheld_defer_distrust", "I'll share it when I choose, %s, not at your asking." % asker_name, {"asker": asker_name})
	return _mind().say_voiced(n, "withheld_deflect", "Why single me out? Ask someone else.")

## Why a good NPC holds back: a burden that isn't its alone (a Rumormonger's reading; with
## Burdens, also the Unrequited shielding its beloved), a reading naming a friend, or distrust
## of the asker (the Demonologist, "player", or an NPC). "" for none.
static func _defer_reason(w, n, still: Array, seen: Array = [], asker_id: String = "player") -> String:
	for e in still:
		if str(e.get("role", "")) == "rumormonger":
			return "burden"
	for e in still:
		if Gifts.implicated(e).any(func(id): return id in n.friends):
			return "friend"
	for b in seen:
		if str(b.get("who", "")) in n.friends:
			return "friend"
	var trust: float = n.trust if asker_id == "player" else float(n.npc_trust.get(asker_id, 0.5))
	if trust < Tuning.Trust.DISTRUST_EXPLAIN_THRESHOLD:
		return "distrust"
	return ""
