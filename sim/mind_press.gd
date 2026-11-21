## Hints and pressing: a hint's follow-up, being pressed with evidence, and the
## caught-out ladder (split from `sim/mind_dialogue.gd`).
extends "res://sim/mind_dialogue_base.gd"


## The player follows up on a hint ("what's your reason?"). They may still keep it back;
## if they tell, it comes out as their gift and the reading (as in answer_gift at full
## disclosure), and if their gift isn't public they ask you to keep it to yourself: the
## cards come back marked confidential, and using them at the meeting breaks your word.
## Returns {lines, facts}.
static func has_live_hint(w, n) -> bool:
	return n.hints.keys().any(func(k): return w.by_id.has(k) and w.by_id[k].alive)

static func answer_hint(w, n) -> Dictionary:
	_dialogue().on_question(w, n)
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
		var empty_key: String = "hint_why_empty_1" if count % 2 == 0 else "hint_why_empty_2"
		var empty_fb: String = "I've nothing more to tell you." if count % 2 == 0 else "I've no further reason to give you."
		lines.append(say_voiced(n, empty_key, empty_fb))
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
	var parts = {"trust": (n.trust - Tuning.Dialogue.HINT_FOLLOWUP_TRUST_PIVOT) * Tuning.Dialogue.HINT_FOLLOWUP_TRUST_SLOPE, "privacy": (0.5 - trait_of(n, "privacy")) * Tuning.Dialogue.HINT_FOLLOWUP_PRIVACY_SLOPE}
	if cost.has("afraid"):
		parts["afraid"] = Tuning.Dialogue.HINT_FOLLOWUP_AFRAID_OFFSET
	if not decide(w, n, "hint_followup", parts, "Tell the Demonologist why they suspect %s?" % target):
		lines.append(_hint_decline(w, n, t))
		return {"lines": lines, "facts": []}
	var r = _answers().answer_gift(w, n, 4, false)
	lines.append(say_voiced(n, "hint_why_lead", "All right. You asked, so here's why I suspect %s." % t.name, {"target": t.name}))
	lines.append_array(r["lines"])
	var facts: Array = r["facts"]
	if not n.claim_public:
		n.dialogue_memory["confidence_requested"] = true
		lines.append(say_voiced(n, "hint_why_confidential", "But keep this between us. Don't bring it up at the meeting; not yet."))
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
	if card.get("tavern_gossip", false) or not card.get("pressable", true):
		return {"lines": ["That's only unattributed tavern talk; you need a named witness or concrete evidence to press %s." % n.name], "facts": []}
	var c: Dictionary = card.get("conclusion", {})
	var subj: Array = card.get("subject", [])
	var pair: Array = card.get("data", {}).get("pair", [])
	var trace_fits_me: bool = card.get("kind") == "trace" and card.get("trace_family", "") != "" and w.actor_fits_trace_truth(n, {"trace_family": card.get("trace_family", ""), "locs": card.get("locs", []), "home_block": card.get("trace_home_block", ""), "evening_block": card.get("trace_evening_block", ""), "victim": card.get("victim", ""), "day": card.get("day", -1)})
	var about_me = trace_fits_me or n.id in subj or c.get("a", "") == n.id or n.id in pair or (card.get("kind") == "claim" and card.get("source") != n.id and n.claim_public and card.get("role") == n.claimed_role)
	if not about_me:
		_dialogue().on_question(w, n)
		lines.append(say_voiced(n, "press_not_about_me", "What has that to do with me?"))
		return {"lines": lines, "facts": facts}
	var kind: String = card.get("kind", "")
	var d: Dictionary = card.get("data", {})
	# What is the card pushing on: their night, or their gift?
	var night = -1
	if kind in ["sighting", "secret"] and card.get("phase", -1) == C.NIGHT and card.get("source", "") != n.id:
		night = card.get("day", -1)
	elif kind == "deduction":
		# A case resting on night evidence is about that night, whatever it concludes (Michael,
		# Nov 18: a "suspicious" case built from an alibi or a vigil got a gift refusal).
		for x in card.get("support_cards", []):
			if x.get("phase", -1) == C.NIGHT:
				night = x.get("day", -1)
		# When the case's cards place them out (GameConversation.press_contradiction, Quill),
		# that's the night it's about.
		if not card.get("contradiction", {}).is_empty():
			night = int(card.contradiction.get("night", night))
	var naming_me = kind == "info" and C.has_role_def(card.get("role", "")) and C.role_def(card.get("role", "")).names_good_role_in_pair() and n.id in pair  # "one of you two is the X"
	var counter = kind == "claim" and card.get("source", "") != n.id and n.claim_public and card.get("role", "") == n.claimed_role
	# How hard the card lands: the town's own shared weight for it (purge phase 4b).
	var strength = Tuning.Dialogue.PRESS_DEDUCTION_STRENGTH if kind == "deduction" else clampf(_mind().card_weight_against(w, card, n.id), Tuning.Dialogue.PRESS_STRENGTH_MIN, 1.0)
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
		set_trust(w, n, n.trust - (Tuning.Trust.PRESSED_EVIDENCE_BASE + Tuning.Trust.PRESSED_EVIDENCE_PRIVACY * trait_of(n, "privacy")), "the Demonologist pressed me with evidence")
	if nervous:
		lines.append("%s %s" % [n.name, ["looks away a moment too quickly.", "shifts uneasily.", "goes a little pale.", "fumbles for an answer."][w.rng.randi_range(0, 3)]])
	if counter:
		_dialogue().on_question(w, n)
		var rival = w.by_id[card["source"]]
		var role_disp: String = C.role_name(n.claimed_role)
		var accusation: Dictionary = say_voiced(n, "press_counter_claim", "I am the %s. If %s says otherwise, %s is lying." % [role_disp, rival.name, rival.name], {"role": role_disp, "rival": rival.name})
		accusation["expression"] = "harsh"
		accusation["expression_strength"] = 2
		lines.append(accusation)
		if not n.is_evil():
			var receipt: Dictionary = WorkshopLedger.Evidence.normalize_card(card)
			ledger_hear(w, n, "own_role:" + fact_id(card), [], 1.0,
				[rival.id, -1, "role"], {"kind": "role_counter", "workshop_card": receipt})
		var pressed: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card)
		pressed["dialogue_exchange"] = {"action": "challenge_gift", "subject": n.id}
		return pressed
	if night >= 0:
		# Shown a sighting of themselves, they may add what the death record says of that night
		# (BACKLOG "Explicit night-sighting rebuttals"): after whatever else they answer, speech
		# only, to the Demonologist alone (no one else hears it, so no ledger entry).
		# It's said only once their account is in, and only if it fits that account.
		var defence = load("res://sim/mind_defence.gd")
		var reb: Dictionary = {}
		if kind == "sighting":
			reb = defence.night_route_rebuttal(w, n, int(night), str(card.get("block", "")))
		var reb_after: Callable = func() -> Array:
			if not defence.rebuttal_fits_account(w, n, reb):
				return []
			defence.note_rebuttal(w, n, reb, "In private")
			return [defence.rebuttal_line(w, n, reb, true)]
		# Evil may answer a sighting of itself with an Unrequited bluff (burdens prototype).
		if kind == "sighting":
			var ub: Dictionary = Burdens.evil_unrequited_bluff(w, n, int(night), str(card.get("block", "")))
			if not ub.is_empty():
				_own_night_account(w, n, int(night), str(card.get("block", "")))
				return {"lines": lines + [ub["line"]], "facts": facts + [ub["fact"]], "dialogue_exchange": {"action": "challenge_night", "subject": n.id}}
		var caught: Dictionary = _pressed_caught_out(w, n, night, card.get("contradiction", {}) if kind == "deduction" else {})
		if not caught.is_empty():
			caught["lines"].append_array(reb_after.call())
			caught["dialogue_exchange"] = {"action": "challenge_night", "subject": n.id}
			return caught
		var r = _answer_pressed_night(w, n, night)
		# Caught out on gift business, they explain rather than defend what they saw: the
		# "you doubt my account" opener only fits a restated sighting or alibi.
		var reveal: bool = r["facts"].any(func(f): return f.get("kind", "") == "claim" and f.get("source", "") == n.id)
		if r.get("soft", false):
			# The soft tier owns the night: it answers the sighting, not "you doubt my account".
			return {"lines": lines + r["lines"] + reb_after.call(), "facts": facts + r["facts"], "dialogue_exchange": {"action": "challenge_night", "subject": n.id}}
		if reveal:
			lines.append(say_voiced(n, "pressed_caught_out", "All right, you saw me. Here's why I was out."))
		lines += r["lines"]
		facts += r["facts"]
		if reveal:
			lines.append_array(reb_after.call())
			return {"lines": lines, "facts": facts, "dialogue_exchange": {"action": "challenge_night", "subject": n.id}}
		var witness_lying: Dictionary = _witness_lying(w, n, card, night, r)
		if not witness_lying.is_empty():
			lines.append(witness_lying)
		lines.append_array(reb_after.call())
		var pressed: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card)
		pressed["dialogue_exchange"] = {"action": "challenge_night", "subject": n.id}
		return pressed
	if kind == "trace" and card.get("trace_family", "") != "":
		var tr_reply: Dictionary = _dialogue().react_to_trace(w, n, card, known_haunts, true)
		lines += tr_reply["lines"]
		facts += tr_reply["facts"]
		var pressed_tr: Dictionary = _challenged(n, {"lines": lines, "facts": facts, "profile_haunts": tr_reply.get("profile_haunts", [])}, card)
		pressed_tr["dialogue_exchange"] = {"action": "challenge_trace", "subject": n.id}
		return pressed_tr
	if kind == "deduction":
		var trace_supports: Array = card.get("support_cards", []).filter(func(sc): return sc.get("kind", "") == "trace")
		if trace_supports.size() >= 2:
			_dialogue().on_question(w, n)
			lines.append(say_voiced(n, "pressed_multi_trace_case", "You're stringing scraps from half the village together to hang me. Anyone out in the dark could have tracked those in or left them to frame me."))
			var pressed_multi: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card)
			pressed_multi["dialogue_exchange"] = {"action": "challenge_trace_case", "subject": n.id}
			return pressed_multi
	# A reading that calls them evil, answered privately by Marked (burdens prototype).
	if kind == "info" and about_me:
		var ba: Dictionary = Burdens.answer_evil_reading(w, n, {"role": str(card.get("role", "")), "data": d}, false, "player")
		if not ba.is_empty():
			_dialogue().on_question(w, n)
			lines.append(ba["line"])
			if not ba["fact"].is_empty():
				facts.append(ba["fact"])
			return {"lines": lines, "facts": facts, "dialogue_exchange": {"action": "challenge_gift", "subject": n.id}}
	# Their gift: a true naming opens them up; otherwise pressure decides.
	var bonus = 1 if naming_me and d.get("role", "") == mine else 0
	var tier = mini(_dialogue()._target_tier(w, n) + bonus, 4)
	var r2 = _answers().answer_gift(w, n, tier)
	lines += r2["lines"]
	facts += r2["facts"]
	# "Are you doubting my account?" only fits when the card questions something they said.
	# A reading or claim that names them is an accusation, and gets the gift answer plain.
	var own_account: bool = card.get("source", "") == n.id or (kind == "deduction" and c.get("type", "") in ["lied", "unreliable"])
	var pressed: Dictionary = _challenged(n, {"lines": lines, "facts": facts}, card) if own_account else {"lines": lines, "facts": facts}
	pressed["dialogue_exchange"] = {"action": "challenge_gift", "subject": n.id}
	return pressed

