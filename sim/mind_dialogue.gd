## One-on-one player conversation and pressing mechanics for NPCs: hint follow-ups,
## pressing with evidence or deductions, sleepwalking excuses, question fatigue,
## greeting cues, trait reveals, gift disclosure tiers, fear/protection/confidence
## requests, and answers for gifts, night whereabouts, daytime sightings, and opinions.
##
## Extracted from `sim/mind.gd`; `Mind` retains forwarding wrappers so callers can
## invoke either `Mind.<fn>` or `MindDialogue.<fn>`.
extends RefCounted

const WorkshopLedger = preload("res://workshop/shared_ledger.gd")
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Gifts = preload("res://sim/gifts.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const Observations = preload("res://sim/dialogue_observations.gd")

static var _mind_script


static func _mind():
	if _mind_script == null:
		_mind_script = load("res://sim/mind.gd")
	return _mind_script

## The player follows up on a hint ("what's your reason?"). They may still keep it back;
## if they tell, it comes out as their gift and the reading (as in answer_gift at full
## disclosure), and if their gift isn't public they ask you to keep it to yourself: the
## cards come back marked confidential, and using them at the meeting breaks your word.
## Returns {lines, facts}.
static func has_live_hint(w, n) -> bool:
	return n.hints.keys().any(func(k): return w.by_id.has(k) and w.by_id[k].alive)

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
		var count: int = n.dialogue_memory.get("empty_hint_replies", 0)
		n.dialogue_memory["empty_hint_replies"] = count + 1
		lines.append(say(n, "[PH] I've nothing more to tell you." if count % 2 == 0 else "[PH] I've no further reason to give you."))
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
	var r = answer_gift(w, n, 4, false)
	lines.append(say(n, "[PH] All right. You asked, so here's why I suspect %s." % t.name))
	lines.append_array(r["lines"])
	var facts: Array = r["facts"]
	if not n.claim_public:
		n.dialogue_memory["confidence_requested"] = true
		lines.append(say(n, "[PH] But keep this between us. Don't bring it up at the meeting; not yet."))
		for f in facts:
			if f.get("source", "") == n.id and f.get("kind", "") in ["info", "claim"]:
				f["confidential"] = n.id
	n.hints.erase(target)
	return {"lines": lines, "facts": facts}

## Keeping a hinted reason back. Good and evil draw from the same lines, so stalling ("give
## me a day or two") is no tell: a cautious good NPC stalls as often as an evil one with
## nothing behind its hint.
static func _hint_decline(w, n, t) -> Dictionary:
	if w.decision_roll(n, "hint_decline_wording", 0.5):
		return say_voiced(n, "hint_stall_watch", "Not yet. Give me a day or two, and watch %s." % t.name, {"subject": t.name})
	return say_voiced(n, "hint_stall_wait", "I said I'm not ready, and I'm not. Ask me again another time.")


# ---------------------------------------------------------------- pressing

## "press <card>": confront someone with a card or deduction about them. It raises the
## pressure on them (which loosens tongues and secrets) and asks them to answer it: where
## they were that night, or what their gift really is. Anyone with something to hide may
## show nerves, and so, less often, may an innocent who's simply rattled.
static func press(w, n, card: Dictionary, known_haunts: Dictionary = {}) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var c: Dictionary = card.get("conclusion", {})
	var subj: Array = card.get("subject", [])
	var pair: Array = card.get("data", {}).get("pair", [])
	var trace_fits_me: bool = card.get("kind") == "trace" and card.get("trace_family", "") != "" and w.actor_fits_trace_truth(n, {"trace_family": card.get("trace_family", ""), "locs": card.get("locs", []), "home_block": card.get("trace_home_block", ""), "evening_block": card.get("trace_evening_block", ""), "victim": card.get("victim", ""), "day": card.get("day", -1)})
	var about_me = trace_fits_me or n.id in subj or c.get("a", "") == n.id or n.id in pair or (card.get("kind") == "claim" and card.get("source") != n.id and n.claim_public and card.get("role") == n.claimed_role)
	if not about_me:
		on_question(w, n)
		lines.append(say(n, "[PH] What has that to do with me?"))
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
	var naming_me = kind == "info" and C.has_role_def(card.get("role", "")) and C.role_def(card.get("role", "")).names_good_role_in_pair() and n.id in pair  # "one of you two is the X"
	var counter = kind == "claim" and card.get("source", "") != n.id and n.claim_public and card.get("role", "") == n.claimed_role
	var strength = 0.6 if kind == "deduction" else clampf(card_strength(w, card, n), 0.3, 1.0)
	if naming_me:
		strength = 0.5
	# Hiding something this card touches?
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var hiding = n.is_evil() or (night >= 0 and not n.secret.is_empty()) or (night < 0 and n.max_tier < 3 and not n.claim_public and C.ROLES[mine]["kind"] != "evil")
	var p_nerves = (Tuning.Dialogue.PRESS_NERVES_HIDING if hiding else Tuning.Dialogue.PRESS_NERVES_HONEST) * (1.0 - trait_of(n, "composure")) * strength
	var nervous = w.decision_roll(n, "pressed_nerves", p_nerves, {"composure": trait_of(n, "composure"), "evidence_strength": strength, "hiding": hiding})
	w.dlog.think(n.id, "pressed", "Pressed with '%s' (strength %.2f; hiding %s; nerves p=%.2f -> %s)." %
		[card.get("text", ""), strength, str(hiding), p_nerves, str(nervous)], {"night": night, "naming_me": naming_me, "counter": counter})
	n.pressure += Tuning.Dialogue.PRESS_PRESSURE_GAIN * strength
	if not naming_me and not n.is_evil():
		set_trust(w, n, n.trust - (0.03 + 0.06 * trait_of(n, "privacy")), "the Demonologist pressed me with evidence")
	if nervous:
		lines.append("%s %s" % [n.name, ["looks away a moment too quickly.", "shifts uneasily.", "goes a little pale.", "fumbles for an answer."][w.rng.randi_range(0, 3)]])
	if counter:
		on_question(w, n)
		var rival = w.by_id[card["source"]]
		var accusation: Dictionary = say(n, "[PH] I am the %s. If %s says otherwise, %s is lying." % [C.role_name(n.claimed_role), rival.name, rival.name])
		accusation["expression"] = "harsh"
		accusation["expression_strength"] = 2
		lines.append(accusation)
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
	if kind == "trace" and card.get("trace_family", "") != "":
		var tr_reply: Dictionary = react_to_trace(w, n, card, known_haunts, true)
		lines += tr_reply["lines"]
		facts += tr_reply["facts"]
		var pressed_tr: Dictionary = _challenged(n, {"lines": lines, "facts": facts, "profile_haunts": tr_reply.get("profile_haunts", [])}, card)
		pressed_tr["dialogue_exchange"] = {"action": "challenge_trace", "subject": n.id}
		return pressed_tr
	if kind == "deduction":
		var trace_supports: Array = card.get("support_cards", []).filter(func(sc): return sc.get("kind", "") == "trace")
		if trace_supports.size() >= 2:
			on_question(w, n)
			lines.append(say_voiced(n, "pressed_multi_trace_case", "You're stringing scraps from half the village together to hang me. Anyone walking that road in the dark could have tracked those in or left them to frame me."))
			var pressed_multi: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card)
			pressed_multi["dialogue_exchange"] = {"action": "challenge_trace_case", "subject": n.id}
			return pressed_multi
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
	var rdef = C.role_def(n.role)
	if rdef != null and rdef.has_gift_outing(n, night): return true
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
	var line = say_voiced(n, "sleepwalk_excuse", "I don't remember going out. But I've been known to sleepwalk.")
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
	var statement = ""
	for fact in response.facts:
		if fact.get("kind", "") == "alibi" and fact.get("source", "") == n.id and n.id in fact.get("subject", []):
			statement = ("That sighting doesn't change where I was: at home %s." if alternate else "I was at home %s. I stand by that account.") % when
			text = ("[PH] " + statement) if alternate else Dialogue.voice_line(n.id, "pressed_home_stand", statement, {"when": when})
			break
		if fact.get("kind", "") == "secret" and fact.get("owner", "") == n.id:
			var sec_me: String = n.secret.get("me", n.secret["text"])
			statement = ("I wasn't there on evil business. I %s. Keep that between us." if alternate else "All right: I %s. That's why I was out; please keep it quiet.") % sec_me
			text = ("[PH] " + statement) if alternate else Dialogue.voice_line(n.id, "confess_secret_private", statement, {"secret": sec_me})
			break
		if fact.get("kind", "") == "refusal" and fact.get("source", "") == n.id:
			statement = "I've nothing more to say about that night." if alternate else "That sighting doesn't give you the right to demand my whereabouts."
			text = ("[PH] " + statement) if alternate else Dialogue.voice_line(n.id, "pressed_refusal_stand", statement)
			break
		var f_role: String = fact.get("role", "") if fact.get("kind", "") == "info" else ("nightwatch" if fact.get("watch_claim", false) else (fact.get("duty", "") if fact.get("duty_claim", false) else ""))
		if f_role != "" and C.has_role_def(f_role):
			statement = C.role_def(f_role).pressed_night_line(w, n, fact, night, when, alternate, C.block_name)
			if statement != "":
				text = "[PH] " + statement
				break
	if text != "":
		for line in response.lines:
			if line is Dictionary and line.get("speaker", "") == n.id:
				line.text = text
				line["statement"] = statement
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
	if not w.decision_roll(n, "greeting_attitude_visible", (1.0 - trait_of(n, "composure")) * 0.9, {"composure": trait_of(n, "composure")}, "", "<="):
		w.dlog.think(n.id, "cue", "Composure hides their attitude (trust %.2f)." % n.trust)
		return ""
	var t: float = n.trust
	var cue = ""
	if t < 0.3:
		cue = "%s eyes you warily. \"[PH] What do you want now?\"" % n.name
	elif t < 0.5:
		cue = "%s gives you a guarded nod." % n.name
	elif t < 0.7:
		cue = "%s greets you civilly enough." % n.name
	else:
		cue = "%s brightens when they see you. \"[PH] Ah, Demonologist. Sit.\"" % n.name
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

