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

const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Dialogue = preload("res://sim/dialogue.gd")

# ---------------------------------------------------------------- utilities

static func say(n, text: String) -> Dictionary:
	return {"speaker": n.id, "name": n.name, "text": text}

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

## Keep every fact and narration intact; only the first spoken response is rephrased.
static func _challenged(n, response: Dictionary, card: Dictionary) -> Dictionary:
	for i in range(response["lines"].size()):
		var line = response["lines"][i]
		if line is Dictionary and line.get("speaker", "") == n.id:
			response["lines"][i] = voiced(n, "doubted", line["text"], fact_id(card), {"challenged": true})
			break
	return response

static func trait_of(n, t: String) -> float:
	return n.traits.get(t, 0.5)

## Effective paranoia (rises with the dead; composure dampens).
static func paranoia(w, n) -> float:
	var dead = w.npcs.filter(func(m): return not m.alive).size()
	return 0.07 * dead * (1.0 - 0.6 * trait_of(n, "composure"))

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
	var p = sigmoid(total * 4.0)
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
	if old - n.trust >= 0.03 and not why.begins_with("apology"):
		_record_grievance(w, n, old - n.trust, why)
	if absf(n.trust - n.trust_at_reconsider) >= 0.1:
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

const SERIOUS_GRIEVANCE = 0.12

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
	var share: float = 0.25 if g["serious"] else 0.5
	var ins: float = trait_of(n, "insight")
	if g["evidence"]:
		share *= 1.0 - clampf((ins - 0.4) * 1.2, 0.0, 0.6)
	var repair: float = g["drop"] * share
	w.dlog.decision(n.id, "apology", "outcome", snappedf(repair, 0.01), {"incident": g["why"],
		"drop": snappedf(g["drop"], 0.01), "serious": g["serious"], "evidence": g["evidence"],
		"insight": ins, "share": snappedf(share, 0.01)})
	set_trust(w, n, n.trust + repair, "apology: " + g["why"])
	var line: String
	if repair >= 0.05:
		line = "Well. I appreciate you saying so."
	elif g["evidence"] and ins >= 0.6:
		line = "Sorry for it, are you? You'd do the same again, I think."
	else:
		line = "Hm. Words are cheap, but I heard you."
	return {"lines": [say(n, line)], "facts": []}

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
	lines.append(say(n, ("I don't trust you. " + action) if action != "" else "You're an outsider, I'm not sure I can trust you."))

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
			var bonus = 0.03 + 0.04 * trait_of(n, "privacy")
			if n.secret_spread_by_npc:
				bonus *= 0.4
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
		"cost": cost, "caution": caution, "score": stakes - cost, "comparison": ">"})
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
		delta *= 1.4 - 0.8 * trait_of(listener, "confidence")
	var old: float = listener.suspicion[target_id]
	var nv = old + delta
	if listener.workshop_state.get("active", false):
		var state: Dictionary = listener.workshop_state
		var outside: float = state.outside.get(target_id, old)
		outside += delta
		state.outside[target_id] = outside
		nv = outside + state.requested.get(target_id, 0.0)
		state.applied[target_id] = nv - outside
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
	return clampf(n.suspicion.get(target_id, 0.0), 0.0, 1.5)

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
		"trace":
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
const HONESTY_K = 0.8
const HONESTY_CAP = 0.5

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
	var rate = 1.0 - 0.6 * trait_of(n, "confidence")
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
	var own = source == listener
	var src_name: String = "my own" if own else source.name + "'s"
	var src_bare: String = "I" if own else source.name
	var tag = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	match r:
		"hearthwitch", "dowser":
			var nbrs: Array = Gifts.group_of(d)
			var count: int = d["count"]
			var others: Array = nbrs.filter(func(i): return i != listener.id)
			var excluded = nbrs.size() - others.size()
			if count == 0:
				for i in others:
					_eff(effs, i, -0.25, tag + ": hearthwitch count 0", "", not own)
			else:
				var per = 0.35 * count
				if excluded > 0:
					per = 0.7 * count
				if count > others.size() and not own:
					_eff(effs, source.id, 0.5, tag + ": hearthwitch count impossible from my view",
						"%s reading about the lane can't be right" % src_name)
				for i in others:
					_eff(effs, i, per, tag + ": %s count %d" % [r, count],
						"%s reading pointed at %s" % [src_name, "their neighbours" if r == "hearthwitch" else "that crowd"], not own)
		"seer":
			var pair: Array = d["pair"]
			var others: Array = pair.filter(func(i): return i != listener.id)
			if d["yes"]:
				var per = 0.45 if others.size() > 1 else 0.85
				for i in others:
					_eff(effs, i, per, tag + ": seer yes",
						"%s sight said one of them is the demon" % src_name, not own)
			else:
				for i in others:
					_eff(effs, i, (-0.45 if own else -0.3), tag + ": seer no", "", not own)
					if own and fresh:
						listener.cleared[i] = true
		"nightwatch":
			var seen: Array = d["seen"]
			for i in seen:
				if i == listener.id:
					var where: String = listener.history.get(w.time_key(entry["day"], C.NIGHT), "")
					if where.begins_with("home") and not own:
						_eff(effs, source.id, 0.45, tag + ": claims to have seen me out, but I was home",
							"%s claims to have seen me out at night, which is a lie" % src_bare)
					continue
				var sc = night_sighting_scale(w, listener, i, d["block"], entry["day"])
				_eff(effs, i, 0.5 * sc, tag + ": seen out at night (x%.2f: %s)" % [sc, "near a death" if sc >= 0.99 else "nowhere near a death" if sc > 0.1 else "discounted"],
					"%s saw them out at night%s" % [src_bare, " where someone was killed" if sc >= 0.5 else ""], not own)
		"archivist":
			var pair: Array = d["pair"]
			var others: Array = pair.filter(func(i): return i != listener.id)
			var per = 0.35 if others.size() > 1 else 0.75
			for i in others:
				_eff(effs, i, per, tag + ": archivist pair",
					"%s records tie them to the %s" % [src_name, C.role_name(d.get("role", "poisoner"))], not own)
		"rumormonger":
			# Secret-holders are good, so "one of these two carries a secret" speaks for both a little.
			for i in d["pair"]:
				if i != listener.id:
					_eff(effs, i, -0.12, tag + ": rumormonger pair probably good", "", not own)
		"martyr":
			if d.get("chosen", false) and d["target"] != listener.id:
				_eff(effs, d["target"], -0.2, tag + ": the Martyr would die for them", "", not own)
			elif d.get("evil", false) and d["target"] != listener.id:
				_eff(effs, d["target"], 1.0, tag + ": hanged and the Martyr lived: evil", "", false)
		"veteran":
			# The demon came by way of that block: a little toward those who live there.
			for m in w.living():
				if m != listener and m != source and m.home_block == d.get("block", ""):
					_eff(effs, m.id, 0.12, tag + ": the demon came by way of their block",
						"the demon came by way of %s, where they live" % C.block_name(d["block"]), not own)
		"psychologist":
			pass # Accurate knowledge of an opinion does not make it alignment evidence.
		"medium":
			# What the dead knew, at a remove: weaker than hearing it from them.
			var it: Dictionary = d.get("item", {})
			var dead: String = d.get("dead", "")
			match it.get("type", ""):
				"reading":
					var inner: Dictionary = it["entry"]
					var dn = w.by_id.get(dead)
					if dn != null:
						for ef in _info_effects(w, listener, dn, inner, weight, false):
							ef[1] = ef[1] * 0.6
							effs.append(ef)
				"sighting":
					if it["who"] != listener.id:
						var sc2 = night_sighting_scale(w, listener, it["who"], it.get("block", ""), it.get("night", -1))
						_eff(effs, it["who"], 0.3 * sc2, tag + ": the dead %s saw them out at night (x%.2f)" % [dead, sc2],
							"the dead saw them out at night", not own)
				"suspicion":
					pass # A faithfully relayed opinion remains an opinion (Q4).
		"clerk":
			var pair: Array = d["pair"]
			if listener.id in pair and d["role"] == listener.role and not own:
				_eff(effs, source.id, -0.3, tag + ": clerk correctly named my role")
			for i in pair:
				if i != listener.id:
					_eff(effs, i, -0.15, tag + ": clerk pair probably good", "", not own)
		"gravedigger":
			var ex = w.by_id[d["executed"]]
			var ex_good: bool = C.ROLES[d["role"]]["align"] == "good"
			if ex.id != listener.id:
				# "X was evil" (or good) is evidence about X like any other; X's credibility
				# follows from it in recompute_beliefs, not from a role-specific rule.
				_eff(effs, ex.id, 1.0 if not ex_good else -0.4, tag + ": %s was the %s" % [ex.id, d["role"]], "", false)
			for e in w.executions:
				if e["id"] == ex.id:
					var nom: String = e["nominator"]
					if nom != "" and nom != "player":
						_eff(effs, nom, (0.25 if ex_good else -0.2),
							tag + ": nominator of %s, who was %s" % [ex.id, d["role"]],
							"they pushed to hang %s, who was innocent" % ex.name)
					if fresh and not own and weight > 0.2 and (e["player_nominated"] or e["player_yes"]):
						if ex_good:
							set_trust(w, listener, listener.trust - 0.06, "the Demonologist backed hanging %s, an innocent" % ex.id)
						else:
							set_trust(w, listener, listener.trust + 0.08 + 0.06 * trait_of(listener, "insight"),
								"the Demonologist was proven right about %s" % ex.id)
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
	var ranked = ranked_suspects(w, n)
	var asked: Array = requested_targets(w, n, "seer")
	if not asked.is_empty():
		var pair: Array = asked.slice(0, 2)
		if pair.size() < 2:
			var rest: Array = ranked.filter(func(m): return not (m.id in pair))
			if not rest.is_empty():
				pair.append(rest[0].id)
		w.dlog.think(n.id, "seer_pick", "Seer: looks where the Demonologist asked.", {"pair": pair, "requested": asked})
		return pair
	var ins = trait_of(n, "insight")
	var pair: Array = []
	var why = ""
	var checked = {}
	var yes_on = {}
	for e in n.info_log:
		if e.get("role", "") == "seer":
			for pid in e["data"]["pair"]:
				checked[pid] = true
				if e["data"]["yes"]:
					yes_on[pid] = yes_on.get(pid, 0) + 1
	var fresh: Array = ranked.filter(func(m): return not checked.has(m.id))
	if w.day == 0 or ranked.size() < 3:
		pair = w.shuffled(ranked).slice(0, 2)
		why = "first look: two at random"
	elif w.rng.randf() >= 0.3 + 0.5 * ins:
		pair = w.shuffled(ranked).slice(0, 2)
		why = "a scattered look (insight %.2f): two at random" % ins
	elif ins >= 0.6 and yes_on.get(ranked[0].id, 0) >= 2 and fresh.size() >= 2:
		pair = w.shuffled(fresh).slice(0, 2)
		why = "settled on %s (two yeses); looks at two fresh people" % ranked[0].id
	else:
		var others: Array = ranked.slice(1)
		if ins >= 0.6:
			var fr: Array = others.filter(func(m): return not checked.has(m.id))
			if not fr.is_empty():
				others = fr
		pair = [ranked[0], w.pick(others)]
		why = "top suspect plus %s (insight %.2f)" % ["someone unchecked" if ins >= 0.6 else "one other", ins]
	var ids: Array = pair.map(func(m): return m.id)
	w.dlog.think(n.id, "seer_pick", "Seer: " + why + ".", {"pair": ids})
	return ids

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
	match role:
		"seer":
			if top in targets:
				parts["already_wondering"] = 0.3
			for t in targets:
				if n.npc_trust.get(t, 0.5) >= 0.7:
					parts["doubting_a_friend"] = -0.25
			var checked = {}
			for e in n.info_log:
				if e.get("role", "") == "seer":
					for pid in e["data"]["pair"]:
						checked[pid] = true
			if targets.all(func(t): return checked.has(t)):
				parts["already_looked"] = -0.3
		"warden":
			var t: String = targets[0]
			parts["cares_for_them"] = (n.npc_trust.get(t, 0.5) - 0.5) * 1.0
			parts["suspects_them"] = -susp(n, t) * 1.0
		"nightwatch":
			if top != "" and w.by_id[top].home_block == targets[0]:
				parts["already_wondering"] = 0.3
	var named: String = _request_target_text(w, role, targets)
	var yes: bool = decide(w, n, "gift_request", parts, "Use the %s tonight as the Demonologist asks (%s)?" % [C.role_name(role), named])
	if yes:
		n.gift_request = {"night": w.day, "role": role, "targets": targets.duplicate()}
		w.dlog.add("gift_request_agreed", "player", n.id, {"role": role, "targets": targets})
		var lines = {"seer": "All right. Tonight I'll look at %s.", "warden": "Very well. I'll stand at %s's door tonight.",
			"nightwatch": "I'll keep my watch over %s tonight, then."}
		return {"lines": [say(n, lines[role] % named)], "facts": [], "agreed": true}
	w.dlog.add("gift_request_refused", "player", n.id, {"role": role, "targets": targets})
	var counter: String = ""
	if n.trust >= 0.35 and top != "" and not (top in targets):
		match role:
			"seer":
				counter = "I'd sooner look at %s." % w.by_id[top].name
			"nightwatch":
				if w.by_id[top].home_block != targets[0]:
					counter = "I'd sooner watch %s." % C.block_name(w.by_id[top].home_block)
	if counter != "":
		return {"lines": [say(n, "No. " + counter)], "facts": [], "agreed": false}
	return {"lines": [say(n, "My gift's mine to use as I see fit.")], "facts": [], "agreed": false}