## Only a known gift outing collapses disclosure. Personal errands keep the existing
## choices, including all their original RNG draws.
static func _gift_outing(w, n, night: int) -> bool:
	if n.is_evil() or not C.ROLES[n.role].get("night_walk", false): return false
	if not str(n.history.get(w.time_key(night, C.NIGHT), "home")).begins_with("night:"): return false
	if night == w.day - 1:
		for walker in w.night_walkers:
			if walker.id == n.id:
				return not str(walker.why).begins_with("secret:")
	var rdef = C.role_def(n.role)
	if rdef != null and rdef.has_gift_outing(n, night): return true
	if n.info_log.any(func(e): return e.get("role", "") == n.role and e.get("day", -1) == night): return true
	return n.secret.is_empty()

## Evil's side of `_gift_outing`: out that night, with a planned walking bluff whose duty
## story would cover the night once claimed. Pressed with the sighting, evil backs into
## that bluff and owns the outing just as a good walker does (BACKLOG, "An evil walker's
## owned lie doesn't follow its disclosure"), so the response isn't a tell.
static func _bluff_outing(w, n, night: int) -> bool:
	if not n.is_evil():
		return false
	var bluff: String = str(w.evil_plan.get("bluffs", {}).get(n.id, ""))
	if bluff == "" or not C.ROLES.get(bluff, {}).get("night_walk", false):
		return false
	if not str(n.history.get(w.time_key(night, C.NIGHT), "home")).begins_with("night:"):
		return false
	return bluff_duty_covers(w, n, bluff, night)

