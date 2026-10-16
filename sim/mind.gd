## NPC reasoning for good and evil townsfolk: suspicion, trust, claims and disclosure,
## testimony, nominations, votes, conversation answers. Decisions with hidden reasoning are
## written to the dev log via w.dlog.think(...).
##
## Speech lines are returned as {"speaker": id, "name": name, "text": text}; narration as
## plain strings. game.gd renders both.
##
## All functions are static and take the world as the first argument.
extends RefCounted

const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")

# ---------------------------------------------------------------- utilities

static func say(n, text: String) -> Dictionary:
	return {"speaker": n.id, "name": n.name, "text": text}

static func trait_of(n, t: String) -> float:
	return n.traits.get(t, 0.5)

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
	w.dlog.think(n.id, topic, "%s -> %s (p=%.2f)" % [why, "yes" if yes else "no", p], d)
	return yes

# ---------------------------------------------------------------- trust

static func set_trust(w, n, value: float, why: String) -> void:
	var old: float = n.trust
	n.trust = clampf(value, 0.0, n.trust_cap)
	if absf(n.trust - old) >= 0.01:
		w.dlog.add("trust", n.id, "player", {"from": snappedf(old, 0.01), "to": snappedf(n.trust, 0.01), "cap": n.trust_cap}, why)

static func cap_trust(w, n, cap: float, why: String) -> void:
	if cap < n.trust_cap:
		n.trust_cap = cap
		w.dlog.add("trust_cap", n.id, "player", {"cap": cap}, why)
		if n.trust > cap:
			set_trust(w, n, cap, why)

## End of each day: bonus for keeping a confessed secret.
static func end_of_day_trust(w) -> void:
	for n in w.living():
		if n.secret_known and not n.secret_spread:
			set_trust(w, n, n.trust + 0.03 + 0.04 * trait_of(n, "privacy"), "the Demonologist kept my secret today")

# ---------------------------------------------------------------- suspicion

static func adjust(w, listener, target_id: String, delta: float, why: String, public_why: String = "", conf_scaled: bool = true) -> void:
	if listener.is_evil() or target_id == listener.id or not listener.suspicion.has(target_id):
		return
	var t = w.by_id[target_id]
	if not t.alive and t.death_cause == "demon":
		return  # killed by the demon: treated as good
	if conf_scaled:
		delta *= 1.4 - 0.8 * trait_of(listener, "confidence")
	var old: float = listener.suspicion[target_id]
	var nv = clampf(old + delta, 0.0, 1.5)
	listener.suspicion[target_id] = nv
	if absf(delta) >= 0.05:
		w.dlog.add("suspicion", listener.id, target_id, {"from": snappedf(old, 0.01), "to": snappedf(nv, 0.01)}, why)
	if delta >= 0.15 and public_why != "":
		listener.sus_why[target_id] = public_why

static func susp(n, target_id: String) -> float:
	return n.suspicion.get(target_id, 0.0)

static func known_good(w, id: String) -> bool:
	var t = w.by_id[id]
	return not t.alive and t.death_cause == "demon"