static func _request_target_text(w, role: String, targets: Array) -> String:
	if role == "nightwatch":
		return C.block_name(targets[0])
	return " and ".join(PackedStringArray(targets.map(func(t): return w.by_id[t].name)))

static func watch_block(w, n) -> String:
	var asked: Array = requested_targets(w, n, "nightwatch")
	if not asked.is_empty():
		w.dlog.think(n.id, "watch_pick", "Night Watch watches the block the Demonologist asked for.", {"block": asked[0]})
		return asked[0]
	var ranked = ranked_suspects(w, n)
	var b = ""
	if w.day == 0 or ranked.is_empty():
		b = w.pick(C.BLOCKS.keys())
	else:
		b = ranked[0].home_block
	w.dlog.think(n.id, "watch_pick", "Night Watch watches the block of their top suspect's home.", {"block": b})
	return b

static func warden_target(w, n) -> String:
	var asked: Array = requested_targets(w, n, "warden")
	if not asked.is_empty() and w.by_id[asked[0]].alive:
		w.dlog.think(n.id, "warden_pick", "Guards whom the Demonologist asked.", {"pick": asked[0]})
		return asked[0]
	var best = ""
	var best_s = -99.0
	var scores = {}
	for m in w.living():
		if m == n:
			continue
		var s: float = w.rng.randf() * 0.3
		if m.claim_public and m.claimed_role in C.INFO_ROLES:
			s += 1.0 - susp(n, m.id)
		s += (n.npc_trust.get(m.id, 0.5) - 0.5) * 0.8
		s -= susp(n, m.id) * 0.5
		s += n.protect_pref.get(m.id, 0.0) * 1.2
		scores[m.id] = snappedf(s, 0.01)
		if s > best_s:
			best_s = s
			best = m.id
	w.dlog.think(n.id, "warden_pick", "Protects whoever scores highest (trusted info claimants, trusted people).", {"scores": scores, "pick": best})
	return best

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
			continue  # the Breathstealer took their voice
		var lines: Array = []
		var facts: Array = []
		flush_beliefs(w, n)  # a speaker reacts to everything said before their turn
		if not n.claim_public and _public_claim_decision(w, n) != "":
			_go_public(w, n, lines, facts)
		elif n.claim_public:
			_go_public(w, n, lines, facts)  # already out: share any new readings
		var acc = _public_accusation(w, n, lines, facts)
		if acc != null:
			lines.append(acc["line"])
			facts.append(acc["fact"])
		return {"who": n.id, "lines": lines, "facts": facts}
	# Everyone has spoken: the remaining refreshes, one mind per step, in queue order.
	if not w.pending_beliefs.is_empty():
		flush_beliefs(w, w.pending_beliefs[0][0])
	if w.pending_beliefs.is_empty():
		w.defer_beliefs = false
		st["done"] = true
	return {}

static func _public_claim_decision(w, n) -> String:
	var role: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var kind: String = C.ROLES[role]["kind"]
	var parts = {
		"openness": (0.5 - trait_of(n, "privacy")) * 1.2,
		"day": 0.3 * (w.day - 1),
		"pressure": n.pressure * 0.8 * (1.0 - 0.5 * trait_of(n, "composure")),
		"base": -0.35,
	}
	if kind != "info":
		parts["hides_from_demon"] = -0.5
	# Gifts that pay off night after night are worth protecting early; one-shot first-night
	# gifts have less to lose by coming out.
	if role in ["seer", "hearthwitch", "nightwatch", "lamplighter", "medium", "psychologist", "dowser"] and w.day <= 2:
		parts["gift_keeps_giving"] = -0.4
	elif role in C.START_ROLES:
		parts["one_shot_gift"] = 0.3
	elif role == "martyr" and not n.is_evil() and n.martyr_target != "":
		parts["martyr_chosen"] = 0.4  # coming out as the Martyr protects their choice by deterrence
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
	return say(n, "%sI am the %s." % [openers.get(n.style, ""), C.role_name(role)])

## Construct the exact public-facing report before a presentation layer touches it.
static func _info_intent(w, n, e: Dictionary) -> Dictionary:
	var when = "The night before you arrived" if e["day"] == 0 else "Last night" if e["day"] == w.day - 1 else "On night %d" % e["day"]
	if e.has("phase"):
		when = ("This " + C.PHASES[e["phase"]].to_lower()) if e["day"] == w.day else "On day %d, in the %s" % [e["day"], C.PHASES[e["phase"]].to_lower()]
	return {"kind": "report", "statement": "%s, %s." % [when, e["text"]], "event_id": info_eid(n.id, e)}

static func info_line(w, n, e: Dictionary, audience: String = "player") -> Dictionary:
	var approved = _info_intent(w, n, e)
	return voiced(n, "report", approved["statement"], approved["event_id"], {"audience": audience})

## A batch of readings is one uninterrupted speech turn. Each report remains an
## independent line and fact; only its introduction/connective is turn-aware.
static func info_lines(w, n, entries: Array, audience: String = "player", preceded: bool = false) -> Array:
	var approved: Array = []
	for e in entries:
		approved.append(_info_intent(w, n, e))
	var rendered: Array = Dialogue.compose_turn(n.id, approved,
		{"audience": audience, "trust": n.trust, "pressure": n.pressure}, n.dialogue_memory, preceded)
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
	match e.get("role", ""):
		"seer":
			return 0.9 if d.get("yes", false) else 0.0
		"martyr":
			return 0.9 if d.get("evil", false) else 0.0
		"dowser", "hearthwitch":
			var g: Array = Gifts.group_of(d)
			return clampf(0.9 * d.get("count", 0) / maxf(1.0, g.size()), 0.0, 0.8) if t_id in g else 0.0
		"archivist":
			var r: String = d.get("role", "")
			return (0.6 if r == "demon" else 0.4) if C.ROLES.get(r, {}).get("align", "good") == "evil" else 0.15
		"nightwatch":
			return 0.35
		"medium":
			return 0.5
	return 0.3

## Evil: an unshared fake reading of theirs that points at t, or {}.
static func _unshared_fake_on(n, t_id: String) -> Dictionary:
	for e in n.info_log:
		if e.get("fake", false) and not e.get("shared", false) and t_id in Gifts.implicated(e):
			return e
	return {}

## The player follows up on a hint ("what's your reason?"). They may still keep it back;
## if they tell, it comes out as their gift and the reading (as in answer_gift at full
## disclosure), and if their gift isn't public they ask you to keep it to yourself: the
## cards come back marked confidential, and using them at the meeting breaks your word.
## Returns {lines, facts}.
static func answer_hint(w, n) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var target = ""
	var best_day = -1
	for k in n.hints:
		if w.by_id[k].alive and n.hints[k]["day"] > best_day:
			best_day = n.hints[k]["day"]
			target = k
	if target == "":
		w.dlog.decision(n.id, "hint_followup", "gate", false, {"gate": "no_living_hinted_target"})
		lines.append(say(n, "I've nothing more to tell you."))
		return {"lines": lines, "facts": []}
	var t = w.by_id[target]
	var has_reason = _unshared_fake_on(n, target) != {} if n.is_evil() else reason_status(w, n, target)["kind"] in ["private", "player"]
	if not has_reason and not n.claim_public:
		w.dlog.decision(n.id, "hint_followup", "gate", false,
			{"gate": "no_revealable_reason"}, target)
		# Evil's free bluff (or a reason since shared): nothing it can show.
		w.dlog.think(n.id, "hint_followup", "Asked about the hint on %s: nothing to back it; declines." % target, {"evil": n.is_evil()})
		lines.append(_hint_decline(w, n, t))
		return {"lines": lines, "facts": []}
	var cost = reveal_cost(w, n)
	var parts = {"trust": (n.trust - 0.45) * 2.0, "privacy": (0.5 - trait_of(n, "privacy")) * 0.8}
	if cost.has("afraid"):
		parts["afraid"] = -0.3
	if not decide(w, n, "hint_followup", parts, "Tell the Demonologist why they suspect %s?" % target):
		lines.append(_hint_decline(w, n, t))
		return {"lines": lines, "facts": []}
	var r = answer_gift(w, n, 4)
	lines.append(say(n, "All right. You asked, so here's why I suspect %s." % t.name))
	lines.append_array(r["lines"])
	var facts: Array = r["facts"]
	if not n.claim_public:
		lines.append(say(n, "But keep this between us. Don't bring it up at the meeting; not yet."))
		for f in facts:
			if f.get("source", "") == n.id and f.get("kind", "") in ["info", "claim"]:
				f["confidential"] = n.id
	n.hints.erase(target)
	return {"lines": lines, "facts": facts}

