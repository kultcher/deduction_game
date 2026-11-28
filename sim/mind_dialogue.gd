## NPC conversation with the player: greetings, disclosure, fear, protection and
## confidence requests, opinions, the dead, and reactions to traces.
##
## Pressing and hints are in `sim/mind_press.gd`; answers about a gift, a night and
## the day are in `sim/mind_answers.gd`. All three share `sim/mind_dialogue_base.gd`.
## `Mind` keeps forwarding wrappers for the main entry points.
extends "res://sim/mind_dialogue_base.gd"


# ---------------------------------------------------------------- conversation

static func on_question(w, n) -> void:
	n.pressed_today += 1
	if n.pressed_today > Tuning.Trust.QUESTION_FATIGUE_LIMIT:
		var drop: float = (Tuning.Trust.QUESTION_FATIGUE_BASE + Tuning.Trust.QUESTION_FATIGUE_PRIVACY * trait_of(n, "privacy")) * (1.0 - Tuning.Trust.QUESTION_FATIGUE_COMPOSURE_DAMP * trait_of(n, "composure"))
		set_trust(w, n, n.trust - drop, "pressed with %d questions today" % n.pressed_today)


static func _pool_greeting(id: String, key: String, index: int, fallback: String) -> String:
	if not Dialogue.has_voice(id):
		return fallback
	var arr = Dialogue.Voices.VOICES[id].get(key, [])
	if arr is Array and not arr.is_empty():
		return str(arr[posmod(index, arr.size())])
	return fallback

## Attitude cue on greeting, shown only if their composure lets it slip.
static func greeting_cue(w, n) -> String:
	if not w.decision_roll(n, "greeting_attitude_visible", (1.0 - trait_of(n, "composure")) * 0.9, {"composure": trait_of(n, "composure")}, "", "<="):
		w.dlog.think(n.id, "cue", "Composure hides their attitude (trust %.2f)." % n.trust)
		return ""
	var t: float = n.trust
	var cue = ""
	if t < 0.3:
		cue = "%s eyes you warily. \"%s\"" % [n.name, _pool_greeting(n.id, "greet_cold", 0, "What do you want now?")]
	elif t < 0.5:
		cue = "%s gives you a guarded nod." % n.name
	elif t < 0.7:
		cue = "%s greets you civilly enough." % n.name
	else:
		cue = "%s brightens when they see you. \"%s\"" % [n.name, _pool_greeting(n.id, "greet_warm", 0, "Ah, Demonologist. Sit.")]
	w.dlog.think(n.id, "cue", "Shows attitude cue for trust %.2f." % t)
	return cue

