## The town talking to itself (stage 2): what NPCs tell each other, evil meetings and
## whispers, NPCs approaching the player, questions about roles, and paranoia.
##
## Every exchange is logged ("npc_share", "evil_share", "approach") with what was said,
## whether it was true, and who it came from originally.
extends RefCounted

const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")

static func trait_of(n, t: String) -> float:
	return n.traits.get(t, 0.5)

static func _told(s, l, key: String) -> bool:
	return s.told_to.has(l.id + "|" + key)

static func _mark(s, l, key: String) -> void:
	s.told_to[l.id + "|" + key] = true

static func _implicated(e: Dictionary) -> Array:
	return Gifts.implicated(e)

# ---------------------------------------------------------------- news (drives who seeks whom out)

## Does this NPC have something they'd want to tell someone today?
static func has_news(w, n) -> bool:
	if n.is_evil():
		for mate in Evil.mates(w, n):
			if Evil.unshared_intel(n, mate) > 0:
				return true
		return false
	for e in n.info_log:
		if not e["shared"]:
			return true
	return false

## Extra pairing weight for someone with news and the person they'd tell.
static func news_bonus(w, a, b) -> float:
	var bonus = 0.0
	for p in [[a, b], [b, a]]:
		var x = p[0]
		var y = p[1]
		if not has_news(w, x):
			continue
		if x.is_evil():
			if y.is_evil():
				bonus += 0.6
		elif x.npc_trust.get(y.id, 0.5) > 0.6:
			bonus += 0.5
	return bonus

# ---------------------------------------------------------------- NPC-to-NPC exchanges

static func converse(w, a, b, when: String) -> void:
	if a.silenced or b.silenced:
		return  # one of them can't speak
	if a.is_evil() and b.is_evil():
		Evil.share_intel(w, a, b, "meeting (%s)" % when)
		return
	for p in [[a, b], [b, a]]:
		var item = _pick_item(w, p[0], p[1])
		if item != null:
			_deliver(w, p[0], p[1], item)