## Keeping a hinted reason back. Good and evil draw from the same lines, so stalling ("give
## me a day or two") is no tell: a cautious good NPC stalls as often as an evil one with
## nothing behind its hint.
static func _hint_decline(w, n, t) -> Dictionary:
	if w.chance(0.5):
		return say(n, "Not yet. Give me a day or two, and watch %s." % t.name)
	return say(n, "I said I'm not ready, and I'm not. Ask me again another time.")

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
	if src.alive and not src.silenced and not src.claim_public and w.chance(C.RELAY_CORROBORATE):
		lines.append(say(src, "That was me."))
		for l in w.living():
			if l != n and l != src:
				acknowledge_reading(w, l, src, e, n.id)
		_go_public(w, src, lines, facts)

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
	if C.ROLES[role]["kind"] != "info":
		parts["hides_from_demon"] = 0.5
	if role in ["seer", "hearthwitch", "nightwatch", "lamplighter", "medium", "psychologist", "dowser"] and w.day <= 2:
		parts["gift_keeps_giving"] = 0.4
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
		lines.append_array(info_lines(w, n, shared_this_turn, "town", not lines.is_empty()))

## Last words are a claim and a spoken suspicion, not a fresh evidence argument.
## Reuse ordinary public claiming without adding the speaker's reading backlog.
static func last_words(w, n) -> Dictionary:
	if n.silenced:
		return {"lines": ["%s tries to speak, but no sound comes. Their voice is still stolen." % n.name], "facts": []}
	var lines: Array = []
	var facts: Array = []
	var claim: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	if n.claim_public and n.claimed_role != claim:
		n.claim_public = false # With nothing to hide, correct their earlier claim.
	_go_public(w, n, lines, facts, false)
	if lines.is_empty():
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
		if why == "" and C.has_readings(bluff) and (_unshared_fake_on(n, t.id) != {} or w.chance(C.EVIL_HINT_CHANCE)):
			hint = true
		w.dlog.think(n.id, "lie", "Evil: publicly accuses scapegoat %s, citing: %s." % [t.id, "a hinted private reason" if hint else why if why != "" else "vibes"])
	else:
		var tier = _accuse_tier(w, n, t, s2)
		if tier["tier"] == "reveal":
			_go_public(w, n, lines, facts)
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
	var report = sighting_report(w, n, seen, seen["day"])
	report["line"]["text"] = "On %s: %s" % [C.night_name(seen["day"]), report["line"]["text"]]
	lines.append(report["line"])
	facts.append(report["fact"])

## Peer pressure: what public accusations add to a listener's action score.
## Each accuser counts once (their latest stance), older accusations fade, and
## each further voice adds half as much as the one before, so a chorus can't bury someone.
## The crowd supplies no evidence, source dishonesty or world-prior weight.
const CONSENSUS_BASE = 0.12
const CONSENSUS_FADE = 0.6
const CONSENSUS_CAP = 0.3
const CONSENSUS_HINT = 1.15  # "I have a reason, but I'm not ready to share it": a little more than a bare accusation

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
	var thr: float = maxf(0.45, 0.86 - 0.08 * w.day) - 0.15 * (trait_of(n, "confidence") - 0.5) * 2.0 - 0.5 * paranoia(w, n)
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
	w.dlog.think(n.id, "nomination_case", "Case against %s: %s." % [t.id, ", ".join(PackedStringArray(items.map(func(x): return "%s (%s, %.2f)" % [x["why"], x["kind"], x["contrib"]])))], {"items": items.map(func(x): return {"eid": x["eid"], "kind": x["kind"]})})
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
			_go_public(w, n, lines, facts)
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
				_go_public(w, d, lines, facts)
			lines.append(say(d, "I was out because I'm the %s. That's what you saw." % C.role_name(role)))
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
			var pings = src.info_log.filter(func(e): return e.get("shared", false) and e.get("role", "") == "seer" and e["data"].get("yes", false) and d.id in e["data"].get("pair", [])).size()
			if rd["role"] == "seer" and pings >= 2:
				lines.append(say(d, "%s keeps finding me because I'm the one the Seer always misreads. Look at who else they named." % src.name))
				moves.append("red_herring")
				effs_by_move["red_herring"] = [[d.id, -0.12, true, "says they're the Seer's red herring", ""]]
				defence_scopes["red_herring"] = {"type": "challenge", "mode": "misled", "reading": WorkshopLedger.reading(src_id, rd).id}
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
					lines.append(say(d, "Then %s is lying, and you should ask yourselves why." % src.name))
					moves.append("lying")
					effs_by_move["lying"] = [[d.id, -0.05, true, "says the reading against them is a lie", ""], [src_id, C.DEFENCE_LIE_BLOWBACK, true, "%s says they lied" % d.name, ""]]
					defence_scopes["lying"] = {"type": "challenge", "mode": "lying", "reading": WorkshopLedger.reading(src_id, rd).id}
				else:
					lines.append(say(d, "%s's gift could have been turned. It's happened before." % src.name))
					moves.append("misled")
					effs_by_move["misled"] = [[d.id, -0.06, true, "says the reading against them was misled", ""]]
					defence_scopes["misled"] = {"type": "challenge", "mode": "misled", "reading": WorkshopLedger.reading(src_id, rd).id}
	# 4. Nothing to show: fear, or the desperation play.
	if moves.is_empty():
		if _afraid(w, d) and not d.claim_public:
			lines.append(say(d, "If I say what I am, I'll be dead by morning. But I'm not what you think."))
			moves.append("fear")
		else:
			lines.append(say(d, "I don't know what's going on, but I know I'm not evil."))
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
	if c > 0.66:
		return say(n, "This is madness, and you all know it.")
	if c < 0.34:
		return say(n, "P-please. I've done nothing.")
	return say(n, "You've got the wrong person.")

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
	if v.role == "martyr" and v.martyr_target == nominee and not v.gift_broken():
		# They'd die in this one's place: reluctant, unless the case, the pressure or the
		# panic is overwhelming.
		var r = 0.6 - 0.4 * paranoia(w, v) - 0.3 * v.pressure - 0.4 * maxf(0.0, base - 0.8)
		if r > 0.0:
			parts["martyr_reluctance"] = -snappedf(r, 0.01)
	for k in parts:
		if k not in ["suspicion", "town_pressure", "shared_execution_priority"]:
			s += parts[k]
	var need = 0.5 - 0.12 * (trait_of(v, "confidence") - 0.5) * 2.0 + (0.1 if w.day <= 1 else 0.0) - 0.4 * paranoia(w, v)
	var yes = s >= need
	var exact_parts: Dictionary = parts.duplicate()
	exact_parts["suspicion"] = susp(v, nominee) # pressure is reported separately
	w.dlog.decision(v.id, "vote", "evaluation", yes, {"parts": exact_parts,
		"score": s, "threshold": need, "comparison": ">=", "margin": s - need,
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

# ---------------------------------------------------------------- pressing

## "press <card>": confront someone with a card or deduction about them. It raises the
## pressure on them (which loosens tongues and secrets) and asks them to answer it: where
## they were that night, or what their gift really is. Anyone with something to hide may
## show nerves, and so, less often, may an innocent who's simply rattled.
static func press(w, n, card: Dictionary) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var c: Dictionary = card.get("conclusion", {})
	var subj: Array = card.get("subject", [])
	var pair: Array = card.get("data", {}).get("pair", [])
	var about_me = n.id in subj or c.get("a", "") == n.id or n.id in pair or (card.get("kind") == "claim" and card.get("source") != n.id and n.claim_public and card.get("role") == n.claimed_role)
	if not about_me:
		on_question(w, n)
		lines.append(say(n, "What has that to do with me?"))
		return {"lines": lines, "facts": facts}
	var kind: String = card.get("kind", "")
	var d: Dictionary = card.get("data", {})
	# What is the card pushing on: their night, or their gift?
	var night = -1
	if kind in ["sighting", "secret"] and card.get("phase", -1) == C.NIGHT and card.get("source", "") != n.id:
		night = card.get("day", -1)
	elif kind == "deduction" and c.get("type", "") in ["lied", "unreliable"]:
		for x in card.get("support_cards", []):
			if x.get("phase", -1) == C.NIGHT:
				night = x.get("day", -1)
	var naming_me = kind == "info" and card.get("role", "") == "clerk" and n.id in pair  # "one of you two is the X"
	var counter = kind == "claim" and card.get("source", "") != n.id and n.claim_public and card.get("role", "") == n.claimed_role
	var strength = 0.6 if kind == "deduction" else clampf(card_strength(w, card, n), 0.3, 1.0)
	if naming_me:
		strength = 0.5
	# Hiding something this card touches?
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var hiding = n.is_evil() or (night >= 0 and not n.secret.is_empty()) or (night < 0 and n.max_tier < 3 and not n.claim_public and C.ROLES[mine]["kind"] != "evil")
	var p_nerves = (0.6 if hiding else 0.2) * (1.0 - trait_of(n, "composure")) * strength
	var nervous = w.rng.randf() < p_nerves
	w.dlog.think(n.id, "pressed", "Pressed with '%s' (strength %.2f; hiding %s; nerves p=%.2f -> %s)." %
		[card.get("text", ""), strength, str(hiding), p_nerves, str(nervous)], {"night": night, "naming_me": naming_me, "counter": counter})
	n.pressure += 0.35 * strength
	if not naming_me and not n.is_evil():
		set_trust(w, n, n.trust - (0.03 + 0.06 * trait_of(n, "privacy")), "the Demonologist pressed me with evidence")
	if nervous:
		lines.append("%s %s" % [n.name, ["looks away a moment too quickly.", "shifts uneasily.", "goes a little pale.", "fumbles for an answer."][w.rng.randi_range(0, 3)]])
	if counter:
		on_question(w, n)
		var rival = w.by_id[card["source"]]
		lines.append(say(n, "I am the %s. If %s says otherwise, %s is lying." % [C.role_name(n.claimed_role), rival.name, rival.name]))
		if not n.is_evil():
			var receipt: Dictionary = WorkshopLedger.Evidence.normalize_card(card)
			ledger_hear(w, n, "own_role:" + fact_id(card), [[rival.id, 0.3, true, "the Demonologist showed me %s claims my gift" % rival.id, "they claim my gift"]], 1.0,
				[rival.id, -1, "role"], {"kind": "role_counter", "workshop_card": receipt})
		var pressed: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card)
		pressed["dialogue_exchange"] = {"action": "challenge_gift", "subject": n.id}
		return pressed
	if night >= 0:
		var r = _answer_pressed_night(w, n, night)
		lines += r["lines"]
		facts += r["facts"]
		var pressed: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card)
		pressed["dialogue_exchange"] = {"action": "challenge_night", "subject": n.id}
		return pressed
	# Their gift: a true naming opens them up; otherwise pressure decides.
	var bonus = 1 if naming_me and d.get("role", "") == mine else 0
	var tier = mini(_target_tier(w, n) + bonus, 4)
	var r2 = answer_gift(w, n, tier)
	lines += r2["lines"]
	facts += r2["facts"]
	var pressed: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card)
	pressed["dialogue_exchange"] = {"action": "challenge_gift", "subject": n.id}
	return pressed

