## Town meeting reasoning and flow for NPCs: public testimony, volunteering night
## sightings, public role claims, citing reasons, anonymous relays, social consensus
## pressure, accusations and choosing nominations.
##
## The nominator's case is in `sim/mind_nomination.gd`, the defence in
## `sim/mind_defence.gd` and the vote in `sim/mind_vote.gd`; all four share
## `sim/mind_meeting_base.gd`. `Mind` keeps forwarding wrappers for the main entry points.
extends "res://sim/mind_meeting_base.gd"


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
		_late_relay(w, n, lines, facts)
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
		if l.is_evil() and my_role in claimed and switch_taken_bluff(w, l):
			my_role = str(w.evil_plan["bluffs"][l.id])  # its bluff was just taken: no rival claim to answer
		elif l.is_evil() and not claimed.is_empty() and not (my_role in claimed) and choose_double_claim(w, l, s, str(claimed[0])):
			my_role = str(claimed[0])
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

## A reading the dead told them privately, brought to the town (Nov 5): it would be lost
## otherwise. Named, since there's no one left to protect. At most one per speaker per
## meeting; the more they trusted the dead, the likelier. Good minds only for now (evil
## inventing a dead person's reading is a follow-up).
static func _late_relay(w, n, lines: Array, facts: Array) -> void:
	if n.is_evil() or n.silenced:
		return
	for src_id in n.known_claims:
		if not w.by_id.has(src_id) or w.by_id[src_id].alive or src_id == n.id:
			continue
		var src = w.by_id[src_id]
		for e in n.known_claims[src_id].get("readings", []):
			if not e is Dictionary or _reading_public(w, src, e):
				continue
			var key: String = "town|late:%s:%d:%s" % [src_id, int(e.get("day", -1)), str(e.get("role", ""))]
			if n.told_to.has(key):
				continue
			var parts = {"base": Tuning.Meeting.LATE_RELAY_BASE,
				"trust_in_dead": (n.npc_trust.get(src_id, 0.5) - 0.5) * Tuning.Meeting.LATE_RELAY_TRUST_SLOPE,
				"openness": (0.5 - trait_of(n, "privacy")) * Tuning.Meeting.LATE_RELAY_OPENNESS_SLOPE}
			if not decide(w, n, "late_relay", parts, "Tell the town what %s told them before dying (%s, day %d)?" % [src_id, str(e.get("role", "")), int(e.get("day", -1))]):
				continue # they may yet, at a later meeting
			n.told_to[key] = true
			var rn: String = C.role_name(e["role"])
			# Say when, relative to today, once: a "night N" inside the reading's own text (the
			# Veteran's, the Medium's) is dropped if it's that night, or said as a person would.
			var rday: int = int(e.get("day", w.day))
			var said: String = "%s %s" % [C.spoken_when(rday, w.day), C.third_person(relay_body(reading_body(e["text"]), rday, w.day))]
			lines.append(say_voiced(n, "meeting_late_relay", "Before %s died, they told me they were the %s, and that %s." % [src.name, rn, said],
				{"dead": src.name, "role": rn, "reading": said}))
			var f: Dictionary = info_fact(w, src, e)
			f["via"] = n.id
			f["public"] = true
			f["text"] = "%s says the late %s (as %s, night %d) told them: %s." % [n.name, src.name, rn, int(e.get("day", -1)), said]
			facts.append(f)
			# Told before the town: public grounds for every mind, the teller's own copy
			# included (Codex review of PR #77). The source's own statement stays private.
			for l in w.living():
				if l != n:
					apply_info(w, l, src, e, C.RELAY_WEIGHT * heard_weight(l, n), n.id, false, true)
			apply_info(w, n, src, e, Tuning.Meeting.LATE_RELAY_TELLER_MARK, "", false, true)
			w.public_event("reading", Gifts.implicated(e), n.id)
			w.dlog.think(n.id, "relay", "Tells the town %s's private %s reading, heard before they died." % [src_id, e["role"]], {"src": src_id})
			return

## Has this reading of src already been told to the whole town?
static func _reading_public(w, src, e: Dictionary) -> bool:
	for own in src.info_log:
		if int(own.get("day", -1)) == int(e.get("day", -2)) and str(own.get("role", "")) == str(e.get("role", "")):
			return src.claim_public and bool(own.get("shared", false))
	return false

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