## Spoken VN conversation opener with rapport tiers, one-shot event overrides, and
## curated portrait expressions. Consumes the exact same single composure roll as
## greeting_cue so RNG state and Decision Inspector parity are preserved.
static func greeting_line(w, n, context: Dictionary = {}, roll_attitude: bool = true) -> Dictionary:
	var attitude_visible: bool = w.decision_roll(n, "greeting_attitude_visible", (1.0 - trait_of(n, "composure")) * 0.9, {"composure": trait_of(n, "composure")}, "", "<=") if roll_attitude else (trait_of(n, "composure") < 0.5)
	var greeted: Dictionary = n.dialogue_memory.get("greeted_events", {})
	var visits: int = int(n.dialogue_memory.get("greet_visits", 0))
	var text: String = ""
	var canonical: String = ""
	var expr: String = "neutral"
	var strength: int = 1
	var event_fired: bool = false

	if w.phase == C.MORNING and not w.deaths_last_night.is_empty() and not greeted.has("murder:%d" % w.day):
		var friend_vid: String = ""
		for vid in w.deaths_last_night:
			var s_vid: String = str(vid)
			if w.by_id.has(s_vid) and (float(n.npc_trust.get(s_vid, 0.5)) >= 0.65 or s_vid in n.friends):
				friend_vid = s_vid
				break
		if friend_vid != "":
			var f_name: String = w.by_id[friend_vid].name
			canonical = "I still cannot believe %s is gone. Ask what you need." % f_name
			text = Dialogue.voice_line(n.id, "greet_friend_killed", canonical, {"victim": f_name})
			expr = "sorrowful"
			strength = 2
		else:
			var v0_id: String = str(w.deaths_last_night[0])
			var v_name: String = w.by_id[v0_id].name if w.by_id.has(v0_id) else "our neighbor"
			canonical = "After losing %s in the night, nobody slept easy." % v_name
			text = Dialogue.voice_line(n.id, "greet_after_murder", canonical, {"victim": v_name})
			expr = str(GREET_MURDER_EXP.get(n.id, "concerned"))
			strength = 2
		greeted["murder:%d" % w.day] = true
		event_fired = true
	elif w.phase == C.MORNING and not w.executions.is_empty() and int(w.executions[-1].get("day", -1)) == w.day - 1 and not greeted.has("exec:%d" % (w.day - 1)):
		var ex_id: String = str(w.executions[-1].get("id", ""))
		if w.by_id.has(ex_id):
			var ex_name: String = w.by_id[ex_id].name
			canonical = "After hanging %s last night, let us tread carefully today." % ex_name
			text = Dialogue.voice_line(n.id, "greet_after_execution", canonical, {"executed": ex_name})
			expr = str(GREET_EXEC_EXP.get(n.id, "sorrowful"))
			strength = 2 if expr != "neutral" else 1
			greeted["exec:%d" % (w.day - 1)] = true
			event_fired = true
	if not event_fired:
		var prot_key: String = str(context.get("protection_key", ""))
		var fric_key: String = str(context.get("friction_key", ""))
		if prot_key != "" and not greeted.has(prot_key):
			canonical = "Thank you for looking out for my safety. Ask what you need."
			text = Dialogue.voice_line(n.id, "greet_after_protection", canonical)
			expr = "warm"
			strength = 1
			greeted[prot_key] = true
			event_fired = true
		elif fric_key != "" and not greeted.has(fric_key):
			canonical = "After how you treated me earlier, state your question plainly."
			text = Dialogue.voice_line(n.id, "greet_after_friction", canonical)
			expr = str(GREET_FRICTION_EXP.get(n.id, "harsh"))
			strength = 2
			greeted[fric_key] = true
			event_fired = true

	if not event_fired:
		n.dialogue_memory["greet_visits"] = visits + 1
		var idx: int = visits + w.day
		if attitude_visible and n.trust < 0.32:
			w.dlog.think(n.id, "cue", "Shows attitude cue for trust %.2f." % n.trust)
			canonical = "What do you want now?"
			text = _pool_greeting(n.id, "greet_cold", idx, canonical)
			expr = str(GREET_COLD_EXP.get(n.id, "harsh"))
			strength = 2
		elif attitude_visible and n.trust >= 0.65:
			w.dlog.think(n.id, "cue", "Shows attitude cue for trust %.2f." % n.trust)
			canonical = "Ah, Demonologist. Sit."
			text = _pool_greeting(n.id, "greet_warm", idx, canonical)
			expr = "warm"
			strength = 1
		else:
			if not attitude_visible:
				w.dlog.think(n.id, "cue", "Composure hides their attitude (trust %.2f)." % n.trust)
			else:
				w.dlog.think(n.id, "cue", "Shows attitude cue for trust %.2f." % n.trust)
			canonical = "Good day, Demonologist."
			text = _pool_greeting(n.id, "greet_neutral", idx, canonical)
			expr = "neutral"
			strength = 1
	else:
		w.dlog.think(n.id, "cue", "Shows contextual greeting (%s)." % expr)

	n.dialogue_memory["greeted_events"] = greeted
	var M = _mind()
	var spoken: String = Dialogue.apply_tics(n.id, text, M._tic_memory(n))
	var line: Dictionary = {"speaker": n.id, "name": n.name, "text": spoken, "statement": canonical}
	if expr != "" and expr != "neutral" and Dialogue.has_voice(n.id):
		line["expression"] = expr
		line["expression_strength"] = strength
	return line

## End of a conversation: small trust gain (once a day) and trait reveals.
static func end_conversation(w, n) -> Array:
	var out: Array = []
	if n.talked_day != w.day:
		n.talked_day = w.day
		set_trust(w, n, n.trust + Tuning.Trust.CIVIL_TALK_BASE * (1.0 - Tuning.Trust.CIVIL_TALK_PRIVACY_DAMP * trait_of(n, "privacy")), "a civil conversation with the Demonologist")
	var t = reveal_trait(w, n)
	if t != "":
		out.append(t)
	if w.decision_roll(n, "extra_trait_reveal", 0.6 * (1.0 - trait_of(n, "composure")), {"composure": trait_of(n, "composure")}):
		var t2 = reveal_trait(w, n)
		if t2 != "":
			out.append(t2)
	return out

static func reveal_trait(w, n) -> String:
	var hidden: Array = C.TRAITS.filter(func(t): return not n.revealed_traits.has(t))
	if hidden.is_empty():
		return ""
	var t: String = w.decision_pick(n, "revealed_trait", hidden)
	var tier: String = C.tier(n.traits[t])
	n.revealed_traits[t] = tier
	w.dlog.add("trait_reveal", "player", n.id, {"trait": t, "tier": tier, "value": n.traits[t]})
	return "You get the measure of %s: %s. (%s: %s)" % [n.name, C.TRAIT_TEXT[t][tier] % n.name, t.capitalize(), tier]

