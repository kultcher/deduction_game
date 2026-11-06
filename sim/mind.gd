## NPC reasoning for good and evil townsfolk: suspicion, trust, claims and disclosure,
## testimony, nominations, votes, conversation answers. Decisions with hidden reasoning are
## written to the dev log via w.dlog.think(...).
##
## Speech lines are returned as {"speaker": id, "name": name, "text": text}; narration as
## plain strings. game.gd renders both.
##
## All functions are static and take the world as the first argument.
extends RefCounted

const WorkshopLedger = preload("res://workshop/shared_ledger.gd")
const WorkshopLedgerProfiler = preload("res://workshop/profiler.gd")

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")

static func _mind():
	return load("res://sim/mind.gd")

# ---------------------------------------------------------------- utilities

static func say(n, text: String) -> Dictionary:
	return {"speaker": n.id, "name": n.name, "text": Dialogue.apply_tics(n.id, text, _tic_memory(n))}

## Tic counts live with the speaker's dialogue memory; a bare speaker record (tools, UI
## previews) has none, so nothing is capped for it.
static func _tic_memory(n) -> Dictionary:
	if n is Dictionary:
		return n.get("dialogue_memory", {})
	return n.dialogue_memory

static func say_voiced(n, key: String, fallback: String, slots: Dictionary = {}) -> Dictionary:
	var line = {"speaker": n.id, "name": n.name, "text": Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, key, fallback, slots), _tic_memory(n)), "statement": fallback}
	# Curated from the actual voiced wording. Unlisted deliveries stay neutral.
	# These cues do not inspect alignment, secrets, decisions, or truthfulness.
	var cues = {
		"apology_accept": {"agnes": "warm", "dorian": "warm", "fenwick": "warm", "isolde": "warm", "jory": "warm", "merrin": "warm"},
		"distrust_action": {"greta": "harsh", "jory": "harsh", "lian": "harsh", "merrin": "harsh", "isolde": "concerned"},
		"fear_gift_refusal": {"dorian": "concerned", "isolde": "concerned", "jory": "concerned", "merrin": "concerned"},
		"withhold_readings_fear_all": {"dorian": "concerned", "isolde": "concerned", "jory": "concerned", "merrin": "concerned"},
		"withhold_readings_fear_rest": {"dorian": "concerned", "isolde": "concerned", "jory": "concerned", "merrin": "concerned"},
		"defence_fear_plea": {"dorian": "concerned", "isolde": "concerned", "jory": "concerned", "merrin": "concerned"},
		"protect_trust_now": {"agnes": "warm", "dorian": "warm", "edda": "warm", "fenwick": "warm", "isolde": "warm", "jory": "warm", "merrin": "warm"},
		"request_ward": {"dorian": "concerned", "isolde": "concerned"},
		"request_vigil": {"isolde": "concerned"},
		"pressed_multi_trace_case": {"dorian": "harsh", "jory": "harsh", "merrin": "harsh"},
	}
	var expression: String = cues.get(key, {}).get(n.id, "")
	if expression != "" and Dialogue.has_voice(n.id):
		line["expression"] = expression
		# Warm acceptance is a gentle cue; explicit alarm or rebuke is stronger.
		line["expression_strength"] = 1 if expression == "warm" else 2
	return line

## Small presentation boundary: approve content first, then supply only delivery cues.
static func voiced(n, kind: String, statement: String, event_id: String = "", context: Dictionary = {}) -> Dictionary:
	var cues = context.duplicate()
	cues["trust"] = n.trust
	cues["pressure"] = n.pressure
	var rendered = Dialogue.compose(n.id, {"kind": kind, "statement": statement, "event_id": event_id}, cues, n.dialogue_memory)
	return say(n, rendered["text"])

static func decision_line(n, approved: Dictionary, audience: String = "player") -> Dictionary:
	return say(n, Dialogue.decision(n.id, approved, audience, n.dialogue_memory)["text"])

static func reconsideration_line(n, said: String) -> Dictionary:
	var rendered = Dialogue.compose(n.id, Dialogue.reconsideration_intent(said), {"reconsidered": true}, n.dialogue_memory)
	return say(n, rendered["text"])

static func whereabouts_refusal(n, nd: int) -> Dictionary:
	var rendered = Dialogue.compose(n.id, Dialogue.whereabouts_intent("whereabouts:%d" % nd), {"withholding": true}, n.dialogue_memory)
	return say(n, rendered["text"])

static func gift_refusal(n) -> Dictionary:
	var rendered = Dialogue.compose(n.id, Dialogue.gift_refusal_intent("gift_refusal"), {"withholding": true}, n.dialogue_memory)
	return say(n, rendered["text"])

static func home_alibi(w, n, nd: int) -> Dictionary:
	var when_label = "last night"
	if w != null and nd != w.day - 1:
		var nm: String = C.night_name(nd)
		when_label = ("on " + nm) if nm.begins_with("night") else nm
	var rendered = Dialogue.compose(n.id, Dialogue.alibi_intent("alibi:%d" % nd, when_label), {"audience": "player", "speech_act": "answer", "trust": n.trust, "pressure": n.pressure}, n.dialogue_memory)
	return say(n, rendered["text"])

## Keep every fact and narration intact; only the first spoken response is rephrased.
static func _challenged(n, response: Dictionary, card: Dictionary) -> Dictionary:
	for i in range(response["lines"].size()):
		var line = response["lines"][i]
		if line is Dictionary and line.get("speaker", "") == n.id:
			# Rephrasing changes delivery only. Keep the approved statement and any
			# canonical payload/provenance attached to the original speech event.
			var is_visual: bool = card.get("kind", "") in ["sighting", "vigil"] or (card.get("kind", "") == "info" and card.get("role", "") == "nightwatch")
			var rephrased: Dictionary = line.duplicate(true)
			rephrased["text"] = voiced(n, "doubted", line["text"], fact_id(card), {"challenged": true, "visual": is_visual})["text"]
			response["lines"][i] = rephrased
			break
	return response

static func trait_of(n, t: String) -> float:
	return n.traits.get(t, 0.5)

## Effective paranoia (rises with the dead; composure dampens).
static func paranoia(w, n) -> float:
	var dead = w.npcs.filter(func(m): return not m.alive).size()
	return Tuning.Mind.PARANOIA_PER_DEAD * dead * (1.0 - Tuning.Mind.PARANOIA_COMPOSURE_DAMP * trait_of(n, "composure"))

static func implicated(e: Dictionary) -> Array:
	return Gifts.implicated(e)

static func sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))

## Weighted roll. parts: named score contributions; a total of 0 means 50/50.
## Logged with the breakdown so every decision is traceable.
static func decide(w, n, topic: String, parts: Dictionary, why: String) -> bool:
	var total = 0.0
	for k in parts:
		total += parts[k]
	var p = sigmoid(total * Tuning.Mind.SIGMOID_SLOPE)
	var r = w.rng.randf()
	var yes = r < p
	var d = {}
	for k in parts:
		d[k] = snappedf(parts[k], 0.01)
	d["p"] = snappedf(p, 0.01)
	d["result"] = yes
	w.dlog.trace_event("decision_roll", n.id, "", {"topic": topic, "parts": parts,
		"total": total, "probability": p, "draw": r, "result": yes}, why)
	w.dlog.decision(n.id, topic, "roll", yes, {"mechanism": "sigmoid", "parts": parts,
		"total": total, "probability": p, "draw": r, "reason": why})
	w.dlog.think(n.id, topic, "%s -> %s (p=%.2f)" % [why, "yes" if yes else "no", p], d)
	return yes

# ---------------------------------------------------------------- trust

static func set_trust(w, n, value: float, why: String) -> void:
	var old: float = n.trust
	n.trust = clampf(value, 0.0, n.trust_cap)
	var action = _trust_action(w, why)
	var loss: float = old - n.trust
	if action != "" and loss > float(n.distrust_memory.get("loss", 0.0)):
		n.distrust_memory = {"loss": loss, "action": action}
	w.dlog.trace_event("value_change", n.id, "player", {"quantity": "trust",
		"from": old, "requested_to": value, "to": n.trust, "cap": n.trust_cap}, why)
	if absf(n.trust - old) >= 0.01:
		w.dlog.add("trust", n.id, "player", {"from": snappedf(old, 0.01), "to": snappedf(n.trust, 0.01), "cap": n.trust_cap}, why)
	if old - n.trust >= Tuning.Trust.GRIEVANCE_MIN_DROP and not why.begins_with("apology"):
		_record_grievance(w, n, old - n.trust, why)
	elif old - n.trust > 0.0 and not why.begins_with("apology") and not why.begins_with("grief"):
		n.friction += old - n.trust  # small slights fade overnight (fade_slights)
	if absf(n.trust - n.trust_at_reconsider) >= Tuning.Mind.RECONSIDER_TRUST_DELTA:
		reconsider(w, n, why)

## A player action that cost trust, kept so the player can apologise for it once.
## The same kind of incident on the same day is one incident (e.g. pressing questions).
static func _record_grievance(w, n, drop: float, why: String) -> void:
	var key: String = "%d:%s" % [w.day, RegEx.create_from_string("[0-9]+").sub(why, "#", true)]
	for g in n.grievances:
		if g["key"] == key and not g["apologised"]:
			g["drop"] += drop
			g["serious"] = g["drop"] >= SERIOUS_GRIEVANCE
			return
	var evidence: bool = "evidence" in why or "argued against me" in why or "spoke against me" in why
	n.grievances.append({"key": key, "why": why, "drop": drop, "day": w.day,
		"serious": drop >= SERIOUS_GRIEVANCE, "evidence": evidence, "apologised": false, "repaired": 0.0})

const SERIOUS_GRIEVANCE = Tuning.Trust.SERIOUS_GRIEVANCE

## The incidents the player could still apologise for (most recent first).
static func open_grievances(n) -> Array:
	var out: Array = n.grievances.filter(func(g): return not g["apologised"])
	out.reverse()
	return out

## Apologise for one incident: once each. Repairs half the trust lost for a minor incident,
## a quarter for a serious one; a sharp (high-Insight) listener forgives less when the player
## acted on evidence against them, since the apology doesn't change what the player thinks.
## No suspicion is withdrawn, and trust caps still hold.
static func apologise(w, n, index: int) -> Dictionary:
	var open: Array = open_grievances(n)
	if index < 0 or index >= open.size():
		return {"lines": [], "facts": [], "error": "Apologise for what?"}
	var g: Dictionary = open[index]
	g["apologised"] = true
	var share: float = Tuning.Trust.APOLOGY_SHARE_SERIOUS if g["serious"] else Tuning.Trust.APOLOGY_SHARE_MINOR
	var ins: float = trait_of(n, "insight")
	if g["evidence"]:
		share *= 1.0 - clampf((ins - Tuning.Mind.APOLOGY_EVIDENCE_INSIGHT_PIVOT) * Tuning.Mind.APOLOGY_EVIDENCE_INSIGHT_SLOPE, 0.0, Tuning.Mind.APOLOGY_EVIDENCE_DAMP_CAP)
	var repair: float = g["drop"] * share
	# Fading may already have repaid part of it; together they never exceed the limit.
	repair = minf(repair, maxf(0.0, _repay_limit(g) - float(g.get("repaired", 0.0))))
	g["repaired"] = float(g.get("repaired", 0.0)) + repair
	w.dlog.decision(n.id, "apology", "outcome", snappedf(repair, 0.01), {"incident": g["why"],
		"drop": snappedf(g["drop"], 0.01), "serious": g["serious"], "evidence": g["evidence"],
		"insight": ins, "share": snappedf(share, 0.01)})
	set_trust(w, n, n.trust + repair, "apology: " + g["why"])
	var line: String
	var apology_key: String
	if repair >= 0.05:
		line = "Well. I appreciate you saying so."
		apology_key = "apology_accept"
	elif g["evidence"] and ins >= 0.6:
		line = "Sorry for it, are you? You'd do the same again, I think."
		apology_key = "apology_skeptical"
	else:
		line = "Hm. Words are cheap, but I heard you."
		apology_key = "apology_grudging"
	return {"lines": [say_voiced(n, apology_key, line)], "facts": []}