## Who else, as far as n knows, claims `role`: a public claim, or one n heard of (gossip, a
## private claim passed on). Living only.
static func rival_claimants(w, n, role: String) -> Array:
	var out: Array = []
	if role == "":
		return out
	for o in w.living():
		if o == n:
			continue
		var heard: bool = n.known_claims.has(o.id) and str(n.known_claims[o.id].get("role", "")) == role
		if (o.claim_public and o.claimed_role == role) or heard:
			out.append(o.id)
	return out

## Evil whose planned bluff someone else has claimed first, before it has claimed anything,
## drops it for a spare from evil's bluff list (Michael, Nov 19), rather than counterclaim.
## Not if it has already told a fake reading of the old bluff: that's committed. Returns
## whether it switched.
static func switch_taken_bluff(w, n) -> bool:
	# A Revenant-turned townsperson keeps its own gift as its cover: nothing to switch.
	if not n.is_evil() or n.turned or n.claim_public or n.claimed_role != "":
		return false
	var bluff: String = str(w.evil_plan["bluffs"].get(n.id, ""))
	if str(n.dialogue_memory.get("double_claim", {}).get("role", "")) == bluff:
		return false  # a double claim it chose: the rival is the point
	var rivals: Array = rival_claimants(w, n, bluff)
	if rivals.is_empty():
		return false
	if n.info_log.any(func(e): return e.get("fake", false) and e.get("role", "") == bluff and e.get("shared", false)):
		return false
	var used: Array = w.evil_plan["bluffs"].values()
	var spares: Array = w.bluffs.filter(func(r): return r not in used and rival_claimants(w, n, r).is_empty())
	if spares.is_empty():
		return false
	var spare: String = str(spares[0])
	_change_bluff(w, n, bluff, spare)
	w.dlog.think(n.id, "bluff_switch", "Bluff taken (%s claimed the %s); switched to the %s." % [w.by_id[rivals[0]].name, C.role_name(bluff), C.role_name(spare)],
		{"from": bluff, "to": spare, "rival": rivals[0], "why": "bluff taken; switched to %s" % spare})
	return true

## Evil drops its planned bluff `old` for `new` before claiming either (Codex on #390): its
## untold fabrications of the old gift go, from its log and from those held back a day, and
## its shadow (its good self) drops their evidence and takes the new gift as its own, with
## its reading cursor moved back past what was removed.
static func _change_bluff(w, n, old: String, new: String) -> void:
	var cursor: int = int(n.shadow_seen.get("fake", 0)) if n.shadow_seen is Dictionary else 0
	var keep: Array = []
	var removed_before: int = 0
	for i in range(n.info_log.size()):
		var e: Dictionary = n.info_log[i]
		if e.get("fake", false) and e.get("role", "") == old:
			if i < cursor:
				removed_before += 1
			continue
		keep.append(e)
	n.info_log = keep
	if n.shadow_seen is Dictionary and n.shadow_seen.has("fake"):
		n.shadow_seen["fake"] = cursor - removed_before
	n.held_fakes = n.held_fakes.filter(func(h): return str(h.get("entry", {}).get("role", "")) != old)
	w.evil_plan["bluffs"][n.id] = new
	if n.shadow != null:
		var s = n.shadow
		for e in s.info_log:
			if e.get("fake", false) and e.get("role", "") == old:
				s.ledger.erase(_mind().info_eid(s.id, e))
		s.info_log = s.info_log.filter(func(e): return not (e.get("fake", false) and e.get("role", "") == old))
		s.applied_info = s.info_log.size()
		s.role = new if C.ROLES.has(new) and C.ROLES[new]["align"] == "good" else ""