## Only a known gift outing collapses disclosure. Personal errands and unaware
## Sleepwalkers keep the existing choices, including all their original RNG draws.
static func _gift_outing(w, n, night: int) -> bool:
	if n.is_evil() or n.secret_mod == "sleepwalker" or not C.ROLES[n.role].get("night_walk", false): return false
	if not str(n.history.get(w.time_key(night, C.NIGHT), "home")).begins_with("night:"): return false
	if night == w.day - 1:
		for walker in w.night_walkers:
			if walker.id == n.id:
				return not str(walker.why).begins_with("secret:") and not str(walker.why).begins_with("sleepwalking")
	if n.role == "warden" and n.warden_log.has(str(night)): return true
	if n.info_log.any(func(e): return e.get("role", "") == n.role and e.get("day", -1) == night): return true
	return n.secret.is_empty()

## "I've been known to sleepwalk." Offered under pressure (pressed with a sighting, or
## defending against a nomination) by the real Sleepwalker, who can't know they were out
## but knows they've walked before, and by an evil member whose bluffed gift doesn't
## already explain being out. One Sleepwalker per case, so evil won't say it once someone
## else has. Returns {line, fact} or {}.
static func sleepwalk_excuse(w, n, where: String) -> Dictionary:
	if n.silenced:
		return {}
	var others: bool = w.sleepwalk_claims.any(func(id): return id != n.id)
	if n.is_evil():
		var bluff: String = w.evil_plan["bluffs"].get(n.id, "")
		if others or (bluff != "" and C.ROLES[bluff].get("night_walk", false)) or n.claim_public and C.ROLES.get(n.claimed_role, {}).get("night_walk", false):
			return {}
		if not (n.id in w.sleepwalk_claims) and not decide(w, n, "sleepwalk_bluff", {"base": -0.1, "pressure": n.pressure * 0.5},
				"Evil: explain being seen out by claiming to sleepwalk?"):
			return {}
		w.dlog.think(n.id, "lie", "Evil: says they sleepwalk to explain being seen out.", {"lie": true})
	elif n.secret_mod != "sleepwalker":
		return {}
	if not (n.id in w.sleepwalk_claims):
		w.sleepwalk_claims.append(n.id)
	var line = say(n, "I don't remember going out. But I've been known to sleepwalk.")
	return {"line": line, "fact": {"kind": "secret", "subject": [n.id], "owner": n.id, "source": n.id,
		"secret_kind": "sleepwalker", "mod": "sleepwalker",
		"text": "%s says they've been known to sleepwalk (at %s)." % [n.name, where]}}

static func _answer_pressed_night(w, n, night: int) -> Dictionary:
	if not n.claim_public and n.max_tier < 3 and _gift_outing(w, n, night):
		if night not in n.lied_nights: n.lied_nights.append(night)
		# The existing gift answer owns the admission, claim, reading willingness,
		# question fatigue and the "So yes: I was out..." line, exactly once.
		return answer_gift(w, n, 3)
	var response = answer_night(w, n, night)
	var variants: Dictionary = n.dialogue_memory.get("pressed_nights", {})
	var count: int = variants.get(str(night), 0)
	variants[str(night)] = count + 1
	n.dialogue_memory["pressed_nights"] = variants
	var alternate = count % 2 == 1
	var when = C.night_name(night)
	if when.begins_with("night"): when = "on " + when
	var text = ""
	for fact in response.facts:
		if fact.get("kind", "") == "alibi" and fact.get("source", "") == n.id and n.id in fact.get("subject", []):
			text = ("That sighting doesn't change where I was: at home %s." if alternate else "I was at home %s. I stand by that account.") % when
			break
		if fact.get("kind", "") == "secret" and fact.get("owner", "") == n.id:
			text = ("I wasn't there on evil business. I %s. Keep that between us." if alternate else "All right: I %s. That's why I was out; please keep it quiet.") % n.secret.get("me", n.secret["text"])
			break
		if fact.get("kind", "") == "refusal" and fact.get("source", "") == n.id:
			text = "I've nothing more to say about that night." if alternate else "That sighting doesn't give you the right to demand my whereabouts."
			break
		if fact.get("kind", "") == "info" and fact.get("role", "") == "warden":
			var door: String = fact.data.target
			text = ("I stand by it: I guarded %s's door %s." if alternate else "My duty was at %s's door %s. That is still my account.") % [w.by_id[door].name, when]
			break
		if fact.get("watch_claim", false):
			text = ("I was keeping watch on %s %s; my account stands." if alternate else "My watch took me through %s %s. That's where I was.") % [C.block_name(fact.block), when]
			break
		if fact.get("duty_claim", false):
			if fact.get("duty", "") == "lamplighter":
				text = ("My lamp route still accounts for my being out %s." if alternate else "I was out on my lamp route %s. I haven't changed that account.") % when
			else:
				var dead = _hearth_dead(w, n, night)
				var hearth = "%s's hearth" % dead.name if dead != null else "the dead"
				text = ("My account stands: I was visiting %s %s." if alternate else "My gift took me to %s %s. That is still my account.") % [hearth, when]
			break
	if text != "":
		for line in response.lines:
			if line is Dictionary and line.get("speaker", "") == n.id:
				line.text = text
				break
	# Pressed with a sighting, they may offer the sleepwalking explanation (they were seen
	# out, whatever they remember).
	var stood_by_home: bool = response.facts.any(func(f): return f.get("kind", "") == "alibi" and f.get("source", "") == n.id)
	if stood_by_home and str(n.history.get(w.time_key(night, C.NIGHT), "")).begins_with("night:"):
		var excuse: Dictionary = sleepwalk_excuse(w, n, "night %d" % night)
		if not excuse.is_empty():
			response.lines.append(excuse["line"])
			response.facts.append(excuse["fact"])
	return response

# ---------------------------------------------------------------- conversation

static func on_question(w, n) -> void:
	n.pressed_today += 1
	if n.pressed_today > 3:
		var drop: float = (0.03 + 0.05 * trait_of(n, "privacy")) * (1.0 - 0.5 * trait_of(n, "composure"))
		set_trust(w, n, n.trust - drop, "pressed with %d questions today" % n.pressed_today)

## Attitude cue on greeting, shown only if their composure lets it slip.
static func greeting_cue(w, n) -> String:
	if w.rng.randf() > (1.0 - trait_of(n, "composure")) * 0.9:
		w.dlog.think(n.id, "cue", "Composure hides their attitude (trust %.2f)." % n.trust)
		return ""
	var t: float = n.trust
	var cue = ""
	if t < 0.3:
		cue = "%s eyes you warily. \"What do you want now?\"" % n.name
	elif t < 0.5:
		cue = "%s gives you a guarded nod." % n.name
	elif t < 0.7:
		cue = "%s greets you civilly enough." % n.name
	else:
		cue = "%s brightens when they see you. \"Ah, Demonologist. Sit.\"" % n.name
	w.dlog.think(n.id, "cue", "Shows attitude cue for trust %.2f." % t)
	return cue

## End of a conversation: small trust gain (once a day) and trait reveals.
static func end_conversation(w, n) -> Array:
	var out: Array = []
	if n.talked_day != w.day:
		n.talked_day = w.day
		set_trust(w, n, n.trust + 0.04 * (1.0 - 0.5 * trait_of(n, "privacy")), "a civil conversation with the Demonologist")
	var t = reveal_trait(w, n)
	if t != "":
		out.append(t)
	if w.rng.randf() < 0.6 * (1.0 - trait_of(n, "composure")):
		var t2 = reveal_trait(w, n)
		if t2 != "":
			out.append(t2)
	return out

static func reveal_trait(w, n) -> String:
	var hidden: Array = C.TRAITS.filter(func(t): return not n.revealed_traits.has(t))
	if hidden.is_empty():
		return ""
	var t: String = w.pick(hidden)
	var tier: String = C.tier(n.traits[t])
	n.revealed_traits[t] = tier
	w.dlog.add("trait_reveal", "player", n.id, {"trait": t, "tier": tier, "value": n.traits[t]})
	return "You get the measure of %s: %s. (%s: %s)" % [n.name, C.TRAIT_TEXT[t][tier] % n.name, t.capitalize(), tier]

## Disclosure tier the NPC is willing to reach right now (1..4).
static func _target_tier(w, n, trace_id: int = 0) -> int:
	var jitter = w.rng.randf_range(-0.2, 0.2)
	var openness = (1.0 - trait_of(n, "privacy")) * 1.0 + n.trust * 1.2 + n.pressure * 0.6 * (1.0 - 0.5 * trait_of(n, "composure")) \
		+ 0.1 * (w.day - 1) - 0.72 + jitter
	var role: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var gift_terms = {}
	if C.ROLES[role]["kind"] != "info":
		gift_terms["hides_from_demon"] = -0.5
	if role in ["seer", "hearthwitch", "nightwatch", "lamplighter", "medium", "psychologist", "dowser"] and w.day <= 2:
		gift_terms["gift_keeps_giving"] = -0.4
	elif role in C.START_ROLES:
		gift_terms["one_shot_gift"] = 0.3
	for value in gift_terms.values():
		openness += value
	var t = 1
	if openness > 0.75:
		t = 4
	elif openness > 0.45:
		t = 3
	elif openness > 0.15:
		t = 2
	w.dlog.decision(n.id, "gift_disclosure", "tier", t, {"openness": openness,
		"parts": {"privacy": (1.0 - trait_of(n, "privacy")) * 1.0, "trust": n.trust * 1.2,
			"pressure": n.pressure * 0.6 * (1.0 - 0.5 * trait_of(n, "composure")),
			"day": 0.1 * (w.day - 1), "base": -0.72, "jitter": jitter}.merged(gift_terms),
		"thresholds": [{"above": 0.75, "tier": 4}, {"above": 0.45, "tier": 3},
			{"above": 0.15, "tier": 2}, {"otherwise": 1}], "comparison": ">"}, "", trace_id)
	w.dlog.think(n.id, "disclosure", "Disclosure tier %d (openness %.2f; privacy %.2f, trust %.2f, pressure %.2f)." %
		[t, openness, trait_of(n, "privacy"), n.trust, n.pressure], {"tier": t})
	return t

