## NPC reasoning for good and evil townsfolk: suspicion, claims, testimony, nominations,
## votes and conversation answers. Every decision with hidden reasoning is written to the
## dev log via w.dlog.think(...).
##
## All functions are static and take the world as the first argument.
extends RefCounted

const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")

# ---------------------------------------------------------------- suspicion

static func adjust(w, listener, target_id: String, delta: float, why: String, public_why: String = "") -> void:
	if listener.is_evil() or target_id == listener.id or not listener.suspicion.has(target_id):
		return
	var t = w.by_id[target_id]
	if not t.alive and t.death_cause == "demon":
		return  # killed by the demon: known good
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
## weight: 1.0 for own info, lower for heard info depending on trust in the source.
static func apply_info(w, listener, source, entry: Dictionary, weight: float) -> void:
	if weight <= 0.01 or listener.is_evil():
		return
	var d: Dictionary = entry["data"]
	var r: String = entry["role"]
	var src_name: String = source.name + "'s" if source != listener else "my own"
	var src_bare: String = source.name if source != listener else "I"
	var tag = "own info" if source == listener else "heard %s's info (w=%.2f)" % [source.id, weight]
	match r:
		"hearthwitch":
			var nbrs: Array = d["nbrs"]
			var count: int = d["count"]
			var others: Array = nbrs.filter(func(i): return i != listener.id and not known_good(w, i))
			var excluded = nbrs.size() - others.size()
			if listener.id in nbrs and count > 0:
				pass  # listener knows they are not evil, so the evil must be among others
			if count == 0:
				for i in others:
					adjust(w, listener, i, -0.25 * weight, tag + ": hearthwitch count 0")
			else:
				var per = 0.35 * count
				if excluded > 0:
					per = 0.7 * count
				if count > others.size() and source != listener:
					adjust(w, listener, source.id, 0.5 * weight, tag + ": hearthwitch count impossible from my view",
						"%s reading about the lane can't be right" % src_name)
				for i in others:
					adjust(w, listener, i, per * weight, tag + ": hearthwitch count %d" % count,
						"%s reading pointed at their neighbours" % src_name)
		"seer":
			var pair: Array = d["pair"]
			var others: Array = pair.filter(func(i): return i != listener.id and not known_good(w, i))
			if d["yes"]:
				var per = 0.45 if others.size() > 1 else 0.85
				for i in others:
					adjust(w, listener, i, per * weight, tag + ": seer yes",
						"%s sight said one of them is the demon" % src_name)
			else:
				for i in others:
					adjust(w, listener, i, -0.3 * weight, tag + ": seer no")
		"nightwatch":
			var seen: Array = d["seen"]
			for i in seen:
				if i == listener.id:
					var key: String = w.time_key(entry["day"], C.NIGHT)
					var where: String = listener.history.get(key, "")
					if where.begins_with("home") and source != listener:
						adjust(w, listener, source.id, 0.45 * weight, tag + ": claims to have seen me out, but I was home",
							"%s claims to have seen me out at night, which is a lie" % src_bare)
					continue
				var bonus = 0.0
				for sid in w.scenes:
					if w.scenes[sid]["day"] == entry["day"] and w.scenes[sid]["block"] == d["block"]:
						bonus = 0.3
				adjust(w, listener, i, (0.2 + bonus) * weight, tag + ": seen out at night",
					"%s saw them out at night" % src_bare)
		"archivist":
			var pair: Array = d["pair"]
			var others: Array = pair.filter(func(i): return i != listener.id and not known_good(w, i))
			var per = 0.35 if others.size() > 1 else 0.75
			for i in others:
				adjust(w, listener, i, per * weight, tag + ": archivist pair",
					"%s records tie them to the Poisoner" % src_name)
		"clerk":
			var pair: Array = d["pair"]
			if listener.id in pair and d["role"] == listener.role and source != listener:
				adjust(w, listener, source.id, -0.3 * weight, tag + ": clerk correctly named my role")
			for i in pair:
				if i != listener.id:
					adjust(w, listener, i, -0.15 * weight, tag + ": clerk pair probably good")
		"gravedigger":
			var ex = w.by_id[d["executed"]]
			var ex_good: bool = C.ROLES[d["role"]]["align"] == "good"
			for e in w.executions:
				if e["id"] == ex.id:
					for nom in e["nominators"]:
						if nom == "player":
							continue
						adjust(w, listener, nom, (0.25 if ex_good else -0.2) * weight,
							tag + ": nominator of %s, who was %s" % [ex.id, d["role"]],
							"they pushed to hang %s, who was innocent" % ex.name)

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
		if m.id in n.friends:
			s += 0.3
		s -= susp(n, m.id) * 0.5
		scores[m.id] = snappedf(s, 0.01)
		if s > best_s:
			best_s = s
			best = m.id
	w.dlog.think(n.id, "warden_pick", "Protects whoever scores highest (trusted info claimants, friends).", {"scores": scores, "pick": best})
	return best