## A Minion that hears a claim may take that gift as its own bluff: a deliberate double
## claim (Michael, Nov 19). Never the Demon or a Scion, never once it has claimed, nor if a
## told fake reading commits it to its bluff. Heat (being already implicated, Evil.exposure's
## public talk) makes it a poorer bet. Returns whether it chose to.
static func choose_double_claim(w, l, rival, role: String) -> bool:
	# A real Minion only: a Revenant-turned townsperson is evil but keeps its own gift (Codex on #390).
	if not l.is_evil() or not C.is_minion(l.role) or l.turned or l.id == w.demon_id or l.role == "scion" or l.claim_public or l.claimed_role != "" or l.silenced:
		return false
	if role == "" or C.ROLES.get(role, {}).get("kind", "") == "evil":
		return false
	if l.info_log.any(func(e): return e.get("fake", false) and e.get("shared", false)):
		return false
	# One roll per Minion per game, up front (Michael, Nov 20): is it looking to double-claim
	# at all? Then at each claim it hears, heat decides whether it acts: already implicated
	# (Evil.exposure's public talk), it lets the chance pass. Both draws are its own, seeded
	# from the case, so the world's stream moves only when a double claim is made.
	var intent := RandomNumberGenerator.new()
	intent.seed = hash([w.seed_value, l.id, "minion_double_claim_intent"])
	var intent_draw: float = intent.randf()
	if intent_draw >= Tuning.Evil.MINION_DOUBLE_CLAIM_CHANCE:
		return false
	var heat: float = float(Evil.exposure(w, l).get("public_talk", 0.0))
	var p: float = clampf(1.0 - heat, 0.0, 1.0)
	var drng := RandomNumberGenerator.new()
	drng.seed = hash([w.seed_value, w.day, l.id, rival.id, role, "minion_double_claim"])
	var draw: float = drng.randf()
	if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
		w.dlog.decision(l.id, "minion_double_claim", "roll", draw < p, {"mechanism": "probability", "inputs": {"intent": intent_draw, "chance": Tuning.Evil.MINION_DOUBLE_CLAIM_CHANCE, "public_talk": heat}, "probability": p, "draw": draw}, rival.id)
	if draw >= p:
		return false
	var old: String = str(w.evil_plan["bluffs"].get(l.id, ""))
	_change_bluff(w, l, old, role)
	l.dialogue_memory["double_claim"] = {"day": w.day, "rival": rival.id, "role": role}
	w.dlog.think(l.id, "plan", "Will claim the %s too, the gift %s just claimed: a deliberate double claim (heat %.2f)." % [C.role_name(role), rival.name, heat], {"from": old, "to": role, "rival": rival.id})
	return true

static func _public_claim_decision(w, n) -> String:
	if n.is_evil():
		switch_taken_bluff(w, n)
	var role: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	# Someone else claims my gift: the true holder counterclaims at its first chance, this
	# meeting or (silenced, or it heard of the claim elsewhere) the next (Michael, Nov 19).
	if not n.is_evil():
		var rivals: Array = rival_claimants(w, n, role)
		if not rivals.is_empty():
			w.dlog.think(n.id, "counterclaim", "%s claimed my gift (the %s): I come out with it at once." % [", ".join(PackedStringArray(rivals.map(func(r): return w.by_id[r].name))), C.role_name(role)], {"rivals": rivals})
			w.observe_decision(n, "claim", true, {"gate": "counterclaim", "rivals": rivals})
			return role
	# A Minion's deliberate double claim, chosen when it heard the rival's claim.
	var dc: Dictionary = n.dialogue_memory.get("double_claim", {}) if n.is_evil() else {}
	if not dc.is_empty() and int(dc.get("day", -1)) == w.day and str(dc.get("role", "")) == role:
		w.dlog.think(n.id, "lie", "Claimed before the town to be the %s, the gift %s had just claimed: a deliberate double claim." % [C.role_name(role), w.by_id[str(dc.rival)].name],
			{"bluff": role, "true_role": n.role, "lie": true, "why": "a double claim casts doubt on the rival, and it wasn't yet implicated"})
		w.observe_decision(n, "claim", true, {"gate": "double_claim", "rival": dc.rival})
		return role
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
	# Promised to tell the Demonologist first once protected, or offered them a deal for it
	# today (a vigil, a ward, or keeping it quiet): hold it back until that's settled
	# (triage 3.2: Odette asked for a vigil, then claimed at that evening's meeting).
	if (n.protect_lock or n.request_day == w.day) and not (n.id in w.meeting.get("nominated", []) or n.pressure >= 0.7 or w.living().size() <= 4):
		w.observe_decision(n, "claim", false, {"gate": "protect_lock_promised_player_first" if n.protect_lock else "offered_player_a_deal_today"})
		return ""
	if w.living().size() <= 4:
		parts["few_left"] = Tuning.Meeting.PUBLIC_CLAIM_FEW_LEFT
	var why = ("Evil cover: publicly claim bluff %s?" % role) if n.is_evil() else ("Publicly reveal true role %s?" % role)
	if decide(w, n, "claim", parts, why):
		if n.is_evil():
			w.dlog.think(n.id, "lie", "Claimed before the town to be the %s, as cover." % C.role_name(role), {"bluff": role, "true_role": n.role})
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