static func _pick_item(w, s, l):
	var cands: Array = []
	var priv = trait_of(s, "privacy")
	var gos = trait_of(s, "gossip")
	var bond: float = s.npc_trust.get(l.id, 0.5)
	if s.is_evil():
		var sg: String = w.evil_plan.get("scapegoat", "")
		for e in s.info_log:
			if e.get("fake", false) and not e["shared"] and not _told(s, l, "reading:%d:%s" % [e["day"], e["role"]]):
				# Same willingness formula as a good NPC sharing a real reading.
				var wgt = (1.0 - priv) * 1.2 * maxf(0.0, bond - 0.3) * 2.0 + 0.3 * s.pressure
				cands.append([wgt, {"kind": "reading", "entry": e, "about": "", "from": s.id, "key": "reading:%d:%s" % [e["day"], e["role"]], "lie": true}])
		if sg != "" and sg != l.id and w.by_id[sg].alive:
			var fs = Evil.fake_night_sighting(w, s, w.day - 1)
			if fs != null and not _told(s, l, "sighting:%s:%d" % [sg, fs["day"]]):
				cands.append([gos * 0.8, {"kind": "sighting", "about": sg, "block": fs["block"], "day": fs["day"],
					"from": s.id, "key": "sighting:%s:%d" % [sg, fs["day"]], "lie": true}])
			if not _told(s, l, "opinion:" + sg) and Evil.public_heat(w, w.by_id[sg]) >= 0.3:
				cands.append([gos * 0.6 + (trait_of(s, "confidence") - 0.5) * 0.4, {"kind": "opinion", "about": sg, "why": Evil.bluff_reason(w, s, w.by_id[sg]), "from": s.id,
					"key": "opinion:" + sg, "lie": true}])
	else:
		for e in s.info_log:
			var key = "reading:%d:%s" % [e["day"], e["role"]]
			if not e["shared"] and not _told(s, l, key):
				var wgt = (1.0 - priv) * 1.2 * maxf(0.0, bond - 0.3) * 2.0 + 0.3 * s.pressure
				cands.append([wgt, {"kind": "reading", "entry": e, "about": "", "from": s.id, "key": key}])
		if not s.secret.is_empty() and not l.known_secrets.has(s.id):
			cands.append([(1.0 - priv) * maxf(0.0, bond - 0.6) * 3.0, {"kind": "secret", "about": s.id, "from": s.id, "key": "secret:" + s.id}])
		var ranked = Mind.ranked_suspects(w, s).filter(func(m): return m != l)
		if not ranked.is_empty() and Mind.susp(s, ranked[0].id) >= 0.5 and not _told(s, l, "opinion:" + ranked[0].id):
			var t = ranked[0]
			cands.append([gos * 0.6 + (trait_of(s, "confidence") - 0.5) * 0.4, {"kind": "opinion", "about": t.id,
				"why": Mind.citable_reason(w, s, t.id, "town"), "from": s.id, "key": "opinion:" + t.id}])
		for c in s.player_cases.slice(-2):
			var about: String = c["suspect"]
			if about != l.id and not _told(s, l, "case:" + c["card"]["text"]):
				cands.append([gos * 0.5, {"kind": "case", "about": about, "card": c["card"], "from": "player", "key": "case:" + c["card"]["text"]}])
	# Things anyone might pass on: what they saw at night, what they've heard, others' secrets.
	for b in s.beliefs:
		if b["kind"] == "saw" and b["phase"] == C.NIGHT and b["day"] >= w.day - 2 and b["who"] != l.id and w.by_id[b["who"]].alive:
			if s.is_evil() and w.by_id[b["who"]].is_evil():
				continue
			var key2 = "sighting:%s:%d" % [b["who"], b["day"]]
			if _told(s, l, key2):
				continue
			var scene = 0.0
			for sid in w.scenes:
				if w.scenes[sid]["day"] == b["day"] and w.scenes[sid]["block"] == b["block"]:
					scene = 0.4
			cands.append([gos * 0.8 + scene, {"kind": "sighting", "about": b["who"], "block": b["block"], "day": b["day"], "from": s.id, "key": key2}])
	for h in s.hearsay.slice(-4):
		if h["from"] == l.id or h.get("about", "") == l.id or h["kind"] == "secret":
			continue
		if s.is_evil() and h.get("about", "") != "" and w.by_id[h["about"]].is_evil():
			continue
		var key3 = "relay:" + h["key"]
		if _told(s, l, key3):
			continue
		var r = h.duplicate()
		r["key"] = key3
		r["relay"] = true
		cands.append([gos * 0.45, r])
	for owner in s.known_secrets:
		if owner == l.id or owner == s.id or l.known_secrets.has(owner):
			continue
		cands.append([gos * 0.4 * (1.3 - trait_of(s, "composure")), {"kind": "secret", "about": owner, "from": owner, "key": "secret:" + owner, "relay": true}])
	if cands.is_empty():
		return null
	var total = 0.3  # chance they just talk about the weather
	for c in cands:
		total += maxf(c[0], 0.0)
	var r2 = w.rng.randf() * total
	for c in cands:
		r2 -= maxf(c[0], 0.0)
		if r2 <= 0:
			return c[1]
	return null

static func _deliver(w, s, l, item: Dictionary) -> void:
	_mark(s, l, item["key"])
	var lie: bool = item.get("lie", false)
	var desc = _describe(w, s, item)
	w.dlog.add("npc_share", s.id, l.id, {"kind": item["kind"], "about": item.get("about", ""), "from": item.get("from", ""),
		"relay": item.get("relay", false), "lie": lie}, "%s tells %s: %s%s" % [s.name, l.name, desc, "  [LIE]" if lie else ""])
	if lie:
		w.dlog.think(s.id, "lie", "Evil: tells %s %s." % [l.name, desc], {"lie": true})
	if l.is_evil():
		Evil.intel_from_share(w, l, s, item)
		if item["kind"] == "secret":
			l.known_secrets[item["about"]] = s.id
		return
	# Repeats are handled by the listener's ledger (same reading never stacks).
	# The teller's credibility is applied live by the listener's ledger (rel = the source).
	var wgt = clampf(0.75 * l.npc_trust.get(s.id, 0.5), 0.0, 0.55)
	var times: int = l.heard.get(item["key"].trim_prefix("relay:"), 0)
	l.heard[item["key"].trim_prefix("relay:")] = times + 1
	var hs = item.duplicate()
	hs["via"] = s.id
	hs["day_heard"] = w.day
	hs["key"] = item["key"].trim_prefix("relay:")
	match item["kind"]:
		"reading":
			var e: Dictionary = item["entry"]
			var src = w.by_id[item["from"]]
			Mind.apply_info(w, l, src, e, wgt)
			if not l.known_claims.has(src.id):
				l.known_claims[src.id] = {"role": e["role"], "readings": [], "via": s.id}
			Mind.hear_claim(w, l, src.id, e["role"], wgt, "relayed")
			if not (e in l.known_claims[src.id]["readings"]):
				l.known_claims[src.id]["readings"].append(e)
			l.hearsay.append(hs)
		"sighting":
			var sc = Mind.night_sighting_scale(w, l, item["about"], item.get("block", ""), item.get("day", -1))
			var e1: Array = []
			Mind._eff(e1, item["about"], 0.4 * sc, "heard from %s that %s was out at night (x%.2f)" % [s.id, item["about"], sc],
				"%s says they were out at night" % s.name)
			Mind.ledger_hear(w, l, "heard:" + hs["key"], e1, wgt * 2.0, [s.id, item.get("day", -1), "report"])
			l.hearsay.append(hs)
		"opinion":
			var e2: Array = []
			Mind._eff(e2, item["about"], 0.12, "%s told me they distrust %s" % [s.id, item["about"]], "%s has doubts about them" % s.name)
			Mind.ledger_hear(w, l, "opinion:%s>%s" % [s.id, item["about"]], e2, wgt * 2.0, [s.id, -1, "report"])
			l.hearsay.append(hs)
		"case":
			var e3: Array = []
			Mind._eff(e3, item["about"], 0.1, "heard the Demonologist's case against %s via %s" % [item["about"], s.id],
				"the Demonologist has a case against them")
			Mind.ledger_hear(w, l, "relayed-case:%s>%s" % [Mind.fact_id(item["card"]), item["about"]], e3, wgt * 2.0)
			l.hearsay.append(hs)
		"secret":
			var owner = w.by_id[item["about"]]
			l.known_secrets[owner.id] = s.id
			if owner != s:
				owner.secret_spread_by_npc = true
	l.npc_trust[s.id] = clampf(l.npc_trust.get(s.id, 0.5) + 0.02, 0.0, 1.0)

