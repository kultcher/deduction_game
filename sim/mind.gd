## NPC reasoning for good and evil townsfolk: suspicion, trust, claims and disclosure,
## testimony, nominations, votes, conversation answers. Decisions with hidden reasoning are
## written to the dev log via w.dlog.think(...).
##
## Speech lines are returned as {"speaker": id, "name": name, "text": text}; narration as
## plain strings. game.gd renders both.
##
## All functions are static and take the world as the first argument.
##
## The shadow self is in `mind_shadow.gd`, case and card evaluation in `mind_cases.gd` and the
## evidence ledger in `mind_ledger.gd`, all one inheritance chain over `mind_base.gd`, so every
## `Mind.<fn>` is unchanged for callers.
extends "res://sim/mind_ledger.gd"


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
	# The voices' alibis say "all last night"; an earlier night takes its spoken ordinal in
	# that place ("all the second night"), never a number (Nov 17).
	var when_label = "last night"
	if w != null and nd != w.day - 1:
		when_label = C.spoken_night(nd, w.day)
	var rendered = Dialogue.compose(n.id, Dialogue.alibi_intent("alibi:%d" % nd, when_label), {"audience": "player", "speech_act": "answer", "trust": n.trust, "pressure": n.pressure}, n.dialogue_memory)
	return say(n, rendered["text"])

## Keep every fact and narration intact; only the first spoken response is rephrased.
static func _challenged(n, response: Dictionary, card: Dictionary) -> Dictionary:
	for i in range(response["lines"].size()):
		var line = response["lines"][i]
		if line is Dictionary and line.get("speaker", "") == n.id:
			# Rephrasing changes delivery only. Keep the approved statement and any
			# canonical payload/provenance attached to the original speech event.
			# The "I saw it with my own eyes" opener is for a witness defending their own
			# sighting. Someone else's sighting of the speaker (the player's vigil, a
			# neighbour's window) gets the plain opener (playtest 89077, finding 2).
			var own_sighting: bool = str(card.get("source", "")) == n.id
			var is_visual: bool = own_sighting and (card.get("kind", "") in ["sighting", "vigil"] or (card.get("kind", "") == "info" and card.get("role", "") == "nightwatch"))
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
	var was_defer: bool = w.defer_beliefs
	w.defer_beliefs = true
	hear_claim(w, protectee, warden.id, "warden", 1.0, "told")
	var card = fact.duplicate(true)
	card["learned"] = [{"day": w.day, "phase": w.phase, "via": warden.id}]
	var receipt = WorkshopLedger.Evidence.normalize_card(card)
	ledger_hear(w, protectee, "heard:" + receipt.id, [], 1.0, [warden.id, night, "report"],
		{"kind": "tell", "workshop_card": receipt, "workshop_teller": warden.id, "workshop_public": false})
	w.defer_beliefs = was_defer
	flush_beliefs(w, protectee)
	if susp(protectee, warden.id) < Tuning.Social.GOSSIP_BELIEVED_BELOW:
		protectee.npc_trust[warden.id] = clampf(protectee.npc_trust.get(warden.id, 0.5) + Tuning.Roles.WARDEN_SAVE_TRUST * belief, 0.0, 1.0)

static func warden_target(w, n) -> String:
	return C.role_def("warden").pick_targets(w, n, _mind())

# ---------------------------------------------------------------- town meeting (sim/mind_meeting.gd, mind_nomination.gd, mind_defence.gd, mind_vote.gd)


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
	return MindNomination.case_against(w, n, t_id, limit)

static func nomination_case(w, n, t, already: String) -> Dictionary:
	return MindNomination.nomination_case(w, n, t, already)

static func defend_self(w, d, nominator_id: String, disclosed_facts: Array = []) -> Dictionary:
	return MindDefence.defend_self(w, d, nominator_id, disclosed_facts)

static func defence_line(w, n) -> Dictionary:
	return MindDefence.defence_line(w, n)

static func vote(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int) -> bool:
	return MindVote.vote(w, v, nominee, nominator, player_yes, statement, yes_so_far)

