## Town meeting reasoning and flow for NPCs: public testimony, volunteering night
## sightings, public role claims, citing reasons, anonymous relays, social consensus
## pressure, nominations, nominator cases, self-defence, and voting.
##
## Extracted from `sim/mind.gd`; `Mind` retains forwarding wrappers so callers can
## invoke either `Mind.<fn>` or `MindMeeting.<fn>`.
extends RefCounted

const WorkshopLedger = preload("res://workshop/shared_ledger.gd")
const ReasonAttribution = preload("res://workshop/reason_attribution.gd")
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
	var st: Dictionary = {"speakers": w.shuffled(w.living()), "i": 0, "done": false,
		"substantive_turns": 0, "reactive": {}, "interjected": {}, "spoke_ids": {}}
	_sync_testimony_ctx(w, st)
	return st

## What speakers' decisions read about the testimony so far, as plain data (ids and
## counts only, so meeting state stays comparable between runs).
static func _sync_testimony_ctx(w, st: Dictionary) -> void:
	if w.meeting is Dictionary:
		w.meeting["testimony"] = {"reactive": st.get("reactive", {}), "substantive_turns": int(st.get("substantive_turns", 0)), "done": bool(st.get("done", false))}

## One step: the next speaker's turn ({who, lines, facts}; lines may be empty), or once
## everyone has spoken, one of the belief refreshes still waiting ({}). Sets st.done after
## the last one.
static func testimony_step(w, st: Dictionary) -> Dictionary:
	for k in ["reactive", "interjected", "spoke_ids"]:
		if not st.has(k):
			st[k] = {}
	if not st.has("substantive_turns"):
		st["substantive_turns"] = 0
	_sync_testimony_ctx(w, st)
	while st["i"] < st["speakers"].size():
		var n = st["speakers"][st["i"]]
		st["i"] += 1
		if n.silenced:
			w.observe_decision(n, "meeting_testimony", false, {"gate": "silenced; no testimony or roll"})
			continue  # the Breathstealer took their voice
		var lines: Array = []
		var facts: Array = []
		flush_beliefs(w, n)  # a speaker reacts to everything said before their turn
		var reacting: bool = st["reactive"].has(n.id)
		if not n.claim_public and _public_claim_decision(w, n) != "":
			_public_disclosure(w, n, lines, facts)
		elif n.claim_public:
			_public_disclosure(w, n, lines, facts)  # already out: share any new readings
		var acc = _public_accusation(w, n, lines, facts)
		if acc != null:
			lines.append(acc["line"])
			facts.append(acc["fact"])
		_volunteer_night_sightings(w, n, lines, facts)
		st["reactive"].erase(n.id)
		st["spoke_ids"][n.id] = true
		if facts.any(func(f): return str(f.get("kind", "")) in ["claim", "info", "accusation"]):
			st["substantive_turns"] += 1
		if not facts.is_empty():
			_queue_reactions(w, st, n, facts)
		_sync_testimony_ctx(w, st)
		if reacting and not lines.is_empty():
			w.dlog.think(n.id, "testimony", "Speaks up in reaction to what was just said.", {"reactive": true})
		return {"who": n.id, "lines": lines, "facts": facts}
	# Everyone has spoken: the remaining refreshes, one mind per step, in queue order.
	if not w.pending_beliefs.is_empty():
		flush_beliefs(w, w.pending_beliefs[0][0])
	if w.pending_beliefs.is_empty():
		w.defer_beliefs = false
		st["done"] = true
		_sync_testimony_ctx(w, st)
	return {}

## Who reacts to what a speaker just said (plan 2.2), from cheap metadata only (no solver):
## 1 a rival claim on their gift, 2 being named, 3 holding something that clears the
## person just accused. Those yet to speak move up (by priority); someone who already spoke
## may interject once per meeting, for 1 or 2 only.
static func _queue_reactions(w, st: Dictionary, s, facts: Array) -> void:
	var claimed: Array = []
	var named: Array = []
	var accused: Array = []
	for f in facts:
		var subj: Array = f.get("subject", []) if f.get("subject", []) is Array else [str(f.get("subject", ""))]
		match str(f.get("kind", "")):
			"claim":
				if str(f.get("source", "")) == s.id:
					claimed.append(str(f.get("role", "")))
			"accusation", "info", "sighting":
				named.append_array(subj)
				if str(f.get("kind", "")) == "accusation":
					accused.append_array(subj)
				elif str(f.get("kind", "")) == "info":
					accused.append_array(Gifts.implicated(f))
	var picks: Array = []
	for l in w.living():
		if l == s or l.silenced:
			continue
		var my_role: String = str(w.evil_plan.get("bluffs", {}).get(l.id, "")) if l.is_evil() else str(l.role)
		var trigger: int = 0
		var subject: String = ""
		if my_role != "" and my_role in claimed:
			trigger = 1
		elif l.id in named:
			trigger = 2
			subject = l.id
		else:
			for x in accused:
				if x == l.id or not w.by_id.has(x):
					continue
				var clears_x: bool = l.info_log.any(func(e): return not e.get("shared", false) and x in Gifts.clears(e))
				if clears_x or (l.role == "martyr" and not l.is_evil() and l.martyr_target == x):
					trigger = 3
					subject = x
					break
		if trigger == 0:
			continue
		var idx: int = st["speakers"].find(l)
		var yet: bool = idx >= st["i"]
		if not yet and (trigger == 3 or st["interjected"].has(l.id) or not st["spoke_ids"].has(l.id)):
			continue
		picks.append([trigger, l, yet])
		st["reactive"][l.id] = {"trigger": trigger, "by": s.id, "subject": subject, "bonus": Tuning.Meeting.REACTIVE_OPENNESS_BONUS}
	picks.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1].id < b[1].id)
	var insert_at: int = st["i"]
	for p in picks:
		var l = p[1]
		if p[2]:
			st["speakers"].erase(l)
		else:
			st["interjected"][l.id] = true
		st["speakers"].insert(insert_at, l)
		insert_at += 1
		w.dlog.think(l.id, "testimony", "Reacts to %s (trigger %d): moves up to speak next." % [s.id, int(p[0])], {"trigger": p[0], "by": s.id, "interjection": not p[2]})

## Opening openness during testimony: a reaction boosts it; otherwise, once a few speakers
## have claimed, shared or accused, a private person holds their cards (plan 2.3).
static func _testimony_openness(w, n) -> float:
	var st = w.meeting.get("testimony", null) if w.meeting is Dictionary else null
	if st == null or st.get("done", true):
		return 0.0
	if st["reactive"].has(n.id):
		return float(st["reactive"][n.id].get("bonus", 0.0))
	return -float(st.get("substantive_turns", 0)) * maxf(0.0, trait_of(n, "privacy") - Tuning.Meeting.CROWD_FADE_PRIVACY_FLOOR) * Tuning.Meeting.CROWD_FADE_SLOPE

static func _testimony_sighting_bar(w, n) -> float:
	var st = w.meeting.get("testimony", null) if w.meeting is Dictionary else null
	if st == null or st.get("done", true) or st["reactive"].has(n.id):
		return 0.0
	return float(st.get("substantive_turns", 0)) * Tuning.Meeting.CROWD_FADE_SIGHTING_BAR

## How safe nominee d is because someone else is already firmly on the block (0..1, public
## information only; plan Step 2). Feeds the defence, and later the Podium Press and supporters.
static func block_safety(w, d) -> float:
	var blk: String = str(w.meeting.get("block", ""))
	var high: int = int(w.meeting.get("block_count", 0))
	var thr: int = w.vote_threshold()
	if blk == "" or blk == d.id or high < thr:
		return 0.0
	var margin: float = clampf(float(high - thr + 1) / Tuning.Meeting.BLOCK_SAFETY_FULL_MARGIN, 0.0, 1.0)
	var accusers: int = w.meeting.get("accusations", []).filter(func(a): return a.get("target", "") == d.id).size()
	var pending: Dictionary = w.meeting.get("pending", {})
	var nominator: String = str(pending.get("by", "")) if str(pending.get("nominee", "")) == d.id else ""
	var nom_cred: float = 0.0
	if nominator == "player":
		nom_cred = clampf(d.credibility, 0.0, 1.0)
	elif nominator != "" and w.by_id.has(nominator):
		nom_cred = clampf(d.npc_trust.get(nominator, 0.5), 0.0, 1.0)
	var heat: float = clampf(Tuning.Meeting.BLOCK_SAFETY_HEAT_BASE + Tuning.Meeting.BLOCK_SAFETY_HEAT_PER_ACCUSER * accusers + Tuning.Meeting.BLOCK_SAFETY_HEAT_CREDIBILITY * nom_cred, 0.0, 1.0)
	return margin * (1.0 - heat)

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
	var threshold = Tuning.Meeting.VOLUNTEER_SIGHTING_BASE - panic + _testimony_sighting_bar(w, n)
	w.observe_decision(n, "volunteer_night_sightings", score >= threshold, {"score": score, "threshold": threshold, "comparison": ">=",
		"inputs": {"gossip": trait_of(n, "gossip"), "confidence": trait_of(n, "confidence"), "paranoia": panic, "composure": trait_of(n, "composure")},
		"threshold_parts": {"base": Tuning.Meeting.VOLUNTEER_SIGHTING_BASE, "paranoia": -panic}, "gate": "Gossip + Confidence threshold; eligible untold sightings still require disclosure/cover checks; no random draw"})
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
		"openness": (0.5 - trait_of(n, "privacy")) * Tuning.Meeting.PUBLIC_CLAIM_OPENNESS_SLOPE,
		"day": Tuning.Meeting.PUBLIC_CLAIM_DAY_SLOPE * (w.day - 1),
		"pressure": n.pressure * Tuning.Meeting.PUBLIC_CLAIM_PRESSURE_SLOPE * (1.0 - Tuning.Meeting.PUBLIC_CLAIM_COMPOSURE_DAMP * trait_of(n, "composure")),
		"base": Tuning.Meeting.PUBLIC_CLAIM_BASE,
	}
	# Gifts that pay off night after night are worth protecting early; one-shot first-night
	# gifts have less to lose by coming out.
	C.role_def(role).score_public_claim(w, n, parts)
	var opening: float = _testimony_openness(w, n)
	if opening != 0.0:
		parts["reactive" if opening > 0.0 else "crowd_fade"] = opening
	if n.protect_lock and not (n.id in w.meeting.get("nominated", []) or n.pressure >= 0.7 or w.living().size() <= 4):
		w.observe_decision(n, "claim", false, {"gate": "protect_lock_promised_player_first"})
		return ""  # promised to tell the Demonologist first once protected
	if w.living().size() <= 4:
		parts["few_left"] = Tuning.Meeting.PUBLIC_CLAIM_FEW_LEFT
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
	var spoken: String = C.spoken_when(e["day"], w.day)
	var when = spoken[0].to_upper() + spoken.substr(1)
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
## first (see _accuse_tier). Reasons come from the shared model's attribution
## (case_against), so their provenance is the evidence itself, not its wording.
static func reason_status(w, n, t_id: String) -> Dictionary:
	var mind = n.shadow if n.is_evil() and n.shadow != null else n
	if mind.workshop_state.get("active", false):
		var ranked: Array = case_against(w, n, t_id, 1)
		if not ranked.is_empty():
			var top: Dictionary = ranked[0]
			var resolved = {"why": top["why"], "kind": top["kind"], "entry": top["entry"], "strength": top["strength"], "eid": top.get("eid", "")}
			if top.has("channel"):
				resolved["channel"] = top["channel"]
			if top.has("src"):
				resolved["src"] = top["src"]
			return resolved
		return {"why": "", "kind": "none", "entry": {}, "strength": 0.0, "eid": ""}
	# Before a mind's first shared refresh it has no reasons yet (the legacy sus_why
	# provenance this used to fall back to is gone, purge phase 4).
	return {"why": "", "kind": "none", "entry": {}, "strength": 0.0, "eid": ""}

