## Meeting plan M2b (docs/meeting_flow_plan.md section 3, Step 3): the player's podium
## press on a nominee, answered before the whole town.
##
##   press role      "what is your gift?" -> public claim (+ readings), a hint, or refusal
##   press readings  (already claimed) share what the gift has shown that the town hasn't heard
##   press night N   their account of night N: home, duty, a confessed errand or a hidden
##                   walking gift, a lie, or a refusal; then what they saw from there
##   press card #    a board card about them: routed to the night, gift or counter-claim answer
##
## Everything said here is public: board cards for the player, and every living listener
## hears the same receipts (claims and readings through the usual public paths; alibis,
## refusals, hints and confessions as public meeting receipts; sightings through
## Social.deliver_public_sighting). Private conversation functions are not used, so the
## private dialogue keeps every decision and RNG draw it had.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Dialogue = preload("res://sim/dialogue.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const WorkshopLedger = preload("res://workshop/shared_ledger.gd")

static var _mind_script
static var _social_script


static func _mind():
	if _mind_script == null:
		_mind_script = load("res://sim/mind.gd")
	return _mind_script


static func _social():
	if _social_script == null:
		_social_script = load("res://sim/social.gd")
	return _social_script


static func _trait(n, t: String) -> float:
	return _mind().trait_of(n, t)


static func _say(n, key: String, fallback: String, slots: Dictionary = {}) -> Dictionary:
	return _mind().say_voiced(n, key, fallback, slots)


## What the player can press this nominee on now.
## {"silenced": bool, "gift": "role" | "readings" | "", "nights": [0 .. day-1]}
static func options(w, d) -> Dictionary:
	if d.silenced:
		return {"silenced": true, "gift": "", "nights": []}
	var gift: String = "role"
	if d.claim_public:
		gift = "readings" if (_unshared_readings(d) > 0 or _ongoing_info(d.claimed_role) or _never_read(d)) else ""
	return {"silenced": false, "gift": gift, "nights": range(0, w.day)}


static func _unshared_readings(d) -> int:
	return d.info_log.filter(func(e): return not e.get("shared", false) and not e.get("disowned", false)).size()


## Claimed a gift with readings but never told one of it (playtest 51795: an Archivist claim with
## no reading behind it): the town can still press for it.
static func _never_read(d) -> bool:
	var role: String = d.claimed_role
	return role != "" and C.has_readings(role) and not d.info_log.any(func(e): return e.get("shared", false) and str(e.get("role", role)) == role)

static func _ongoing_info(role: String) -> bool:
	return role != "" and C.has_readings(role) and not (role in C.START_ROLES)


## The podium parts shared by every "say it before the town?" decision.
static func _stakes(w, d) -> Dictionary:
	var parts = {
		"openness": (0.5 - _trait(d, "privacy")) * Tuning.Meeting.PUBLIC_CLAIM_OPENNESS_SLOPE,
		"urgency": Tuning.Meeting.PODIUM_PRESS_URGENCY,
		"pressure": d.pressure * Tuning.Meeting.PUBLIC_CLAIM_PRESSURE_SLOPE * (1.0 - Tuning.Meeting.PUBLIC_CLAIM_COMPOSURE_DAMP * _trait(d, "composure")),
	}
	var safety: float = MindMeeting.block_safety(w, d)
	if safety > 0.0:
		parts["block_safety"] = -safety * Tuning.Meeting.BLOCK_SAFETY_PRESS_RELIEF
	return parts


# ---------------------------------------------------------------- press role / readings