static func vote_resistance_lines(w, res: Dictionary) -> Array:
	return MindVote.vote_resistance_lines(w, res)

static func catches_home_lie(view: Dictionary, ids: Array, target: String) -> bool:
	return MindVote.catches_home_lie(view, ids, target)

static func _vote_impl(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int, trace_id: int) -> bool:
	return MindVote._vote_impl(w, v, nominee, nominator, player_yes, statement, yes_so_far, trace_id)


# ---------------------------------------------------------------- pressing & conversation (sim/mind_dialogue.gd, mind_press.gd, mind_answers.gd)

static func has_live_hint(w, n) -> bool:
	return MindPress.has_live_hint(w, n)

static func answer_hint(w, n) -> Dictionary:
	return MindPress.answer_hint(w, n)

static func _hint_decline(w, n, t) -> Dictionary:
	return MindPress._hint_decline(w, n, t)

static func press(w, n, card: Dictionary, known_haunts: Dictionary = {}) -> Dictionary:
	return MindPress.press(w, n, card, known_haunts)

static func react_to_trace(w, n, card: Dictionary, known_haunts: Dictionary = {}, already_counted: bool = false) -> Dictionary:
	return MindDialogue.react_to_trace(w, n, card, known_haunts, already_counted)

static func _gift_outing(w, n, night: int) -> bool:
	return MindPress._gift_outing(w, n, night)

static func _answer_pressed_night(w, n, night: int) -> Dictionary:
	return MindPress._answer_pressed_night(w, n, night)

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
	return MindAnswers.answer_gift(w, n, force_tier, count_question)

static func _answer_gift_impl(w, n, force_tier: int, trace_id: int, count_question: bool = true) -> Dictionary:
	return MindAnswers._answer_gift_impl(w, n, force_tier, trace_id, count_question)

static func _gossip_share(w, n, topic: String) -> int:
	return MindAnswers._gossip_share(w, n, topic)

static func warden_door(w, n, nd: int) -> String:
	return MindAnswers.warden_door(w, n, nd)

static func _guard_fact(w, n, nd: int, guarded: String) -> Dictionary:
	return MindAnswers._guard_fact(w, n, nd, guarded)

static func _hearth_dead(w, n, nd: int):
	return MindAnswers._hearth_dead(w, n, nd)

static func _bluff_hearth(w, n, nd: int) -> String:
	return MindAnswers._bluff_hearth(w, n, nd)

static func _alibi_home(n, nd: int) -> Dictionary:
	return MindAnswers._alibi_home(n, nd)

static func answer_night(w, n, night: int = -1) -> Dictionary:
	return MindAnswers.answer_night(w, n, night)

static func reading_disclosed(n, entry: Dictionary) -> bool:
	return MindAnswers.reading_disclosed(n, entry)

static func _fake_watch_entry(n, nd: int) -> Dictionary:
	return MindAnswers._fake_watch_entry(n, nd)

static func _spoken_list(items: Array) -> String:
	return Dialogue.Observations.spoken_list(items)

static func _add_observation(groups: Array, observation: Dictionary) -> void:
	MindDialogue._add_observation(groups, observation)

static func _observation_lines(n, groups: Array, audience: String, speech_act: String, preceded: bool, first_relation: String = "independent") -> Array:
	return MindDialogue._observation_lines(n, groups, audience, speech_act, preceded, first_relation)

static func sighting_report(w, n, b: Dictionary, nd: int) -> Dictionary:
	return MindAnswers.sighting_report(w, n, b, nd)

static func sighting_is_here(w, b: Dictionary, who: String, near_loc: String = "") -> bool:
	return MindAnswers.sighting_is_here(w, b, who, near_loc)

static func answer_today(w, n, when: String = "", near_loc: String = "", seen_pairs: Dictionary = {}) -> Dictionary:
	return MindAnswers.answer_today(w, n, when, near_loc, seen_pairs)

static func answer_opinion(w, n, t) -> Dictionary:
	return MindDialogue.answer_opinion(w, n, t)