static func _describe(w, s, item: Dictionary) -> String:
	var src = item.get("from", "")
	var via = ""
	if item.get("relay", false) and src != s.id and w.by_id.has(src):
		via = " (heard from %s)" % w.by_id[src].name
	match item["kind"]:
		"reading":
			return "their %s reading: %s%s" % [C.role_name(item["entry"]["role"]), item["entry"]["text"], via]
		"sighting":
			return "%s was out on %s on night %d%s" % [w.by_id[item["about"]].name, C.block_name(item["block"]), item["day"], via]
		"opinion":
			return "they distrust %s%s" % [w.by_id[item["about"]].name, via]
		"case":
			return "the Demonologist's case against %s" % w.by_id[item["about"]].name
		"secret":
			var o = w.by_id[item["about"]]
			return "%s's secret: %s %s" % [o.name, o.name, o.secret.get("text", "?")]
	return item["kind"]

## Evil members in the same crowded tavern can pass word unobserved (slow, partial).
static func tavern_whispers(w) -> void:
	if w.npcs_at("tavern").size() < 4:
		return
	var here: Array = w.evil_team().filter(func(x): return x.loc == "tavern" and x.busy_with == "")
	for i in range(here.size()):
		for j in range(i + 1, here.size()):
			var d = here[i]
			var m = here[j]
			if Evil.unshared_intel(d, m) + Evil.unshared_intel(m, d) > 0 and w.chance(0.5):
				Evil.share_intel(w, d, m, "whisper in the crowded tavern")

# ---------------------------------------------------------------- paranoia

static func paranoia_drift(w) -> void:
	for n in w.living_good():
		var p = Mind.paranoia(w, n)
		if p <= 0.0:
			continue
		for m in w.living():
			if m != n and not n.cleared.has(m.id):
				if n.workshop_state.get("active", false):
					Mind.adjust(w, n, m.id, 0.06 * p, "paranoia drift", "", false)
				else:
					n.suspicion[m.id] = clampf(n.suspicion[m.id] + 0.06 * p, 0.0, 1.5)
		w.dlog.think(n.id, "paranoia", "Paranoia %.2f: everyone left alive looks a little more suspect." % p)

# ---------------------------------------------------------------- approaches

## Pick an NPC who wants a word with the player at the start of a phase, or null.
static func approach_candidate(w):
	if not w.chance(0.4):
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
				if not n.info_log[i]["shared"]:
					fresh += 1
			if fresh > 0 and n.trust >= 0.5 and sg != "" and w.by_id[sg].alive:
				s = (1.0 - trait_of(n, "privacy")) + n.trust - 0.6
				a = "frame"
		else:
			var unshared = n.info_log.size() - n.told_readings
			var hidden_new = 0
			for i in range(n.told_readings, n.info_log.size()):
				if not n.info_log[i]["shared"]:
					hidden_new += 1
			if hidden_new > 0 and n.trust >= 0.5 and unshared > 0:
				s = (1.0 - trait_of(n, "privacy")) + n.trust - 0.6
				a = "news"
		if gos >= 0.6 and has_gossip(w, n):
			var gs = gos - 0.3
			if gs > s:
				s = gs
				a = "gossip"
		s += w.rng.randf() * 0.2
		if s > best_s:
			best_s = s
			best = n
			agenda = a
	if best == null or best_s < 0.35:
		return null
	w.dlog.think(best.id, "approach", "Seeks out the Demonologist (agenda: %s, score %.2f)." % [agenda, best_s], {"agenda": agenda})
	return {"npc": best, "agenda": agenda}

