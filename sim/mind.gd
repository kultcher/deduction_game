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

static func _mind():
	return load("res://sim/mind.gd")

# ---------------------------------------------------------------- utilities

static func say(n, text: String) -> Dictionary:
	return {"speaker": n.id, "name": n.name, "text": text}

static func say_voiced(n, key: String, fallback: String, slots: Dictionary = {}) -> Dictionary:
	return {"speaker": n.id, "name": n.name, "text": Dialogue.voice_line(n.id, key, fallback, slots), "statement": fallback}

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
			var rephrased: Dictionary = line.duplicate(true)
			rephrased["text"] = voiced(n, "doubted", line["text"], fact_id(card), {"challenged": true})["text"]
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
		"serious": drop >= SERIOUS_GRIEVANCE, "evidence": evidence, "apologised": false})

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
		share *= 1.0 - clampf((ins - 0.4) * 1.2, 0.0, 0.6)
	var repair: float = g["drop"] * share
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
	if n.trust >= 0.35 or n.distrust_explained_day == w.day:
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
static func end_of_day_trust(w) -> void:
	for n in w.living():
		if n.secret_known and not n.secret_spread:
			var bonus = Tuning.Trust.SECRET_KEPT_BASE + Tuning.Trust.SECRET_KEPT_PRIVACY_SCALE * trait_of(n, "privacy")
			if n.secret_spread_by_npc:
				bonus *= Tuning.Trust.SECRET_KEPT_RUMOR_MULT
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
	"suspicion", "sus_why", "sus_src", "npc_trust", "ledger", "honesty", "discounted", "believed_roles",
	"cleared", "protect_pref", "spare_pref", "known_claims", "known_secrets", "heard", "used_facts", "workshop_state", "consensus_pressure"]
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
		hear_claim(w, s, s.id, s.role, 1.5, "own")  # knows "its own" gift, as every good NPC does
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
	for f in ["alive", "death_day", "loc", "working", "busy_with", "silenced", "trust", "trust_cap",
			"pressure", "claimed_role", "claim_public", "max_tier", "told_readings", "night_block", "out_last_night"]:
		s.set(f, n.get(f))
	for k in n.npc_trust:
		s.npc_trust[k] = n.npc_trust[k]
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

## Freed from the Revenant's curse: the good self they kept while turned becomes their
## mind again. It heard everything they heard as evil, and never knew who else was evil,
## which is what "remembers nothing of their time as evil" means. What it took from their
## own fake readings is dropped (those readings are disowned), and the beliefs re-derived.
static func shadow_adopt(w, n) -> void:
	var s = n.shadow
	if s == null:
		return
	for f in SHADOW_COPY:
		if f in ["traits", "trait_base", "work_phases", "haunts", "friends", "rivals"]:
			continue
		n.set(f, s.get(f).duplicate(true))
	for e in n.info_log:
		if e.get("fake", false):
			n.ledger.erase(info_eid(n.id, e))
	n.applied_info = n.info_log.size()
	w.dlog.think(n.id, "shadow_adopt", "Freed: takes back their good self's beliefs (%d ledger entries)." % n.ledger.size())
	recompute_beliefs(w, n, " (freed from the curse)")

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
	if delta >= 0.15 and public_why != "":
		listener.sus_why[target_id] = public_why
		listener.sus_src[target_id] = src  # where the reason came from (a ledger entry id), for citing

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

# ---------------------------------------------------------------- evidence ledger
## Each good NPC keeps a ledger of the evidence and arguments they've taken in, keyed by the
## underlying fact (not by who relayed it, or which card or deduction wrapped it).
## An entry's contribution = its effects x weight x current reliability of its source.
## When weight or reliability changes, only the difference is applied, so suspicion is
## always "social base + what the evidence currently says". Social effects (vibes,
## nominations, grudges, claims) stay as direct adjustments.
##
## Effect = [target, delta, conf_scaled, why, public_why]. Targets: an NPC id (suspicion),
## "pref:protect:<id>", "pref:spare:<id>", "disc:<source>:<night|*>" (doubt in a source's
## readings), "role:<id>:<role>" (believes id holds role).

static func _eff(effs: Array, target: String, delta: float, why: String, public_why: String = "", conf_scaled: bool = true) -> void:
	effs.append([target, delta, conf_scaled, why, public_why])

