## Answers about a gift, a night and the day: readings, night accounts and alibis,
## sightings (split from `sim/mind_dialogue.gd`).
extends "res://sim/mind_dialogue_base.gd"


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
		_dialogue().on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var evil: bool = n.is_evil()
	var role: String = w.evil_plan["bluffs"][n.id] if evil else n.role
	var gate: Dictionary = _dialogue().disclosure_gate(w, n, force_tier, trace_id)
	var target: int = gate["target"]
	var tier: int = gate["tier"]
	var withholding: bool = gate["withholding"]
	if tier == 2 and C.hint_package(w, role) == "":
		tier = 1  # every family the gift is in has only it on this script: a hint would name it
	if tier <= 1:
		if _dialogue()._afraid(w, n):
			var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true, "fear": true,
				"text": "%s won't say whether they have a gift: afraid it would make them the Demon's next mark." % n.name}
			var ask: Dictionary = _dialogue()._protection_request(w, n, refusal)
			if not ask.is_empty():
				n.max_tier = maxi(n.max_tier, 1)
				return {"lines": [ask["line"]], "facts": [], "request": ask}
			lines.append(say_voiced(n, "fear_gift_refusal", "If I say what I am, I'll be dead by morning. Ask me again when it's safer."))
			facts.append(refusal)
		else:
			var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true,
				"text": "%s refused to say whether they have a gift." % n.name}
			var ask: Dictionary = _dialogue()._confidence_request(w, n, 3, refusal)
			if not ask.is_empty():
				n.max_tier = maxi(n.max_tier, 1)
				return {"lines": [ask["line"]], "facts": [], "request": ask}
			lines.append(gift_refusal(n))
			facts.append(refusal)
		n.max_tier = maxi(n.max_tier, 1)
		return {"lines": lines, "facts": facts}
	if tier == 2:
		var pk: String = C.hint_package(w, role)
		if evil:
			w.dlog.think(n.id, "lie", "Hinted at being the %s, as cover." % C.role_name(role), {"lie": true})
		var pkg_fb: String = C.HINT_PACKAGES[pk]["text"] + " That's all I'll say."
		lines.append(say_voiced(n, "hint_pkg_" + pk, pkg_fb))
		facts.append({"kind": "hint", "subject": [n.id], "source": n.id, "private": true, "package": pk,
			"roles": C.HINT_PACKAGES[pk]["roles"],
			"text": "%s hinted at %s (%s)." % [n.name, C.HINT_PACKAGES[pk]["name"],
				C.package_roles_text(pk, w.case_script)]})
		n.max_tier = 2
		return {"lines": lines, "facts": facts}
	# Tier 3+: names the gift.
	var first_time = n.max_tier < 3 and not n.claim_public
	n.claimed_role = role
	if evil:
		w.dlog.think(n.id, "lie", "Told you they were the %s, as cover." % C.role_name(role), {"true_role": n.role})
	if first_time:
		var reveal_cue: String = Dialogue.exchange_cue(n.dialogue_memory, "gift", n.id)
		var contextual: String = Dialogue.gift_reveal(n.id, C.role_name(role), reveal_cue)
		if contextual != "":
			lines.append(say(n, contextual))
		elif w.day < 2 and (n.pressed_today - (1 if count_question else 0)) < 2:
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
		# Evil owns only the nights its bluffed duty now tells of; any other night keeps the
		# story it told (an owned night it would then deny would be a worse slip).
		var owning: Array = n.lied_nights.filter(func(x): return not evil or _press().bluff_duty_covers(w, n, role, x))
		if C.ROLES[role].get("night_walk", false) and not owning.is_empty():
			# The nights they were out, owned now it has a reason: by what they actually said
			# about each night (a false "home", a refusal, or nothing yet).
			var by_account: Dictionary = {"alibi": [], "refusal": [], "none": []}
			for x in owning:
				var said: String = str(n.dialogue_memory.get("night_accounts", {}).get(str(x), {}).get("kind", ""))
				by_account["alibi" if said == "alibi" else ("refusal" if said == "refusal" else "none")].append(x)
			var spoken = func(nights: Array) -> String:
				return " and ".join(PackedStringArray(nights.map(func(x): return C.spoken_when(x, w.day))))
			if not by_account.alibi.is_empty():
				var ns: String = spoken.call(by_account.alibi)
				lines.append(say_voiced(n, "own_night_lie", "So yes: I was out %s, whatever I told you. I wasn't ready to tell you why." % ns, {"nights": ns}))
			if not by_account.refusal.is_empty():
				var nr: String = spoken.call(by_account.refusal)
				lines.append(say_voiced(n, "own_night_refusal", "That's why I wouldn't say where I was %s. I was out on the gift's business." % nr, {"nights": nr}))
			if not by_account.none.is_empty():
				var nn: String = spoken.call(by_account.none)
				lines.append(say_voiced(n, "own_night_out", "So yes, I was out %s. That's the gift's work." % nn, {"nights": nn}))
			w.dlog.think(n.id, "admit", "Owns the night(s) out now the gift is out: lied %s, refused %s, unasked %s.%s" % [str(by_account.alibi), str(by_account.refusal), str(by_account.none),
				(" Evil: the bluffed %s's duty covers them." % C.role_name(role)) if evil else ""], {"lie": evil} if evil else {})
			n.lied_nights = n.lied_nights.filter(func(x): return not (x in owning))
	else:
		lines.append(say_voiced(n, "repeat_gift_confirm", "As you know, I'm the %s." % C.role_name(role), {"role": C.role_name(role)}))
	facts.append({"kind": "claim", "subject": [n.id], "role": role, "source": n.id, "private": not n.claim_public,
		"text": "%s %s the %s." % [n.name, "claims to be" if n.claim_public else "told you privately they are", C.role_name(role)]})
	if first_time:
		set_trust(w, n, n.trust + Tuning.Trust.SHARED_GIFT_FIRST_TIME_BONUS, "shared their gift with the Demonologist")
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
		w.dlog.think(n.id, "lie", "Recited its made-up %s readings." % C.role_name(role))
	if not first_time and not readings.is_empty(): lines.pop_front()
	# Asked again with something new: say the new reading and stand by the old ones, rather
	# than reciting the whole history before reaching the news. (Facts still cover them all.)
	var told: Dictionary = n.dialogue_memory.get("told_player_readings", {})
	var recite: Array = readings
	if not first_time:
		var fresh: Array = readings.filter(func(e): return not told.has(str(n.info_log.find(e))))
		if not fresh.is_empty() and fresh.size() < readings.size():
			recite = fresh
			lines.append(say_voiced(n, "readings_stand", "My earlier readings stand as I told you."))
	for e in readings:
		told[str(n.info_log.find(e))] = true
	n.dialogue_memory["told_player_readings"] = told
	var reports = info_lines(w, n, recite, "player", not lines.is_empty())
	if not reports.is_empty():
		lines.append(say(n, " ".join(PackedStringArray(reports.map(func(line): return line.text)))))
	var PsychRoleD = preload("res://sim/roles/psychologist.gd")
	for e in readings:
		facts.append(info_fact(w, n, e))
		facts.append_array(PsychRoleD.companion_facts(w, n, e))
	var held = n.info_log.size() - readings.size()
	if held > 0:
		var afraid: bool = _dialogue()._afraid(w, n)
		# One card per person and gift (the same refusal again adds nothing new).
		var refusal = {"kind": "refusal", "subject": [n.id], "source": n.id, "private": true, "withheld": true, "role": role, "fear": afraid,
			"text": "%s claims the %s but won't share what it has shown them." % [n.name, C.role_name(role)]}
		var ask: Dictionary = {}
		if withholding:
			lines.append(say_voiced(n, "withhold_readings_trust", "I've told you what I knew before. The rest I'll keep, for now."))
			w.dlog.think(n.id, "withhold", "Trust fell; withholding %d newer reading(s) from the player." % held)
		elif afraid:
			ask = _dialogue()._protection_request(w, n, refusal)
			if ask.is_empty():
				var fear_fb: String = "If word gets round what %s, I'll be dead by morning. Not yet." % ("the rest of my readings show" if not readings.is_empty() else "my gift has shown me")
				var fear_key: String = "withhold_readings_fear_rest" if not readings.is_empty() else "withhold_readings_fear_all"
				lines.append(say_voiced(n, fear_key, fear_fb))
		else:
			ask = _dialogue()._confidence_request(w, n, 4, refusal)
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
	var count = 1 + int(round((g + n.pressure * Tuning.Dialogue.GOSSIP_SHARE_PRESSURE_SCALE) * Tuning.Dialogue.GOSSIP_SHARE_MULT))
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