## Apply one ability result (own or heard) to a listener's suspicion.
static func apply_info(w, listener, source, entry: Dictionary, weight: float) -> void:
	if weight <= 0.01 or listener.is_evil():
		return
	var d: Dictionary = entry["data"]
	var r: String = entry["role"]
	var own = source == listener
	var src_name: String = "my own" if own else source.name + "'s"
	var src_bare: String = "I" if own else source.name
	var tag = "own info" if own else "heard %s's info (w=%.2f)" % [source.id, weight]
	match r:
		"hearthwitch":
			var nbrs: Array = d["nbrs"]
			var count: int = d["count"]
			var others: Array = nbrs.filter(func(i): return i != listener.id and not known_good(w, i))
			var excluded = nbrs.size() - others.size()
			if count == 0:
				for i in others:
					adjust(w, listener, i, -0.25 * weight, tag + ": hearthwitch count 0", "", not own)
			else:
				var per = 0.35 * count
				if excluded > 0:
					per = 0.7 * count
				if count > others.size() and not own:
					adjust(w, listener, source.id, 0.5 * weight, tag + ": hearthwitch count impossible from my view",
						"%s reading about the lane can't be right" % src_name)
				for i in others:
					adjust(w, listener, i, per * weight, tag + ": hearthwitch count %d" % count,
						"%s reading pointed at their neighbours" % src_name, not own)
		"seer":
			var pair: Array = d["pair"]
			var others: Array = pair.filter(func(i): return i != listener.id and not known_good(w, i))
			if d["yes"]:
				var per = 0.45 if others.size() > 1 else 0.85
				for i in others:
					adjust(w, listener, i, per * weight, tag + ": seer yes",
						"%s sight said one of them is the demon" % src_name, not own)
			else:
				for i in others:
					adjust(w, listener, i, -0.3 * weight, tag + ": seer no", "", not own)
		"nightwatch":
			var seen: Array = d["seen"]
			for i in seen:
				if i == listener.id:
					var where: String = listener.history.get(w.time_key(entry["day"], C.NIGHT), "")
					if where.begins_with("home") and not own:
						adjust(w, listener, source.id, 0.45 * weight, tag + ": claims to have seen me out, but I was home",
							"%s claims to have seen me out at night, which is a lie" % src_bare)
					continue
				var bonus = 0.0
				for sid in w.scenes:
					if w.scenes[sid]["day"] == entry["day"] and w.scenes[sid]["block"] == d["block"]:
						bonus = 0.3
				adjust(w, listener, i, (0.2 + bonus) * weight, tag + ": seen out at night",
					"%s saw them out at night" % src_bare, not own)
		"archivist":
			var pair: Array = d["pair"]
			var others: Array = pair.filter(func(i): return i != listener.id and not known_good(w, i))
			var per = 0.35 if others.size() > 1 else 0.75
			for i in others:
				adjust(w, listener, i, per * weight, tag + ": archivist pair",
					"%s records tie them to the Poisoner" % src_name, not own)
		"clerk":
			var pair: Array = d["pair"]
			if listener.id in pair and d["role"] == listener.role and not own:
				adjust(w, listener, source.id, -0.3 * weight, tag + ": clerk correctly named my role")
			for i in pair:
				if i != listener.id:
					adjust(w, listener, i, -0.15 * weight, tag + ": clerk pair probably good", "", not own)
		"gravedigger":
			var ex = w.by_id[d["executed"]]
			var ex_good: bool = C.ROLES[d["role"]]["align"] == "good"
			for e in w.executions:
				if e["id"] == ex.id:
					var nom: String = e["nominator"]
					if nom != "" and nom != "player":
						adjust(w, listener, nom, (0.25 if ex_good else -0.2) * weight,
							tag + ": nominator of %s, who was %s" % [ex.id, d["role"]],
							"they pushed to hang %s, who was innocent" % ex.name)
					if not own and weight > 0.2 and (e["player_nominated"] or e["player_yes"]):
						if ex_good:
							set_trust(w, listener, listener.trust - 0.06, "the Demonologist backed hanging %s, an innocent" % ex.id)
						else:
							set_trust(w, listener, listener.trust + 0.08 + 0.06 * trait_of(listener, "insight"),
								"the Demonologist was proven right about %s" % ex.id)

static func update_from_own_info(w) -> void:
	for n in w.living_good():
		while n.applied_info < n.info_log.size():
			var e: Dictionary = n.info_log[n.applied_info]
			n.applied_info += 1
			apply_info(w, n, n, e, 1.0)

static func heard_weight(listener, speaker) -> float:
	return clampf(0.55 * (1.0 - susp(listener, speaker.id)), 0.0, 0.6)

# ---------------------------------------------------------------- night choices (good)

static func ranked_suspects(w, n) -> Array:
	var c: Array = w.living().filter(func(m): return m != n)
	c.sort_custom(func(a, b): return susp(n, a.id) > susp(n, b.id))
	return c

static func seer_picks(w, n) -> Array:
	var ranked = ranked_suspects(w, n)
	var pair: Array = []
	if w.day == 0 or ranked.size() < 3:
		pair = w.shuffled(ranked).slice(0, 2)
	else:
		pair = [ranked[0], w.pick(ranked.slice(1))]
	var ids: Array = pair.map(func(m): return m.id)
	w.dlog.think(n.id, "seer_pick", "Seer checks the top suspect plus one other.", {"pair": ids})
	return ids

static func watch_block(w, n) -> String:
	var ranked = ranked_suspects(w, n)
	var b = ""
	if w.day == 0 or ranked.is_empty():
		b = w.pick(C.BLOCKS.keys())
	else:
		b = ranked[0].home_block
	w.dlog.think(n.id, "watch_pick", "Night Watch watches the block of their top suspect's home.", {"block": b})
	return b

