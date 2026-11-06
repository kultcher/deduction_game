## Meeting plan M2c (docs/meeting_flow_plan.md section 3, Step 4): supporters.
##
## After the defence and the podium press, the bystanders are offered the floor one at a
## time, in seat order (clockwise from the nominee, like the vote). Each decides for
## themselves from what they know and what's been said; nobody picks a "minimal set".
## The town stops listening after Tuning.Meeting.MAX_SUPPORTERS_SHOWN speakers.
##
## Moves, strongest first for each bystander:
##   counter_claim  (against)  the nominee claims the bystander's own gift: they come out
##                             with it. Speaks before anyone else.
##   exonerate      (for)      an unshared reading that clears the nominee, or seeing them go
##                             in for the night on a night they're accused of walking. A
##                             reading costs cover, so it's weighed (`support_reveal`):
##                             belief they're good, what their role is still worth, what
##                             speaking costs, and the danger they're in. Short of that, a hint.
##   vouch          (for)      the nominee confided their gift before today, and the bystander
##                             trusts them (M1's peer gossip pays off here).
##   pile_on        (against)  the bystander suspects them and has a reason of their own.
##   vibes          (for/against) plain liking or distrust, said aloud: social, not evidence.
##
## Danger (how likely they hang if the bystander stays quiet) is re-read before every
## offer, so once a trusted voice has cleared them the next one keeps their own cover.
## Evil bystanders weigh it as their good self would (the shadow) and break cover only
## through Mind.evil_override: to defend a teammate in danger, or to pile onto the
## scapegoat.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")
const Evil = preload("res://sim/evil.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const WorkshopLedger = preload("res://workshop/shared_ledger.gd")

static var _mind_script


static func _mind():
	if _mind_script == null:
		_mind_script = load("res://sim/mind.gd")
	return _mind_script


## Run Step 4 for the pending nomination. Returns {"lines", "facts", "speakers"} where
## speakers is [{id, move, side}] in speaking order.
static func run(w, nominee_id: String, nominator_id: String) -> Dictionary:
	var out: Dictionary = {"lines": [], "facts": [], "speakers": []}
	if not w.by_id.has(nominee_id):
		return out
	var d = w.by_id[nominee_id]
	_mind().flush_beliefs(w)
	var ctx: Dictionary = {"for_ids": [], "accused": 0, "spoken": [], "case_facts": w.meeting.get("pending", {}).get("case_facts", [])}
	var queue: Array = candidates(w, d, nominator_id)
	# Anyone holding the gift the nominee claims speaks first.
	var first: Array = queue.filter(func(s): return _counter_claim_ready(w, s, d))
	for s in first:
		if out.speakers.size() >= Tuning.Meeting.MAX_SUPPORTERS_SHOWN:
			break
		_speak(w, s, d, {"move": "counter_claim", "side": "against"}, ctx, out)
		queue.erase(s)
	for s in queue:
		if out.speakers.size() >= Tuning.Meeting.MAX_SUPPORTERS_SHOWN:
			break
		var choice: Dictionary = choose(w, s, d, ctx)
		w.dlog.add("support_offer", s.id, d.id, {"move": choice.get("move", ""), "side": choice.get("side", ""), "danger": snappedf(danger(w, s, d, ctx), 0.001)},
			"%s is offered the floor on %s: %s." % [s.name, d.name, choice.get("move", "") if choice.get("move", "") != "" else "stays quiet"])
		if choice.get("move", "") == "":
			continue
		_speak(w, s, d, choice, ctx, out)
	return out


## Who may speak: living, unsilenced townsfolk other than the nominee and the nominator,
## in seat order from the nominee.
static func candidates(w, d, nominator_id: String) -> Array:
	var out: Array = []
	for id in w.vote_order(d.id):
		if id == "player" or id == d.id or id == nominator_id or not w.by_id.has(id):
			continue
		var s = w.by_id[id]
		if s.alive and not s.silenced:
			out.append(s)
	return out


## How likely `d` is to hang if `s` stays quiet: high unless someone else is firmly on the
## block; voices already raised for them take some of it away (as far as `s` trusts those
## voices), voices against add.
static func danger(w, s, d, ctx: Dictionary) -> float:
	var base: float = 1.0 - MindMeeting.block_safety(w, d)
	var defended: float = 0.0
	for id in ctx.get("for_ids", []):
		defended += float(s.npc_trust.get(id, 0.5))
	return clampf(base * (1.0 - Tuning.Meeting.SUPPORT_DANGER_DEFENCE_DAMPING * minf(defended, 1.0))
		+ Tuning.Meeting.SUPPORT_DANGER_PER_ACCUSER * int(ctx.get("accused", 0)), 0.0, 1.0)


## The bystander's move: a good mind decides as itself; an evil one as its good self would,
## unless breaking cover is worth it.
static func choose(w, s, d, ctx: Dictionary) -> Dictionary:
	if not s.is_evil():
		return _choose_good(w, s, d, ctx)
	var sh = _mind().shadow_eval(w, s, func(sh): return _choose_good(w, sh, d, ctx))
	var shadow_choice: Dictionary = sh if sh is Dictionary else {}
	var dang: float = danger(w, s, d, ctx)
	if Evil.is_teammate(w, s, d.id):
		var stakes: float = Tuning.Meeting.SUPPORT_EVIL_DEFEND_STAKES * Evil.teammate_value(w, d.id) * dang
		if shadow_choice.get("side", "") == "against":
			# Their good self would speak against a teammate: keep quiet instead, if it's worth it.
			if _mind().evil_override(w, s, "support", stakes, 0.5, "stay quiet rather than speak against teammate %s" % d.id):
				return {}
			return shadow_choice
		if shadow_choice.get("side", "") != "for" and _mind().evil_override(w, s, "support", stakes, 1.0, "speak up for teammate %s" % d.id):
			return {"move": "vibes", "side": "for"}
		return shadow_choice
	if d.id == str(w.evil_plan.get("scapegoat", "")) and shadow_choice.get("side", "") != "against":
		var push: float = Tuning.Meeting.SUPPORT_EVIL_PILE_STAKES * dang
		if _mind().evil_override(w, s, "support", push, 1.0, "pile onto scapegoat %s" % d.id):
			return {"move": "pile_on", "side": "against"}
	# An evil bystander never reveals a "clearing" reading it doesn't hold: its good self's
	# exonerate is played from the bluff's own (fabricated) readings, as any reveal is.
	return shadow_choice


static func _choose_good(w, s, d, ctx: Dictionary) -> Dictionary:
	var dang: float = danger(w, s, d, ctx)
	var sus: float = MindMeeting.susp(s, d.id)
	var trust: float = float(s.npc_trust.get(d.id, 0.5))
	# 1. Exonerate: a reading that clears them, or a window alibi on a night they're accused of.
	var clearing: Array = clearing_readings(s, d)
	if not clearing.is_empty():
		var parts: Dictionary = exonerate_parts(w, s, d, true, dang)
		var why: String = "Reveal what clears %s (danger %.2f)?" % [d.id, dang]
		if _mind().decide(w, s, "support_reveal", parts, why):
			return {"move": "exonerate", "side": "for", "how": "reveal", "entries": clearing}
		if benefit_clears_hint(parts):
			return {"move": "exonerate", "side": "for", "how": "hint", "entries": clearing}
	var alibis: Array = window_alibis(w, s, d, ctx)
	if not alibis.is_empty():
		var a_parts: Dictionary = exonerate_parts(w, s, d, false, dang)
		if _mind().decide(w, s, "support_alibi", a_parts, "Say I saw %s stay in that night?" % d.id):
			return {"move": "exonerate", "side": "for", "how": "alibi", "beliefs": alibis}
	# 2. Vouch: they confided their gift before today, and I trust them.
	var kc: Dictionary = s.known_claims.get(d.id, {})
	if not kc.is_empty() and int(kc.get("first_claimed_day", 99)) <= w.day - 1 and trust >= Tuning.Meeting.VOUCH_MIN_TRUST and sus < Tuning.Meeting.VOUCH_MAX_SUSP:
		var v_parts: Dictionary = {"base": Tuning.Meeting.VOUCH_BASE,
			"believes_good": ((1.0 - sus) - Tuning.Meeting.SUPPORT_GOOD_PIVOT) * Tuning.Meeting.SUPPORT_GOOD_SLOPE * dang,
			"trust": (trust - 0.5) * Tuning.Meeting.SUPPORT_TRUST_SLOPE * dang}
		if _mind().decide(w, s, "support_vouch", v_parts, "Vouch for %s's early claim?" % d.id):
			return {"move": "vouch", "side": "for", "claim": kc}
	# 3. Pile on: I suspect them, with a reason of my own the town hasn't heard today.
	if sus >= Tuning.Meeting.SUPPORT_PILE_ON_MIN_SUSP and _has_own_reason(w, s, d, ctx):
		var p_parts: Dictionary = {"base": Tuning.Meeting.SUPPORT_PILE_ON_BASE,
			"suspicion": (sus - Tuning.Meeting.SUPPORT_PILE_ON_MIN_SUSP) * Tuning.Meeting.SUPPORT_PILE_ON_SLOPE,
			"confidence": (MindMeeting.trait_of(s, "confidence") - 0.5) * Tuning.Meeting.ACCUSE_CONFIDENCE_SLOPE,
			"heard_against": -0.3 * int(ctx.get("accused", 0))}
		if _mind().decide(w, s, "support_pile_on", p_parts, "Add my own reason against %s?" % d.id):
			return {"move": "pile_on", "side": "against"}
	# 4. Vibes: plain liking or distrust.
	var gossip: float = MindMeeting.trait_of(s, "gossip")
	if trust >= Tuning.Meeting.VIBES_TRUST_MIN and sus < Tuning.Meeting.VOUCH_MAX_SUSP:
		var f_parts: Dictionary = {"base": Tuning.Meeting.VIBES_BASE, "trust": (trust - Tuning.Meeting.VIBES_TRUST_MIN) * 4.0 * dang, "gossip": (gossip - 0.5)}
		if _mind().decide(w, s, "support_vibes", f_parts, "Speak up for %s?" % d.id):
			return {"move": "vibes", "side": "for"}
	elif sus >= Tuning.Meeting.VIBES_SUSP_MIN:
		var g_parts: Dictionary = {"base": Tuning.Meeting.VIBES_BASE, "suspicion": (sus - Tuning.Meeting.VIBES_SUSP_MIN) * 3.0, "gossip": (gossip - 0.5),
			"heard_against": -0.3 * int(ctx.get("accused", 0))}
		if _mind().decide(w, s, "support_vibes", g_parts, "Say I don't trust %s?" % d.id):
			return {"move": "vibes", "side": "against"}
	return {}


## The four groups of the self-exposing defence (plan 4B), as decision parts. `reading`
## says whether speaking means revealing a gift's reading (costs cover) or only an
## alibi (costs nothing but saying it).
static func exonerate_parts(w, s, d, reading: bool, dang: float) -> Dictionary:
	var sus: float = MindMeeting.susp(s, d.id)
	var good: float = ((1.0 - sus) - Tuning.Meeting.SUPPORT_GOOD_PIVOT) * Tuning.Meeting.SUPPORT_GOOD_SLOPE
	if reading:
		good += Tuning.Meeting.SUPPORT_CLEARING_READING
	var parts: Dictionary = {"base": Tuning.Meeting.SUPPORT_BASE,
		"believes_good": good * dang,
		"trust": (float(s.npc_trust.get(d.id, 0.5)) - 0.5) * Tuning.Meeting.SUPPORT_TRUST_SLOPE * dang}
	var belief01: float = clampf(1.0 - sus, 0.0, 1.0)
	var pv: Dictionary = protect_value(w, s, d)
	for k in pv:
		parts["worth_" + k] = pv[k] * belief01 * dang
	if reading:
		var cost: Dictionary = MindMeeting.reveal_cost(w, s)
		for k in cost:
			parts["cost_" + k] = -cost[k] * Tuning.Meeting.SUPPORT_REVEAL_COST_SCALE
	return parts


## A hint instead of a reveal: the benefit side clears a fraction of the cost.
static func benefit_clears_hint(parts: Dictionary) -> bool:
	var benefit: float = 0.0
	var cost: float = 0.0
	for k in parts:
		if str(k).begins_with("cost_"):
			cost -= float(parts[k])
		elif k != "base":
			benefit += float(parts[k])
	return cost > 0.0 and benefit >= Tuning.Meeting.SUPPORT_HINT_FRACTION * cost


## What `s` believes the nominee's role is still worth, as decision parts.
static func protect_value(w, s, d) -> Dictionary:
	var role: String = ""
	if d.claim_public:
		role = d.claimed_role
	else:
		role = str(s.known_claims.get(d.id, {}).get("role", ""))
	var parts: Dictionary = {}
	if role == "" or not C.has_role_def(role):
		parts["unknown_role"] = Tuning.Meeting.PROTECT_VALUE_UNKNOWN
		return parts
	C.role_def(role).score_protect_value(w, d, parts)
	return parts


## Unshared readings of `s` that speak for `d`.
static func clearing_readings(s, d) -> Array:
	var out: Array = []
	for e in s.info_log:
		if e.get("shared", false) or e.get("disowned", false):
			continue
		if d.id in Gifts.clears(e):
			out.append(e)
	return out


## Nights `s` saw `d` go in and stay in, among nights the case puts `d` out.
static func window_alibis(w, s, d, ctx: Dictionary) -> Array:
	var nights: Dictionary = {}
	for f in ctx.get("case_facts", []):
		if int(f.get("phase", -1)) == C.NIGHT and d.id in f.get("subject", []) and not f.get("home", false):
			nights[int(f.get("day", -1))] = true
	for c in w.public_log:
		if c.get("kind", "") == "sighting" and d.id in c.get("subjects", []):
			nights[int(c.get("day", -1))] = true
	var out: Array = []
	for b in s.beliefs:
		if b.get("kind", "") == "stayed_in" and b.get("who", "") == d.id and nights.has(int(b.get("day", -2))):
			if not s.told_to.has("town|alibi:%s:%d" % [d.id, int(b.day)]):
				out.append(b)
	return out


static func _counter_claim_ready(w, s, d) -> bool:
	if s.is_evil() or s.claim_public or not d.claim_public or d.claimed_role == "":
		return false
	return s.role == d.claimed_role and C.has_role_def(s.role)


static func _has_own_reason(w, s, d, ctx: Dictionary) -> bool:
	var rs: Dictionary = MindMeeting.reason_status(w, s, d.id)
	return rs.get("kind", "none") in ["private", "relay", "player"]


## Say it, apply it, and re-read the room for the next offer.
static func _speak(w, s, d, choice: Dictionary, ctx: Dictionary, out: Dictionary) -> void:
	var lines: Array = []
	var facts: Array = []
	match choice.get("move", ""):
		"counter_claim":
			MindMeeting._public_disclosure(w, s, lines, facts)
			lines.append(_mind().say_voiced(s, "support_counter_claim", "%s is lying. That gift is mine." % d.name, {"target": d.name}))
			_stance_against(w, s, d)
			facts.append({"kind": "accusation", "subject": [d.id], "source": s.id, "text": "%s says %s's claim of the %s is false: it's their own gift." % [s.name, d.name, C.role_name(s.role)], "hint": false})
		"exonerate":
			match choice.get("how", ""):
				"reveal":
					MindMeeting._public_disclosure(w, s, lines, facts)
					lines.append(_mind().say_voiced(s, "support_exonerate", "That's why I won't see %s hang." % d.name, {"target": d.name}))
				"hint":
					lines.append(_mind().say_voiced(s, "support_hint", "I have reason to believe %s is innocent, though I'm not ready to say why." % d.name, {"target": d.name}))
					facts.append({"kind": "hint", "subject": [d.id], "source": s.id, "stance": "for", "day": w.day, "phase": w.phase,
						"text": "%s hints at a private reason to believe %s is innocent." % [s.name, d.name]})
				"alibi":
					for b in choice.get("beliefs", []):
						var nd: int = int(b.day)
						lines.append(_mind().say_voiced(s, "support_window_alibi", "From my window %s, I saw %s go in for the night, and they never came out." % [C.spoken_when(nd, w.day), d.name],
							{"when": C.spoken_when(nd, w.day), "target": d.name}))
						facts.append({"kind": "alibi", "subject": [d.id], "home": true, "witness": true, "day": nd, "phase": C.NIGHT, "source": s.id, "block": b.get("block", d.home_block),
							"text": "%s says they saw %s go home for the night on night %d and not come out (from their window)." % [s.name, d.name, nd]})
						s.told_to["town|alibi:%s:%d" % [d.id, nd]] = true
					_town_hears(w, s, facts)
			_stance_for(w, s, d)
		"vouch":
			var kc: Dictionary = choice.get("claim", {})
			var role: String = str(kc.get("role", ""))
			if d.claim_public and d.claimed_role == role and role != "":
				lines.append(_mind().say_voiced(s, "support_vouch_named", "%s confided to me back on day %d that they were the %s, and their word has held steady since." % [d.name, int(kc.get("first_claimed_day", w.day - 1)), C.role_name(role)],
					{"target": d.name, "day": str(int(kc.get("first_claimed_day", w.day - 1))), "role": C.role_name(role)}))
			else:
				lines.append(_mind().say_voiced(s, "support_vouch", "%s trusted me with their calling early on, and nothing they've done contradicts it." % d.name, {"target": d.name}))
			facts.append({"kind": "opinion", "subject": [d.id], "source": s.id, "stance": "for", "vouch": true, "day": w.day, "phase": w.phase,
				"text": "%s vouches for %s: they confided their gift early, and it has held." % [s.name, d.name]})
			_stance_for(w, s, d)
		"pile_on":
			var acc: Dictionary = MindMeeting.accuse_named(w, s, d, lines, facts)
			if acc.has("line"):
				lines.append(acc.line)
			if acc.has("fact"):
				facts.append(acc.fact)
		"vibes":
			if choice.get("side", "") == "for":
				lines.append(_mind().say_voiced(s, "support_vibes_for", "I've known %s long enough. I don't believe it of them." % d.name, {"target": d.name}))
				facts.append({"kind": "opinion", "subject": [d.id], "source": s.id, "stance": "for", "day": w.day, "phase": w.phase, "text": "%s speaks up for %s." % [s.name, d.name]})
				_stance_for(w, s, d)
			else:
				lines.append(_mind().say_voiced(s, "support_vibes_against", "Something about %s has never sat right with me." % d.name, {"target": d.name}))
				facts.append({"kind": "opinion", "subject": [d.id], "source": s.id, "stance": "against", "day": w.day, "phase": w.phase, "text": "%s distrusts %s." % [s.name, d.name]})
				_stance_against(w, s, d)
	var side: String = choice.get("side", "")
	if side == "for":
		ctx["for_ids"].append(s.id)
	elif side == "against":
		ctx["accused"] = int(ctx.get("accused", 0)) + 1
	ctx["spoken"].append(s.id)
	out.lines.append_array(lines)
	out.facts.append_array(facts)
	out.speakers.append({"id": s.id, "move": choice.get("move", ""), "side": side, "how": choice.get("how", "")})
	w.meeting["pending"]["case_facts"] = w.meeting.get("pending", {}).get("case_facts", []) + facts
	w.dlog.add("supporter", s.id, d.id, {"move": choice.get("move", ""), "side": side, "how": choice.get("how", "")},
		"%s speaks %s %s (%s)." % [s.name, "for" if side == "for" else "against", d.name, choice.get("move", "")])
	_mind().flush_beliefs(w)


static func _stance_for(w, s, d) -> void:
	w.defences[s.id] = {"target": d.id, "day": w.day}
	for l in w.living():
		MindMeeting.refresh_consensus(w, l, d.id)


static func _stance_against(w, s, d) -> void:
	var prev: String = w.stances.get(s.id, {}).get("target", "")
	w.stances[s.id] = {"target": d.id, "day": w.day, "hint": false}
	for l in w.living():
		MindMeeting.refresh_consensus(w, l, d.id)
		if prev != "" and prev != d.id:
			MindMeeting.refresh_consensus(w, l, prev)


## Every other living listener takes a witness's alibi as testimony (as the podium press
## does for the nominee's own account).
static func _town_hears(w, s, facts: Array) -> void:
	for f in facts:
		if f.get("kind", "") != "alibi":
			continue
		var card: Dictionary = f.duplicate(true)
		var receipt: Dictionary = WorkshopLedger.Evidence.normalize_card(card)
		var eid: String = "support:%s:%s" % [s.id, receipt.id]
		for l in w.living():
			if l == s:
				continue
			_mind().ledger_hear(w, l, eid, [], 0.5 + 0.5 * l.npc_trust.get(s.id, 0.5), [s.id, -1, "report"],
				{"kind": "tell", "support": "alibi", "text": f.get("text", ""), "workshop_card": receipt, "workshop_teller": s.id, "workshop_public": true})
