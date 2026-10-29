## Town meeting reasoning and flow for NPCs: public testimony, volunteering night
## sightings, public role claims, citing reasons, anonymous relays, social consensus
## pressure, nominations, nominator cases, self-defence, and voting.
##
## Extracted from `sim/mind.gd`; `Mind` retains forwarding wrappers so callers can
## invoke either `Mind.<fn>` or `MindMeeting.<fn>`.
extends RefCounted

const WorkshopLedger = preload("res://workshop/shared_ledger.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Dialogue = preload("res://sim/dialogue.gd")

static var _mind_script


static func _mind():
	if _mind_script == null:
		_mind_script = load("res://sim/mind.gd")
	return _mind_script

# ---------------------------------------------------------------- town meeting

## Public testimony before nominations. Returns Array of {who, lines, facts}.
static func meeting_testimony(w) -> Array:
	var out: Array = []
	var st: Dictionary = testimony_start(w)
	while not st["done"]:
		var turn: Dictionary = testimony_step(w, st)
		if not turn.get("lines", []).is_empty():
			out.append(turn)
	return out

## The same testimony one step at a time, so the UI can show each speaker while the next
## one is worked out. Running every step in a row is exactly meeting_testimony.
static func testimony_start(w) -> Dictionary:
	w.defer_beliefs = true
	return {"speakers": w.shuffled(w.living()), "i": 0, "done": false}

## One step: the next speaker's turn ({who, lines, facts}; lines may be empty), or once
## everyone has spoken, one of the belief refreshes still waiting ({}). Sets st.done after
## the last one.
static func testimony_step(w, st: Dictionary) -> Dictionary:
	while st["i"] < st["speakers"].size():
		var n = st["speakers"][st["i"]]
		st["i"] += 1
		if n.silenced:
			w.observe_decision(n, "meeting_testimony", false, {"gate": "silenced; no testimony or roll"})
			continue  # the Breathstealer took their voice
		var lines: Array = []
		var facts: Array = []
		flush_beliefs(w, n)  # a speaker reacts to everything said before their turn
		if not n.claim_public and _public_claim_decision(w, n) != "":
			_public_disclosure(w, n, lines, facts)
		elif n.claim_public:
			_public_disclosure(w, n, lines, facts)  # already out: share any new readings
		var acc = _public_accusation(w, n, lines, facts)
		if acc != null:
			lines.append(acc["line"])
			facts.append(acc["fact"])
		_volunteer_night_sightings(w, n, lines, facts)
		return {"who": n.id, "lines": lines, "facts": facts}
	# Everyone has spoken: the remaining refreshes, one mind per step, in queue order.
	if not w.pending_beliefs.is_empty():
		flush_beliefs(w, w.pending_beliefs[0][0])
	if w.pending_beliefs.is_empty():
		w.defer_beliefs = false
		st["done"] = true
	return {}

## A volunteer never invents a cover or reveals an undisclosed walk. Reuse the
## known account and walking-gift/reading constraints used by private followups.
static func _public_sighting_allowed(w, n, b: Dictionary) -> bool:
	if n.secret_mod == "sleepwalker": return false
	if n.is_evil() and Evil.is_teammate(w, n, b.who): return false
	var pre_def = C.role_def(n.claimed_role)
	if pre_def != null:
		var pre_gate: int = pre_def.check_public_sighting_pregate(w, n, b, _mind())
		if pre_gate != 0: return pre_gate > 0
	var account: Dictionary = n.dialogue_memory.get("night_accounts", {}).get(str(b.day), {})
	if account.get("kind", "") == "refusal": return b.block == n.home_block
	if account.get("kind", "") == "alibi" and account.get("home", false):
		return b.get("how", "street") == "window" and b.block == n.home_block
	if account.get("block", b.block) != b.block: return false
	if b.get("how", "street") == "window": return b.block == n.home_block
	var where: String = n.history.get(w.time_key(b.day, C.NIGHT), "home:" + n.home_block)
	if not n.is_evil() and n.secret_known:
		return where == "night:" + b.block
	if not (n.claim_public or n.max_tier >= 3) or not C.ROLES.get(n.claimed_role, {}).get("night_walk", false): return false
	if not n.is_evil(): return n.role == n.claimed_role and where == "night:" + b.block
	var cdef = C.role_def(n.claimed_role)
	if cdef != null:
		return cdef.public_sighting_allowed(w, n, b)
	return false

static func _town_sighting_key(n, b: Dictionary) -> String:
	return "town|sighting:%s:%s:%d:%d:%s" % [n.id, b.who, b.day, C.NIGHT, b.block]

static func _volunteer_night_sightings(w, n, lines: Array, facts: Array) -> void:
	if n.silenced: return
	var score = trait_of(n, "gossip") + trait_of(n, "confidence")
	var panic = paranoia(w, n)
	var threshold = Tuning.Meeting.VOLUNTEER_SIGHTING_BASE - panic
	w.observe_decision(n, "volunteer_night_sightings", score >= threshold, {"score": score, "threshold": threshold, "comparison": ">=",
		"inputs": {"gossip": trait_of(n, "gossip"), "confidence": trait_of(n, "confidence"), "paranoia": panic, "composure": trait_of(n, "composure")},
		"threshold_parts": {"base": 1.2, "paranoia": -panic}, "gate": "Gossip + Confidence threshold; eligible untold sightings still require disclosure/cover checks; no random draw"})
	if score < threshold: return
	var groups: Array = []
	for b in n.beliefs:
		if b.get("kind", "") != "saw" or b.get("phase", -1) != C.NIGHT or b.get("day", -1) < 0 or b.day >= w.day or not w.by_id.has(b.get("who", "")): continue
		if n.told_to.has(_town_sighting_key(n, b)) or not _public_sighting_allowed(w, n, b): continue
		var report = sighting_report(w, n, b, b.day)
		n.told_to[_town_sighting_key(n, b)] = true
		_add_observation(groups, report.observation)
		facts.append(report.fact)
		w.dlog.add("volunteer_sighting", n.id, b.who, {"night": b.day, "block": b.block, "score": score, "threshold": threshold})
	lines.append_array(_observation_lines(n, groups, "town", "volunteer", not lines.is_empty()))

static func _public_claim_decision(w, n) -> String:
	var role: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var kind: String = C.ROLES[role]["kind"]
	var parts = {
		"openness": (0.5 - trait_of(n, "privacy")) * 1.2,
		"day": 0.3 * (w.day - 1),
		"pressure": n.pressure * 0.8 * (1.0 - 0.5 * trait_of(n, "composure")),
		"base": -0.35,
	}
	# Gifts that pay off night after night are worth protecting early; one-shot first-night
	# gifts have less to lose by coming out.
	C.role_def(role).score_public_claim(w, n, parts)
	if w.living().size() <= 4:
		parts["few_left"] = 0.8
	if n.protect_lock and not (n.id in w.meeting.get("nominated", []) or n.pressure >= 0.7):
		parts["promised_player_first"] = -0.6  # they've promised the Demonologist first
	var why = ("Evil cover: publicly claim bluff %s?" % role) if n.is_evil() else ("Publicly reveal true role %s?" % role)
	if decide(w, n, "claim", parts, why):
		if n.is_evil():
			w.dlog.think(n.id, "lie", "Evil cover: publicly claims bluff %s." % role, {"bluff": role, "true_role": n.role})
		return role
	return ""

static func _claim_line(n, role: String) -> Dictionary:
	var openers = {
		"warm": "I'll not keep secrets from my neighbours. ",
		"gruff": "Fine. ",
		"formal": "In the interest of the town, I shall be plain. ",
		"nervous": "I-I suppose I have to say it. ",
		"plain": "Here's the truth of it. ",
	}
	var fallback = "%sI am the %s." % [openers.get(n.style, ""), C.role_name(role)]
	return say_voiced(n, "public_claim", fallback, {"role": C.role_name(role)})

## Construct the exact public-facing report before a presentation layer touches it.
static func _info_intent(w, n, e: Dictionary) -> Dictionary:
	var when = "The night before you arrived" if e["day"] == 0 else "Last night" if e["day"] == w.day - 1 else "On night %d" % e["day"]
	if e.has("phase"):
		when = ("This " + C.PHASES[e["phase"]].to_lower()) if e["day"] == w.day else "On day %d, in the %s" % [e["day"], C.PHASES[e["phase"]].to_lower()]
	return {"kind": "report", "statement": "%s, %s." % [when, e["text"]], "event_id": info_eid(n.id, e)}

static func info_line(w, n, e: Dictionary, audience: String = "player", speech_act: String = "answer") -> Dictionary:
	var approved = _info_intent(w, n, e)
	return voiced(n, "report", approved["statement"], approved["event_id"], {"audience": audience, "speech_act": speech_act})

## A batch of readings is one uninterrupted speech turn. Each report remains an
## independent line and fact; only its introduction/connective is turn-aware.
static func info_lines(w, n, entries: Array, audience: String = "player", preceded: bool = false, speech_act: String = "answer") -> Array:
	var approved: Array = []
	for e in entries:
		approved.append(_info_intent(w, n, e))
	var rendered: Array = Dialogue.compose_turn(n.id, approved,
		{"audience": audience, "speech_act": speech_act, "trust": n.trust, "pressure": n.pressure}, n.dialogue_memory, preceded)
	var lines: Array = []
	for part in rendered:
		lines.append(say(n, part["text"]))
	return lines

static func info_fact(w, n, e: Dictionary) -> Dictionary:
	var subj: Array = Gifts.subjects(e)
	var d: Dictionary = e["data"]
	var f = {"kind": "info", "subject": subj, "source": n.id, "day": e["day"], "role": e["role"], "data": d.duplicate(),
		"text": "%s (as %s, %s %d): %s." % [n.name, C.role_name(e["role"]), "day" if e.has("phase") else "night", e["day"], e["text"]]}
	if e.has("phase"):
		f["phase"] = e["phase"]
	return f

# ---------------------------------------------------------------- citing reasons

## Where n's current reason for suspecting t stands. Returns {why, kind, entry, strength}:
##   kind "none"    no reason on record (vibes);
##        "public"  the town already knows it (or it reveals nothing of n's gift);
##        "player"  n's own reading, told to the player privately but not to the town;
##        "private" n's own reading, told to nobody.
## An NPC may only cite what the audience already has; a private reason has to be claimed
## first (see _accuse_tier). The reason's provenance is the ledger entry that last raised
## the suspicion (n.sus_src), not its wording.
static func reason_status(w, n, t_id: String) -> Dictionary:
	var why: String = n.sus_why.get(t_id, "")
	var src: String = n.sus_src.get(t_id, "")
	if n.workshop_state.get("active", false):
		var joint_strength: float = n.workshop_state.get("requested", {}).get(t_id, 0.0)
		if joint_strength >= 0.15:
			return {"why": "the reports considered together point toward them", "kind": n.workshop_state.get("reason_visibility", "shared_private"), "entry": {}, "strength": joint_strength}
		if n.workshop_state.get("owned", {}).has(src):
			return {"why": "", "kind": "none", "entry": {}, "strength": 0.0} # An obsolete raw bonus is no longer the reason.
	var out = {"why": why, "kind": "none" if why == "" else "public", "entry": {}, "strength": 0.0}
	if why == "":
		return out
	if src == "own_role" or n.ledger.get(src, {}).get("meta", {}).get("kind") == "role_counter":
		out["kind"] = "public" if n.claim_public else "private"
		out["strength"] = 0.5
		return out
	var own = "info:%s:" % n.id
	if not src.begins_with(own):
		var hr = _heard_reading(w, n, src)
		if not hr.is_empty():
			out["kind"] = "relay"
			out["entry"] = hr["entry"]
			out["src"] = hr["src"]
			out["strength"] = reading_strength(hr["entry"], t_id) * 0.5
		return out
	for i in range(n.info_log.size()):
		var e: Dictionary = n.info_log[i]
		if info_eid(n.id, e) != src:
			continue
		out["entry"] = e
		out["strength"] = reading_strength(e, t_id)
		if e.get("shared", false):
			out["kind"] = "public"
		elif i < n.told_readings:
			out["kind"] = "player"
		else:
			out["kind"] = "private"
		return out
	return out

## The reason n may give for suspecting t to this audience ("town" or "player"), or "" if
## the only reason they have is one the audience hasn't been told.
static func citable_reason(w, n, t_id: String, audience: String = "town") -> String:
	var rs = reason_status(w, n, t_id)
	if rs["kind"] == "public" or (rs["kind"] in ["player", "shared_player"] and audience == "player"):
		return rs["why"]
	return ""

## How strongly one reading points at t (0..1): a Seer naming the demon among two says far
## more than one in a Dowser's crowd of four.
static func reading_strength(e: Dictionary, t_id: String) -> float:
	var d: Dictionary = e.get("data", {})
	var rdef = C.role_def(e.get("role", ""))
	if rdef != null:
		return rdef.reading_strength(d, t_id)
	return 0.3

## Evil: an unshared fake reading of theirs that points at t, or {}.
static func _unshared_fake_on(n, t_id: String) -> Dictionary:
	for e in n.info_log:
		if e.get("fake", false) and not e.get("shared", false) and t_id in Gifts.implicated(e):
			return e
	return {}


## A reading someone else told n in private, not yet public: {src, entry}, or {}.
static func _heard_reading(w, n, eid: String) -> Dictionary:
	if not eid.begins_with("info:"):
		return {}
	var parts = eid.split(":")
	if parts.size() < 4 or parts[1] == n.id or not w.by_id.has(parts[1]):
		return {}
	var src = w.by_id[parts[1]]
	for e in src.info_log:
		if info_eid(src.id, e) == eid:
			return {} if e.get("shared", false) else {"src": src, "entry": e}
	return {}

## Passing on, at the meeting, a reading someone told them in private, without naming
## them: "Word reached me from the Seer: …". Gossip, so it counts for much less than the
## claim itself would (C.RELAY_WEIGHT, and through the relayer's credibility), but it
## leaves a trail: there's a Seer, and the relayer knows who. Now and then
## (C.RELAY_CORROBORATE) the source steps forward and confirms it.
static func relay_reading(w, n, src, e: Dictionary, lines: Array, facts: Array) -> void:
	var rn = C.role_name(e["role"])
	var said = C.third_person(e["text"])
	lines.append(say(n, "Word reached me from the %s: %s." % [rn, said]))
	facts.append({"kind": "accusation", "subject": Gifts.implicated(e), "source": n.id, "relay": true, "role": e["role"],
		"text": "%s says the %s (unnamed) told them: %s." % [n.name, rn, said]})
	for l in w.living():
		if l != n and l != src:
			apply_info(w, l, src, e, C.RELAY_WEIGHT * heard_weight(l, n), n.id, true)
	w.dlog.think(n.id, "relay", "Relays %s's private %s reading without naming them." % [src.id, e["role"]], {"src": src.id})
	if src.alive and not src.silenced and not src.claim_public and w.decision_roll(src, "corroborate_relay", C.RELAY_CORROBORATE, {}, n.id):
		lines.append(say(src, "That was me."))
		for l in w.living():
			if l != n and l != src:
				acknowledge_reading(w, l, src, e, n.id)
		_public_disclosure(w, src, lines, facts)

## The source has explicitly said "That was me" in public. Binding this particular
## anonymous telling is now permitted; unrelated anonymous stories remain unresolved.
static func acknowledge_reading(w, listener, source, entry: Dictionary, teller: String) -> void:
	if listener.is_evil():
		shadow_run(w, listener, func(sh): acknowledge_reading(w, sh, source, entry, teller))
		return
	var eid = info_eid(source.id, entry)
	if not listener.ledger.has(eid):
		return
	var meta: Dictionary = listener.ledger[eid].meta
	var receipts: Dictionary = meta.get("workshop_receipts", {})
	var anonymous = WorkshopLedger.reading(source.id, entry, teller, true)
	if not receipts.has(anonymous.id):
		return
	var paths: Array = receipts[anonymous.id].get("provenance_paths", []).duplicate(true)
	receipts.erase(anonymous.id)
	var named = WorkshopLedger.reading(source.id, entry, teller)
	named["heard_in_public"] = true
	named.provenance.origin_certainty = "public_acknowledgement"
	paths.append(named.provenance.duplicate(true))
	if receipts.has(named.id):
		for path in receipts[named.id].get("provenance_paths", []):
			if path not in paths:
				paths.append(path.duplicate(true))
	named.provenance_paths = paths
	receipts[named.id] = named
	recompute_beliefs(w, listener, " (reading source publicly acknowledged)")

## What going public with their gift would cost n right now (higher = more reluctant):
## gifts that hide from the demon or keep paying off, fear, privacy; less as the game
## wears on or the town thins out. 0 if they've already claimed it.
static func reveal_cost(w, n) -> Dictionary:
	if n.claim_public:
		return {}
	var role: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var parts = {"privacy": (trait_of(n, "privacy") - 0.5) * 0.8, "base": 0.2}
	C.role_def(role).score_reveal_cost(w, n, parts)
	if _afraid(w, n):
		parts["afraid"] = 0.35
	parts["day"] = -0.12 * (w.day - 1)
	if w.living().size() <= 4:
		parts["few_left"] = -0.6
	return parts

## The four ways a good NPC with a reason to suspect t can speak at the meeting:
##   "silent"  (didn't want to accuse at all; decided by the caller)
##   "generic" no reason to protect: "I don't trust X." with whatever they can cite;
##   "hint"    a reason they won't give yet: "I have a reason to suspect X, but I'm not
##             ready to share it yet.";
##   "reveal"  claim their gift (if not yet claimed) and give the reading.
static func _accuse_tier(w, n, t, s2: float) -> Dictionary:
	var result = _accuse_tier_impl(w, n, t, s2)
	var logged: Dictionary = result.duplicate(true)
	if logged.get("src") is Object:
		logged["src"] = logged["src"].id
	w.dlog.decision(n.id, "public_accusation_disclosure", "outcome", logged,
		{"suspicion": s2, "public": n.claim_public}, t.id)
	return result

static func _accuse_tier_impl(w, n, t, s2: float) -> Dictionary:
	var rs = reason_status(w, n, t.id)
	if rs["kind"] in ["none", "public"]:
		return {"tier": "generic", "why": rs["why"]}
	if rs["kind"] in ["shared_player", "shared_private"]:
		return {"tier": "generic", "why": ""} # A joint private reason is not necessarily their own gift to reveal.
	if rs["kind"] == "relay":
		return {"tier": "relay", "why": "", "src": rs["src"], "entry": rs["entry"]}
	var cost = reveal_cost(w, n)
	var parts = {"strength": (rs["strength"] - 0.45) * 1.4, "suspicion": (s2 - 0.75) * 1.2,
		"confidence": (trait_of(n, "confidence") - 0.5) * 0.6}
	for k in cost:
		parts["cost_" + k] = -cost[k]
	if decide(w, n, "reveal_to_accuse", parts, "Go public with what points at %s (%s)?" % [t.id, rs["why"]]):
		return {"tier": "reveal", "why": rs["why"], "entry": rs["entry"]}
	return {"tier": "hint", "why": ""}

## Called at the actual disclosure, including inside a streamed speaker's turn.
## The promise itself still lapses through Game._break_confidences as before.
static func _public_disclosure(w, n, lines: Array, facts: Array, share_readings: bool = true) -> void:
	if not n.claim_public and n.dialogue_memory.get("confidence_requested", false):
		lines.append(say(n, "I've decided the town should hear it."))
		n.dialogue_memory.erase("confidence_requested")
	_go_public(w, n, lines, facts, share_readings)

## Come out with their gift at the meeting (if not already) and share their unshared
## readings with the town. Adds the lines and cards; shared by the claim step and the
## reveal tier of an accusation.
static func _go_public(w, n, lines: Array, facts: Array, share_readings: bool = true) -> void:
	if not n.claim_public:
		var claim: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
		n.claimed_role = claim
		n.claim_public = true
		n.max_tier = maxi(n.max_tier, 3)
		w.public_claims.append({"day": w.day, "who": n.id, "role": claim})
		lines.append(_claim_line(n, claim))
		facts.append({"kind": "claim", "subject": [n.id], "role": claim, "source": n.id,
			"text": "%s publicly claims to be the %s." % [n.name, C.role_name(claim)]})
		for l in w.living():
			if l != n:
				hear_claim(w, l, n.id, claim, 0.5, "public")
	if share_readings and C.has_readings(n.claimed_role):
		var shared_this_turn: Array = []
		for e in n.info_log:
			if e["shared"] or e.get("disowned", false):
				continue
			e["shared"] = true
			var weights = {}
			for x in implicated(e):
				weights[x] = reading_strength(e, x)
			w.public_event("reading", implicated(e), n.id, {"weights": weights})
			w.public_event("clear", Gifts.clears(e), n.id)
			shared_this_turn.append(e)
			facts.append(info_fact(w, n, e))
			for l in w.living():
				if l != n:
					apply_info(w, l, n, e, heard_weight(l, n))
		lines.append_array(info_lines(w, n, shared_this_turn, "town", not lines.is_empty(), "volunteer"))

## Last words are a claim and a spoken suspicion, not a fresh evidence argument.
## Reuse ordinary public claiming without adding the speaker's reading backlog.
static func last_words(w, n) -> Dictionary:
	if n.silenced:
		return {"lines": ["%s tries to speak, but no sound comes. Their voice is still stolen." % n.name], "facts": []}
	var lines: Array = []
	var facts: Array = []
	var claim: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var already_claimed: bool = n.claim_public and n.claimed_role == claim
	if n.claim_public and n.claimed_role != claim:
		n.claim_public = false # With nothing to hide, correct their earlier claim.
	_public_disclosure(w, n, lines, facts, false)
	if lines.is_empty():
		if already_claimed:
			lines.append(say(n, "As I've said, I am the %s." % C.role_name(claim)))
		else:
			lines.append(_claim_line(n, claim))
		facts.append({"kind": "claim", "subject": [n.id], "role": claim, "source": n.id,
			"text": "%s publicly claims to be the %s." % [n.name, C.role_name(claim)]})
	var suspect = ""
	if n.is_evil():
		suspect = w.evil_plan.get("scapegoat", "")
	else:
		var ranked: Array = ranked_suspects(w, n)
		if not ranked.is_empty(): suspect = ranked[0].id
	if suspect != "" and w.by_id.has(suspect) and w.by_id[suspect].alive and suspect != n.id:
		lines.append(say(n, "I still suspect %s." % w.by_id[suspect].name))
	return {"lines": lines, "facts": facts}

static func _public_accusation(w, n, lines: Array = [], facts: Array = []):
	if n.silenced:
		return null
	var t = null
	var s2 = 0.0
	var why = ""
	if n.is_evil():
		var sg: String = w.evil_plan["scapegoat"]
		if sg == "" or not w.by_id[sg].alive or w.day < 2:
			return null
		t = w.by_id[sg]
		s2 = 0.8
		why = Evil.bluff_reason(w, n, t)
	else:
		var ranked = ranked_suspects(w, n)
		if ranked.is_empty():
			return null
		t = ranked[0]
		s2 = susp(n, t.id)
	var parts = {"suspicion": (s2 - 0.6) * 1.5, "confidence": (trait_of(n, "confidence") - 0.5) * 0.8,
		"pressure_deflect": n.pressure * 0.4}
	if not decide(w, n, "accuse", parts, "Publicly accuse %s?" % t.id):
		return null
	# What they can say for it: a reason the town already has, a hint at one they're
	# keeping back, or their gift and its reading brought out now.
	var hint = false
	if n.is_evil():
		# A hinted "private reason" must fit the bluff: a gift that gives readings, with a
		# fake one ready that points at the target, or (sometimes) none yet, as a free bluff
		# they'll decline to back up if asked.
		var bluff: String = w.evil_plan["bluffs"].get(n.id, "")
		if why == "" and C.has_readings(bluff) and (_unshared_fake_on(n, t.id) != {} or w.decision_roll(n, "hint_without_reading", C.EVIL_HINT_CHANCE, {}, t.id)):
			hint = true
		w.dlog.think(n.id, "lie", "Evil: publicly accuses scapegoat %s, citing: %s." % [t.id, "a hinted private reason" if hint else why if why != "" else "vibes"])
	else:
		var tier = _accuse_tier(w, n, t, s2)
		if tier["tier"] == "reveal":
			_public_disclosure(w, n, lines, facts)
		elif tier["tier"] == "relay":
			relay_reading(w, n, tier["src"], tier["entry"], lines, facts)
		hint = tier["tier"] == "hint"
		why = tier["why"]
		w.dlog.think(n.id, "accuse_tier", "Accuses %s: %s%s." % [t.id, tier["tier"], (" (" + why + ")") if why != "" else ""])
	if hint:
		n.hints[t.id] = {"day": w.day, "src": n.sus_src.get(t.id, "")}
	why = Evil.cite(w, n, why)
	if not hint and why.begins_with("I saw"):
		_append_accusation_sighting(w, n, t, why, lines, facts)
	var prev_target: String = w.stances.get(n.id, {}).get("target", "")
	w.stances[n.id] = {"target": t.id, "day": w.day, "hint": hint}
	for l in w.living():
		refresh_consensus(w, l, t.id)
		if prev_target != "" and prev_target != t.id:
			refresh_consensus(w, l, prev_target)
	# Scrutiny rises with each voice, but less for each one that only joins in.
	var earlier: Array = w.meeting.get("accusations", []).filter(func(a): return a["target"] == t.id)
	t.pressure += 0.15 * pow(0.5, earlier.size())
	w.public_event("accusation", [t.id], n.id)
	var line: Dictionary
	if not earlier.is_empty():
		# Someone already said it: agree rather than restate their grounds. Only grounds of
		# their own (their reading, what they saw) are worth adding.
		var first = w.by_id[earlier[0]["by"]]
		var own = why.begins_with("my own") or why.begins_with("I ")
		var extra = " I have my own reason, but I'm not ready to share it yet." if hint else ((" " + why[0].to_upper() + why.substr(1) + ".") if own else "")
		line = say(n, "I agree with %s about %s.%s" % [first.name, t.name, extra])
	elif hint:
		line = say(n, "I have a reason to suspect %s, but I'm not ready to share it yet." % t.name)
	else:
		var tail = (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else " Something's off about them."
		line = say(n, "I don't trust %s.%s" % [t.name, tail])
	if w.meeting.has("accusations"):
		w.meeting["accusations"].append({"by": n.id, "target": t.id})
	var text = ("%s publicly accused %s, hinting at a private reason they won't share yet." if hint else "%s publicly accused %s.") % [n.name, t.name]
	return {"line": line,
		"fact": {"kind": "accusation", "subject": [t.id], "source": n.id, "text": text, "hint": hint}}

## A spoken observation must leave the same usable card as asking the witness privately.
static func _append_accusation_sighting(w, n, target, why: String, lines: Array, facts: Array) -> void:
	var candidates: Array = []
	if n.is_evil():
		for key in w.evil_plan.get("fake_sightings", {}):
			var b = w.evil_plan["fake_sightings"][key]
			if key.begins_with(n.id + ":") and b is Dictionary and b.get("who", "") == target.id:
				candidates.append(b)
	else:
		candidates = n.beliefs.filter(func(b): return b.get("kind", "") == "saw" and b.get("who", "") == target.id and b.get("phase", -1) == C.NIGHT)
	candidates = candidates.filter(func(b): return (b.get("how", "street") == "window") if "window" in why else C.block_name(b.get("block", "")) in why)
	candidates.sort_custom(func(a, b): return a["day"] > b["day"])
	if candidates.is_empty():
		return
	var seen: Dictionary = candidates[0]
	if n.told_to.has(_town_sighting_key(n, seen)): return
	n.told_to[_town_sighting_key(n, seen)] = true
	var report = sighting_report(w, n, seen, seen["day"])
	var night_label: String = C.night_name(seen["day"])
	if not (night_label in report["line"]["text"] or ("night %d" % seen["day"]) in report["line"]["text"]):
		report["line"]["text"] = "On %s: %s" % [night_label, report["line"]["text"]]
	lines.append(report["line"])
	facts.append(report["fact"])

## Peer pressure: what public accusations add to a listener's action score.
## Each accuser counts once (their latest stance), older accusations fade, and
## each further voice adds half as much as the one before, so a chorus can't bury someone.
## The crowd supplies no evidence, source dishonesty or world-prior weight.
const CONSENSUS_BASE = Tuning.Meeting.CONSENSUS_BASE
const CONSENSUS_FADE = Tuning.Meeting.CONSENSUS_FADE
const CONSENSUS_CAP = Tuning.Meeting.CONSENSUS_CAP
const CONSENSUS_HINT = Tuning.Meeting.CONSENSUS_HINT  # "I have a reason, but I'm not ready to share it": a little more than a bare accusation

static func refresh_consensus(w, l, target: String) -> void:
	if l.is_evil():
		shadow_run(w, l, func(sh): refresh_consensus(w, sh, target))
		return
	if l.id == target or not l.suspicion.has(target):
		return
	var vals: Array = []
	for a in w.stances:
		var st: Dictionary = w.stances[a]
		if st["target"] != target or a == l.id or a == target:
			continue
		var bond: float = l.npc_trust.get(a, 0.5)
		var hint_w = CONSENSUS_HINT if st.get("hint", false) else 1.0
		vals.append(CONSENSUS_BASE * hint_w * (0.5 + bond) * pow(CONSENSUS_FADE, w.day - st["day"]))
	vals.sort()
	vals.reverse()
	var want = 0.0
	for i in range(vals.size()):
		want += vals[i] * pow(0.5, i)
	want = minf(want, CONSENSUS_CAP)
	var have: float = l.consensus_pressure.get(target, 0.0)
	if absf(want - have) < 0.002:
		return
	l.consensus_pressure[target] = want
	var what = ("town consensus: %d voice(s) against them" % vals.size()) if want > have else ("town consensus fading (%d older voice(s) against them)" % vals.size())
	w.dlog.think(l.id, "social_pressure", what, {"target": target, "before": have, "after": want})

static func refresh_all_consensus(w) -> void:
	var targets = {}
	for a in w.stances:
		targets[w.stances[a]["target"]] = true
	for listener in w.living():
		var mind = listener.shadow if listener.is_evil() and listener.shadow != null else listener
		for target in mind.consensus_pressure:
			targets[target] = true
	for l in w.living():
		for t in targets:
			refresh_consensus(w, l, t)

## Whom a good NPC would nominate now, or null.
static func _good_nomination(w, n, m: Dictionary, block: String):
	var id = w.dlog.decision(n.id, "nomination", "start", null, {"block": block,
		"nominated": m["nominated"], "confidence": trait_of(n, "confidence"),
		"paranoia": paranoia(w, n), "day": w.day})
	var result = _good_nomination_impl(w, n, m, block, id)
	w.dlog.decision(n.id, "nomination", "outcome", result, {}, "", id)
	return result

static func _good_nomination_impl(w, n, m: Dictionary, block: String, trace_id: int):
	var thr: float = maxf(Tuning.Meeting.NOMINATION_FLOOR, Tuning.Meeting.NOMINATION_BASE - Tuning.Meeting.NOMINATION_DAY_SLOPE * w.day) - Tuning.Meeting.NOMINATION_CONFIDENCE_SCALE * (trait_of(n, "confidence") - 0.5) * 2.0 - Tuning.Meeting.NOMINATION_PARANOIA_SCALE * paranoia(w, n)
	for t in ranked_suspects(w, n, true):
		if t.id in m["nominated"] or t.id == n.id:
			w.dlog.decision(n.id, "nomination", "gate", false,
				{"gate": "already_nominated_or_self"}, t.id, trace_id)
			continue
		var s = action_susp(n, t.id)
		if n.cleared.has(t.id):
			s -= 0.2  # their own sight said this person is no demon
		w.dlog.decision(n.id, "nomination", "evaluation", s >= thr, {"score": s,
			"raw_suspicion": susp(n, t.id), "town_pressure": action_susp(n, t.id) - execution_priority_contribution(n, t.id) - susp(n, t.id), "own_clear_adjustment": -0.2 if n.cleared.has(t.id) else 0.0,
			"shared_execution_priority": execution_priority(n, t.id), "shared_execution_weight": C.SHARED_EXECUTION_PRIORITY_WEIGHT,
			"threshold": thr, "comparison": ">=",
			"threshold_parts": {"day_base": maxf(0.45, 0.86 - 0.08 * w.day),
				"confidence": -0.15 * (trait_of(n, "confidence") - 0.5) * 2.0,
				"paranoia": -0.5 * paranoia(w, n)}}, t.id, trace_id)
		if s < thr:
			continue
		if block != "" and action_susp(n, block) >= s:
			w.dlog.decision(n.id, "nomination", "gate", false, {"gate": "prefers_existing_block",
				"block": block, "block_suspicion": action_susp(n, block), "candidate_score": s}, t.id, trace_id)
			return null  # content with who is already on the block
		return {"nominee": t.id, "by": n.id, "score": s,
			"reason": "suspicion of %s %.2f >= threshold %.2f" % [t.id, s, thr]}
	return null

## Shadow self (step 2): evil nominates as its good self would. Naming a teammate is
## high stakes (overridden unless caution has worn thin); pushing the scapegoat when the
## good self wouldn't nominate is an override that's cheap once the town is already hot on them.
static func _evil_nomination(w, n, m: Dictionary, block: String):
	var ev = Evil.evil_nomination(w, n)
	if not C.SHADOW_SELF:
		return ev
	var sc = shadow_eval(w, n, func(sh): return _good_nomination(w, sh, m, block))
	if sc != null:
		sc["by"] = n.id
		if w.by_id[sc["nominee"]].role == "demon":
			w.dlog.think(n.id, "team_survival", "Protects the demon: maintaining cover cannot justify nominating them.")
			return ev
		if Evil.is_teammate(w, n, sc["nominee"]):
			var stakes = 0.8 * Evil.teammate_value(w, sc["nominee"])
			if evil_override(w, n, "nomination", stakes, 1.0, "good self would nominate teammate %s" % sc["nominee"]):
				return ev
			sc["reason"] = "Evil (good self): nominates teammate %s; %s" % [sc["nominee"], sc["reason"]]
		return sc
	if ev == null:
		return null
	var sg = w.by_id[ev["nominee"]]
	if evil_override(w, n, "nomination", 0.4 + Evil.public_heat(w, sg), 0.5, "push scapegoat %s (good self wouldn't nominate)" % sg.id):
		return ev
	return null

## Next NPC nomination, or null. Respects BotC limits and who is already on the block.
static func next_nomination(w):
	var m: Dictionary = w.meeting
	var cands: Array = []
	var block: String = m["block"]
	for n in w.living():
		if n.id in m["nominators"] or n.silenced:
			w.dlog.decision(n.id, "nomination", "gate", false,
				{"gate": "silenced" if n.silenced else "no_nominations_remaining"})
			continue
		if n.is_evil():
			var ev = _evil_nomination(w, n, m, block)
			if ev != null:
				cands.append(ev)
			continue
		var gc = _good_nomination(w, n, m, block)
		if gc != null:
			cands.append(gc)
	if cands.is_empty():
		w.dlog.decision("world", "nomination_selection", "outcome", null, {"candidates": []})
		return null
	cands.sort_custom(func(a, b): return a["score"] > b["score"])
	w.dlog.decision("world", "nomination_selection", "outcome", cands[0], {"candidates": cands})
	var c: Dictionary = cands[0]
	w.dlog.think(c["by"], "nominate", c["reason"], {"nominee": c["nominee"]})
	var nom = w.by_id[c["by"]]
	var t = w.by_id[c["nominee"]]
	var why: String = Evil.cite(w, nom, Evil.bluff_reason(w, nom, t) if nom.is_evil() else citable_reason(w, nom, t.id, "town"))
	c["speech"] = decision_line(nom, {"kind": "nomination", "target": t.name,
		"reason_text": (why[0].to_upper() + why.substr(1) + ".") if why != "" else ""}, "town")
	var cs = nomination_case(w, nom, t, why)
	c["case_lines"] = cs["lines"]
	c["case_facts"] = cs["facts"]
	return c

# ---------------------------------------------------------------- the nominator's case

## What drove n's suspicion of t most (meeting-flow plan, step 1): ledger entries ranked by
## how much they now add to it, at most `limit`. Each item: {eid, why, kind, strength,
## entry}, with kind as in reason_status (public | player | private) for that entry. An
## evil nominator ranks its good self's ledger (what an innocent would cite) but its own
## readings (real or fake) are looked up on the real NPC.
static func case_against(w, n, t_id: String, limit: int = 3) -> Array:
	var mind = n
	if n.is_evil():
		mind = n.shadow if n.shadow != null else n
	var items: Array = []
	for e in mind.ledger.values():
		var contrib = 0.0
		var why = ""
		var effs: Array = e["effects"]
		for i in range(effs.size()):
			var f: Array = effs[i]
			if f[0] != t_id:
				continue
			var a: float = e["applied"].get(i, 0.0) + e["applied"].get("%d:%s" % [i, t_id], 0.0)
			if a > 0.0:
				contrib += a
				if why == "" and f[4] != "":
					why = f[4]
		if contrib >= 0.03 and why != "":
			items.append({"eid": e["eid"], "why": why, "contrib": contrib})
	items.sort_custom(func(x, y): return x["contrib"] > y["contrib"])
	items = items.slice(0, limit)
	var own = "info:%s:" % n.id
	for it in items:
		it["kind"] = "public"
		it["strength"] = 0.3
		it["entry"] = {}
		if it["eid"].begins_with(own):
			for i in range(n.info_log.size()):
				var en: Dictionary = n.info_log[i]
				if info_eid(n.id, en) == it["eid"]:
					it["entry"] = en
					it["strength"] = reading_strength(en, t_id)
					it["kind"] = "public" if en.get("shared", false) else ("player" if i < n.told_readings else "private")
		elif it["eid"].begins_with("info:"):
			var hr = _heard_reading(w, n, it["eid"])
			if not hr.is_empty():
				it["kind"] = "relay"
				it["entry"] = hr["entry"]
				it["src"] = hr["src"]
		# Wording that gives away their own gift is private until the gift is public (the
		# same rule Evil.cite applies to accusations), whatever entry it came from.
		if it["kind"] == "public" and it["why"].begins_with("my own") and not n.claim_public:
			it["kind"] = "private"
			it["strength"] = maxf(it["strength"], 0.5)
	return items

## The nominator lays out their case: public reasons recapped (cosmetic: hearing them again
## changes nothing), and their strongest private one hinted at or brought out (claim and
## reading, with their usual effect, as at any other time). Returns {lines, facts}.
static func nomination_case(w, n, t, already: String) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var items = case_against(w, n, t.id)
	var recap: Array = items.filter(func(x): return x["kind"] == "public" and x["why"] != already).map(func(x): return x["why"])
	var priv: Array = items.filter(func(x): return x["kind"] in ["private", "player"])
	var relays: Array = items.filter(func(x): return x["kind"] == "relay")
	if priv.is_empty() and not relays.is_empty():
		relay_reading(w, n, relays[0]["src"], relays[0]["entry"], lines, facts)
	var description = ", ".join(PackedStringArray(items.map(func(x): return "%s (%s, %.2f)" % [x["why"], x["kind"], x["contrib"]])))
	w.dlog.think(n.id, "nomination_case", "Case against %s: %s." % [t.id, description if description != "" else "no citable reasons on record"], {"items": items.map(func(x): return {"eid": x["eid"], "kind": x["kind"]})})
	if items.is_empty():
		lines.append(say(n, "I don't trust %s, and I can't say better than that." % t.name))
	if not recap.is_empty():
		lines.append(say(n, "Remember: %s." % "; and ".join(PackedStringArray(recap.slice(0, 2)))))
	if not priv.is_empty():
		var top: Dictionary = priv[0]
		var cost = reveal_cost(w, n)
		var parts = {"strength": (top["strength"] - 0.45) * 1.4, "suspicion": (susp(n.shadow if n.is_evil() and n.shadow != null else n, t.id) - 0.75) * 1.2,
			"confidence": (trait_of(n, "confidence") - 0.5) * 0.6, "nominating": 0.2}
		for k in cost:
			parts["cost_" + k] = -cost[k]
		if decide(w, n, "reveal_to_nominate", parts, "Bring out what points at %s (%s) to back the nomination?" % [t.id, top["why"]]):
			_public_disclosure(w, n, lines, facts)
		else:
			n.hints[t.id] = {"day": w.day, "src": top["eid"]}
			lines.append(say(n, "And I have another reason I'm not ready to share yet."))
			facts.append({"kind": "accusation", "subject": [t.id], "source": n.id, "hint": true,
				"text": "%s nominated %s, hinting at a private reason they won't share yet." % [n.name, t.name]})
	return {"lines": lines, "facts": facts}

# ---------------------------------------------------------------- the defence

## The nominee answers (meeting-flow plan, step 2). One or two moves, chosen from what's
## against them and what they have:
##   reveal    a night-walking gift explains being out: claim it and share readings
##             (normal claim effects), plus an excuse for the sightings;
##   secret    a good NPC's personal reason for being out, confessed;
##   red_herring / pair_other / misled / lying   against a reading that names them;
##   fear / desperation   when there's nothing else ("I know I'm not evil").
## Each underlying defence has one stable ledger identity, independently of the
## day it is repeated. A challenge to a different original reading is distinct.
## weighed by the listener's regard for the defender and the defender's credibility, so
## it rises and falls with them. Only a reveal carries real weight; the rest sway little.
## Evil defends as the good townsperson it pretends to be: its bluff stands in for its gift,
## and it has no secret to confess. Returns {lines, facts, moves}.
static func defend_self(w, d, nominator_id: String) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var moves: Array = []
	if d.silenced:
		return {"lines": [{"speaker": d.id, "name": d.name, "text": "...", "silent": true}], "facts": [], "moves": ["silenced"]}
	var accuser = w.by_id.get(nominator_id) if nominator_id != "player" else null
	if accuser == null:
		var best = -1.0
		for m in w.living_good():
			if m != d and susp(m, d.id) > best:
				best = susp(m, d.id)
				accuser = m
	var items: Array = case_against(w, accuser, d.id) if accuser != null else []
	var role: String = w.evil_plan["bluffs"].get(d.id, "") if d.is_evil() else d.role
	var out_items: Array = items.filter(func(x): return "out" in x["why"] or "night" in x["why"])
	var out_weight = 0.0
	for x in out_items:
		out_weight += x["contrib"]
	var effs_by_move = {}
	var defence_scopes = {}
	# 1. A gift that walks at night explains being seen out.
	if not out_items.is_empty() and C.ROLES.get(role, {}).get("night_walk", false):
		var parts = {"facing_the_rope": C.DEFENCE_ROPE, "strength": 0.2}
		for k in reveal_cost(w, d):
			parts["cost_" + k] = -reveal_cost(w, d)[k]
		if d.claim_public or decide(w, d, "defence_reveal", parts, "Explain being out with my gift (%s)?" % role):
			if not d.claim_public:
				_public_disclosure(w, d, lines, facts)
			lines.append(say_voiced(d, "defence_reveal", "I was out because I'm the %s. That's what you saw." % C.role_name(role), {"role": C.role_name(role)}))
			moves.append("reveal")
			effs_by_move["reveal"] = [[d.id, -minf(0.35, out_weight), true, "excused: out at night as the %s" % C.role_name(role), ""]]
			defence_scopes["reveal"] = {"type": "gift_claim", "role": role}
	# 2. A personal secret explains it (good only: evil has nothing true to confess).
	if moves.is_empty() and not out_items.is_empty() and not d.is_evil() and not d.secret.is_empty():
		if decide(w, d, "defence_confess", {"facing_the_rope": 0.5, "privacy": (0.4 - trait_of(d, "privacy")) * 1.0}, "Confess my secret to explain being out?"):
			d.secret_known = true
			lines.append(say(d, "I wasn't out for anything wicked. I %s." % d.secret.get("me", d.secret.get("text", ""))))
			facts.append({"kind": "secret", "subject": [d.id], "owner": d.id, "source": d.id,
				"secret_kind": d.secret.get("kind", ""), "mod": "lovers" if d.secret.get("kind", "") == "lover" else "",
				"text": "%s confessed at the meeting why they were out: %s %s." % [d.name, d.name, d.secret.get("text", "")]})
			moves.append("secret")
			effs_by_move["secret"] = [[d.id, -minf(0.3, out_weight), true, "excused: a personal secret", ""]]
			defence_scopes["secret"] = {"type": "secret_claim", "owner": d.id, "kind": d.secret.get("kind", "")}
	# 2b. "I've been known to sleepwalk": the real Sleepwalker (who can't know they were
	# out, only that they've walked before) or an evil bluffer whose cover needs it.
	if moves.is_empty() and not out_items.is_empty():
		var excuse: Dictionary = sleepwalk_excuse(w, d, "the meeting")
		if not excuse.is_empty():
			lines.append(excuse["line"])
			facts.append(excuse["fact"])
			moves.append("sleepwalk")
			effs_by_move["sleepwalk"] = [[d.id, -minf(0.3, out_weight), true, "excused: says they sleepwalk", ""]]
			defence_scopes["sleepwalk"] = {"type": "secret_claim", "owner": d.id, "kind": "sleepwalker"}
	# 3. Against a reading that names them.
	if moves.size() < 2:
		var rd = {}
		var src_id = ""
		for x in items:
			if x["eid"].begins_with("info:"):
				var parts2 = x["eid"].split(":")
				var sn = w.by_id.get(parts2[1])
				if sn == null or sn == d:
					continue
				for en in sn.info_log:
					if info_eid(sn.id, en) == x["eid"]:
						rd = en
						src_id = sn.id
				if not rd.is_empty():
					break
		if not rd.is_empty():
			var dd: Dictionary = rd.get("data", {})
			var pair: Array = dd.get("pair", [])
			var src = w.by_id[src_id]
			var rdef_rd = C.role_def(rd.get("role", ""))
			var custom_def: Dictionary = rdef_rd.try_reading_defence(w, d, src, src_id, rd, _mind(), WorkshopLedger) if rdef_rd != null else {}
			if custom_def.get("handled", false):
				var mv_name: String = custom_def["move"]
				lines.append(custom_def["line"])
				moves.append(mv_name)
				effs_by_move[mv_name] = custom_def["effs"]
				defence_scopes[mv_name] = custom_def["scope"]
			elif pair.size() == 2 and d.id in pair:
				# One incident, one hearing: "it's the other one" accepts the reading, "the
				# reading is wrong" rejects it, so never both. Point at the other only when
				# that's what they believe (good: they suspect the other at least as much as
				# the source; evil: the other isn't a teammate); otherwise challenge it below.
				var other: String = pair[0] if pair[1] == d.id else pair[1]
				var fits: bool = (not Evil.is_teammate(w, d, other)) if d.is_evil() else susp(d, other) >= susp(d, src_id)
				if fits and w.by_id.has(other) and w.by_id[other].alive:
					lines.append(say(d, "One of the two, %s said. It isn't me, so look at %s." % [src.name, w.by_id[other].name]))
					moves.append("pair_other")
					effs_by_move["pair_other"] = [[d.id, -0.06, true, "points at the other one in the pair", ""], [other, 0.06, true, "%s says it's the other one in the pair" % d.name, ""]]
					defence_scopes["pair_other"] = {"type": "rival", "source": src_id, "other": other}
			if moves.size() < 2 and not ("red_herring" in moves) and not ("pair_other" in moves):
				if trait_of(d, "confidence") > 0.6:
					lines.append(say_voiced(d, "defence_lying", "Then %s is lying, and you should ask yourselves why." % src.name, {"source": src.name}))
					moves.append("lying")
					effs_by_move["lying"] = [[d.id, -0.05, true, "says the reading against them is a lie", ""], [src_id, C.DEFENCE_LIE_BLOWBACK, true, "%s says they lied" % d.name, ""]]
					defence_scopes["lying"] = {"type": "challenge", "mode": "lying", "reading": WorkshopLedger.reading(src_id, rd).id}
				else:
					lines.append(say_voiced(d, "defence_misled", "%s's gift could have been turned. It's happened before." % src.name, {"source": src.name}))
					moves.append("misled")
					effs_by_move["misled"] = [[d.id, -0.06, true, "says the reading against them was misled", ""]]
					defence_scopes["misled"] = {"type": "challenge", "mode": "misled", "reading": WorkshopLedger.reading(src_id, rd).id}
	# 4. Nothing to show: fear, or the desperation play.
	if moves.is_empty():
		if _afraid(w, d) and not d.claim_public:
			lines.append(say(d, "If I say what I am, I'll be dead by morning. But I'm not what you think."))
			moves.append("fear")
		else:
			lines.append(say_voiced(d, "defence_desperation", "I don't know what's going on, but I know I'm not evil."))
			moves.append("desperation")
		effs_by_move[moves[0]] = [[d.id, -0.02, true, "pleads innocence", ""]]
		defence_scopes[moves[0]] = {"type": "plea"}
	for mv in effs_by_move:
		var scope: Dictionary = defence_scopes[mv]
		var identity: String = "def:%s:%s:%s" % [d.id, scope.type, JSON.stringify(WorkshopLedger.Evidence.canonical(scope)).sha256_text()]
		var effects: Array = effs_by_move[mv].duplicate(true)
		var strength = 1.0
		if mv in ["reveal", "secret"]:
			# Keep the strongest complete hearing, rather than borrowing a strong
			# excuse's magnitude and a different hearing's stronger trust weight.
			strength = -float(effects[0][1])
			effects[0][1] = -1.0
		for l in w.living():
			if l == d:
				continue
			var meta = {"kind": "defence", "move": mv, "scope": scope.duplicate(true), "hearing_scale": 1.0}
			if scope.type == "gift_claim":
				meta["workshop_card"] = WorkshopLedger.Evidence.normalize_card({"kind": "claim", "source": d.id, "subject": [d.id], "role": scope.role, "day": w.day, "phase": w.phase, "text": "Walking-gift defence."})
			elif scope.type == "secret_claim":
				meta["workshop_card"] = WorkshopLedger.Evidence.normalize_card({"kind": "secret", "source": d.id, "subject": [d.id], "owner": d.id, "secret_kind": scope.kind, "day": w.day, "phase": w.phase, "text": "Confessed errand defence."})
			else:
				meta.hearing_scale = 0.0
				for effect in effects:
					meta.hearing_scale = maxf(meta.hearing_scale, absf(float(effect[1])))
			if l.ledger.get(identity, {}).get("meta", {}).has("workshop_card"):
				meta["workshop_card"] = l.ledger[identity].meta.workshop_card
			ledger_hear(w, l, identity, effects, strength * (0.5 + 0.5 * l.npc_trust.get(d.id, 0.5)),
				[d.id, -1, "report"], meta)
	w.dlog.think(d.id, "defence", "Defends against %s: %s." % [nominator_id, ", ".join(PackedStringArray(moves))], {"moves": moves, "evil": d.is_evil()})
	return {"lines": lines, "facts": facts, "moves": moves}

static func defence_line(w, n) -> Dictionary:
	if n.silenced:
		return {"speaker": n.id, "name": n.name, "text": "...", "silent": true}
	var c = trait_of(n, "confidence")
	var fallback = "You've got the wrong person."
	if c > 0.66:
		fallback = "This is madness, and you all know it."
	elif c < 0.34:
		fallback = "P-please. I've done nothing."
	return say_voiced(n, "defence_line", fallback)

## One NPC's vote on a nomination. statement: "", "defend" or "accuse" (the player's).
static func vote(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int) -> bool:
	var id = w.dlog.decision(v.id, "vote", "start", null, {"nominator": nominator,
		"player_yes": player_yes, "statement": statement, "yes_so_far": yes_so_far,
		"route": "self" if v.id == nominee else "evil_strategy" if v.is_evil() else "good_threshold"}, nominee)
	var result = _vote_impl(w, v, nominee, nominator, player_yes, statement, yes_so_far, id)
	w.dlog.decision(v.id, "vote", "outcome", result, {}, nominee, id)
	return result

static func _vote_impl(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int, trace_id: int) -> bool:
	if v.id == nominee:
		w.dlog.think(v.id, "vote", "Votes no on own execution.", {"nominee": nominee, "yes": false})
		return false
	if v.is_evil():
		var evil_yes: bool = Evil.evil_vote(w, v, nominee, yes_so_far, player_yes)
		if w.by_id[nominee].role == "demon":
			w.dlog.think(v.id, "team_survival", "Votes no on the demon: later voters can make even an early vote decisive.")
			return false
		if not C.SHADOW_SELF:
			return evil_yes
		# Shadow self (step 2): vote as their good self would, unless breaking cover is worth it.
		var sh_yes = shadow_eval(w, v, func(sh): return vote(w, sh, nominee, nominator, player_yes, statement, yes_so_far))
		if sh_yes == null or sh_yes == evil_yes:
			return evil_yes
		var have = yes_so_far + (1 if player_yes else 0)
		var pivot = 1.0 if absi(have + 1 - w.vote_threshold()) <= 1 else 0.35
		var stakes = 0.3
		if Evil.is_teammate(w, v, nominee):
			stakes = Evil.teammate_value(w, nominee) * pivot if not evil_yes else 0.6
		elif evil_yes:
			stakes = (0.5 + (0.3 if nominee == w.evil_plan.get("scapegoat", "") else 0.0)) * pivot
		var detail = "%s on %s (good self: %s)" % ["YES" if evil_yes else "no", nominee, "yes" if sh_yes else "no"]
		return evil_yes if evil_override(w, v, "vote", stakes, 0.6, detail) else sh_yes
	reconsider(w, v, "thinking it over before the vote")
	var base = action_susp(v, nominee)
	var s = base
	var parts = {"suspicion": snappedf(susp(v, nominee), 0.01), "town_pressure": base - execution_priority_contribution(v, nominee) - susp(v, nominee)}
	if C.SHARED_EXECUTION_PRIORITY_WEIGHT != 0.0:
		parts["shared_execution_priority"] = execution_priority_contribution(v, nominee)
	if player_yes:
		parts["player_votes_yes"] = 0.25 * v.trust - 0.05
	if statement == "defend":
		parts["player_defends"] = -0.25 * v.trust
	elif statement == "accuse":
		parts["player_accuses"] = 0.2 * v.trust
	parts["trust_in_nominee"] = -(v.npc_trust.get(nominee, 0.5) - 0.5) * 0.6
	if nominator != "player" and susp(v, nominator) > 0.7:
		parts["distrusts_nominator"] = -0.15
	if v.spare_pref.get(nominee, 0.0) > 0.0:
		parts["persuaded_to_spare"] = -0.5 * v.spare_pref[nominee]
	var block: String = w.meeting["block"]
	if block != "" and block != nominee and action_susp(v, block) >= base:
		parts["prefers_block"] = -0.4
	C.role_def(v.role).score_vote_reluctance(w, v, nominee, base, paranoia(w, v), parts)
	for k in parts:
		if k not in ["suspicion", "town_pressure", "shared_execution_priority"]:
			s += parts[k]
	var need = Tuning.Meeting.VOTE_BASE_NEED - Tuning.Meeting.VOTE_CONFIDENCE_SCALE * (trait_of(v, "confidence") - 0.5) * 2.0 + (Tuning.Meeting.VOTE_DAY1_PENALTY if w.day <= 1 else 0.0) - Tuning.Meeting.VOTE_PARANOIA_WEIGHT * paranoia(w, v)
	var yes = s >= need
	var exact_parts: Dictionary = parts.duplicate()
	exact_parts["suspicion"] = susp(v, nominee) # pressure is reported separately
	w.dlog.decision(v.id, "vote", "evaluation", yes, {"parts": exact_parts,
		"score": s, "threshold": need, "comparison": ">=", "margin": s - need,
		"inputs": {"confidence": trait_of(v, "confidence"), "composure": trait_of(v, "composure"),
			"paranoia": paranoia(w, v), "trust": v.trust, "trust_in_nominee": v.npc_trust.get(nominee, 0.5), "suspicion": susp(v, nominee)},
		"threshold_parts": {"base": 0.5,
			"confidence": -0.12 * (trait_of(v, "confidence") - 0.5) * 2.0,
			"early_day": 0.1 if w.day <= 1 else 0.0, "paranoia": -0.4 * paranoia(w, v)},
		"trust": v.trust, "block": block, "spare_preference": v.spare_pref.get(nominee, 0.0),
		"shared_execution_priority": execution_priority(v, nominee), "shared_execution_weight": C.SHARED_EXECUTION_PRIORITY_WEIGHT,
		"reluctance_rounding": "martyr contribution retains existing two-decimal rounding"}, nominee, trace_id)
	parts["total"] = snappedf(s, 0.01)
	parts["need"] = snappedf(need, 0.01)
	w.dlog.think(v.id, "vote", "%s on %s (score %.2f vs %.2f)." % ["YES" if yes else "no", nominee, s, need], parts)
	return yes

# ---------------------------------------------------------------- Mind delegates

static func _add_observation(groups: Array, observation: Dictionary) -> void:
	_mind()._add_observation(groups, observation)

static func _afraid(w, n) -> bool:
	return _mind()._afraid(w, n)

static func _observation_lines(n, groups: Array, audience: String, speech_act: String, preceded: bool) -> Array:
	return _mind()._observation_lines(n, groups, audience, speech_act, preceded)

static func action_susp(n, id: String) -> float:
	return _mind().action_susp(n, id)

static func apply_info(w, listener, source, entry: Dictionary, weight: float, via: String = "", anonymous: bool = false) -> void:
	_mind().apply_info(w, listener, source, entry, weight, via, anonymous)

static func decide(w, n, topic: String, parts: Dictionary, why: String) -> bool:
	return _mind().decide(w, n, topic, parts, why)

static func decision_line(n, approved: Dictionary, audience: String = "player") -> Dictionary:
	return _mind().decision_line(n, approved, audience)

static func evil_override(w, n, act: String, stakes: float, deviation: float, detail: String) -> bool:
	return _mind().evil_override(w, n, act, stakes, deviation, detail)

static func execution_priority(n, id: String) -> float:
	return _mind().execution_priority(n, id)

static func execution_priority_contribution(n, id: String) -> float:
	return _mind().execution_priority_contribution(n, id)

static func flush_beliefs(w, only = null) -> void:
	_mind().flush_beliefs(w, only)

static func hear_claim(w, l, who: String, role: String, weight: float, how: String, original: Dictionary = {}) -> void:
	_mind().hear_claim(w, l, who, role, weight, how, original)

static func heard_weight(listener, speaker) -> float:
	return _mind().heard_weight(listener, speaker)

static func implicated(e: Dictionary) -> Array:
	return _mind().implicated(e)

static func info_eid(src: String, entry: Dictionary) -> String:
	return _mind().info_eid(src, entry)

static func ledger_hear(w, n, eid: String, effects: Array, weight: float, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	return _mind().ledger_hear(w, n, eid, effects, weight, rel, meta)

static func paranoia(w, n) -> float:
	return _mind().paranoia(w, n)

static func ranked_suspects(w, n, social_pressure: bool = false) -> Array:
	return _mind().ranked_suspects(w, n, social_pressure)

static func recompute_beliefs(w, n, note: String) -> void:
	_mind().recompute_beliefs(w, n, note)

static func reconsider(w, n, why: String) -> void:
	_mind().reconsider(w, n, why)

static func say(n, text: String) -> Dictionary:
	return _mind().say(n, text)

static func say_voiced(n, key: String, fallback: String, slots: Dictionary = {}) -> Dictionary:
	return _mind().say_voiced(n, key, fallback, slots)

static func shadow_eval(w, n, f: Callable):
	return _mind().shadow_eval(w, n, f)

static func shadow_run(w, n, f: Callable) -> void:
	_mind().shadow_run(w, n, f)

static func sighting_report(w, n, b: Dictionary, nd: int) -> Dictionary:
	return _mind().sighting_report(w, n, b, nd)

static func sleepwalk_excuse(w, n, where: String) -> Dictionary:
	return _mind().sleepwalk_excuse(w, n, where)

static func susp(n, target_id: String) -> float:
	return _mind().susp(n, target_id)

static func trait_of(n, t: String) -> float:
	return _mind().trait_of(n, t)

static func voiced(n, kind: String, statement: String, event_id: String = "", context: Dictionary = {}) -> Dictionary:
	return _mind().voiced(n, kind, statement, event_id, context)