static func warden_target(w, n) -> String:
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
	var speakers = w.shuffled(w.living())
	for n in speakers:
		var lines: Array = []
		var facts: Array = []
		if not n.claim_public:
			var claim = _public_claim_decision(w, n)
			if claim != "":
				n.claimed_role = claim
				n.claim_public = true
				n.max_tier = maxi(n.max_tier, 3)
				w.public_claims.append({"day": w.day, "who": n.id, "role": claim})
				lines.append(_claim_line(n, claim))
				facts.append({"kind": "claim", "subject": [n.id], "role": claim, "source": n.id,
					"text": "%s publicly claims to be the %s." % [n.name, C.role_name(claim)]})
				_react_to_claim(w, n, claim)
		if n.claim_public and n.claimed_role in C.INFO_ROLES:
			for e in n.info_log:
				if e["shared"]:
					continue
				e["shared"] = true
				lines.append(info_line(w, n, e))
				facts.append(info_fact(w, n, e))
				for l in w.living():
					if l != n:
						apply_info(w, l, n, e, heard_weight(l, n))
		var acc = _public_accusation(w, n)
		if acc != null:
			lines.append(acc["line"])
			facts.append(acc["fact"])
		if not lines.is_empty():
			out.append({"who": n.id, "lines": lines, "facts": facts})
	return out

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
	if w.living().size() <= 4:
		parts["few_left"] = 0.8
	var why = ("Evil cover: publicly claim bluff %s?" % role) if n.is_evil() else ("Publicly reveal true role %s?" % role)
	if decide(w, n, "claim", parts, why):
		if n.is_evil():
			w.dlog.think(n.id, "lie", "Evil cover: publicly claims bluff %s." % role, {"bluff": role, "true_role": n.role})
		return role
	return ""

static func _react_to_claim(w, claimant, role: String) -> void:
	for l in w.living():
		if l == claimant or l.is_evil():
			continue
		if l.role == role:
			adjust(w, l, claimant.id, 0.9, "claimed MY role (%s); they are lying" % role,
				"they claimed my own gift, so they're lying", false)
			continue
		for pc in w.public_claims:
			if pc["role"] == role and pc["who"] != claimant.id:
				var other = w.by_id[pc["who"]]
				if known_good(w, other.id):
					adjust(w, l, claimant.id, 0.8, "double claim of %s; other claimant died to the demon" % role,
						"%s claimed the same gift as %s, who the demon killed" % [claimant.name, other.name])
				else:
					adjust(w, l, claimant.id, 0.35, "double claim of %s with %s" % [role, other.id],
						"they and %s both claim to be the %s" % [other.name, C.role_name(role)])
					adjust(w, l, other.id, 0.25, "double claim of %s with %s" % [role, claimant.id],
						"they and %s both claim to be the %s" % [claimant.name, C.role_name(role)])

static func _claim_line(n, role: String) -> Dictionary:
	var openers = {
		"warm": "I'll not keep secrets from my neighbours. ",
		"gruff": "Fine. ",
		"formal": "In the interest of the town, I shall be plain. ",
		"nervous": "I-I suppose I have to say it. ",
		"plain": "Here's the truth of it. ",
	}
	return say(n, "%sI am the %s." % [openers.get(n.style, ""), C.role_name(role)])

static func info_line(w, n, e: Dictionary) -> Dictionary:
	var when = "On the first night" if e["day"] == 0 else "Last night" if e["day"] == w.day - 1 else "On night %d" % e["day"]
	return say(n, "%s, %s." % [when, e["text"]])

static func info_fact(w, n, e: Dictionary) -> Dictionary:
	var subj: Array = []
	var d: Dictionary = e["data"]
	for k in ["nbrs", "pair", "seen"]:
		if d.has(k):
			subj += d[k]
	if d.has("executed"):
		subj.append(d["executed"])
	return {"kind": "info", "subject": subj, "source": n.id, "day": e["day"], "role": e["role"], "data": d.duplicate(),
		"text": "%s (as %s, night %d): %s." % [n.name, C.role_name(e["role"]), e["day"], e["text"]]}