## What they open with once the player accepts. Returns {lines, facts}.
static func approach_open(w, n, agenda: String) -> Dictionary:
	var lines: Array = []
	var facts: Array = []
	match agenda:
		"news", "frame":
			var r: Dictionary = Mind.answer_gift(w, n, 4)
			n.pressed_today -= 1
			lines.append(Mind.say(n, "I've been meaning to find you."))
			lines += r["lines"]
			facts += r["facts"]
			if agenda == "frame":
				var sg = w.by_id[w.evil_plan["scapegoat"]]
				var why = Evil.cite(w, n, Evil.bluff_reason(w, n, sg))
				w.dlog.think(n.id, "lie", "Evil: approaches the player to push scapegoat %s." % sg.id)
				lines.append(Mind.say(n, "And keep an eye on %s. %s" % [sg.name,
					(why[0].to_upper() + why.substr(1) + ".") if why != "" else "Something's off about them."]))
				facts.append({"kind": "opinion", "subject": [sg.id], "source": n.id, "text": "%s warned you about %s." % [n.name, sg.name]})
		"gossip":
			lines.append(Mind.say(n, "You'll want to hear this."))
			var g = gossip_item(w, n)
			lines += g["lines"]
			facts += g["facts"]
	return {"lines": lines, "facts": facts}

## Gossip the player hasn't heard from them, and that the whole town didn't already hear:
## a known secret, or a relayed reading or sighting. Returns [kind, owner/index] or [].
static func _gossip_items(w, n) -> Array:
	var out: Array = []
	for owner in n.known_secrets:
		if owner != n.id and w.by_id[owner].alive and not n.told_to.has("player|secret:" + owner):
			out.append(["secret", owner])
	for i in range(n.hearsay.size() - 1, -1, -1):
		var h: Dictionary = n.hearsay[i]
		if n.told_to.has("player|hs:%d" % i):
			continue
		if h["kind"] == "reading" and w.by_id.has(h["from"]) and not h["entry"].get("shared", false):
			out.append(["hearsay", i])
		elif h["kind"] == "sighting" and w.by_id.has(h["about"]):
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
		if w.chance(0.5 + 0.3 * trait_of(n, "gossip")):
			n.told_to["player|secret:" + owner] = true
			w.dlog.think(n.id, "gossip", "Tells the player %s's secret (heard via %s)." % [owner, n.known_secrets[owner]])
			o.secret_spread_by_npc = true
			return {"lines": [Mind.say(n, "Between you and me, %s %s. That's why they're about at night." % [o.name, o.secret["text"]])],
				"facts": [{"kind": "secret", "subject": [owner], "owner": owner, "source": n.id, "via": n.known_secrets[owner],
					"text": "%s told you %s's secret: %s %s." % [n.name, o.name, o.name, o.secret["text"]]}]}
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
			return {"lines": [Mind.say(n, "%s told me their gift is %s, and that %s." % [src.name, C.role_name(e["role"]), C.third_person(e["text"])])], "facts": [f]}
		if h["kind"] == "sighting":
			var who = w.by_id[h["about"]]
			var by = w.by_id[h["from"]].name if w.by_id.has(h["from"]) else "someone"
			return {"lines": [Mind.say(n, "%s says %s was out on %s on night %d." % [by, who.name, C.block_name(h["block"]), h["day"]])],
				"facts": [{"kind": "sighting", "subject": [who.id], "block": h["block"], "day": h["day"], "phase": C.NIGHT, "source": h["from"], "via": n.id,
					"text": "Via %s: %s saw %s on %s on night %d." % [n.name, by, who.name, C.block_name(h["block"]), h["day"]]}]}
	return {"lines": [Mind.say(n, "...Well, I thought I had something. The price of bread, mostly.")], "facts": []}

# ---------------------------------------------------------------- asking about a role