static func press_role(w, d, grounds: bool) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var role: String = w.evil_plan["bluffs"][d.id] if d.is_evil() else d.role
	var parts: Dictionary = _stakes(w, d)
	var cost: Dictionary = MindMeeting.reveal_cost(w, d)
	for k in cost:
		parts["cost_" + k] = -cost[k]
	var why: String = ("Evil cover: pressed at the podium, claim bluff %s?" % role) if d.is_evil() else ("Pressed at the podium: claim %s before the town?" % role)
	if _mind().decide(w, d, "podium_claim", parts, why):
		if d.is_evil():
			w.dlog.think(d.id, "lie", "Pressed before the town, claimed to be the %s, as cover." % C.role_name(role), {"bluff": role, "true_role": d.role})
		MindMeeting._public_disclosure(w, d, lines, facts)
		return {"lines": lines, "facts": facts, "outcome": "claim"}
	var pk: String = C.hint_package(w, role)
	if pk != "":
		var hint_parts: Dictionary = parts.duplicate()
		hint_parts["hint_ease"] = Tuning.Meeting.PODIUM_HINT_EASE
		if _mind().decide(w, d, "podium_hint", hint_parts, "Pressed at the podium: hint at my gift (%s) instead?" % pk):
			if d.is_evil():
				w.dlog.think(d.id, "lie", "Pressed before the town, hinted at being the %s, as cover." % C.role_name(role), {"lie": true})
			var pkg: Dictionary = C.HINT_PACKAGES[pk]
			lines.append(_say(d, "hint_pkg_" + pk, pkg["text"] + " That's as far as I'll go."))
			facts.append({"kind": "hint", "subject": [d.id], "source": d.id, "package": pk, "roles": pkg["roles"], "public": true,
				"text": "%s hinted before the town at %s (%s)." % [d.name, pkg["name"],
					" / ".join(PackedStringArray(pkg["roles"].map(func(r): return C.role_name(r))))]})
			d.max_tier = maxi(d.max_tier, 2)
			_town_hears(w, d, facts)
			return {"lines": lines, "facts": facts, "outcome": "hint"}
	lines.append(_say(d, "podium_gift_refusal", "My gift is my own affair, and I'll not air it before the whole town."))
	facts.append({"kind": "refusal", "subject": [d.id], "source": d.id, "public": true,
		"text": "%s refused, before the town, to say whether they have a gift." % d.name})
	_refused(w, d, grounds)
	_town_hears(w, d, facts)
	return {"lines": lines, "facts": facts, "outcome": "refusal"}


static func press_readings(w, d) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	MindMeeting._go_public(w, d, lines, facts, true)
	if facts.is_empty():
		lines.append(_say(d, "podium_nothing_new", "I've told the town everything my gift has shown me."))
		return {"lines": lines, "facts": facts, "outcome": "nothing_new"}
	return {"lines": lines, "facts": facts, "outcome": "readings"}


## A refusal under the press: a little pressure, and (good only) a little friction with the
## Demonologist when the press had no grounds or the nominee was already safe.
static func _refused(w, d, grounds: bool) -> void:
	d.pressure += Tuning.Meeting.PODIUM_PRESS_PRESSURE_GAIN
	if d.is_evil():
		return
	if not grounds or MindMeeting.block_safety(w, d) >= Tuning.Meeting.PODIUM_FRICTION_SAFETY:
		_mind().set_trust(w, d, d.trust - Tuning.Trust.PRESSED_EVIDENCE_BASE, "the Demonologist pressed me before the town without cause")


# ---------------------------------------------------------------- press night

## `admitted`: the defender has just owned that they were out (a true sighting of them), so
## the account never falls back to "I was home" (Codex P2 on #115); refusing to say why
## stays open.
## They already owned being out that night (a plain account): keep to it (#130 review).
static func admitted_before(d, nd: int) -> bool:
	var prior: Dictionary = d.dialogue_memory.get("night_accounts", {}).get(str(nd), {})
	return prior.get("kind", "") == "alibi" and not prior.get("home", true) and prior.get("source", "") == d.id

## They've already confessed that night's errand (at the podium or to you): asked again,
## they tell the same confession, never a refusal or a lie (Quill, Nov 20, seed 701).
static func confessed_before(d, nd: int) -> bool:
	var prior: Dictionary = d.dialogue_memory.get("night_accounts", {}).get(str(nd), {})
	return prior.get("kind", "") == "secret" and prior.get("owner", "") == d.id