# ---------------------------------------------------------------- town meeting

static func say(n, text: String) -> String:
	return "%s: \"%s\"" % [n.name, text]

## Public testimony before nominations. Returns Array of {who, text, facts}.
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
				lines.append(_info_line(w, n, e))
				facts.append(_info_fact(w, n, e))
				for l in w.living():
					if l != n:
						apply_info(w, l, n, e, heard_weight(l, n))
		var acc = _public_accusation(w, n)
		if acc != null:
			lines.append(acc["text"])
			facts.append(acc["fact"])
		if not lines.is_empty():
			out.append({"who": n.id, "text": "\n".join(PackedStringArray(lines)), "facts": facts})
	return out

static func _public_claim_decision(w, n) -> String:
	var cau: float = n.traits["caution"]
	if n.is_evil():
		var bluff: String = w.evil_plan["bluffs"][n.id]
		var claim_day: int = w.evil_plan["claim_day"][n.id]
		if w.day >= claim_day:
			w.dlog.think(n.id, "claim", "Evil cover: publicly claims bluff %s." % bluff, {"bluff": bluff, "lie": true})
			return bluff
		w.dlog.think(n.id, "claim", "Evil: holding claim until day %d to look natural." % claim_day)
		return ""
	var kind: String = C.ROLES[n.role]["kind"]
	var reveal = false
	var why = ""
	if kind == "info":
		reveal = w.day >= 2 or cau < 0.55
		why = "info role; caution %.2f, day %d" % [cau, w.day]
	else:
		reveal = w.day >= 3 or cau < 0.3
		why = "protective/passive role, hides from the demon until day 3; caution %.2f" % cau
	if not reveal and w.living().size() <= 4:
		reveal = true
		why = "few people left; hiding no longer helps"
	w.dlog.think(n.id, "claim", ("Reveals true role. " if reveal else "Keeps gift hidden. ") + why, {"role": n.role})
	return n.role if reveal else ""

static func _react_to_claim(w, claimant, role: String) -> void:
	for l in w.living():
		if l == claimant or l.is_evil():
			continue
		if l.role == role:
			adjust(w, l, claimant.id, 0.9, "claimed MY role (%s); they are lying" % role,
				"they claimed my own gift, so they're lying")
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

static func _claim_line(n, role: String) -> String:
	var openers = {
		"warm": "I'll not keep secrets from my neighbours. ",
		"gruff": "Fine. ",
		"formal": "In the interest of the town, I shall be plain. ",
		"nervous": "I-I suppose I have to say it. ",
		"plain": "Here's the truth of it. ",
	}
	return say(n, "%sI am the %s." % [openers.get(n.style, ""), C.role_name(role)])

static func _info_line(w, n, e: Dictionary) -> String:
	var when = "On the first night" if e["day"] == 0 else "Last night" if e["day"] == w.day - 1 else "On night %d" % e["day"]
	return say(n, "%s, %s." % [when, e["text"]])