static func answer_about_role(w, n, role: String) -> Dictionary:
	Mind.on_question(w, n)
	var lines: Array = []
	var facts: Array = []
	var rn = C.role_name(role)
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	if mine == role and (n.claim_public or n.max_tier >= 3):
		lines.append(Mind.say(n, "That would be me."))
		return {"lines": lines, "facts": facts}
	# A general question about the town, but it touches their own gift: a small chance they
	# own up (likelier the more they trust you). Otherwise they answer like anyone else.
	if mine == role:
		var p = 0.15 + 0.2 * n.trust
		var out = w.rng.randf() < p
		w.dlog.think(n.id, "about_role", "Asked who holds their own gift (%s): owns up? -> %s (p=%.2f)." % [role, "yes" if out else "no", p])
		if out:
			n.pressed_today -= 1  # answer_gift counts the question again
			return Mind.answer_gift(w, n, maxi(2, Mind._target_tier(w, n)))
	var public: Array = w.public_claims.filter(func(c): return c["role"] == role and w.by_id[c["who"]].alive).map(func(c): return w.by_id[c["who"]].name)
	var text = ""
	if not public.is_empty():
		text = "Everyone heard %s claim the %s." % [" and ".join(PackedStringArray(public)), rn]
	var willing = trait_of(n, "gossip") * 0.7 + n.trust * 0.5 + n.pressure * 0.3 > 0.55
	var told = false
	if not n.is_evil() and willing:
		for sid in n.known_claims:
			var kc: Dictionary = n.known_claims[sid]
			var who = w.by_id[sid]
			if kc["role"] != role or who.claim_public:
				continue
			told = true
			text += (" " if text != "" else "") + "Between us, %s told %s they're the %s." % [who.name, "me" if kc["via"] == sid else w.by_id[kc["via"]].name, rn]
			facts.append({"kind": "claim", "subject": [sid], "role": role, "source": sid, "via": n.id, "private": true,
				"text": "Via %s: %s privately claims to be the %s." % [n.name, who.name, rn]})
			for e in kc["readings"]:
				text += " They said %s." % e["text"]
				var f = Mind.info_fact(w, who, e)
				f["via"] = n.id
				f["text"] = "Via %s: " % n.name + f["text"]
				facts.append(f)
		w.dlog.think(n.id, "about_role", "Asked about the %s: shares private knowledge (willing)." % role if told else "Asked about the %s: knows nothing private." % role)
	elif not willing:
		w.dlog.think(n.id, "about_role", "Asked about the %s: not willing to share private knowledge." % role)
	if text == "":
		text = "I couldn't tell you who the %s is." % rn if willing or n.is_evil() else "That's not for me to say."
	lines.append(Mind.say(n, text))
	return {"lines": lines, "facts": facts}

## "Are you the <gift>?": a direct guess at the listener's own gift. Right, they own up a
## little more readily than usual (only for the first guess you put to them, so going down
## the list doesn't pay). Wrong, or unwilling, they give the same non-answer either way, so
## a guess never eliminates anyone, and each wrong guess costs a little more trust.
static func answer_is_role(w, n, role: String) -> Dictionary:
	Mind.on_question(w, n)
	var rn = C.role_name(role)
	var mine: String = w.evil_plan["bluffs"][n.id] if n.is_evil() else n.role
	var said: bool = n.claim_public or n.max_tier >= 3
	if said:
		var claimed: String = n.claimed_role
		if claimed == role:
			return {"lines": [Mind.say(n, "I am. I've said as much.")], "facts": []}
		return {"lines": [Mind.say(n, "No. I told you: I'm the %s." % C.role_name(claimed) if C.ROLES.has(claimed) else "No.")], "facts": []}
	if mine == role:
		var first = n.role_guesses == 0
		var tier: int = Mind._target_tier(w, n) + (1 if first and w.rng.randf() < 0.5 else 0)
		w.dlog.think(n.id, "about_role", "Asked if they are the %s (right): disclosure tier %d%s." % [role, tier,
			"" if first else " (no bonus: you guessed wrong before)"])
		if tier >= 2:
			n.pressed_today -= 1  # answer_gift counts the question again
			return Mind.answer_gift(w, n, mini(tier, 4))
	else:
		n.role_guesses += 1
		var cost = 0.02 * n.role_guesses
		Mind.set_trust(w, n, n.trust - cost, "the Demonologist guessed my gift wrong (%s; %d wrong so far)" % [role, n.role_guesses])
		w.dlog.think(n.id, "about_role", "Asked if they are the %s (wrong): gives the usual non-answer." % role)
	var line = "Why do you keep asking me that?" if n.role_guesses >= 3 else "What my gift is, I'll keep to myself."
	return {"lines": [Mind.say(n, line)], "facts": []}