## Whether an evil member's bluffed walking gift, once named, tells a duty story for night
## `night`. Asked as if the bluff were already claimed (the roles' duty checks read the claim).
static func bluff_duty_covers(w, n, bluff: String, night: int) -> bool:
	if not C.has_role_def(bluff):
		return false
	var was_claimed: String = n.claimed_role
	var was_tier: int = n.max_tier
	n.claimed_role = bluff
	n.max_tier = maxi(n.max_tier, 3)
	# Not just "tells a duty story" but one that puts them out: a Warden bluff has no door
	# before its first night and says "home" (Codex P2 on #175).
	var covers: bool = C.role_def(bluff).duty_explains_outing(w, n, night)
	n.claimed_role = was_claimed
	n.max_tier = was_tier
	return covers

## The caught-out ladder's soft tier (Michael, Nov 19: one ladder for good and evil, so the
## answer isn't a tell). A walker whose gift (or evil's bluff) would explain the night, not
## yet claimed, owns the night and keeps the gift: "Fine, I was out", then the default
## whereabouts refusal ("Where I go at night is my own business"). It names a gift only when pressed again about that night, or once nominated.
## {} when it's already given the soft tier for that night, or is nominated: the caller
## names the gift (a good walker its own, evil its planned walking bluff).
static func _soft_tier(w, n, night: int) -> Dictionary:
	var nominated: bool = n.id in w.meeting.get("nominated", []) or str(w.meeting.get("block", "")) == n.id
	var soft: Dictionary = n.dialogue_memory.get("caught_soft", {})
	if nominated or soft.has(str(night)):
		return {}
	soft[str(night)] = w.day
	n.dialogue_memory["caught_soft"] = soft
	_dialogue().on_question(w, n)
	var where: String = str(n.history.get(w.time_key(night, C.NIGHT), ""))
	if night not in n.lied_nights:
		n.lied_nights.append(night)
	_own_night_account(w, n, night, where.substr(6))
	# The reason kept back with the whereabouts refusal, not the gift refusal: some voices'
	# gift refusals name a gift the player never asked about (Herald, Nov 19).
	var lines: Array = [say_voiced(n, "trapped_night_out", "Fine, I was out. Doesn't mean I was doing anything wrong."), whereabouts_refusal(n, night)]
	var facts: Array = [_excuse_fact(w, n, night, "admit")]
	if n.is_evil():
		w.dlog.think(n.id, "admit_out", "Caught out on night %d: owns the night and keeps its planned %s bluff back for now." % [night, C.role_name(str(w.evil_plan["bluffs"].get(n.id, "")))], {"why": "caught out of a home alibi; a walking bluff would explain the night"})
	else:
		w.dlog.think(n.id, "admit_out", "Caught out on night %d: owns the night and keeps its %s gift back for now." % [night, C.role_name(n.role)])
	return {"lines": lines, "facts": facts, "soft": true}