## Disclosure tier the NPC is willing to reach right now (1..4). `pressed_again` is added to
## openness when it's pressed again about a night it owned (Tuning.Dialogue.PRESSED_AGAIN_OPENNESS).
static func _target_tier(w, n, trace_id: int = 0, pressed_again: float = 0.0) -> int:
	# One mood per NPC per day (a fixed daily sample, like fear), so asking again the same
	# day can't fish for a better roll (Oct 30, docs/social_trust_pass.md).
	var jitter: float = (_day_roll(n.id, w.day, 0x0BE7) - 0.5) * 2.0 * Tuning.Dialogue.OPENNESS_JITTER
	var openness = (1.0 - trait_of(n, "privacy")) * Tuning.Dialogue.OPENNESS_PRIVACY_WEIGHT + n.trust * Tuning.Dialogue.OPENNESS_TRUST_WEIGHT + n.pressure * Tuning.Dialogue.OPENNESS_PRESSURE_WEIGHT * (1.0 - Tuning.Dialogue.OPENNESS_COMPOSURE_DAMP * trait_of(n, "composure")) \
		+ Tuning.Dialogue.OPENNESS_DAY_SLOPE * (w.day - 1) + Tuning.Dialogue.OPENNESS_BASE_OFFSET + jitter + pressed_again
	var role: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var gift_terms = {}
	C.role_def(role).score_disclosure_tier(w, n, gift_terms)
	for value in gift_terms.values():
		openness += value
	var t = 1
	if openness > Tuning.Dialogue.TIER_FULL:
		t = 4
	elif openness > Tuning.Dialogue.TIER_PARTIAL:
		t = 3
	elif openness > Tuning.Dialogue.TIER_VAGUE:
		t = 2
	w.dlog.decision(n.id, "gift_disclosure", "tier", t, {"openness": openness,
		"parts": {"privacy": (1.0 - trait_of(n, "privacy")) * Tuning.Dialogue.OPENNESS_PRIVACY_WEIGHT, "trust": n.trust * Tuning.Dialogue.OPENNESS_TRUST_WEIGHT,
			"pressure": n.pressure * Tuning.Dialogue.OPENNESS_PRESSURE_WEIGHT * (1.0 - Tuning.Dialogue.OPENNESS_COMPOSURE_DAMP * trait_of(n, "composure")),
			"day": Tuning.Dialogue.OPENNESS_DAY_SLOPE * (w.day - 1), "base": Tuning.Dialogue.OPENNESS_BASE_OFFSET, "jitter": jitter}.merged(gift_terms).merged({"pressed_again": pressed_again} if pressed_again != 0.0 else {}),
		"jitter_min": -Tuning.Dialogue.OPENNESS_JITTER, "jitter_max": Tuning.Dialogue.OPENNESS_JITTER, "thresholds": [{"above": Tuning.Dialogue.TIER_FULL, "tier": 4}, {"above": Tuning.Dialogue.TIER_PARTIAL, "tier": 3},
			{"above": Tuning.Dialogue.TIER_VAGUE, "tier": 2}, {"otherwise": 1}], "comparison": ">"}, "", trace_id)
	w.dlog.think(n.id, "disclosure", "Disclosure tier %d (openness %.2f; privacy %.2f, trust %.2f, pressure %.2f)." %
		[t, openness, trait_of(n, "privacy"), n.trust, n.pressure], {"tier": t})
	return t

## How far they'll go about their gift today, for anything that asks after it ("ask gift",
## and "ask night" for a gift's night result): target (today's openness, at least
## force_tier, and at least the public floor), tier (never below what they've told
## before), withholding (trust has fallen below what they told before: no new readings).
## New readings are told only when readings_open is true. No game RNG (a fixed daily mood).
static func disclosure_gate(w, n, force_tier: int = 0, trace_id: int = 0) -> Dictionary:
	var target = maxi(_target_tier(w, n, trace_id), force_tier)
	# Public with their gift already: their readings too, unless they badly distrust you.
	var public_floor: int = (4 if n.trust >= Tuning.Dialogue.PUBLIC_READINGS_MIN_TRUST else 3) if n.claim_public else 0
	target = maxi(target, public_floor)
	var tier = maxi(target, n.max_tier)
	var withholding = target < n.max_tier
	w.dlog.decision(n.id, "gift_disclosure", "gate", tier, {"target_tier": target,
		"effective_tier": tier, "prior_tier": n.max_tier, "force_tier": force_tier,
		"public_floor": public_floor, "withhold_new_readings": withholding}, "", trace_id)
	return {"target": target, "tier": tier, "withholding": withholding, "readings_open": tier >= 4 and not withholding}

## The unified gift/info question. Tiers: 1 deny/refuse, 2 hint, 3 gift, 4 gift + readings.
## Fear as a reason for silence ("I'll be dead by morning"): more likely as the bodies pile
## up and for the skittish. Fixed per person and day (no game RNG), and the same chance for
## evil hiding behind a bluffed gift as for good, so it isn't a tell.
## Too afraid to say what they are (the Demon's next mark)? Steadier people are less afraid.
## Pressure works against fear: keep withholding and they risk being hanged on suspicion.
## Paranoia no longer subtracts from fear (Phase 4.1), so fear never drops as bodies pile up.
## A kept ward/vigil promise halves what's left. One roll per person per day.
static func fear_chance(w, n) -> float:
	var p: float = Tuning.Dialogue.FEAR_BASE + Tuning.Dialogue.FEAR_COMPOSURE_SCALE * (1.0 - trait_of(n, "composure")) - Tuning.Dialogue.FEAR_PRESSURE_SCALE * n.pressure
	if n.fear_eased:
		p *= Tuning.Dialogue.FEAR_EASED_MULT  # the Demonologist kept their word to watch over them
	return clampf(p, 0.0, Tuning.Dialogue.FEAR_CAP)