## Already confessed that night's errand before the town (the stored account is public).
static func confessed_before_town(n, nd: int) -> bool:
	var prior: Dictionary = n.dialogue_memory.get("night_accounts", {}).get(str(nd), {})
	return prior.get("kind", "") == "secret" and prior.get("owner", "") == n.id and bool(prior.get("public", false))


static func answer_night(w, n, night: int = -1) -> Dictionary:
	_dialogue().on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var nd: int = w.day - 1 if night < 0 else night
	var where: String = n.history.get(w.time_key(nd, C.NIGHT), "home:" + n.home_block)
	var was_out = where.begins_with("night:")
	var block = where.substr(where.find(":") + 1)
	# Where they say they were: what their sightings must be told from. "" = not saying.
	var vantage = ""
	var refused_whereabouts = false
	var how = "window"
	# The gift whose night's work they just told of ("" = none): its result follows.
	var duty_role: String = ""
	# A claimed night-walking gift keeps its story: an evil bluff always tells the duty,
	# a real holder tells it whenever they were actually out (Case 22485: a claimed
	# Lamplighter must never say "home all night").
	if C.has_role_def(n.claimed_role) and C.role_def(n.claimed_role).uses_night_duty_alibi(w, n, nd, was_out):
		var duty_res: Dictionary = C.role_def(n.claimed_role).night_duty_alibi(w, n, nd, was_out, block, _mind(), C.block_name)
		lines.append(duty_res["line"])
		facts.append(duty_res["fact"])
		vantage = duty_res["vantage"]
		how = duty_res["how"]
		duty_role = n.claimed_role
	elif not was_out:
		lines.append(home_alibi(w, n, nd))
		facts.append(_alibi_home(n, nd))
		vantage = n.home_block
	elif _honest_outing(w, n, nd) == "reveal":
		# A good gift that took them out, and they choose to tell of it (the Sexton's toll).
		var own_def = C.role_def(n.role)
		var first_claim: bool = n.claimed_role != n.role
		n.claimed_role = n.role
		n.max_tier = maxi(n.max_tier, 3)
		if first_claim:
			facts.append({"kind": "claim", "subject": [n.id], "role": n.role, "source": n.id, "private": true,
				"text": "%s told you privately they are the %s." % [n.name, C.role_name(n.role)]})
		var duty_out: Dictionary = own_def.night_duty_alibi(w, n, nd, was_out, block, _mind(), C.block_name)
		lines.append(duty_out["line"])
		facts.insert(0, duty_out["fact"])
		vantage = duty_out["vantage"]
		how = duty_out["how"]
		duty_role = n.role
	elif _honest_outing(w, n, nd) == "withhold" and load("res://sim/mind_podium.gd").admitted_before(n, nd):
		# Not ready to tell why, but they already owned being out that night (at the podium,
		# or to you before): the same plain account, not a refusal that would also overwrite
		# the owned account in night_accounts (Steward, Nov 11 report A1).
		load("res://sim/mind_podium.gd")._plain_account(w, n, nd, block, lines, facts)
		vantage = block
		how = "street"
	elif _honest_outing(w, n, nd) == "withhold":
		# Honest but not ready to tell (the bell still holds): a refusal, never a lie.
		w.dlog.think(n.id, "stonewall", "Keeps the night's errand (%s gift) to themself for now." % C.role_name(n.role))
		refused_whereabouts = true
		lines.append(whereabouts_refusal(n, nd))
		facts.append({"kind": "refusal", "subject": [n.id], "source": n.id, "day": nd, "phase": C.NIGHT,
			"text": "%s refused to say where they were on night %d." % [n.name, nd]})
	else:
		# Out with something to hide: evil work, a personal secret, or a hidden Night Watch gift.
		var hiding = "evil work" if n.is_evil() else ("hidden %s gift" % C.role_name(n.role) if C.ROLES[n.role].get("night_walk", false) and n.secret.is_empty() else "secret: %s" % n.secret.get("kind", "?"))
		var can_confess = not n.is_evil() and not n.secret.is_empty()
		var confess = false
		if can_confess and load("res://sim/mind_podium.gd").confessed_before(n, nd):
			confess = true  # already confessed that night: the same account, not a refusal
		elif can_confess:
			confess = decide(w, n, "confess", {"trust": (n.trust - Tuning.Dialogue.CONFESS_TRUST_PIVOT) * Tuning.Dialogue.CONFESS_TRUST_SLOPE, "privacy": (Tuning.Dialogue.CONFESS_PRIVACY_PIVOT - trait_of(n, "privacy")) * Tuning.Dialogue.CONFESS_PRIVACY_SLOPE,
				"pressure": n.pressure * Tuning.Dialogue.CONFESS_PRESSURE_SLOPE * (1.0 - Tuning.Dialogue.CONFESS_COMPOSURE_DAMP * trait_of(n, "composure")), "insight_none": 0.0},
				"Confess personal secret (%s)?" % n.secret.get("kind", "?"))
		if confess:
			n.secret_known = true
			if confessed_before_town(n, nd):
				# Told before the town already: no plea to keep it quiet, the podium's words again.
				lines.append(say_voiced(n, "confess_secret_public", "I wasn't out for anything wicked. I %s." % n.secret.get("me", n.secret["text"]), {"secret": n.secret.get("me", n.secret["text"])}))
			else:
				lines.append(say_voiced(n, "confess_secret_private", "...I wasn't home. I %s. Please, keep it quiet." % n.secret.get("me", n.secret["text"]), {"secret": n.secret.get("me", n.secret["text"])}))
			vantage = block
			how = "street"
			facts.append({"kind": "secret", "subject": [n.id], "owner": n.id, "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
				"secret_kind": n.secret.get("kind", ""), "text": "%s confessed they were out on %s on night %d: %s %s." % [n.name, C.block_name(block), nd, n.name, n.secret["text"]]})
		else:
			var prior_account: Dictionary = n.dialogue_memory.get("night_accounts", {}).get(str(nd), {})
			var prior_kind: String = prior_account.get("kind", "")
			var Podium = load("res://sim/mind_podium.gd")
			var owned: bool = Podium.admitted_before(n, nd)
			var lie_parts: Dictionary = {"confidence": (trait_of(n, "confidence") - 0.5) * Tuning.Dialogue.LIE_BOLD_CONF_SLOPE,
				"privacy_stonewalls": -(trait_of(n, "privacy") - 0.5) * Tuning.Dialogue.LIE_BOLD_PRIVACY_SLOPE}
			if hiding.begins_with("hidden "):
				lie_parts["gift_declines"] = Tuning.Dialogue.HIDDEN_GIFT_DECLINE_BIAS
			var bold: bool = false if owned else (prior_kind == "alibi") if prior_kind in ["alibi", "refusal"] else decide(w, n, "lie_or_stonewall", lie_parts, "Hiding (%s): lie outright rather than stonewall?" % hiding)
			if owned:
				# They already owned being out that night: the same plain account, not a lie.
				Podium._plain_account(w, n, nd, block, lines, facts)
				vantage = block
				how = "street"
			elif bold:
				w.dlog.think(n.id, "lie", "Said they were home, though they were out on %s, to hide %s." % [C.block_name(block), _dialogue()._hidden_thing(w, n)], {"lie": true})
				if not (nd in n.lied_nights):
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
	var told_town: bool = confessed_before_town(n, nd)
	accounts[str(nd)] = facts[0].duplicate(true)
	if told_town and accounts[str(nd)].get("kind", "") == "secret":
		accounts[str(nd)]["public"] = true  # a private retelling doesn't unsay the public confession (Codex on #399)
	n.dialogue_memory["night_accounts"] = accounts
	if duty_role != "":
		if _night_gift_result(w, n, nd, duty_role, lines, facts):
			# The watch result was just told in words and on the board: the night's
			# sightings are that result, so they aren't rolled for or told again.
			return {"lines": lines, "facts": facts}
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
			w.dlog.think(n.id, "lie", "Left out seeing %s, a fellow evil, at night." % w.by_id[b["who"]].name)
			continue
		if vantage != "" and b["block"] != vantage:
			# Seen from somewhere they say they weren't: telling it would give the lie away.
			# Most keep quiet; a rattled few let it slip.
			var slip = Tuning.Dialogue.SLIP_COMPOSURE_SCALE * (1.0 - trait_of(n, "composure")) + Tuning.Dialogue.SLIP_PRESSURE_SCALE * n.pressure
			if not w.decision_roll(n, "whereabouts_slip", slip, {"composure": trait_of(n, "composure"), "pressure": n.pressure}, b["who"]):
				w.dlog.think(n.id, "omit", "Leaves out seeing %s on %s: they say they were on %s." % [b["who"], b["block"], vantage])
				continue
			w.dlog.think(n.id, "slip", "Lets slip seeing %s on %s, though they say they were on %s (p=%.2f)." % [b["who"], b["block"], vantage, slip])
		reported.append(b)
	var ov_sight: Dictionary = C.role_def(n.claimed_role).override_night_sightings(w, n, nd, reported) if C.has_role_def(n.claimed_role) else {}
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
				var slip = Tuning.Dialogue.SLIP_COMPOSURE_SCALE * (1.0 - trait_of(n, "composure")) + Tuning.Dialogue.SLIP_PRESSURE_SCALE * n.pressure
				if not w.decision_roll(n, "refused_whereabouts_slip", slip, {"composure": trait_of(n, "composure"), "pressure": n.pressure}, observation.who):
					w.dlog.think(n.id, "omit", "Withholds seeing %s on %s after refusing whereabouts." % [observation.who, observation.block])
					continue
				slips.append(observation)
				w.dlog.think(n.id, "slip", "Lets slip seeing %s on %s after refusing whereabouts (p=%.2f)." % [observation.who, observation.block, slip])
			safe.append(observation)
		reported = safe
	if not reported.is_empty():
		var shares = w.decision_roll(n, "direct_night_sightings", Tuning.Dialogue.DIRECT_NIGHT_SIGHTING_SHARE_PROB, {"eligible_sightings": reported.size()})
		w.dlog.decision(n.id, "direct_night_sightings", "outcome", shares, {"p": Tuning.Dialogue.DIRECT_NIGHT_SIGHTING_SHARE_PROB, "eligible": reported.size()})
		if not shares:
			lines.append(say_voiced(n, "night_sightings_refuse", "I'm not ready to discuss who I saw."))
			return {"lines": lines, "facts": facts}
	# Some alibi wordings already say they saw nobody ("didn't see a soul"): don't repeat it.
	var said_nobody: bool = lines.any(func(l): return l is Dictionary and SAW_NOBODY_MARKERS.any(func(m): return m in str(l.get("text", "")).to_lower()))
	if reported.is_empty() and not (was_out and not n.is_evil()) and not said_nobody:
		lines.append(say_voiced(n, "night_saw_nobody", "I saw nobody."))
	var groups: Array = []
	for b in reported:
		var r = sighting_report(w, n, b, nd)
		if b in slips:
			var who: String = w.by_id[b.who].name
			var detail = "go in for the night" if b.kind == "stayed_in" else ("leave their house" if b.get("detail", "") == "leaving_home" else "out")
			var end = ", and they never came out" if b.kind == "stayed_in" else ""
			r.line.text = "…though I did see %s %s on %s %s%s, not that I was there." % [who, detail, C.block_name(b.block), C.spoken_when(nd, w.day), end]
			r.observation.before = "…though I did see "
			r.observation.after = " %s on %s %s%s, not that I was there." % [detail, C.block_name(b.block), C.spoken_when(nd, w.day), end]
			r.observation.scene["slip"] = true
		_dialogue()._add_observation(groups, r.observation)
		facts.append(r["fact"])
		n.told_to["player|saw:%s:%d" % [b.who, nd]] = true
		n.told_to["player|" + fact_id(r.fact)] = true
	lines.append_array(_dialogue()._observation_lines(n, groups, "player", "answer", not lines.is_empty()))
	return {"lines": lines, "facts": facts}