## Only translate known player actions. Never quote arbitrary reasoning strings:
## those can contain private role, alignment or secret information.
static func _trust_action(w, why: String) -> String:
	var actions = {
		"the Demonologist nominated me": "You nominated me.",
		"the Demonologist voted to hang me": "You voted to hang me.",
		"the Demonologist overruled my nomination": "You overruled my nomination.",
		"the Demonologist spoke against my nomination": "You spoke against my nomination.",
		"the Demonologist spoke against me": "You spoke against me.",
		"the Demonologist spread my secret": "You spread what I told you in confidence.",
		"the Demonologist pressed me with evidence": "You pressed me with evidence."}
	if actions.has(why):
		return actions[why]
	if why.begins_with("the Demonologist guessed my gift wrong ("):
		return "You kept guessing at my gift."
	if why.begins_with("the Demonologist broke my confidence (card #"):
		return "You broke my confidence at the meeting."
	if why.begins_with("the Demonologist broke their word ("):
		return "You broke your promise to me."
	if why.begins_with("pressed with ") and why.ends_with(" questions today"):
		return "You kept pressing me with questions."
	var named_actions = {
		"grief: the Demonologist nominated ": "You nominated %s.",
		"grief: the Demonologist voted to hang ": "You voted to hang %s.",
		"the Demonologist backed hanging ": "You backed hanging %s.",
		"player accused ": "You accused %s.",
		"the Demonologist spared ": "You spared %s."}
	for prefix in named_actions:
		if why.begins_with(prefix):
			var person: String = why.trim_prefix(prefix).get_slice(",", 0)
			if w.by_id.has(person):
				return named_actions[prefix] % w.by_id[person].name
	return ""

## A refusal can explain distrust once per day, without affecting its decision,
## facts, RNG or trust. The same safe action vocabulary serves both alignments.
static func _append_distrust(w, n, lines: Array) -> void:
	if n.trust >= Tuning.Trust.DISTRUST_EXPLAIN_THRESHOLD or n.distrust_explained_day == w.day:
		return
	n.distrust_explained_day = w.day
	var action: String = n.distrust_memory.get("action", "")
	if action != "":
		lines.append(say_voiced(n, "distrust_action", "I don't trust you. " + action, {"action": action}))
	else:
		lines.append(say_voiced(n, "distrust_outsider", "You're an outsider, I'm not sure I can trust you."))

static func cap_trust(w, n, cap: float, why: String) -> void:
	if cap < n.trust_cap:
		w.dlog.trace_event("value_change", n.id, "player", {"quantity": "trust_cap",
			"from": n.trust_cap, "to": cap}, why)
		n.trust_cap = cap
		w.dlog.add("trust_cap", n.id, "player", {"cap": cap}, why)
		if n.trust > cap:
			set_trust(w, n, cap, why)

## End of each day: bonus for keeping a confessed secret.
## How much of a grievance can ever be repaid (by fading and apology together).
static func _repay_limit(g: Dictionary) -> float:
	return float(g["drop"]) * (Tuning.Trust.SERIOUS_FADE_LIMIT if g.get("serious", false) else 1.0)

## Past slights fade (Oct 30, docs/social_trust_pass.md): each night every grievance gives
## back GRIEVANCE_FADE of its drop up to its limit, and so does the small-slight friction.
## Grief and trust caps are untouched (set_trust still clamps to trust_cap).
static func fade_slights(w, n) -> void:
	var back := 0.0
	for g in n.grievances:
		if str(g.get("why", "")).begins_with("grief"):
			continue  # grief doesn't fade with time (an apology can still address it)
		var room: float = _repay_limit(g) - float(g.get("repaired", 0.0))
		if room <= 0.0:
			continue
		var step: float = minf(room, float(g["drop"]) * Tuning.Trust.GRIEVANCE_FADE)
		g["repaired"] = float(g.get("repaired", 0.0)) + step
		back += step
	if n.friction > 0.0:
		var f: float = n.friction * Tuning.Trust.GRIEVANCE_FADE if n.friction > 0.002 else n.friction
		n.friction -= f
		back += f
	if back > 0.0005:
		set_trust(w, n, n.trust + back, "time softens past slights")

static func end_of_day_trust(w) -> void:
	for n in w.living():
		fade_slights(w, n)
		fade_resentments(w, n)
	for n in w.living():
		if n.secret_known and not n.secret_spread:
			var bonus = Tuning.Trust.SECRET_KEPT_BASE + Tuning.Trust.SECRET_KEPT_PRIVACY_SCALE * trait_of(n, "privacy")
			if n.secret_spread_by_npc:
				bonus *= Tuning.Trust.SECRET_KEPT_RUMOR_MULT
			# Gratitude fades as keeping it becomes the expected thing (Oct 30): full the first
			# night, then shrinking each night after.
			bonus *= pow(Tuning.Trust.SECRET_KEPT_DECAY, n.secret_kept_nights)
			n.secret_kept_nights += 1
			set_trust(w, n, n.trust + bonus, "the Demonologist kept my secret today%s" % (" (though others are talking)" if n.secret_spread_by_npc else ""))

# ---------------------------------------------------------------- shadow self

## Evil NPCs keep a second, good mind: what they'd believe if they were the good
## townsperson they pretend to be, with their bluff as their gift (docs/shadow_self_plan.md).
## Every belief entry point below that used to skip evil listeners now feeds the shadow
## instead, through shadow_run. The shadow is a separate NPC object, never in w.npcs or
## w.by_id; it hears what the real NPC heard, minus what only evil could know (night
## sightings made while out on evil work), and takes evil's fake readings as its own.
## It runs on its own random stream and its own log (w.shadow_log), so it can't change
## the case. Step 1: nothing reads it yet.

## Fields copied once, when the shadow is made (a turned NPC's good mind carries over).
const SHADOW_COPY = ["traits", "trait_base", "work_phases", "haunts", "friends", "rivals",
	"suspicion", "npc_trust", "ledger", "honesty", "discounted", "believed_roles",
	"cleared", "protect_pref", "spare_pref", "known_claims", "known_secrets", "heard", "used_facts", "workshop_state", "consensus_pressure", "claim_record", "resentments"]
const SHADOW_SAME = ["id", "name", "pron", "style", "blurb", "occupation", "work", "home_block", "ring"]

## Run f(shadow) for evil NPC n inside the shadow context: the shadow's RNG and log in
## place of the world's, and the shadow synced with what n has seen since last time.
static func shadow_run(w, n, f: Callable) -> void:
	if not C.SHADOW_SELF or not n.is_evil():
		return
	var saved_rng = w.rng
	var saved_log = w.dlog
	var made = n.shadow == null
	if made:
		n.shadow = _make_shadow(w, n)
	var s = n.shadow
	w.rng = s.shadow_rng
	w.shadow_log.set_time(saved_log.day, saved_log.phase)
	w.dlog = w.shadow_log
	w.dlog.capture_npc(s, "before_shadow_sync")
	_shadow_sync(w, n, s)
	w.dlog.capture_npc(s, "after_shadow_sync")
	if made and s.role != "":
		hear_claim(w, s, s.id, s.role, Tuning.Setup.OWN_ROLE_CLAIM_WEIGHT, "own")  # knows "its own" gift, as every good NPC does
	f.call(s)
	w.dlog.capture_npc(s, "shadow_return")
	w.rng = saved_rng
	w.dlog = saved_log

static func _make_shadow(w, n):
	var s = n.get_script().new()
	for f in SHADOW_SAME:
		s.set(f, n.get(f))
	for f in SHADOW_COPY:
		s.set(f, n.get(f).duplicate(true))
	s.credibility = n.credibility  # the player's track record carries over (a Revenant turn included)
	s.alignment = "good"
	s.is_shadow = true
	var bluff: String = w.evil_plan["bluffs"].get(n.id, "")
	s.role = bluff if C.ROLES.has(bluff) and C.ROLES[bluff]["align"] == "good" else ""
	# A turned NPC's own true readings were theirs before the curse; fake ones arrive below.
	s.info_log = n.info_log.filter(func(e): return not e.get("fake", false)).map(func(e): return e.duplicate(true))
	s.applied_info = s.info_log.size()
	s.shadow_rng = RandomNumberGenerator.new()
	s.shadow_rng.seed = hash("%d:shadow:%s" % [w.seed_value, n.id])
	n.shadow_seen = {"beliefs": n.beliefs.size() if n.turned else 0, "hearsay": n.hearsay.size() if n.turned else 0, "fake": 0}
	if n.turned:
		s.beliefs = n.beliefs.map(func(b): return b.duplicate(true))
		s.hearsay = n.hearsay.map(func(h): return h.duplicate(true))
	return s

## Bring the shadow up to date with what the real NPC has seen and heard. Night sightings
## made while out (killing, poisoning, guarding a teammate) stay out: a good self would
## have been at home.
static func _shadow_sync(w, n, s) -> void:
	for f in ["alive", "death_day", "loc", "working", "busy_with", "silenced", "trust", "trust_cap", "credibility",
			"pressure", "claimed_role", "claim_public", "max_tier", "told_readings", "night_block", "out_last_night"]:
		s.set(f, n.get(f))
	for k in n.npc_trust:
		s.npc_trust[k] = n.npc_trust[k]
	for k in n.claim_record:
		s.claim_record[k] = n.claim_record[k].duplicate(true)
	s.history = n.history.duplicate()
	var seen: Dictionary = n.shadow_seen
	while seen["beliefs"] < n.beliefs.size():
		var b: Dictionary = n.beliefs[seen["beliefs"]]
		seen["beliefs"] += 1
		if b.get("phase", -1) == C.NIGHT and not str(n.history.get(w.time_key(b.get("day", 0), C.NIGHT), "home")).begins_with("home"):
			continue
		s.beliefs.append(b.duplicate(true))
	while seen["hearsay"] < n.hearsay.size():
		s.hearsay.append(n.hearsay[seen["hearsay"]].duplicate(true))
		seen["hearsay"] += 1
	for k in n.known_claims:
		if not s.known_claims.has(k) or s.known_claims[k] != n.known_claims[k]:
			s.known_claims[k] = n.known_claims[k].duplicate(true)

## Evil's fake readings, taken by the shadow as its own (firmly, not unshakably).
static func _shadow_own_info(w, n) -> void:
	shadow_run(w, n, func(s):
		var seen: Dictionary = n.shadow_seen
		while seen["fake"] < n.info_log.size():
			var e: Dictionary = n.info_log[seen["fake"]]
			seen["fake"] += 1
			if not e.get("fake", false):
				continue
			var mine = e.duplicate(true)
			s.info_log.append(mine)
			s.applied_info = s.info_log.size()
			apply_info(w, s, s, mine, C.SHADOW_OWN_READING_WEIGHT))

## Step 2: should evil NPC n break cover, doing the evil choice instead of what its good
## self would? stakes: what the evil choice buys (a teammate saved, a frame pushed);
## deviation: how far the evil choice strays from the shadow's (0..1). Logged either way.
static func evil_override(w, n, act: String, stakes: float, deviation: float, detail: String) -> bool:
	var exp_parts: Dictionary = Evil.exposure(w, n)
	var exposure = 0.0
	for k in exp_parts:
		exposure += exp_parts[k]
	var cost = deviation * exposure
	var caution = Evil.caution(w, n)
	var yes = stakes - cost > caution
	w.dlog.decision(n.id, "evil_override", "evaluation", yes, {"act": act, "detail": detail,
		"stakes": stakes, "deviation": deviation, "exposure": exposure, "exposure_parts": exp_parts,
		"cost": cost, "caution": caution, "score": stakes - cost, "threshold": caution, "comparison": ">"})
	w.dlog.think(n.id, "override", "%s %s: %s (stakes %.2f - exposure cost %.2f vs caution %.2f)." %
		["Breaks cover on" if yes else "Keeps cover on", act, detail, stakes, cost, caution],
		{"act": act, "stakes": snappedf(stakes, 0.01), "cost": snappedf(cost, 0.01), "caution": snappedf(caution, 0.01), "exposure": exp_parts, "override": yes})
	return yes