static func _afraid(w, n) -> bool:
	var draw = _day_roll(n.id, w.day, 0x5EA4)
	var p = fear_chance(w, n)
	var yes = draw < p
	w.observe_decision(n, "afraid_to_disclose", yes, {"mechanism": "fixed daily sample (not a fresh RNG draw)", "inputs": {"composure": trait_of(n, "composure"), "pressure": n.pressure, "paranoia": paranoia(w, n), "fear_eased": n.fear_eased}, "probability": p, "draw": draw, "threshold": p, "comparison": "<"})
	return yes

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
		var walks: bool = (C.is_demon(n.role) and not C.is_day_demon(n.role)) or C.ROLES[n.role].get("night_walk", false)
		var bluff: String = w.evil_plan["bluffs"].get(n.id, "")
		if walks and not (bluff != "" and C.ROLES[bluff].get("night_walk", false)):
			return "ward" if w.tools.get("ward", 0) > 0 else ""
	return "vigil"

static func protection_line(n, kind: String) -> Dictionary:
	if kind == "ward":
		return say_voiced(n, "request_ward", "Put your ward on my door tonight, and I'll tell you what I am. I can't say it otherwise.")
	var blk_name = C.block_name(n.home_block)
	return say_voiced(n, "request_vigil", "Watch over %s tonight, and I'll tell you what I am. I daren't otherwise." % blk_name, {"block": blk_name})

## Where the fear refusal would come, a frightened NPC who trusts the player enough may ask
## for protection instead. One request a day; {} when they don't ask. Hearing and answering
## it is free; "decline" carries what they'd have said instead.
static func _protection_request(w, n, refusal: Dictionary) -> Dictionary:
	# Nothing to trade once the player knows what they are (triage 3.2: Edda gave her role,
	# then asked for a vigil in exchange for it).
	if n.request_day == w.day or n.claim_public or n.protect_lock or n.max_tier >= 3 or n.trust < Tuning.Dialogue.PROTECTION_REQ_MIN_TRUST:
		w.observe_decision(n, "protection_request", false, {"gate": "request already made today, claim public, promised protection, role already told, or trust < 0.45", "inputs": {"trust": n.trust, "request_day": n.request_day, "day": w.day, "claim_public": n.claim_public, "protect_lock": n.protect_lock}})
		return {}
	var kind: String = protection_kind(w, n)
	if kind == "":
		return {}
	var p: float = clampf(Tuning.Dialogue.PROTECTION_REQ_BASE + (n.trust - Tuning.Dialogue.PROTECTION_REQ_MIN_TRUST) * Tuning.Dialogue.PROTECTION_REQ_TRUST_SLOPE, 0.0, Tuning.Dialogue.PROTECTION_REQ_CAP)
	var asks: bool = w.decision_roll(n, "protection_request", p, {"trust": n.trust})
	w.dlog.decision(n.id, "protection_request", "outcome", asks, {"trust": n.trust, "p": snappedf(p, 0.01), "kind": kind})
	if not asks:
		return {}
	n.request_day = w.day
	return {"kind": "protect", "npc": n.id, "what": kind, "line": protection_line(n, kind),
		"decline": {"lines": [say_voiced(n, "request_declined", "Then I'll keep it to myself. I'm sorry.")], "facts": [refusal]}}

## Where they'd keep something back (not out of fear, and not because trust fell), a nervous
## NPC may offer it on condition the player keeps it quiet for now. tier: what they'd tell.
static func _confidence_request(w, n, tier: int, refusal: Dictionary) -> Dictionary:
	if n.request_day == w.day or n.claim_public or n.trust < Tuning.Dialogue.CONFIDENCE_REQ_MIN_TRUST:
		w.observe_decision(n, "confidence_request", false, {"gate": "request already made today, claim public, or trust < 0.4", "inputs": {"trust": n.trust, "request_day": n.request_day, "day": w.day, "claim_public": n.claim_public, "protect_lock": n.protect_lock}})
		return {}
	var p: float = clampf(Tuning.Dialogue.CONFIDENCE_REQ_BASE + (n.trust - 0.5) * Tuning.Dialogue.CONFIDENCE_REQ_TRUST_SLOPE + (0.5 - trait_of(n, "composure")) * Tuning.Dialogue.CONFIDENCE_REQ_COMPOSURE_SLOPE, 0.0, Tuning.Dialogue.CONFIDENCE_REQ_CAP)
	var asks: bool = w.decision_roll(n, "confidence_request", p, {"trust": n.trust, "composure": trait_of(n, "composure")})
	w.dlog.decision(n.id, "confidence_request", "outcome", asks, {"trust": n.trust,
		"composure": trait_of(n, "composure"), "p": snappedf(p, 0.01), "tier": tier})
	if not asks:
		return {}
	n.request_day = w.day
	n.dialogue_memory["confidence_requested"] = true
	return {"kind": "confidence", "npc": n.id, "tier": tier,
		"line": say_voiced(n, "request_confidence", "I'll tell you, but only if you promise not to reveal it yet."),
		"decline": {"lines": [say_voiced(n, "request_declined", "Then it stays with me.")], "facts": [refusal]}}

## A promised answer, once the player agrees: what answer_gift would say at that tier, without
## costing a question (the question was spent asking).
static func keep_request(w, n, tier: int) -> Dictionary:
	# Accepting an NPC's own secrecy deal spends no new question and never triggers question-4 fatigue.
	return _answers().answer_gift(w, n, tier, false)

## Below this credit for someone's word (Mind honesty, evidence-based), an opinion that
## clears them adds a caveat about relying on what they say.
## Canonical (unvoiced) wording when the opinion and the bond are said together.