static func _public_accusation(w, n):
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
		why = n.sus_why.get(t.id, "")
	why = Evil.cite(w, n, why)
	var parts = {"suspicion": (s2 - 0.6) * 1.5, "confidence": (trait_of(n, "confidence") - 0.5) * 0.8,
		"pressure_deflect": n.pressure * 0.4}
	if not decide(w, n, "accuse", parts, "Publicly accuse %s?" % t.id):
		return null
	if n.is_evil():
		w.dlog.think(n.id, "lie", "Evil: publicly accuses scapegoat %s, citing: %s." % [t.id, why if why != "" else "vibes"])
	for l in w.living():
		if l != n and l != t:
			adjust(w, l, t.id, 0.12 * heard_weight(l, n) * 2.0, "public accusation by %s" % n.id,
				"%s spoke against them at the meeting" % n.name)
	t.pressure += 0.15
	var tail = (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else " Something's off about them."
	return {"line": say(n, "I don't trust %s.%s" % [t.name, tail]),
		"fact": {"kind": "accusation", "subject": [t.id], "source": n.id, "text": "%s publicly accused %s." % [n.name, t.name]}}

## Next NPC nomination, or null. Respects BotC limits and who is already on the block.
static func next_nomination(w):
	var m: Dictionary = w.meeting
	var cands: Array = []
	var block: String = m["block"]
	for n in w.living():
		if n.id in m["nominators"]:
			continue
		if n.is_evil():
			var ev = Evil.evil_nomination(w, n)
			if ev != null:
				cands.append(ev)
			continue
		var thr: float = maxf(0.45, 0.86 - 0.08 * w.day) - 0.15 * (trait_of(n, "confidence") - 0.5) * 2.0
		for t in ranked_suspects(w, n):
			if t.id in m["nominated"]:
				continue
			var s = susp(n, t.id)
			if s < thr:
				break
			if block != "" and susp(n, block) >= s:
				break  # content with who is already on the block
			cands.append({"nominee": t.id, "by": n.id, "score": s,
				"reason": "suspicion of %s %.2f >= threshold %.2f" % [t.id, s, thr]})
			break
	if cands.is_empty():
		return null
	cands.sort_custom(func(a, b): return a["score"] > b["score"])
	var c: Dictionary = cands[0]
	w.dlog.think(c["by"], "nominate", c["reason"], {"nominee": c["nominee"]})
	var nom = w.by_id[c["by"]]
	var t = w.by_id[c["nominee"]]
	var why: String = Evil.cite(w, nom, Evil.bluff_reason(w, nom, t) if nom.is_evil() else nom.sus_why.get(t.id, ""))
	c["speech"] = say(nom, "I nominate %s.%s" % [t.name, (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else ""])
	return c

static func defence_line(w, n) -> Dictionary:
	var c = trait_of(n, "confidence")
	if c > 0.66:
		return say(n, "This is madness, and you all know it.")
	if c < 0.34:
		return say(n, "P-please. I've done nothing.")
	return say(n, "You've got the wrong person.")

## One NPC's vote on a nomination. statement: "", "defend" or "accuse" (the player's).
static func vote(w, v, nominee: String, nominator: String, player_yes: bool, statement: String, yes_so_far: int) -> bool:
	if v.id == nominee:
		w.dlog.think(v.id, "vote", "Votes no on own execution.", {"nominee": nominee, "yes": false})
		return false
	if v.is_evil():
		return Evil.evil_vote(w, v, nominee, yes_so_far)
	var base = susp(v, nominee)
	var s = base
	var parts = {"suspicion": snappedf(base, 0.01)}
	if player_yes:
		parts["player_votes_yes"] = 0.25 * v.trust - 0.05
	if statement == "defend":
		parts["player_defends"] = -0.25 * v.trust
	elif statement == "accuse":
		parts["player_accuses"] = 0.2 * v.trust
	parts["trust_in_nominee"] = -(v.npc_trust.get(nominee, 0.5) - 0.5) * 0.6
	if nominator != "player" and susp(v, nominator) > 0.7:
		parts["distrusts_nominator"] = -0.15
	var block: String = w.meeting["block"]
	if block != "" and block != nominee and susp(v, block) >= base:
		parts["prefers_block"] = -0.4
	for k in parts:
		if k != "suspicion":
			s += parts[k]
	var need = 0.5 - 0.12 * (trait_of(v, "confidence") - 0.5) * 2.0 + (0.1 if w.day <= 1 else 0.0)
	var yes = s >= need
	parts["total"] = snappedf(s, 0.01)
	parts["need"] = snappedf(need, 0.01)
	w.dlog.think(v.id, "vote", "%s on %s (score %.2f vs %.2f)." % ["YES" if yes else "no", nominee, s, need], parts)
	return yes

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
static func _target_tier(w, n) -> int:
	var openness = (1.0 - trait_of(n, "privacy")) * 1.0 + n.trust * 1.2 + n.pressure * 0.6 * (1.0 - 0.5 * trait_of(n, "composure")) \
		+ 0.1 * (w.day - 1) - 0.72 + w.rng.randf_range(-0.2, 0.2)
	var t = 1
	if openness > 0.75:
		t = 4
	elif openness > 0.45:
		t = 3
	elif openness > 0.15:
		t = 2
	w.dlog.think(n.id, "disclosure", "Disclosure tier %d (openness %.2f; privacy %.2f, trust %.2f, pressure %.2f)." %
		[t, openness, trait_of(n, "privacy"), n.trust, n.pressure], {"tier": t})
	return t

## The unified gift/info question. Tiers: 1 deny/refuse, 2 hint, 3 gift, 4 gift + readings.
static func answer_gift(w, n) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var evil: bool = n.is_evil()
	var role: String = w.evil_plan["bluffs"][n.id] if evil else n.role
	var target = _target_tier(w, n)
	if n.claim_public:
		target = maxi(target, 3)
	var tier = maxi(target, n.max_tier)
	var withholding = target < n.max_tier
	if tier <= 1:
		var lie = decide(w, n, "deny_or_refuse", {"confidence": (trait_of(n, "confidence") - 0.5) * 1.5, "base": -0.1},
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
		else:
			lines.append(say(n, "Whether I have a gift is my own business."))
			facts.append({"kind": "refusal", "subject": [n.id], "source": n.id, "private": true,
				"text": "%s refused to say whether they have a gift." % n.name})
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
		lines.append(say(n, "I'll trust you with this. I'm the %s." % C.role_name(role)))
	else:
		lines.append(say(n, "As you know, I'm the %s." % C.role_name(role)))
	facts.append({"kind": "claim", "subject": [n.id], "role": role, "source": n.id, "private": not n.claim_public,
		"text": "%s %s the %s." % [n.name, "claims to be" if n.claim_public else "told you privately they are", C.role_name(role)]})
	if first_time:
		set_trust(w, n, n.trust + 0.03, "shared their gift with the Demonologist")
	n.max_tier = maxi(n.max_tier, 3)
	if not (role in C.INFO_ROLES):
		lines.append(say(n, "My gift doesn't tell me things. It only does what it does."))
		n.max_tier = maxi(n.max_tier, tier)
		return {"lines": lines, "facts": facts}
	# Readings: public ones are always repeated; private ones need tier 4.
	var readings: Array = []
	for i in range(n.info_log.size()):
		var e: Dictionary = n.info_log[i]
		if e["shared"] or i < n.told_readings or tier >= 4 and not withholding:
			readings.append(e)
	if tier >= 4 and not withholding:
		n.told_readings = n.info_log.size()
		n.max_tier = 4
	if evil and not readings.is_empty():
		w.dlog.think(n.id, "lie", "Evil: recites fabricated %s results." % role)
	for e in readings:
		lines.append(info_line(w, n, e))
		facts.append(info_fact(w, n, e))
	var held = n.info_log.size() - readings.size()
	if held > 0:
		if withholding:
			lines.append(say(n, "I've told you what I knew before. The rest I'll keep, for now."))
			w.dlog.think(n.id, "withhold", "Trust fell; withholding %d newer reading(s) from the player." % held)
		else:
			lines.append(say(n, "What it's shown me, I'll keep to myself for now."))
	elif n.info_log.is_empty():
		lines.append(say(n, "It hasn't shown me anything yet."))
	return {"lines": lines, "facts": facts}

## Sharing what they saw of others is gated by Gossip (and loosened by pressure).
static func _gossip_share(w, n, topic: String) -> int:
	var g = trait_of(n, "gossip")
	if g < 0.2 and n.pressure < 0.5:
		w.dlog.think(n.id, topic, "Gossip %.2f: none of my business (pressure %.2f)." % [g, n.pressure])
		return 0
	var limit = 1 + int(round((g + n.pressure * 0.5) * 6.0))
	return limit

static func answer_night(w, n) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var nd: int = w.day - 1
	var where: String = n.history.get(w.time_key(nd, C.NIGHT), "home:" + n.home_block)
	var was_out = where.begins_with("night:")
	var block = where.substr(where.find(":") + 1)
	if n.is_evil() and n.claimed_role == "nightwatch" and w.evil_plan["fake_watch"].has(str(nd)):
		var fb: String = w.evil_plan["fake_watch"][str(nd)]
		w.dlog.think(n.id, "lie", "Evil bluffing Night Watch: claims to have watched %s (actually %s)." % [fb, where], {"lie": true})
		lines.append(say(n, "Keeping watch over %s, as is my duty." % C.block_name(fb)))
	elif not was_out:
		lines.append(say(n, "At home, asleep, same as any honest soul."))
	elif n.role == "nightwatch" and n.claimed_role == "nightwatch":
		lines.append(say(n, "Keeping watch over %s, as is my duty." % C.block_name(block)))
		facts.append({"kind": "sighting", "subject": [n.id], "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
			"text": "%s says they kept watch on %s on night %d." % [n.name, C.block_name(block), nd]})
	else:
		# Out with something to hide: evil work, a personal secret, or a hidden Night Watch gift.
		var hiding = "evil work" if n.is_evil() else ("hidden Night Watch gift" if n.role == "nightwatch" else "secret: %s" % n.secret.get("kind", "?"))
		var can_confess = not n.is_evil() and not n.secret.is_empty()
		var confess = false
		if can_confess:
			confess = decide(w, n, "confess", {"trust": (n.trust - 0.6) * 1.5, "privacy": (0.4 - trait_of(n, "privacy")) * 1.0,
				"pressure": n.pressure * 0.8 * (1.0 - 0.5 * trait_of(n, "composure")), "insight_none": 0.0},
				"Confess personal secret (%s)?" % n.secret.get("kind", "?"))
		if confess:
			n.secret_known = true
			lines.append(say(n, "...I wasn't home. I %s. Please, keep it quiet." % n.secret["text"]))
			facts.append({"kind": "secret", "subject": [n.id], "owner": n.id, "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
				"text": "%s confessed they were out on %s on night %d: they %s." % [n.name, C.block_name(block), nd, n.secret["text"]]})
		else:
			var bold = decide(w, n, "lie_or_stonewall", {"confidence": (trait_of(n, "confidence") - 0.5) * 1.5,
				"privacy_stonewalls": -(trait_of(n, "privacy") - 0.5) * 0.6}, "Hiding (%s): lie outright rather than stonewall?" % hiding)
			if bold:
				w.dlog.think(n.id, "lie", "Hiding (%s): was on %s, claims to have been home." % [hiding, block], {"lie": true})
				lines.append(say(n, "Home. Where else would I be?"))
			else:
				w.dlog.think(n.id, "stonewall", "Hiding (%s): refuses to say where they were." % hiding)
				lines.append(say(n, "Where I go at night is my own business."))
				facts.append({"kind": "refusal", "subject": [n.id], "source": n.id, "day": nd, "phase": C.NIGHT,
					"text": "%s refused to say where they were on night %d." % [n.name, nd]})
	var limit = _gossip_share(w, n, "share_sightings")
	var seen: Array = n.beliefs.filter(func(b): return b["kind"] == "saw" and b["day"] == nd and b["phase"] == C.NIGHT)
	var reported: Array = []
	for b in seen:
		if n.is_evil() and Evil.is_teammate(w, n, b["who"]):
			w.dlog.think(n.id, "lie", "Evil: omits seeing teammate %s at night." % b["who"])
			continue
		if n.npc_trust.get(b["who"], 0.5) > 0.7 and w.rng.randf() < 0.6:
			w.dlog.think(n.id, "omit", "Leaves out seeing %s, whom they trust." % b["who"])
			continue
		reported.append(b)
	if n.is_evil():
		var fake = Evil.fake_night_sighting(w, n, nd)
		if fake != null:
			reported.append(fake)
	if limit == 0 and not reported.is_empty():
		lines.append(say(n, "As for anyone else, that's none of my business."))
		return {"lines": lines, "facts": facts}
	reported = reported.slice(0, limit)
	if reported.is_empty() and not (was_out and not n.is_evil()):
		lines.append(say(n, "I saw nobody."))
	for b in reported:
		var who = w.by_id[b["who"]]
		lines.append(say(n, "I did see %s out on %s that night." % [who.name, C.block_name(b["block"])]))
		facts.append({"kind": "sighting", "subject": [who.id], "block": b["block"], "day": nd, "phase": C.NIGHT, "source": n.id,
			"text": "%s says they saw %s on %s on night %d." % [n.name, who.name, C.block_name(b["block"]), nd]})
	return {"lines": lines, "facts": facts}

static func answer_today(w, n) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var limit = _gossip_share(w, n, "share_sightings")
	if limit == 0:
		lines.append(say(n, "Who goes where is none of my business."))
		return {"lines": lines, "facts": facts}
	var seen: Array = n.beliefs.filter(func(b): return b["kind"] == "saw" and b["phase"] != C.NIGHT and b["day"] >= w.day - 1)
	var dedup = {}
	for b in seen:
		if n.is_evil() and Evil.is_teammate(w, n, b["who"]):
			continue
		dedup["%s|%d|%d" % [b["who"], b["day"], b["phase"]]] = b
	if dedup.is_empty():
		lines.append(say(n, "Nobody worth mentioning."))
		return {"lines": lines, "facts": facts}
	var keys: Array = dedup.keys()
	keys.reverse()
	var parts: Array = []
	for k in keys.slice(0, limit):
		var b: Dictionary = dedup[k]
		var who = w.by_id[b["who"]]
		var when = "%s %s" % ["yesterday" if b["day"] < w.day else "this", C.PHASES[b["phase"]].to_lower()]
		var where: String = w.loc_name(b["loc"]) if b["loc"] != "" else C.block_name(b["block"])
		parts.append("%s at %s (%s)" % [who.name, where, when])
		facts.append({"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": b["phase"], "source": n.id,
			"text": "%s saw %s on %s, day %d %s." % [n.name, who.name, C.block_name(b["block"]), b["day"], C.PHASES[b["phase"]]]})
	lines.append(say(n, "Let me think. " + "; ".join(PackedStringArray(parts)) + "."))
	return {"lines": lines, "facts": facts}

static func answer_opinion(w, n, t) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var text = ""
	var level = 0.0
	if trait_of(n, "gossip") < 0.2 and n.pressure < 0.5:
		w.dlog.think(n.id, "opinion", "Gossip %.2f: won't discuss others." % trait_of(n, "gossip"))
		lines.append(say(n, "It's not my place to say."))
		return {"lines": lines, "facts": facts}
	# Same pipeline for both alignments: a suspicion level plus an optional grounded reason.
	var why = ""
	var lie = false
	if n.is_evil():
		if Evil.is_teammate(w, n, t.id):
			level = 0.2
			lie = true
		elif t.id == w.evil_plan["scapegoat"]:
			level = 0.85
			why = Evil.bluff_reason(w, n, t)
			lie = true
		else:
			level = Evil.town_view(w, t)
	else:
		level = susp(n, t.id)
		why = n.sus_why.get(t.id, "")
	why = Evil.cite(w, n, why)
	var shown = level
	if level < 0.25:
		text = "I trust %s." % t.name
	elif level < 0.45:
		if w.rng.randf() < 0.6 - 0.4 * trait_of(n, "insight"):
			text = "I can't put my finger on it, but something's off about %s." % t.name
			shown = 0.5
		else:
			text = "%s seems all right to me." % t.name
	elif level < 0.8:
		text = "I have my doubts about %s." % t.name
	else:
		text = "If you ask me, %s is the one." % t.name
	if level >= 0.45:
		text += (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else " Something's off about them."
	if n.npc_trust.get(t.id, 0.5) > 0.7 and not (n.is_evil() and t.id == w.evil_plan["scapegoat"]):
		text += " We're close, mind."
	w.dlog.think(n.id, "lie" if lie else "opinion", "%s opinion of %s: level %.2f, reason: %s." %
		["Evil cover" if lie else ("Evil (mimicking the town)" if n.is_evil() else "Honest"), t.id, level, why if why != "" else "vibes"])
	level = shown
	lines.append(say(n, text))
	if level >= 0.5:
		facts.append({"kind": "opinion", "subject": [t.id], "source": n.id, "text": "%s distrusts %s." % [n.name, t.name]})
	return {"lines": lines, "facts": facts}

## Evidence class of a card: speech, circumstantial or concrete.
static func evidence_class(card: Dictionary) -> String:
	var src: String = card.get("source", "")
	var kind: String = card.get("kind", "")
	if src == "player" and kind in ["sighting", "vigil", "death", "vote", "execution"]:
		return "concrete"
	if kind in ["claim", "hint", "refusal", "opinion", "accusation"]:
		return "speech"
	return "circumstantial"

## How incriminating a board card is on its own (0..1.4), before credibility and trust.
static func card_strength(w, card: Dictionary, suspect) -> float:
	match card.get("kind", ""):
		"sighting":
			return 1.4 if card.get("phase", -1) == C.NIGHT else 0.15
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
			return 0.0
		"trace":
			return 0.7
		"accusation", "opinion":
			return 0.4
		"refusal":
			return 0.35
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

## The player's case: "tell <n>: <suspect> is suspicious because <card>".
static func hear_accusation(w, n, suspect, card: Dictionary) -> Dictionary:
	on_question(w, n)
	_secret_used(w, card)
	var lines: Array = []
	var subj: Array = card.get("subject", [])
	var relevance = 1.0 if suspect.id in subj else 0.25
	var src: String = card.get("source", "")
	var cred = 0.5
	var cred_why = ""
	if src == "player":
		cred = 1.0
		cred_why = "you saw it yourself"
	elif src == "evidence":
		cred = 0.9
		cred_why = "physical evidence"
	elif src == n.id:
		cred = 1.0
		cred_why = "their own words"
	elif src != "" and w.by_id.has(src):
		cred = clampf(0.9 - susp(n, src), 0.1, 0.9)
		cred_why = "source %s (suspicion %.2f)" % [src, susp(n, src)]
	if card.get("kind", "") == "trace":
		relevance = 1.0 if suspect.home_block == card.get("block", "") or w.loc_block(suspect.work) == card.get("block", "") else 0.3
	var strength = card_strength(w, card, suspect)
	relevance *= strength
	var cls = evidence_class(card)
	var ins = trait_of(n, "insight")
	var class_w = {"speech": lerpf(1.0, 0.2, ins), "circumstantial": lerpf(1.0, 0.6, ins), "concrete": 1.0}[cls]
	var key: String = card.get("text", "")
	var times: int = n.heard.get(key, 0)
	n.heard[key] = times + 1
	var repeat_mult = pow(0.35, times)
	if n.is_evil():
		return Evil.evil_hear_accusation(w, n, suspect, card, relevance)
	var delta: float = 0.35 * cred * relevance * class_w * repeat_mult * (0.5 + n.trust)
	var bond: float = n.npc_trust.get(suspect.id, 0.5)
	if bond > 0.6:
		delta *= 1.0 - (bond - 0.5) * 1.4
		set_trust(w, n, n.trust - 0.12 * (bond - 0.5) * 2.0, "player accused %s, whom I trust" % suspect.id)
	var old = susp(n, suspect.id)
	adjust(w, n, suspect.id, delta, "player accusation using card '%s' (class %s x%.2f, cred %.2f: %s, relevance %.2f, repeat x%.2f, trust %.2f)" %
		[key, cls, class_w, cred, cred_why, relevance, repeat_mult, n.trust], "the Demonologist made a case against them")
	var nv = susp(n, suspect.id)
	w.dlog.think(n.id, "persuaded", "Accusation moved suspicion of %s from %.2f to %.2f." % [suspect.id, old, nv])
	if times > 0:
		lines.append(say(n, "You've told me that already."))
	elif strength < 0.3 and suspect.id in subj:
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
	return {"lines": lines, "facts": []}

## Tavern gossip. Returns {lines, facts}.
static func gossip(w) -> Dictionary:
	var present: Array = w.npcs_at("tavern")
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
	var night_seen: Array = speaker.beliefs.filter(func(b): return b["kind"] == "saw" and b["phase"] == C.NIGHT and b["day"] >= w.day - 2)
	if not night_seen.is_empty() and trait_of(speaker, "gossip") >= 0.2:
		var b: Dictionary = night_seen[night_seen.size() - 1]
		var who = w.by_id[b["who"]]
		w.dlog.think(speaker.id, "gossip", "Shares a true night sighting of %s." % who.id)
		return {"lines": ["You overhear %s telling the room that %s was out on %s on night %d." %
			[speaker.name, who.name, C.block_name(b["block"]), b["day"]]],
			"facts": [{"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": C.NIGHT, "source": speaker.id,
				"text": "Gossip from %s: %s was out on %s on night %d." % [speaker.name, who.name, C.block_name(b["block"]), b["day"]]}]}
	var ranked = ranked_suspects(w, speaker)
	if not ranked.is_empty() and susp(speaker, ranked[0].id) >= 0.4:
		var t = ranked[0]
		w.dlog.think(speaker.id, "gossip", "Shares their suspicion of %s." % t.id)
		var why: String = speaker.sus_why.get(t.id, "")
		var tail = (", because " + why) if why != "" else ". Something's off about them, apparently"
		return {"lines": ["You overhear %s muttering that %s can't be trusted%s." % [speaker.name, t.name, tail]],
			"facts": [{"kind": "opinion", "subject": [t.id], "source": speaker.id, "text": "Gossip: %s distrusts %s." % [speaker.name, t.name]}]}
	return {"lines": ["You overhear %s complaining about the price of bread. Nothing useful." % speaker.name], "facts": []}