## Disclosure tier the NPC is willing to reach right now (1..4).
static func _target_tier(w, n, trace_id: int = 0) -> int:
	# One mood per NPC per day (a fixed daily sample, like fear), so asking again the same
	# day can't fish for a better roll (Oct 30, docs/social_trust_pass.md).
	var jitter: float = (_day_roll(n.id, w.day, 0x0BE7) - 0.5) * 2.0 * Tuning.Dialogue.OPENNESS_JITTER
	var openness = (1.0 - trait_of(n, "privacy")) * 1.0 + n.trust * 1.2 + n.pressure * 0.6 * (1.0 - 0.5 * trait_of(n, "composure")) \
		+ 0.1 * (w.day - 1) + Tuning.Dialogue.OPENNESS_BASE_OFFSET + jitter
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
		"parts": {"privacy": (1.0 - trait_of(n, "privacy")) * 1.0, "trust": n.trust * 1.2,
			"pressure": n.pressure * 0.6 * (1.0 - 0.5 * trait_of(n, "composure")),
			"day": 0.1 * (w.day - 1), "base": -0.72, "jitter": jitter}.merged(gift_terms),
		"jitter_min": -Tuning.Dialogue.OPENNESS_JITTER, "jitter_max": Tuning.Dialogue.OPENNESS_JITTER, "thresholds": [{"above": 0.75, "tier": 4}, {"above": 0.45, "tier": 3},
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
	var p: float = Tuning.Dialogue.FEAR_BASE + Tuning.Dialogue.FEAR_COMPOSURE_SCALE * (1.0 - trait_of(n, "composure")) - Tuning.Dialogue.FEAR_PRESSURE_SCALE * n.pressure - paranoia(w, n)
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
		var walks: bool = n.role == "demon" or C.ROLES[n.role].get("night_walk", false)
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
	if n.request_day == w.day or n.claim_public or n.protect_lock or n.trust < 0.45:
		w.observe_decision(n, "protection_request", false, {"gate": "request already made today, claim public, promised protection, or trust < 0.45", "inputs": {"trust": n.trust, "request_day": n.request_day, "day": w.day, "claim_public": n.claim_public, "protect_lock": n.protect_lock}})
		return {}
	var kind: String = protection_kind(w, n)
	if kind == "":
		return {}
	var p: float = clampf(0.35 + (n.trust - 0.45) * 1.5, 0.0, 0.85)
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
	if n.request_day == w.day or n.claim_public or n.trust < 0.4:
		w.observe_decision(n, "confidence_request", false, {"gate": "request already made today, claim public, or trust < 0.4", "inputs": {"trust": n.trust, "request_day": n.request_day, "day": w.day, "claim_public": n.claim_public, "protect_lock": n.protect_lock}})
		return {}
	var p: float = clampf(0.15 + (n.trust - 0.5) * 0.8 + (0.5 - trait_of(n, "composure")) * 0.5, 0.0, 0.5)
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
	return answer_gift(w, n, tier, false)

static func answer_gift(w, n, force_tier: int = 0, count_question: bool = true) -> Dictionary:
	var id = w.dlog.decision(n.id, "gift_disclosure", "start", null,
		{"force_tier": force_tier, "prior_tier": n.max_tier, "public": n.claim_public,
			"trust": n.trust, "pressure": n.pressure, "questions_today": n.pressed_today, "count_question": count_question})
	var result = _answer_gift_impl(w, n, force_tier, id, count_question)
	if result.facts.any(func(f): return f.get("kind", "") == "refusal"):
		result["refusal_line"] = result.lines.size() - 1
		_append_distrust(w, n, result.lines)
	w.dlog.decision(n.id, "gift_disclosure", "outcome", result["facts"],
		{"final_tier": n.max_tier, "told_readings": n.told_readings,
			"role_claim": n.claimed_role, "public": n.claim_public}, "", id)
	return result

static func _answer_gift_impl(w, n, force_tier: int, trace_id: int, count_question: bool = true) -> Dictionary:
	if count_question:
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
			lines.append(say(n, "[PH] A gift? No, nothing like that. I'm only the %s." % n.occupation))
			facts.append({"kind": "claim", "subject": [n.id], "role": "none", "source": n.id, "private": true,
				"text": "%s told you privately they have no gift." % n.name})
		elif _afraid(w, n):
			var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true, "fear": true,
				"text": "%s won't say whether they have a gift: afraid it would make them the demon's next mark." % n.name}
			var ask: Dictionary = _protection_request(w, n, refusal)
			if not ask.is_empty():
				n.max_tier = maxi(n.max_tier, 1)
				return {"lines": [ask["line"]], "facts": [], "request": ask}
			lines.append(say_voiced(n, "fear_gift_refusal", "If I say what I am, I'll be dead by morning. Ask me again when it's safer."))
			facts.append(refusal)
		else:
			var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true,
				"text": "%s refused to say whether they have a gift." % n.name}
			var ask: Dictionary = _confidence_request(w, n, 3, refusal)
			if not ask.is_empty():
				n.max_tier = maxi(n.max_tier, 1)
				return {"lines": [ask["line"]], "facts": [], "request": ask}
			lines.append(gift_refusal(n))
			facts.append(refusal)
		n.max_tier = maxi(n.max_tier, 1)
		return {"lines": lines, "facts": facts}
	if tier == 2:
		var pk: String = C.package_of(role)
		if evil:
			w.dlog.think(n.id, "lie", "Evil: gives a hint matching bluff %s." % role, {"lie": true})
		lines.append(say(n, "[PH] " + C.HINT_PACKAGES[pk]["text"] + " That's all I'll say."))
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
		if contextual != "":
			lines.append(say(n, contextual))
		elif w.day <= 1 and w.phase == C.MORNING:
			var early_fb: String = "I'll trust you with this. I'm the %s." % C.role_name(role)
			var early_voiced: String = Dialogue.voice_line(n.id, "private_reveal_early", "", {"role": C.role_name(role)})
			if early_voiced != "":
				var early_line: Dictionary = say(n, early_voiced)
				early_line["statement"] = early_fb
				lines.append(early_line)
			else:
				lines.append(say_voiced(n, "private_reveal", early_fb, {"role": C.role_name(role)}))
		else:
			lines.append(say_voiced(n, "private_reveal", "I'll trust you with this. I'm the %s." % C.role_name(role), {"role": C.role_name(role)}))
		if not evil and C.ROLES[role].get("night_walk", false) and not n.lied_nights.is_empty():
			# The lie they told you about that night, owned now it has a reason.
			var nights: Array = n.lied_nights.map(func(x): return C.night_name(x))
			var nights_str: String = " and ".join(PackedStringArray(nights.map(func(x): return ("on " + x) if x.begins_with("night") else x)))
			lines.append(say_voiced(n, "own_night_lie", "So yes: I was out %s, whatever I told you. I wasn't ready to tell you why." % nights_str, {"nights": nights_str}))
			w.dlog.think(n.id, "admit", "Owns the whereabouts lie(s) now the gift is out: nights %s." % str(n.lied_nights))
			n.lied_nights.clear()
	else:
		lines.append(say_voiced(n, "repeat_gift_confirm", "As you know, I'm the %s." % C.role_name(role), {"role": C.role_name(role)}))
	facts.append({"kind": "claim", "subject": [n.id], "role": role, "source": n.id, "private": not n.claim_public,
		"text": "%s %s the %s." % [n.name, "claims to be" if n.claim_public else "told you privately they are", C.role_name(role)]})
	if first_time:
		set_trust(w, n, n.trust + 0.03, "shared their gift with the Demonologist")
	n.max_tier = maxi(n.max_tier, 3)
	var rdef = C.role_def(role)
	if rdef != null:
		var custom: Dictionary = rdef.answer_gift_custom(w, n, first_time, tier, lines, facts, _mind(), C.night_name, C.block_name)
		if not custom.is_empty():
			return custom
	if not C.has_readings(role):
		lines.append(say_voiced(n, "passive_gift_note", "My gift doesn't tell me things. It only does what it does."))
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
	if not first_time and not readings.is_empty(): lines.pop_front()
	var reports = info_lines(w, n, readings, "player", not lines.is_empty())
	if not reports.is_empty():
		lines.append(say(n, " ".join(PackedStringArray(reports.map(func(line): return line.text)))))
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
			lines.append(say_voiced(n, "withhold_readings_trust", "I've told you what I knew before. The rest I'll keep, for now."))
			w.dlog.think(n.id, "withhold", "Trust fell; withholding %d newer reading(s) from the player." % held)
		elif afraid:
			ask = _protection_request(w, n, refusal)
			if ask.is_empty():
				lines.append(say(n, "[PH] If word gets round what %s, I'll be dead by morning. Not yet." % ("the rest of my readings show" if not readings.is_empty() else "my gift has shown me")))
		else:
			ask = _confidence_request(w, n, 4, refusal)
			if ask.is_empty():
				lines.append(say_voiced(n, "withhold_readings_privacy", "What it's shown me, I'll keep to myself for now."))
		if not ask.is_empty():
			lines.append(ask["line"])
			return {"lines": lines, "facts": facts, "request": ask}
		facts.append(refusal)
	elif n.info_log.is_empty():
		lines.append(say_voiced(n, "empty_readings", "It hasn't shown me anything yet."))
	return {"lines": lines, "facts": facts}