## After telling of a night's gift work, what the gift showed that night (playtest 26532:
## a Confessor said where they went but not what they learned, so "nothing" and "won't
## say" sounded the same). A result the player has already heard is said again. One they
## haven't is told now only if they already share their readings (tier 4) and would still
## tell them to "ask gift" today (disclosure_gate: no new readings once trust has fallen);
## then every reading not yet told goes with it. Asking about a night never opens readings
## someone isn't ready to share (Michael, Nov 17). Otherwise it's held back in so many words. A
## night the gift showed nothing is said plainly. The Night Watch's result is the night's
## sightings: when the gate opens, that reading is told in words and on the board, and
## true is returned so the caller doesn't tell (or refuse) the same sightings again (Codex,
## #178: left to the sightings path, a quiet watch said nothing, and a refusal roll could
## withhold a result whose card was already given).
static func _night_gift_result(w, n, nd: int, role: String, lines: Array, facts: Array) -> bool:
	if not C.has_readings(role) or not C.has_role_def(role):
		return false
	var in_sightings: bool = C.role_def(role).night_result_in_sightings()
	var tonight: Array = n.info_log.filter(func(e): return e.get("role", "") == role and int(e.get("day", -1)) == nd \
		and not e.has("phase") and not e.get("disowned", false))
	if tonight.is_empty():
		if in_sightings:
			return false
		if n.is_evil():
			# No story made up for that night: hold it back rather than say "nothing",
			# which a real holder of most gifts never could.
			w.dlog.think(n.id, "stonewall", "Bluffing %s: no reading prepared for night %d; keeps it back." % [role, nd])
			lines.append(say_voiced(n, "night_gift_result_withheld", "What my gift showed me that night, I'll keep to myself for now."))
		else:
			lines.append(say_voiced(n, "night_gift_result_none", "My gift showed me nothing that night."))
		return false
	var told: Array = tonight.filter(func(e): return reading_disclosed(n, e))
	if told.size() == tonight.size():
		if in_sightings:
			return false
		if n.is_evil():
			w.dlog.think(n.id, "lie", "Repeated its made-up %s reading for %s." % [C.role_name(role), C.spoken_night(nd, -1)])
		var reports: Array = info_lines(w, n, told, "player", true)
		if not reports.is_empty():
			lines.append(say(n, " ".join(PackedStringArray(reports.map(func(line): return line.text)))))
		return false
	var gate: Dictionary = _dialogue().disclosure_gate(w, n)
	# The question about one night never opens their readings: someone who hasn't yet told
	# their readings (below tier 4) keeps them back, whatever today's mood would allow "ask
	# gift" (Michael, Nov 17; test_social's false Night Watch).
	var capped: bool = n.max_tier < 4
	if capped or not gate["readings_open"]:
		w.dlog.think(n.id, "withhold", "Tells of the night's %s work but keeps its result back (%s)." % [role,
			"not yet sharing readings" if capped else ("disclosure tier %d%s" % [gate["tier"], ", trust fell" if gate["withholding"] else ""])])
		if not in_sightings:
			lines.append(say_voiced(n, "night_gift_result_withheld", "What my gift showed me that night, I'll keep to myself for now."))
		return false
	# Open: tell every reading not yet told, as the gift question would at this tier.
	var fresh: Array = []
	for e in n.info_log:
		if not e.get("disowned", false) and not reading_disclosed(n, e):
			fresh.append(e)
	n.told_readings = n.info_log.size()
	var memo: Dictionary = n.dialogue_memory.get("told_player_readings", {})
	for e in fresh:
		memo[str(n.info_log.find(e))] = true
	n.dialogue_memory["told_player_readings"] = memo
	if n.is_evil():
		w.dlog.think(n.id, "lie", "Recited its made-up %s readings when asked about %s." % [C.role_name(role), C.spoken_night(nd, -1)])
	else:
		w.dlog.think(n.id, "disclose", "Asked about night %d: tells the %s result%s." % [nd, role, "" if fresh.size() == 1 else "s"])
	if not fresh.is_empty():
		var reports: Array = info_lines(w, n, fresh, "player", true)
		if not reports.is_empty():
			lines.append(say(n, " ".join(PackedStringArray(reports.map(func(line): return line.text)))))
	var PsychRoleN = preload("res://sim/roles/psychologist.gd")
	for e in fresh:
		facts.append(info_fact(w, n, e))
		facts.append_array(PsychRoleN.companion_facts(w, n, e))
	return in_sightings and fresh.any(func(e): return e in tonight)

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
		return {"line": say(n, "From my window %s, I saw %s go in for the night, and they never came out." % [C.spoken_when(nd, w.day), who.name]),
			"observation": {"kind": "alibi", "subject": who.name, "scene": _dialogue()._observation_scene(n, b, nd),
				"before": "From my window %s, I saw " % C.spoken_when(nd, w.day), "after": " go in for the night, and they never came out."},
			"fact": {"kind": "alibi", "subject": [who.id], "home": true, "witness": true, "day": nd, "phase": C.NIGHT, "source": n.id, "block": b["block"],
				"text": "%s says they saw %s go home for the night on night %d and not come out (from their window, %s)." % [n.name, who.name, nd, bn]}}
	var before = ""
	var after = ""
	var how = ""
	if b.get("how", "street") == "window":
		how = " (from their window)"
		if b.get("detail", "") == "leaving_home":
			before = "From my window, I saw "
			after = " leave their house %s." % C.spoken_when(nd, w.day)
		else:
			before = "From my window, I saw "
			after = " out in the street %s." % C.spoken_when(nd, w.day)
	else:
		before = "I did see "
		after = " out on %s %s." % [bn, C.spoken_when(nd, w.day)]
	return {"line": say(n, before + who.name + after),
		"observation": {"kind": "sighting", "subject": who.name, "scene": _dialogue()._observation_scene(n, b, nd), "before": before, "after": after},
		"fact": {"kind": "sighting", "subject": [who.id], "block": b["block"], "day": nd, "phase": C.NIGHT, "source": n.id, "how": b.get("how", "street"),
			"text": "%s says they saw %s on %s on night %d%s." % [n.name, who.name, bn, nd, how]}}