## The unified gift/info question. Tiers: 1 deny/refuse, 2 hint, 3 gift, 4 gift + readings.
## Fear as a reason for silence ("I'll be dead by morning"): more likely as the bodies pile
## up and for the skittish. Fixed per person and day (no game RNG), and the same chance for
## evil hiding behind a bluffed gift as for good, so it isn't a tell.
## Too afraid to say what they are (the Demon's next mark)? Steadier people are less afraid.
## Pressure works against fear: keep withholding and they risk being hanged on suspicion.
## So does paranoia, here in its sense of the town opening up as the dead pile up.
## A kept ward/vigil promise halves what's left. One roll per person per day.
static func fear_chance(w, n) -> float:
	var p: float = 0.2 + 0.3 * (1.0 - trait_of(n, "composure")) - 0.5 * n.pressure - paranoia(w, n)
	if n.fear_eased:
		p *= 0.5  # the Demonologist kept their word to watch over them
	return clampf(p, 0.0, 0.85)

static func _afraid(w, n) -> bool:
	return _day_roll(n.id, w.day, 0x5EA4) < fear_chance(w, n)

## A deterministic roll in [0, 1) for this person and day (no RNG used, so asking twice in
## a day gets the same answer). Integer mixing: string hashes of "id:day" barely change
## from one day to the next.
static func _day_roll(id: String, day: int, salt: int) -> float:
	var x: int = (hash(id) ^ (day * 0x9E3779B1) ^ salt) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
	x = x ^ (x >> 16)
	return float(x & 0xFFFF) / 65536.0

## What protection a frightened NPC would ask the player for: "vigil" (watch their block),
## "ward" (a sigil on their door), or "" (none). An evil NPC who walks at night (the Demon,
## the Poisoner) never asks for a vigil that would see them go out, unless the gift they
## bluff walks at night too; they ask for the ward instead, if it's still to give.
static func protection_kind(w, n) -> String:
	if n.is_evil():
		var walks: bool = n.role == "demon" or C.ROLES[n.role].get("night_walk", false)
		var bluff: String = w.evil_plan["bluffs"].get(n.id, "")
		if walks and not (bluff != "" and C.ROLES[bluff].get("night_walk", false)):
			return "ward" if w.tools.get("ward", 0) > 0 else ""
	return "vigil"

static func protection_line(n, kind: String) -> Dictionary:
	if kind == "ward":
		return say(n, "Put your ward on my door tonight, and I'll tell you what I am. I can't say it otherwise.")
	return say(n, "Watch over %s tonight, and I'll tell you what I am. I daren't otherwise." % C.block_name(n.home_block))

## Where the fear refusal would come, a frightened NPC who trusts the player enough may ask
## for protection instead. One request a day; {} when they don't ask. Hearing and answering
## it is free; "decline" carries what they'd have said instead.
static func _protection_request(w, n, refusal: Dictionary) -> Dictionary:
	if n.request_day == w.day or n.claim_public or n.protect_lock or n.trust < 0.45:
		return {}
	var kind: String = protection_kind(w, n)
	if kind == "":
		return {}
	var p: float = clampf(0.35 + (n.trust - 0.45) * 1.5, 0.0, 0.85)
	var asks: bool = w.chance(p)
	w.dlog.decision(n.id, "protection_request", "outcome", asks, {"trust": n.trust, "p": snappedf(p, 0.01), "kind": kind})
	if not asks:
		return {}
	n.request_day = w.day
	return {"kind": "protect", "npc": n.id, "what": kind, "line": protection_line(n, kind),
		"decline": {"lines": [say(n, "Then I'll keep it to myself. I'm sorry.")], "facts": [refusal]}}

## Where they'd keep something back (not out of fear, and not because trust fell), a nervous
## NPC may offer it on condition the player keeps it quiet for now. tier: what they'd tell.
static func _confidence_request(w, n, tier: int, refusal: Dictionary) -> Dictionary:
	if n.request_day == w.day or n.claim_public or n.trust < 0.4:
		return {}
	var p: float = clampf(0.15 + (n.trust - 0.5) * 0.8 + (0.5 - trait_of(n, "composure")) * 0.5, 0.0, 0.5)
	var asks: bool = w.chance(p)
	w.dlog.decision(n.id, "confidence_request", "outcome", asks, {"trust": n.trust,
		"composure": trait_of(n, "composure"), "p": snappedf(p, 0.01), "tier": tier})
	if not asks:
		return {}
	n.request_day = w.day
	return {"kind": "confidence", "npc": n.id, "tier": tier,
		"line": say(n, "I'll tell you, but only if you promise not to reveal it yet."),
		"decline": {"lines": [say(n, "Then it stays with me.")], "facts": [refusal]}}

## A promised answer, once the player agrees: what answer_gift would say at that tier, without
## costing a question (the question was spent asking).
static func keep_request(w, n, tier: int) -> Dictionary:
	var r: Dictionary = answer_gift(w, n, tier)
	n.pressed_today = maxi(n.pressed_today - 1, 0)
	return r

static func answer_gift(w, n, force_tier: int = 0) -> Dictionary:
	var id = w.dlog.decision(n.id, "gift_disclosure", "start", null,
		{"force_tier": force_tier, "prior_tier": n.max_tier, "public": n.claim_public,
			"trust": n.trust, "pressure": n.pressure, "questions_today": n.pressed_today})
	var result = _answer_gift_impl(w, n, force_tier, id)
	if result.facts.any(func(f): return f.get("kind", "") == "refusal"):
		_append_distrust(w, n, result.lines)
	w.dlog.decision(n.id, "gift_disclosure", "outcome", result["facts"],
		{"final_tier": n.max_tier, "told_readings": n.told_readings,
			"role_claim": n.claimed_role, "public": n.claim_public}, "", id)
	return result

static func _answer_gift_impl(w, n, force_tier: int, trace_id: int) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var evil: bool = n.is_evil()
	var role: String = w.evil_plan["bluffs"][n.id] if evil else n.role
	var target = maxi(_target_tier(w, n, trace_id), force_tier)
	if n.claim_public:
		target = maxi(target, 3)
	var tier = maxi(target, n.max_tier)
	var withholding = target < n.max_tier
	w.dlog.decision(n.id, "gift_disclosure", "gate", tier, {"target_tier": target,
		"effective_tier": tier, "prior_tier": n.max_tier, "force_tier": force_tier,
		"public_floor": 3 if n.claim_public else 0, "withhold_new_readings": withholding}, "", trace_id)
	if tier <= 1:
		# Denying any gift is off (C.ALLOW_NO_GIFT_DENIAL): evil almost never says it, so it
		# read as a near-certain good, at the price of the gift. Refusing to say remains.
		var lie = C.ALLOW_NO_GIFT_DENIAL and decide(w, n, "deny_or_refuse", {"confidence": (trait_of(n, "confidence") - 0.5) * 1.5, "base": -0.1},
			"Tier 1: deny having a gift (lie) rather than refuse to say?")
		if lie:
			if not evil:
				w.dlog.think(n.id, "lie", "Caution: denies having a gift (true role %s)." % n.role, {"lie": true})
			else:
				w.dlog.think(n.id, "lie", "Evil: denies having a gift.", {"lie": true})
			n.claimed_role = "none"
			lines.append(say(n, "A gift? No, nothing like that. I'm only the %s." % n.occupation))
			facts.append({"kind": "claim", "subject": [n.id], "role": "none", "source": n.id, "private": true,
				"text": "%s told you privately they have no gift." % n.name})
		elif _afraid(w, n):
			var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true, "fear": true,
				"text": "%s won't say whether they have a gift: afraid it would make them the demon's next mark." % n.name}
			var ask: Dictionary = _protection_request(w, n, refusal)
			if not ask.is_empty():
				n.max_tier = maxi(n.max_tier, 1)
				return {"lines": [ask["line"]], "facts": [], "request": ask}
			lines.append(say(n, "If I say what I am, I'll be dead by morning. Ask me again when it's safer."))
			facts.append(refusal)
		else:
			var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true,
				"text": "%s refused to say whether they have a gift." % n.name}
			var ask: Dictionary = _confidence_request(w, n, 3, refusal)
			if not ask.is_empty():
				n.max_tier = maxi(n.max_tier, 1)
				return {"lines": [ask["line"]], "facts": [], "request": ask}
			lines.append(say(n, "Whether I have a gift is my own business."))
			facts.append(refusal)
		n.max_tier = maxi(n.max_tier, 1)
		return {"lines": lines, "facts": facts}
	if tier == 2:
		var pk: String = C.package_of(role)
		if evil:
			w.dlog.think(n.id, "lie", "Evil: gives a hint matching bluff %s." % role, {"lie": true})
		lines.append(say(n, C.HINT_PACKAGES[pk]["text"] + " That's all I'll say."))
		facts.append({"kind": "hint", "subject": [n.id], "source": n.id, "private": true, "package": pk,
			"roles": C.HINT_PACKAGES[pk]["roles"],
			"text": "%s hinted at %s (%s)." % [n.name, C.HINT_PACKAGES[pk]["name"],
				" / ".join(PackedStringArray(C.HINT_PACKAGES[pk]["roles"].map(func(r): return C.role_name(r))))]})
		n.max_tier = 2
		return {"lines": lines, "facts": facts}
	# Tier 3+: names the gift.
	var first_time = n.max_tier < 3 and not n.claim_public
	n.claimed_role = role
	if evil:
		w.dlog.think(n.id, "lie", "Evil cover: tells the player they are the %s." % role, {"true_role": n.role})
	if first_time:
		var reveal_cue: String = Dialogue.exchange_cue(n.dialogue_memory, "gift", n.id)
		var contextual: String = Dialogue.gift_reveal(n.id, C.role_name(role), reveal_cue)
		lines.append(say(n, contextual if contextual != "" else "I'll trust you with this. I'm the %s." % C.role_name(role)))
		if not evil and C.ROLES[role].get("night_walk", false) and not n.lied_nights.is_empty():
			# The lie they told you about that night, owned now it has a reason.
			var nights: Array = n.lied_nights.map(func(x): return C.night_name(x))
			lines.append(say(n, "So yes: I was out %s, whatever I told you. I wasn't ready to tell you why." % " and ".join(PackedStringArray(nights.map(func(x): return ("on " + x) if x.begins_with("night") else x)))))
			w.dlog.think(n.id, "admit", "Owns the whereabouts lie(s) now the gift is out: nights %s." % str(n.lied_nights))
			n.lied_nights.clear()
	else:
		lines.append(say(n, "As you know, I'm the %s." % C.role_name(role)))
	facts.append({"kind": "claim", "subject": [n.id], "role": role, "source": n.id, "private": not n.claim_public,
		"text": "%s %s the %s." % [n.name, "claims to be" if n.claim_public else "told you privately they are", C.role_name(role)]})
	if first_time:
		set_trust(w, n, n.trust + 0.03, "shared their gift with the Demonologist")
	n.max_tier = maxi(n.max_tier, 3)
	if role == "warden":
		# A Warden's work is whose door they stood at: say so when asked about the gift.
		var doors: Array = []
		for nd in range(0, w.day):
			var gd: String = warden_door(w, n, nd)
			if gd != "" and w.by_id.has(gd):
				doors.append("%s at %s's door" % [C.night_name(nd), w.by_id[gd].name])
				facts.append(_guard_fact(w, n, nd, gd))
		if not doors.is_empty():
			var said: String = "; ".join(PackedStringArray(doors))
			lines.append(say(n, "I keep watch over one door each night: %s." % (said[0].to_upper() + said.substr(1))))
			n.max_tier = maxi(n.max_tier, tier)
			return {"lines": lines, "facts": facts}
	if not C.has_readings(role):
		lines.append(say(n, "My gift doesn't tell me things. It only does what it does."))
		n.max_tier = maxi(n.max_tier, tier)
		return {"lines": lines, "facts": facts}
	# Readings: public ones are always repeated; private ones need tier 4.
	var readings: Array = []
	for i in range(n.info_log.size()):
		var e: Dictionary = n.info_log[i]
		if e.get("disowned", false):
			continue
		if e["shared"] or i < n.told_readings or tier >= 4 and not withholding:
			readings.append(e)
	if tier >= 4 and not withholding:
		n.told_readings = n.info_log.size()
		n.max_tier = 4
	if evil and not readings.is_empty():
		w.dlog.think(n.id, "lie", "Evil: recites fabricated %s results." % role)
	lines.append_array(info_lines(w, n, readings, "player", not lines.is_empty()))
	for e in readings:
		facts.append(info_fact(w, n, e))
	var held = n.info_log.size() - readings.size()
	if held > 0:
		var afraid: bool = _afraid(w, n)
		# One card per person and gift (the same refusal again adds nothing new).
		var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true, "withheld": true, "role": role, "fear": afraid,
			"text": "%s claims the %s but won't share what it has shown them." % [n.name, C.role_name(role)]}
		var ask: Dictionary = {}
		if withholding:
			lines.append(say(n, "I've told you what I knew before. The rest I'll keep, for now."))
			w.dlog.think(n.id, "withhold", "Trust fell; withholding %d newer reading(s) from the player." % held)
		elif afraid:
			ask = _protection_request(w, n, refusal)
			if ask.is_empty():
				lines.append(say(n, "If word gets round what %s, I'll be dead by morning. Not yet." % ("the rest of my readings show" if not readings.is_empty() else "my gift has shown me")))
		else:
			ask = _confidence_request(w, n, 4, refusal)
			if ask.is_empty():
				lines.append(say(n, "What it's shown me, I'll keep to myself for now."))
		if not ask.is_empty():
			lines.append(ask["line"])
			return {"lines": lines, "facts": facts, "request": ask}
		facts.append(refusal)
	elif n.info_log.is_empty():
		lines.append(say(n, "It hasn't shown me anything yet."))
	return {"lines": lines, "facts": facts}