## Run f(shadow) and return what it returns (null without a shadow).
static func shadow_eval(w, n, f: Callable):
	var box = {}
	shadow_run(w, n, func(sh): box["r"] = f.call(sh))
	return box.get("r")

## Snapshot the pre-curse good mind at `turn_evil` so `free_turned` restores it cleanly,
## carrying forward only public claims and readings from the turned period (Decision 3).
static func capture_pre_turn_snapshot(w, n) -> Dictionary:
	var snap: Dictionary = {"fields": {}, "public_claims_cursor": w.public_claims.size(), "shared_readings": {}}
	for f in SHADOW_COPY:
		if f in ["traits", "trait_base", "work_phases", "haunts", "friends", "rivals"]:
			continue
		snap.fields[f] = n.get(f).duplicate(true)
	snap["credibility"] = n.credibility
	snap["trust"] = n.trust
	snap["trust_cap"] = n.trust_cap
	snap["trust_at_reconsider"] = n.trust_at_reconsider
	snap["beliefs"] = n.beliefs.duplicate(true)
	snap["hearsay"] = n.hearsay.duplicate(true)
	snap["claimed_role"] = n.claimed_role
	snap["claim_public"] = n.claim_public
	snap["max_tier"] = n.max_tier
	snap["told_readings"] = n.told_readings
	for p in w.npcs:
		for en in p.info_log:
			if en.get("shared", false):
				snap.shared_readings[info_eid(p.id, en)] = true
	return snap

static func restore_pre_turn_snapshot(w, n) -> void:
	var snap: Dictionary = n.pre_turn_snapshot if n.pre_turn_snapshot is Dictionary else {}
	var turned_shadow = n.shadow
	if not snap.is_empty():
		var fields: Dictionary = snap.get("fields", {})
		for f in fields:
			n.set(f, fields[f].duplicate(true))
		n.credibility = float(snap.get("credibility", n.credibility))
		n.trust = float(snap.get("trust", n.trust))
		n.trust_cap = float(snap.get("trust_cap", n.trust_cap))
		n.trust_at_reconsider = float(snap.get("trust_at_reconsider", n.trust_at_reconsider))
		n.beliefs = snap.get("beliefs", []).duplicate(true)
		n.hearsay = snap.get("hearsay", []).duplicate(true)
		n.claimed_role = str(snap.get("claimed_role", n.claimed_role))
		n.claim_public = bool(snap.get("claim_public", n.claim_public))
		n.max_tier = int(snap.get("max_tier", n.max_tier))
		n.told_readings = int(snap.get("told_readings", n.told_readings))
	# Public hearings from the turned period (meeting testimony, volunteered sightings,
	# defences) were heard by the good-self shadow; carry those forward, nothing private.
	if turned_shadow != null:
		for eid in turned_shadow.ledger:
			var le: Dictionary = turned_shadow.ledger[eid]
			if not n.ledger.has(eid) and bool(le.get("meta", {}).get("workshop_public", false)):
				n.ledger[eid] = le.duplicate(true)
	n.pre_turn_snapshot = {}
	shadow_reset(n)
	for e in n.info_log:
		if e.get("fake", false):
			n.ledger.erase(info_eid(n.id, e))
	var prev_defer: bool = w.defer_beliefs
	w.defer_beliefs = true
	hear_claim(w, n, n.id, n.role, Tuning.Setup.OWN_ROLE_CLAIM_WEIGHT, "own")
	var cursor: int = int(snap.get("public_claims_cursor", 0))
	for idx in range(maxi(0, cursor), w.public_claims.size()):
		var pc: Dictionary = w.public_claims[idx]
		var who_id: String = str(pc.get("who", ""))
		var role_id: String = str(pc.get("role", ""))
		if who_id == n.id:
			if role_id == n.role:
				n.claimed_role = role_id
				n.claim_public = true
		elif who_id != "":
			hear_claim(w, n, who_id, role_id, Tuning.Mind.PUBLIC_CLAIM_HEARING_WEIGHT, "public")
	var prev_shared: Dictionary = snap.get("shared_readings", {})
	for p in w.npcs:
		if p == n:
			continue
		for en in p.info_log:
			if not en.get("shared", false) or en.get("disowned", false):
				continue
			var r_eid: String = info_eid(p.id, en)
			if not prev_shared.has(r_eid):
				apply_info(w, n, p, en, heard_weight(n, p))
	for a in w.stances:
		var st_target: String = str(w.stances[a].get("target", ""))
		if st_target != "" and st_target != n.id:
			MindMeeting.refresh_consensus(w, n, st_target)
	w.defer_beliefs = prev_defer
	flush_beliefs(w, n)
	refresh_beliefs(w, n, " (freed from the curse)")
	w.dlog.think(n.id, "freed_restore", "Freed: restored pre-curse mind and public receipts (%d ledger entries)." % n.ledger.size())

## Turned or freed by the Revenant's curse: the shadow is rebuilt (or dropped) next time.
static func shadow_reset(n) -> void:
	n.shadow = null
	n.shadow_seen = {}

## Debug: the shadow's view, for snapshots. {} if none.
static func shadow_view(w, n) -> Dictionary:
	if n.shadow == null:
		return {}
	var sus = {}
	for k in n.shadow.suspicion:
		if w.by_id.has(k) and w.by_id[k].alive:
			sus[k] = snappedf(susp(n.shadow, k), 0.01)
	return {"role": n.shadow.role, "trust": snappedf(n.shadow.trust, 0.01), "suspicion": sus}

# ---------------------------------------------------------------- suspicion

static func adjust(w, listener, target_id: String, delta: float, why: String, public_why: String = "", conf_scaled: bool = true, src: String = "") -> void:
	if listener.is_evil():
		shadow_run(w, listener, func(sh): adjust(w, sh, target_id, delta, why, public_why, conf_scaled, src))
		return
	if target_id == listener.id or not listener.suspicion.has(target_id):
		return
	if conf_scaled:
		delta *= Tuning.Mind.CONFIDENCE_SCALE_BASE - Tuning.Mind.CONFIDENCE_SCALE_SLOPE * trait_of(listener, "confidence")
	var old: float = listener.suspicion[target_id]
	var nv = old + delta
	if listener.workshop_state.get("active", false):
		var state: Dictionary = listener.workshop_state
		var outside: float = state.outside.get(target_id, old)
		outside += delta
		state.outside[target_id] = outside
		var stage1_req: float = state.requested.get(target_id, 0.0)
		var stage2_req: float = state.get("circumstantial_requested", {}).get(target_id, 0.0)
		nv = outside + stage1_req + stage2_req
		state.applied[target_id] = (outside + stage1_req) - outside
		if state.get("circumstantial_requested", {}).has(target_id):
			state.circumstantial_applied[target_id] = nv - (outside + stage1_req)
	listener.suspicion[target_id] = nv
	w.dlog.trace_event("value_change", listener.id, target_id, {"quantity": "suspicion",
		"from": old, "to": nv, "requested_delta": delta, "applied_delta": nv - old,
		"ledger_id": src}, why)
	if absf(delta) >= 0.05:
		w.dlog.add("suspicion", listener.id, target_id, {"from": snappedf(old, 0.01), "to": snappedf(nv, 0.01)}, why)

static func susp(n, target_id: String) -> float:
	if n.workshop_state.get("active", false) and target_id in n.workshop_state.get("public_good", []):
		return 0.0
	return clampf(n.suspicion.get(target_id, 0.0), 0.0, Tuning.Mind.MAX_SUSPICION)

## The stored vector is an exact, reversible sum. Consumers see bounded beliefs.
static func suspicion_view(n) -> Dictionary:
	var result = {}
	for id in n.suspicion:
		result[id] = susp(n, id)
	return result

static func demon_victim(w, id: String) -> bool:
	return w.public_log.any(func(event): return event.kind == "demon_death" and id in event.subjects)

# ---------------------------------------------------------------- mourning resentment

static func _friend_shown_evil(w, n, friend_id: String) -> bool:
	if friend_id == "":
		return false
	if susp(n, friend_id) >= Tuning.Trust.GRIEF_BELIEVED_EVIL:
		return true
	var b_role: String = str(n.believed_roles.get(friend_id, ""))
	if b_role != "" and C.ROLES.get(b_role, {}).get("align", "good") == "evil":
		return true
	if w != null and w.public_log.any(func(ev): return ev.get("kind", "") == "curse" and friend_id in ev.get("subjects", [])):
		return true
	return false

static func add_resentment(w, mourner, target_id: String, delta: float, friend_id: String, role_tag: String = "nominator") -> void:
	if mourner == null or target_id == "" or target_id == "player" or target_id == mourner.id or delta <= 0.0:
		return
	if mourner.is_evil():
		shadow_run(w, mourner, func(sh): add_resentment(w, sh, target_id, delta, friend_id, role_tag))
		return
	if _friend_shown_evil(w, mourner, friend_id):
		return
	for r in mourner.resentments:
		if str(r.get("target", "")) == target_id and str(r.get("friend", "")) == friend_id:
			r["strength"] = minf(float(r.get("strength", 0.0)) + delta, Tuning.Trust.RESENTMENT_CAP)
			if role_tag == "nominator":
				r["role"] = "nominator"
			r["day"] = w.day
			return
	mourner.resentments.append({
		"target": target_id,
		"strength": minf(delta, Tuning.Trust.RESENTMENT_CAP),
		"friend": friend_id,
		"day": w.day,
		"role": role_tag,
	})
	w.dlog.trace_event("resentment_added", mourner.id, target_id, {"friend": friend_id, "role": role_tag, "strength": minf(delta, Tuning.Trust.RESENTMENT_CAP)},
		"grief resentment: %s %s %s" % [target_id, "nominated" if role_tag == "nominator" else "voted to hang", friend_id])

static func prune_resentments(w, n) -> void:
	if n == null or n.resentments.is_empty():
		return
	n.resentments = n.resentments.filter(func(r): return float(r.get("strength", 0.0)) >= 0.01 and not _friend_shown_evil(w, n, str(r.get("friend", ""))))

static func fade_resentments(w, n) -> void:
	if n.is_evil():
		shadow_run(w, n, func(sh): fade_resentments(w, sh))
		return
	if n.resentments.is_empty():
		return
	var kept: Array = []
	for r in n.resentments:
		if _friend_shown_evil(w, n, str(r.get("friend", ""))):
			continue
		var next_s: float = float(r.get("strength", 0.0)) * (1.0 - Tuning.Trust.RESENTMENT_FADE)
		if next_s >= 0.01:
			var r_copy: Dictionary = r.duplicate(true)
			r_copy["strength"] = next_s
			kept.append(r_copy)
	n.resentments = kept

static func resentment_toward(w, n, target_id: String) -> float:
	var mind = n.shadow if n.is_evil() and n.shadow != null else n
	if mind == null or mind.resentments.is_empty() or target_id == "" or target_id == mind.id:
		return 0.0
	var total: float = 0.0
	for r in mind.resentments:
		if str(r.get("target", "")) != target_id:
			continue
		if _friend_shown_evil(w, mind, str(r.get("friend", ""))):
			continue
		total += float(r.get("strength", 0.0))
	return minf(total, Tuning.Trust.RESENTMENT_CAP)

