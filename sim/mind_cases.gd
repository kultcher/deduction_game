## Case and card evaluation: how an NPC weighs a card or a case on the board (split from
## `sim/mind.gd`; part of Mind's inheritance chain).
extends "res://sim/mind_shadow.gd"


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
			return conclusion.get("type", "") in ["good", "notdemon", "truthful", "secret", "marked", "red_herring"]
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
	var p = _mind().trait_of(owner, "privacy")
	var first = not owner.secret_spread
	owner.secret_spread = true
	var loss = Tuning.Trust.SECRET_SPREAD_BASE + Tuning.Trust.SECRET_SPREAD_PRIVACY * p
	_mind().set_trust(w, owner, owner.trust - (loss if first else loss * Tuning.Trust.SECRET_SPREAD_REPEAT_MULT), "the Demonologist spread my secret")
	if p >= 0.67:
		_mind().cap_trust(w, owner, Tuning.Trust.SECRET_CAP_HIGH_PRIVACY, "the Demonologist spread my secret (very private person)")
	elif p >= 0.34:
		_mind().cap_trust(w, owner, Tuning.Trust.SECRET_CAP_MID_PRIVACY, "the Demonologist spread my secret")

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
	var ins = _mind().trait_of(n, "insight")
	var class_w = {"speech": lerpf(1.0, 0.2, ins), "circumstantial": lerpf(1.0, 0.6, ins), "concrete": 1.0}[cls]
	var key: String = _mind().fact_id(card)
	var times: int = n.heard.get(key, 0)
	n.heard[key] = times + 1
	var rel: Array = []
	if src != "" and w.by_id.has(src) and src != n.id:
		rel = _mind().support_ref(card)
	return {"rel": rel, "relevance": relevance, "cred": cred, "cred_why": cred_why, "cls": cls, "class_w": class_w,
		"repeat": pow(0.35, times), "times": times, "key": key, "subj": subj}