## Sharing what they saw of others is gated by Gossip (and loosened by pressure).
static func _gossip_share(w, n, topic: String) -> int:
	var g = trait_of(n, "gossip")
	if g < 0.2 and n.pressure < 0.5:
		w.dlog.decision(n.id, "gossip_share", "gate", 0, {"gate": "gossip_and_pressure_cutoff",
			"topic": topic, "gossip": g, "gossip_minimum": 0.2,
			"pressure": n.pressure, "pressure_override": 0.5})
		w.dlog.think(n.id, topic, "Gossip %.2f: none of my business (pressure %.2f)." % [g, n.pressure])
		return 0
	var count = 1 + int(round((g + n.pressure * 0.5) * 3.0))
	w.dlog.decision(n.id, "gossip_share", "outcome", count,
		{"topic": topic, "gossip": g, "pressure": n.pressure})
	return count

## Whose door a Warden (or an evil Warden bluff) says they guarded on night nd. A bluff
## invents one on the block they were really on (or anyone, if they stayed in), once per
## night, so the story stays the same however often they're asked.
static func warden_door(w, n, nd: int) -> String:
	if n.warden_log.has(str(nd)) or not n.is_evil():
		return n.warden_log.get(str(nd), "")
	var hist: String = n.history.get(w.time_key(nd, C.NIGHT), "home:" + n.home_block)
	var was_out = hist.begins_with("night:")
	var block: String = hist.split(":")[1] if ":" in hist else n.home_block
	var cands: Array = w.living().filter(func(m): return m != n and (not was_out or m.home_block == block))
	if cands.is_empty():
		cands = w.living().filter(func(m): return m != n)
	var guarded = cands[w.rng.randi_range(0, cands.size() - 1)].id if not cands.is_empty() else ""
	n.warden_log[str(nd)] = guarded
	w.dlog.think(n.id, "lie", "Evil bluffing Warden: claims to have guarded %s on night %d." % [guarded, nd], {"lie": true})
	return guarded

static func _guard_fact(w, n, nd: int, guarded: String) -> Dictionary:
	var gb: String = w.by_id[guarded].home_block
	return {"kind": "sighting", "subject": [n.id], "block": gb, "day": nd, "phase": C.NIGHT, "source": n.id, "guard_claim": guarded,
		"text": "%s says they guarded %s's door (on %s) on night %d." % [n.name, w.by_id[guarded].name, C.block_name(gb), nd]}

## Whose hearth a Medium's reading (real, or an evil bluff's fake) for night nd names.
static func _hearth_dead(w, n, nd: int):
	for e in n.info_log:
		if e.get("role", "") == "medium" and e.get("day", -1) == nd and (e.get("fake", false) == n.is_evil()):
			var dead = w.by_id.get(e.get("data", {}).get("dead", ""))
			if dead != null:
				return dead
	return null

## The block of the hearth an evil Medium bluff's fake reading for night nd names ("" if none).
static func _bluff_hearth(w, n, nd: int) -> String:
	var dead = _hearth_dead(w, n, nd)
	return dead.home_block if dead != null and n.is_evil() else ""

static func _alibi_home(n, nd: int) -> Dictionary:
	return {"kind": "alibi", "subject": [n.id], "home": true, "day": nd, "phase": C.NIGHT, "source": n.id, "block": n.home_block,
		"text": "%s says they were home (on %s) on night %d." % [n.name, C.block_name(n.home_block), nd]}