## The reason n may give for suspecting t to this audience ("town" or "player"), or "" if
## the only reason they have is one the audience hasn't been told.
static func citable_reason(w, n, t_id: String, audience: String = "town") -> String:
	var rs = reason_status(w, n, t_id)
	if rs["kind"] == "public" or (rs["kind"] in ["player", "shared_player"] and audience == "player"):
		return rs["why"]
	return ""

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
	var kc_readings: Array = n.known_claims.get(src.id, {}).get("readings", [])
	for re in kc_readings:
		if info_eid(src.id, re) == eid:
			return {"src": src, "entry": re}
	return {}

## Passing on, at the meeting, a reading someone told them in private, without naming
## them: "Word reached me from the Seer: …". Gossip, so it counts for much less than the
## claim itself would (C.RELAY_WEIGHT, and through the relayer's credibility), but it
## leaves a trail: there's a Seer, and the relayer knows who. Now and then
## (C.RELAY_CORROBORATE) the source steps forward and confirms it.
static func _retire_muddled_reading_in_town(w, src, muddled_e: Dictionary) -> void:
	var m_eid: String = info_eid(src.id, muddled_e)
	for l in w.living():
		if l == src:
			continue
		var mind = l.shadow if l.is_evil() and l.shadow != null else l
		if mind != null and mind.ledger.has(m_eid):
			mind.ledger[m_eid]["weight"] = 0.0
			mind.ledger[m_eid]["meta"] = {"kind": "retired_muddle"}
			refresh_beliefs(w, l, " (muddled reading debunked)")

static func relay_reading(w, n, src, e: Dictionary, lines: Array, facts: Array) -> void:
	var Muddler = preload("res://sim/muddler.gd")
	var spoken_e: Dictionary = Muddler.maybe_muddle_reading(w, n, src.id, e)
	var rn = C.role_name(spoken_e["role"])
	var said = C.third_person(spoken_e["text"])
	lines.append(say_voiced(n, "meeting_relay_reading", "Word reached me from the %s: %s." % [rn, said], {"role": rn, "reading": said}))
	facts.append({"kind": "accusation", "subject": Gifts.implicated(spoken_e), "source": n.id, "relay": true, "role": spoken_e["role"],
		"text": "%s says the %s (unnamed) told them: %s." % [n.name, rn, said]})
	for l in w.living():
		if l != n and l != src:
			apply_info(w, l, src, spoken_e, C.RELAY_WEIGHT * heard_weight(l, n), n.id, true)
	w.dlog.think(n.id, "relay", "Relays %s's private %s reading without naming them." % [src.id, spoken_e["role"]], {"src": src.id, "muddled": spoken_e.get("muddled", false)})
	if spoken_e.get("muddled", false) and src.alive and not src.silenced:
		if src.claim_public:
			lines.append(say_voiced(src, "debunk_muddle_claimed", "Hold on: %s got my %s reading twisted." % [n.name, rn], {"teller": n.name, "role": rn}))
			_retire_muddled_reading_in_town(w, src, spoken_e)
			facts.append({"kind": "deprecate_muddle", "source": src.id, "role": spoken_e["role"], "day": spoken_e["day"], "muddled_data": spoken_e["data"].duplicate(true)})
			for real_e in src.info_log:
				if int(real_e.get("day", -1)) == int(spoken_e.get("day", -2)) and str(real_e.get("role", "")) == str(spoken_e.get("role", "")) and not real_e.get("disowned", false):
					if not real_e.get("shared", false):
						_go_public(w, src, lines, facts)
					else:
						lines.append_array(info_lines(w, src, [real_e], "town", true, "volunteer"))
						facts.append(info_fact(w, src, real_e))
					break
			return
		var cost = reveal_cost(w, src)
		var harm_bonus: float = 0.25 if Gifts.implicated(spoken_e).any(func(pid): return pid == src.id or src.npc_trust.get(pid, 0.5) >= 0.65) else 0.0
		var parts = {"muddle_harm": 0.45 + harm_bonus, "confidence": (trait_of(src, "confidence") - 0.5) * 0.6}
		for k in cost:
			parts["cost_" + k] = -cost[k]
		if decide(w, src, "debunk_muddle", parts, "Reveal gift (%s) to debunk %s's muddled relay?" % [spoken_e["role"], n.id]):
			lines.append(say_voiced(src, "debunk_muddle_reveal", "Wait. That isn't what my gift showed at all; %s got it garbled." % n.name, {"teller": n.name}))
			_retire_muddled_reading_in_town(w, src, spoken_e)
			facts.append({"kind": "deprecate_muddle", "source": src.id, "role": spoken_e["role"], "day": spoken_e["day"], "muddled_data": spoken_e["data"].duplicate(true)})
			_public_disclosure(w, src, lines, facts)
		else:
			src.pending_muddle_debunks.append({"teller": n.id, "role": spoken_e["role"], "day": spoken_e["day"], "muddled_entry": spoken_e.duplicate(true)})
			w.dlog.think(src.id, "withhold", "Holds tongue on %s's muddled %s relay to protect cover; will debunk if revealing later." % [n.id, spoken_e["role"]])
		return
	if src.alive and not src.silenced and not src.claim_public and w.decision_roll(src, "corroborate_relay", C.RELAY_CORROBORATE, {}, n.id):
		lines.append(say_voiced(src, "relay_claim_authorship", "That was me."))
		for l in w.living():
			if l != n and l != src:
				acknowledge_reading(w, l, src, spoken_e, n.id)
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
	refresh_beliefs(w, listener, " (reading source publicly acknowledged)")

## What going public with their gift would cost n right now (higher = more reluctant):
## gifts that hide from the demon or keep paying off, fear, privacy; less as the game
## wears on or the town thins out. 0 if they've already claimed it.
static func reveal_cost(w, n) -> Dictionary:
	if n.claim_public:
		return {}
	var role: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var parts = {"privacy": (trait_of(n, "privacy") - 0.5) * Tuning.Meeting.REVEAL_COST_PRIVACY_SLOPE, "base": Tuning.Meeting.REVEAL_COST_BASE}
	C.role_def(role).score_reveal_cost(w, n, parts)
	if _afraid(w, n):
		parts["afraid"] = Tuning.Meeting.REVEAL_COST_AFRAID
	parts["day"] = Tuning.Meeting.REVEAL_COST_DAY_SLOPE * (w.day - 1)
	if w.living().size() <= 4:
		parts["few_left"] = Tuning.Meeting.REVEAL_COST_FEW_LEFT
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
	var parts = {"strength": (rs["strength"] - Tuning.Meeting.REVEAL_STRENGTH_PIVOT) * Tuning.Meeting.REVEAL_STRENGTH_SLOPE,
		"suspicion": (s2 - Tuning.Meeting.REVEAL_SUSPICION_PIVOT) * Tuning.Meeting.REVEAL_SUSPICION_SLOPE,
		"confidence": (trait_of(n, "confidence") - 0.5) * Tuning.Meeting.REVEAL_CONFIDENCE_SLOPE}
	for k in cost:
		parts["cost_" + k] = -cost[k]
	if decide(w, n, "reveal_to_accuse", parts, "Go public with what points at %s (%s)?" % [t.id, rs["why"]]):
		return {"tier": "reveal", "why": rs["why"], "entry": rs["entry"], "eid": rs.get("eid", "")}
	return {"tier": "hint", "why": "", "eid": rs.get("eid", "")}