## Out that night, owned, but the reason kept back.
static func _plain_account(w, d, nd: int, block: String, lines: Array, facts: Array) -> void:
	w.dlog.think(d.id, "admit_out", "Owned the sighting: says they were out on %s on night %d, keeps the reason." % [block, nd])
	lines.append(_say(d, "admitted_plain_account", "I was out %s, on %s. I'll not pretend otherwise, though the why is my own." % [C.spoken_when(nd, w.day), C.block_name(block)],
		{"when": C.spoken_when(nd, w.day), "block": C.block_name(block)}))
	facts.append({"kind": "alibi", "subject": [d.id], "home": false, "day": nd, "phase": C.NIGHT, "source": d.id, "block": block, "public": true,
		"text": "%s says they were out on %s %s." % [d.name, C.block_name(block), C.spoken_when(nd, w.day)]})

## `pressed` (Michael, Nov 20 plan: the same ladder at the podium): the player pressing them
## with a card about that night (press_card). Each earlier press about the night, in private or
## here, makes owning up to the reason likelier (PRESSED_AGAIN_OPENNESS); evil with nothing to
## tell may back into a spare walking gift; and the truly home grow irritated.
static func press_night(w, d, nd: int, grounds: bool, admitted: bool = false, pressed: bool = false) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	var outcome: String = ""
	var Press = load("res://sim/mind_press.gd")
	var presses: int = Press.press_count(d, nd) if pressed else 0
	var where: String = d.history.get(w.time_key(nd, C.NIGHT), "home:" + d.home_block)
	var was_out: bool = where.begins_with("night:")
	var block: String = where.substr(where.find(":") + 1)
	var vantage: String = ""
	var how: String = "window"
	var duty_def = C.role_def(d.claimed_role) if d.claim_public and C.has_role_def(d.claimed_role) else null
	if duty_def != null and duty_def.uses_night_duty_alibi(w, d, nd, was_out):
		var duty: Dictionary = duty_def.night_duty_alibi(w, d, nd, was_out, block, _mind(), C.block_name)
		lines.append(duty["line"])
		facts.append(duty["fact"])
		vantage = duty["vantage"]
		how = duty["how"]
		outcome = "duty"
		if not d.is_evil():
			duty_def.on_public_duty_account(w, d, nd)
	elif not was_out:
		lines.append(_home_alibi(w, d, nd))
		facts.append(_alibi_home(d, nd))
		vantage = d.home_block
		outcome = "home"
		if presses > 0:
			# Truly home and pressed again about it before the town: it stands by its account and
			# trusts the Demonologist less, as in private (MindPress._answer_pressed_night).
			var drop: float = (Tuning.Trust.QUESTION_FATIGUE_BASE + Tuning.Trust.QUESTION_FATIGUE_PRIVACY * _trait(d, "privacy")) * (1.0 - Tuning.Trust.QUESTION_FATIGUE_COMPOSURE_DAMP * _trait(d, "composure"))
			_mind().set_trust(w, d, d.trust - drop, "pressed again before the town about night %d, when they were home" % nd)
	else:
		var parts: Dictionary = _stakes(w, d)
		if presses > 0:
			parts["pressed_again"] = Tuning.Dialogue.PRESSED_AGAIN_OPENNESS * presses
		var walking_gift: bool = not d.is_evil() and d.secret.is_empty() and C.ROLES[d.role].get("night_walk", false)
		var outing: String = C.role_def(d.role).honest_outing(w, d, nd, _mind(), true) if not d.is_evil() and C.has_role_def(d.role) else ""
		if outing == "reveal":
			# A good gift that took them out (the Sexton's toll): come out with it before the town.
			# The account below tells of the toll, so the claim doesn't announce it again.
			d.dialogue_memory["toll_told_public"] = true
			MindMeeting._public_disclosure(w, d, lines, facts, false)
			var duty_out: Dictionary = C.role_def(d.role).night_duty_alibi(w, d, nd, was_out, block, _mind(), C.block_name)
			lines.append(duty_out["line"])
			facts.append(duty_out["fact"])
			vantage = duty_out["vantage"]
			how = duty_out["how"]
			outcome = "gift_outing"
		elif outing == "withhold" and (admitted or admitted_before(d, nd)) and not (presses > 0 and _gives_way(w, d, nd, parts)):
			_plain_account(w, d, nd, block, lines, facts)
			outcome = "admitted"
		elif outing == "withhold" and (admitted or admitted_before(d, nd)):
			# Pressed again, it gives the gift that took it out (Michael, Nov 20).
			MindMeeting._public_disclosure(w, d, lines, facts, false)
			lines.append(_say(d, "podium_gift_outing", "So yes, I was out %s, on %s. That was my gift's work." % [C.spoken_when(nd, w.day), C.block_name(block)],
				{"when": C.spoken_when(nd, w.day), "block": C.block_name(block)}))
			facts.append({"kind": "alibi", "subject": [d.id], "home": false, "day": nd, "phase": C.NIGHT, "source": d.id, "block": block,
				"text": "%s says they were out on %s %s, on their gift's work." % [d.name, C.block_name(block), C.spoken_when(nd, w.day)]})
			vantage = block
			how = "street"
			outcome = "gift_outing"
		elif outing == "withhold":
			w.dlog.think(d.id, "stonewall", "Pressed at the podium: keeps the night's errand (%s gift) to themself for now." % C.role_name(d.role))
			lines.append(_say(d, "podium_whereabouts_refusal", "Where I spend my nights is my own affair, and I'll not answer for %s here." % C.spoken_when(nd, w.day),
				{"when": C.spoken_when(nd, w.day)}))
			facts.append({"kind": "refusal", "subject": [d.id], "source": d.id, "day": nd, "phase": C.NIGHT, "public": true,
				"text": "%s refused, before the town, to say where they were %s." % [d.name, C.spoken_when(nd, w.day)]})
			_refused(w, d, grounds)
			outcome = "refusal"
		elif walking_gift:
			var cost: Dictionary = MindMeeting.reveal_cost(w, d)
			for k in cost:
				parts["cost_" + k] = -cost[k]
			parts["seen_out"] = Tuning.Meeting.PODIUM_SEEN_OUT
			if d.claim_public or _mind().decide(w, d, "podium_gift_outing", parts, "Pressed on night %d: admit I was out with my gift (%s)?" % [nd, d.role]):
				MindMeeting._public_disclosure(w, d, lines, facts, false)
				lines.append(_say(d, "podium_gift_outing", "So yes, I was out %s, on %s. That was my gift's work." % [C.spoken_when(nd, w.day), C.block_name(block)],
					{"when": C.spoken_when(nd, w.day), "block": C.block_name(block)}))
				facts.append({"kind": "alibi", "subject": [d.id], "home": false, "day": nd, "phase": C.NIGHT, "source": d.id, "block": block,
					"text": "%s says they were out on %s %s, on their gift's work." % [d.name, C.block_name(block), C.spoken_when(nd, w.day)]})
				vantage = block
				how = "street"
				outcome = "gift_outing"
		elif not d.is_evil() and not d.secret.is_empty():
			parts["privacy"] = (Tuning.Dialogue.CONFESS_PRIVACY_PIVOT - _trait(d, "privacy")) * Tuning.Dialogue.CONFESS_PRIVACY_SLOPE
			if confessed_before(d, nd) or _mind().decide(w, d, "podium_confess", parts, "Pressed on night %d: confess my errand (%s) before the town?" % [nd, d.secret.get("kind", "?")]):
				d.secret_known = true
				var me: String = d.secret.get("me", d.secret.get("text", ""))
				lines.append(_say(d, "confess_secret_public", "I wasn't out for anything wicked. I %s." % me, {"secret": me}))
				load("res://sim/burdens.gd").reveal_cost(w, d, w.living())
				facts.append(load("res://sim/burdens.gd").with_errand(w, d, {"kind": "secret", "subject": [d.id], "owner": d.id, "block": block, "day": nd, "phase": C.NIGHT, "source": d.id,
					"secret_kind": d.secret.get("kind", ""), "public": true,
					"text": "%s confessed before the town they were out on %s %s: %s %s." % [d.name, C.block_name(block), C.spoken_when(nd, w.day), d.name, d.secret.get("text", "")]}))
				vantage = block
				how = "street"
				outcome = "confess"
		if outcome == "" and d.is_evil() and presses > 0 and (admitted or admitted_before(d, nd)) and Press.back_into_walking_gift(w, d, nd) != "":
			# Evil pressed again about a night it owned, with nothing to tell: it comes out with
			# the spare walking gift it backed into, before the town.
			MindMeeting._public_disclosure(w, d, lines, facts, false)
			lines.append(_say(d, "podium_gift_outing", "So yes, I was out %s, on %s. That was my gift's work." % [C.spoken_when(nd, w.day), C.block_name(block)],
				{"when": C.spoken_when(nd, w.day), "block": C.block_name(block)}))
			facts.append({"kind": "alibi", "subject": [d.id], "home": false, "day": nd, "phase": C.NIGHT, "source": d.id, "block": block,
				"text": "%s says they were out on %s %s, on their gift's work." % [d.name, C.block_name(block), C.spoken_when(nd, w.day)]})
			vantage = block
			how = "street"
			outcome = "gift_outing"
		if outcome == "" and (admitted or admitted_before(d, nd)):
			# They've just owned a true sighting: a plain account, never a stonewall, and
			# no grudge against the Demonologist for "pressing" (any nominator can get here).
			_plain_account(w, d, nd, block, lines, facts)
			outcome = "admitted"
		if outcome == "":
			var prior: String = d.dialogue_memory.get("night_accounts", {}).get(str(nd), {}).get("kind", "")
			var bold: bool = false if admitted else (prior == "alibi") if prior in ["alibi", "refusal"] else _mind().decide(w, d, "podium_lie_or_stonewall",
				{"confidence": (_trait(d, "confidence") - 0.5) * Tuning.Dialogue.LIE_BOLD_CONF_SLOPE,
				"privacy_stonewalls": -(_trait(d, "privacy") - 0.5) * Tuning.Dialogue.LIE_BOLD_PRIVACY_SLOPE},
				"Pressed on night %d before the town: lie outright rather than refuse?" % nd)
			if bold:
				w.dlog.think(d.id, "lie", "Pressed before the town, said they were home %s, though they were out on %s." % [C.spoken_when(nd, -1), C.block_name(block)], {"lie": true})
				if not (nd in d.lied_nights):
					d.lied_nights.append(nd)
				lines.append(_home_alibi(w, d, nd))
				facts.append(_alibi_home(d, nd))
				vantage = d.home_block
				outcome = "lie"
			else:
				w.dlog.think(d.id, "stonewall", "Pressed at the podium: refuses to say where they were on night %d." % nd)
				lines.append(_say(d, "podium_whereabouts_refusal", "Where I spend my nights is my own affair, and I'll not answer for %s here." % C.spoken_when(nd, w.day),
					{"when": C.spoken_when(nd, w.day)}))
				facts.append({"kind": "refusal", "subject": [d.id], "source": d.id, "day": nd, "phase": C.NIGHT, "public": true,
					"text": "%s refused, before the town, to say where they were %s." % [d.name, C.spoken_when(nd, w.day)]})
				_refused(w, d, grounds)
				outcome = "refusal"
	var accounts: Dictionary = d.dialogue_memory.get("night_accounts", {})
	accounts[str(nd)] = facts[facts.size() - 1].duplicate(true) if outcome == "gift_outing" else facts[0].duplicate(true)
	d.dialogue_memory["night_accounts"] = accounts
	if vantage != "":
		_night_sightings(w, d, nd, vantage, how, lines, facts)
	_town_hears(w, d, facts)
	if pressed:
		Press.note_press(d, nd)
	return {"lines": lines, "facts": facts, "outcome": outcome, "night": nd, "presses": presses}