## The player's case: "tell <n>: <suspect> is suspicious because <card>".
static func hear_accusation(w, n, suspect, card: Dictionary) -> Dictionary:
	_mind().on_question(w, n)
	if not n.is_shadow:
		_secret_used(w, card)
	var lines: Array = []
	var cw = card_weight(w, n, suspect, card)
	var strength = card_weight_against(w, card, suspect.id)
	var relevance: float = cw["relevance"] * strength
	var times: int = cw["times"]
	var cls: String = cw["cls"]
	var ins = _mind().trait_of(n, "insight")
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
	_mind().ledger_hear(w, n, "tell:%s>%s" % [cw["key"], suspect.id], [], 0.25 * (0.5 + n.credibility), cw["rel"],
		{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": false})
	n.used_facts[cw["key"] + ">" + suspect.id] = true
	if times > 0:
		lines.append(_mind().say_voiced(n, "present_repeat_private", "You've told me that already."))
	elif suspect == n:
		lines.append(Presentations.render_evil_override(w, n, {"type": "evil", "a": n.id}, "reject", false, false, "player", "Me? That's madness.", _mind()._tic_memory(n)))
	elif cls == "speech" and ins >= 0.67:
		lines.append(_mind().say_voiced(n, "present_unmoved", "That's only talk. Show me something real.", {"target": suspect.name}))
	else:
		lines.append(_mind().say_voiced(n, "present_partial", "Maybe. I'll keep an eye on %s." % suspect.name, {"target": suspect.name}))
	return {"lines": lines, "facts": [], "repeated": times > 0}

## The player speaks for someone in private, citing a card ("present <card#> for <name>").
static func hear_defence(w, n, whos, card: Dictionary) -> Dictionary:
	_mind().on_question(w, n)
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
		var key = "support_self:" + _mind().fact_id(card)
		var repeated: bool = n.heard.has(key)
		n.heard[key] = n.heard.get(key, 0) + 1
		if repeated:
			lines.append(Presentations.render_self_support(n, "repeat", "You've told me that already. Thank you.", _mind()._tic_memory(n)))
		elif card_clears(card, n.id, true):
			_mind().set_trust(w, n, n.trust + Tuning.Trust.SELF_SUPPORT_BONUS, "the Demonologist spoke up for me")
			lines.append(Presentations.render_self_support(n, "thanks", "Thank you for believing me.", _mind()._tic_memory(n)))
		else:
			lines.append(Presentations.render_self_support(n, "weak", "I appreciate the support, but I'm not sure that explains it.", _mind()._tic_memory(n)))
		return {"lines": lines, "facts": [], "repeated": repeated, "workshop": shared_self}
	if n.is_evil():
		var r = w.rng.randf()
		w.observe_decision(n, "defence_reply", r < (0.6 if who.is_evil() else 0.7), {"probability": 0.6 if who.is_evil() else 0.7, "draw": r, "comparison": "<", "inputs": {}}, who.id)
		if who.is_evil():
			lines.append(_mind().say_voiced(n, "present_accept_open" if r < 0.6 else "present_partial", "Fair enough. I'll think better of %s." % who.name if r < 0.6 else "Maybe. I'll keep an open mind about %s." % who.name, {"target": who.name}))
		else:
			lines.append(_mind().say_voiced(n, "present_partial" if r < 0.7 else "present_unmoved", "Maybe. I'll keep an open mind about %s." % who.name if r < 0.7 else "That doesn't clear %s." % who.name, {"target": who.name}))
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
		var hx = _mind().ledger_hear(w, n, "for:%s>%s" % [cw["key"], x.id], [], 0.25 * (0.5 + n.credibility) / group.size(), cw["rel"],
			{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": false})
		times = maxi(times, hx["times"])
	if times > 0:
		lines.append(_mind().say_voiced(n, "present_repeat_private", "You've told me that already."))
	else:
		lines.append(_mind().say_voiced(n, "present_partial", "Maybe. I'll keep an open mind about %s." % gname, {"target": gname}))
	return {"lines": lines, "facts": [], "repeated": times > 0}

## A card that implicates one of several people (a Seer "yes" on two): the case is split
## between them. Evil hears it through the usual mask.
static func hear_group_case(w, n, group: Array, card: Dictionary) -> Dictionary:
	_mind().on_question(w, n)
	var lines: Array = []
	var gname = " and ".join(PackedStringArray(group.map(func(x): return x.name)))
	if n.is_evil():
		for x in group:
			if x.is_evil():
				Evil.add_intel(w, n, "player_suspects", x.id, 0.0, "the Demonologist thinks it's one of %s" % gname)
		var grp_partial: bool = w.decision_roll(n, "group_defence_reply", 0.6)
		lines.append(_mind().say_voiced(n, "present_partial" if grp_partial else "present_accept_open", "Maybe. I'll keep an eye on them both." if grp_partial else "That... does look bad for one of them.", {"target": gname}))
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
		var h = _mind().ledger_hear(w, n, "tell:%s>%s" % [cw["key"], x.id], [], 0.25 * (0.5 + n.credibility) / group.size(), cw["rel"],
			{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": false})
		n.used_facts[cw["key"] + ">" + x.id] = true
		times = maxi(times, h["times"])
	if times > 0:
		lines.append(_mind().say_voiced(n, "present_repeat_private", "You've told me that already."))
	else:
		lines.append(_mind().say_voiced(n, "present_partial", "Maybe. I'll keep an eye on them both.", {"target": gname}))
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
	_mind().ledger_hear(w, v, "pub:%s:%s>%s" % [direction, cw["key"], nominee.id], [], 0.2 * (0.5 + v.credibility), cw["rel"],
		{"kind": "tell", "text": card.get("text", ""), "workshop_card": WorkshopLedger.Evidence.normalize_card(card), "workshop_public": true})
	if direction == "accuse":
		v.used_facts[cw["key"] + ">" + nominee.id] = true

## Tavern gossip. Returns {lines, facts}.
static func gossip(w) -> Dictionary:
	var present: Array = w.npcs_at("tavern").filter(func(n): return not n.silenced)
	if present.is_empty():
		return {"lines": ["The tavern is nearly empty. Nobody to overhear."], "facts": []}
	var weights: Array = present.map(func(m): return 0.1 + _mind().trait_of(m, "gossip"))
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
		w.observe_decision(speaker, "gossip_speaker", speaker.name, {"weights": speaker_weights, "selected": speaker.id, "draw": observed_draw, "comparison": "cumulative weights", "inputs": {"gossip": _mind().trait_of(speaker, "gossip")}})
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
	var ranked = _mind().ranked_suspects(w, speaker)
	if not ranked.is_empty() and _mind().susp(speaker, ranked[0].id) >= Tuning.Social.TAVERN_OVERHEAR_MIN_SUSP and not speaker.told_to.has("player|gossip_susp:%s:%d" % [ranked[0].id, w.day]):
		var t = ranked[0]
		speaker.told_to["player|gossip_susp:%s:%d" % [t.id, w.day]] = true
		w.dlog.think(speaker.id, "gossip", "Shares their suspicion of %s." % t.id)
		var why: String = Evil.cite(w, speaker, _mind().citable_reason(w, speaker, t.id, "town"))
		var tail = (", because " + why) if why != "" else ". Something's off about them, apparently"
		return {"lines": ["You overhear %s muttering that %s can't be trusted%s." % [speaker.name, t.name, tail]],
			"facts": [{"kind": "opinion", "subject": [t.id], "source": speaker.id, "text": "Gossip: %s distrusts %s." % [speaker.name, t.name]}]}
	return {"lines": ["You overhear %s complaining about the price of bread. Nothing useful." % speaker.name], "facts": []}

static func _observation_scene(n, b: Dictionary, day: int) -> Dictionary:
	return MindDialogue._observation_scene(n, b, day)