static func answer_night(w, n, night: int = -1) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var nd: int = w.day - 1 if night < 0 else night
	var where: String = n.history.get(w.time_key(nd, C.NIGHT), "home:" + n.home_block)
	var was_out = where.begins_with("night:")
	if n.secret_mod == "sleepwalker" and was_out:
		w.dlog.think(n.id, "unaware", "Sleepwalker: was out on %s on night %d but honestly believes they slept at home." % [where, nd])
		was_out = false  # they truly don't know
	var block = where.substr(where.find(":") + 1)
	# Where they say they were: what their sightings must be told from. "" = not saying.
	var vantage = ""
	var how = "window"
	if n.is_evil() and n.claimed_role == "nightwatch" and w.evil_plan["fake_watch"].has(str(nd)):
		var fb: String = w.evil_plan["fake_watch"][str(nd)]
		w.dlog.think(n.id, "lie", "Evil bluffing Night Watch: claims to have watched %s (actually %s)." % [fb, where], {"lie": true})
		lines.append(say(n, "Keeping watch over %s, as is my duty." % C.block_name(fb)))
		facts.append({"kind": "sighting", "subject": [n.id], "block": fb, "day": nd, "phase": C.NIGHT, "source": n.id, "watch_claim": true,
			"text": "%s says they kept watch on %s on night %d." % [n.name, C.block_name(fb), nd]})
		vantage = fb
		how = "street"
	# A claimed night-walking gift keeps its story: an evil bluff always tells the duty,
	# a real holder tells it whenever they were actually out (Case 22485: a claimed
	# Lamplighter must never say "home all night").
	elif n.claimed_role in ["lamplighter", "medium"] and (n.claim_public or n.max_tier >= 3) and ((n.role == n.claimed_role and was_out) or n.is_evil()) \
			and not (n.is_evil() and n.claimed_role == "medium" and _bluff_hearth(w, n, nd) == ""):
		if n.is_evil() and n.claimed_role == "medium":
			# Their story puts them at the hearth their fake reading names, not where they were.
			block = _bluff_hearth(w, n, nd)
			w.dlog.think(n.id, "lie", "Evil bluffing Medium: claims to have sat at a hearth on %s on night %d." % [block, nd], {"lie": true})
		elif n.is_evil():
			block = block if was_out else n.home_block
			w.dlog.think(n.id, "lie", "Evil bluffing %s: claims their gift took them out on night %d." % [n.claimed_role, nd], {"lie": true})
		vantage = block
		how = "street"
		var hearth = _hearth_dead(w, n, nd)
		var duty = "Walking the lamp route, as I do every night." if n.claimed_role == "lamplighter" else \
			("Communing with the dead at %s's hearth, as my gift asks." % hearth.name if hearth != null else "Communing with the dead, as my gift asks.")
		lines.append(say(n, duty))
		facts.append({"kind": "sighting", "subject": [n.id], "block": block, "day": nd, "phase": C.NIGHT, "source": n.id, "duty_claim": true, "duty": n.claimed_role,
			"text": "%s says they were out on %s on night %d (%s)." % [n.name, C.block_name(block), nd, "the lamp route" if n.claimed_role == "lamplighter" else "visiting the dead"]})
	elif n.claimed_role == "warden" and (n.claim_public or n.max_tier >= 3) and ((n.role == "warden" and was_out) or n.is_evil()):
		# An open Warden says whose door they guarded; an evil one bluffing it invents a door
		# on the block they were really on (or anyone, if they stayed in).
		var guarded: String = warden_door(w, n, nd)
		if guarded != "" and w.by_id.has(guarded):
			var gb: String = w.by_id[guarded].home_block
			lines.append(say(n, "Standing guard at %s's door, as my gift asks." % w.by_id[guarded].name))
			vantage = gb
			how = "street"
			facts.append(_guard_fact(w, n, nd, guarded))
		else:
			lines.append(say(n, "At home all night, same as any honest soul."))
			facts.append(_alibi_home(n, nd))
			vantage = n.home_block
	elif not was_out:
		lines.append(say(n, "At home all night, same as any honest soul."))
		facts.append(_alibi_home(n, nd))
		vantage = n.home_block
	elif n.role == "nightwatch" and n.claimed_role == "nightwatch":
		vantage = block
		how = "street"
		lines.append(say(n, "Keeping watch over %s, as is my duty." % C.block_name(block)))
		facts.append({"kind": "sighting", "subject": [n.id], "block": block, "day": nd, "phase": C.NIGHT, "source": n.id, "watch_claim": true,
			"text": "%s says they kept watch on %s on night %d." % [n.name, C.block_name(block), nd]})
	else:
		# Out with something to hide: evil work, a personal secret, or a hidden Night Watch gift.
		var hiding = "evil work" if n.is_evil() else ("hidden %s gift" % C.role_name(n.role) if C.ROLES[n.role].get("night_walk", false) and n.secret.is_empty() else "secret: %s" % n.secret.get("kind", "?"))
		var can_confess = not n.is_evil() and not n.secret.is_empty()
		var confess = false
		if can_confess:
			confess = decide(w, n, "confess", {"trust": (n.trust - 0.6) * 1.5, "privacy": (0.4 - trait_of(n, "privacy")) * 1.0,
				"pressure": n.pressure * 0.8 * (1.0 - 0.5 * trait_of(n, "composure")), "insight_none": 0.0},
				"Confess personal secret (%s)?" % n.secret.get("kind", "?"))
		if confess:
			n.secret_known = true
			lines.append(say(n, "...I wasn't home. I %s. Please, keep it quiet." % n.secret.get("me", n.secret["text"])))
			vantage = block
			how = "street"
			facts.append({"kind": "secret", "subject": [n.id], "owner": n.id, "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
				"secret_kind": n.secret.get("kind", ""), "mod": "lovers" if n.secret.get("kind", "") == "lover" else "",
				"text": "%s confessed they were out on %s on night %d: %s %s." % [n.name, C.block_name(block), nd, n.name, n.secret["text"]]})
		else:
			var bold = decide(w, n, "lie_or_stonewall", {"confidence": (trait_of(n, "confidence") - 0.5) * 1.5,
				"privacy_stonewalls": -(trait_of(n, "privacy") - 0.5) * 0.6}, "Hiding (%s): lie outright rather than stonewall?" % hiding)
			if bold:
				w.dlog.think(n.id, "lie", "Hiding (%s): was on %s, claims to have been home." % [hiding, block], {"lie": true})
				if not n.is_evil() and not (nd in n.lied_nights):
					n.lied_nights.append(nd)
				lines.append(say(n, "Home. Where else would I be?"))
				facts.append(_alibi_home(n, nd))
				vantage = n.home_block
			else:
				w.dlog.think(n.id, "stonewall", "Hiding (%s): refuses to say where they were." % hiding)
				lines.append(whereabouts_refusal(n, nd))
				_append_distrust(w, n, lines)
				facts.append({"kind": "refusal", "subject": [n.id], "source": n.id, "day": nd, "phase": C.NIGHT,
					"text": "%s refused to say where they were on night %d." % [n.name, nd]})
	var limit = _gossip_share(w, n, "share_sightings")
	# Asking for whereabouts must not disclose a watch result the gift question withheld.
	if n.claimed_role == "nightwatch":
		for e in n.info_log:
			if e.get("role", "") == "nightwatch" and e.get("day", -1) == nd and not reading_disclosed(n, e):
				lines.append(say(n, "Where I kept watch is one thing. Who I saw there, I'm not ready to share."))
				return {"lines": lines, "facts": facts}
	var seen: Array = n.beliefs.filter(func(b): return b["kind"] in ["saw", "stayed_in"] and b["day"] == nd and b["phase"] == C.NIGHT)
	var reported: Array = []
	for b in seen:
		if n.is_evil() and Evil.is_teammate(w, n, b["who"]) and b["kind"] == "saw":
			w.dlog.think(n.id, "lie", "Evil: omits seeing teammate %s at night." % b["who"])
			continue
		if b["kind"] == "saw" and n.npc_trust.get(b["who"], 0.5) > 0.7 and w.rng.randf() < 0.6:
			w.dlog.think(n.id, "omit", "Leaves out seeing %s, whom they trust." % b["who"])
			continue
		if vantage != "" and b["block"] != vantage:
			# Seen from somewhere they say they weren't: telling it would give the lie away.
			# Most keep quiet; a rattled few let it slip.
			var slip = 0.25 * (1.0 - trait_of(n, "composure")) + 0.15 * n.pressure
			if w.rng.randf() >= slip:
				w.dlog.think(n.id, "omit", "Leaves out seeing %s on %s: they say they were on %s." % [b["who"], b["block"], vantage])
				continue
			w.dlog.think(n.id, "slip", "Lets slip seeing %s on %s, though they say they were on %s (p=%.2f)." % [b["who"], b["block"], vantage, slip])
		reported.append(b)
	var watch_story = _fake_watch_entry(n, nd) if n.is_evil() and n.claimed_role == "nightwatch" else {}
	if not watch_story.is_empty():
		# A false Night Watch tells the same story as their made-up watch report: exactly
		# who they "saw" pass on the block they "watched", nothing more, nothing less.
		reported = []
		for x in watch_story["data"].get("seen", []):
			if x != n.id and w.by_id.has(x):
				reported.append({"kind": "saw", "who": x, "loc": "", "block": watch_story["data"]["block"], "day": nd, "phase": C.NIGHT, "how": "street", "detail": "street"})
		w.dlog.think(n.id, "lie", "Evil bluffing Night Watch: night-%d sightings match the fake watch report (%s)." % [nd, ", ".join(PackedStringArray(watch_story["data"].get("seen", [])))])
	elif n.is_evil() and vantage != "":
		var fake = Evil.fake_night_sighting(w, n, nd, vantage, how)
		if fake != null:
			reported.append(fake)
	if limit == 0 and not reported.is_empty():
		lines.append(say(n, "As for anyone else, that's none of my business."))
		return {"lines": lines, "facts": facts}
	if watch_story.is_empty():
		reported = reported.slice(0, limit)
	if reported.is_empty() and not (was_out and not n.is_evil()):
		lines.append(say(n, "I saw nobody."))
	for b in reported:
		var r = sighting_report(w, n, b, nd)
		lines.append(r["line"])
		facts.append(r["fact"])
	return {"lines": lines, "facts": facts}

## A reading the player already heard, privately or at a meeting.
static func reading_disclosed(n, entry: Dictionary) -> bool:
	var index: int = n.info_log.find(entry)
	return not entry.get("disowned", false) and (entry.get("shared", false) or (index >= 0 and index < n.told_readings))

## An evil member's made-up Night Watch report for night nd, or {}.
static func _fake_watch_entry(n, nd: int) -> Dictionary:
	for e in n.info_log:
		if e.get("fake", false) and e.get("role", "") == "nightwatch" and e.get("day", -1) == nd:
			return e
	return {}

## One night sighting (or a neighbour seen going in for the night), as said and as a card.
## From a window, they can only speak for their own street.
static func sighting_report(w, n, b: Dictionary, nd: int) -> Dictionary:
	var who = w.by_id[b["who"]]
	var bn = C.block_name(b["block"])
	if b["kind"] == "stayed_in":
		return {"line": say(n, "From my window on night %d, I saw %s go in for the night, and they never came out." % [nd, who.name]),
			"fact": {"kind": "alibi", "subject": [who.id], "home": true, "witness": true, "day": nd, "phase": C.NIGHT, "source": n.id, "block": b["block"],
				"text": "%s says they saw %s go home for the night on night %d and not come out (from their window, %s)." % [n.name, who.name, nd, bn]}}
	var line = ""
	var how = ""
	if b.get("how", "street") == "window":
		how = " (from their window)"
		if b.get("detail", "") == "leaving_home":
			line = "From my window, I saw %s leave their house on night %d." % [who.name, nd]
		else:
			line = "From my window, I saw %s out in the street on night %d." % [who.name, nd]
	else:
		line = "I did see %s out on %s on night %d." % [who.name, bn, nd]
	return {"line": say(n, line),
		"fact": {"kind": "sighting", "subject": [who.id], "block": b["block"], "day": nd, "phase": C.NIGHT, "source": n.id, "how": b.get("how", "street"),
			"text": "%s says they saw %s on %s on night %d%s." % [n.name, who.name, bn, nd, how]}}

## Who they've seen around by day. when: "" (recently: today and yesterday), "morning",
## "afternoon", "evening" (today) or "yesterday". near_block: where the player is right now;
## people seen there this phase are left out (you can see them yourself), and memory reaches
## further back instead.
## "Where were you, and who did you see?" for a daytime frame: "" (earlier today, up to
## now), "morning" / "afternoon" / "evening" (today), "yesterday", or "yesterday
## morning" / "yesterday afternoon" / "yesterday evening". They say where they were
## (daytime whereabouts are open to anyone's eyes), then who they saw: as many as their
## memory (Insight) holds and their Gossip lets them share.
static func answer_today(w, n, when: String = "", near_block: String = "", seen_pairs: Dictionary = {}) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var parts_w: PackedStringArray = when.split(" ", false)
	var yday = parts_w.size() > 0 and parts_w[0] == "yesterday"
	var ph_name: String = parts_w[parts_w.size() - 1] if parts_w.size() > 0 and parts_w[parts_w.size() - 1] != "yesterday" else ""
	var ph = C.PHASES.map(func(x): return x.to_lower()).find(ph_name)
	var day: int = w.day - 1 if yday else w.day
	# The phases the question covers, in order.
	var phases: Array = []
	if ph >= 0:
		phases = [ph]
	else:
		for p in range(3):
			if yday or p <= w.phase:
				phases.append(p)
	var in_frame = func(b) -> bool:
		return b["day"] == day and b["phase"] in phases
	# Where they were.
	var was: Array = []
	for p in phases:
		if day < 1 or (day == w.day and p > w.phase):
			continue
		var at: String = n.history.get(w.time_key(day, p), "")
		if day == w.day and p == w.phase:
			at = n.loc
		if at == "" or at == "dead":
			continue
		var place: String = "at home" if at.begins_with("home") else ("at " + w.loc_name(at))
		var lead: String = ("yesterday " if yday else "this ") + C.PHASES[p].to_lower()
		was.append("%s I was %s" % [lead, place])
		facts.append({"kind": "sighting", "subject": [n.id], "source": n.id, "loc": at,
			"block": w.loc_block(at), "day": day, "phase": p, "self_report": true,
			"text": "%s says they were %s, day %d %s." % [n.name, place, day, C.PHASES[p]]})
	var was_s = ""
	if not was.is_empty():
		was_s = ", and ".join(PackedStringArray(was))
		was_s = was_s[0].to_upper() + was_s.substr(1)
	var limit = _gossip_share(w, n, "share_sightings")
	if limit == 0:
		lines.append(say(n, ((was_s + ". ") if was_s != "" else "") + "Who else goes where is none of my business."))
		return {"lines": lines, "facts": facts}
	# Memory: they recall only their most recent few sightings (more with Insight), one per person.
	var memory = 2 + int(round(trait_of(n, "insight") * 4.0))
	var before: Array = n.beliefs.filter(func(b): return b["kind"] == "saw" and b["phase"] != C.NIGHT and in_frame.call(b))
	var seen: Array = before.filter(func(b): return near_block == "" or not (b["day"] == w.day and b["phase"] == w.phase and b.get("block", "") == near_block))
	if seen.is_empty() and not before.is_empty():
		lines.append(say(n, ((was_s + ". ") if was_s != "" else "") + "Nobody but who you can see around you for yourself."))
		return {"lines": lines, "facts": facts}
	var recalled: Array = []
	var people = {}
	for i in range(seen.size() - 1, -1, -1):
		var b: Dictionary = seen[i]
		if people.has(b["who"]):
			continue
		if n.is_evil() and Evil.is_teammate(w, n, b["who"]):
			continue
		people[b["who"]] = true
		recalled.append(b)
		if recalled.size() >= memory:
			break
	if recalled.is_empty():
		lines.append(say(n, (was_s + ", and saw nobody worth mentioning.") if was_s != "" else "Nobody worth mentioning."))
		return {"lines": lines, "facts": facts}
	w.dlog.think(n.id, "share_sightings", "Recalls %d recent sighting(s) (memory %d from insight), shares up to %d (gossip)." %
		[recalled.size(), memory, limit])
	var parts: Array = []
	var named = {}   # people already mentioned (as someone's conversation partner, too)
	for b in recalled.slice(0, limit):
		if named.has("%s:%d:%d" % [b["who"], b["day"], b["phase"]]):
			continue
		var who = w.by_id[b["who"]]
		var when_s = "%s %s" % ["yesterday" if b["day"] < w.day else "this", C.PHASES[b["phase"]].to_lower()]
		var where: String = w.loc_name(b["loc"]) if b["loc"] != "" else C.block_name(b["block"])
		var tag = (" (%s)" % when_s) if phases.size() > 1 else ""
		if b.get("with", "") != "":
			named["%s:%d:%d" % [b["with"], b["day"], b["phase"]]] = true
		var partner: String = b.get("with", "")
		if partner != "" and w.by_id.has(partner) and not (n.is_evil() and Evil.is_teammate(w, n, partner)):
			var pn = w.by_id[partner]
			var pair = [who.id, partner]
			pair.sort()
			var conv = {"kind": "conversation", "subject": [who.id, partner], "block": b["block"], "loc": b["loc"], "day": b["day"], "phase": b["phase"],
				"source": n.id, "text": "%s saw %s and %s talking at %s, day %d %s." % [n.name, who.name, pn.name, where, b["day"], C.PHASES[b["phase"]]]}
			people[partner] = true
			if seen_pairs.has("talk:%s|%d|%d" % [",".join(PackedStringArray(pair)), b["day"], b["phase"]]):
				# You saw this pair yourself: they leave it out, but it backs your card.
				conv["silent"] = true
				facts.append(conv)
				continue
			parts.append("%s at %s, talking with %s%s" % [who.name, where, pn.name, tag])
			facts.append(conv)
		else:
			parts.append("%s at %s%s" % [who.name, where, tag])
		facts.append({"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": b["phase"], "source": n.id,
			"text": "%s saw %s on %s, day %d %s." % [n.name, who.name, C.block_name(b["block"]), b["day"], C.PHASES[b["phase"]]]})
	if parts.is_empty():
		lines.append(say(n, ((was_s + ". ") if was_s != "" else "") + "Nobody you didn't see for yourself."))
		return {"lines": lines, "facts": facts}
	var seen_s = "; ".join(PackedStringArray(parts))
	lines.append(say(n, ("%s, and saw %s." % [was_s, seen_s]) if was_s != "" else ("Let me think. %s." % seen_s)))
	return {"lines": lines, "facts": facts}