## How much they share of what they saw of others: Gossip (and pressure) set the count.
static func _gossip_share(w, n, topic: String) -> int:
	# No Gossip cutoff (Oct 30): the least talkative still share one thing.
	var g = trait_of(n, "gossip")
	var count = 1 + int(round((g + n.pressure * 0.5) * 3.0))
	w.dlog.decision(n.id, "gossip_share", "outcome", count,
		{"topic": topic, "gossip": g, "pressure": n.pressure})
	return count

## Whose door a Warden (or an evil Warden bluff) says they guarded on night nd. A bluff
## invents one on the block they were really on (or anyone, if they stayed in), once per
## night, so the story stays the same however often they're asked.
static func warden_door(w, n, nd: int) -> String:
	return C.role_def("warden").warden_door(w, n, nd)

static func _guard_fact(w, n, nd: int, guarded: String) -> Dictionary:
	return C.role_def("warden").guard_fact(w, n, nd, guarded, C.block_name)

## Whose hearth a Medium's reading (real, or an evil bluff's fake) for night nd names.
static func _hearth_dead(w, n, nd: int):
	return C.role_def("medium").hearth_dead(w, n, nd)

## The block of the hearth an evil Medium bluff's fake reading for night nd names ("" if none).
static func _bluff_hearth(w, n, nd: int) -> String:
	return C.role_def("medium").bluff_hearth(w, n, nd)

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
	var refused_whereabouts = false
	var how = "window"
	# A claimed night-walking gift keeps its story: an evil bluff always tells the duty,
	# a real holder tells it whenever they were actually out (Case 22485: a claimed
	# Lamplighter must never say "home all night").
	if C.has_role_def(n.claimed_role) and C.role_def(n.claimed_role).uses_night_duty_alibi(w, n, nd, was_out):
		var duty_res: Dictionary = C.role_def(n.claimed_role).night_duty_alibi(w, n, nd, was_out, block, _mind(), C.block_name)
		lines.append(duty_res["line"])
		facts.append(duty_res["fact"])
		vantage = duty_res["vantage"]
		how = duty_res["how"]
	elif not was_out:
		lines.append(home_alibi(w, n, nd))
		facts.append(_alibi_home(n, nd))
		vantage = n.home_block
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
			lines.append(say_voiced(n, "confess_secret_private", "...I wasn't home. I %s. Please, keep it quiet." % n.secret.get("me", n.secret["text"]), {"secret": n.secret.get("me", n.secret["text"])}))
			vantage = block
			how = "street"
			facts.append({"kind": "secret", "subject": [n.id], "owner": n.id, "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
				"secret_kind": n.secret.get("kind", ""), "mod": "lovers" if n.secret.get("kind", "") == "lover" else "",
				"text": "%s confessed they were out on %s on night %d: %s %s." % [n.name, C.block_name(block), nd, n.name, n.secret["text"]]})
		else:
			var prior_account: Dictionary = n.dialogue_memory.get("night_accounts", {}).get(str(nd), {})
			var prior_kind: String = prior_account.get("kind", "")
			var bold: bool = (prior_kind == "alibi") if prior_kind in ["alibi", "refusal"] else decide(w, n, "lie_or_stonewall", {"confidence": (trait_of(n, "confidence") - 0.5) * 1.5,
				"privacy_stonewalls": -(trait_of(n, "privacy") - 0.5) * 0.6}, "Hiding (%s): lie outright rather than stonewall?" % hiding)
			if bold:
				w.dlog.think(n.id, "lie", "Hiding (%s): was on %s, claims to have been home." % [hiding, block], {"lie": true})
				if not n.is_evil() and not (nd in n.lied_nights):
					n.lied_nights.append(nd)
				lines.append(home_alibi(w, n, nd))
				facts.append(_alibi_home(n, nd))
				vantage = n.home_block
			else:
				w.dlog.think(n.id, "stonewall", "Hiding (%s): refuses to say where they were." % hiding)
				refused_whereabouts = true
				lines.append(whereabouts_refusal(n, nd))
				_append_distrust(w, n, lines)
				facts.append({"kind": "refusal", "subject": [n.id], "source": n.id, "day": nd, "phase": C.NIGHT,
					"text": "%s refused to say where they were on night %d." % [n.name, nd]})
	var accounts: Dictionary = n.dialogue_memory.get("night_accounts", {})
	accounts[str(nd)] = facts[0].duplicate(true)
	n.dialogue_memory["night_accounts"] = accounts
	# Asking for whereabouts must not disclose a watch result the gift question withheld.
	if C.has_role_def(n.claimed_role):
		var withhold_msg: String = C.role_def(n.claimed_role).withholds_night_sightings(n, nd, _mind())
		if withhold_msg != "":
			lines.append(say_voiced(n, "nightwatch_withhold", withhold_msg))
			return {"lines": lines, "facts": facts}
	var seen: Array = n.beliefs.filter(func(b): return b["kind"] in ["saw", "stayed_in"] and b["day"] == nd and b["phase"] == C.NIGHT)
	var reported: Array = []
	for b in seen:
		if n.is_evil() and Evil.is_teammate(w, n, b["who"]) and b["kind"] == "saw":
			w.dlog.think(n.id, "lie", "Evil: omits seeing teammate %s at night." % b["who"])
			continue
		if vantage != "" and b["block"] != vantage:
			# Seen from somewhere they say they weren't: telling it would give the lie away.
			# Most keep quiet; a rattled few let it slip.
			var slip = 0.25 * (1.0 - trait_of(n, "composure")) + 0.15 * n.pressure
			if not w.decision_roll(n, "whereabouts_slip", slip, {"composure": trait_of(n, "composure"), "pressure": n.pressure}, b["who"]):
				w.dlog.think(n.id, "omit", "Leaves out seeing %s on %s: they say they were on %s." % [b["who"], b["block"], vantage])
				continue
			w.dlog.think(n.id, "slip", "Lets slip seeing %s on %s, though they say they were on %s (p=%.2f)." % [b["who"], b["block"], vantage, slip])
		reported.append(b)
	var ov_sight: Dictionary = C.role_def(n.claimed_role).override_night_sightings(w, n, nd) if C.has_role_def(n.claimed_role) else {}
	if ov_sight.get("handled", false):
		reported = ov_sight["reported"]
	elif n.is_evil() and vantage != "":
		var fake = Evil.fake_night_sighting(w, n, nd, vantage, how)
		if fake != null:
			reported.append(fake)
	var slips: Array = []
	if refused_whereabouts:
		var safe: Array = []
		for observation in reported:
			if observation.get("block", "") != n.home_block:
				# Same slip mechanic as an account contradicted by an observation.
				# Discretionary Gossip/friend filters have been replaced by the
				# direct-answer willingness roll; the privacy gate still applies.
				var slip = 0.25 * (1.0 - trait_of(n, "composure")) + 0.15 * n.pressure
				if not w.decision_roll(n, "refused_whereabouts_slip", slip, {"composure": trait_of(n, "composure"), "pressure": n.pressure}, observation.who):
					w.dlog.think(n.id, "omit", "Withholds seeing %s on %s after refusing whereabouts." % [observation.who, observation.block])
					continue
				slips.append(observation)
				w.dlog.think(n.id, "slip", "Lets slip seeing %s on %s after refusing whereabouts (p=%.2f)." % [observation.who, observation.block, slip])
			safe.append(observation)
		reported = safe
	if not reported.is_empty():
		var shares = w.decision_roll(n, "direct_night_sightings", 0.95, {"eligible_sightings": reported.size()})
		w.dlog.decision(n.id, "direct_night_sightings", "outcome", shares, {"p": 0.95, "eligible": reported.size()})
		if not shares:
			lines.append(say_voiced(n, "night_sightings_refuse", "I'm not ready to discuss who I saw."))
			return {"lines": lines, "facts": facts}
	if reported.is_empty() and not (was_out and not n.is_evil()):
		lines.append(say_voiced(n, "night_saw_nobody", "I saw nobody."))
	var groups: Array = []
	for b in reported:
		var r = sighting_report(w, n, b, nd)
		if b in slips:
			var who: String = w.by_id[b.who].name
			var detail = "go in for the night" if b.kind == "stayed_in" else ("leave their house" if b.get("detail", "") == "leaving_home" else "out")
			var end = ", and they never came out" if b.kind == "stayed_in" else ""
			r.line.text = "…though I did see %s %s on %s on night %d%s, not that I was there." % [who, detail, C.block_name(b.block), nd, end]
			r.observation.before = "…though I did see "
			r.observation.after = " %s on %s on night %d%s, not that I was there." % [detail, C.block_name(b.block), nd, end]
			r.observation.scene["slip"] = true
		_add_observation(groups, r.observation)
		facts.append(r["fact"])
		n.told_to["player|saw:%s:%d" % [b.who, nd]] = true
		n.told_to["player|" + fact_id(r.fact)] = true
	lines.append_array(_observation_lines(n, groups, "player", "answer", not lines.is_empty()))
	return {"lines": lines, "facts": facts}

