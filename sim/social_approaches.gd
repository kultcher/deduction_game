## NPCs approaching the player, and the player asking about a role (split from
## `sim/social.gd`; part of Social's inheritance chain).
extends "res://sim/social_base.gd"


# ---------------------------------------------------------------- approaches

## Pick an NPC who wants a word with the player at the start of a phase, or null.
## `skip_id`: whoever you talked with last phase doesn't come straight back to you (playtest
## triage 1.8). Their noise draw still happens so the RNG stream doesn't shift.
static func approach_candidate(w, skip_id: String = ""):
	if not w.decision_roll(null, "approach_this_phase", Tuning.Social.APPROACH_PHASE_CHANCE):
		return null
	var best = null
	var best_s = 0.0
	var agenda = ""
	for n in w.living():
		if not n.available() or n.working or n.silenced:
			continue
		var s = 0.0
		var a = ""
		var gos = trait_of(n, "gossip")
		if n.is_evil():
			# Same conditions as a good NPC with news: unshared (fake) readings and some trust.
			var sg: String = w.evil_plan.get("scapegoat", "")
			var fresh = 0
			for i in range(n.told_readings, n.info_log.size()):
				if not n.info_log[i]["shared"] and not n.told_to.has("player|approached:%d" % i):
					fresh += 1
			if fresh > 0 and n.trust >= Tuning.Social.APPROACH_NEWS_MIN_TRUST and sg != "" and w.by_id[sg].alive:
				s = (1.0 - trait_of(n, "privacy")) + n.trust - Tuning.Social.APPROACH_NEWS_OFFSET
				a = "frame"
		else:
			var unshared = n.info_log.size() - n.told_readings
			var hidden_new = 0
			for i in range(n.told_readings, n.info_log.size()):
				if not n.info_log[i]["shared"] and not n.told_to.has("player|approached:%d" % i):
					hidden_new += 1
			if hidden_new > 0 and n.trust >= Tuning.Social.APPROACH_NEWS_MIN_TRUST and unshared > 0:
				s = (1.0 - trait_of(n, "privacy")) + n.trust - Tuning.Social.APPROACH_NEWS_OFFSET
				a = "news"
		if gos >= Tuning.Social.APPROACH_GOSSIP_MIN and has_gossip(w, n):
			var gs = gos - Tuning.Social.APPROACH_GOSSIP_OFFSET
			if gs > s:
				s = gs
				a = "gossip"
		if wants_protection(w, n):
			var ps = n.trust + Tuning.Social.APPROACH_PROTECT_COMPOSURE_SCALE * (1.0 - trait_of(n, "composure")) - Tuning.Social.APPROACH_PROTECT_OFFSET
			if ps > s:
				s = ps
				a = "protect"
		var noise_draw = w.rng.randf()
		var noise: float = noise_draw * Tuning.Social.APPROACH_NOISE
		s += noise
		if n.id == skip_id:
			s = 0.0
			a = "just talked"
		w.observe_decision(n, "approach_score", s >= Tuning.Social.APPROACH_SCORE_THRESHOLD, {"inputs": {"gossip": gos, "privacy": trait_of(n, "privacy"), "trust": n.trust, "composure": trait_of(n, "composure")}, "score": s, "threshold": Tuning.Social.APPROACH_SCORE_THRESHOLD, "comparison": ">=", "draw": noise_draw, "noise": noise, "noise_min": 0.0, "noise_max": Tuning.Social.APPROACH_NOISE, "agenda": a, "note": "Threshold chance excludes competing NPCs; highest score chooses the approach"})
		if s > best_s:
			best_s = s
			best = n
			agenda = a
	if best == null or best_s < Tuning.Social.APPROACH_SCORE_THRESHOLD:
		w.observe_decision(best, "approach_selection", false, {"gate": "no eligible NPC cleared the approach threshold", "score": best_s, "threshold": Tuning.Social.APPROACH_SCORE_THRESHOLD, "comparison": ">="})
		return null
	w.observe_decision(best, "approach_selection", agenda, {"score": best_s, "threshold": Tuning.Social.APPROACH_SCORE_THRESHOLD, "comparison": ">=", "gate": "highest eligible score selected; no extra draw"})
	w.dlog.think(best.id, "approach", "Seeks out the Demonologist (agenda: %s, score %.2f)." % [agenda, best_s], {"agenda": agenda})
	return {"npc": best, "agenda": agenda}

