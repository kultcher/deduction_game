## Withheld readings: NPCs asking for the reading a claimed gift owes (docs/design/withheld_readings.md;
## direction Michael, Nov 22; values Nov 28).
##
## - **Asking in private** (`maybe_ask_private`, from `Social.converse`): a good NPC that heard
##   someone claim an information gift a day or more ago, and has heard no reading from them
##   since, may ask for it (Tuning.Social.ASK_PRIVATE_*), at most once per pair per day. The
##   answer goes to the asker only (`answer_private`).
## - **Pressing at the meeting** (`meeting_press`, from the testimony): a confident good NPC that
##   suspects a public claimant who has gone a day without a reading may press them before the
##   town (Tuning.Meeting.PRESS_WITHHELD_*), at most once per meeting. The claimant answers as
##   to the Demonologist's "Call on" (`MindCallOn.respond`), with the presser as the asker.
## - **The refusal record** (agreed with Lantern, Nov 23 and 28), for the cost Lantern builds:
##   every deferral or deflection, the player's "Call on" included, is one entry in
##   `w.withheld_refusals` and a "withheld_refusal" log entry:
##     {asker (NPC id or "player"), claimant, claim: {day, role} (the night of the dodged
##      reading and its gift; `fact_id` alongside once one exists), tick, day,
##      venue: "private" | "meeting", kind: "deferred" | "deflected",
##      reason: "friend" | "burden" | "distrust" | "", known_to: [asker] | ["public"],
##      shared_at: the tick the reading came out (absent until then; set on every entry for
##      that claimant and claim)}
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Chronology = preload("res://workshop/chronology.gd")

static func _mind():
	return load("res://sim/mind.gd")

static func _social():
	return load("res://sim/social.gd")

static func _call_on():
	return load("res://sim/mind_call_on.gd")

static func _evil():
	return load("res://sim/evil.gd")

static func _trait(n, t: String) -> float:
	return float(n.traits.get(t, 0.5))

## The statement tick now (workshop/chronology.gd's clock).
static func tick(w) -> int:
	return Chronology.tick({"day": w.day, "phase": str(C.PHASES[w.phase]).to_lower()})

## Does a claim of `role` owe the town a reading by the day after it's made? A first-night gift
## (its reading is from night 0), or an ongoing one (a night has passed). Not a gift that reads
## only after a hanging.
static func owes_reading(role: String) -> bool:
	if not C.has_role_def(role):
		return false
	var d = C.role_def(role)
	return d.kind == "info" and (d.first_night or d.is_ongoing_info())

## The day `n` first claimed `role` before the town, or -1.
static func public_claim_day(w, n, role: String) -> int:
	var day: int = -1
	for pc in w.public_claims:
		if str(pc.get("who", "")) == n.id and str(pc.get("role", "")) == role and (day < 0 or int(pc.get("day", 0)) < day):
			day = int(pc.get("day", 0))
	return day

## Has `n` given the town any reading?
static func gave_public_reading(n) -> bool:
	return n.info_log.any(func(e): return e.get("shared", false) and not e.get("disowned", false))

## What `asker` would ask `c` for in private: {role, claimed_day}, or {} when nothing is owed.
static func private_claim(w, asker, c) -> Dictionary:
	if asker == c or asker.is_evil() or not c.alive or asker.silenced or c.silenced:
		return {}
	if int(asker.dialogue_memory.get("withheld_asked", {}).get(c.id, -1)) == w.day:
		return {}
	var role: String = ""
	var day: int = -1
	var kc: Dictionary = asker.known_claims.get(c.id, {})
	if str(kc.get("role", "")) != "":
		role = str(kc["role"])
		day = int(kc.get("first_claimed_day", w.day))
		if not kc.get("readings", []).is_empty():
			return {}
	if c.claim_public and (role == "" or role == c.claimed_role):
		var pd: int = public_claim_day(w, c, c.claimed_role)
		if pd >= 0:
			role = c.claimed_role
			day = pd if day < 0 else mini(day, pd)
	if role == "" or day < 0 or day >= w.day or not owes_reading(role) or gave_public_reading(c):
		return {}
	return {"role": role, "claimed_day": day}