## A good walker that kept its gift's errand, pressed again before the town: does it give way?
## The podium's own gift-outing decision, with the press in its parts and the reveal's cost.
static func _gives_way(w, d, nd: int, parts: Dictionary) -> bool:
	var p2: Dictionary = parts.duplicate()
	var cost: Dictionary = MindMeeting.reveal_cost(w, d)
	for k in cost:
		p2["cost_" + k] = -cost[k]
	p2["seen_out"] = Tuning.Meeting.PODIUM_SEEN_OUT
	return _mind().decide(w, d, "podium_gift_outing", p2, "Pressed again on night %d before the town: give my gift (%s)?" % [nd, d.role])


## What they saw that night, told from where they say they were (the same gate public
## testimony uses, now that the account is on record). Evil adds its cover sighting.
static func _night_sightings(w, d, nd: int, vantage: String, how: String, lines: Array, facts: Array) -> void:
	if C.has_role_def(d.claimed_role):
		var withhold: String = C.role_def(d.claimed_role).withholds_night_sightings(d, nd, _mind())
		if withhold != "":
			return
	var reported: Array = []
	for b in d.beliefs:
		if b.get("kind", "") != "saw" or b.get("phase", -1) != C.NIGHT or int(b.get("day", -1)) != nd or not w.by_id.has(b.get("who", "")):
			continue
		if d.told_to.has(MindMeeting._town_sighting_key(d, b)) or not MindMeeting._public_sighting_allowed(w, d, b):
			continue
		reported.append(b)
	var ov: Dictionary = C.role_def(d.claimed_role).override_night_sightings(w, d, nd, reported) if C.has_role_def(d.claimed_role) else {}
	if ov.get("handled", false):
		reported = ov["reported"].filter(func(b): return not d.told_to.has(MindMeeting._town_sighting_key(d, b)))
	elif d.is_evil():
		var fake = Evil.fake_night_sighting(w, d, nd, vantage, how)
		if fake != null and not d.told_to.has(MindMeeting._town_sighting_key(d, fake)):
			reported.append(fake)
	var groups: Array = []
	for b in reported:
		var report: Dictionary = _mind().sighting_report(w, d, b, nd)
		d.told_to[MindMeeting._town_sighting_key(d, b)] = true
		MindMeeting._add_observation(groups, report.observation)
		facts.append(report.fact)
	lines.append_array(MindMeeting._observation_lines(d, groups, "town", "answer", true))