## "Fine, I was out", then why (Michael, Nov 18): a good NPC caught out of a home alibi in
## private, who has an honest reason, gives it: the gift that took them out, or the secret
## errand. {} when there's no honest reason to give (evil work, a gift kept back): they
## stonewall. Never the lie branch: they've just owned the night.
static func trapped_explanation(w, n, nd: int) -> Dictionary:
	var where: String = str(n.history.get(w.time_key(nd, C.NIGHT), ""))
	if not where.begins_with("night:"):
		return {}
	if n.is_evil():
		# The same ladder (Michael, Nov 19): a claimed walking bluff tells its duty; an
		# unclaimed one gets the soft tier, then the bluff; otherwise the line stands alone
		# ("being out isn't wicked").
		if _disclosed(n) and C.has_role_def(n.claimed_role) and C.role_def(n.claimed_role).uses_night_duty_alibi(w, n, nd, true):
			return _tag_duty_excuse(w, n, nd, _answers().answer_night(w, n, nd))
		if not n.claim_public and n.max_tier < 3 and _bluff_outing(w, n, nd):
			var soft_e: Dictionary = _soft_tier(w, n, nd)
			if not soft_e.is_empty():
				return soft_e
			if nd not in n.lied_nights:
				n.lied_nights.append(nd)
			_own_night_account(w, n, nd, where.substr(6))
			return _answers().answer_gift(w, n, 3)
		return {}
	if _honest_outing(w, n, nd) == "reveal":
		return _tag_duty_excuse(w, n, nd, _answers().answer_night(w, n, nd))
	if _gift_outing(w, n, nd):
		# Out on gift business (a Night Watch, Warden, Lamplighter...), as a direct press would
		# answer it: their claimed duty if they're already out with it, else the gift itself
		# (Codex on #261: only the Sexton reached the reveal branch).
		if _disclosed(n):
			return _tag_duty_excuse(w, n, nd, _answers().answer_night(w, n, nd))
		var soft: Dictionary = _soft_tier(w, n, nd)
		if not soft.is_empty():
			return soft
		if nd not in n.lied_nights:
			n.lied_nights.append(nd)
		_own_night_account(w, n, nd, where.substr(6))
		return _answers().answer_gift(w, n, 3)
	if n.secret.is_empty():
		return {}
	var block: String = where.substr(6)
	_own_night_account(w, n, nd, block)
	n.secret_known = true
	var line: Dictionary = say_voiced(n, "confess_secret_private", "...I wasn't home. I %s. Please, keep it quiet." % n.secret.get("me", n.secret["text"]), {"secret": n.secret.get("me", n.secret["text"])})
	var fact: Dictionary = Burdens.with_errand(w, n, {"kind": "secret", "subject": [n.id], "owner": n.id, "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
		"secret_kind": n.secret.get("kind", ""), "text": "%s confessed they were out on %s on night %d: %s %s." % [n.name, C.block_name(block), nd, n.name, n.secret["text"]]})
	w.dlog.think(n.id, "admit_out", "Caught out of a home alibi: owns the night and explains it (secret: %s)." % n.secret.get("kind", "?"))
	return {"lines": [line], "facts": [fact]}