static func best_resentment_against(w, n, target_id: String) -> Dictionary:
	var mind = n.shadow if n.is_evil() and n.shadow != null else n
	if mind == null or mind.resentments.is_empty() or target_id == "" or target_id == mind.id:
		return {}
	var best: Dictionary = {}
	var best_s: float = 0.0
	for r in mind.resentments:
		if str(r.get("target", "")) != target_id:
			continue
		if _friend_shown_evil(w, mind, str(r.get("friend", ""))):
			continue
		var s: float = float(r.get("strength", 0.0))
		if s > best_s:
			best_s = s
			best = r.duplicate(true)
	return best

# ---------------------------------------------------------------- evidence ledger
## Each good NPC keeps a ledger of the evidence and arguments they've taken in, keyed by the
## underlying fact (not by who relayed it, or which card or deduction wrapped it).
## An entry's contribution = its effects x weight x current reliability of its source.
## When weight or reliability changes, only the difference is applied, so suspicion is
## always "social base + what the evidence currently says". Social effects (vibes,
## nominations, grudges, claims) stay as direct adjustments.
##
## A role claim reaches a listener and enters their ledger as a receipt with its hearing
## weight (used by the shared model and metadata-derived role beliefs). how: public | relayed |
## own | told.
static func hear_claim(w, l, who: String, role: String, weight: float, how: String, original: Dictionary = {}) -> void:
	if l.is_evil():
		shadow_run(w, l, func(sh): hear_claim(w, sh, who, role, weight, how, original))
		return
	if not C.ROLES.has(role) or C.ROLES[role]["align"] != "good" or not w.by_id.has(who):
		return
	var rn = C.role_name(role)
	var nm: String = w.by_id[who].name
	var eid: String = claim_eid(who, role)
	var receipt: Dictionary = original if not original.is_empty() else l.ledger.get(eid, {}).get("meta", {}).get("workshop_card", {})
	if receipt.is_empty():
		receipt = WorkshopLedger.Evidence.normalize_card({"kind": "claim", "source": who, "subject": [who], "role": role, "day": w.day, "phase": w.phase, "text": "%s claims the %s." % [nm, rn]})
	ledger_hear(w, l, eid, [], weight, [who, -1, "role"], {"kind": "role_claim", "how": how, "role": role, "who": who, "workshop_card": receipt})

static func claim_eid(who: String, role: String) -> String:
	return "claim:%s:%s" % [who, role]

## How much this listener credits who's claim to role (0 = never heard it).
static func claim_credence(n, who: String, role: String) -> float:
	var eid: String = claim_eid(who, role)
	if n.workshop_state.get("owned", {}).has(eid):
		return 0.0 # Shared role testimony owns the claim's evidence weight.
	var e = n.ledger.get(eid)
	return e.get("eff", 0.0) if e != null else 0.0

## What a card rests on, as [source, night, kind] (kind: reading | report | evidence).
static func support_ref(card: Dictionary) -> Array:
	var src: String = card.get("source", "")
	if src in ["", "player", "evidence"]:
		return ["", -1, "evidence"]
	if card.get("kind", "") == "info":
		return [src, card.get("day", -1), "reading"]
	return [src, card.get("day", -1) if card.get("phase", -1) == C.NIGHT else -1, "report"]

## A stable identity for the fact behind a board card.
static func fact_id(card: Dictionary) -> String:
	var prefix: String = "rumour|" if card.get("tavern_gossip", false) else ""
	return prefix + _raw_fact_id(card)

static func _raw_fact_id(card: Dictionary) -> String:
	var k: String = card.get("kind", "")
	var subj: Array = card.get("subject", []).duplicate()
	subj.sort()
	var ss = ",".join(PackedStringArray(subj))
	match k:
		"info":
			return WorkshopLedger.Evidence.reading_key(WorkshopLedger.Evidence.normalize_card(card))
		"sighting", "vigil", "alibi", "secret":
			return "%s:%s:%s:%d:%d:%s" % [k, card.get("source", ""), ss, card.get("day", -1), card.get("phase", -1), card.get("block", "")]
		"home":
			return "home:%s:%s" % [ss, card.get("block", "")]
		"work":
			return "work:%s:%s" % [ss, card.get("loc", "")]
		"haunt":
			return "haunt:%s:%s" % [ss, ",".join(PackedStringArray(card.get("locs", [card.get("loc", "")])))]
		"trait":
			return "trait:%s:%s:%s:%s" % [ss, card.get("trait", ""), card.get("tier", ""), "bereaved" if card.get("withdrawn", false) else "base"]
		"bond":
			return "bond:%s:%s" % [card.get("bond_kind", ""), ss]
		"trace":
			if card.get("scene", "") != "" and (card.has("trace_slot") or card.get("trace_family", "") != ""):
				return "trace:%s:%d" % [card.get("scene", ""), int(card.get("trace_slot", 0))]
			return "trace:%s:%d" % [card.get("block", ""), card.get("day", -1)]
		"claim":
			return "claim:%s:%s" % [card.get("source", ""), card.get("role", "")]
		"town_hall":
			var th_roles: Array = card.get("roles", []).duplicate()
			th_roles.sort()
			return "town_hall:" + ",".join(PackedStringArray(th_roles))
		"death", "execution":
			return "%s:%s" % [k, ss]
	return "card:" + card.get("text", "")

## Kinds of claim (what someone says): "reading" (a gift's result: poison can break it),
## "report" (ordinary testimony: a sighting, an alibi, an opinion; poison doesn't touch it).
## A claim's rel = [source, night, kind]; night -1 = no particular night.
static func _rel(e: Dictionary) -> Array:
	var r: Array = e["rel"]
	if r.is_empty():
		return ["", -1, "evidence"]
	return [r[0], r[1], r[2] if r.size() > 2 else "reading"]

## Doubt about one particular reading (only gift readings; never testimony).
static func _night_factor(disc: Dictionary, src: String, night: int, kind: String) -> float:
	if src == "" or kind != "reading":
		return 1.0
	return 1.0 - maxf(disc.get("%s:%d" % [src, night], 0.0), disc.get(src + ":*", 0.0))

## How much this NPC currently credits a claim (1 = fully), derived from shared-model
## `workshop_state.source_doubt`. A good NPC never doubts their own sincerity, though
## they can accept that their own reading on a particular night was poisoned.
static func reliability(n, src: String, night: int, kind: String = "reading") -> float:
	if src == "":
		return 1.0
	var sd: Dictionary = n.workshop_state.get("source_doubt", {})
	if kind == "reading":
		return clampf(_night_factor(sd, src, night, kind), 0.0, 1.0)
	if src != n.id:
		return clampf(1.0 - float(sd.get(src + ":*", 0.0)), 0.0, 1.0)
	return 1.0

static func night_reliability(n, src: String, night: int) -> float:
	return _night_factor(n.workshop_state.get("source_doubt", {}), src, night, "reading")