## Called at the actual disclosure, including inside a streamed speaker's turn.
## The promise itself still lapses through Game._break_confidences as before.
static func _public_disclosure(w, n, lines: Array, facts: Array, share_readings: bool = true) -> void:
	if not n.claim_public and n.dialogue_memory.get("confidence_requested", false):
		lines.append(say_voiced(n, "release_confidence_public", "I've decided the town should hear it."))
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
				hear_claim(w, l, n.id, claim, Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "public")
	if share_readings and C.has_readings(n.claimed_role):
		var PsychRole = preload("res://sim/roles/psychologist.gd")
		if not n.pending_muddle_debunks.is_empty():
			for pm in n.pending_muddle_debunks:
				var m_ent: Dictionary = pm.get("muddled_entry", {})
				if not m_ent.is_empty():
					_retire_muddled_reading_in_town(w, n, m_ent)
					facts.append({"kind": "deprecate_muddle", "source": n.id, "role": m_ent.get("role", n.claimed_role), "day": m_ent.get("day", -1), "muddled_data": m_ent.get("data", {}).duplicate(true)})
			var t_id0: String = str(n.pending_muddle_debunks[0].get("teller", ""))
			var t_nm0: String = w.by_id[t_id0].name if w.by_id.has(t_id0) else "someone"
			lines.append(say_voiced(n, "debunk_muddle_deferred", "And to set the record straight: that earlier %s reading %s passed along was muddled." % [C.role_name(n.claimed_role), t_nm0], {"role": C.role_name(n.claimed_role), "teller": t_nm0}))
			n.pending_muddle_debunks.clear()
		var shared_this_turn: Array = []
		for e in n.info_log:
			if e["shared"] or e.get("disowned", false):
				continue
			e["shared"] = true
			var weights = {}
			for x in implicated(e):
				weights[x] = ReasonAttribution.score_reading_entry_in_world(w, n.id, e, x)["strength"]
			w.public_event("reading", implicated(e), n.id, {"weights": weights})
			w.public_event("clear", Gifts.clears(e), n.id)
			if str(e.get("role", n.claimed_role)) == "nightwatch":
				var nw_day: int = int(e.get("day", -1))
				var nw_blk: String = str(e.get("data", {}).get("block", ""))
				for seen_id in e.get("data", {}).get("seen", []):
					n.told_to["town|sighting:%s:%s:%d:%d:%s" % [n.id, str(seen_id), nw_day, C.NIGHT, nw_blk]] = true
			shared_this_turn.append(e)
			var pub_fact: Dictionary = info_fact(w, n, e)
			facts.append(pub_fact)
			facts.append_array(PsychRole.companion_facts(w, n, e))
			var is_false_pub: bool = not bool(e.get("true", not e.get("fake", false)))
			var f_why_pub: String = ("lying" if n.is_evil() else "misled") if is_false_pub else ""
			for l in w.living():
				if l != n:
					apply_info(w, l, n, e, heard_weight(l, n))
					PsychRole.record_heard(w, l, n.id, pub_fact, is_false_pub, f_why_pub)
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
			lines.append(say_voiced(n, "gallows_confirm_role", "As I've said, I am the %s." % C.role_name(claim), {"role": C.role_name(claim)}))
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
		lines.append(say_voiced(n, "gallows_parting_suspect", "I still suspect %s." % w.by_id[suspect].name, {"suspect": w.by_id[suspect].name}))
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
		var planter_id: String = str(w.evil_plan.get("daily_planter", ""))
		var earlier_sg: Array = w.meeting.get("accusations", []).filter(func(a): return a.get("target", "") == sg)
		if planter_id != "" and n.id != planter_id and not earlier_sg.is_empty():
			var good_spoke: bool = earlier_sg.any(func(a): return w.by_id.has(a.get("by", "")) and not w.by_id[a["by"]].is_evil())
			if not good_spoke:
				good_spoke = w.public_log.any(func(ev): return int(ev.get("day", -1)) == w.day and ev.get("kind", "") in ["accusation", "reading"] and sg in ev.get("subjects", []) and w.by_id.has(ev.get("by", "")) and not w.by_id[ev["by"]].is_evil())
			if not good_spoke:
				w.dlog.think(n.id, "accuse", "Evil patience: waits for a good voice against %s before echoing teammates." % sg)
				return null
		t = w.by_id[sg]
		s2 = 0.8
		why = Evil.bluff_reason(w, n, t)
	var acc_resent: float = 0.0
	if not n.is_evil():
		var ranked = ranked_suspects(w, n)
		if ranked.is_empty():
			return null
		ranked.sort_custom(func(a, b):
			var sa: float = susp(n, a.id) + _mind().resentment_toward(w, n, a.id)
			var sb: float = susp(n, b.id) + _mind().resentment_toward(w, n, b.id)
			return sa > sb)
		t = ranked[0]
		s2 = susp(n, t.id)
		acc_resent = _mind().resentment_toward(w, n, t.id)
	var parts = {"suspicion": (s2 - Tuning.Meeting.ACCUSE_SUSPICION_PIVOT) * Tuning.Meeting.ACCUSE_SUSPICION_SLOPE, "confidence": (trait_of(n, "confidence") - 0.5) * Tuning.Meeting.ACCUSE_CONFIDENCE_SLOPE,
		"pressure_deflect": n.pressure * Tuning.Meeting.ACCUSE_PRESSURE_DEFLECT}
	if acc_resent > 0.0:
		parts["resentment"] = acc_resent * Tuning.Meeting.ACCUSE_RESENTMENT_SLOPE
	var acc_opening: float = _testimony_openness(w, n)
	if acc_opening != 0.0:
		parts["reactive" if acc_opening > 0.0 else "crowd_fade"] = acc_opening
	if not decide(w, n, "accuse", parts, "Publicly accuse %s?" % t.id):
		return null
	# What they can say for it: a reason the town already has, a hint at one they're
	# keeping back, or their gift and its reading brought out now.
	var hint = false
	var hint_src: String = ""
	if n.is_evil():
		# A hinted "private reason" must fit the bluff: a gift that gives readings, with a
		# fake one ready that points at the target, or (sometimes) none yet, as a free bluff
		# they'll decline to back up if asked.
		var bluff: String = w.evil_plan["bluffs"].get(n.id, "")
		var fake_on_t: Dictionary = _unshared_fake_on(n, t.id)
		if why == "" and C.has_readings(bluff) and (not fake_on_t.is_empty() or w.decision_roll(n, "hint_without_reading", C.EVIL_HINT_CHANCE, {}, t.id)):
			hint = true
			if not fake_on_t.is_empty():
				hint_src = info_eid(n.id, fake_on_t)
		w.dlog.think(n.id, "lie", "Evil: publicly accuses scapegoat %s, citing: %s." % [t.id, "a hinted private reason" if hint else why if why != "" else "vibes"])
	else:
		var tier = _accuse_tier(w, n, t, s2)
		if tier["tier"] == "reveal":
			_public_disclosure(w, n, lines, facts)
		elif tier["tier"] == "relay":
			relay_reading(w, n, tier["src"], tier["entry"], lines, facts)
		hint = tier["tier"] == "hint"
		hint_src = str(tier.get("eid", ""))
		why = tier["why"]
		w.dlog.think(n.id, "accuse_tier", "Accuses %s: %s%s." % [t.id, tier["tier"], (" (" + why + ")") if why != "" else ""])
	if hint:
		n.hints[t.id] = {"day": w.day, "src": hint_src}
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
	t.pressure += Tuning.Meeting.ACCUSE_PRESSURE_BASE * pow(Tuning.Meeting.ACCUSE_PRESSURE_DECAY, earlier.size())
	w.public_event("accusation", [t.id], n.id)
	# Being accused in front of the town costs the accuser some of the target's trust (Oct 30).
	t.npc_trust[n.id] = clampf(t.npc_trust.get(n.id, 0.5) - Tuning.Social.TRUST_ACCUSED_ME, 0.0, 1.0)
	var line: Dictionary
	if not earlier.is_empty():
		# Someone already said it: agree rather than restate their grounds. Only grounds of
		# their own (their reading, what they saw) are worth adding.
		var first = w.by_id[earlier[0]["by"]]
		var own = why.begins_with("my own") or why.begins_with("I ")
		var canonical_extra = " I have my own reason, but I'm not ready to share it yet." if hint else ((" " + why[0].to_upper() + why.substr(1) + ".") if own else "")
		var voiced_extra = (" " + Dialogue.voice_line(n.id, "nomination_held_reason", "I have my own reason, but I'm not ready to share it yet.")) if hint else canonical_extra
		var canonical_agree = "I agree with %s about %s.%s" % [first.name, t.name, canonical_extra]
		var voiced_agree = Dialogue.voice_line(n.id, "meeting_agree_accuse", "I agree with %s about %s." % [first.name, t.name], {"accuser": first.name, "target": t.name}) + voiced_extra
		line = {"speaker": n.id, "name": n.name, "text": voiced_agree, "statement": canonical_agree}
	elif hint:
		line = say_voiced(n, "meeting_accuse_hint", "I have a reason to suspect %s, but I'm not ready to share it yet." % t.name, {"target": t.name})
	else:
		var reason_s: String = (why[0].to_upper() + why.substr(1)).trim_suffix(".") if why != "" else ""
		var tail = (" " + reason_s + ".") if why != "" else " Something's off about them."
		var canonical_accuse = "I don't trust %s.%s" % [t.name, tail]
		if why != "":
			line = say_voiced(n, "meeting_accuse_reason", canonical_accuse, {"target": t.name, "reason": reason_s})
		else:
			line = say_voiced(n, "meeting_accuse_vibes", canonical_accuse, {"target": t.name})
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