static func answer_opinion(w, n, t) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var text = ""
	var level = 0.0
	if trait_of(n, "gossip") < 0.2 and n.pressure < 0.5:
		w.dlog.decision(n.id, "opinion_disclosure", "gate", false,
			{"gate": "gossip_and_pressure_cutoff", "gossip": trait_of(n, "gossip"),
				"gossip_minimum": 0.2, "pressure": n.pressure, "pressure_override": 0.5}, t.id)
		w.dlog.think(n.id, "opinion", "Gossip %.2f: won't discuss others." % trait_of(n, "gossip"))
		var refused: String = "It's not my place to say."
		var previous: String = Dialogue.exchange_cue(n.dialogue_memory, "opinion", t.id)
		refused = Dialogue.repeated_opinion_refusal(n.id, t.name, previous, refused)
		lines.append(say(n, Dialogue.contextualize(n.id, refused, previous if previous != "opinion_again" else "", t.name)))
		_append_distrust(w, n, lines)
		return {"lines": lines, "facts": facts}
	# Same pipeline for both alignments: a suspicion level plus an optional grounded reason.
	var why = ""
	var lie = false
	var held = false
	if n.is_evil():
		if Evil.is_teammate(w, n, t.id):
			level = 0.2
			lie = true
			# Shadow self: if their good self would speak against this teammate, cover them
			# only when it's worth breaking cover; otherwise go along (under the bus).
			var tl = shadow_eval(w, n, func(sh): return susp(sh, t.id)) if C.SHADOW_SELF else null
			if tl != null and tl >= 0.45:
				var stakes = Evil.teammate_value(w, t.id) * (0.3 + Evil.public_heat(w, t))
				if not evil_override(w, n, "opinion", stakes, 0.5, "good self distrusts teammate %s (%.2f)" % [t.id, tl]):
					level = tl
		elif t.id == w.evil_plan["scapegoat"]:
			level = 0.85
			why = Evil.bluff_reason(w, n, t)
			lie = true
		else:
			var sl = shadow_eval(w, n, func(sh): return susp(sh, t.id)) if C.SHADOW_SELF else null
			level = sl if sl != null else Evil.town_view(w, t)
	else:
		level = susp(n, t.id)
		why = citable_reason(w, n, t.id, "player")
		# A reason they haven't told you (their unshared reading) stays back, but they say so.
		held = why == "" and reason_status(w, n, t.id)["kind"] == "private"
	why = Evil.cite(w, n, why)
	var shown = level
	if level < 0.25:
		text = "I trust %s." % t.name
	elif level < 0.45:
		if w.rng.randf() < 0.6 - 0.4 * trait_of(n, "insight") + paranoia(w, n):
			text = "I can't put my finger on it, but something's off about %s." % t.name
			shown = 0.5
		else:
			text = ("%s seems all right to me." % t.name) if level < 0.35 else ("I don't really know %s that well." % t.name)
	elif level < 0.8:
		text = "I have my doubts about %s." % t.name
	else:
		text = "If you ask me, %s is the one." % t.name
	if level >= 0.45:
		text += (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else (" I have my reasons, but I'm not ready to say." if held else " Something's off about them.")
	var close = n.npc_trust.get(t.id, 0.5) > 0.7 and not (n.is_evil() and t.id == w.evil_plan["scapegoat"])
	if close and not Dialogue.has_voice(n.id):
		text += " We're close, mind."
	w.dlog.think(n.id, "lie" if lie else "opinion", "%s opinion of %s: level %.2f, reason: %s." %
		["Evil cover" if lie else ("Evil (mimicking the town)" if n.is_evil() else "Honest"), t.id, level, why if why != "" else "vibes"])
	level = shown
	var opinion_reply: Dictionary = voiced(n, "friend", text, "opinion:" + t.id, {"close": close, "subject": t.name})
	var opinion_cue: String = Dialogue.exchange_cue(n.dialogue_memory, "opinion", t.id)
	opinion_reply["text"] = Dialogue.contextualize(n.id, opinion_reply["text"], opinion_cue, t.name)
	lines.append(opinion_reply)
	if level >= 0.5:
		facts.append({"kind": "opinion", "subject": [t.id], "source": n.id, "text": "%s distrusts %s." % [n.name, t.name]})
	return {"lines": lines, "facts": facts}

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
			match card.get("role", ""):
				"seer":
					return 1.0 if d.get("yes", false) else 0.0
				"hearthwitch":
					return 0.5 * d.get("count", 0)
				"archivist":
					return 0.8
				"nightwatch":
					return 1.0 if suspect.id in d.get("seen", []) else 0.0
				"gravedigger":
					return 0.3
			if suspect.id in Gifts.implicated(card):
				return 0.6
			return 0.0
		"trace":
			return 0.7
		"home", "haunt":
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
	var loss = 0.08 + 0.4 * p
	set_trust(w, owner, owner.trust - (loss if first else loss * 0.4), "the Demonologist spread my secret")
	if p >= 0.67:
		cap_trust(w, owner, 0.3, "the Demonologist spread my secret (very private person)")
	elif p >= 0.34:
		cap_trust(w, owner, 0.6, "the Demonologist spread my secret")

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
			match card.get("role", ""):
				"seer":
					return 0.0 if d.get("yes", false) else 0.8
				"hearthwitch":
					return 0.6 if d.get("count", 0) == 0 else 0.0
				"clerk":
					return 0.5
				"nightwatch":
					return 0.0
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
		lines.append(say(n, "You've told me that already."))
	elif suspect == n:
		lines.append(say(n, "Me? That's madness."))
	elif strength < 0.3 and suspect.id in cw["subj"]:
		lines.append(say(n, "That proves nothing against %s." % suspect.name))
	elif relevance < 0.3:
		lines.append(say(n, "I don't see what that has to do with %s." % suspect.name))
	elif bond > 0.65 and delta < 0.1:
		lines.append(say(n, "%s is my friend. You'll need more than that." % suspect.name))
	elif cls == "speech" and ins >= 0.67 and delta < 0.1:
		lines.append(say(n, "That's only talk. Show me something real."))
	elif nv >= 0.8:
		lines.append(say(n, "You're right. I'll not trust %s again." % suspect.name))
	elif delta >= 0.15:
		lines.append(say(n, "That... does look bad for %s." % suspect.name))
	else:
		lines.append(say(n, "Maybe. I'll keep an eye on %s." % suspect.name))
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
			lines.append(say(n, "You've told me that already. Thank you."))
		elif defend_strength(card, n.id) >= 0.2:
			set_trust(w, n, n.trust + 0.03, "the Demonologist spoke up for me")
			lines.append(say(n, "Thank you for believing me."))
		else:
			lines.append(say(n, "I appreciate the support, but I'm not sure that explains it."))
		return {"lines": lines, "facts": [], "repeated": repeated, "workshop": shared_self}
	if n.is_evil():
		var r = w.rng.randf()
		if who.is_evil():
			lines.append(say(n, "Fair enough. I'll think better of %s." % who.name if r < 0.6 else "Maybe. I'll keep an open mind about %s." % who.name))
		else:
			lines.append(say(n, "Maybe. I'll keep an open mind about %s." % who.name if r < 0.7 else "That doesn't clear %s." % who.name))
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
		lines.append(say(n, "You've told me that already."))
	elif strength < 0.2:
		lines.append(say(n, "That doesn't clear %s." % gname))
	elif h["gain"] >= 0.12:
		lines.append(say(n, "Fair enough. I'll think better of %s." % gname))
	else:
		lines.append(say(n, "Maybe. I'll keep an open mind about %s." % gname))
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
		lines.append(say(n, "Maybe. I'll keep an eye on them both." if w.rng.randf() < 0.6 else "That... does look bad for one of them."))
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
		lines.append(say(n, "You've told me that already."))
	elif gain >= 0.12:
		lines.append(say(n, "That... does look bad for one of them."))
	else:
		lines.append(say(n, "Maybe. I'll keep an eye on them both."))
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
	var speaker = present[0]
	for i in range(present.size()):
		r -= weights[i]
		if r <= 0:
			speaker = present[i]
			break
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