## Afraid, trusting the player enough, and the player doesn't yet know their gift: they may
## come asking for a ward or a vigil (see Mind.protection_kind for who asks for which).
static func wants_protection(w, n) -> bool:
	if n.claim_public or n.max_tier >= 3 or n.protect_lock or n.request_day == w.day or n.trust < Tuning.Social.PROTECTION_MIN_TRUST:
		return false
	if Mind.protection_kind(w, n) == "":
		return false
	return Mind._afraid(w, n)

## A free line as they approach, naming what they want to talk about.
static func approach_teaser(w, n, agenda: String) -> Dictionary:
	match agenda:
		"news", "frame":
			return Mind.say_voiced(n, "approach_teaser_gift", "It's about my gift. I've learned something you should hear.")
		"gossip":
			return Mind.say_voiced(n, "approach_teaser_gossip", "I've heard something about one of our neighbours.")
		"protect":
			return Mind.protection_line(n, Mind.protection_kind(w, n))
	return Mind.say_voiced(n, "approach_word", "Demonologist, a word?")

## What they open with once the player accepts. Returns {lines, facts}.
static func approach_open(w, n, agenda: String) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	match agenda:
		"news", "frame":
			# Never twice for the same reading (Michael, Nov 19): every reading this approach was
			# about is marked, so a reading held back from the answer (the disclosure gate kept it,
			# and told_readings didn't move) can't bring them back with the same news.
			for i in range(n.told_readings, n.info_log.size()):
				n.told_to["player|approached:%d" % i] = true
			var r: Dictionary = Mind.answer_gift(w, n, 4)
			n.pressed_today -= 1
			lines.append(Mind.say_voiced(n, "approach_open_gift", "I've been meaning to find you."))
			lines += r["lines"]
			facts += r["facts"]
			if agenda == "frame":
				var sg = w.by_id[w.evil_plan["scapegoat"]]
				var why = Evil.cite(w, n, Evil.bluff_reason(w, n, sg))
				w.dlog.think(n.id, "lie", "Sought you out to push %s, evil's scapegoat." % sg.name)
				var reason_s: String = ((why[0].to_upper() + why.substr(1)).trim_suffix(".") + ".") if why != "" else "Something's off about them."
				var canonical_warn: String = "And keep an eye on %s. %s" % [sg.name, reason_s]
				lines.append(Mind.say_voiced(n, "approach_frame_warn", canonical_warn, {"subject": sg.name, "reason": reason_s}))
				facts.append({"kind": "opinion", "subject": [sg.id], "source": n.id, "text": "%s warned you about %s." % [n.name, sg.name]})
		"gossip":
			lines.append(Mind.say_voiced(n, "approach_open_gossip", "You'll want to hear this."))
			var g = gossip_item(w, n)
			lines += g["lines"]
			facts += g["facts"]
	return {"lines": lines, "facts": facts}

## Gossip the player hasn't heard from them, and that the whole town didn't already hear:
## a known secret, or a relayed reading or sighting. Returns [kind, owner/index] or [].
static func _gossip_items(w, n) -> Array:
	var out: Array = []
	for owner in n.known_secrets:
		# A secret that names the teller (a Lover's "slips out to meet <teller>") isn't
		# gossip: passing it on would out the teller too (playtest 97626, Agnes on Nisha).
		if owner != n.id and w.by_id[owner].alive and not n.told_to.has("player|secret:" + owner) \
				and str(w.by_id[owner].secret.get("with", "")) != n.id:
			out.append(["secret", owner])
	for i in range(n.hearsay.size() - 1, -1, -1):
		var h: Dictionary = n.hearsay[i]
		if n.told_to.has("player|hs:%d" % i) or h.get("public", false) or h.get("about", "") == n.id:
			continue
		if h["kind"] == "reading" and w.by_id.has(h["from"]) and not h["entry"].get("shared", false):
			var src = w.by_id[h["from"]]
			if Mind.reading_disclosed(src, h["entry"]):
				continue
			out.append(["hearsay", i])
		elif h["kind"] in ["role_claim", "role_hint"] and w.by_id.has(h["from"]) and w.by_id[h["from"]].alive and not w.by_id[h["from"]].claim_public:
			if n.told_to.has("player|%s:%s" % [h["kind"], h["from"]]):
				continue
			out.append(["hearsay", i])
		elif h["kind"] == "sighting" and w.by_id.has(h["about"]):
			var src = w.by_id.get(h["from"])
			var town_key = "town|sighting:%s:%s:%d:%d:%s" % [h.get("from", ""), h["about"], h.get("day", -1), C.NIGHT, h.get("block", "")]
			var player_key = "player|saw:%s:%d" % [h["about"], h.get("day", -1)]
			if (src != null and (src.told_to.has(town_key) or src.told_to.has(player_key))) or n.told_to.has(player_key):
				continue
			out.append(["hearsay", i])
	return out