## A relayed reading's body with its numbered nights put right for a speaker on `today`:
## the reading's own night is already said up front, so " on night N" for it goes; any other
## night is said the spoken way ("on the second night"). Card text keeps its numbers.
static func relay_body(body: String, reading_day: int, today: int) -> String:
	var re := RegEx.new()
	re.compile(" on night (\\d+)")
	var out: String = ""
	var cursor: int = 0
	for m in re.search_all(body):
		out += body.substr(cursor, m.get_start() - cursor)
		var nd: int = int(m.get_string(1))
		if nd != reading_day:
			out += " " + C.spoken_when(nd, today)
		cursor = m.get_end()
	out += body.substr(cursor)
	return C.natural_nights(out)

## Construct the exact public-facing report before a presentation layer touches it.
static func _info_intent(w, n, e: Dictionary) -> Dictionary:
	var spoken: String = C.spoken_when(e["day"], w.day)
	var when = spoken[0].to_upper() + spoken.substr(1)
	var body: String = reading_body(str(e["text"]))
	if body.contains(C.spoken_day(int(e["day"]))):
		# The reading already says which day (the Augur's "…the morning or afternoon of the
		# second day"; Michael, Nov 19): a lead naming the evening would read as when it happened.
		var said: String = "%s." % (body[0].to_upper() + body.substr(1))
		if str(e.get("role", "")) == "augur":
			# Each voice says it its own way, keeping "the morning or afternoon of {day}" (Michael,
			# Nov 19). The card keeps the canonical text.
			said = Dialogue.voice_line(n.id, "augur_yes" if bool(e.get("data", {}).get("yes", false)) else "augur_no", said, {"day": C.spoken_day(int(e["day"]))})
		return {"kind": "report", "statement": said, "event_id": info_eid(n.id, e)}
	if e.has("phase"):
		when = ("This " + C.PHASES[e["phase"]].to_lower()) if e["day"] == w.day else "On day %d, in the %s" % [e["day"], C.PHASES[e["phase"]].to_lower()]
	elif body.ends_with(" " + spoken):
		body = body.substr(0, body.length() - spoken.length() - 1) # the lead already says when
	return {"kind": "report", "statement": "%s, %s." % [when, body], "event_id": info_eid(n.id, e)}

## A reading's text as a clause: no closing punctuation (the sentence adds its own).
static func reading_body(text: String) -> String:
	var body: String = text.strip_edges()
	while body.length() > 0 and body[body.length() - 1] in [".", "!", "?"]:
		body = body.substr(0, body.length() - 1)
	return body

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
		"text": "%s (as %s, %s %d): %s." % [n.name, C.role_name(e["role"]), "day" if e.has("phase") else "night", e["day"], reading_body(str(e["text"]))]}
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
		var ranked: Array = _nomination().case_against(w, n, t_id, 1)
		if not ranked.is_empty():
			var top: Dictionary = ranked[0]
			var resolved = {"why": top["why"], "kind": top["kind"], "entry": top["entry"], "strength": top["strength"], "eid": top.get("eid", ""), "cards": top.get("cards", [])}
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
static func relay_reading(w, n, src, e: Dictionary, lines: Array, facts: Array) -> void:
	var rn = C.role_name(e["role"])
	var said = C.third_person(e["text"])
	lines.append(say_voiced(n, "meeting_relay_reading", "Word reached me from the %s: %s." % [rn, said], {"role": rn, "reading": said}))
	facts.append({"kind": "accusation", "subject": Gifts.implicated(e), "source": n.id, "relay": true, "role": e["role"],
		"text": "%s says the %s (unnamed) told them: %s." % [n.name, rn, said]})
	for l in w.living():
		if l != n and l != src:
			apply_info(w, l, src, e, C.RELAY_WEIGHT * heard_weight(l, n), n.id, true)
	w.dlog.think(n.id, "relay", "Relays %s's private %s reading without naming them." % [src.id, e["role"]], {"src": src.id})
	if src.alive and not src.silenced and not src.claim_public and w.decision_roll(src, "corroborate_relay", C.RELAY_CORROBORATE, {}, n.id):
		lines.append(say_voiced(src, "relay_claim_authorship", "That was me."))
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
		return {"tier": "relay", "why": "", "src": rs["src"], "entry": rs["entry"], "cards": rs.get("cards", [])}
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
## The promise itself still lapses through GameBoard._break_confidences as before.
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
		if C.has_role_def(n.role) and not n.is_evil():
			C.role_def(n.role).on_public_claim(w, n, lines, facts, _mind())
	elif C.has_role_def(n.role) and not n.is_evil() and n.claimed_role == n.role:
		C.role_def(n.role).on_public_update(w, n, lines, facts, _mind())
	if share_readings and C.has_readings(n.claimed_role):
		var PsychRole = preload("res://sim/roles/psychologist.gd")
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
		_say_gift_doubt(w, n, lines, facts)