static func _info_fact(w, n, e: Dictionary) -> Dictionary:
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
	if n.is_evil():
		var s: String = w.evil_plan["scapegoat"]
		if w.by_id[s].alive and w.day >= 2 and w.chance(0.5):
			w.dlog.think(n.id, "accuse", "Evil: publicly casts doubt on scapegoat %s." % s)
			for l in w.living():
				if l != n:
					adjust(w, l, s, 0.15 * heard_weight(l, n) * 2.0, "public accusation by %s" % n.id,
						"%s spoke against them at the meeting" % n.name)
			return {"text": say(n, "I'll say it: I don't trust %s." % w.by_id[s].name),
				"fact": {"kind": "accusation", "subject": [s], "source": n.id, "text": "%s publicly accused %s." % [n.name, w.by_id[s].name]}}
		return null
	var ranked = ranked_suspects(w, n)
	if ranked.is_empty():
		return null
	var t = ranked[0]
	var s2 = susp(n, t.id)
	if s2 >= 0.6 and w.chance(0.4 + n.traits["temper"] * 0.4):
		w.dlog.think(n.id, "accuse", "Publicly accuses top suspect %s (suspicion %.2f)." % [t.id, s2])
		for l in w.living():
			if l != n and l != t:
				adjust(w, l, t.id, 0.12 * heard_weight(l, n) * 2.0, "public accusation by %s" % n.id,
					"%s spoke against them at the meeting" % n.name)
		var why: String = n.sus_why.get(t.id, "")
		var tail = (" " + why[0].to_upper() + why.substr(1) + ".") if why != "" else ""
		return {"text": say(n, "I don't trust %s.%s" % [t.name, tail]),
			"fact": {"kind": "accusation", "subject": [t.id], "source": n.id, "text": "%s publicly accused %s." % [n.name, t.name]}}
	return null

## NPC nominations at the evening meeting. Returns Array of {nominee, by, reason}.
static func npc_nominations(w) -> Array:
	var cands: Array = []
	var thr: float = maxf(0.5, 0.86 - 0.08 * w.day)
	for n in w.living():
		if n.is_evil():
			continue
		var ranked = ranked_suspects(w, n)
		if ranked.is_empty():
			continue
		var t = ranked[0]
		var s = susp(n, t.id)
		if s >= thr:
			cands.append({"nominee": t.id, "by": n.id, "score": s,
				"reason": "top suspect %s at %.2f >= threshold %.2f" % [t.id, s, thr]})
	var ev = Evil.evil_nomination(w)
	if ev != null:
		cands.append(ev)
	cands.sort_custom(func(a, b): return a["score"] > b["score"])
	var out: Array = []
	var used_nominees = {}
	var used_by = {}
	for c in cands:
		if out.size() >= 2:
			break
		if used_nominees.has(c["nominee"]) or used_by.has(c["by"]):
			continue
		used_nominees[c["nominee"]] = true
		used_by[c["by"]] = true
		out.append(c)
		w.dlog.think(c["by"], "nominate", c["reason"], {"nominee": c["nominee"]})
	return out

static func vote(w, v, nominee: String, nominator: String, player_supports: bool, yes_so_far: int) -> bool:
	if v.id == nominee:
		w.dlog.think(v.id, "vote", "Votes no on own execution.", {"nominee": nominee, "yes": false})
		return false
	if v.is_evil():
		return Evil.evil_vote(w, v, nominee, yes_so_far)
	var base = susp(v, nominee)
	var s = base
	var parts = {"suspicion": snappedf(base, 0.01)}
	if player_supports:
		var b: float = 0.3 * v.trust - 0.05
		s += b
		parts["player_pull"] = snappedf(b, 0.01)
	if nominee in v.friends:
		var b2: float = -0.2 * v.traits["loyalty"]
		s += b2
		parts["friend"] = snappedf(b2, 0.01)
	if nominee in v.rivals:
		s += 0.1
		parts["rival"] = 0.1
	if nominator != "player" and susp(v, nominator) > 0.7:
		s -= 0.15
		parts["distrusts_nominator"] = -0.15
	var need = 0.6 if w.day <= 1 else 0.5
	var yes = s >= need
	parts["total"] = snappedf(s, 0.01)
	w.dlog.think(v.id, "vote", "%s on %s (score %.2f vs %.2f)." % ["YES" if yes else "no", nominee, s, need], parts)
	return yes