## A reading the player already heard, privately or at a meeting.
static func reading_disclosed(n, entry: Dictionary) -> bool:
	var index: int = n.info_log.find(entry)
	return not entry.get("disowned", false) and (entry.get("shared", false) or (index >= 0 and index < n.told_readings))

## An evil member's made-up Night Watch report for night nd, or {}.
static func _fake_watch_entry(n, nd: int) -> Dictionary:
	return C.role_def("nightwatch").fake_watch_entry(n, nd)

## One night sighting (or a neighbour seen going in for the night), as said and as a card.
## From a window, they can only speak for their own street.
static func sighting_report(w, n, b: Dictionary, nd: int) -> Dictionary:
	var who = w.by_id[b["who"]]
	var bn = C.block_name(b["block"])
	if b["kind"] == "stayed_in":
		return {"line": say(n, "From my window on night %d, I saw %s go in for the night, and they never came out." % [nd, who.name]),
			"observation": {"kind": "alibi", "subject": who.name, "scene": _observation_scene(n, b, nd),
				"before": "From my window on night %d, I saw " % nd, "after": " go in for the night, and they never came out."},
			"fact": {"kind": "alibi", "subject": [who.id], "home": true, "witness": true, "day": nd, "phase": C.NIGHT, "source": n.id, "block": b["block"],
				"text": "%s says they saw %s go home for the night on night %d and not come out (from their window, %s)." % [n.name, who.name, nd, bn]}}
	var before = ""
	var after = ""
	var how = ""
	if b.get("how", "street") == "window":
		how = " (from their window)"
		if b.get("detail", "") == "leaving_home":
			before = "From my window, I saw "
			after = " leave their house on night %d." % nd
		else:
			before = "From my window, I saw "
			after = " out in the street on night %d." % nd
	else:
		before = "I did see "
		after = " out on %s on night %d." % [bn, nd]
	return {"line": say(n, before + who.name + after),
		"observation": {"kind": "sighting", "subject": who.name, "scene": _observation_scene(n, b, nd), "before": before, "after": after},
		"fact": {"kind": "sighting", "subject": [who.id], "block": b["block"], "day": nd, "phase": C.NIGHT, "source": n.id, "how": b.get("how", "street"),
			"text": "%s says they saw %s on %s on night %d%s." % [n.name, who.name, bn, nd, how]}}