## Pressed with a case whose cards place them out that night (BACKLOG 78148, Kiran): a good
## NPC who was out on its own business, not its gift, can't stand by "I was at home". It says
## "Fine, I was out", the line a presented case already gets (WorkshopPresentation), and, if
## it's open enough today, why (`trapped_explanation`). {} leaves every other case to the
## usual answer: the truly home stand by it, a gift walker owns its gift or duty, and evil keeps its
## cover.
static func _pressed_caught_out(w, n, night: int, contra: Dictionary) -> Dictionary:
	if contra.is_empty() or contra.get("ruled_out_home_by", []).is_empty() or int(contra.get("night", -1)) != night:
		return {}
	if n.silenced:
		return {}
	if not str(n.history.get(w.time_key(night, C.NIGHT), "")).begins_with("night:"):
		return {}
	if n.is_evil():
		return _evil_caught_out(w, n, night)
	if _gift_outing(w, n, night):
		return {}
	_dialogue().on_question(w, n)
	var lines: Array = [say_voiced(n, "trapped_night_out", "Fine, I was out. Doesn't mean I was doing anything wrong.")]
	var facts: Array = []
	var tier: int = _dialogue()._target_tier(w, n)
	var why: Dictionary = trapped_explanation(w, n, night) if tier >= 2 else {}
	lines.append_array(why.get("lines", []))
	facts.append_array(why.get("facts", []))
	if why.is_empty():
		# The reason kept back, the night is still owned: a later question about it gets the
		# plain "I was out" account, not the home alibi it replaced (Codex on #330).
		_own_night_account(w, n, night, str(n.history.get(w.time_key(night, C.NIGHT), "")).substr(6))
		facts.append(_excuse_fact(w, n, night, "not_wicked"))
	w.dlog.think(n.id, "admit_out", "Pressed with a case placing them out on night %d (tier %d): %s." % [night, tier, "explains the night" if not why.get("lines", []).is_empty() else "says only that being out isn't wicked"])
	return {"lines": lines, "facts": facts}