# ---------------------------------------------------------------- conversation

static func _trust_gain(w, n, amount: float, why: String) -> void:
	var old: float = n.trust
	n.trust = clampf(n.trust + amount, 0.0, 1.0)
	if absf(amount) >= 0.03:
		w.dlog.add("trust", n.id, "player", {"from": snappedf(old, 0.01), "to": snappedf(n.trust, 0.01)}, why)

static func on_question(w, n) -> void:
	n.pressed_today += 1
	if n.pressed_today > 3:
		var drop: float = -0.04 - 0.06 * n.traits["temper"]
		_trust_gain(w, n, drop, "pressed with %d questions today" % n.pressed_today)

## Private role question.
static func answer_role(w, n) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	if n.is_evil():
		var bluff: String = w.evil_plan["bluffs"][n.id]
		n.claimed_role = bluff
		n.told_player_role = true
		w.dlog.think(n.id, "lie", "Evil cover: tells the player they are the %s." % bluff, {"true_role": n.role})
		lines.append(say(n, "Between us? I'm the %s." % C.role_name(bluff)))
		facts.append(_claim_fact(n, bluff, true))
		return {"lines": lines, "facts": facts}
	if n.claimed_role != "" and n.claimed_role != "none":
		lines.append(say(n, "As I said, I'm the %s." % C.role_name(n.claimed_role)))
		facts.append(_claim_fact(n, n.claimed_role, not n.claim_public))
		return {"lines": lines, "facts": facts}
	var need: float = 0.25 + n.traits["caution"] * 0.45
	if w.day >= 3:
		need -= 0.15
	if n.trust >= need:
		n.claimed_role = n.role
		n.told_player_role = true
		w.dlog.think(n.id, "claim", "Trusts the player (%.2f >= %.2f): reveals true role privately." % [n.trust, need], {"role": n.role})
		lines.append(say(n, "I'll trust you with this. I'm the %s. %s" % [C.role_name(n.role), C.ROLES[n.role]["desc"]]))
		facts.append(_claim_fact(n, n.role, true))
		_trust_gain(w, n, 0.05, "shared a secret with the player")
	else:
		n.claimed_role = "none"
		w.dlog.think(n.id, "lie", "Caution: doesn't trust the player enough (%.2f < %.2f); claims no gift. True role %s." % [n.trust, need, n.role], {"lie": true})
		lines.append(say(n, "A gift? No, nothing like that. I'm only the %s." % n.occupation))
		facts.append({"kind": "claim", "subject": [n.id], "role": "none", "source": n.id, "private": true,
			"text": "%s told you privately they have no gift." % n.name})
	return {"lines": lines, "facts": facts}

static func _claim_fact(n, role: String, private: bool) -> Dictionary:
	return {"kind": "claim", "subject": [n.id], "role": role, "source": n.id, "private": private,
		"text": "%s %s to be the %s." % [n.name, "told you privately they claim" if private else "claims", C.role_name(role)]}