static func _home_alibi(w, d, nd: int) -> Dictionary:
	var rendered: Dictionary = Dialogue.compose(d.id, Dialogue.alibi_intent("alibi:%d" % nd, C.spoken_when(nd, w.day)),
		{"audience": "town", "speech_act": "answer", "trust": d.trust, "pressure": d.pressure}, d.dialogue_memory)
	return _mind().say(d, rendered["text"])


static func _alibi_home(d, nd: int) -> Dictionary:
	var f: Dictionary = _mind()._alibi_home(d, nd)
	f["public"] = true
	return f


# ---------------------------------------------------------------- press card

## Which board cards make sense to press this nominee with (the picker's filter).
static func card_fits(w, d, card: Dictionary) -> bool:
	if card.get("deleted", false) or card.get("tavern_gossip", false) or not card.get("pressable", true):
		return false
	var kind: String = card.get("kind", "")
	if not (kind in ["sighting", "info", "trace", "claim", "alibi", "secret", "vigil"]):
		return false
	# Whereabouts cards press on a night account; a daytime sighting gives nothing to answer.
	if kind in ["sighting", "alibi", "secret", "vigil"] and int(card.get("phase", -1)) != C.NIGHT:
		return false
	var subj: Array = card.get("subject", [])
	if d.id in subj or d.id in card.get("data", {}).get("pair", []):
		return true
	return kind == "claim" and card.get("source", "") != d.id and d.claim_public and card.get("role", "") == d.claimed_role