## "<witness> is lying about seeing me" in private (Michael, Nov 19), as the meeting defence
## says it: pressed with another NPC's sighting of it, an NPC standing by "home" may call the
## witness a liar, with Confidence over the same gate. Evil uses it freely; a good NPC says it
## only if it really was home (one who knows the sighting is true doesn't). A line only: it
## adds no doubt of the witness. {} when it doesn't apply.
static func _witness_lying(w, n, card: Dictionary, night: int, reply: Dictionary) -> Dictionary:
	# The meeting defence's Confidence gate (MindMeeting, "is lying, and you should ask...").
	if str(card.get("kind", "")) != "sighting" or trait_of(n, "confidence") <= 0.6:
		return {}
	var src: String = str(card.get("relay_source", card.get("source", "")))
	if src == "" or src == n.id or not w.by_id.has(src):
		return {}
	if not reply.get("facts", []).any(func(f): return f.get("kind", "") == "alibi" and f.get("home", false) and f.get("source", "") == n.id):
		return {}
	if not n.is_evil() and str(n.history.get(w.time_key(night, C.NIGHT), "home")).begins_with("night:"):
		return {}
	var witness = w.by_id[src]
	if n.is_evil() and str(n.history.get(w.time_key(night, C.NIGHT), "home")).begins_with("night:"):
		w.dlog.think(n.id, "lie", "Called %s a liar for seeing it out on night %d." % [witness.name, night], {"lie": true, "why": "denying a true sighting of its night's work"})
	return say_voiced(n, "press_witness_lying", "%s is lying about seeing me." % witness.name, {"witness": witness.name})

## Whether n has named its gift (or evil its bluff): publicly, or privately to the player
## (`max_tier` 3, as the roles' duty checks read it; Codex on #368).
static func _disclosed(n) -> bool:
	return n.claimed_role != "" and (n.claim_public or n.max_tier >= 3)

## The fact an excuse leaves on the board, for the judge (Lantern, Nov 19): the owner, the
## night it excuses, and its kind: "admit" ("Fine, I was out", the gift kept back),
## "not_wicked" (out, no reason given) or "duty" (a claimed walking gift's night work; set by
## `_tag_duty_excuse`). Neither "admit" nor "not_wicked" names anything that could be
## contradicted.
static func _excuse_fact(w, n, night: int, kind: String) -> Dictionary:
	return {"kind": "alibi", "subject": [n.id], "home": false, "day": night, "phase": C.NIGHT, "source": n.id,
		"excuse": kind, "excuses_night": night,
		"text": "%s admits they were out %s." % [n.name, C.spoken_when(night, w.day)]}

## A claimed walking gift's duty account given as the excuse for a broken home alibi: its
## facts are marked "duty", with the claimed role and the block, for the judge.
static func _tag_duty_excuse(w, n, night: int, reply: Dictionary) -> Dictionary:
	for f in reply.get("facts", []):
		if f is Dictionary and str(f.get("source", "")) == n.id and str(f.get("kind", "")) != "claim" and int(f.get("day", -1)) == night:
			f["excuse"] = "duty"
			f["excuses_night"] = night
			f["duty_role"] = n.claimed_role
			if not f.has("block"):
				f["block"] = str(n.history.get(w.time_key(night, C.NIGHT), "")).trim_prefix("night:")
	return reply

## Evil caught out of its home alibi by a case, in private (Michael, Nov 19: the same ladder).
## A walking bluff, claimed or not, is answered downstream as a good walker's gift is (its
## duty, or the soft tier, then the bluff): {}. Otherwise it owns the night and says only that being out isn't wicked, rather than
## standing by a home alibi the case has just broken.
static func _evil_caught_out(w, n, night: int) -> Dictionary:
	var claimed_walk: bool = _disclosed(n) and C.has_role_def(n.claimed_role) and C.role_def(n.claimed_role).uses_night_duty_alibi(w, n, night, true)
	if claimed_walk or (not n.claim_public and n.max_tier < 3 and _bluff_outing(w, n, night)):
		return {}
	_dialogue().on_question(w, n)
	_own_night_account(w, n, night, str(n.history.get(w.time_key(night, C.NIGHT), "")).substr(6))
	w.dlog.think(n.id, "admit_out", "Caught out of a home alibi on night %d: owns the night and keeps the reason (evil work)." % night, {"why": "a case broke its home alibi; nothing it could claim explains the night"})
	return {"lines": [say_voiced(n, "trapped_night_out", "Fine, I was out. Doesn't mean I was doing anything wrong.")],
		"facts": [_excuse_fact(w, n, night, "not_wicked")]}