static func has_gossip(w, n) -> bool:
	return not _gossip_items(w, n).is_empty()

## A busybody's best bit of news for the player: a secret, a relayed reading or sighting,
## never one they've already told you or one the whole town heard at a meeting.
static func gossip_item(w, n) -> Dictionary:
	var items: Array = _gossip_items(w, n)
	for it in items:
		if it[0] != "secret":
			continue
		var owner: String = it[1]
		var o = w.by_id[owner]
		if w.decision_roll(n, "approach_gossip_direct", Tuning.Social.APPROACH_SECRET_DIRECT_BASE + Tuning.Social.APPROACH_SECRET_DIRECT_GOSSIP_SCALE * trait_of(n, "gossip"), {"gossip": trait_of(n, "gossip")}):
			n.told_to["player|secret:" + owner] = true
			w.dlog.think(n.id, "gossip", "Tells the player %s's secret (heard via %s)." % [owner, n.known_secrets[owner]])
			o.secret_spread_by_npc = true
			var said: String = Burdens.phrase(o)
			var gossip_line: Dictionary
			if o.secret.is_empty():
				# A burden, not an errand (burdens prototype): nothing to do with being out at night.
				gossip_line = Mind.say_voiced(n, "gossip_burden", "Between you and me, %s %s." % [o.name, said], {"subject": o.name, "secret": said})
			else:
				gossip_line = Mind.say_voiced(n, "gossip_secret", "Between you and me, %s %s. That's why they're about at night." % [o.name, said], {"subject": o.name, "secret": said})
			if o.secret.is_empty():
				return {"lines": [gossip_line], "facts": [Burdens.relay_fact(w, n, o, said)]}
			return {"lines": [gossip_line],
				"facts": [Burdens.with_errand(w, o, {"kind": "secret", "subject": [owner], "owner": owner, "source": n.id, "via": n.known_secrets[owner],
					"secret_kind": o.secret.get("kind", o.secret_mod), "burden": o.secret.is_empty(), "text": "%s told you %s's secret: %s %s." % [n.name, o.name, o.name, said]})]}
	for it in items:
		if it[0] != "hearsay":
			continue
		var i: int = it[1]
		var h: Dictionary = n.hearsay[i]
		var src = w.by_id.get(h["from"])
		n.told_to["player|hs:%d" % i] = true
		if h["kind"] == "reading" and src != null:
			var e: Dictionary = h["entry"]
			var f = Mind.info_fact(w, src, e)
			f["via"] = n.id
			f["text"] = "Via %s: " % n.name + f["text"]
			var out_facts_r: Array = [f] + PsychologistRole.companion_facts(w, src, e, n.id)
			var role_s: String = C.role_name(e["role"])
			var report_s: String = C.third_person(e["text"])
			var reading_fallback: String = "%s told me their gift is %s, and that %s." % [src.name, role_s, report_s]
			return {"lines": [Mind.say_voiced(n, "gossip_reading", reading_fallback, {"source": src.name, "role": role_s, "report": report_s})], "facts": out_facts_r}
		if h["kind"] == "role_claim" and src != null:
			n.told_to["player|role_claim:" + src.id] = true
			var crn: String = C.role_name(h["role"])
			var claim_fb: String = "Between us, %s told me they're the %s." % [src.name, crn]
			return {"lines": [Mind.say_voiced(n, "role_query_private_direct", claim_fb, {"who": src.name, "role": crn})],
				"facts": [{"kind": "claim", "subject": [src.id], "role": h["role"], "source": src.id, "via": n.id, "private": true,
					"text": "Via %s: %s privately claims to be the %s." % [n.name, src.name, crn]}]}
		if h["kind"] == "role_hint" and src != null:
			n.told_to["player|role_hint:" + src.id] = true
			var hp: String = h["package"]
			var hint_fb: String = "Between us, %s hinted their gift is %s." % [src.name, C.HINT_PACKAGES[hp]["name"]]
			return {"lines": [Mind.say(n, hint_fb)],
				"facts": [{"kind": "hint", "subject": [src.id], "source": src.id, "via": n.id, "private": true, "package": hp,
					"roles": C.HINT_PACKAGES[hp]["roles"].duplicate(),
					"text": "Via %s: %s hinted at %s (%s)." % [n.name, src.name, C.HINT_PACKAGES[hp]["name"],
						C.package_roles_text(hp, w.case_script)]}]}
		if h["kind"] == "sighting":
			var mh_s: Dictionary = h  # (the item as heard; the Muddler hook is gone)
			var who = w.by_id[mh_s["about"]]
			var by = w.by_id[mh_s["from"]].name if w.by_id.has(mh_s["from"]) else "someone"
			var block_s: String = C.block_name(mh_s["block"])
			var night_s: String = C.spoken_when(int(mh_s["day"]), w.day)  # spoken: "last night", "on the second night"
			var sighting_fallback: String = "%s says %s was out on %s %s." % [by, who.name, block_s, night_s]
			var s_fact_out: Dictionary = {"kind": "sighting", "subject": [who.id], "block": mh_s["block"], "day": mh_s["day"], "phase": C.NIGHT, "source": mh_s["from"], "via": n.id,
				"text": "Via %s: %s saw %s on %s on night %d." % [n.name, by, who.name, block_s, mh_s["day"]]}
			return {"lines": [Mind.say_voiced(n, "gossip_sighting", sighting_fallback, {"source": by, "subject": who.name, "block": block_s, "night": night_s})],
				"facts": [s_fact_out]}
	return {"lines": [Mind.say_voiced(n, "gossip_empty", "...Well, I thought I had something. The price of bread, mostly.")], "facts": []}