## Action-only cooloff after a failed vote yesterday, scaled by vote shortfall against threshold.
## Leaves underlying suspicion and yes/no vote evaluations untouched, and tapers out in endgame.
static func nomination_cooloff(w, nominator_id: String, target_id: String) -> float:
	if w.day <= 1:
		return 0.0
	var living_count: int = w.living().size()
	if living_count <= 4:
		return 0.0
	var urgency_mult: float = 0.5 if (living_count == 5 or (w.max_days > 0 and w.day >= w.max_days - 1)) else 1.0
	for i in range(w.public_log.size() - 1, -1, -1):
		var ev: Dictionary = w.public_log[i]
		if ev.get("kind", "") != "vote" or int(ev.get("day", -1)) != w.day - 1:
			continue
		var d: Dictionary = ev.get("data", {})
		if str(d.get("nominee", "")) != target_id:
			continue
		var count: int = int(d.get("count", 0))
		var thr: int = maxi(int(d.get("threshold", 1)), 1)
		if count >= thr:
			return 0.0
		var shortfall: float = clampf(float(thr - count) / float(thr), 0.0, 1.0)
		var prev_by: String = str(d.get("nominator", ""))
		var scale: float = Tuning.Meeting.NOMINATION_COOLOFF_SELF if (nominator_id != "" and prev_by == nominator_id) else Tuning.Meeting.NOMINATION_COOLOFF_ROOM
		return scale * shortfall * urgency_mult
	return 0.0

static func _nomination_action_score(w, n, target_id: String) -> float:
	var s: float = action_susp(n, target_id) + _mind().resentment_toward(w, n, target_id)
	if n.cleared.has(target_id):
		s -= Tuning.Meeting.NOMINATION_OWN_CLEAR_RELIEF
	s -= nomination_cooloff(w, n.id, target_id)
	return s

static func _good_nomination_impl(w, n, m: Dictionary, block: String, trace_id: int):
	var day_base: float = maxf(Tuning.Meeting.NOMINATION_FLOOR, Tuning.Meeting.NOMINATION_BASE - Tuning.Meeting.NOMINATION_DAY_SLOPE * w.day)
	var conf_term: float = -Tuning.Meeting.NOMINATION_CONFIDENCE_SCALE * (trait_of(n, "confidence") - 0.5) * 2.0
	var para_term: float = -Tuning.Meeting.NOMINATION_PARANOIA_SCALE * paranoia(w, n)
	var thr: float = day_base + conf_term + para_term
	var candidates: Array = ranked_suspects(w, n, true)
	candidates.sort_custom(func(a, b):
		var sa: float = _nomination_action_score(w, n, a.id)
		var sb: float = _nomination_action_score(w, n, b.id)
		return sa > sb if not is_equal_approx(sa, sb) else a.id < b.id)
	for t in candidates:
		if t.id in m["nominated"] or t.id == n.id:
			w.dlog.decision(n.id, "nomination", "gate", false,
				{"gate": "already_nominated_or_self"}, t.id, trace_id)
			continue
		var cooloff: float = nomination_cooloff(w, n.id, t.id)
		var clear_adj: float = -Tuning.Meeting.NOMINATION_OWN_CLEAR_RELIEF if n.cleared.has(t.id) else 0.0
		var resent: float = _mind().resentment_toward(w, n, t.id)
		var s: float = action_susp(n, t.id) + resent + clear_adj - cooloff
		w.dlog.decision(n.id, "nomination", "evaluation", s >= thr, {"score": s,
			"raw_suspicion": susp(n, t.id), "town_pressure": action_susp(n, t.id) - execution_priority_contribution(n, t.id) - susp(n, t.id),
			"resentment": resent, "own_clear_adjustment": clear_adj, "nomination_cooloff": -cooloff,
			"shared_execution_priority": execution_priority(n, t.id), "shared_execution_weight": C.SHARED_EXECUTION_PRIORITY_WEIGHT,
			"threshold": thr, "comparison": ">=",
			"threshold_parts": {"day_base": day_base, "confidence": conf_term, "paranoia": para_term}}, t.id, trace_id)
		if s < thr:
			continue
		var block_s: float = (action_susp(n, block) + _mind().resentment_toward(w, n, block)) if block != "" else 0.0
		if block != "" and block_s >= s:
			w.dlog.decision(n.id, "nomination", "gate", false, {"gate": "prefers_existing_block",
				"block": block, "block_suspicion": block_s, "candidate_score": s}, t.id, trace_id)
			return null  # content with who is already on the block
		return {"nominee": t.id, "by": n.id, "score": s,
			"reason": "suspicion of %s %.2f >= threshold %.2f" % [t.id, s, thr]}
	return null

## Shadow self (step 2): evil nominates as its good self would. Naming a teammate is
## high stakes (overridden unless caution has worn thin); pushing the scapegoat when the
## good self wouldn't nominate is an override that's cheap once the town is already hot on them.
static func _evil_counter_or_pass(w, n, m: Dictionary, ev) -> Variant:
	if ev == null:
		return null
	var blk: String = m.get("block", "")
	var mate_on_block: bool = blk != "" and w.by_id.has(blk) and w.by_id[blk].is_evil()
	var sg = w.by_id[ev["nominee"]]
	var ready: Dictionary = Evil.scapegoat_readiness(w, n, sg)
	if not mate_on_block and float(ready.get("room_heat", 0.0)) < Tuning.Meeting.EVIL_COUNTER_MIN_HEAT:
		w.dlog.think(n.id, "nominate", "Evil: stays silent rather than nominating teammate or forcing a cold scapegoat push.")
		return null
	var rescue_bonus: float = Tuning.Meeting.EVIL_RESCUE_DEMON_BONUS if (mate_on_block and blk == w.demon_id) else (Tuning.Meeting.EVIL_RESCUE_MINION_BONUS if mate_on_block else 0.0)
	if evil_override(w, n, "nomination", Tuning.Meeting.EVIL_NOMINATION_STAKES_BASE + float(ready["score"]) + rescue_bonus, 0.5, "push scapegoat %s instead" % sg.id):
		return ev
	return null

static func _evil_nomination(w, n, m: Dictionary, block: String):
	var ev = Evil.evil_nomination(w, n)
	if not C.SHADOW_SELF:
		return ev
	var sc = shadow_eval(w, n, func(sh): return _good_nomination(w, sh, m, block))
	if sc != null:
		sc["by"] = n.id
		if w.by_id[sc["nominee"]].role == "demon":
			w.dlog.think(n.id, "team_survival", "Protects the demon: maintaining cover cannot justify nominating them.")
			return _evil_counter_or_pass(w, n, m, ev)
		if Evil.is_teammate(w, n, sc["nominee"]):
			var stakes = 0.85 * Evil.teammate_value(w, sc["nominee"])
			if evil_override(w, n, "nomination", stakes, 0.35, "stay silent instead of nominating teammate %s" % sc["nominee"]):
				return _evil_counter_or_pass(w, n, m, ev)
			sc["reason"] = "Evil (good self): nominates teammate %s; %s" % [sc["nominee"], sc["reason"]]
		return sc
	if ev == null:
		return null
	var blk2: String = m.get("block", "")
	var scion_safe_nom: bool = Evil.scion_fallback_active(w)
	var rescue2: float = 0.0
	if blk2 != "" and blk2 == w.demon_id:
		rescue2 = (0.0 if n.role == "scion" else Tuning.Meeting.EVIL_RESCUE_MINION_BONUS) if scion_safe_nom else Tuning.Meeting.EVIL_RESCUE_DEMON_BONUS
	elif blk2 != "" and w.by_id.has(blk2) and w.by_id[blk2].is_evil():
		rescue2 = Tuning.Meeting.EVIL_RESCUE_MINION_BONUS
	var sg = w.by_id[ev["nominee"]]
	var sg_ready: float = Evil.scapegoat_readiness(w, n, sg)["score"]
	if evil_override(w, n, "nomination", Tuning.Meeting.EVIL_NOMINATION_STAKES_BASE + sg_ready + rescue2, 0.5, "push scapegoat %s (good self wouldn't nominate)" % sg.id):
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
static func _visibility_maps(w, mind, real_npc) -> Dictionary:
	var public_ids: Dictionary = {}
	var player_ids: Dictionary = {}
	var st: Dictionary = mind.workshop_state
	for id in st.get("disclosures", {}):
		var d: Dictionary = st.disclosures[id]
		if d.get("player", false):
			player_ids[str(id)] = true
		if d.get("public", false):
			public_ids[str(id)] = true
	var withdrawn: Dictionary = st.get("withdrawn", {})
	for pkey in st.get("presentations", {}):
		if withdrawn.has(pkey) or withdrawn.has(str(pkey)):
			continue
		var snap: Dictionary = st.presentations[pkey]
		var is_pub_venue: bool = str(snap.get("venue", "private")) != "private"
		for id in snap.get("selected", []):
			player_ids[str(id)] = true
			if is_pub_venue:
				public_ids[str(id)] = true
	for entry in mind.ledger.values():
		var meta: Dictionary = entry.get("meta", {})
		for receipt in meta.get("workshop_receipts", {}).values():
			if receipt is Dictionary and receipt.get("heard_in_public", false):
				public_ids[str(receipt.get("id", ""))] = true
		if meta.get("workshop_public", false) and meta.has("workshop_card"):
			public_ids[str(meta.workshop_card.get("id", ""))] = true
	for i in range(real_npc.info_log.size()):
		var en: Dictionary = real_npc.info_log[i]
		var rid: String = WorkshopLedger.reading(real_npc.id, en).id
		if en.get("shared", false):
			public_ids[rid] = true
		if i < real_npc.told_readings:
			player_ids[rid] = true
	for p in w.npcs:
		if p == real_npc:
			continue
		for en in p.info_log:
			if en.get("shared", false):
				public_ids[WorkshopLedger.reading(p.id, en).id] = true
	for pc in w.public_claims:
		var who_id: String = str(pc.get("who", ""))
		var role_id: String = str(pc.get("role", ""))
		var c_eid: String = "claim:%s:%s" % [who_id, role_id]
		if mind.ledger.has(c_eid) and mind.ledger[c_eid].get("meta", {}).has("workshop_card"):
			public_ids[str(mind.ledger[c_eid].meta.workshop_card.get("id", ""))] = true
	return {"public": public_ids, "player": player_ids}