## Route a card to the answer it calls for. Returns {lines, facts, outcome, mode}.
static func press_card(w, d, card: Dictionary, grounds: bool) -> Dictionary:
	var kind: String = card.get("kind", "")
	if kind == "claim" and card.get("source", "") != d.id and d.claim_public and card.get("role", "") == d.claimed_role:
		var rival = w.by_id.get(card["source"])
		var role_disp: String = C.role_name(d.claimed_role)
		var line: Dictionary = _say(d, "press_counter_claim", "I am the %s. If %s says otherwise, %s is lying." % [role_disp, rival.name, rival.name],
			{"role": role_disp, "rival": rival.name})
		line["expression"] = "harsh"
		line["expression_strength"] = 2
		return {"lines": [line], "facts": [], "outcome": "counter_claim", "mode": "claim"}
	var nd: int = -1
	if kind in ["sighting", "alibi", "secret", "vigil", "trace"] and int(card.get("phase", C.NIGHT)) == C.NIGHT:
		nd = int(card.get("day", -1))
	if nd >= 0 and nd < w.day:
		var r: Dictionary = press_night(w, d, nd, grounds, false, true)
		r["mode"] = "night"
		# Shown a sighting, they may add what the death record says of that night (BACKLOG
		# "Explicit night-sighting rebuttals"): after the account, speech only, no weight.
		if kind == "sighting":
			var defence = load("res://sim/mind_defence.gd")
			var blk: String = str(card.get("block", ""))
			var reb: Dictionary = defence.night_route_rebuttal(w, d, nd, blk)
			if defence.rebuttal_fits_account(w, d, reb):
				r.lines.append(defence.rebuttal_line(w, d, reb))
				defence.note_rebuttal(w, d, reb, "At the podium")
				var s_eid: String = "sighting:%s:%s:%d:%s" % [str(card.get("source", "")), d.id, nd, blk]
				defence.hear_rebuttal(w, d, defence.rebuttal_scope(reb, s_eid))
				r["rebuttal"] = reb
		return r
	# A reading or anything else about them presses on their gift.
	var r2: Dictionary = press_readings(w, d) if d.claim_public else press_role(w, d, grounds)
	r2["mode"] = "gift"
	return r2