## Asked about someone who has died: they say so, and offer no opinion of them (Nov 10). The
## haunt roll still follows, framed in the past tense (game_conversation._maybe_tell_haunts).
static func answer_about_dead(w, n, t) -> Dictionary:
	on_question(w, n)
	return {"lines": [say_voiced(n, "ask_about_dead", "%s is gone now, God rest them." % t.name, {"subject": t.name})], "facts": []}


static func answer_opinion(w, n, t) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var text = ""
	var level = 0.0
	# No hard Gossip cutoff: even discreet townsfolk give an opinion when asked directly.
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
	var opinion_key = ""
	# What they say keeps three things apart (docs/social_trust_pass.md): whether they think
	# the subject is evil (the suspicion level, which picks the line), how far they credit the
	# subject's word (honesty, an optional clause), and their bond (friend or rival, said
	# alongside, never instead). Bonds are stated truthfully by both alignments.
	var close = n.npc_trust.get(t.id, 0.5) > 0.7 and not (n.is_evil() and t.id == w.evil_plan["scapegoat"])
	var bond: String = "friend" if (t.id in n.friends or close) else ("rival" if t.id in n.rivals else "")
	var combined: bool = false   # the line itself states the bond
	var agree: Dictionary = {}
	if level < 0.25:
		text = "I don't take %s for one of the evil ones." % t.name
		opinion_key = "opinion_clear"
		# Their readings confirm what I know (Michael, Nov 19): said as the reason, from a
		# moderate or known confirmation; evil only from its good self's record.
		agree = load("res://sim/social.gd").readings_agree_record(n, t.id)
		if not agree.is_empty():
			text = "%s's readings agree with what I know, so I don't take them for one of the wicked." % t.name
			opinion_key = "opinion_readings_agree"
	elif level < 0.45:
		if w.decision_roll(n, "neutral_opinion_suspicion", 0.6 - 0.4 * trait_of(n, "insight") + paranoia(w, n), {"insight": trait_of(n, "insight"), "paranoia": paranoia(w, n)}, t.id):
			text = "I can't put my finger on it, but something's off about %s." % t.name
			opinion_key = "opinion_vibes"
			shown = 0.5
		else:
			# "I don't really know them" makes no sense of a friend or a rival.
			var fine: bool = level < 0.35 or bond != ""
			text = ("%s seems all right to me." % t.name) if fine else ("I don't really know %s that well." % t.name)
			opinion_key = "opinion_fine" if fine else "opinion_unfamiliar"
	elif level < 0.8:
		text = "I have my doubts about %s." % t.name
		opinion_key = "opinion_doubt"
	else:
		text = "If you ask me, %s is the one." % t.name
		opinion_key = "opinion_accuse"
	if bond != "" and opinion_key in ["opinion_clear", "opinion_fine", "opinion_doubt"]:
		var settled: bool = opinion_key != "opinion_doubt"
		opinion_key = "opinion_%s_%s" % [bond, "clear" if settled else "suspect"]
		text = OPINION_BONDED[opinion_key] % t.name
		combined = true
	var canonical_opinion: String = text
	text = Dialogue.voice_line(n.id, opinion_key, text, {"subject": t.name})
	if level >= 0.45:
		var opinion_tail: String = (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else (" I have my reasons, but I'm not ready to say." if held else " Something's off about them.")
		# A friend-or-rival line has already admitted it's a doubt, not a case.
		if combined and why == "" and not held:
			opinion_tail = ""
		text += opinion_tail
		canonical_opinion += opinion_tail
	# Their word is a separate matter from their alignment: a cleared neighbour whose reports
	# haven't held up gets a caveat. Not for a teammate or scapegoat an evil speaker is lying about.
	if level < 0.45 and not lie and _mind().reliability(n, t.id, -1, "report") < WORD_DOUBT_BELOW:
		var caveat: String = "Though I'd not take everything %s says on faith." % t.name
		text += " " + Dialogue.voice_line(n.id, "opinion_word_doubt", caveat, {"subject": t.name})
		canonical_opinion += " " + caveat
	if bond == "friend" and not combined and not Dialogue.has_voice(n.id):
		text += " We're close, mind."
	elif bond == "rival" and not combined and not Dialogue.has_voice(n.id):
		text += " We don't get along, mind."
	if lie:
		w.dlog.think(n.id, "lie", "Gave a false opinion of %s, as cover, %s." % [t.name, ("citing \"%s\"" % why) if why != "" else "with no reason given"])
	else:
		w.dlog.think(n.id, "opinion", "%s opinion of %s: level %.2f, reason: %s." %
			["Evil (mimicking the town)" if n.is_evil() else "Honest", t.id, level, why if why != "" else "vibes"])
	level = shown
	# An uncombined friend or rival gets the voice's partiality note after the opinion.
	var tail_kind: String = bond if (bond != "" and not combined) else "friend"
	var opinion_reply: Dictionary = voiced(n, tail_kind, text, "opinion:" + t.id,
		{"close": bond == "friend" and not combined, "rival": bond == "rival" and not combined, "subject": t.name})
	var opinion_cue: String = Dialogue.exchange_cue(n.dialogue_memory, "opinion", t.id)
	opinion_reply["text"] = Dialogue.contextualize(n.id, opinion_reply["text"], opinion_cue, t.name)
	opinion_reply["statement"] = canonical_opinion
	# Assign only to specific voiced deliveries, never to the private relationship
	# or suspicion score that led to the publicly spoken opinion.
	var opinion_expressions = {
		"opinion_clear": {"agnes": "warm", "edda": "warm", "fenwick": "warm", "isolde": "warm", "jory": "warm", "merrin": "warm"},
		"opinion_friend_clear": {"agnes": "warm", "edda": "warm", "fenwick": "warm", "isolde": "warm", "jory": "warm", "merrin": "warm"},
		"opinion_friend_suspect": {"dorian": "concerned", "isolde": "concerned", "merrin": "concerned"},
		"opinion_accuse": {"constance": "harsh", "edda": "harsh", "fenwick": "harsh", "greta": "harsh", "jory": "harsh", "lian": "harsh", "merrin": "harsh", "dorian": "concerned", "isolde": "concerned"},
	}
	var expressed: String = opinion_expressions.get(opinion_key, {}).get(n.id, "")
	if expressed != "" and Dialogue.has_voice(n.id):
		opinion_reply["expression"] = expressed
		opinion_reply["expression_strength"] = 1 if expressed == "warm" else 2
	if bond != "":
		opinion_reply["relationship"] = {"kind": bond, "people": [n.id, t.id]}
	lines.append(opinion_reply)
	if level >= 0.5:
		facts.append({"kind": "opinion", "subject": [t.id], "source": n.id, "text": "%s distrusts %s." % [n.name, t.name]})
	if not agree.is_empty():
		facts.append(load("res://sim/social.gd").readings_agree_fact(n, t, agree))
	_second_hand_gift_note(w, n, t, lines, facts)
	_meeting_note(w, n, t, lines, facts)
	return {"lines": lines, "facts": facts}

## Asked about someone, the speaker mentions the latest meeting of theirs it saw or heard of,
## from today or yesterday (BACKLOG item 3, Michael, Nov 18: meetings feed the gossip
## network). Once for each meeting. The player takes it as a location report for each of the
## two, at second hand when the speaker only heard of it. Evil keeps quiet about its
## teammates' meetings; nobody repeats one the player can see for themselves.
static func _meeting_note(w, n, t, lines: Array, facts: Array) -> void:
	# Every meeting of theirs it saw or heard of, from today or yesterday; the latest one not yet
	# told wins, first or second hand alike (Codex on #308: an old memory mustn't block newer word).
	var cands: Array = []
	for b in n.beliefs:
		if b.get("kind", "") == "saw" and b.get("phase", C.NIGHT) != C.NIGHT and str(b.get("with", "")) != "" and str(b.get("loc", "")) != "" \
				and t.id in [str(b.get("who", "")), str(b["with"])] and int(b.get("day", -1)) >= w.day - 1:
			cands.append({"a": str(b["who"]), "b": str(b["with"]), "loc": str(b["loc"]), "block": str(b.get("block", "")), "day": int(b["day"]), "phase": int(b["phase"]), "witness": n.id})
	for h in n.hearsay:
		if str(h.get("kind", "")) == "meeting" and t.id in [str(h.get("about", "")), str(h.get("with", ""))] and int(h.get("day", -1)) >= w.day - 1 \
				and w.by_id.has(str(h.get("witness", ""))):
			cands.append({"a": str(h["about"]), "b": str(h["with"]), "loc": str(h["loc"]), "block": str(h.get("block", "")), "day": int(h["day"]), "phase": int(h["phase"]), "witness": str(h["witness"])})
	var got: Dictionary = {}
	var other_id: String = ""
	var key: String = ""
	for c in cands:
		var oid: String = c.b if c.a == t.id else c.a
		if oid == n.id or not w.by_id.has(oid):
			continue
		if n.is_evil() and (Evil.is_teammate(w, n, t.id) or Evil.is_teammate(w, n, oid)):
			continue
		if c.day == w.day and c.phase == w.phase and c.loc == w.player_loc:
			continue
		var pair: Array = [t.id, oid]
		pair.sort()
		var k: String = "player|meeting:%s:%s:%d:%d" % [pair[0], pair[1], c.day, c.phase]
		if n.told_to.has(k):
			continue
		# The latest; on a tie, what they saw themselves.
		if got.is_empty() or c.day * 3 + c.phase > got.day * 3 + got.phase or (c.day * 3 + c.phase == got.day * 3 + got.phase and c.witness == n.id and got.witness != n.id):
			got = c
			other_id = oid
			key = k
	if got.is_empty():
		return
	n.told_to[key] = true
	var other = w.by_id[other_id]
	var where: String = w.loc_name(got.loc)
	var when_s: String = "%s %s" % ["yesterday" if got.day < w.day else "this", C.PHASES[got.phase].to_lower()]
	var fact: Dictionary = {"kind": "conversation", "subject": [t.id, other_id], "block": got.block, "loc": got.loc, "day": got.day, "phase": got.phase,
		"source": got.witness, "text": "%s saw %s and %s talking at %s, day %d %s." % [w.by_id[got.witness].name, t.name, other.name, where, got.day, C.PHASES[got.phase]]}
	if got.witness == n.id:
		lines.append(say(n, "I saw %s at %s, talking with %s, %s." % [t.name, where, other.name, when_s]))
	else:
		# Heard of it: second hand, through this speaker.
		fact["via"] = n.id
		fact["text"] = "Via %s: %s" % [n.name, fact["text"]]
		var heard_fallback: String = "%s told me they saw %s and %s talking at %s, %s." % [w.by_id[got.witness].name, t.name, other.name, where, when_s]
		lines.append(say_voiced(n, "gossip_meeting", heard_fallback, {"source": w.by_id[got.witness].name, "a": t.name, "b": other.name, "place": where, "when": when_s}))
	facts.append(fact)

## Meeting plan M1: asked about someone, a willing good speaker passes on a private gift
## claim or hint that person made to them (once; shares the keys gossip_item uses).
static func _second_hand_gift_note(w, n, t, lines: Array, facts: Array) -> void:
	if n.is_evil() or t.claim_public or not t.alive:
		return
	var willing: bool = trait_of(n, "gossip") * Tuning.Social.ROLE_WILLING_GOSSIP_SCALE + n.trust * Tuning.Social.ROLE_WILLING_TRUST_SCALE + n.pressure * Tuning.Social.ROLE_WILLING_PRESSURE_SCALE > Tuning.Social.ROLE_WILLING_THRESHOLD
	if not willing:
		return
	var kc: Dictionary = n.known_claims.get(t.id, {})
	if not kc.is_empty() and kc.get("via", "") == t.id and C.ROLES.has(str(kc.get("role", ""))) and not n.told_to.has("player|role_claim:" + t.id):
		n.told_to["player|role_claim:" + t.id] = true
		var rn: String = C.role_name(kc["role"])
		lines.append(say_voiced(n, "role_query_private_direct", "Between us, %s told me they're the %s." % [t.name, rn], {"who": t.name, "role": rn}))
		facts.append({"kind": "claim", "subject": [t.id], "role": kc["role"], "source": t.id, "via": n.id, "private": true,
			"text": "Via %s: %s privately claims to be the %s." % [n.name, t.name, rn]})
		return
	for h in n.hearsay:
		if h.get("kind", "") != "role_hint" or h.get("from", "") != t.id or n.told_to.has("player|role_hint:" + t.id):
			continue
		var pk: String = str(h.get("package", ""))
		if not C.HINT_PACKAGES.has(pk):
			continue
		n.told_to["player|role_hint:" + t.id] = true
		lines.append(say(n, "Between us, %s hinted their gift is %s." % [t.name, C.HINT_PACKAGES[pk]["name"]]))
		facts.append({"kind": "hint", "subject": [t.id], "source": t.id, "via": n.id, "private": true, "package": pk,
			"roles": C.HINT_PACKAGES[pk]["roles"].duplicate(),
			"text": "Via %s: %s hinted at %s (%s)." % [n.name, t.name, C.HINT_PACKAGES[pk]["name"],
				C.package_roles_text(pk, w.case_script)]})
		return

static func _observation_scene(n, b: Dictionary, day: int) -> Dictionary:
	return {"source": n.id, "place_id": b.get("loc", ""), "block": b.get("block", ""),
		"day": day, "phase": b.get("phase", C.NIGHT), "how": b.get("how", "street"),
		"predicate": b.get("kind", ""), "detail": b.get("detail", ""), "partner": b.get("with", "")}

static func _add_observation(groups: Array, observation: Dictionary) -> void:
	Observations.add(groups, observation.kind, observation.scene, observation.subject, observation.before, observation.after)

static func _observation_lines(n, groups: Array, audience: String, speech_act: String, preceded: bool, first_relation: String = "independent") -> Array:
	var intents: Array = []
	for i in range(groups.size()):
		var group = groups[i]
		var statement: String = group.before + Observations.spoken_list(group.names) + group.after
		var intent: Dictionary = {"kind": "report", "statement": statement, "event_id": JSON.stringify([group.scene, group.names])}
		if i == 0 and first_relation != "independent":
			intent["relation"] = first_relation
		intents.append(intent)
	var rendered = Dialogue.compose_turn(n.id, intents, {"audience": audience, "speech_act": speech_act,
		"trust": n.trust, "pressure": n.pressure}, n.dialogue_memory, preceded)
	# Keep the established one-line-per-fact-kind presentation; cards stay separate.
	var kinds = {}
	for i in range(groups.size()):
		if not kinds.has(groups[i].kind): kinds[groups[i].kind] = []
		kinds[groups[i].kind].append(rendered[i].text)
	var lines: Array = []
	for texts in kinds.values(): lines.append(say(n, " ".join(PackedStringArray(texts))))
	return lines


## Deterministic reaction when shown or pressed with a structured crime-scene trace.
## Minions never volunteer their Demon when suggesting someone else who fits a prong,
## and any haunt pointer reveals only a true town haunt via profile_haunts (never lying about haunts).
static func react_to_trace(w, n, card: Dictionary, known_haunts: Dictionary = {}, already_counted: bool = false) -> Dictionary:
	if not already_counted:
		on_question(w, n)
	var lines: Array = []
	var profile_haunts: Array = []
	var tr_check = {
		"trace_family": card.get("trace_family", ""),
		"locs": card.get("locs", []),
		"home_block": card.get("trace_home_block", ""),
		"evening_block": card.get("trace_evening_block", ""),
		"victim": card.get("victim", ""),
		"day": card.get("day", -1),
	}
	var fits_me: bool = w.actor_fits_trace_truth(n, tr_check)
	var is_minion: bool = n.is_evil() and n.id != w.demon_id
	# Pick a deterministic deflection pointer if willing (gossip + trust) or deflecting off oneself.
	var share_score: float = 0.35 * trait_of(n, "gossip") + 0.45 * n.trust + (0.20 if fits_me else 0.0)
	var pointer_target = null
	var pointer_loc: String = ""
	var pointer_is_haunt: bool = false
	if share_score >= 0.38:
		var candidates: Array = w.living().filter(func(o):
			if o.id == n.id or o.id == card.get("victim", ""):
				return false
			if is_minion and o.id == w.demon_id:
				return false
			return w.actor_fits_trace_truth(o, tr_check))
		# Rank candidates deterministically by listener suspicion (or cover suspicion for evil).
		candidates.sort_custom(func(a, b):
			var sa: float = _mind().susp(n.shadow if n.is_evil() and n.shadow != null else n, a.id)
			var sb: float = _mind().susp(n.shadow if n.is_evil() and n.shadow != null else n, b.id)
			if not is_equal_approx(sa, sb):
				return sa > sb
			return a.id < b.id)
		if not candidates.is_empty():
			pointer_target = candidates[0]
			if card.get("trace_family", "") == "locations":
				var locs: Array = card.get("locs", [])
				if pointer_target.work in locs:
					pointer_loc = pointer_target.work
				else:
					var already: Array = known_haunts.get(pointer_target.id, [])
					for h in pointer_target.haunts:
						if h in locs and not (h in already):
							pointer_loc = h
							pointer_is_haunt = true
							break
					if pointer_loc == "":
						for h in pointer_target.haunts:
							if h in locs:
								pointer_loc = h
								pointer_is_haunt = true
								break
	if fits_me:
		match card.get("trace_family", ""):
			"locations":
				var places: String = C.loc_list_or(card.get("locs", []))
				var item_lbl: String = card.get("item_label", "that")
				lines.append(say_voiced(n, "trace_fit_locations", "Plenty of us go by %s every week. Finding %s hardly pins a murder on me." % [places, item_lbl], {"places": places, "item": item_lbl}))
			"quarter":
				var hb_lbl: String = C.block_name(card.get("trace_home_block", "square"))
				var eb_lbl: String = C.block_name(card.get("trace_evening_block", "square"))
				lines.append(say_voiced(n, "trace_fit_quarter", "Half the village either lives on %s or walks %s by evening. That's thin ground to accuse me on." % [hb_lbl, eb_lbl], {"home_block": hb_lbl, "evening_block": eb_lbl}))
			"connection":
				var vname: String = w.by_id[card.get("victim", "")].name if w.by_id.has(card.get("victim", "")) else "them"
				lines.append(say_voiced(n, "trace_fit_connection", "Knowing %s or living near their lane doesn't make me a killer." % vname, {"victim": vname}))
	else:
		lines.append(say_voiced(n, "trace_not_me", "That doesn't point to my habits, at least."))
	if pointer_target != null:
		if pointer_loc != "" and pointer_is_haunt:
			var h_loc_lbl: String = w.loc_name(pointer_loc)
			lines.append(say_voiced(n, "trace_point_haunt", "If you're checking %s, look to %s; they often spend their free hours there." % [h_loc_lbl, pointer_target.name], {"loc": h_loc_lbl, "target": pointer_target.name}))
			profile_haunts.append({"subject": pointer_target.id, "loc": pointer_loc})
		elif pointer_loc != "":
			var w_loc_lbl: String = w.loc_name(pointer_loc)
			lines.append(say_voiced(n, "trace_point_work", "%s works at %s; that fits this trace as well as anyone." % [pointer_target.name, w_loc_lbl], {"loc": w_loc_lbl, "target": pointer_target.name}))
		elif card.get("trace_family", "") == "quarter" and pointer_target.home_block == card.get("trace_home_block", ""):
			var q_blk_lbl: String = C.block_name(pointer_target.home_block)
			lines.append(say_voiced(n, "trace_point_quarter", "%s lives over on %s, if you're following that trail." % [pointer_target.name, q_blk_lbl], {"block": q_blk_lbl, "target": pointer_target.name}))
		elif card.get("trace_family", "") == "connection":
			lines.append(say_voiced(n, "trace_point_connection", "%s had ties around that cottage as well, if you're asking around." % pointer_target.name, {"target": pointer_target.name}))
	w.dlog.add("trace_reaction", n.id, pointer_target.id if pointer_target != null else "", {"card": card.get("n", 0), "fits_self": fits_me, "minion_guarded": is_minion, "haunt_shared": pointer_loc if pointer_is_haunt else ""})
	return {"lines": lines, "facts": [], "profile_haunts": profile_haunts}


## What a "home all night" lie hid, in plain words for the reveal.
static func _hidden_thing(w, n) -> String:
	if n.is_evil():
		return "their evil work"
	var kind: String = str(n.secret.get("kind", ""))
	if kind == "":
		return "their gift as the %s" % C.role_name(n.role)
	if n.secret.has("text"):
		return "that %s %s" % [n.name, n.secret["text"]]
	return "a secret"