## "My gift may have been turned" (BACKLOG, Michael, Nov 17-18), said once to the town by a
## public claimant who has it waiting (`n.gift_doubt`): for now only a boxed-in liar
## (Evil._boxed_in_gift_doubt). It is the teller's own word that its gift may have failed;
## listeners read it as honest doubt about all of that teller's readings.
static func _say_gift_doubt(w, n, lines: Array, facts: Array) -> void:
	_good_gift_doubt(w, n)
	var gd: Dictionary = n.gift_doubt
	if gd.is_empty() or gd.has("said") or not n.claim_public or n.claimed_role != str(gd.get("role", "")):
		return
	gd["said"] = w.day
	var role: String = str(gd["role"])
	if gd.get("first", false):
		# Only the one reading to doubt (its first for this gift): the singular line.
		lines.append(say_voiced(n, "doubt_own_gift_one", "Something seems off about that reading. I fear something might have turned my gift."))
	else:
		lines.append(say_voiced(n, "doubt_own_gift", "Something seems off about those readings, I fear something might have turned my gift."))
	# Listeners hear it through the public record (SourceDoubt.derive), not as a card: a new
	# card kind isn't one the Workshop's evidence takes (Lantern, Nov 18).
	w.public_event("self_doubt", [n.id], n.id, {"role": role})
	# Nothing else may be told this turn (the boxed-in liar dropped its reading), so the
	# listeners take it in now, or at the meeting's next refresh (Codex on #245).
	for l in w.living():
		if l != n:
			_mind().refresh_beliefs(w, l, "heard %s say their gift may have been turned" % n.id)
	var why: String = str(gd.get("why", ""))
	if n.is_evil():
		# The reveal lists it with the other lies, with its reason.
		# Michael's wording (Nov 18). The full reason stays in the "plan" entry.
		w.dlog.think(n.id, "lie", "Claimed its gift as the %s might have been turned, to explain away a made-up reading." % C.role_name(role), {"lie": true, "why": why})
	else:
		w.dlog.think(n.id, "self_doubt", "Tells the town its %s gift may have been turned (%s)." % [role, why])

## The good side (BACKLOG "Saying 'my gift may have been turned'" (a), Michael, Nov 17-19): a
## good public claimant that doubts a night of its own readings (SourceDoubt.doubts_own_gift:
## the judge's chance that night's reading was wrong, from its clash with everything else the
## NPC holds, at or above Workshop.SELF_DOUBT_TRIGGER) has it waiting to say, once a game, by
## the same route as the boxed-in liar. The earliest such night is the one it names.
static func _good_gift_doubt(w, n) -> void:
	if n.is_evil() or not n.claim_public or n.claimed_role != n.role or not n.gift_doubt.is_empty() or not C.has_readings(n.role):
		return
	var SD = load("res://workshop/source_doubt.gd")
	var nights: Array = SD.doubts_own_gift(n)
	if nights.is_empty():
		return
	var night: int = int(nights[0])
	var doubt: float = float(SD.self_doubt(n).get(night, 0.0))
	var why: String = ("%d%% doubt about all its readings" % int(round(doubt * 100.0))) if night == -1 \
		else ("%d%% doubt about its reading for %s" % [int(round(doubt * 100.0)), C.night_name(night)])
	n.gift_doubt = {"day": w.day, "role": n.role, "why": why, "night": night, "doubt": doubt}
	w.dlog.add("gift_doubt_planned", n.id, "", {"night": night, "doubt": snappedf(doubt, 0.001), "good": true},
		"%s (good, the %s) doubts its own readings enough to say so [%s]" % [n.name, C.role_name(n.role), why])

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
	if already_accused(w, n, t.id):
		return null # They've said it at this meeting already; once is enough.
	var parts = {"suspicion": (s2 - Tuning.Meeting.ACCUSE_SUSPICION_PIVOT) * Tuning.Meeting.ACCUSE_SUSPICION_SLOPE, "confidence": (trait_of(n, "confidence") - 0.5) * Tuning.Meeting.ACCUSE_CONFIDENCE_SLOPE,
		"pressure_deflect": n.pressure * Tuning.Meeting.ACCUSE_PRESSURE_DEFLECT}
	if acc_resent > 0.0:
		parts["resentment"] = acc_resent * Tuning.Meeting.ACCUSE_RESENTMENT_SLOPE
	var acc_opening: float = _testimony_openness(w, n)
	if acc_opening != 0.0:
		parts["reactive" if acc_opening > 0.0 else "crowd_fade"] = acc_opening
	if not decide(w, n, "accuse", parts, "Publicly accuse %s?" % t.id):
		return null
	return _accusation_body(w, n, t, s2, why, lines, facts)