# ---------------------------------------------------------------- asking about a role

static func answer_about_role(w, n, role: String) -> Dictionary:
	Mind.on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var rn = C.role_name(role)
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	if mine == role and (n.claim_public or n.max_tier >= 3):
		lines.append(Mind.say_voiced(n, "role_query_self", "That would be me."))
		return {"lines": lines, "facts": facts}
	# A general question about the town, but it touches their own gift: a small chance they
	# own up (likelier the more they trust you). Otherwise they answer like anyone else.
	if mine == role:
		var p = Tuning.Social.ROLE_OWN_UP_BASE + Tuning.Social.ROLE_OWN_UP_TRUST_SCALE * n.trust
		var out = w.decision_roll(n, "own_up_to_gift", p, {"trust": n.trust})
		w.dlog.think(n.id, "about_role", "Asked who holds their own gift (%s): owns up? -> %s (p=%.2f)." % [role, "yes" if out else "no", p])
		if out:
			n.pressed_today -= 1  # answer_gift counts the question again
			return Mind.answer_gift(w, n, maxi(2, Mind._target_tier(w, n)))
	var public: Array = w.public_claims.filter(func(c): return c["role"] == role and w.by_id[c["who"]].alive).map(func(c): return w.by_id[c["who"]].name)
	var text = ""
	var voiced_chunks: Array = []
	if not public.is_empty():
		var pub_names: String = " and ".join(PackedStringArray(public))
		var pub_fb: String = "Everyone heard %s claim the %s." % [pub_names, rn]
		text = pub_fb
		voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_public", pub_fb, {"names": pub_names, "role": rn}))
	var willing = trait_of(n, "gossip") * Tuning.Social.ROLE_WILLING_GOSSIP_SCALE + n.trust * Tuning.Social.ROLE_WILLING_TRUST_SCALE + n.pressure * Tuning.Social.ROLE_WILLING_PRESSURE_SCALE > Tuning.Social.ROLE_WILLING_THRESHOLD
	var told = false
	if not n.is_evil() and willing:
		for sid in n.known_claims:
			var kc: Dictionary = n.known_claims[sid]
			var who = w.by_id[sid]
			if kc["role"] != role or who.claim_public:
				continue
			told = true
			if kc["via"] == sid:
				var priv_fb: String = "Between us, %s told me they're the %s." % [who.name, rn]
				text += (" " if text != "" else "") + priv_fb
				voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_private_direct", priv_fb, {"who": who.name, "role": rn}))
			else:
				var via_name: String = w.by_id[kc["via"]].name
				var priv_fb: String = "Between us, %s told %s they're the %s." % [who.name, via_name, rn]
				text += (" " if text != "" else "") + priv_fb
				voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_private_via", priv_fb, {"who": who.name, "via": via_name, "role": rn}))
			facts.append({"kind": "claim", "subject": [sid], "role": role, "source": sid, "via": n.id, "private": true,
				"text": "Via %s: %s privately claims to be the %s." % [n.name, who.name, rn]})
			for raw_e in kc["readings"]:
				var e: Dictionary = raw_e
				var said_rd: String = C.third_person(e["text"])
				var rd_fb: String = "They said %s." % said_rd
				text += " " + rd_fb
				voiced_chunks.append(Dialogue.voice_line(n.id, "role_query_reading", rd_fb, {"reading": said_rd}))
				var f = Mind.info_fact(w, who, e)
				f["via"] = n.id
				f["text"] = "Via %s: " % n.name + f["text"]
				facts.append(f)
				facts.append_array(PsychologistRole.companion_facts(w, who, e, n.id))
		w.dlog.think(n.id, "about_role", "Asked about the %s: shares private knowledge (willing)." % role if told else "Asked about the %s: knows nothing private." % role)
	elif not willing:
		w.dlog.think(n.id, "about_role", "Asked about the %s: not willing to share private knowledge." % role)
	if text == "":
		if mine == role or not (willing or n.is_evil()):
			lines.append(Mind.say_voiced(n, "role_query_refuse", "That's not for me to say."))
		else:
			lines.append(Mind.say_voiced(n, "role_query_unknown", "I couldn't tell you who the %s is." % rn, {"role": rn}))
	else:
		var line_dict: Dictionary = Mind.say(n, " ".join(PackedStringArray(voiced_chunks)))
		line_dict["statement"] = text
		lines.append(line_dict)
	return {"lines": lines, "facts": facts}