## In a conversation, `asker` may ask `c` for the reading its claimed gift owes. True when it asks.
static func maybe_ask_private(w, asker, c) -> bool:
	var claim: Dictionary = private_claim(w, asker, c)
	if claim.is_empty():
		return false
	var s: float = _mind().susp(asker, c.id)
	var p: float = Tuning.Social.ASK_PRIVATE_BASE + Tuning.Social.ASK_PRIVATE_WARY * s + Tuning.Social.ASK_PRIVATE_INSIGHT * _trait(asker, "insight")
	if not w.decision_roll(asker, "ask_withheld_private", p, {"suspicion": s, "insight": _trait(asker, "insight"), "role": claim.role, "claimed_day": claim.claimed_day}, c.id):
		return false
	var asked: Dictionary = asker.dialogue_memory.get("withheld_asked", {})
	asked[c.id] = w.day
	asker.dialogue_memory["withheld_asked"] = asked
	var rn: String = C.role_name(str(claim.role))
	var line: Dictionary = _mind().say_voiced(asker, "ask_reading_private", "You claim the %s. What did it show you?" % rn, {"role": rn})
	w.dlog.add("withheld_ask", asker.id, c.id, {"venue": "private", "role": claim.role, "claimed_day": claim.claimed_day, "line": line.get("text", "")},
		"%s asks %s, in private, what the %s showed them." % [asker.name, c.name, rn])
	answer_private(w, c, asker, claim)
	return true

## `n`, asked in private by `asker` for its `claim.role` reading: shares it with the asker
## alone, has nothing to tell, or holds back (deferring with a reason, or deflecting), on the
## "Call on" rules. A bluffer with a fabricated reading answers. Returns {outcome, reason}.
static func answer_private(w, n, asker, claim: Dictionary) -> Dictionary:
	var Social = _social()
	var role: String = str(claim.role)
	if n.is_evil():
		_evil().backfill_start_reading(w, n, role)
	var held: Array = n.info_log.filter(func(e): return not e.get("shared", false) and not e.get("disowned", false) and str(e.get("role", "")) == role \
		and not Social._told(n, asker, "reading:%d:%s" % [int(e.get("day", -1)), str(e.get("role", ""))]))
	if held.is_empty():
		var why_none: String = "has no such reading to give" if not n.is_evil() else "has no reading ready for its %s bluff" % C.role_name(role)
		w.dlog.think(n.id, "lie" if n.is_evil() else "withheld_answer", "Asked by %s for the %s's reading: says there's nothing more to tell (%s)." % [asker.name, C.role_name(role), why_none],
			{"outcome": "nothing", "asker": asker.id, "lie": n.is_evil(), "why": why_none})
		return {"outcome": "nothing", "reason": ""}
	var share: Array = held
	if n.is_evil():
		w.dlog.think(n.id, "withheld_answer", "Asked by %s for the %s's reading: gives the made-up reading, as a bluffer would." % [asker.name, C.role_name(role)], {"outcome": "shared", "asker": asker.id})
	else:
		share = held.filter(func(e): return (not C.has_role_def(role) or C.role_def(role).may_share_reading(w, n, e)) and not load("res://sim/burdens.gd").withholds_for_beloved(w, n, e))
		# The normal private-sharing willingness (Social._reading_weight against idle talk), with
		# the "Call on" push as a little more pressure.
		var bond: float = n.npc_trust.get(asker.id, 0.5)
		var saved_p: float = n.pressure
		n.pressure = saved_p + Tuning.Meeting.CALL_ON_PRESSURE_BUMP
		var wgt: float = maxf(0.0, Social._reading_weight(n, _trait(n, "privacy"), bond))
		n.pressure = saved_p
		var p: float = wgt / (wgt + Tuning.Social.IDLE_CHAT_WEIGHT)
		var yes: bool = w.decision_roll(n, "answer_withheld_private", p, {"weight": wgt, "trust_in_asker": bond, "held": held.size(), "shareable": share.size()}, asker.id)
		if not yes or share.is_empty():
			var reason: String = _call_on()._defer_reason(w, n, held, [], asker.id)
			if reason == "" and share.is_empty():
				reason = "burden"  # kept for the beloved's sake (burdens prototype), or not its to share
			var kind: String = "deferred" if reason != "" else "deflected"
			var line: Dictionary = _call_on().refusal_line(n, reason, asker.name)
			w.dlog.think(n.id, "withheld_answer", "Asked by %s for the %s's reading: holds back (%s)." % [asker.name, C.role_name(role), reason if reason != "" else "no reason given"],
				{"outcome": kind, "reason": reason, "asker": asker.id, "line": line.get("text", "")})
			record_refusal(w, asker.id, n, {"day": int(held[0].get("day", -1)), "role": role}, "private", kind, reason)
			return {"outcome": kind, "reason": reason}
		w.dlog.think(n.id, "withheld_answer", "Asked by %s for the %s's reading: tells them." % [asker.name, C.role_name(role)], {"outcome": "shared", "asker": asker.id})
	for e in share:
		var key: String = "reading:%d:%s" % [int(e.get("day", -1)), str(e.get("role", ""))]
		Social._deliver(w, n, asker, {"kind": "reading", "entry": e, "about": "", "from": n.id, "key": key, "lie": e.get("fake", false)})
	return {"outcome": "shared", "reason": ""}