# ---------------------------------------------------------------- the town hears

## Public meeting receipts for what the nominee just said under the press. Claims and
## readings already went out through the public claim paths; sightings go through the
## usual public-sighting delivery; alibis, refusals, hints and confessions are heard here,
## weighted by each listener's trust in the speaker (as the defence is).
static func _town_hears(w, d, facts: Array) -> void:
	for f in facts:
		var kind: String = f.get("kind", "")
		if kind == "sighting":
			_social().deliver_public_sighting(w, d, f)
			continue
		if not (kind in ["alibi", "refusal", "hint", "secret"]):
			continue
		var card: Dictionary = f.duplicate(true)
		card["day"] = int(f.get("day", w.day))
		card["phase"] = int(f.get("phase", w.phase))
		var receipt: Dictionary = WorkshopLedger.Evidence.normalize_card(card)
		var eid: String = "podium:%s:%s" % [d.id, receipt.id]
		for l in w.living():
			if l == d:
				continue
			# "tell" + workshop_card is the kind the shared model reads as testimony
			# (Shared.prepare); the teller marks it as heard from the nominee themselves.
			_mind().ledger_hear(w, l, eid, [], 0.5 + 0.5 * l.npc_trust.get(d.id, 0.5), [d.id, -1, "report"],
				{"kind": "tell", "podium": kind, "text": f.get("text", ""), "workshop_card": receipt, "workshop_teller": d.id, "workshop_public": true})