## A public accusation of a chosen target (a supporter piling on in Step 4): the same
## voice as `_public_accusation` without its own choice of target or decision to speak.
static func accuse_named(w, n, t, lines: Array, facts: Array) -> Dictionary:
	var why: String = Evil.bluff_reason(w, n, t) if n.is_evil() else ""
	var s2: float = 0.8 if n.is_evil() else susp(n, t.id)
	return _accusation_body(w, n, t, s2, why, lines, facts)

## What they can say for an accusation: a reason the town already has, a hint at one
## they're keeping back, or their gift and its reading brought out now.
static func _accusation_body(w, n, t, s2: float, why: String, lines: Array, facts: Array) -> Dictionary:
	var relay_cards: Array = []
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
		w.dlog.think(n.id, "lie", ("Accused %s, evil's scapegoat, before the town, %s." % [t.name, "citing a reason they wouldn't share" if hint else ("citing \"%s\"" % why) if why != "" else "with no reason given"]))
	else:
		var tier = _accuse_tier(w, n, t, s2)
		if tier["tier"] == "reveal":
			_public_disclosure(w, n, lines, facts)
		elif tier["tier"] == "relay":
			relay_reading(w, n, tier["src"], tier["entry"], lines, facts)
			relay_cards = tier.get("cards", [])
		hint = tier["tier"] == "hint"
		hint_src = str(tier.get("eid", ""))
		why = tier["why"]
		w.dlog.think(n.id, "accuse_tier", "Accuses %s: %s%s." % [t.id, tier["tier"], (" (" + why + ")") if why != "" else ""])
	if hint:
		n.hints[t.id] = {"day": w.day, "src": hint_src}
	why = Evil.cite(w, n, why)
	if not hint:
		_nomination().recall_cited(w, n, t.id, [why], relay_cards)
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
	load("res://sim/social.gd").backing_trust(w, t.id, n.id, "accused %s, whom I suspect too" % t.id)
	var line: Dictionary
	# Agreeing needs someone else to agree with (a speaker who interjects can come round again).
	var others_earlier: Array = earlier.filter(func(a): return a.get("by", "") != n.id and w.by_id.has(a.get("by", "")))
	if not others_earlier.is_empty():
		# Someone already said it: agree rather than restate their grounds. Only grounds of
		# their own (their reading, what they saw) are worth adding.
		var first = w.by_id[others_earlier[0]["by"]]
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
			var echo_of: String = _said_by_other(w, n, "reason:" + reason_s)
			if echo_of != "":
				# The same grounds, already given at this meeting: point back rather than recite.
				var lc: String = reason_s[0].to_lower() + reason_s.substr(1)
				line = say_voiced(n, "meeting_accuse_reason_echo", "I don't trust %s either. As %s said, %s." % [t.name, w.by_id[echo_of].name, lc],
					{"target": t.name, "speaker": w.by_id[echo_of].name, "reason": lc})
			else:
				line = say_voiced(n, "meeting_accuse_reason", canonical_accuse, {"target": t.name, "reason": reason_s})
			_note_said(w, n, "reason:" + reason_s)
		else:
			line = say_voiced(n, "meeting_accuse_vibes", canonical_accuse, {"target": t.name})
	if w.meeting.has("accusations"):
		w.meeting["accusations"].append({"by": n.id, "target": t.id})
	var text = ("%s publicly accused %s, hinting at a private reason they won't share yet." if hint else "%s publicly accused %s.") % [n.name, t.name]
	return {"line": line,
		"fact": {"kind": "accusation", "subject": [t.id], "source": n.id, "text": text, "hint": hint}}