## At its testimony, a confident good NPC may press a public claimant it suspects, one that has
## gone a day without giving a reading. Appends the press and the answer; true when it presses.
static func meeting_press(w, n, lines: Array, facts: Array) -> bool:
	if n.is_evil() or n.silenced or str(w.meeting.get("withheld_pressed", "")) != "":
		return false
	var conf: float = _trait(n, "confidence")
	if conf < Tuning.Meeting.PRESS_WITHHELD_CONFIDENCE_MIN:
		return false
	var best = null
	var best_s: float = -1.0
	var best_day: int = -1
	for c in w.living():
		if c == n or c.silenced or not c.claim_public or not owes_reading(c.claimed_role) or gave_public_reading(c):
			continue
		var cd: int = public_claim_day(w, c, c.claimed_role)
		if cd < 0 or cd >= w.day:
			continue
		var s: float = _mind().susp(n, c.id)
		if s < Tuning.Meeting.GOOD_ACCUSE_MIN_SUSP or s <= best_s:
			continue
		best = c
		best_s = s
		best_day = cd
	if best == null:
		return false
	var p: float = Tuning.Meeting.PRESS_WITHHELD_SCALE * conf
	if not w.decision_roll(n, "press_withheld", p, {"confidence": conf, "suspicion": best_s, "claimed_day": best_day}, best.id):
		return false
	w.meeting["withheld_pressed"] = n.id
	var rn: String = C.role_name(best.claimed_role)
	var when: String = "yesterday" if best_day == w.day - 1 else C.spoken_day(best_day)
	lines.append(_mind().say_voiced(n, "press_withheld", "%s, you've claimed the %s since %s, and we've heard nothing of what it showed you. That's worth an explanation." % [best.name, rn, when],
		{"target": best.name, "role": rn, "when": when}))
	w.dlog.add("withheld_ask", n.id, best.id, {"venue": "meeting", "role": best.claimed_role, "claimed_day": best_day},
		"%s presses %s before the town for what the %s showed them." % [n.name, best.name, rn])
	var res: Dictionary = _call_on().respond(w, best, n.id)
	lines.append_array(res.get("lines", []))
	facts.append_array(res.get("facts", []))
	# The claimant's night sightings reach the town as said by the claimant (Codex on #588): the
	# testimony turn delivers its facts as the presser's, which a sighting's source rules out.
	for f in res.get("facts", []):
		_social().deliver_public_sighting(w, best, f)
	return true

## One refusal on the record (see the header). `claim` is {day, role}.
static func record_refusal(w, asker_id: String, n, claim: Dictionary, venue: String, kind: String, reason: String) -> void:
	var r: Dictionary = {"asker": asker_id, "claimant": n.id, "claim": {"day": int(claim.get("day", -1)), "role": str(claim.get("role", ""))},
		"tick": tick(w), "day": w.day, "venue": venue, "kind": kind, "reason": reason,
		"known_to": [asker_id] if venue == "private" else ["public"]}
	w.withheld_refusals.append(r)
	var who: String = "the Demonologist" if asker_id == "player" else (w.by_id[asker_id].name if w.by_id.has(asker_id) else asker_id)
	w.dlog.add("withheld_refusal", n.id, asker_id, r, "%s %s %s's ask (%s)%s." % [n.name, "defers" if kind == "deferred" else "deflects", who, venue, (", " + reason) if reason != "" else ""])

## `n` has given reading `e` (or told a night sighting: `e` = {role: "", day: its night}), to
## `to_id` alone or to "public": every open refusal of that claim the hearer knows of gets
## `shared_at`.
static func note_shared(w, n, e: Dictionary, to_id: String) -> void:
	var now: int = -1
	for r in w.withheld_refusals:
		if str(r.get("claimant", "")) != n.id or r.has("shared_at"):
			continue
		var cl: Dictionary = r.get("claim", {})
		if str(cl.get("role", "")) != str(e.get("role", "")) or int(cl.get("day", -2)) != int(e.get("day", -1)):
			continue
		if to_id != "public" and not (to_id in r.get("known_to", [])):
			continue
		if now < 0:
			now = tick(w)
		r["shared_at"] = now