## A role claim reaches a listener. It becomes a record whose credence (hearing weight x the
## claimant's honesty) is what the listener makes of it. Each record counts against anyone
## else claiming the same gift, so a double claim resolves by comparing credences, and it
## shifts as either claimant's credibility changes. An NPC's knowledge of their own true
## gift is a record too (weight 1.5: they *know* a rival is lying). how: public | relayed |
## own | told.
static func hear_claim(w, l, who: String, role: String, weight: float, how: String, original: Dictionary = {}) -> void:
	if l.is_evil():
		shadow_run(w, l, func(sh): hear_claim(w, sh, who, role, weight, how, original))
		return
	if not C.ROLES.has(role) or C.ROLES[role]["align"] != "good" or not w.by_id.has(who):
		return
	var rn = C.role_name(role)
	var nm: String = w.by_id[who].name
	var effs: Array = []
	if how == "own":
		_eff(effs, "rivals:%s:%s" % [role, who], 0.6, "claimed MY gift (%s); they are lying" % role, "they claimed my own gift, so they're lying", false)
	else:
		_eff(effs, "rivals:%s:%s" % [role, who], 0.6, "%s claims the %s too" % [nm, rn], "they claim a gift %s claims" % nm)
	_eff(effs, "role:%s:%s" % [who, role], 1.0, "%s claims the %s" % [nm, rn], "", false)
	var eid: String = claim_eid(who, role)
	var receipt: Dictionary = original if not original.is_empty() else l.ledger.get(eid, {}).get("meta", {}).get("workshop_card", {})
	if receipt.is_empty():
		receipt = WorkshopLedger.Evidence.normalize_card({"kind": "claim", "source": who, "subject": [who], "role": role, "day": w.day, "phase": w.phase, "text": "%s claims the %s." % [nm, rn]})
	ledger_hear(w, l, eid, effs, weight, [who, -1, "role"], {"kind": "role_claim", "how": how, "role": role, "who": who, "workshop_card": receipt})

static func claim_eid(who: String, role: String) -> String:
	return "claim:%s:%s" % [who, role]

## How much this listener credits who's claim to role (0 = never heard it).
static func claim_credence(n, who: String, role: String) -> float:
	var eid: String = claim_eid(who, role)
	if n.workshop_state.get("owned", {}).has(eid):
		return 0.0 # Shared role testimony owns the claim's evidence weight.
	var e = n.ledger.get(eid)
	return e.get("eff", 0.0) if e != null else 0.0

## How much a night sighting of someone counts (0..1). Being out at night is only damning
## near a death: seen on the block where someone was killed that night counts in full,
## anywhere else very little. Someone who openly claims a gift that walks at night (Night
## Watch, Warden, Lamplighter, Medium) is discounted further, as far as the listener
## believes the claim.
static func night_sighting_scale(w, listener, who: String, block: String, night: int) -> float:
	# Native compatibility and social pressing only. Shared reading/tell owners
	# park these legacy effects; live_activity alone judges their alignment evidence.
	var near_death = false
	for sid in w.scenes:
		if w.scenes[sid]["day"] == night and w.scenes[sid]["block"] == block:
			near_death = true
	var s = 1.0 if near_death else 0.12
	var nn = w.by_id.get(who)
	if nn != null and nn.claim_public and C.ROLES.get(nn.claimed_role, {}).get("night_walk", false):
		var cr = claim_credence(listener, who, nn.claimed_role) if listener != null else 0.5
		s *= 1.0 - 0.7 * clampf(cr, 0.0, 1.0)
	return s

## Who this listener has heard claim each gift: role -> [ids].
static func _claimants(E: Array) -> Dictionary:
	var out = {}
	for e in E:
		if e["meta"].get("kind", "") == "role_claim":
			var r: String = e["meta"]["role"]
			if not out.has(r):
				out[r] = []
			out[r].append(e["meta"]["who"])
	return out

## A "rivals:<role>:<who>" effect lands on everyone else this listener knows claims role.
static func _expand(t: String, claimants: Dictionary) -> Array:
	if not t.begins_with("rivals:"):
		return [t]
	var parts = t.split(":")
	return claimants.get(parts[1], []).filter(func(x): return x != parts[2])

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

## How much this NPC currently credits a claim (1 = fully): doubt about that particular
## reading x the source's honesty. A good NPC never doubts their own honesty, but can
## accept that their own reading was poisoned. Derived values, set by recompute_beliefs.
static func reliability(n, src: String, night: int, kind: String = "reading") -> float:
	if src == "":
		return 1.0
	var r = _night_factor(n.discounted, src, night, kind)
	if src != n.id:
		r *= n.honesty.get(src, 1.0)
	return clampf(r, 0.0, 1.0)

static func night_reliability(n, src: String, night: int) -> float:
	return _night_factor(n.discounted, src, night, "reading")