static func answer_info(w, n) -> Dictionary:
	if n.claimed_role == "":
		var r = answer_role(w, n)
		if n.claimed_role == "none":
			return r
	else:
		on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	if n.claimed_role == "none":
		lines.append(say(n, "I don't know anything you'd want."))
		return {"lines": lines, "facts": facts}
	if not (n.claimed_role in C.INFO_ROLES):
		lines.append(say(n, "My gift doesn't tell me things. It only does what it does."))
		return {"lines": lines, "facts": facts}
	if n.info_log.is_empty():
		lines.append(say(n, "Nothing yet."))
	for e in n.info_log:
		lines.append(_info_line(w, n, e))
		facts.append(_info_fact(w, n, e))
	if n.is_evil():
		w.dlog.think(n.id, "lie", "Evil: recites fabricated %s results." % n.claimed_role)
	return {"lines": lines, "facts": facts}

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
	elif n.is_evil():
		w.dlog.think(n.id, "lie", "Evil: was out on %s doing evil work; claims to have been home." % block, {"lie": true})
		lines.append(say(n, "Home. Where else would I be?"))
	elif n.role == "nightwatch" and n.claimed_role == "nightwatch":
		lines.append(say(n, "Keeping watch over %s, as is my duty." % C.block_name(block)))
		facts.append({"kind": "sighting", "subject": [n.id], "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
			"text": "%s says they kept watch on %s on night %d." % [n.name, C.block_name(block), nd]})
	elif n.role == "nightwatch":
		w.dlog.think(n.id, "lie", "Hiding Night Watch role, so claims to have been home.", {"lie": true})
		lines.append(say(n, "Home."))
	else:
		var confess: bool = n.trust > 0.7 and n.traits["honesty"] > 0.55
		if confess:
			w.dlog.think(n.id, "confess", "Trusts the player enough to confess personal secret.", {"secret": n.secret})
			lines.append(say(n, "...I wasn't home. I %s. Please, keep it quiet." % n.secret["text"]))
			facts.append({"kind": "sighting", "subject": [n.id], "block": block, "day": nd, "phase": C.NIGHT, "source": n.id,
				"text": "%s confessed they were out on %s on night %d (%s)." % [n.name, C.block_name(block), nd, n.secret["kind"]]})
		else:
			w.dlog.think(n.id, "lie", "Personal secret (%s): was on %s, claims home." % [n.secret.get("kind", "?"), block],
				{"lie": true, "trust": snappedf(n.trust, 0.01)})
			lines.append(say(n, "Home, of course."))
	var seen: Array = n.beliefs.filter(func(b): return b["kind"] == "saw" and b["day"] == nd and b["phase"] == C.NIGHT)
	var reported: Array = []
	for b in seen:
		if n.is_evil() and Evil.is_teammate(w, n, b["who"]):
			w.dlog.think(n.id, "lie", "Evil: omits seeing teammate %s at night." % b["who"])
			continue
		reported.append(b)
	if n.is_evil():
		var fake = Evil.fake_night_sighting(w, n, nd)
		if fake != null:
			reported.append(fake)
	if reported.is_empty():
		if was_out and not n.is_evil():
			pass
		else:
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
	var seen: Array = n.beliefs.filter(func(b): return b["kind"] == "saw" and b["phase"] != C.NIGHT and b["day"] >= w.day - 1)
	var dedup = {}
	for b in seen:
		if n.is_evil() and Evil.is_teammate(w, n, b["who"]):
			continue
		var k = "%s|%d|%d" % [b["who"], b["day"], b["phase"]]
		dedup[k] = b
	if dedup.is_empty():
		lines.append(say(n, "Nobody worth mentioning."))
		return {"lines": lines, "facts": facts}
	var parts: Array = []
	for k in dedup:
		var b: Dictionary = dedup[k]
		var who = w.by_id[b["who"]]
		var when = "%s %s" % ["yesterday" if b["day"] < w.day else "this", C.PHASES[b["phase"]].to_lower()]
		var where: String = w.loc_name(b["loc"]) if b["loc"] != "" else C.block_name(b["block"])
		parts.append("%s at %s (%s)" % [who.name, where, when])
		facts.append({"kind": "sighting", "subject": [who.id], "block": b["block"], "day": b["day"], "phase": b["phase"], "source": n.id,
			"text": "%s saw %s on %s, day %d %s." % [n.name, who.name, C.block_name(b["block"]), b["day"], C.PHASES[b["phase"]]]})
	lines.append(say(n, "Let me think. " + "; ".join(PackedStringArray(parts.slice(0, 8))) + "."))
	return {"lines": lines, "facts": facts}