## n has already accused t at the current meeting (testimony or a supporter's pile-on).
static func already_accused(w, n, t_id: String) -> bool:
	return w.meeting.get("accusations", []).any(func(a): return a.get("by", "") == n.id and a.get("target", "") == t_id)

## Who else (living, not n) already said this at the current meeting, or "".
static func _said_by_other(w, n, key: String) -> String:
	var by: String = str(w.meeting.get("said", {}).get(key, ""))
	return by if by != "" and by != n.id and w.by_id.has(by) else ""

## Remember the first speaker of a line at this meeting (the meeting dict resets daily).
static func _note_said(w, n, key: String) -> void:
	if not w.meeting.has("said"):
		w.meeting["said"] = {}
	if not w.meeting.said.has(key):
		w.meeting.said[key] = n.id

## A spoken observation must leave the same usable card as asking the witness privately.
static func _append_accusation_sighting(w, n, target, why: String, lines: Array, facts: Array, spoken: Array = []) -> void:
	var candidates: Array = []
	if n.is_evil():
		for key in w.evil_plan.get("fake_sightings", {}):
			var b = w.evil_plan["fake_sightings"][key]
			if key.begins_with(n.id + ":") and b is Dictionary and b.get("who", "") == target.id and Evil.street_story_fits(n, b):
				candidates.append(b)
	else:
		candidates = n.beliefs.filter(func(b): return b.get("kind", "") == "saw" and b.get("who", "") == target.id and b.get("phase", -1) == C.NIGHT)
	candidates = candidates.filter(func(b): return (b.get("how", "street") == "window") if "window" in why else C.block_name(b.get("block", "")) in why)
	candidates.sort_custom(func(a, b): return a["day"] > b["day"])
	if candidates.is_empty():
		return
	var seen: Dictionary = candidates[0]
	if n.told_to.has(_town_sighting_key(n, seen)):
		# Already told the town: not a new card, but it is what this nomination accuses
		# them of, so the defence still answers it (playtest 89077: Fenwick, a claimed
		# Warden, pleaded desperation against Nisha's spoken sighting).
		spoken.append(sighting_report(w, n, seen, seen["day"])["fact"])
		return
	n.told_to[_town_sighting_key(n, seen)] = true
	var report = sighting_report(w, n, seen, seen["day"])
	facts.append(report["fact"])

## Peer pressure: what public accusations add to a listener's action score.
## Each accuser counts once (their latest stance), older accusations fade, and
## each further voice adds half as much as the one before, so a chorus can't bury someone.
## The crowd supplies no evidence, source dishonesty or world-prior weight.

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
	# Voices raised for them at a trial (M2c supporters) take a little of it back.
	for a in w.defences:
		var df: Dictionary = w.defences[a]
		if df["target"] == target and a != l.id and a != target:
			want -= Tuning.Meeting.VIBES_SWAY * (0.5 + l.npc_trust.get(a, 0.5)) * pow(CONSENSUS_FADE, w.day - df["day"])
	want = maxf(want, 0.0)
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
	for a in w.defences:
		targets[w.defences[a]["target"]] = true
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
		var role_lean: float = C.role_def(n.role).nomination_lean(w, n)
		var s: float = action_susp(n, t.id) + resent + clear_adj - cooloff + role_lean
		w.dlog.decision(n.id, "nomination", "evaluation", s >= thr, {"score": s, "role_lean": role_lean,
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
		if C.is_demon(w.by_id[sc["nominee"]].role):
			w.dlog.think(n.id, "team_survival", "Protects the Demon: maintaining cover cannot justify nominating them.")
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
	var cs = _nomination().nomination_case(w, nom, t, why)
	c["case_lines"] = cs["lines"]
	c["case_facts"] = cs["facts"]
	c["spoken_facts"] = cs.get("spoken_facts", [])
	return c