## Take in a claim, evidence or an argument. Hearing the same thing again only raises its
## weight to the stronger hearing; it never stacks. An argument (meta.supports) keeps each
## distinct justification separately, with its own strength and supports, so a weak
## restatement can't borrow a strong one's weight. Returns {fresh, gain, times}.
static func ledger_hear(w, n, eid: String, effects: Array, weight: float, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	if n.is_evil():
		# The shadow hears it; the real evil mind still takes nothing from it.
		shadow_run(w, n, func(sh): ledger_hear(w, sh, eid, effects, weight, rel, meta))
		return {"fresh": false, "gain": 0.0, "times": 0}
	var fresh = not n.ledger.has(eid)
	if fresh:
		n.ledger[eid] = {"eid": eid, "effects": effects, "weight": 0.0, "rel": rel, "applied": {}, "meta": {}, "day": w.day, "times": 0}
	var e: Dictionary = n.ledger[eid]
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
	recompute_beliefs(w, n, "")
	return {"fresh": fresh, "gain": maxf(0.0, weight - old_w), "times": times}

static func _merge_workshop_roots(old: Dictionary, value: Dictionary) -> Dictionary:
	var result = {"complete": old.get("complete", false) and value.get("complete", false), "receipts": old.get("receipts", {}).duplicate(true)}
	result.receipts.merge(value.get("receipts", {}))
	return result

# Credibility (honesty) tuning: how far evidence of evil discounts what someone says.
const HONESTY_K = Tuning.Mind.HONESTY_K
const HONESTY_CAP = Tuning.Mind.HONESTY_CAP

## Recompute everything the ledger implies, from scratch, from the underlying inputs: each
## entry's original strength, the player's arguments (each justification separately) and
## their supporting evidence. Nothing carries over between calculations, so re-running it
## with no new evidence changes nothing, and beliefs can't feed their own justification.
## Fixed order:
##   1. a first estimate of reading doubt and honesty, from arguments at full strength
##   2. each argument scaled by how credible its supporting evidence is (from step 1)
##   3. final reading doubt, from the scaled arguments
##   4. final honesty, from the evidence against each source under that final doubt
##      (two passes: the second weights each piece of evidence by its giver's honesty)
##   5. every effect applied as a difference from what's applied now
## Steps 3-5 all use the same final doubt, so undoing a poison argument undoes everything
## downstream of it. Only step 2 looks one level back (step 1), by design.
static func recompute_beliefs(w, n, note: String) -> void:
	if w.defer_beliefs:
		if not w.pending_beliefs.any(func(p): return is_same(p[0], n)):
			w.pending_beliefs.append([n, note])
		return
	var span = WorkshopLedgerProfiler.open("belief_refresh")
	_recompute_beliefs(w, n, note)
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
		recompute_beliefs(w, p[0], p[1])
	w.defer_beliefs = was

static func _recompute_beliefs(w, n, note: String) -> void:
	if n.is_evil():
		shadow_run(w, n, func(sh): recompute_beliefs(w, sh, note))
		return
	if w.workshop_refresh.is_valid():
		w.workshop_refresh.call(n, "before")
	var E: Array = n.ledger.values()
	var cl = _claimants(E)
	# Transitional claim credence is finite; a Demon victim can still be lying.
	var kg = func(e) -> float:
		return 1.95 if e["meta"].get("kind", "") == "role_claim" and e["meta"].get("how", "") != "own" and demon_victim(w, e["meta"]["who"]) else 1.0
	var raw = func(e): return e["weight"] * kg.call(e)
	var disc_a = _night_doubt(E, raw, n.workshop_state.get("owned", {}))
	var h_a = {}
	# A Demon victim was good: whatever was said against them, they weren't lying (their
	# readings can still have been wrong, which is reading doubt, not honesty).
	var settled = {}
	for m in w.npcs:
		if not m.alive and demon_victim(w, m.id):
			settled[m.id] = true
	var h_a1 = _honesty(n, E, disc_a, {}, raw, cl, settled)
	h_a = _honesty(n, E, disc_a, h_a1, raw, cl, settled)
	var wf = {}
	for e in E:
		wf[e["eid"]] = _final_weight(n, e, disc_a, h_a) * kg.call(e)
	var final_w = func(e): return wf[e["eid"]]
	var disc = _night_doubt(E, final_w, n.workshop_state.get("owned", {}))
	var h = _honesty(n, E, disc, _honesty(n, E, disc, {}, final_w, cl, settled), final_w, cl, settled)
	# Log notable changes in doubt and honesty (derived values, kept for display).
	for k in disc:
		if absf(disc[k] - n.discounted.get(k, 0.0)) >= 0.05:
			var parts = k.split(":")
			w.dlog.think(n.id, "poison_belief", "Doubt in %s's readings (%s) now %.2f%s." %
				[parts[0], "all nights" if parts[1] == "*" else "night " + parts[1], disc[k], note])
	for s2 in h:
		if absf(h[s2] - n.honesty.get(s2, 1.0)) >= 0.05:
			w.dlog.think(n.id, "credibility", "Credits %s's word at %.0f%% (evidence against them)%s." % [s2, h[s2] * 100.0, note])
	n.discounted = disc
	n.honesty = h
	var conf = 1.4 - 0.8 * trait_of(n, "confidence")
	for e in E:
		var rp = _rel(e)
		var r = reliability(n, rp[0], rp[1], rp[2])
		e["eff"] = wf[e["eid"]] * r  # its current influence, for the debug overlay
		var effs: Array = e["effects"]
		for i in range(effs.size()):
			var f: Array = effs[i]
			if f[0].begins_with("disc:"):
				continue  # derived above
			var want: float = f[1] * (conf if f[2] else 1.0) * wf[e["eid"]] * r
			if n.workshop_state.get("owned", {}).has(e.eid) and WorkshopLedger.ordinary(f[0]):
				want = 0.0
			for t in _expand(f[0], cl):
				var key = i if t == f[0] else "%d:%s" % [i, t]
				var have: float = e["applied"].get(key, 0.0)
				var diff = want - have
				var shared_transition = n.workshop_state.get("owned", {}).has(e.eid) or n.workshop_state.get("previous_owned", {}).has(e.eid)
				if absf(diff) < (0.000000001 if shared_transition else 0.002):
					continue
				e["applied"][key] = want
				_ledger_apply(w, n, [t, f[1], f[2], f[3], f[4]], diff, want, note, e["eid"])
	if w.workshop_refresh.is_valid():
		w.workshop_refresh.call(n, "after")
	w.dlog.capture_npc(n, "belief_recompute" + note)

## An argument's weight = its strongest justification as it stands now (each justification
## scaled by how credible its own supports are). Other entries: their weight.
static func _final_weight(n, e: Dictionary, disc: Dictionary, hon: Dictionary) -> float:
	var js: Array = e.get("justs", [])
	if js.is_empty():
		return e["weight"]
	var best = 0.0
	for jj in js:
		best = maxf(best, jj["weight"] * _support_factor(n, e, jj["supports"], disc, hon))
	return best

static func _night_doubt(E: Array, weight_of: Callable, owned: Dictionary = {}) -> Dictionary:
	var d = {}
	for e in E:
		if owned.has(e.eid) and e.get("meta", {}).get("workshop_conclusion") == "conflict":
			continue # A conflict does not arbitrarily invalidate every night from each source.
		for f in e["effects"]:
			if f[0].begins_with("disc:"):
				var key: String = f[0].substr(5)
				d[key] = minf(d.get(key, 0.0) + f[1] * weight_of.call(e), 0.9)
	return d

## Honesty of each source = 1 - (modest, capped) share of the evidence against them. Evidence
## counts at its weight (weight_of), adjusted by doubt about the particular reading (the
## listener's own readings included) and, in the second pass, by the honesty of whoever gave
## it. Never by suspicion (which includes vibes and grudges), never by its previous value.
static func _honesty(n, E: Array, disc: Dictionary, prev: Dictionary, weight_of: Callable, cl: Dictionary = {}, settled: Dictionary = {}) -> Dictionary:
	var grounds = {}
	for e in E:
		var rp = _rel(e)
		var src: String = rp[0]
		var r = _night_factor(disc, src, rp[1], rp[2])
		if src != "" and src != n.id:
			r *= prev.get(src, 1.0)
		var wgt: float = weight_of.call(e)
		for f in e["effects"]:
			if n.workshop_state.get("owned", {}).has(e.eid) and WorkshopLedger.ordinary(f[0]):
				continue # Joint evidence owns these grounds as well as suspicion.
			for t in _expand(f[0], cl):
				if t.begins_with("disc:") or t.begins_with("pref:") or t.begins_with("role:") or t == src or t == n.id:
					continue
				grounds[t] = grounds.get(t, 0.0) + f[1] * wgt * r
	var out = {}
	for t in grounds:
		if settled.has(t):
			continue  # sincerity settled by their death (see _recompute_beliefs)
		out[t] = 1.0 - clampf(HONESTY_K * maxf(0.0, grounds[t]), 0.0, HONESTY_CAP)
	return out

## How credible one justification's supports still are. Supports the argument itself casts
## doubt on don't count against it. Support = [source, night, kind]; source "" = your own
## observation or physical evidence (fully credible).
static func _support_factor(n, e: Dictionary, sup: Array, disc: Dictionary, hon: Dictionary) -> float:
	if sup.is_empty():
		return 1.0
	var own_doubt = {}
	for f in e["effects"]:
		if f[0].begins_with("disc:"):
			own_doubt[f[0].substr(5)] = true
	var total = 0.0
	var count = 0
	for sp in sup:
		var src: String = sp[0]
		var night: int = sp[1]
		var kind: String = sp[2] if sp.size() > 2 else "reading"
		if kind == "reading" and (own_doubt.has("%s:%d" % [src, night]) or own_doubt.has(src + ":*")):
			continue
		count += 1
		var f2 = _night_factor(disc, src, night, kind)
		if src != "" and src != n.id:
			f2 *= hon.get(src, 1.0)
		total += f2
	return total / count if count > 0 else 1.0

static func _ledger_apply(w, n, f: Array, diff: float, total: float, note: String, eid: String = "") -> void:
	var t: String = f[0]
	if t.begins_with("pref:"):
		var parts = t.split(":")
		var d: Dictionary = n.protect_pref if parts[1] == "protect" else n.spare_pref
		d[parts[2]] = maxf(0.0, d.get(parts[2], 0.0) + diff)
	elif t.begins_with("role:"):
		var parts2 = t.split(":")
		if total >= 0.12:
			n.believed_roles[parts2[1]] = parts2[2]
		elif n.believed_roles.get(parts2[1], "") == parts2[2]:
			n.believed_roles.erase(parts2[1])
	else:
		adjust(w, n, t, diff, f[3] + note, f[4] if diff > 0 else "", false, eid)

## Re-weigh what the player has argued, in light of current trust. Firsthand knowledge and
## the evidence itself don't change; how much the player's word counts does. Confidence
## sets how far they move at once. Called when trust shifts noticeably and before votes.
static func reconsider(w, n, why: String) -> void:
	if n.is_evil():
		shadow_run(w, n, func(sh): reconsider(w, sh, why))
		return
	if absf(n.trust - n.trust_at_reconsider) < 0.03:
		if n.workshop_state.get("enabled", false):
			recompute_beliefs(w, n, " (shared evidence reconsidered: %s)" % why)
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
			var want: float = m["base"] * (0.5 + n.trust)
			if absf(want - cur) < 0.02:
				continue
			nw = cur + (want - cur) * rate
		else:
			nw = 0.0
			for jj in js:
				var wj: float = jj["base"] * (0.5 + n.trust)
				jj["weight"] = jj["weight"] + (wj - jj["weight"]) * rate
				nw = maxf(nw, jj["weight"])
			if absf(nw - cur) < 0.02:
				continue
		e["weight"] = nw
		w.dlog.think(n.id, "reconsider", "Re-weighs '%s': %.2f -> %.2f (trust %.2f, %s)." % [m.get("text", e["eid"]), cur, nw, n.trust, why],
			{"eid": e["eid"], "from": snappedf(cur, 0.01), "to": snappedf(nw, 0.01)})
		var w0: float = m.get("w0", cur)
		if m.get("kind", "") == "arg" and nw >= maxf(w0 * 1.35, w0 + 0.05) and not m.get("remarked", false) and m.get("said", "") != "":
			m["remarked"] = true
			n.remarks.append(m["said"])
	recompute_beliefs(w, n, " (reconsidered: %s)" % why)

## Apply one ability result (own or heard) to a listener's suspicion, through their ledger:
## hearing the same reading again (directly, relayed, at the meeting) never stacks.
static func apply_info(w, listener, source, entry: Dictionary, weight: float, via: String = "", anonymous: bool = false) -> void:
	if weight <= 0.01:
		return
	if listener.is_evil():
		shadow_run(w, listener, func(sh): apply_info(w, sh, source, entry, weight, via, anonymous))
		return
	var receipt = WorkshopLedger.reading(source.id, entry, via)
	var eid = WorkshopLedger.reading_key(receipt)
	var fresh = not listener.ledger.has(eid)
	var effs: Array = _info_effects(w, listener, source, entry, weight, fresh)
	var receipts: Dictionary = listener.ledger.get(eid, {}).get("meta", {}).get("workshop_receipts", {}).duplicate(true)
	if anonymous:
		receipt = WorkshopLedger.reading(source.id, entry, via, true)
	receipt["heard_in_public"] = anonymous or entry.get("shared", false) or receipts.get(receipt.id, {}).get("heard_in_public", false)
	var paths: Array = receipts.get(receipt.id, {}).get("provenance_paths", []).duplicate(true)
	if (via != "" or anonymous or not paths.is_empty()) and receipt.provenance not in paths:
		paths.append(receipt.provenance.duplicate(true))
	receipt.provenance_paths = paths
	receipts[receipt.id] = receipt
	ledger_hear(w, listener, eid, effs, weight, [source.id, entry["day"], "reading"], {"kind": "reading", "workshop_receipts": receipts})

static func info_eid(src: String, entry: Dictionary) -> String:
	return WorkshopLedger.reading_key(WorkshopLedger.reading(src, entry))

## The suspicion effects of one reading, at weight 1 (side effects only on first hearing).
static func _info_effects(w, listener, source, entry: Dictionary, weight: float, fresh: bool) -> Array:
	var effs: Array = []
	var d: Dictionary = entry["data"]
	var r: String = entry["role"]
	var rdef = C.role_def(r)
	if rdef != null:
		return rdef.info_effects(w, listener, source, entry, weight, fresh, _mind())
	return effs

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
	return 0.5

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
	var parts = {"trust": (n.trust - 0.5) * 2.0, "base": 0.2}
	var rdef = C.role_def(role)
	if rdef != null:
		rdef.score_gift_request(w, n, targets, top, parts, _mind())
	var named: String = _request_target_text(w, role, targets)
	var yes: bool = decide(w, n, "gift_request", parts, "Use the %s tonight as the Demonologist asks (%s)?" % [C.role_name(role), named])
	if yes:
		n.gift_request = {"night": w.day, "role": role, "targets": targets.duplicate()}
		w.dlog.add("gift_request_agreed", "player", n.id, {"role": role, "targets": targets})
		var agree_tpl: String = rdef.request_agree_line if rdef != null and rdef.request_agree_line != "" else ""
		return {"lines": [say(n, agree_tpl % named)], "facts": [], "agreed": true}
	w.dlog.add("gift_request_refused", "player", n.id, {"role": role, "targets": targets})
	var counter: String = ""
	if n.trust >= 0.35 and top != "" and not (top in targets) and rdef != null:
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

static func reading_strength(e: Dictionary, t_id: String) -> float:
	return MindMeeting.reading_strength(e, t_id)

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

static func defend_self(w, d, nominator_id: String) -> Dictionary:
	return MindMeeting.defend_self(w, d, nominator_id)

static func defence_line(w, n) -> Dictionary:
	return MindMeeting.defence_line(w, n)

static func vote(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int) -> bool:
	return MindMeeting.vote(w, v, nominee, nominator, player_yes, statement, yes_so_far)

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

static func answer_gift(w, n, force_tier: int = 0) -> Dictionary:
	return MindDialogue.answer_gift(w, n, force_tier)

static func _answer_gift_impl(w, n, force_tier: int, trace_id: int) -> Dictionary:
	return MindDialogue._answer_gift_impl(w, n, force_tier, trace_id)

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

static func _observation_lines(n, groups: Array, audience: String, speech_act: String, preceded: bool) -> Array:
	return MindDialogue._observation_lines(n, groups, audience, speech_act, preceded)

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

## How incriminating a board card is on its own (0..1.4), before credibility and trust.
static func card_strength(w, card: Dictionary, suspect) -> float:
	if WorkshopLedger.Evidence.contains_opinion(card) or WorkshopLedger.Evidence.social_reading(card):
		return 0.0
	match card.get("kind", ""):
		"sighting":
			if card.get("phase", -1) != C.NIGHT:
				return 0.15
			return 1.4 * night_sighting_scale(w, null, suspect.id, card.get("block", ""), card.get("day", -1))
		"info":
			var d: Dictionary = card.get("data", {})
			var rdef = C.role_def(card.get("role", ""))
			if rdef != null:
				return rdef.card_strength(d, suspect.id)
			if suspect.id in Gifts.implicated(card):
				return 0.6
			return 0.0
		"trace":
			return 0.7
		"home", "work", "haunt", "trait", "bond":
			return 0.0
		"refusal":
			# Fear is a better reason than none: it softens, but doesn't clear, the silence.
			return 0.25 if card.get("fear", false) else 0.35
		"secret":
			return 0.5
		"claim":
			var role: String = card.get("role", "")
			if role == "" or role == "none":
				return 0.1
			for pc in w.public_claims:
				if pc["role"] == role and pc["who"] != suspect.id:
					return 1.0
			return 0.1
	return 0.2

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
## How much the listener takes your word on a card: 0.5 + their trust in you, unless it's
## something you saw that a witness they believe saw too, in which case the witness carries
## it ("Dorian saw it as well").
static func word_factor(w, n, card: Dictionary) -> float:
	var f = 0.5 + n.trust
	if card.get("source", "") != "player":
		return f
	for c in card.get("corroborated_by", []):
		if c == n.id:
			return maxf(f, 1.4)
		if w.by_id.has(c):
			f = maxf(f, 0.5 + clampf(0.9 - susp(n, c), 0.1, 0.9))
	return f

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

## How strongly a card speaks *for* someone (used when defending a nominee).
static func defend_strength(card: Dictionary, nominee: String) -> float:
	if WorkshopLedger.Evidence.contains_opinion(card) or WorkshopLedger.Evidence.social_reading(card):
		return 0.0
	var subj: Array = card.get("subject", [])
	if not (nominee in subj):
		return 0.1
	var d: Dictionary = card.get("data", {})
	match card.get("kind", ""):
		"deduction":
			var conclusion: Dictionary = card.get("conclusion", {})
			if conclusion.get("a", "") == nominee and not card.get("unfounded", false):
				if conclusion.get("type", "") in ["good", "notdemon", "truthful", "spare", "protect", "secret", "marked", "red_herring"]:
					return 0.3
				if conclusion.get("type", "") == "role" and C.ROLES.get(conclusion.get("role", ""), {}).get("align", "") == "good":
					return 0.2
		"info":
			var rdef = C.role_def(card.get("role", ""))
			if rdef != null:
				return rdef.defend_strength(d, nominee)
			if nominee in Gifts.clears(card):
				return 0.5
		"claim":
			return 0.2
		"death":
			return 1.0
		"vigil":
			return 0.4
		"secret":
			return 0.4
	return 0.15

## The player's case: "tell <n>: <suspect> is suspicious because <card>".
static func hear_accusation(w, n, suspect, card: Dictionary) -> Dictionary:
	on_question(w, n)
	if not n.is_shadow:
		_secret_used(w, card)
	var lines: Array = []
	var cw = card_weight(w, n, suspect, card)
	var strength = card_strength(w, card, suspect)
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
	# Already knowing the fact itself (heard the reading, saw it) leaves less to add.
	var known = 0.35 if n.ledger.has(cw["key"]) else 1.0
	var base: float = 0.35 * cw["cred"] * relevance * cw["class_w"] * known
	var bond: float = n.npc_trust.get(suspect.id, 0.5)
	if bond > 0.6:
		base *= 1.0 - (bond - 0.5) * 1.4
		if times == 0:
			set_trust(w, n, n.trust - 0.12 * (bond - 0.5) * 2.0, "player accused %s, whom I trust" % suspect.id)
	var old = susp(n, suspect.id)
	var why = "player accusation using card '%s' (class %s x%.2f, cred %.2f: %s, relevance %.2f, already known x%.2f)" % [cw["key"], cls, cw["class_w"], cw["cred"], cw["cred_why"], relevance, known]
	var effs: Array = []
	_eff(effs, suspect.id, 1.0, why, "the Demonologist made a case against them")
	var h = ledger_hear(w, n, "tell:%s>%s" % [cw["key"], suspect.id], effs, base * word_factor(w, n, card), cw["rel"],
		_tell_meta(card, base))
	n.used_facts[cw["key"] + ">" + suspect.id] = true
	var delta: float = h["gain"]
	var nv = susp(n, suspect.id)
	w.dlog.think(n.id, "persuaded", "Accusation moved suspicion of %s from %.2f to %.2f." % [suspect.id, old, nv])
	if times > 0:
		lines.append(say(n, "[PH] You've told me that already."))
	elif suspect == n:
		lines.append(say(n, "[PH] Me? That's madness."))
	elif strength < 0.3 and suspect.id in cw["subj"]:
		lines.append(say(n, "[PH] That proves nothing against %s." % suspect.name))
	elif relevance < 0.3:
		lines.append(say(n, "[PH] I don't see what that has to do with %s." % suspect.name))
	elif bond > 0.65 and delta < 0.1:
		var friendship = say(n, "[PH] %s is my friend. You'll need more than that." % suspect.name)
		friendship["relationship"] = {"kind": "friend", "people": [n.id, suspect.id]}
		lines.append(friendship)
	elif cls == "speech" and ins >= 0.67 and delta < 0.1:
		lines.append(say(n, "[PH] That's only talk. Show me something real."))
	elif nv >= 0.8:
		lines.append(say(n, "[PH] You're right. I'll not trust %s again." % suspect.name))
	elif delta >= 0.15:
		lines.append(say(n, "[PH] That... does look bad for %s." % suspect.name))
	else:
		lines.append(say(n, "[PH] Maybe. I'll keep an eye on %s." % suspect.name))
	if old >= 0.5 and times == 0:
		set_trust(w, n, n.trust + 0.05 * (1.0 - 0.5 * ins), "the Demonologist agrees with me about %s" % suspect.id)
	elif delta >= 0.1:
		set_trust(w, n, n.trust + 0.02, "player made a case that seemed sound")
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
		if n.is_evil() and C.SHADOW_SELF and n.workshop_state.get("enabled", false):
			var own_defence = shadow_eval(w, n, func(sh): return hear_defence(w, sh, whos, card))
			shared_self = own_defence != null and own_defence.get("workshop", false)
		var key = "support_self:" + fact_id(card)
		var repeated: bool = n.heard.has(key)
		n.heard[key] = n.heard.get(key, 0) + 1
		if repeated:
			lines.append(say(n, "[PH] You've told me that already. Thank you."))
		elif defend_strength(card, n.id) >= 0.2:
			set_trust(w, n, n.trust + 0.03, "the Demonologist spoke up for me")
			lines.append(say(n, "[PH] Thank you for believing me."))
		else:
			lines.append(say(n, "[PH] I appreciate the support, but I'm not sure that explains it."))
		return {"lines": lines, "facts": [], "repeated": repeated, "workshop": shared_self}
	if n.is_evil():
		var r = w.rng.randf()
		w.observe_decision(n, "defence_reply", r < (0.6 if who.is_evil() else 0.7), {"probability": 0.6 if who.is_evil() else 0.7, "draw": r, "comparison": "<", "inputs": {}}, who.id)
		if who.is_evil():
			lines.append(say(n, "[PH] Fair enough. I'll think better of %s." % who.name if r < 0.6 else "[PH] Maybe. I'll keep an open mind about %s." % who.name))
		else:
			lines.append(say(n, "[PH] Maybe. I'll keep an open mind about %s." % who.name if r < 0.7 else "[PH] That doesn't clear %s." % who.name))
		var dr = shadow_eval(w, n, func(sh): return hear_defence(w, sh, whos, card)) if C.SHADOW_SELF and (not (n in group) or n.workshop_state.get("enabled", false)) else null
		if dr != null:
			# Evil would rather a good person stay suspect: worth more if they're a threat.
			var threats = group.filter(func(x): return not x.is_evil())
			var stakes = 0.0
			for x in threats:
				stakes += 0.3 + (0.3 if Evil.intel_threat(n, x.id) > 0.0 else 0.0)
			if threats.is_empty() or not evil_override(w, n, "private defence", stakes, 0.5, "the Demonologist speaking for %s" % gname):
				return dr
		return {"lines": lines, "facts": [], "workshop": dr != null and dr.get("workshop", false)}
	var h = {"times": 0, "gain": 0.0}
	var strength = 0.0
	for x in group:
		var cw = card_weight(w, n, x, card)
		var st = defend_strength(card, x.id)
		strength = maxf(strength, st)
		var base: float = 0.3 * cw["cred"] * cw["class_w"] * st * (0.35 if n.ledger.has(cw["key"]) else 1.0) / group.size()
		var effs: Array = []
		_eff(effs, x.id, -1.0, "the Demonologist spoke for them, citing '%s'" % cw["key"])
		var hx = ledger_hear(w, n, "for:%s>%s" % [cw["key"], x.id], effs, base * (0.5 + n.trust), cw["rel"], _tell_meta(card, base))
		h["times"] = maxi(h["times"], hx["times"])
		h["gain"] += hx["gain"]
	if h["times"] > 0:
		lines.append(say(n, "[PH] You've told me that already."))
	elif strength < 0.2:
		lines.append(say(n, "[PH] That doesn't clear %s." % gname))
	elif h["gain"] >= 0.12:
		lines.append(say(n, "[PH] Fair enough. I'll think better of %s." % gname))
	else:
		lines.append(say(n, "[PH] Maybe. I'll keep an open mind about %s." % gname))
	return {"lines": lines, "facts": [], "repeated": h["times"] > 0}

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
		lines.append(say(n, "[PH] Maybe. I'll keep an eye on them both." if w.decision_roll(n, "group_defence_reply", 0.6) else "[PH] That... does look bad for one of them."))
		var gr = shadow_eval(w, n, func(sh): return hear_group_case(w, sh, group, card)) if C.SHADOW_SELF and (not (n in group) or n.workshop_state.get("enabled", false)) else null
		if gr != null:
			var mates = group.filter(func(x): return Evil.is_teammate(w, n, x.id))
			var stakes = 0.0
			for x in mates:
				stakes += 0.5 * Evil.teammate_value(w, x.id) * (0.3 + Evil.public_heat(w, x))
			if mates.is_empty() or not evil_override(w, n, "private group case", stakes, 0.5, "a case against %s" % gname):
				return gr
		return {"lines": lines, "facts": [], "workshop": gr != null and gr.get("workshop", false)}
	var gain = 0.0
	var times = 0
	if w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(n, card, group.map(func(p): return p.id), "accuse", "private", true)
		if not interpreted.is_empty():
			return interpreted
	for x in group:
		var cw = card_weight(w, n, x, card)
		var known = 0.35 if n.ledger.has(cw["key"]) else 1.0
		var base: float = 0.35 * cw["cred"] * card_strength(w, card, x) * cw["class_w"] * known / group.size()
		var effs: Array = []
		_eff(effs, x.id, 1.0, "player's case that one of %s is guilty, citing '%s'" % [gname, cw["key"]], "the Demonologist made a case against them")
		var h = ledger_hear(w, n, "tell:%s>%s" % [cw["key"], x.id], effs, base * (0.5 + n.trust), cw["rel"], _tell_meta(card, base))
		n.used_facts[cw["key"] + ">" + x.id] = true
		gain += h["gain"]
		times = maxi(times, h["times"])
	if times > 0:
		lines.append(say(n, "[PH] You've told me that already."))
	elif gain >= 0.12:
		lines.append(say(n, "[PH] That... does look bad for one of them."))
	else:
		lines.append(say(n, "[PH] Maybe. I'll keep an eye on them both."))
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
	if w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(v, card, [nominee.id], direction, "nomination", false)
		if not interpreted.is_empty():
			return
	var known = 0.35 if v.ledger.has(cw["key"]) else 1.0
	var base: float = 0.25 * cw["cred"] * cw["class_w"] * known
	var sign = 1.0
	if direction == "accuse":
		base *= cw["relevance"] * card_strength(w, card, nominee)
	else:
		base *= defend_strength(card, nominee.id)
		sign = -1.0
	var effs: Array = []
	_eff(effs, nominee.id, sign, "the Demonologist's public %s using card '%s' (class %s, cred %.2f, already known x%.2f)" %
		[direction, cw["key"], cw["cls"], cw["cred"], known], "the Demonologist made a case against them" if direction == "accuse" else "")
	ledger_hear(w, v, "pub:%s:%s>%s" % [direction, cw["key"], nominee.id], effs, base * word_factor(w, v, card), cw["rel"],
		_tell_meta(card, base, true))
	if direction == "accuse":
		v.used_facts[cw["key"] + ">" + nominee.id] = true

static func _tell_meta(card: Dictionary, base: float, public: bool = false) -> Dictionary:
	return {"kind": "tell", "base": base, "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": public}

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
	if not night_seen.is_empty() and trait_of(speaker, "gossip") >= 0.2:
		var b: Dictionary = night_seen[night_seen.size() - 1]
		var who = w.by_id[b["who"]]
		speaker.told_to["player|saw:%s:%d" % [b["who"], b["day"]]] = true
		w.dlog.think(speaker.id, "gossip", "Shares a true night sighting of %s." % who.id)
		return {"lines": ["You overhear %s telling the room that %s was out on %s on night %d." %
			[speaker.name, who.name, C.block_name(b["block"]), b["day"]]],
			"facts": [{"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": C.NIGHT, "source": speaker.id,
				"text": "Gossip from %s: %s was out on %s on night %d." % [speaker.name, who.name, C.block_name(b["block"]), b["day"]]}]}
	var ranked = ranked_suspects(w, speaker)
	if not ranked.is_empty() and susp(speaker, ranked[0].id) >= 0.4 and not speaker.told_to.has("player|gossip_susp:%s:%d" % [ranked[0].id, w.day]):
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