static func _root_is_public(w, mind, real_npc, rid: String, public_ids: Dictionary) -> bool:
	if public_ids.has(rid):
		return true
	var owners: Array = mind.workshop_state.get("owners", {}).get(rid, [])
	for owner in owners:
		var os: String = str(owner)
		if os == "public":
			return true
		if os.begins_with("claim:"):
			var c_eid: String = os.trim_prefix("claim:")
			var meta: Dictionary = mind.ledger.get(c_eid, {}).get("meta", {})
			var who_id: String = str(meta.get("who", ""))
			var role_id: String = str(meta.get("role", ""))
			if w.public_claims.any(func(pc): return str(pc.get("who", "")) == who_id and str(pc.get("role", "")) == role_id):
				return true
		elif os.begins_with("reading:"):
			var r_eid: String = os.trim_prefix("reading:")
			var parts: PackedStringArray = r_eid.split(":")
			if parts.size() >= 2:
				var holder = real_npc if parts[1] == real_npc.id else w.by_id.get(parts[1])
				if holder != null:
					for en in holder.info_log:
						if info_eid(holder.id, en) == r_eid and en.get("shared", false):
							return true
	return false


static func _find_reading_for_card(holder, cid: String, crole: String, cday: int) -> Array:
	for i in range(holder.info_log.size()):
		var en: Dictionary = holder.info_log[i]
		if WorkshopLedger.reading(holder.id, en).id == cid:
			return [i, en]
	for i in range(holder.info_log.size()):
		var en: Dictionary = holder.info_log[i]
		if str(en.get("role", "")) == crole and int(en.get("day", -1)) == cday and not en.get("disowned", false):
			return [i, en]
	return [-1, {}]


static func _resolve_shared_reason(w, mind, real_npc, t_id: String, raw: Dictionary, vis_maps: Dictionary) -> Dictionary:
	var cid: String = str(raw.get("card_id", ""))
	var ckind: String = str(raw.get("card_kind", ""))
	var channel: String = str(raw.get("channel", ""))
	var csrc: String = str(raw.get("source", ""))
	var crole: String = str(raw.get("role", ""))
	var cnight: int = int(raw.get("night", -1))
	var cblock: String = str(raw.get("block", ""))
	var contrib: float = float(raw.get("contrib", 0.0))
	var strength: float = float(raw.get("strength", 0.3))
	var is_joint: bool = bool(raw.get("joint", false))
	var root_ids: Array = raw.get("root_ids", [])
	var owners: Array = raw.get("owners", [])
	var public_ids: Dictionary = vis_maps["public"]
	var player_ids: Dictionary = vis_maps["player"]

	if ckind == "circumstantial":
		return {
			"eid": cid,
			"why": str(raw.get("why_public", "")),
			"kind": str(raw.get("circ_visibility", "shared_player")),
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
		}

	if ckind == "joint":
		var all_pub: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids))
		var all_plr: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids) or player_ids.has(str(r)))
		var j_kind: String = "public" if all_pub else ("shared_player" if all_plr else "shared_private")
		return {
			"eid": cid,
			"why": str(raw.get("why_public", "")),
			"kind": j_kind,
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
		}

	if channel == "role_clash" and csrc == real_npc.id and ckind == "claim":
		return {
			"eid": "own_role",
			"why": str(raw.get("why_own", "")),
			"kind": "public" if real_npc.claim_public else "private",
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
		}

	if csrc == real_npc.id and ckind == "report":
		var matched: Array = _find_reading_for_card(real_npc, cid, crole, cnight)
		var idx: int = int(matched[0])
		var en: Dictionary = matched[1]
		if en.is_empty() and mind != real_npc:
			var m2: Array = _find_reading_for_card(mind, cid, crole, cnight)
			en = m2[1]
		if not en.is_empty() and en.get("disowned", false):
			return {}
		var r_eid: String = info_eid(real_npc.id, en) if not en.is_empty() else ("info:%s:%d:%s" % [real_npc.id, cnight, crole])
		var self_shared: bool = not en.is_empty() and bool(en.get("shared", false))
		var board_pub: bool = public_ids.has(cid)
		var told_direct: bool = idx >= 0 and idx < real_npc.told_readings
		var board_plr: bool = player_ids.has(cid)
		var other_pub: bool = not is_joint or root_ids.all(func(r): return str(r) == cid or _root_is_public(w, mind, real_npc, str(r), public_ids))
		var other_plr: bool = not is_joint or root_ids.all(func(r): return str(r) == cid or _root_is_public(w, mind, real_npc, str(r), public_ids) or player_ids.has(str(r)))
		var r_kind: String = "private"
		var r_why: String = str(raw.get("why_own", ""))
		if (self_shared or board_pub) and other_pub:
			r_kind = "public"
			r_why = str(raw.get("why_own", "")) if (real_npc.claim_public or self_shared) else str(raw.get("why_public", ""))
		elif (told_direct or board_plr) and other_plr:
			r_kind = "player"
			r_why = str(raw.get("why_own", "")) if (told_direct or real_npc.claim_public) else str(raw.get("why_public", ""))
		return {
			"eid": r_eid,
			"why": r_why,
			"kind": r_kind,
			"strength": strength,
			"contrib": contrib,
			"entry": en,
			"channel": channel,
		}

	if csrc == real_npc.id and ckind == "sighting":
		var seen_b: Dictionary = {}
		for b in real_npc.beliefs:
			if b.get("kind", "") == "saw" and b.get("who", "") == t_id and int(b.get("day", -1)) == cnight and int(b.get("phase", -1)) == C.NIGHT:
				seen_b = b
				break
		var blk_label: String = C.block_name(cblock) if cblock in C.BLOCKS else "the street"
		var when_s: String = C.spoken_when(cnight, w.day)
		var s_why: String = str(raw.get("why_own", ""))
		if not seen_b.is_empty():
			if str(seen_b.get("how", "street")) == "window":
				s_why = "I saw them out in the street from my window %s" % when_s
			elif real_npc.claim_public and C.ROLES.get(real_npc.claimed_role, {}).get("night_walk", false):
				s_why = "I saw them out on %s %s, while I was out on my duty" % [blk_label, when_s]
			else:
				s_why = "I saw them out on %s %s" % [blk_label, when_s]
		elif cnight >= 0:
			s_why = s_why.replace("on " + C.night_name(cnight), when_s)
		var already_disclosed: bool = (not seen_b.is_empty() and real_npc.told_to.has(_town_sighting_key(real_npc, seen_b))) or public_ids.has(cid)
		var allowed_pub: bool = not seen_b.is_empty() and _public_sighting_allowed(w, real_npc, seen_b)
		var s_kind: String = "shared_private"
		if already_disclosed or allowed_pub:
			s_kind = "public"
		elif player_ids.has(cid):
			s_kind = "shared_player"
		elif C.ROLES.get(real_npc.role, {}).get("night_walk", false):
			s_kind = "private"
		return {
			"eid": "sighting:%s:%s:%d:%s" % [real_npc.id, t_id, cnight, cblock],
			"why": s_why,
			"kind": s_kind,
			"strength": strength,
			"contrib": contrib,
			"entry": {},
			"channel": channel,
			"own_sighting": true,
			"own_sighting_disclosed": already_disclosed,
		}

	if ckind == "report" and w.by_id.has(csrc):
		var src_npc = w.by_id[csrc]
		var m_other: Array = _find_reading_for_card(src_npc, cid, crole, cnight)
		var en_o: Dictionary = m_other[1]
		if not en_o.is_empty() and en_o.get("disowned", false):
			return {}
		var o_eid: String = info_eid(csrc, en_o) if not en_o.is_empty() else ("info:%s:%d:%s" % [csrc, cnight, crole])
		var o_shared: bool = (not en_o.is_empty() and bool(en_o.get("shared", false))) or public_ids.has(cid)
		if csrc == t_id and channel in ["role_clash", "challenge_lie"] and w.public_claims.any(func(pc): return str(pc.get("who", "")) == t_id):
			o_shared = true
		var o_other_pub: bool = not is_joint or root_ids.all(func(r): return str(r) == cid or _root_is_public(w, mind, real_npc, str(r), public_ids))
		var o_other_plr: bool = not is_joint or root_ids.all(func(r): return str(r) == cid or _root_is_public(w, mind, real_npc, str(r), public_ids) or player_ids.has(str(r)))
		if o_shared and o_other_pub:
			return {
				"eid": o_eid,
				"why": str(raw.get("why_public", "")),
				"kind": "public",
				"strength": strength,
				"contrib": contrib,
				"entry": en_o,
				"channel": channel,
			}
		var heard_anon: bool = mind.ledger.get(o_eid, {}).get("meta", {}).get("workshop_receipts", {}).values().any(func(r): return r is Dictionary and r.get("content", {}).get("anonymous", false))
		var direct_private: bool = not en_o.is_empty() and not heard_anon and owners.any(func(o): return str(o) == "learned" or str(o).begins_with("reading:"))
		if direct_private and not is_joint:
			return {
				"eid": o_eid,
				"why": str(raw.get("why_public", "")),
				"kind": "relay",
				"strength": strength * 0.5,
				"contrib": contrib,
				"entry": en_o,
				"src": src_npc,
				"channel": channel,
			}
		if heard_anon:
			return {
				"eid": o_eid,
				"why": str(raw.get("why_public", "")),
				"kind": "public",
				"strength": strength * 0.5,
				"contrib": contrib,
				"entry": {},
				"channel": channel,
			}
		return {
			"eid": o_eid,
			"why": str(raw.get("why_public", "")),
			"kind": "shared_player" if (player_ids.has(cid) and o_other_plr) else "shared_private",
			"strength": strength,
			"contrib": contrib,
			"entry": en_o,
			"channel": channel,
		}

	var fallback_eid: String = cid
	for owner in owners:
		var os2: String = str(owner)
		if os2.begins_with("share:") or os2.begins_with("claim:") or os2.begins_with("tell:") or os2.begins_with("testimony:"):
			fallback_eid = os2.substr(os2.find(":") + 1)
			break
	var g_kind: String = "public"
	if is_joint:
		var g_pub: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids))
		var g_plr: bool = root_ids.all(func(r): return _root_is_public(w, mind, real_npc, str(r), public_ids) or player_ids.has(str(r)))
		g_kind = "public" if g_pub else ("shared_player" if g_plr else "shared_private")
	elif csrc == "player" and not public_ids.has(cid):
		g_kind = "shared_player"
	var g_why: String = str(raw.get("why_public", ""))
	if cnight >= 0:
		g_why = g_why.replace("on " + C.night_name(cnight), C.spoken_when(cnight, w.day))
	return {
		"eid": fallback_eid,
		"why": g_why,
		"kind": g_kind,
		"strength": strength,
		"contrib": contrib,
		"entry": {},
		"channel": channel,
	}