## The night is owned now: a later question about it, in private or at the podium, gets the
## plain "I was out" account rather than the home alibi it replaced (Codex on #261).
static func _own_night_account(_w, n, nd: int, block: String) -> void:
	var accounts: Dictionary = n.dialogue_memory.get("night_accounts", {})
	accounts[str(nd)] = {"kind": "alibi", "subject": [n.id], "home": false, "day": nd, "phase": C.NIGHT, "source": n.id, "block": block,
		"text": "%s says they were out on %s on night %d." % [n.name, C.block_name(block), nd]}
	n.dialogue_memory["night_accounts"] = accounts

static func _answer_pressed_night(w, n, night: int) -> Dictionary:
	if not n.claim_public and n.max_tier < 3 and (_gift_outing(w, n, night) or _bluff_outing(w, n, night)):
		var soft: Dictionary = _soft_tier(w, n, night)
		if not soft.is_empty():
			return soft
		if night not in n.lied_nights: n.lied_nights.append(night)
		# The existing gift answer owns the admission, claim, reading willingness,
		# question fatigue and the "So yes: I was out..." line, exactly once.
		return _answers().answer_gift(w, n, 3)
	# Whether they'd already given an account of that night: the pressed "home" line says
	# "I stand by that account" only if there was one (89077: Nisha had never been asked).
	var had_account: bool = n.dialogue_memory.get("night_accounts", {}).has(str(night))
	var response = _answers().answer_night(w, n, night)
	var variants: Dictionary = n.dialogue_memory.get("pressed_nights", {})
	var count: int = variants.get(str(night), 0)
	variants[str(night)] = count + 1
	n.dialogue_memory["pressed_nights"] = variants
	var alternate = count % 2 == 1
	var when = C.spoken_when(night, w.day)
	var text = ""
	var statement = ""
	for fact in response.facts:
		if fact.get("kind", "") == "alibi" and fact.get("source", "") == n.id and n.id in fact.get("subject", []):
			if not had_account and not alternate:
				# A first account, so nothing to stand by yet: their own alibi, as answer_night
				# gave it in their voice (Michael, Nov 17). Its meaning is the plain statement.
				statement = "I was at home %s." % when
				for line in response.lines:
					if line is Dictionary and line.get("speaker", "") == n.id:
						text = str(line.get("text", ""))
						break
				break
			statement = ("That sighting doesn't change where I was: at home %s." if alternate else "I was at home %s. I stand by that account.") % when
			text = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, "pressed_home_stand_alt" if alternate else "pressed_home_stand", statement, {"when": when}), n.dialogue_memory)
			break
		if fact.get("kind", "") == "secret" and fact.get("owner", "") == n.id:
			var sec_me: String = n.secret.get("me", n.secret["text"])
			statement = ("I wasn't there on evil business. I %s. Keep that between us." if alternate else "All right: I %s. That's why I was out; please keep it quiet.") % sec_me
			text = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, "confess_secret_private_alt" if alternate else "confess_secret_private", statement, {"secret": sec_me}), n.dialogue_memory)
			break
		if fact.get("kind", "") == "refusal" and fact.get("source", "") == n.id:
			statement = "I've nothing more to say about that night." if alternate else "That sighting doesn't give you the right to demand my whereabouts."
			text = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, "pressed_refusal_stand_alt" if alternate else "pressed_refusal_stand", statement), n.dialogue_memory)
			break
		var f_role: String = fact.get("role", "") if fact.get("kind", "") == "info" else ("nightwatch" if fact.get("watch_claim", false) else (fact.get("duty", "") if fact.get("duty_claim", false) else ""))
		if f_role != "" and C.has_role_def(f_role):
			var rdef_press = C.role_def(f_role)
			statement = rdef_press.pressed_night_line(w, n, fact, night, when, alternate, C.block_name)
			if statement != "":
				var role_key: String = "pressed_%s_night%s" % [f_role, "_alt" if alternate else ""]
				var role_slots: Dictionary = rdef_press.pressed_night_slots(w, n, fact, night, when, C.block_name)
				text = Dialogue.apply_tics(n.id, Dialogue.voice_line(n.id, role_key, statement, role_slots), n.dialogue_memory)
				break
	if text != "":
		for line in response.lines:
			if line is Dictionary and line.get("speaker", "") == n.id:
				line.text = text
				line["statement"] = statement
				break
	return response