## Only observations from this phase are redundant when the named person is
## visibly beside the player now. Older memories and other spots on the block matter.
static func sighting_is_here(w, b: Dictionary, who: String, near_loc: String = "") -> bool:
	var here: String = near_loc if near_loc != "" else w.player_loc
	return here != "" and b.get("day", -1) == w.day and b.get("phase", -1) == w.phase \
		and w.by_id.has(who) and w.by_id[who].loc == here

## Who they've seen around by day. when: "" (earlier today, before this phase), "morning",
## "afternoon", "evening" (today) or "yesterday". near_loc: the exact place where the player is right now;
## people seen there this phase are left out (you can see them yourself), and memory reaches
## further back instead.
## "Where were you, and who did you see?" for a daytime frame: "" (earlier today, not
## this phase), "morning" / "afternoon" / "evening" (today), "yesterday", or "yesterday
## morning" / "yesterday afternoon" / "yesterday evening". They say where they were
## (daytime whereabouts are open to anyone's eyes), then who they saw: as many as their
## memory (Insight) holds and their Gossip lets them share.
static func answer_today(w, n, when: String = "", near_loc: String = "", seen_pairs: Dictionary = {}) -> Dictionary:
	_dialogue().on_question(w, n)
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
		# Earlier today (the current phase is in front of the player), or all of yesterday.
		for p in range(3):
			if yday or p < w.phase:
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
	# Someone who sought you out to tell you their gift is open with you for that conversation
	# (Nov 7): they share every sighting they remember, not just what their Gossip allows.
	var opened_up: bool = n.dialogue_memory.get("conversation", {}).get("opened_up", false)
	if opened_up:
		limit = maxi(limit, Tuning.Dialogue.DAY_MEMORY_BASE + int(round(trait_of(n, "insight") * Tuning.Dialogue.DAY_MEMORY_INSIGHT_SCALE)))
	if limit == 0:
		var refuse_prefix: String = (was_s + ". ") if was_s != "" else ""
		var refuse_tail: String = Dialogue.voice_line(n.id, "day_sightings_refuse", "Who else goes where is none of my business.")
		var refuse_line: Dictionary = say(n, refuse_prefix + refuse_tail)
		refuse_line["statement"] = refuse_prefix + "Who else goes where is none of my business."
		lines.append(refuse_line)
		return {"lines": lines, "facts": facts}
	# Memory: they recall only their most recent few sightings (more with Insight), one per person.
	var memory = Tuning.Dialogue.DAY_MEMORY_BASE + int(round(trait_of(n, "insight") * Tuning.Dialogue.DAY_MEMORY_INSIGHT_SCALE))
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
			var seen_fact: Dictionary = {"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": b["phase"], "source": n.id,
				"text": "%s saw %s on %s, day %d %s." % [n.name, who.name, C.block_name(b["block"]), b["day"], C.PHASES[b["phase"]]]}
			if seen_pairs.has("saw:%s|%d|%d|%s" % [who.id, b["day"], b["phase"], b["block"]]):
				# You saw them there yourself: left out, but it backs your card.
				seen_fact["silent"] = true
				facts.append(seen_fact)
				continue
			var place_id: String = "loc:" + b["loc"] if b["loc"] != "" else "block:" + b["block"]
			parts.append(Observations.presence(n.id, who.id, who.name, place_id, b["day"], b["phase"], where, when_s))
			facts.append(seen_fact)
			continue
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
	# Honest forgetting (Michael, Nov 19): when memory, not discretion, dropped people they
	# saw, they say so without naming anyone. Never when Gossip held anyone back, so it
	# can't stand in for discretion; an evil speaker's teammates never count (skipped above).
	if recalled.size() <= limit:
		var forgotten: int = 0
		var counted = {}
		for b in seen:
			var who_id: String = b["who"]
			if people.has(who_id) or counted.has(who_id) or (n.is_evil() and Evil.is_teammate(w, n, who_id)):
				continue
			counted[who_id] = true
			forgotten += 1
		if forgotten > 0:
			w.dlog.think(n.id, "forgot", "Can't place %d more seen in that time (memory %d)." % [forgotten, memory])
			spoken += " " + Dialogue.voice_line(n.id, "day_forgot_others", "There were others, but I can't place them.")
	lines.append(say(n, ((was_s + ". ") if was_s != "" else "") + spoken))
	return {"lines": lines, "facts": facts}