static func case_against(w, n, t_id: String, limit: int = 3) -> Array:
	var mind = n
	if n.is_evil():
		mind = n.shadow if n.shadow != null else n
	var ws_active: bool = mind.workshop_state.get("active", false)
	var items: Array = []
	if ws_active:
		if mind.workshop_state.get("reasons_pending", false) and w.workshop_reasons.is_valid():
			w.workshop_reasons.call(mind)
		var raw_list: Array = mind.workshop_state.get("reasons", {}).get(t_id, [])
		if not raw_list.is_empty():
			var vis_maps: Dictionary = _visibility_maps(w, mind, n)
			for raw in raw_list:
				var resolved: Dictionary = _resolve_shared_reason(w, mind, n, t_id, raw, vis_maps)
				if not resolved.is_empty() and resolved.get("why", "") != "":
					items.append(resolved)
	var best_res: Dictionary = _mind().best_resentment_against(w, mind, t_id)
	if not best_res.is_empty():
		var r_strength: float = float(best_res.get("strength", 0.0))
		if r_strength >= 0.03:
			var f_id: String = str(best_res.get("friend", ""))
			var f_nm: String = w.by_id[f_id].name if w.by_id.has(f_id) else f_id
			var r_why: String = ("they pushed to hang %s" % f_nm) if str(best_res.get("role", "nominator")) == "nominator" else ("they voted to hang %s" % f_nm)
			items.append({
				"eid": "resentment:%s:%s" % [f_id, t_id],
				"why": r_why,
				"kind": "public",
				"strength": clampf(r_strength * 2.0, 0.25, 0.75),
				"contrib": r_strength,
				"entry": {},
				"channel": "resentment",
			})
	items.sort_custom(func(x, y): return float(x["contrib"]) > float(y["contrib"]))
	return items.slice(0, limit)

## The nominator lays out their case: public reasons recapped (cosmetic: hearing them again
## changes nothing), and their strongest private one hinted at or brought out (claim and
## reading, with their usual effect, as at any other time). Returns {lines, facts}.
static func nomination_case(w, n, t, already: String) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	if already.begins_with("I saw"):
		_append_accusation_sighting(w, n, t, already, lines, facts)
	var items = case_against(w, n, t.id)
	var recap: Array = items.filter(func(x): return x["kind"] == "public" and x["why"] != already).map(func(x): return x["why"])
	for r_why in recap.slice(0, 2):
		if str(r_why).begins_with("I saw"):
			_append_accusation_sighting(w, n, t, str(r_why), lines, facts)
	var priv: Array = items.filter(func(x): return x["kind"] in ["private", "player"])
	var relays: Array = items.filter(func(x): return x["kind"] == "relay")
	if priv.is_empty() and not relays.is_empty():
		relay_reading(w, n, relays[0]["src"], relays[0]["entry"], lines, facts)
	var description = ", ".join(PackedStringArray(items.map(func(x): return "%s (%s, %.2f)" % [x["why"], x["kind"], x["contrib"]])))
	w.dlog.think(n.id, "nomination_case", "Case against %s: %s." % [t.id, description if description != "" else "no citable reasons on record"], {"items": items.map(func(x): return {"eid": x["eid"], "kind": x["kind"]})})
	if items.is_empty():
		lines.append(say_voiced(n, "nomination_no_reasons", "I don't trust %s, and I can't say better than that." % t.name, {"target": t.name}))
	if not recap.is_empty():
		var recap_s: String = "; and ".join(PackedStringArray(recap.slice(0, 2))).trim_suffix(".")
		lines.append(say_voiced(n, "nomination_recap", "Remember: %s." % recap_s, {"recap": recap_s}))
	if not priv.is_empty():
		var top: Dictionary = priv[0]
		var cost = reveal_cost(w, n)
		var nom_susp: float = susp(n.shadow if n.is_evil() and n.shadow != null else n, t.id)
		var parts = {"strength": (top["strength"] - 0.45) * 1.4,
			"suspicion": (nom_susp - Tuning.Meeting.REVEAL_SUSPICION_PIVOT) * Tuning.Meeting.REVEAL_SUSPICION_SLOPE,
			"confidence": (trait_of(n, "confidence") - 0.5) * 0.6, "nominating": 0.2}
		for k in cost:
			parts["cost_" + k] = -cost[k]
		if decide(w, n, "reveal_to_nominate", parts, "Bring out what points at %s (%s) to back the nomination?" % [t.id, top["why"]]):
			_public_disclosure(w, n, lines, facts)
			# The disclosure shares the gift and readings, not sightings: also state the private
			# observations behind the nomination (as _public_accusation does), so the town hears
			# them and the nominee's defence can answer them.
			for p_item in priv.slice(0, 2):
				if p_item.get("own_sighting", false) and str(p_item.get("why", "")).begins_with("I saw"):
					_append_accusation_sighting(w, n, t, str(p_item["why"]), lines, facts)
		else:
			n.hints[t.id] = {"day": w.day, "src": top["eid"]}
			lines.append(say_voiced(n, "nomination_held_reason", "And I have another reason I'm not ready to share yet."))
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
static func _reading_known_to_defender(d, src_id: String, rd: Dictionary, disclosed_facts: Array) -> bool:
	if rd.get("shared", false):
		return true
	for f in disclosed_facts:
		if f.get("kind", "") == "info" and f.get("source", "") == src_id and f.get("role", "") == rd.get("role", "") and int(f.get("day", -2)) == int(rd.get("day", -1)):
			return true
	var d_mind = d.shadow if d.is_evil() and d.shadow != null else d
	if d_mind.known_claims.has(src_id) and rd in d_mind.known_claims[src_id].get("readings", []):
		return true
	var eid: String = info_eid(src_id, rd)
	if not d_mind.ledger.has(eid):
		return false
	var receipts: Dictionary = d_mind.ledger[eid].get("meta", {}).get("workshop_receipts", {})
	if receipts.is_empty():
		return true
	return receipts.values().any(func(r): return not r.get("content", {}).get("anonymous", false))

static func _disclosed_items_against(w, d, accuser, disclosed_facts: Array) -> Array:
	var out: Array = []
	var seen_eids: Dictionary = {}
	var d_mind = d.shadow if d.is_evil() and d.shadow != null else d
	if accuser != null:
		for it in case_against(w, accuser, d.id, 6):
			if it.get("own_sighting", false):
				var sight_spoken: bool = bool(it.get("own_sighting_disclosed", false)) or disclosed_facts.any(func(f): return f.get("kind", "") == "sighting" and f.get("source", "") == accuser.id and d.id in f.get("subject", []))
				if sight_spoken:
					out.append(it)
					seen_eids[it["eid"]] = true
			elif it["eid"].begins_with("info:"):
				var p: PackedStringArray = str(it["eid"]).split(":")
				var sn = w.by_id.get(p[1]) if p.size() >= 2 else null
				if sn != null and not it["entry"].is_empty() and _reading_known_to_defender(d, sn.id, it["entry"], disclosed_facts):
					out.append(it)
					seen_eids[it["eid"]] = true
			elif it["kind"] == "public" or d_mind.ledger.has(it["eid"]):
				out.append(it)
				seen_eids[it["eid"]] = true
	for f in disclosed_facts:
		if f.get("kind", "") == "info" and d.id in f.get("subject", []):
			var src_id: String = str(f.get("source", ""))
			var sn2 = w.by_id.get(src_id)
			if sn2 == null or sn2 == d:
				continue
			for en in sn2.info_log:
				if en.get("role", "") == f.get("role", "") and int(en.get("day", -1)) == int(f.get("day", -2)):
					var eid2: String = info_eid(src_id, en)
					if not seen_eids.has(eid2):
						var r_score: Dictionary = ReasonAttribution.score_reading_entry_in_world(w, src_id, en, d.id)
						out.append({"eid": eid2, "why": "their reading pointed at me", "contrib": float(r_score["contrib"]), "kind": "public", "strength": float(r_score["strength"]), "entry": en, "channel": "report"})
						seen_eids[eid2] = true
		elif f.get("kind", "") == "sighting" and d.id in f.get("subject", []):
			var s_eid: String = "sighting:%s:%s:%d:%s" % [str(f.get("source", "")), d.id, int(f.get("day", -1)), str(f.get("block", ""))]
			if not seen_eids.has(s_eid):
				var s_score: Dictionary = ReasonAttribution.score_disclosed_fact_in_world(w, d_mind, f, d.id)
				out.append({"eid": s_eid, "why": "seen out at night", "contrib": float(s_score["contrib"]), "kind": "public", "strength": float(s_score["strength"]), "entry": {}, "channel": "movement_out"})
				seen_eids[s_eid] = true
	return out