## Only observations from this phase are redundant when the named person is
## visibly beside the player now. Older memories and other spots on the block matter.
static func sighting_is_here(w, b: Dictionary, who: String, near_loc: String = "") -> bool:
	var here: String = near_loc if near_loc != "" else w.player_loc
	return here != "" and b.get("day", -1) == w.day and b.get("phase", -1) == w.phase \
		and w.by_id.has(who) and w.by_id[who].loc == here

## Who they've seen around by day. when: "" (recently: today and yesterday), "morning",
## "afternoon", "evening" (today) or "yesterday". near_loc: the exact place where the player is right now;
## people seen there this phase are left out (you can see them yourself), and memory reaches
## further back instead.
## "Where were you, and who did you see?" for a daytime frame: "" (earlier today, up to
## now), "morning" / "afternoon" / "evening" (today), "yesterday", or "yesterday
## morning" / "yesterday afternoon" / "yesterday evening". They say where they were
## (daytime whereabouts are open to anyone's eyes), then who they saw: as many as their
## memory (Insight) holds and their Gossip lets them share.
static func answer_today(w, n, when: String = "", near_loc: String = "", seen_pairs: Dictionary = {}) -> Dictionary:
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
		var refuse_prefix: String = (was_s + ". ") if was_s != "" else ""
		var refuse_tail: String = Dialogue.voice_line(n.id, "day_sightings_refuse", "Who else goes where is none of my business.")
		var refuse_line: Dictionary = say(n, refuse_prefix + refuse_tail)
		refuse_line["statement"] = refuse_prefix + "Who else goes where is none of my business."
		lines.append(refuse_line)
		return {"lines": lines, "facts": facts}
	# Memory: they recall only their most recent few sightings (more with Insight), one per person.
	var memory = 2 + int(round(trait_of(n, "insight") * 4.0))
	var before: Array = n.beliefs.filter(func(b): return b["kind"] == "saw" and b["phase"] != C.NIGHT and in_frame.call(b))
	var seen: Array = before.filter(func(b): return not sighting_is_here(w, b, b["who"], near_loc))
	if seen.is_empty() and not before.is_empty():
		var here_prefix: String = (was_s + ". ") if was_s != "" else ""
		var here_tail: String = Dialogue.voice_line(n.id, "day_only_here", "Nobody but who you can see around you for yourself.")
		var here_line: Dictionary = say(n, here_prefix + here_tail)
		here_line["statement"] = here_prefix + "Nobody but who you can see around you for yourself."
		lines.append(here_line)
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
		var empty_canonical: String = (was_s + ", and saw nobody worth mentioning.") if was_s != "" else "Nobody worth mentioning."
		var empty_spoken: String = empty_canonical
		if Dialogue.has_voice(n.id):
			var saw_nobody_tail: String = Dialogue.voice_line(n.id, "day_saw_nobody", "saw nobody worth mentioning.")
			empty_spoken = (was_s + ", and " + saw_nobody_tail) if was_s != "" else ("I " + saw_nobody_tail)
		var empty_line: Dictionary = say(n, empty_spoken)
		empty_line["statement"] = empty_canonical
		lines.append(empty_line)
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
		var partner: String = b.get("with", "")
		if partner != "" and sighting_is_here(w, b, partner, near_loc): partner = ""
		if partner != "":
			named["%s:%d:%d" % [partner, b["day"], b["phase"]]] = true
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
			# A witnessed conversation is its own approved predicate. It must never
			# become mere co-presence or an invented shared arrival/departure.
			parts.append({"kind": "report", "event_id": fact_id(conv),
				"statement": "I saw %s at %s, talking with %s, %s." % [who.name, where, pn.name, when_s]})
			facts.append(conv)
		else:
			var place_id: String = "loc:" + b["loc"] if b["loc"] != "" else "block:" + b["block"]
			parts.append(Observations.presence(n.id, who.id, who.name, place_id, b["day"], b["phase"], where, when_s))
		facts.append({"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": b["phase"], "source": n.id,
			"text": "%s saw %s on %s, day %d %s." % [n.name, who.name, C.block_name(b["block"]), b["day"], C.PHASES[b["phase"]]]})
	if parts.is_empty():
		var silent_prefix: String = (was_s + ". ") if was_s != "" else ""
		var silent_tail: String = Dialogue.voice_line(n.id, "day_only_here", "Nobody you didn't see for yourself.")
		var silent_line: Dictionary = say(n, silent_prefix + silent_tail)
		silent_line["statement"] = silent_prefix + "Nobody you didn't see for yourself."
		lines.append(silent_line)
		return {"lines": lines, "facts": facts}
	var reports = Dialogue.compose_turn(n.id, parts, {"audience": "player", "speech_act": "answer",
		"trust": n.trust, "pressure": n.pressure}, n.dialogue_memory, was_s != "")
	var spoken: String = " ".join(PackedStringArray(reports.map(func(r): return r.text)))
	lines.append(say(n, ((was_s + ". ") if was_s != "" else "") + spoken))
	return {"lines": lines, "facts": facts}

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
	if level < 0.25:
		text = "I trust %s." % t.name
		opinion_key = "opinion_trust"
	elif level < 0.45:
		if w.decision_roll(n, "neutral_opinion_suspicion", 0.6 - 0.4 * trait_of(n, "insight") + paranoia(w, n), {"insight": trait_of(n, "insight"), "paranoia": paranoia(w, n)}, t.id):
			text = "I can't put my finger on it, but something's off about %s." % t.name
			opinion_key = "opinion_vibes"
			shown = 0.5
		else:
			text = ("%s seems all right to me." % t.name) if level < 0.35 else ("I don't really know %s that well." % t.name)
			opinion_key = "opinion_fine" if level < 0.35 else "opinion_unfamiliar"
	elif level < 0.8:
		text = "I have my doubts about %s." % t.name
		opinion_key = "opinion_doubt"
	else:
		text = "If you ask me, %s is the one." % t.name
		opinion_key = "opinion_accuse"
	var canonical_opinion: String = text
	text = Dialogue.voice_line(n.id, opinion_key, text, {"subject": t.name})
	if level >= 0.45:
		var opinion_tail: String = (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else (" I have my reasons, but I'm not ready to say." if held else " Something's off about them.")
		text += opinion_tail
		canonical_opinion += opinion_tail
	var close = n.npc_trust.get(t.id, 0.5) > 0.7 and not (n.is_evil() and t.id == w.evil_plan["scapegoat"])
	if close and not Dialogue.has_voice(n.id):
		text += " We're close, mind."
	w.dlog.think(n.id, "lie" if lie else "opinion", "%s opinion of %s: level %.2f, reason: %s." %
		["Evil cover" if lie else ("Evil (mimicking the town)" if n.is_evil() else "Honest"), t.id, level, why if why != "" else "vibes"])
	level = shown
	var opinion_reply: Dictionary = voiced(n, "friend", text, "opinion:" + t.id, {"close": close, "subject": t.name})
	var opinion_cue: String = Dialogue.exchange_cue(n.dialogue_memory, "opinion", t.id)
	opinion_reply["text"] = Dialogue.contextualize(n.id, opinion_reply["text"], opinion_cue, t.name)
	opinion_reply["statement"] = canonical_opinion
	# Assign only to specific voiced deliveries, never to the private relationship
	# or suspicion score that led to the publicly spoken opinion.
	var opinion_expressions = {
		"opinion_trust": {"agnes": "warm", "edda": "warm", "fenwick": "warm", "isolde": "warm", "jory": "warm", "merrin": "warm"},
		"opinion_accuse": {"constance": "harsh", "edda": "harsh", "fenwick": "harsh", "greta": "harsh", "jory": "harsh", "lian": "harsh", "merrin": "harsh", "dorian": "concerned", "isolde": "concerned"},
	}
	var expressed: String = opinion_expressions.get(opinion_key, {}).get(n.id, "")
	if expressed != "" and Dialogue.has_voice(n.id):
		opinion_reply["expression"] = expressed
		opinion_reply["expression_strength"] = 1 if expressed == "warm" else 2
	if close:
		opinion_reply["relationship"] = {"kind": "friend", "people": [n.id, t.id]}
	lines.append(opinion_reply)
	if level >= 0.5:
		facts.append({"kind": "opinion", "subject": [t.id], "source": n.id, "text": "%s distrusts %s." % [n.name, t.name]})
	return {"lines": lines, "facts": facts}

# ---------------------------------------------------------------- Mind delegates

static func _append_distrust(w, n, lines: Array) -> void:
	_mind()._append_distrust(w, n, lines)

static func _challenged(n, response: Dictionary, card: Dictionary) -> Dictionary:
	return _mind()._challenged(n, response, card)

static func _unshared_fake_on(n, t_id: String) -> Dictionary:
	return _mind()._unshared_fake_on(n, t_id)

static func card_strength(w, card: Dictionary, suspect) -> float:
	return _mind().card_strength(w, card, suspect)

static func citable_reason(w, n, t_id: String, audience: String = "town") -> String:
	return _mind().citable_reason(w, n, t_id, audience)

static func decide(w, n, topic: String, parts: Dictionary, why: String) -> bool:
	return _mind().decide(w, n, topic, parts, why)

static func evil_override(w, n, act: String, stakes: float, deviation: float, detail: String) -> bool:
	return _mind().evil_override(w, n, act, stakes, deviation, detail)

static func fact_id(card: Dictionary) -> String:
	return _mind().fact_id(card)

static func info_fact(w, n, e: Dictionary) -> Dictionary:
	return _mind().info_fact(w, n, e)

static func info_lines(w, n, entries: Array, audience: String = "player", preceded: bool = false, speech_act: String = "answer") -> Array:
	return _mind().info_lines(w, n, entries, audience, preceded, speech_act)

static func ledger_hear(w, n, eid: String, effects: Array, weight: float, rel: Array = [], meta: Dictionary = {}) -> Dictionary:
	return _mind().ledger_hear(w, n, eid, effects, weight, rel, meta)

static func paranoia(w, n) -> float:
	return _mind().paranoia(w, n)

static func reason_status(w, n, t_id: String) -> Dictionary:
	return _mind().reason_status(w, n, t_id)

static func reveal_cost(w, n) -> Dictionary:
	return _mind().reveal_cost(w, n)

static func say(n, text: String) -> Dictionary:
	return _mind().say(n, text)

static func say_voiced(n, key: String, fallback: String, slots: Dictionary = {}) -> Dictionary:
	return _mind().say_voiced(n, key, fallback, slots)

static func set_trust(w, n, value: float, why: String) -> void:
	_mind().set_trust(w, n, value, why)

static func shadow_eval(w, n, f: Callable):
	return _mind().shadow_eval(w, n, f)

static func susp(n, target_id: String) -> float:
	return _mind().susp(n, target_id)

static func trait_of(n, t: String) -> float:
	return _mind().trait_of(n, t)

static func voiced(n, kind: String, statement: String, event_id: String = "", context: Dictionary = {}) -> Dictionary:
	return _mind().voiced(n, kind, statement, event_id, context)

static func whereabouts_refusal(n, nd: int) -> Dictionary:
	return _mind().whereabouts_refusal(n, nd)

static func gift_refusal(n) -> Dictionary:
	return _mind().gift_refusal(n)

static func home_alibi(w, n, nd: int) -> Dictionary:
	return _mind().home_alibi(w, n, nd)

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
				lines.append(say_voiced(n, "trace_fit_locations", "Plenty of us pass through %s every week. Finding %s hardly pins a murder on me." % [places, item_lbl], {"places": places, "item": item_lbl}))
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