## "Are you the <gift>?": a direct guess at the listener's own gift. Right, they own up a
## little more readily than usual (only for the first guess you put to them, so going down
## the list doesn't pay). Wrong, or unwilling, they give the same non-answer either way, so
## a guess never eliminates anyone, and each wrong guess costs a little more trust.
static func answer_is_role(w, n, role: String) -> Dictionary:
	# Route before on_question: gift answers own both fatigue and disclosure.
	if (n.claim_public or n.max_tier >= 3) and n.claimed_role == role:
		return Mind.answer_gift(w, n)
	Mind.on_question(w, n)
	var rn = C.role_name(role)
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var said: bool = n.claim_public or n.max_tier >= 3
	if said:
		var claimed: String = n.claimed_role
		if C.ROLES.has(claimed):
			var c_name: String = C.role_name(claimed)
			return {"lines": [Mind.say_voiced(n, "role_already_claimed", "No. I told you: I'm the %s." % c_name, {"role": c_name})], "facts": []}
		return {"lines": [Mind.say_voiced(n, "role_already_claimed_none", "No.")], "facts": []}
	if mine == role:
		var first = n.role_guesses == 0
		var tier: int = Mind._target_tier(w, n) + (1 if first and w.decision_roll(n, "correct_role_guess_bonus", Tuning.Social.CORRECT_ROLE_GUESS_BONUS_PROB) else 0)
		w.dlog.think(n.id, "about_role", "Asked if they are the %s (right): disclosure tier %d%s." % [role, tier,
			"" if first else " (no bonus: you guessed wrong before)"])
		if tier >= 2:
			n.pressed_today -= 1  # answer_gift counts the question again
			return Mind.answer_gift(w, n, mini(tier, 4))
	else:
		n.role_guesses += 1
		var cost = Tuning.Trust.WRONG_ROLE_GUESS_STEP * n.role_guesses
		Mind.set_trust(w, n, n.trust - cost, "the Demonologist guessed my gift wrong (%s; %d wrong so far)" % [role, n.role_guesses])
		w.dlog.think(n.id, "about_role", "Asked if they are the %s (wrong): gives the usual non-answer." % role)
	var line = "Why do you keep asking me that?" if n.role_guesses >= 3 else "What my gift is, I'll keep to myself."
	var guess_key = "guess_3" if n.role_guesses >= 3 else "guess_1"
	if n.role_guesses == 2:
		line = "You're grasping at straws, and I'm running out of patience."
		guess_key = "guess_2"
	return {"lines": [Mind.say_voiced(n, guess_key, line)], "facts": [], "refusal_line": 0}