## Take in a claim, evidence or an argument. Hearing the same thing again only raises its
## weight to the stronger hearing; it never stacks. `effects` is always empty in Phase 2c+:
## ledger entries hold receipts, metadata and hearing weights read by the shared model.
static func ledger_hear(w, n, eid: String, _effects: Array = [], weight: float = 1.0, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	if n.is_evil():
		# The shadow hears it; the real evil mind still takes nothing from it.
		shadow_run(w, n, func(sh): ledger_hear(w, sh, eid, [], weight, rel, meta))
		return {"fresh": false, "gain": 0.0, "times": 0}
	var fresh = not n.ledger.has(eid)
	if fresh:
		n.ledger[eid] = {"eid": eid, "effects": [], "weight": 0.0, "rel": rel, "meta": {}, "day": w.day, "times": 0}
	var e: Dictionary = n.ledger[eid]
	e["effects"] = []
	var times: int = e["times"]
	e["times"] = times + 1
	var old_w: float = e["weight"]
	for k in meta:
		if k == "base":
			e["meta"]["base"] = maxf(e["meta"].get("base", 0.0), meta["base"])
		elif k != "supports":
			e["meta"][k] = meta[k]
	if meta.has("supports"):
		var sup: Array = meta["supports"].duplicate()
		sup.sort()
		var key = str(sup)
		var js: Array = e.get("justs", [])
		var found = false
		for jj in js:
			if jj["key"] == key:
				jj["weight"] = maxf(jj["weight"], weight)
				jj["base"] = maxf(jj["base"], meta.get("base", 0.0))
				if meta.has("workshop_roots"):
					# A coarse support key may hide different original receipts. Keep
					# every proof; never let a later supported path certify a mixed one.
					jj["workshop_roots"] = _merge_workshop_roots(jj.get("workshop_roots", {}), meta.workshop_roots)
					if not jj.has("workshop_cases"):
						jj["workshop_uncertified"] = true
						jj["workshop_cases"] = {}
					jj.workshop_cases[meta.get("workshop_case", "0")] = meta.workshop_roots.duplicate(true)
				found = true
		if not found:
			js.append({"key": key, "weight": weight, "base": meta.get("base", 0.0), "supports": sup})
			if meta.has("workshop_roots"):
				js[-1]["workshop_roots"] = meta.workshop_roots.duplicate(true)
				js[-1]["workshop_cases"] = {meta.get("workshop_case", "0"): meta.workshop_roots.duplicate(true)}
		e["justs"] = js
	if weight > old_w:
		e["weight"] = weight
	if not e["meta"].has("w0"):
		e["meta"]["w0"] = e["weight"]
	refresh_beliefs(w, n, "")
	return {"fresh": fresh, "gain": maxf(0.0, weight - old_w), "times": times}

static func _merge_workshop_roots(old: Dictionary, value: Dictionary) -> Dictionary:
	var result = {"complete": old.get("complete", false) and value.get("complete", false), "receipts": old.get("receipts", {}).duplicate(true)}
	result.receipts.merge(value.get("receipts", {}))
	return result

## Refresh an NPC's beliefs via the shared Workshop model over the flat outside baseline,
## then derive metadata-backed social preferences and role beliefs.
static func refresh_beliefs(w, n, note: String) -> void:
	if w.defer_beliefs:
		if not w.pending_beliefs.any(func(p): return is_same(p[0], n)):
			w.pending_beliefs.append([n, note])
		return
	var span = WorkshopLedgerProfiler.open("belief_refresh")
	_refresh_beliefs(w, n, note)
	WorkshopLedgerProfiler.close(span)

## Run deferred refreshes: every pending mind, or only `only` (a speaker about to act).
static func flush_beliefs(w, only = null) -> void:
	var keep: Array = []
	var run: Array = []
	for p in w.pending_beliefs:
		if only == null or is_same(p[0], only):
			run.append(p)
		else:
			keep.append(p)
	w.pending_beliefs = keep
	var was: bool = w.defer_beliefs
	w.defer_beliefs = false
	for p in run:
		refresh_beliefs(w, p[0], p[1])
	w.defer_beliefs = was

static func _refresh_beliefs(w, n, note: String) -> void:
	if n.is_evil():
		shadow_run(w, n, func(sh): refresh_beliefs(w, sh, note))
		return
	if w.workshop_refresh.is_valid():
		w.workshop_refresh.call(n)
	_refresh_ledger_preferences(w, n)
	prune_resentments(w, n)
	w.dlog.capture_npc(n, "belief_recompute" + note)

static func _entry_support_factor(n, e: Dictionary, sup: Array) -> float:
	if sup.is_empty():
		return 1.0
	var c_meta: Dictionary = e.get("meta", {}).get("conclusion", {})
	var own_doubt_src: String = str(c_meta.get("a", "")) if str(c_meta.get("type", "")) in ["lied", "misled", "unreliable"] else ""
	var own_doubt_night: int = int(c_meta.get("night", -1))
	var total = 0.0
	var count = 0
	for sp in sup:
		var src: String = sp[0]
		var night: int = sp[1]
		var kind: String = sp[2] if sp.size() > 2 else "reading"
		if kind == "reading" and own_doubt_src != "" and src == own_doubt_src and (own_doubt_night < 0 or own_doubt_night == night):
			continue
		count += 1
		total += reliability(n, src, night, kind)
	return total / count if count > 0 else 1.0

static func _refresh_ledger_preferences(w, n) -> void:
	var rev_roles: Dictionary = {}
	for k in n.believed_roles:
		if n.believed_roles[k] == "revenant":
			rev_roles[k] = "revenant"
	n.protect_pref = {}
	n.spare_pref = {}
	n.believed_roles = rev_roles
	for e in n.ledger.values():
		var meta: Dictionary = e.get("meta", {})
		var kind: String = str(meta.get("kind", ""))
		var kg: float = Tuning.Mind.DEMON_VICTIM_CLAIM_BOOST if kind == "role_claim" and str(meta.get("how", "")) != "own" and demon_victim(w, str(meta.get("who", ""))) else 1.0
		var js: Array = e.get("justs", [])
		var w_eff: float = float(e.get("weight", 0.0))
		if not js.is_empty():
			w_eff = 0.0
			for jj in js:
				w_eff = maxf(w_eff, float(jj.get("weight", 0.0)) * _entry_support_factor(n, e, jj.get("supports", [])))
		var rp: Array = _rel(e)
		var eff: float = w_eff * kg * reliability(n, rp[0], rp[1], rp[2])
		e["eff"] = eff
		if kind == "role_claim":
			var who: String = str(meta.get("who", ""))
			var role: String = str(meta.get("role", ""))
			if who != "" and role != "" and eff >= Tuning.Mind.BELIEVED_ROLE_MIN_EFF and n.believed_roles.get(who, "") != "revenant":
				n.believed_roles[who] = role
		elif kind == "arg":
			_apply_conclusion_pref(n, meta.get("conclusion", {}), eff)
	var withdrawn: Dictionary = n.workshop_state.get("withdrawn", {})
	var agreements: Dictionary = n.workshop_state.get("presentation_agreement", {})
	for p_key in n.workshop_state.get("presentations", {}):
		if withdrawn.has(p_key):
			continue
		# Premises pass step 1: only a premise the listener accepted steers their protect
		# and believed-role preferences. Not judged yet (mid-presentation) counts as not
		# accepted; the presentation re-runs this once its agreement is recorded.
		if float(agreements.get(p_key, 0.0)) < Tuning.Workshop.PREMISE_PREF_MIN_AGREEMENT:
			continue
		var snap: Dictionary = n.workshop_state.presentations[p_key]
		var root_num: int = int(snap.get("root", -999))
		for arg in snap.get("arguments", []):
			if int(arg.get("board_number", -998)) == root_num:
				_apply_conclusion_pref(n, arg.get("conclusion", {}), 0.35 * (0.5 + n.trust))

static func _apply_conclusion_pref(n, c: Dictionary, eff: float) -> void:
	if c.is_empty() or eff <= 0.002:
		return
	var ctype: String = str(c.get("type", ""))
	var target_id: String = str(c.get("a", c.get("target", "")))
	if target_id == "":
		return
	match ctype:
		"good":
			n.protect_pref[target_id] = maxf(n.protect_pref.get(target_id, 0.0), 0.5 * eff)
		"protect":
			n.protect_pref[target_id] = maxf(n.protect_pref.get(target_id, 0.0), 1.0 * eff)
		"spare":
			n.spare_pref[target_id] = maxf(n.spare_pref.get(target_id, 0.0), 1.0 * eff)
		"role":
			var r: String = str(c.get("role", ""))
			if r != "" and eff >= Tuning.Mind.BELIEVED_ROLE_MIN_EFF and n.believed_roles.get(target_id, "") != "revenant":
				n.believed_roles[target_id] = r

## Re-weigh what the player has argued, in light of current trust. Firsthand knowledge and
## the evidence itself don't change; how much the player's word counts does. Confidence
## sets how far they move at once. Called when trust shifts noticeably and before votes.
static func reconsider(w, n, why: String) -> void:
	if n.is_evil():
		shadow_run(w, n, func(sh): reconsider(w, sh, why))
		return
	if absf(n.trust - n.trust_at_reconsider) < Tuning.Mind.RECONSIDER_MIN_SHIFT:
		refresh_beliefs(w, n, " (shared evidence reconsidered: %s)" % why)
		return
	n.trust_at_reconsider = n.trust
	var rate = 1.0 - Tuning.Mind.RECONSIDER_CONFIDENCE_DAMP * trait_of(n, "confidence")
	for e in n.ledger.values():
		var m: Dictionary = e["meta"]
		if not m.has("base"):
			continue
		var cur: float = e["weight"]
		var nw = cur
		var js: Array = e.get("justs", [])
		if js.is_empty():
			var want: float = m["base"] * (0.5 + n.credibility)
			if absf(want - cur) < Tuning.Mind.RECONSIDER_ENTRY_MIN_DELTA:
				continue
			nw = cur + (want - cur) * rate
		else:
			nw = 0.0
			for jj in js:
				var wj: float = jj["base"] * (0.5 + n.credibility)
				jj["weight"] = jj["weight"] + (wj - jj["weight"]) * rate
				nw = maxf(nw, jj["weight"])
			if absf(nw - cur) < Tuning.Mind.RECONSIDER_ENTRY_MIN_DELTA:
				continue
		e["weight"] = nw
		w.dlog.think(n.id, "reconsider", "Re-weighs '%s': %.2f -> %.2f (trust %.2f, %s)." % [m.get("text", e["eid"]), cur, nw, n.trust, why],
			{"eid": e["eid"], "from": snappedf(cur, 0.01), "to": snappedf(nw, 0.01)})
		var w0: float = m.get("w0", cur)
		if m.get("kind", "") == "arg" and nw >= maxf(w0 * 1.35, w0 + 0.05) and not m.get("remarked", false) and m.get("said", "") != "":
			m["remarked"] = true
			n.remarks.append(m["said"])
	refresh_beliefs(w, n, " (reconsidered: %s)" % why)

## Apply one ability result (own or heard) to a listener's suspicion, through their ledger:
## hearing the same reading again (directly, relayed, at the meeting) never stacks.
## `public`: told before the whole town (a late relay), so the receipt is public grounds
## even though the source's own statement was private.
static func apply_info(w, listener, source, entry: Dictionary, weight: float, via: String = "", anonymous: bool = false, public: bool = false) -> void:
	if weight <= 0.01:
		return
	if listener.is_evil():
		shadow_run(w, listener, func(sh): apply_info(w, sh, source, entry, weight, via, anonymous, public))
		return
	var receipt = WorkshopLedger.reading(source.id, entry, via)
	var eid = WorkshopLedger.reading_key(receipt)
	var fresh = not listener.ledger.has(eid)
	var rdef = C.role_def(entry.get("role", ""))
	if rdef != null:
		rdef.on_reading_heard(listener, source, entry, fresh)
	var receipts: Dictionary = listener.ledger.get(eid, {}).get("meta", {}).get("workshop_receipts", {}).duplicate(true)
	if anonymous:
		receipt = WorkshopLedger.reading(source.id, entry, via, true)
	receipt["heard_in_public"] = anonymous or public or entry.get("shared", false) or receipts.get(receipt.id, {}).get("heard_in_public", false)
	var paths: Array = receipts.get(receipt.id, {}).get("provenance_paths", []).duplicate(true)
	if (via != "" or anonymous or not paths.is_empty()) and receipt.provenance not in paths:
		paths.append(receipt.provenance.duplicate(true))
	receipt.provenance_paths = paths
	receipts[receipt.id] = receipt
	ledger_hear(w, listener, eid, [], weight, [source.id, entry["day"], "reading"], {"kind": "reading", "workshop_receipts": receipts})
	if fresh and source != listener and weight > 0.2:
		w.on_execution_reading_heard(listener, source, entry, weight)

static func info_eid(src: String, entry: Dictionary) -> String:
	return WorkshopLedger.reading_key(WorkshopLedger.reading(src, entry))

static func update_from_own_info(w) -> void:
	for n in w.evil_team():
		if n.alive:
			_shadow_own_info(w, n)
	for n in w.living_good():
		while n.applied_info < n.info_log.size():
			var e: Dictionary = n.info_log[n.applied_info]
			n.applied_info += 1
			apply_info(w, n, n, e, 1.0)

## How much a reading heard first-hand from its giver counts, before credibility. The
## giver's credibility is applied live by the ledger (it changes as evidence comes in).
static func heard_weight(listener, speaker) -> float:
	return Tuning.Mind.HEARD_READING_WEIGHT

# ---------------------------------------------------------------- night choices (good)

static func ranked_suspects(w, n, social_pressure: bool = false) -> Array:
	var c: Array = w.living().filter(func(m): return m != n)
	c.sort_custom(func(a, b): return action_susp(n, a.id) > action_susp(n, b.id) if social_pressure else susp(n, a.id) > susp(n, b.id))
	return c

## The previous crowd weight and read clamp, confined to social action. In
## particular, it must never enter reading honesty or the shared world's prior.
static func action_susp(n, id: String) -> float:
	var score = clampf(n.suspicion.get(id, 0.0) + n.consensus_pressure.get(id, 0.0), 0.0, 1.5)
	return score + execution_priority_contribution(n, id) if C.SHARED_EXECUTION_PRIORITY_WEIGHT != 0.0 else score

## Only a current shared solve can supply action inputs. This read is separate
## from suspicion, source honesty and the world's prior, including on evil covers.
static func execution_priority(n, id: String) -> float:
	if not n.workshop_state.get("active", false):
		return 0.0
	return clampf(float(n.workshop_state.get("action", {}).get("execution_priority", {}).get(id, 0.0)), 0.0, 1.0)

static func execution_priority_contribution(n, id: String) -> float:
	return C.SHARED_EXECUTION_PRIORITY_WEIGHT * execution_priority(n, id)

## The Seer's two picks, by Insight. A sharp Seer usually re-checks their top suspect and
## pairs them with someone they haven't looked at yet; once two readings have said "yes"
## with that suspect in them, it's settled as far as sight can tell (the demon or the one
## who reads falsely), so they spend their sight on two fresh people instead. A dull Seer
## is more random and doesn't build on what they've seen.
static func seer_picks(w, n) -> Array:
	return C.role_def("seer").pick_targets(w, n, _mind())

## An agreed player request for tonight's use of their gift ([] if none, or if it's stale).
static func requested_targets(w, n, role: String) -> Array:
	var rq: Dictionary = n.gift_request
	if rq.get("night", -1) != w.day or rq.get("role", "") != role:
		return []
	return rq.get("targets", [])

## The player asks someone who told them their gift to use it a particular way tonight:
## a Seer to look at one or two people, a Warden to guard someone, a Night Watch to watch a
## block. They agree, refuse, or say what they'd rather do, by trust, how they feel about the
## target and what they'd have done anyway. An agreed request replaces tonight's pick only.
## Evil bluffers answer the same way and fake the result.
static func consider_gift_request(w, n, role: String, targets: Array) -> Dictionary:
	on_question(w, n)
	var ranked: Array = ranked_suspects(w, n)
	var top: String = ranked[0].id if not ranked.is_empty() else ""
	var parts = {"trust": (n.trust - 0.5) * Tuning.Mind.GIFT_REQ_TRUST_SLOPE, "base": Tuning.Mind.GIFT_REQ_BASE}
	var rdef = C.role_def(role)
	if rdef != null:
		rdef.score_gift_request(w, n, targets, top, parts, _mind())
	var named: String = _request_target_text(w, role, targets)
	var yes: bool = decide(w, n, "gift_request", parts, "Use the %s tonight as the Demonologist asks (%s)?" % [C.role_name(role), named])
	if yes:
		n.gift_request = {"night": w.day, "role": role, "targets": targets.duplicate()}
		w.dlog.add("gift_request_agreed", "player", n.id, {"role": role, "targets": targets})
		var agree_tpl: String = rdef.request_agree_line if rdef != null and rdef.request_agree_line != "" else ""
		var agree_fallback: String = (agree_tpl % named) if agree_tpl != "" else ""
		if rdef != null and rdef.request_agree_voice_key != "":
			return {"lines": [say_voiced(n, rdef.request_agree_voice_key, agree_fallback, {rdef.request_agree_slot: named})], "facts": [], "agreed": true}
		return {"lines": [say(n, agree_fallback)], "facts": [], "agreed": true}
	w.dlog.add("gift_request_refused", "player", n.id, {"role": role, "targets": targets})
	var counter: String = ""
	if n.trust >= Tuning.Mind.GIFT_REQ_COUNTER_MIN_TRUST and top != "" and not (top in targets) and rdef != null:
		counter = rdef.counter_gift_request(w, n, targets, top)
	if counter != "":
		return {"lines": [say_voiced(n, "gift_req_counter", "No. " + counter, {"counter": counter})], "facts": [], "agreed": false}
	return {"lines": [say_voiced(n, "gift_req_refuse", "My gift's mine to use as I see fit.")], "facts": [], "agreed": false}

static func _request_target_text(w, role: String, targets: Array) -> String:
	var rdef = C.role_def(role)
	if rdef != null:
		return rdef.request_target_text(w, targets, C.block_name)
	return " and ".join(PackedStringArray(targets.map(func(t): return w.by_id[t].name)))

static func watch_block(w, n) -> String:
	return C.role_def("nightwatch").pick_targets(w, n, _mind())

## The Warden tells the person whose door they guarded that the quiet night was their save
## (Oct 30). The protectee hears the claim and the guard statement as ordinary testimony
## (the shared model reads "the Demon went for me, so I'm likely good" from it), and warms
## to the Warden if they believe them. Evil protectees just learn who the Warden is.
static func tell_save(w, warden, protectee, night: int, belief: float) -> void:
	var rdef = C.role_def("warden")
	var fact: Dictionary = rdef.guard_fact(w, warden, night, protectee.id, func(b): return C.block_name(b))
	protectee.known_claims[warden.id] = {"role": "warden", "readings": protectee.known_claims.get(warden.id, {}).get("readings", []), "via": warden.id}
	warden.told_to["%s|save:%d" % [protectee.id, night]] = true
	w.dlog.add("warden_tells_save", warden.id, protectee.id, {"night": night, "belief": belief},
		"%s tells %s they stood at their door on night %d." % [warden.name, protectee.name, night])
	if protectee.is_evil():
		return
	hear_claim(w, protectee, warden.id, "warden", 1.0, "told")
	var card = fact.duplicate(true)
	card["learned"] = [{"day": w.day, "phase": w.phase, "via": warden.id}]
	var receipt = WorkshopLedger.Evidence.normalize_card(card)
	ledger_hear(w, protectee, "heard:" + receipt.id, [], 1.0, [warden.id, night, "report"],
		{"kind": "tell", "workshop_card": receipt, "workshop_teller": warden.id, "workshop_public": false})
	if susp(protectee, warden.id) < Tuning.Social.GOSSIP_BELIEVED_BELOW:
		protectee.npc_trust[warden.id] = clampf(protectee.npc_trust.get(warden.id, 0.5) + Tuning.Roles.WARDEN_SAVE_TRUST * belief, 0.0, 1.0)

static func warden_target(w, n) -> String:
	return C.role_def("warden").pick_targets(w, n, _mind())

# ---------------------------------------------------------------- town meeting (sim/mind_meeting.gd)

const CONSENSUS_BASE = MindMeeting.CONSENSUS_BASE
const CONSENSUS_FADE = MindMeeting.CONSENSUS_FADE
const CONSENSUS_CAP = MindMeeting.CONSENSUS_CAP
const CONSENSUS_HINT = MindMeeting.CONSENSUS_HINT

static func meeting_testimony(w) -> Array:
	return MindMeeting.meeting_testimony(w)

static func testimony_start(w) -> Dictionary:
	return MindMeeting.testimony_start(w)

static func testimony_step(w, st: Dictionary) -> Dictionary:
	return MindMeeting.testimony_step(w, st)

static func _public_sighting_allowed(w, n, b: Dictionary) -> bool:
	return MindMeeting._public_sighting_allowed(w, n, b)

static func _town_sighting_key(n, b: Dictionary) -> String:
	return MindMeeting._town_sighting_key(n, b)

static func _volunteer_night_sightings(w, n, lines: Array, facts: Array) -> void:
	MindMeeting._volunteer_night_sightings(w, n, lines, facts)

static func _public_claim_decision(w, n) -> String:
	return MindMeeting._public_claim_decision(w, n)

static func _claim_line(n, role: String) -> Dictionary:
	return MindMeeting._claim_line(n, role)

static func _info_intent(w, n, e: Dictionary) -> Dictionary:
	return MindMeeting._info_intent(w, n, e)

static func info_line(w, n, e: Dictionary, audience: String = "player", speech_act: String = "answer") -> Dictionary:
	return MindMeeting.info_line(w, n, e, audience, speech_act)

static func info_lines(w, n, entries: Array, audience: String = "player", preceded: bool = false, speech_act: String = "answer") -> Array:
	return MindMeeting.info_lines(w, n, entries, audience, preceded, speech_act)

static func info_fact(w, n, e: Dictionary) -> Dictionary:
	return MindMeeting.info_fact(w, n, e)

static func reason_status(w, n, t_id: String) -> Dictionary:
	return MindMeeting.reason_status(w, n, t_id)

static func citable_reason(w, n, t_id: String, audience: String = "town") -> String:
	return MindMeeting.citable_reason(w, n, t_id, audience)

static func _unshared_fake_on(n, t_id: String) -> Dictionary:
	return MindMeeting._unshared_fake_on(n, t_id)

static func _heard_reading(w, n, eid: String) -> Dictionary:
	return MindMeeting._heard_reading(w, n, eid)

static func relay_reading(w, n, src, e: Dictionary, lines: Array, facts: Array) -> void:
	MindMeeting.relay_reading(w, n, src, e, lines, facts)

static func acknowledge_reading(w, listener, source, entry: Dictionary, teller: String) -> void:
	MindMeeting.acknowledge_reading(w, listener, source, entry, teller)

static func reveal_cost(w, n) -> Dictionary:
	return MindMeeting.reveal_cost(w, n)

static func _accuse_tier(w, n, t, s2: float) -> Dictionary:
	return MindMeeting._accuse_tier(w, n, t, s2)

static func _accuse_tier_impl(w, n, t, s2: float) -> Dictionary:
	return MindMeeting._accuse_tier_impl(w, n, t, s2)

static func _public_disclosure(w, n, lines: Array, facts: Array, share_readings: bool = true) -> void:
	MindMeeting._public_disclosure(w, n, lines, facts, share_readings)

static func _go_public(w, n, lines: Array, facts: Array, share_readings: bool = true) -> void:
	MindMeeting._go_public(w, n, lines, facts, share_readings)

static func last_words(w, n) -> Dictionary:
	return MindMeeting.last_words(w, n)

static func _public_accusation(w, n, lines: Array = [], facts: Array = []):
	return MindMeeting._public_accusation(w, n, lines, facts)

static func _append_accusation_sighting(w, n, target, why: String, lines: Array, facts: Array) -> void:
	MindMeeting._append_accusation_sighting(w, n, target, why, lines, facts)

static func refresh_consensus(w, l, target: String) -> void:
	MindMeeting.refresh_consensus(w, l, target)

static func refresh_all_consensus(w) -> void:
	MindMeeting.refresh_all_consensus(w)

static func nomination_cooloff(w, nominator_id: String, target_id: String) -> float:
	return MindMeeting.nomination_cooloff(w, nominator_id, target_id)

static func _good_nomination(w, n, m: Dictionary, block: String):
	return MindMeeting._good_nomination(w, n, m, block)

static func _good_nomination_impl(w, n, m: Dictionary, block: String, trace_id: int):
	return MindMeeting._good_nomination_impl(w, n, m, block, trace_id)

static func _evil_nomination(w, n, m: Dictionary, block: String):
	return MindMeeting._evil_nomination(w, n, m, block)

static func next_nomination(w):
	return MindMeeting.next_nomination(w)

static func case_against(w, n, t_id: String, limit: int = 3) -> Array:
	return MindMeeting.case_against(w, n, t_id, limit)

static func nomination_case(w, n, t, already: String) -> Dictionary:
	return MindMeeting.nomination_case(w, n, t, already)

static func defend_self(w, d, nominator_id: String, disclosed_facts: Array = []) -> Dictionary:
	return MindMeeting.defend_self(w, d, nominator_id, disclosed_facts)

static func defence_line(w, n) -> Dictionary:
	return MindMeeting.defence_line(w, n)

static func vote(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int) -> bool:
	return MindMeeting.vote(w, v, nominee, nominator, player_yes, statement, yes_so_far)

static func vote_resistance_lines(w, res: Dictionary) -> Array:
	return MindMeeting.vote_resistance_lines(w, res)

static func _vote_impl(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int, trace_id: int) -> bool:
	return MindMeeting._vote_impl(w, v, nominee, nominator, player_yes, statement, yes_so_far, trace_id)


# ---------------------------------------------------------------- pressing & conversation (sim/mind_dialogue.gd)

static func has_live_hint(w, n) -> bool:
	return MindDialogue.has_live_hint(w, n)

static func answer_hint(w, n) -> Dictionary:
	return MindDialogue.answer_hint(w, n)

static func _hint_decline(w, n, t) -> Dictionary:
	return MindDialogue._hint_decline(w, n, t)

static func press(w, n, card: Dictionary, known_haunts: Dictionary = {}) -> Dictionary:
	return MindDialogue.press(w, n, card, known_haunts)

static func react_to_trace(w, n, card: Dictionary, known_haunts: Dictionary = {}, already_counted: bool = false) -> Dictionary:
	return MindDialogue.react_to_trace(w, n, card, known_haunts, already_counted)

static func _gift_outing(w, n, night: int) -> bool:
	return MindDialogue._gift_outing(w, n, night)

static func sleepwalk_excuse(w, n, where: String) -> Dictionary:
	return MindDialogue.sleepwalk_excuse(w, n, where)

static func _answer_pressed_night(w, n, night: int) -> Dictionary:
	return MindDialogue._answer_pressed_night(w, n, night)

static func on_question(w, n) -> void:
	MindDialogue.on_question(w, n)

static func greeting_cue(w, n) -> String:
	return MindDialogue.greeting_cue(w, n)

static func greeting_line(w, n, context: Dictionary = {}, roll_attitude: bool = true) -> Dictionary:
	return MindDialogue.greeting_line(w, n, context, roll_attitude)

static func end_conversation(w, n) -> Array:
	return MindDialogue.end_conversation(w, n)

static func reveal_trait(w, n) -> String:
	return MindDialogue.reveal_trait(w, n)

static func _target_tier(w, n, trace_id: int = 0) -> int:
	return MindDialogue._target_tier(w, n, trace_id)

static func fear_chance(w, n) -> float:
	return MindDialogue.fear_chance(w, n)

static func _afraid(w, n) -> bool:
	return MindDialogue._afraid(w, n)

static func _day_roll(id: String, day: int, salt: int) -> float:
	return MindDialogue._day_roll(id, day, salt)

static func protection_kind(w, n) -> String:
	return MindDialogue.protection_kind(w, n)

static func protection_line(n, kind: String) -> Dictionary:
	return MindDialogue.protection_line(n, kind)

static func _protection_request(w, n, refusal: Dictionary) -> Dictionary:
	return MindDialogue._protection_request(w, n, refusal)

static func _confidence_request(w, n, tier: int, refusal: Dictionary) -> Dictionary:
	return MindDialogue._confidence_request(w, n, tier, refusal)

static func keep_request(w, n, tier: int) -> Dictionary:
	return MindDialogue.keep_request(w, n, tier)

static func answer_gift(w, n, force_tier: int = 0, count_question: bool = true) -> Dictionary:
	return MindDialogue.answer_gift(w, n, force_tier, count_question)

static func _answer_gift_impl(w, n, force_tier: int, trace_id: int, count_question: bool = true) -> Dictionary:
	return MindDialogue._answer_gift_impl(w, n, force_tier, trace_id, count_question)

static func _gossip_share(w, n, topic: String) -> int:
	return MindDialogue._gossip_share(w, n, topic)

static func warden_door(w, n, nd: int) -> String:
	return MindDialogue.warden_door(w, n, nd)

static func _guard_fact(w, n, nd: int, guarded: String) -> Dictionary:
	return MindDialogue._guard_fact(w, n, nd, guarded)

static func _hearth_dead(w, n, nd: int):
	return MindDialogue._hearth_dead(w, n, nd)

static func _bluff_hearth(w, n, nd: int) -> String:
	return MindDialogue._bluff_hearth(w, n, nd)

static func _alibi_home(n, nd: int) -> Dictionary:
	return MindDialogue._alibi_home(n, nd)

static func answer_night(w, n, night: int = -1) -> Dictionary:
	return MindDialogue.answer_night(w, n, night)

static func reading_disclosed(n, entry: Dictionary) -> bool:
	return MindDialogue.reading_disclosed(n, entry)

static func _fake_watch_entry(n, nd: int) -> Dictionary:
	return MindDialogue._fake_watch_entry(n, nd)

static func _spoken_list(items: Array) -> String:
	return Dialogue.Observations.spoken_list(items)

static func _add_observation(groups: Array, observation: Dictionary) -> void:
	MindDialogue._add_observation(groups, observation)

static func _observation_lines(n, groups: Array, audience: String, speech_act: String, preceded: bool, first_relation: String = "independent") -> Array:
	return MindDialogue._observation_lines(n, groups, audience, speech_act, preceded, first_relation)

static func sighting_report(w, n, b: Dictionary, nd: int) -> Dictionary:
	return MindDialogue.sighting_report(w, n, b, nd)

static func sighting_is_here(w, b: Dictionary, who: String, near_loc: String = "") -> bool:
	return MindDialogue.sighting_is_here(w, b, who, near_loc)

static func answer_today(w, n, when: String = "", near_loc: String = "", seen_pairs: Dictionary = {}) -> Dictionary:
	return MindDialogue.answer_today(w, n, when, near_loc, seen_pairs)

static func answer_opinion(w, n, t) -> Dictionary:
	return MindDialogue.answer_opinion(w, n, t)

# ---------------------------------------------------------------- case & card evaluation

## Evidence class of a card: speech, circumstantial or concrete.
static func evidence_class(card: Dictionary) -> String:
	var src: String = card.get("source", "")
	var kind: String = card.get("kind", "")
	if src == "player" and kind in ["sighting", "vigil", "death", "vote", "execution", "conversation", "quiet"]:
		return "concrete"
	if kind == "deduction":
		return card.get("class", "circumstantial")
	if kind in ["claim", "hint", "refusal", "opinion", "accusation", "alibi"]:
		return "speech"
	return "circumstantial"

## Does a board card point at `id`, by its structure alone (purge phase 4b)? Night
## sightings, gift readings that implicate them, traces, secrets, and a role claim that
## collides with someone else's public claim. No weights: how much it counts is the
## shared model's business (card_weight_against).
static func card_implicates(w, card: Dictionary, id: String) -> bool:
	if WorkshopLedger.Evidence.contains_opinion(card) or WorkshopLedger.Evidence.social_reading(card):
		return false
	match card.get("kind", ""):
		"sighting":
			return card.get("phase", -1) == C.NIGHT and id in card.get("subject", [])
		"info":
			if id in Gifts.implicated(card):
				return true
			if card.get("role", "") == "registrar":
				var rd: Dictionary = card.get("data", {})
				if not bool(rd.get("yes", true)) and str(rd.get("target", "")) == id and w.by_id.has(id) and w.by_id[id].claimed_role in rd.get("roles", []):
					return true
			return false
		"trace":
			return true
		"secret":
			return id in card.get("subject", []) or card.get("owner", "") == id
		"claim":
			var role: String = card.get("role", "")
			if role == "" or role == "none":
				return false
			for pc in w.public_claims:
				if pc["role"] == role and pc["who"] != id:
					return true
	return false

## Does a board card speak for `id`, by its structure alone? A gift reading that clears
## them, a deduction concluding something good about them, their death, a vigil or a
## secret that accounts for them. With `claims`, their own role claim counts too (thanks
## for repeating what they said).
static func card_clears(card: Dictionary, id: String, claims: bool = false) -> bool:
	if WorkshopLedger.Evidence.contains_opinion(card) or WorkshopLedger.Evidence.social_reading(card):
		return false
	if not (id in card.get("subject", [])):
		return false
	match card.get("kind", ""):
		"deduction":
			var conclusion: Dictionary = card.get("conclusion", {})
			if conclusion.get("a", "") != id or card.get("unfounded", false):
				return false
			if conclusion.get("type", "") in ["good", "notdemon", "truthful", "spare", "protect", "secret", "marked", "red_herring"]:
				return true
			return conclusion.get("type", "") == "role" and C.ROLES.get(conclusion.get("role", ""), {}).get("align", "") == "good"
		"info":
			return id in Gifts.clears(card)
		"death", "vigil", "secret":
			return true
		"claim":
			return claims
	return false

## How hard a card lands against `target_id`, in the town's own shared judgement (0..1):
## the strongest weight any living mind's reason attribution gives this card's roots
## against them. Cards the model has no entry for get a fixed value if they structurally
## implicate the target, else 0.
static func card_weight_against(w, card: Dictionary, target_id: String) -> float:
	var ids: Dictionary = WorkshopLedger.roots([card], []).receipts
	var best: float = -1.0
	if not ids.is_empty():
		for m in w.npcs:
			if not m.alive or m.id == target_id:
				continue
			for item in m.workshop_state.get("reasons", {}).get(target_id, []):
				var hit: bool = ids.has(str(item.get("card_id", "")))
				if not hit:
					for r in item.get("root_ids", []):
						if ids.has(str(r)):
							hit = true
							break
				if hit:
					best = maxf(best, float(item.get("strength", 0.0)))
	if best >= 0.0:
		return clampf(best, 0.0, 1.0)
	return Tuning.Dialogue.UNMODELLED_CARD_WEIGHT if card_implicates(w, card, target_id) else 0.0

## Is this card already among the reasons `v` holds against `target_id` (its own receipt or
## one of its roots)? Then citing it against them changes nothing in v's shared model.
static func card_already_weighed(v, card: Dictionary, target_id: String) -> bool:
	var ids: Dictionary = WorkshopLedger.roots([card], []).receipts
	if ids.is_empty():
		return false
	for item in v.workshop_state.get("reasons", {}).get(target_id, []):
		if ids.has(str(item.get("card_id", ""))):
			return true
		for r in item.get("root_ids", []):
			if ids.has(str(r)):
				return true
	return false

## Using someone's confessed secret against them costs trust with its owner.
static func _secret_used(w, card: Dictionary) -> void:
	if card.get("kind", "") != "secret":
		return
	var owner = w.by_id.get(card.get("owner", ""))
	if owner == null or not owner.alive:
		return
	var p = trait_of(owner, "privacy")
	var first = not owner.secret_spread
	owner.secret_spread = true
	var loss = Tuning.Trust.SECRET_SPREAD_BASE + Tuning.Trust.SECRET_SPREAD_PRIVACY * p
	set_trust(w, owner, owner.trust - (loss if first else loss * Tuning.Trust.SECRET_SPREAD_REPEAT_MULT), "the Demonologist spread my secret")
	if p >= 0.67:
		cap_trust(w, owner, Tuning.Trust.SECRET_CAP_HIGH_PRIVACY, "the Demonologist spread my secret (very private person)")
	elif p >= 0.34:
		cap_trust(w, owner, Tuning.Trust.SECRET_CAP_MID_PRIVACY, "the Demonologist spread my secret")

## How much a card weighs with one listener, against or for one suspect. Counts as a hearing
## (diminishing returns per card per listener).
static func card_weight(w, n, suspect, card: Dictionary) -> Dictionary:
	var subj: Array = card.get("subject", [])
	var relevance = 1.0 if suspect.id in subj else 0.25
	var src: String = card.get("source", "")
	var cred = 0.5
	var cred_why = ""
	if src == "player":
		cred = 1.0
		cred_why = "the Demonologist saw it"
	elif src == "evidence":
		cred = 0.9
		cred_why = "physical evidence"
	elif src == n.id:
		cred = 1.0
		cred_why = "their own words"
	elif src != "" and w.by_id.has(src):
		cred = 0.75  # their credibility is applied live by the ledger (rel below)
		cred_why = "source %s" % src
	if card.get("kind", "") == "trace":
		if card.get("trace_family", "") != "":
			var tr_check = {"trace_family": card.get("trace_family", ""), "locs": card.get("locs", []), "home_block": card.get("trace_home_block", ""), "evening_block": card.get("trace_evening_block", ""), "victim": card.get("victim", ""), "day": card.get("day", -1)}
			relevance = 0.85 if w.actor_fits_trace_truth(suspect, tr_check) else 0.25
		else:
			relevance = 1.0 if suspect.home_block == card.get("block", "") or w.loc_block(suspect.work) == card.get("block", "") else 0.3
	var cls = evidence_class(card)
	var ins = trait_of(n, "insight")
	var class_w = {"speech": lerpf(1.0, 0.2, ins), "circumstantial": lerpf(1.0, 0.6, ins), "concrete": 1.0}[cls]
	var key: String = fact_id(card)
	var times: int = n.heard.get(key, 0)
	n.heard[key] = times + 1
	var rel: Array = []
	if src != "" and w.by_id.has(src) and src != n.id:
		rel = support_ref(card)
	return {"rel": rel, "relevance": relevance, "cred": cred, "cred_why": cred_why, "cls": cls, "class_w": class_w,
		"repeat": pow(0.35, times), "times": times, "key": key, "subj": subj}

## The player's case: "tell <n>: <suspect> is suspicious because <card>".
static func hear_accusation(w, n, suspect, card: Dictionary) -> Dictionary:
	on_question(w, n)
	if not n.is_shadow:
		_secret_used(w, card)
	var lines: Array = []
	var cw = card_weight(w, n, suspect, card)
	var strength = card_weight_against(w, card, suspect.id)
	var relevance: float = cw["relevance"] * strength
	var times: int = cw["times"]
	var cls: String = cw["cls"]
	var ins = trait_of(n, "insight")
	if n.is_evil():
		var er: Dictionary = Evil.evil_hear_accusation(w, n, suspect, card, relevance, times)
		# Shadow self (step 2): the good self hears the case too, and its reply is the one
		# given, unless it's about them or breaking cover to protect a teammate is worth it.
		var sr = shadow_eval(w, n, func(sh): return hear_accusation(w, sh, suspect, card)) if C.SHADOW_SELF else null
		er["workshop"] = sr != null and sr.get("workshop", false)
		if sr == null or suspect == n or (times > 0 and not sr.get("workshop", false)):
			return er
		if Evil.is_teammate(w, n, suspect.id):
			var stakes = Evil.teammate_value(w, suspect.id) * (0.3 + Evil.public_heat(w, suspect))
			if evil_override(w, n, "private case", stakes, 0.5, "the Demonologist's case against %s" % suspect.id):
				return er
		return sr
	if w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(n, card, [suspect.id], "accuse", "private", true)
		if not interpreted.is_empty():
			if not interpreted.get("blocked", false) and not interpreted.get("repeated", false):
				n.player_cases.append({"suspect": suspect.id, "card": card.duplicate(true)})
			return interpreted
	if times == 0:
		n.player_cases.append({"suspect": suspect.id, "card": card})
	ledger_hear(w, n, "tell:%s>%s" % [cw["key"], suspect.id], [], 0.25 * (0.5 + n.credibility), cw["rel"],
		{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": false})
	n.used_facts[cw["key"] + ">" + suspect.id] = true
	if times > 0:
		lines.append(say_voiced(n, "present_repeat_private", "You've told me that already."))
	elif suspect == n:
		lines.append(Presentations.render_evil_override(w, n, {"type": "evil", "a": n.id}, "reject", false, false, "player", "Me? That's madness.", _tic_memory(n)))
	elif cls == "speech" and ins >= 0.67:
		lines.append(say_voiced(n, "present_unmoved", "That's only talk. Show me something real.", {"target": suspect.name}))
	else:
		lines.append(say_voiced(n, "present_partial", "Maybe. I'll keep an eye on %s." % suspect.name, {"target": suspect.name}))
	return {"lines": lines, "facts": [], "repeated": times > 0}

## The player speaks for someone in private, citing a card ("present <card#> for <name>").
static func hear_defence(w, n, whos, card: Dictionary) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var group: Array = whos if whos is Array else [whos]
	var who = group[0]
	var gname: String = who.name if group.size() == 1 else " and ".join(PackedStringArray(group.map(func(x): return x.name)))
	# A self-directed defence can carry evidence about other people too. Hear
	# its roots before the social thanks, just like any other presentation.
	if not n.is_evil() and w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(n, card, group.map(func(p): return p.id), "defend", "private", true)
		if not interpreted.is_empty():
			return interpreted
	if group.size() == 1 and who.id == n.id:
		var shared_self = false
		if n.is_evil() and C.SHADOW_SELF:
			var own_defence = shadow_eval(w, n, func(sh): return hear_defence(w, sh, whos, card))
			shared_self = own_defence != null and own_defence.get("workshop", false)
		var key = "support_self:" + fact_id(card)
		var repeated: bool = n.heard.has(key)
		n.heard[key] = n.heard.get(key, 0) + 1
		if repeated:
			lines.append(Presentations.render_self_support(n, "repeat", "You've told me that already. Thank you.", _tic_memory(n)))
		elif card_clears(card, n.id, true):
			set_trust(w, n, n.trust + Tuning.Trust.SELF_SUPPORT_BONUS, "the Demonologist spoke up for me")
			lines.append(Presentations.render_self_support(n, "thanks", "Thank you for believing me.", _tic_memory(n)))
		else:
			lines.append(Presentations.render_self_support(n, "weak", "I appreciate the support, but I'm not sure that explains it.", _tic_memory(n)))
		return {"lines": lines, "facts": [], "repeated": repeated, "workshop": shared_self}
	if n.is_evil():
		var r = w.rng.randf()
		w.observe_decision(n, "defence_reply", r < (0.6 if who.is_evil() else 0.7), {"probability": 0.6 if who.is_evil() else 0.7, "draw": r, "comparison": "<", "inputs": {}}, who.id)
		if who.is_evil():
			lines.append(say_voiced(n, "present_accept_open" if r < 0.6 else "present_partial", "Fair enough. I'll think better of %s." % who.name if r < 0.6 else "Maybe. I'll keep an open mind about %s." % who.name, {"target": who.name}))
		else:
			lines.append(say_voiced(n, "present_partial" if r < 0.7 else "present_unmoved", "Maybe. I'll keep an open mind about %s." % who.name if r < 0.7 else "That doesn't clear %s." % who.name, {"target": who.name}))
		var dr = shadow_eval(w, n, func(sh): return hear_defence(w, sh, whos, card)) if C.SHADOW_SELF else null
		if dr != null:
			# Evil would rather a good person stay suspect: worth more if they're a threat.
			var threats = group.filter(func(x): return not x.is_evil())
			var stakes = 0.0
			for x in threats:
				stakes += 0.3 + (0.3 if Evil.intel_threat(n, x.id) > 0.0 else 0.0)
			if threats.is_empty() or not evil_override(w, n, "private defence", stakes, 0.5, "the Demonologist speaking for %s" % gname):
				return dr
		return {"lines": lines, "facts": [], "workshop": dr != null and dr.get("workshop", false)}
	var times = 0
	for x in group:
		var cw = card_weight(w, n, x, card)
		var hx = ledger_hear(w, n, "for:%s>%s" % [cw["key"], x.id], [], 0.25 * (0.5 + n.credibility) / group.size(), cw["rel"],
			{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": false})
		times = maxi(times, hx["times"])
	if times > 0:
		lines.append(say_voiced(n, "present_repeat_private", "You've told me that already."))
	else:
		lines.append(say_voiced(n, "present_partial", "Maybe. I'll keep an open mind about %s." % gname, {"target": gname}))
	return {"lines": lines, "facts": [], "repeated": times > 0}

## A card that implicates one of several people (a Seer "yes" on two): the case is split
## between them. Evil hears it through the usual mask.
static func hear_group_case(w, n, group: Array, card: Dictionary) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var gname = " and ".join(PackedStringArray(group.map(func(x): return x.name)))
	if n.is_evil():
		for x in group:
			if x.is_evil():
				Evil.add_intel(w, n, "player_suspects", x.id, 0.0, "the Demonologist thinks it's one of %s" % gname)
		var grp_partial: bool = w.decision_roll(n, "group_defence_reply", 0.6)
		lines.append(say_voiced(n, "present_partial" if grp_partial else "present_accept_open", "Maybe. I'll keep an eye on them both." if grp_partial else "That... does look bad for one of them.", {"target": gname}))
		var gr = shadow_eval(w, n, func(sh): return hear_group_case(w, sh, group, card)) if C.SHADOW_SELF else null
		if gr != null:
			var mates = group.filter(func(x): return Evil.is_teammate(w, n, x.id))
			var stakes = 0.0
			for x in mates:
				stakes += 0.5 * Evil.teammate_value(w, x.id) * (0.3 + Evil.public_heat(w, x))
			if mates.is_empty() or not evil_override(w, n, "private group case", stakes, 0.5, "a case against %s" % gname):
				return gr
		return {"lines": lines, "facts": [], "workshop": gr != null and gr.get("workshop", false)}
	if w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(n, card, group.map(func(p): return p.id), "accuse", "private", true)
		if not interpreted.is_empty():
			return interpreted
	var times = 0
	for x in group:
		var cw = card_weight(w, n, x, card)
		var h = ledger_hear(w, n, "tell:%s>%s" % [cw["key"], x.id], [], 0.25 * (0.5 + n.credibility) / group.size(), cw["rel"],
			{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": false})
		n.used_facts[cw["key"] + ">" + x.id] = true
		times = maxi(times, h["times"])
	if times > 0:
		lines.append(say_voiced(n, "present_repeat_private", "You've told me that already."))
	else:
		lines.append(say_voiced(n, "present_partial", "Maybe. I'll keep an eye on them both.", {"target": gname}))
	return {"lines": lines, "facts": [], "repeated": times > 0}

## A card-backed public statement on a nomination: every voter weighs it (more weakly than
## in private). direction: "accuse" or "defend". Returns a short summary for the log.
static func public_case(w, nominee, card: Dictionary, direction: String) -> void:
	_secret_used(w, card)
	for v in w.living():
		if v == nominee:
			continue
		var cw = card_weight(w, v, nominee, card)
		if v.is_evil():
			if direction == "accuse" and Evil.is_teammate(w, v, nominee.id):
				Evil.add_intel(w, v, "player_suspects", nominee.id, 0.0, "the Demonologist accused %s at the meeting" % nominee.id)
			shadow_run(w, v, func(sh): _public_case_hear(w, sh, nominee, card, direction, card_weight(w, sh, nominee, card)))
			continue
		_public_case_hear(w, v, nominee, card, direction, cw)

## One voter weighs the player's public case (see public_case).
static func _public_case_hear(w, v, nominee, card: Dictionary, direction: String, cw: Dictionary) -> void:
	if direction == "accuse" and card_already_weighed(v, card, nominee.id):
		# Already part of why they suspect the nominee: nothing new to assess (the player's
		# voice and credibility still count, through the statement itself).
		w.dlog.think(v.id, "public_case", "Already weighed card against %s; no new assessment." % nominee.id, {"card": card.get("n", 0)})
		return
	if w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(v, card, [nominee.id], direction, "nomination", false)
		if not interpreted.is_empty():
			return
	ledger_hear(w, v, "pub:%s:%s>%s" % [direction, cw["key"], nominee.id], [], 0.2 * (0.5 + v.credibility), cw["rel"],
		{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": true})
	if direction == "accuse":
		v.used_facts[cw["key"] + ">" + nominee.id] = true

## Tavern gossip. Returns {lines, facts}.
static func gossip(w) -> Dictionary:
	var present: Array = w.npcs_at("tavern").filter(func(n): return not n.silenced)
	if present.is_empty():
		return {"lines": ["The tavern is nearly empty. Nobody to overhear."], "facts": []}
	var weights: Array = present.map(func(m): return 0.1 + trait_of(m, "gossip"))
	var total = 0.0
	for x in weights:
		total += x
	var r: float = w.rng.randf() * total
	var observed_draw = r
	var speaker = present[0]
	for i in range(present.size()):
		r -= weights[i]
		if r <= 0:
			speaker = present[i]
			break
	if w.dlog.live_feed != null and w.dlog.live_feed.enabled:
		var speaker_weights = {}
		for i in range(present.size()): speaker_weights[present[i].id] = weights[i]
		w.observe_decision(speaker, "gossip_speaker", speaker.name, {"weights": speaker_weights, "selected": speaker.id, "draw": observed_draw, "comparison": "cumulative weights", "inputs": {"gossip": trait_of(speaker, "gossip")}})
	if speaker.is_evil():
		var fake = Evil.fake_gossip(w, speaker)
		if fake != null:
			return fake
	# Nothing they've already told you (privately, or in your hearing at the tavern).
	var night_seen: Array = speaker.beliefs.filter(func(b): return b["kind"] == "saw" and b["phase"] == C.NIGHT and b["day"] >= w.day - 2 \
		and not speaker.told_to.has("player|saw:%s:%d" % [b["who"], b["day"]]))
	if not night_seen.is_empty():
		var b: Dictionary = night_seen[night_seen.size() - 1]
		var who = w.by_id[b["who"]]
		speaker.told_to["player|saw:%s:%d" % [b["who"], b["day"]]] = true
		w.dlog.think(speaker.id, "gossip", "Shares a true night sighting of %s." % who.id)
		return {"lines": ["You overhear %s telling the room that %s was out on %s on night %d." %
			[speaker.name, who.name, C.block_name(b["block"]), b["day"]]],
			"facts": [{"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": C.NIGHT, "source": speaker.id,
				"text": "Gossip from %s: %s was out on %s on night %d." % [speaker.name, who.name, C.block_name(b["block"]), b["day"]]}]}
	var ranked = ranked_suspects(w, speaker)
	if not ranked.is_empty() and susp(speaker, ranked[0].id) >= Tuning.Social.TAVERN_OVERHEAR_MIN_SUSP and not speaker.told_to.has("player|gossip_susp:%s:%d" % [ranked[0].id, w.day]):
		var t = ranked[0]
		speaker.told_to["player|gossip_susp:%s:%d" % [t.id, w.day]] = true
		w.dlog.think(speaker.id, "gossip", "Shares their suspicion of %s." % t.id)
		var why: String = Evil.cite(w, speaker, citable_reason(w, speaker, t.id, "town"))
		var tail = (", because " + why) if why != "" else ". Something's off about them, apparently"
		return {"lines": ["You overhear %s muttering that %s can't be trusted%s." % [speaker.name, t.name, tail]],
			"facts": [{"kind": "opinion", "subject": [t.id], "source": speaker.id, "text": "Gossip: %s distrusts %s." % [speaker.name, t.name]}]}
	return {"lines": ["You overhear %s complaining about the price of bread. Nothing useful." % speaker.name], "facts": []}

static func _observation_scene(n, b: Dictionary, day: int) -> Dictionary:
	return MindDialogue._observation_scene(n, b, day)