static func answer_opinion(w, n, t) -> Dictionary:
	on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var text = ""
	var level = 0.0
	if n.is_evil():
		var r: Dictionary = Evil.evil_opinion(w, n, t)
		text = r["text"]
		level = r["level"]
	else:
		level = susp(n, t.id)
		if level < 0.25:
			text = "I trust %s." % t.name
		elif level < 0.5:
			text = "%s seems all right to me." % t.name
		elif level < 0.8:
			text = "I have my doubts about %s." % t.name
		else:
			text = "If you ask me, %s is the one." % t.name
		var why: String = n.sus_why.get(t.id, "")
		if level >= 0.5 and why != "":
			text += " " + why[0].to_upper() + why.substr(1) + "."
		if t.id in n.friends:
			text += " We're close, mind."
		w.dlog.think(n.id, "opinion", "Honest opinion of %s: suspicion %.2f." % [t.id, level])
	lines.append(say(n, text))
	if level >= 0.5:
		facts.append({"kind": "opinion", "subject": [t.id], "source": n.id,
			"text": "%s distrusts %s." % [n.name, t.name]})
	return {"lines": lines, "facts": facts}

## Mad-libs accusation: "Tell <n>: <suspect> is suspicious because <card>".
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
		"claim":
			var role: String = card.get("role", "")
			if role == "" or role == "none":
				return 0.1
			for pc in w.public_claims:
				if pc["role"] == role and pc["who"] != suspect.id:
					return 1.0
			return 0.1
	return 0.2

static func hear_accusation(w, n, suspect, card: Dictionary) -> Dictionary:
	on_question(w, n)
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
	var kind: String = card.get("kind", "")
	if kind == "trace":
		relevance = 1.0 if suspect.home_block == card.get("block", "") or w.loc_block(suspect.work) == card.get("block", "") else 0.3
	# How damning is this kind of card at all?
	var strength = card_strength(w, card, suspect)
	relevance *= strength
	if n.is_evil():
		return Evil.evil_hear_accusation(w, n, suspect, card, relevance)
	var delta: float = 0.35 * cred * relevance * (0.5 + n.trust)
	var friend: bool = suspect.id in n.friends
	if friend:
		delta *= 1.0 - n.traits["loyalty"] * 0.7
		_trust_gain(w, n, -0.08 * n.traits["loyalty"], "player accused my friend %s" % suspect.id)
	var old = susp(n, suspect.id)
	adjust(w, n, suspect.id, delta, "player accusation using card '%s' (cred %.2f: %s, relevance %.2f, trust %.2f)" %
		[card.get("text", "?"), cred, cred_why, relevance, n.trust], "the Demonologist made a case against them")
	var nv = susp(n, suspect.id)
	w.dlog.think(n.id, "persuaded", "Accusation moved suspicion of %s from %.2f to %.2f." % [suspect.id, old, nv])
	if strength < 0.3 and suspect.id in subj:
		lines.append(say(n, "That proves nothing against %s." % suspect.name))
	elif relevance < 0.3:
		lines.append(say(n, "I don't see what that has to do with %s." % suspect.name))
	elif friend and delta < 0.1:
		lines.append(say(n, "%s is my friend. You'll need more than that." % suspect.name))
	elif nv >= 0.8:
		lines.append(say(n, "You're right. I'll not trust %s again." % suspect.name))
	elif delta >= 0.15:
		lines.append(say(n, "That... does look bad for %s." % suspect.name))
	else:
		lines.append(say(n, "Maybe. I'll keep an eye on %s." % suspect.name))
	if delta >= 0.1:
		_trust_gain(w, n, 0.03, "player made a case that seemed sound")
	return {"lines": lines, "facts": []}

## Tavern gossip. Returns {lines, facts}.
static func gossip(w) -> Dictionary:
	var present: Array = w.npcs_at("tavern")
	if present.is_empty():
		return {"lines": ["The tavern is nearly empty. Nobody to overhear."], "facts": []}
	var weights: Array = present.map(func(m): return 0.2 + m.traits["gossip"])
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
	if not night_seen.is_empty():
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
		var tail = (", because " + why) if why != "" else ""
		return {"lines": ["You overhear %s muttering that %s can't be trusted%s." % [speaker.name, t.name, tail]],
			"facts": [{"kind": "opinion", "subject": [t.id], "source": speaker.id, "text": "Gossip: %s distrusts %s." % [speaker.name, t.name]}]}
	var claims: Array = w.public_claims.filter(func(c): return c["who"] != speaker.id)
	return {"lines": ["You overhear %s complaining about the price of bread. Nothing useful." % speaker.name], "facts": []}