static func defend_self(w, d, nominator_id: String, disclosed_facts: Array = []) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var moves: Array = []
	if d.silenced:
		return {"lines": [{"speaker": d.id, "name": d.name, "text": "...", "silent": true}], "facts": [], "moves": ["silenced"]}
	var accuser = w.by_id.get(nominator_id) if nominator_id != "player" else null
	if accuser == null:
		var best = 0.0
		for m in w.living():
			if m != d and susp(m, d.id) > best:
				best = susp(m, d.id)
				accuser = m
	var items: Array = _disclosed_items_against(w, d, accuser, disclosed_facts)
	var role: String = w.evil_plan["bluffs"].get(d.id, "") if d.is_evil() else d.role
	var out_items: Array = items.filter(func(x): return x.get("channel", "") in ["movement_out", "alibi_contradiction"] or "out" in x["why"] or "night" in x["why"])
	var out_weight = 0.0
	for x in out_items:
		out_weight += x["contrib"]
	var move_strengths = {}
	var move_scales = {}
	var defence_scopes = {}
	# 1. A gift that walks at night explains being seen out.
	if not out_items.is_empty() and C.ROLES.get(role, {}).get("night_walk", false):
		var parts = {"facing_the_rope": C.DEFENCE_ROPE, "strength": maxf(0.2, out_weight)}
		var safety: float = block_safety(w, d)
		if safety > 0.0:
			parts["block_safety"] = -safety * Tuning.Meeting.BLOCK_SAFETY_DEFENCE_RELIEF
		for k in reveal_cost(w, d):
			parts["cost_" + k] = -reveal_cost(w, d)[k]
		if d.claim_public or decide(w, d, "defence_reveal", parts, "Explain being out with my gift (%s)?" % role):
			if not d.claim_public:
				_public_disclosure(w, d, lines, facts)
			lines.append(say_voiced(d, "defence_reveal", "I was out because I'm the %s. That's what you saw." % C.role_name(role), {"role": C.role_name(role)}))
			moves.append("reveal")
			move_strengths["reveal"] = minf(Tuning.Meeting.DEFENCE_REVEAL_CAP, out_weight)
			move_scales["reveal"] = 1.0
			defence_scopes["reveal"] = {"type": "gift_claim", "role": role}
	# 2. A personal secret explains it (good only: evil has nothing true to confess).
	if moves.is_empty() and not out_items.is_empty() and not d.is_evil() and not d.secret.is_empty():
		var confess_parts = {"facing_the_rope": 0.5, "privacy": (0.4 - trait_of(d, "privacy")) * 1.0}
		var confess_safety: float = block_safety(w, d)
		if confess_safety > 0.0:
			confess_parts["block_safety"] = -confess_safety * Tuning.Meeting.BLOCK_SAFETY_DEFENCE_RELIEF
			w.dlog.think(d.id, "defence", "Weighs holding back: %s is already on the block (%d votes)." % [str(w.meeting.get("block", "")), int(w.meeting.get("block_count", 0))])
		if decide(w, d, "defence_confess", confess_parts, "Confess my secret to explain being out?"):
			d.secret_known = true
			lines.append(say_voiced(d, "confess_secret_public", "I wasn't out for anything wicked. I %s." % d.secret.get("me", d.secret.get("text", "")), {"secret": d.secret.get("me", d.secret.get("text", ""))}))
			facts.append({"kind": "secret", "subject": [d.id], "owner": d.id, "source": d.id,
				"secret_kind": d.secret.get("kind", ""), "mod": "lovers" if d.secret.get("kind", "") == "lover" else "",
				"text": "%s confessed at the meeting why they were out: %s %s." % [d.name, d.name, d.secret.get("text", "")]})
			moves.append("secret")
			move_strengths["secret"] = minf(Tuning.Meeting.DEFENCE_SECRET_CAP, out_weight)
			move_scales["secret"] = 1.0
			defence_scopes["secret"] = {"type": "secret_claim", "owner": d.id, "kind": d.secret.get("kind", "")}
	# 2b. "I've been known to sleepwalk": the real Sleepwalker (who can't know they were
	# out, only that they've walked before) or an evil bluffer whose cover needs it.
	if moves.is_empty() and not out_items.is_empty():
		var excuse: Dictionary = sleepwalk_excuse(w, d, "the meeting")
		if not excuse.is_empty():
			lines.append(excuse["line"])
			facts.append(excuse["fact"])
			moves.append("sleepwalk")
			move_strengths["sleepwalk"] = 1.0
			move_scales["sleepwalk"] = 1.0
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
					if info_eid(sn.id, en) == x["eid"] and _reading_known_to_defender(d, sn.id, en, disclosed_facts):
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
				move_strengths[mv_name] = 1.0
				move_scales[mv_name] = float(custom_def.get("hearing_scale", 0.05))
				defence_scopes[mv_name] = custom_def["scope"]
			elif pair.size() == 2 and d.id in pair:
				# One incident, one hearing: "it's the other one" accepts the reading, "the
				# reading is wrong" rejects it, so never both. Point at the other only when
				# that's what they believe (good: they suspect the other at least as much as
				# the source; evil: the other isn't a teammate); otherwise challenge it below.
				var other: String = pair[0] if pair[1] == d.id else pair[1]
				var fits: bool = (not Evil.is_teammate(w, d, other)) if d.is_evil() else susp(d, other) >= susp(d, src_id)
				if fits and w.by_id.has(other) and w.by_id[other].alive:
					var other_name: String = w.by_id[other].name
					lines.append(say_voiced(d, "defence_pair_other", "One of the two, %s said. It isn't me, so look at %s." % [src.name, other_name], {"source": src.name, "other": other_name}))
					moves.append("pair_other")
					move_strengths["pair_other"] = 1.0
					move_scales["pair_other"] = Tuning.Meeting.DEFENCE_PAIR_OTHER_DELTA
					defence_scopes["pair_other"] = {"type": "rival", "source": src_id, "other": other}
			if moves.size() < 2 and not ("red_herring" in moves) and not ("pair_other" in moves):
				if trait_of(d, "confidence") > 0.6:
					lines.append(say_voiced(d, "defence_lying", "Then %s is lying, and you should ask yourselves why." % src.name, {"source": src.name}))
					moves.append("lying")
					move_strengths["lying"] = 1.0
					move_scales["lying"] = maxf(absf(float(Tuning.Meeting.DEFENCE_LYING_RELIEF)), absf(float(C.DEFENCE_LIE_BLOWBACK)))
					defence_scopes["lying"] = {"type": "challenge", "mode": "lying", "reading": WorkshopLedger.reading(src_id, rd).id}
				else:
					lines.append(say_voiced(d, "defence_misled", "%s's gift could have been turned. It's happened before." % src.name, {"source": src.name}))
					moves.append("misled")
					move_strengths["misled"] = 1.0
					move_scales["misled"] = absf(float(Tuning.Meeting.DEFENCE_MISLED_RELIEF))
					defence_scopes["misled"] = {"type": "challenge", "mode": "misled", "reading": WorkshopLedger.reading(src_id, rd).id}
	# 4. Nothing to show: fear, or the desperation play.
	if moves.is_empty():
		if _afraid(w, d) and not d.claim_public:
			lines.append(say_voiced(d, "defence_fear_plea", "If I say what I am, I'll be dead by morning. But I'm not what you think."))
			moves.append("fear")
		else:
			lines.append(say_voiced(d, "defence_desperation", "I don't know what's going on, but I know I'm not evil."))
			moves.append("desperation")
		move_strengths[moves[0]] = 1.0
		move_scales[moves[0]] = absf(float(Tuning.Meeting.DEFENCE_PLEA_RELIEF))
		defence_scopes[moves[0]] = {"type": "plea"}
	for mv in move_strengths:
		var scope: Dictionary = defence_scopes[mv]
		var identity: String = "def:%s:%s:%s" % [d.id, scope.type, JSON.stringify(WorkshopLedger.Evidence.canonical(scope)).sha256_text()]
		var strength: float = float(move_strengths[mv])
		for l in w.living():
			if l == d:
				continue
			var meta = {"kind": "defence", "move": mv, "scope": scope.duplicate(true), "hearing_scale": float(move_scales.get(mv, 1.0))}
			if scope.type == "gift_claim":
				meta["workshop_card"] = WorkshopLedger.Evidence.normalize_card({"kind": "claim", "source": d.id, "subject": [d.id], "role": scope.role, "day": w.day, "phase": w.phase, "text": "Walking-gift defence."})
			elif scope.type == "secret_claim":
				meta["workshop_card"] = WorkshopLedger.Evidence.normalize_card({"kind": "secret", "source": d.id, "subject": [d.id], "owner": d.id, "secret_kind": scope.kind, "day": w.day, "phase": w.phase, "text": "Confessed errand defence."})
			if l.ledger.get(identity, {}).get("meta", {}).has("workshop_card"):
				meta["workshop_card"] = l.ledger[identity].meta.workshop_card
			ledger_hear(w, l, identity, [], strength * (0.5 + 0.5 * l.npc_trust.get(d.id, 0.5)),
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
		var scion_safe: bool = Evil.scion_fallback_active(w)
		if w.by_id[nominee].role == "demon" and not scion_safe:
			w.dlog.think(v.id, "team_survival", "Votes no on the demon: later voters can make even an early vote decisive.")
			return false
		if v.id == nominator and not Evil.is_teammate(w, v, nominee):
			w.dlog.think(v.id, "vote", "YES on %s. Follows through on own nomination." % nominee, {"evil": true})
			return true
		var evil_yes: bool = Evil.evil_vote(w, v, nominee, yes_so_far, player_yes)
		if not C.SHADOW_SELF:
			return evil_yes
		var have = yes_so_far + (1 if player_yes else 0)
		var order: Array = w.vote_order(nominee)
		var my_idx: int = order.find(v.id)
		var expected_later: int = 0
		var remaining_possible: int = 0
		if my_idx >= 0:
			for k_idx in range(my_idx + 1, order.size()):
				var rem_id: String = order[k_idx]
				if rem_id == nominee:
					continue
				remaining_possible += 1
				if rem_id == "player" or not w.by_id.has(rem_id):
					continue
				var rem_n = w.by_id[rem_id]
				if rem_n.is_evil() and evil_yes:
					expected_later += 1
				elif w.stances.get(rem_id, {}).get("target", "") == nominee and int(w.stances.get(rem_id, {}).get("day", -1)) == w.day:
					expected_later += 1
		var target_votes: int = maxi(w.vote_threshold(), int(w.meeting.get("block_count", 0)))
		var cur_block: String = w.meeting.get("block", "")
		var demon_on_block: bool = cur_block != "" and cur_block == w.demon_id
		if v.id == w.demon_id and demon_on_block and not scion_safe and evil_yes and not Evil.is_teammate(w, v, nominee) and have + 1 + remaining_possible >= target_votes:
			w.dlog.think(v.id, "team_survival", "Demon on the block backs counter-nominee %s: survival overrides cover." % nominee)
			return true
		# Shadow self (step 2): vote as their good self would, unless breaking cover is worth it.
		var sh_yes = shadow_eval(w, v, func(sh): return vote(w, sh, nominee, nominator, player_yes, statement, yes_so_far))
		if sh_yes == null or sh_yes == evil_yes:
			return evil_yes
		var projected: int = have + 1 + expected_later
		var pivot = 1.0 if (absi(have + 1 - target_votes) <= 1 or (projected >= target_votes - 1 and have + 1 <= target_votes + 1)) else 0.45
		var landslide: bool = have >= target_votes or projected >= target_votes + 2
		var mate_on_block: bool = cur_block != "" and w.by_id.has(cur_block) and w.by_id[cur_block].is_evil()
		var rescue: float = 0.0
		if demon_on_block:
			rescue = (Tuning.Meeting.EVIL_VOTE_RESCUE_MINION * (0.5 if v.role == "scion" else 1.0)) if scion_safe else Tuning.Meeting.EVIL_VOTE_RESCUE_DEMON
		elif mate_on_block:
			rescue = Tuning.Meeting.EVIL_VOTE_RESCUE_MINION
		var stakes = 0.3
		if Evil.is_teammate(w, v, nominee) or w.by_id[nominee].role == "demon":
			if not evil_yes:
				var mate_pivot: float = 1.0 if pivot >= 1.0 else (Tuning.Meeting.EVIL_VOTE_LANDSLIDE_PIVOT if landslide else Tuning.Meeting.EVIL_VOTE_NONPIVOTAL_TEAMMATE)
				stakes = Evil.teammate_value(w, nominee) * mate_pivot
				if scion_safe and w.by_id[nominee].role == "demon" and v.role == "scion":
					stakes *= Tuning.Meeting.EVIL_VOTE_SCION_COVER_MULT
			else:
				stakes = 0.75
		elif evil_yes:
			stakes = (0.55 + (0.30 if nominee == w.evil_plan.get("scapegoat", "") else 0.0)) * pivot + rescue
		var detail = "%s on %s (good self: %s)" % ["YES" if evil_yes else "no", nominee, "yes" if sh_yes else "no"]
		return evil_yes if evil_override(w, v, "vote", stakes, 0.6, detail) else sh_yes
	reconsider(w, v, "thinking it over before the vote")
	var base = action_susp(v, nominee)
	var v_resent: float = _mind().resentment_toward(w, v, nominee)
	var s = base
	var parts = {"suspicion": snappedf(susp(v, nominee), 0.01), "town_pressure": base - execution_priority_contribution(v, nominee) - susp(v, nominee)}
	if C.SHARED_EXECUTION_PRIORITY_WEIGHT != 0.0:
		parts["shared_execution_priority"] = execution_priority_contribution(v, nominee)
	if v_resent > 0.0:
		parts["resentment"] = v_resent
	if player_yes:
		parts["player_votes_yes"] = Tuning.Meeting.PLAYER_VOTE_YES_SLOPE * v.credibility + Tuning.Meeting.PLAYER_VOTE_YES_OFFSET
	if statement == "defend":
		parts["player_defends"] = Tuning.Meeting.PLAYER_DEFEND_SLOPE * v.credibility
	elif statement == "accuse":
		parts["player_accuses"] = Tuning.Meeting.PLAYER_ACCUSE_SLOPE * v.credibility
	if nominator != "player" and susp(v, nominator) > Tuning.Meeting.VOTE_DISTRUST_NOMINATOR_MIN_SUSP:
		parts["distrusts_nominator"] = Tuning.Meeting.VOTE_DISTRUST_NOMINATOR_OFFSET
	if v.spare_pref.get(nominee, 0.0) > 0.0:
		parts["persuaded_to_spare"] = Tuning.Meeting.VOTE_SPARE_PREF_SLOPE * v.spare_pref[nominee]
	var block: String = w.meeting["block"]
	if block != "" and block != nominee and (action_susp(v, block) + _mind().resentment_toward(w, v, block)) >= (base + v_resent):
		parts["prefers_block"] = Tuning.Meeting.VOTE_PREFERS_BLOCK_OFFSET
	C.role_def(v.role).score_vote_reluctance(w, v, nominee, base, paranoia(w, v), parts)
	for k in parts:
		if k not in ["suspicion", "town_pressure", "shared_execution_priority"]:
			s += parts[k]
	var conf_need: float = -Tuning.Meeting.VOTE_CONFIDENCE_SCALE * (trait_of(v, "confidence") - 0.5) * 2.0
	var early_need: float = Tuning.Meeting.VOTE_DAY1_PENALTY if w.day <= 1 else 0.0
	var para_need: float = -Tuning.Meeting.VOTE_PARANOIA_WEIGHT * paranoia(w, v)
	var urg_need: float = -Tuning.Meeting.VOTE_URGENCY_PER_DEATH * w.npcs.filter(func(m): return not m.alive).size()
	var need: float = Tuning.Meeting.VOTE_BASE_NEED + conf_need + early_need + para_need + urg_need
	if v.id == nominator and (block == "" or block == nominee or action_susp(v, nominee) > action_susp(v, block)) and s < need:
		var commit_gap: float = (need - s) + Tuning.Meeting.VOTE_SELF_NOMINATION_MARGIN
		parts["self_nomination"] = commit_gap
		s += commit_gap
	var yes = s >= need
	var exact_parts: Dictionary = parts.duplicate()
	exact_parts["suspicion"] = susp(v, nominee) # pressure is reported separately
	w.dlog.decision(v.id, "vote", "evaluation", yes, {"parts": exact_parts,
		"score": s, "threshold": need, "comparison": ">=", "margin": s - need,
		"inputs": {"confidence": trait_of(v, "confidence"), "composure": trait_of(v, "composure"),
			"paranoia": paranoia(w, v), "trust": v.trust, "credibility": v.credibility, "trust_in_nominee": v.npc_trust.get(nominee, 0.5), "suspicion": susp(v, nominee)},
		"threshold_parts": {"base": Tuning.Meeting.VOTE_BASE_NEED,
			"confidence": conf_need, "early_day": early_need, "paranoia": para_need, "urgency": urg_need},
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

static func _observation_lines(n, groups: Array, audience: String, speech_act: String, preceded: bool, first_relation: String = "independent") -> Array:
	return _mind()._observation_lines(n, groups, audience, speech_act, preceded, first_relation)

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

static func ledger_hear(w, n, eid: String, _effects: Array = [], weight: float = 1.0, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	return _mind().ledger_hear(w, n, eid, [], weight, rel, meta)

static func paranoia(w, n) -> float:
	return _mind().paranoia(w, n)

static func ranked_suspects(w, n, social_pressure: bool = false) -> Array:
	return _mind().ranked_suspects(w, n, social_pressure)

static func refresh_beliefs(w, n, note: String) -> void:
	_mind().refresh_beliefs(w, n, note)

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
