## Case-building (stage 3): card assertions, the contradiction template library,
## conclusions, and how NPCs weigh the player's arguments.
##
## A card carries assertions (small typed facts). Linking cards runs every template over
## every pair of assertions from different cards. A match lists possible explanations; the
## player picks one, which becomes a conclusion (a "deduction" card). NPCs judge a
## conclusion by weighing the same explanations from their own point of view.
extends RefCounted

const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")

const CONCLUSION_TYPES = ["evil", "demon", "good", "role", "notrole", "lied", "poisoned", "protect", "spare", "mistaken"]

# ---------------------------------------------------------------- assertions

static func assertions(card: Dictionary) -> Array:
	var out: Array = []
	var k: String = card.get("kind", "")
	var src: String = card.get("source", "")
	var subj: Array = card.get("subject", [])
	var day: int = card.get("day", -1)
	var ph: int = card.get("phase", -1)
	var n: int = card.get("n", 0)
	match k:
		"sighting":
			if ph == C.NIGHT:
				if card.get("vigil", false):
					out.append({"t": "vigil", "block": card["block"], "night": day, "seen": subj, "src": src, "card": n})
					for who in subj:
						out.append({"t": "out", "who": who, "block": card["block"], "night": day, "src": src, "card": n})
				else:
					for who in subj:
						out.append({"t": "out", "who": who, "block": card["block"], "night": day, "src": src, "card": n})
			else:
				for who in subj:
					out.append({"t": "at", "who": who, "block": card.get("block", ""), "day": day, "phase": ph, "src": src, "card": n})
		"vigil":
			out.append({"t": "vigil", "block": card["block"], "night": day, "seen": [], "src": src, "card": n})
		"secret":
			if card.has("block"):
				out.append({"t": "out", "who": card["owner"], "block": card["block"], "night": day, "src": src, "card": n})
		"alibi":
			out.append({"t": "home", "who": subj[0], "night": day, "src": src, "card": n})
		"claim":
			var role: String = card.get("role", "")
			if role != "":
				out.append({"t": "claim", "who": subj[0], "role": role, "src": src, "card": n})
		"info":
			var d: Dictionary = card.get("data", {})
			var role2: String = card.get("role", "")
			out.append({"t": "reading", "src": src, "role": role2, "night": day, "data": d, "card": n})
			if role2 == "nightwatch":
				out.append({"t": "watch", "who": src, "block": d["block"], "night": day, "seen": d["seen"], "src": src, "card": n})
				out.append({"t": "out", "who": src, "block": d["block"], "night": day, "src": src, "card": n})
			if role2 == "gravedigger":
				out.append({"t": "was_role", "who": d["executed"], "role": d["role"], "src": src, "night": day, "card": n})
		"death":
			out.append({"t": "killed", "who": subj[0], "night": card.get("night", day - 1), "src": src, "card": n})
	return out

# ---------------------------------------------------------------- templates

static func _nm(w, id: String) -> String:
	return w.by_id[id].name if w.by_id.has(id) else id

static func _is_npc(w, id: String) -> bool:
	return w.by_id.has(id)

static func _lied(w, who: String, card: int) -> Dictionary:
	return {"kind": "lied", "label": "%s lied (card #%d)" % [_nm(w, who), card], "blame": who, "card": card,
		"conclusion": {"type": "lied", "a": who, "card": card}}

static func _poisoned(w, who: String, night: int) -> Dictionary:
	return {"kind": "poisoned", "label": "%s was poisoned on night %d" % [_nm(w, who), night], "blame": who,
		"conclusion": {"type": "poisoned", "a": who, "night": night}}

static func _notrole(w, who: String, role: String) -> Dictionary:
	return {"kind": "notrole", "label": "%s isn't really the %s" % [_nm(w, who), C.role_name(role)], "blame": who,
		"conclusion": {"type": "notrole", "a": who, "role": role}}

static func _mistaken(w, card: int, who: String) -> Dictionary:
	return {"kind": "mistaken", "label": "card #%d is mistaken (hearsay)" % card, "blame": who, "card": card,
		"conclusion": {"type": "mistaken", "a": who, "card": card}}

static func _when(a: Dictionary) -> String:
	if a.has("night"):
		return "night %d" % a["night"]
	return "day %d %s" % [a["day"], C.PHASES[a["phase"]].to_lower()]

## Run every template over every pair of assertions from different cards.
## Returns {matches: [...], near: [reason, ...]}.
static func check(w, cards: Array) -> Dictionary:
	var asserts: Array = []
	for c in cards:
		asserts += assertions(c)
	var matches: Array = []
	var near: Array = []
	var killed = {}
	for a in asserts:
		if a["t"] == "killed":
			killed[a["who"]] = a["night"]
	for i in range(asserts.size()):
		for j in range(asserts.size()):
			if i == j:
				continue
			var a: Dictionary = asserts[i]
			var b: Dictionary = asserts[j]
			if a["card"] == b["card"]:
				continue
			var m = _match_pair(w, a, b, near)
			if m != null:
				matches.append(m)
	for a in asserts:
		var m2 = _match_dead(w, a, killed)
		if m2 != null:
			matches.append(m2)
	# Deduplicate by template + cards.
	var seen = {}
	var uniq: Array = []
	for m in matches:
		var key = m["template"] + ":" + str(m["cards"])
		if seen.has(key):
			continue
		seen[key] = true
		for i in range(m["explanations"].size()):
			m["explanations"][i]["id"] = i + 1
		uniq.append(m)
	var near_u: Array = []
	for r in near:
		if not (r in near_u):
			near_u.append(r)
	return {"matches": uniq, "near": near_u}

static func _place_expls(w, a: Dictionary, b: Dictionary) -> Array:
	var ex: Array = []
	for s in [a, b]:
		if _is_npc(w, s["src"]):
			ex.append(_lied(w, s["src"], s["card"]))
	return ex

static func _match_pair(w, a: Dictionary, b: Dictionary, near: Array):
	var ta: String = a["t"]
	var tb: String = b["t"]
	var cards: Array = [a["card"], b["card"]]
	cards.sort()
	# Two places at once (day).
	if ta == "at" and tb == "at" and a["who"] == b["who"] and a["block"] != b["block"] and a["card"] < b["card"]:
		if a["day"] == b["day"] and a["phase"] == b["phase"]:
			return _mk(w, "two_places", "%s can't have been on both %s and %s on %s." %
				[_nm(w, a["who"]), C.block_name(a["block"]), C.block_name(b["block"]), _when(a)], cards, _place_expls(w, a, b), a["who"], [a, b])
		near.append("cards #%d and #%d are about %s at different times (%s vs %s)." % [a["card"], b["card"], _nm(w, a["who"]), _when(a), _when(b)])
	# Two places at once (night), or out vs home.
	if ta == "out" and tb == "out" and a["who"] == b["who"] and a["block"] != b["block"] and a["card"] < b["card"]:
		if a["night"] == b["night"]:
			return _mk(w, "two_places", "%s can't have been out on both %s and %s on night %d." %
				[_nm(w, a["who"]), C.block_name(a["block"]), C.block_name(b["block"]), a["night"]], cards, _place_expls(w, a, b), a["who"], [a, b])
		near.append("cards #%d and #%d are about %s on different nights (%d vs %d)." % [a["card"], b["card"], _nm(w, a["who"]), a["night"], b["night"]])
	if ta == "out" and tb == "home" and a["who"] == b["who"]:
		if a["night"] == b["night"]:
			return _mk(w, "out_vs_home", "%s says they were home on night %d, but card #%d puts them out on %s." %
				[_nm(w, a["who"]), a["night"], a["card"], C.block_name(a["block"])], cards, _place_expls(w, a, b), a["who"], [a, b])
		near.append("cards #%d and #%d are about %s on different nights (%d vs %d)." % [a["card"], b["card"], _nm(w, a["who"]), a["night"], b["night"]])
	# Double claim / changed story.
	if ta == "claim" and tb == "claim" and a["card"] < b["card"]:
		if a["who"] != b["who"] and a["role"] == b["role"] and a["role"] in C.GOOD_ROLES:
			return _mk(w, "double_claim", "%s and %s both claim to be the %s." % [_nm(w, a["who"]), _nm(w, b["who"]), C.role_name(a["role"])],
				cards, [_notrole(w, a["who"], a["role"]), _notrole(w, b["who"], a["role"])], "", [a, b])
		if a["who"] == b["who"] and a["role"] != b["role"]:
			var ex: Array = []
			for s in [a, b]:
				if s["role"] != "none":
					ex.append(_notrole(w, s["who"], s["role"]))
				ex.append(_lied(w, s["who"], s["card"]))
			return _mk(w, "changed_story", "%s has claimed both %s and %s." % [_nm(w, a["who"]), C.role_name(a["role"]), C.role_name(b["role"])],
				cards, ex, a["who"], [a, b])
	# Watcher's omission: a watch report misses someone placed on that block that night.
	if ta == "watch" and tb == "out" and b["who"] != a["who"] and b["src"] != a["src"]:
		if a["block"] == b["block"] and a["night"] == b["night"]:
			if not (b["who"] in a["seen"]):
				var ex2: Array = [_lied(w, a["src"], a["card"]), _poisoned(w, a["src"], a["night"])]
				if _is_npc(w, b["src"]):
					ex2.append(_lied(w, b["src"], b["card"]))
				return _mk(w, "watch_omission", "%s watched %s on night %d and didn't report %s, but card #%d puts %s there." %
					[_nm(w, a["src"]), C.block_name(a["block"]), a["night"], _nm(w, b["who"]), b["card"], _nm(w, b["who"])], cards, ex2, "", [a, b])
		elif a["block"] == b["block"]:
			near.append("cards #%d and #%d are about different nights (%d vs %d)." % [a["card"], b["card"], a["night"], b["night"]])
		elif a["night"] == b["night"]:
			near.append("card #%d is about %s, but card #%d is about %s." % [a["card"], C.block_name(a["block"]), b["card"], C.block_name(b["block"])])
	# Your vigil saw everyone who moved through a block.
	if ta == "vigil" and tb == "out" and a["block"] == b["block"] and a["night"] == b["night"] and not (b["who"] in a["seen"]) and _is_npc(w, b["src"]):
		return _mk(w, "vigil_miss", "Your vigil on %s on night %d saw no sign of %s, but card #%d puts them there." %
			[C.block_name(a["block"]), a["night"], _nm(w, b["who"]), b["card"]], cards, [_lied(w, b["src"], b["card"])], b["who"], [a, b])
	if ta == "vigil" and tb == "watch" and a["block"] == b["block"] and a["night"] == b["night"]:
		var missing: Array = a["seen"].filter(func(x): return x != b["who"] and not (x in b["seen"]))
		if not (b["who"] in a["seen"]):
			return _mk(w, "vigil_watcher", "%s claims to have watched %s on night %d, but your vigil there never saw them." %
				[_nm(w, b["who"]), C.block_name(a["block"]), a["night"]], cards, [_lied(w, b["who"], b["card"])], b["who"], [a, b])
		if not missing.is_empty():
			return _mk(w, "watch_omission", "Your vigil saw %s on %s on night %d, but %s's watch didn't report them." %
				[", ".join(PackedStringArray(missing.map(func(x): return _nm(w, x)))), C.block_name(a["block"]), a["night"], _nm(w, b["who"])],
				cards, [_lied(w, b["who"], b["card"]), _poisoned(w, b["who"], b["night"])], "", [a, b])
	# Same gift, same question, different answer.
	if ta == "reading" and tb == "reading" and a["src"] == b["src"] and a["role"] == b["role"] and a["card"] < b["card"]:
		var da: Dictionary = a["data"]
		var db: Dictionary = b["data"]
		var flip = false
		var what = ""
		if a["role"] == "seer":
			var pa: Array = da["pair"].duplicate()
			var pb: Array = db["pair"].duplicate()
			pa.sort()
			pb.sort()
			if pa == pb and da["yes"] != db["yes"]:
				flip = true
				what = "the same two people"
			elif da["yes"] != db["yes"] and pa != pb:
				near.append("cards #%d and #%d looked at different pairs, so they can both be true." % [a["card"], b["card"]])
		elif a["role"] == "hearthwitch":
			var na: Array = da["nbrs"].duplicate()
			var nb: Array = db["nbrs"].duplicate()
			na.sort()
			nb.sort()
			if na == nb and da["count"] != db["count"]:
				flip = true
				what = "the same neighbours"
			elif da["count"] != db["count"]:
				near.append("cards #%d and #%d are about different neighbours (someone died in between)." % [a["card"], b["card"]])
		if flip:
			return _mk(w, "reading_flip", "%s's %s gave different answers about %s on nights %d and %d." %
				[_nm(w, a["src"]), C.role_name(a["role"]), what, a["night"], b["night"]], cards,
				[_poisoned(w, a["src"], a["night"]), _poisoned(w, a["src"], b["night"]), _lied(w, a["src"], b["card"])], "", [a, b])
	# Gravedigger vs a claim.
	if ta == "was_role" and tb == "claim" and a["who"] == b["who"] and b["role"] != a["role"] and b["role"] != "none":
		return _mk(w, "grave_vs_claim", "%s claimed the %s, but %s says they were the %s." %
			[_nm(w, b["who"]), C.role_name(b["role"]), _nm(w, a["src"]), C.role_name(a["role"])], cards,
			[_notrole(w, b["who"], b["role"]), _lied(w, a["src"], a["card"]), _poisoned(w, a["src"], a["night"])], "", [a, b])
	# A Veteran can't die to the demon (unless poisoned).
	if ta == "claim" and tb == "killed" and a["who"] == b["who"] and a["role"] == "veteran":
		return _mk(w, "veteran_died", "%s claimed the Veteran, but the demon killed them on night %d." % [_nm(w, a["who"]), b["night"]], cards,
			[_notrole(w, a["who"], "veteran"), _poisoned(w, a["who"], b["night"])], "", [a, b])
	return null

## A reading that points only at people the demon has since killed.
static func _match_dead(w, a: Dictionary, killed: Dictionary):
	if a["t"] != "reading" or killed.is_empty():
		return null
	var d: Dictionary = a["data"]
	var named: Array = []
	match a["role"]:
		"seer":
			if d["yes"]:
				named = d["pair"]
		"archivist":
			named = d["pair"]
		"hearthwitch":
			if d["count"] > 0:
				var alive_n: Array = d["nbrs"].filter(func(x): return not killed.has(x))
				if alive_n.size() < d["count"]:
					named = d["nbrs"]
	if named.is_empty():
		return null
	for x in named:
		if not killed.has(x):
			return null
	var cards: Array = [a["card"]]
	return _mk(w, "reading_vs_dead", "%s's %s reading pointed only at people the demon has since killed (%s)." %
		[_nm(w, a["src"]), C.role_name(a["role"]), ", ".join(PackedStringArray(named.map(func(x): return _nm(w, x))))], cards,
		[_poisoned(w, a["src"], a["night"]), _lied(w, a["src"], a["card"])], "", [a])

static func _mk(w, template: String, text: String, cards: Array, expls: Array, subject: String, asserts: Array) -> Dictionary:
	for e in expls:
		for s in asserts:
			if s["card"] == e.get("card", -1):
				e["assert"] = s
	return {"template": template, "text": text, "cards": cards, "explanations": expls, "subject": subject}

# ---------------------------------------------------------------- conclusions

static func conclusion_text(w, c: Dictionary) -> String:
	var a = _nm(w, c.get("a", ""))
	match c["type"]:
		"evil":
			return "%s is evil" % a
		"demon":
			return "%s is the demon" % a
		"good":
			return "%s is good" % a
		"role":
			return "%s is the %s" % [a, C.role_name(c["role"])]
		"notrole":
			return "%s isn't the %s" % [a, C.role_name(c["role"])]
		"lied":
			return "%s lied (card #%d)" % [a, c["card"]]
		"poisoned":
			return "%s was poisoned on night %d" % [a, c["night"]]
		"protect":
			return "%s should be protected" % a
		"spare":
			return "%s shouldn't be executed" % a
		"mistaken":
			return "card #%d is mistaken" % c["card"]
	return c["type"]

# ---------------------------------------------------------------- evaluation

static func _cred(w, n, src: String) -> float:
	if src == "player":
		return 1.0
	if src == "evidence":
		return 0.9
	if src == n.id:
		return 1.0
	if w.by_id.has(src):
		return clampf(0.9 - Mind.susp(n, src), 0.1, 0.9)
	return 0.5

static func _class_w(n, cls: String) -> float:
	var ins = n.traits.get("insight", 0.5)
	return {"speech": lerpf(1.0, 0.2, ins), "circumstantial": lerpf(1.0, 0.6, ins), "concrete": 1.0}.get(cls, 0.6)

static func _quality(w, n, supports: Array) -> float:
	if supports.is_empty():
		return 0.3
	var q = 0.0
	for c in supports:
		q += _cred(w, n, c.get("source", "")) * _class_w(n, c.get("class", "circumstantial"))
	return q / supports.size()

## Does this NPC know firsthand that an assertion about themselves is false?
static func _knows_false(w, n, s: Dictionary) -> int:
	if s.get("who", "") != n.id:
		return 0
	match s["t"]:
		"at":
			var where: String = n.history.get(w.time_key(s["day"], s["phase"]), "")
			if where == "":
				return 0
			return -1 if w.loc_block(where) == s["block"] else 1
		"out":
			var h: String = n.history.get(w.time_key(s["night"], C.NIGHT), "")
			if h == "":
				return 0
			return -1 if (h.begins_with("night:") and h.substr(6) == s["block"]) else 1
		"home":
			var h2: String = n.history.get(w.time_key(s["night"], C.NIGHT), "")
			if h2 == "":
				return 0
			return -1 if h2.begins_with("home:") else 1
	return 0

static func _expl_weight(w, n, e: Dictionary) -> float:
	var who: String = e.get("blame", "")
	if e.has("assert"):
		var k = _knows_false(w, n, e["assert"])
		if k == 1:
			return 3.0
		if k == -1:
			return 0.0
	match e["kind"]:
		"lied", "notrole":
			if who == n.id:
				return 0.0
			var base = 0.15 + Mind.susp(n, who) * 1.2 - (n.npc_trust.get(who, 0.5) - 0.5) * 0.5
			if Mind.known_good(w, who):
				base *= 0.3
			return maxf(base, 0.02)
		"poisoned":
			var t = w.by_id.get(who)
			return 0.25 + (0.1 if t != null and t.claim_public and t.claimed_role in C.INFO_ROLES else 0.0)
		"mistaken":
			return 0.2
	return 0.1

static func _support_strength(w, c: Dictionary, supports: Array) -> float:
	var a = w.by_id.get(c.get("a", ""))
	if a == null:
		return 0.2
	var s = 0.0
	match c["type"]:
		"evil", "demon", "lied", "notrole":
			for card in supports:
				var rel = 1.0 if a.id in card.get("subject", []) or card.get("source", "") == a.id else 0.3
				s += Mind.card_strength(w, card, a) * rel
			return clampf(s / 1.2, 0.0, 1.0)
		"good", "protect", "spare":
			for card in supports:
				s += Mind.defend_strength(card, a.id)
			return clampf(s, 0.0, 1.0)
		"poisoned":
			for card in supports:
				if card.get("kind", "") == "info" and card.get("source", "") == a.id and card.get("day", -1) == c.get("night", -2):
					return 0.5
			return 0.2
		"role":
			for card in supports:
				if card.get("kind", "") == "claim" and card.get("source", "") == a.id and card.get("role", "") == c.get("role", ""):
					return 0.5
			return 0.2
	return 0.2

## Undo some of the effect a reading had on this NPC (they now doubt it).
static func _discount_reading(w, n, card: Dictionary, amount: float) -> void:
	if card.get("kind", "") != "info" or not w.by_id.has(card.get("source", "")):
		return
	var key = "%s:%d" % [card["source"], card.get("day", -1)]
	var already: float = n.discounted.get(key, 0.0)
	var add = minf(amount, 0.6 - already)
	if add <= 0.01:
		return
	n.discounted[key] = already + add
	var entry = {"data": card.get("data", {}), "role": card.get("role", ""), "day": card.get("day", -1)}
	Mind.apply_info(w, n, w.by_id[card["source"]], entry, -add)

## One NPC weighs a deduction card. scale: 1.0 privately, 0.6 at the meeting.
static func evaluate(w, n, ded: Dictionary, board: Array, scale: float) -> Dictionary:
	var lines: Array = []
	var c: Dictionary = ded["conclusion"]
	var target = w.by_id.get(c.get("a", ""))
	var supports: Array = board.filter(func(x): return x["n"] in ded["supports"])
	var key: String = "ded:" + ded["text"]
	var times: int = n.heard.get(key, 0)
	n.heard[key] = times + 1
	var repeat = pow(0.35, times)
	var ins = n.traits.get("insight", 0.5)
	var weights = {}
	var agreement = 0.0
	var reason = ""
	if n.is_evil():
		if target != null and target.is_evil() and c["type"] in ["evil", "demon", "lied", "notrole"]:
			Evil.add_intel(w, n, "player_suspects", target.id, 0.0, "the Demonologist argues: %s" % conclusion_text(w, c))
		w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "evil": true}, "Evil hears the argument: %s" % ded["text"])
		if times > 0:
			lines.append(Mind.say(n, "You've told me that already."))
		elif target != null and target.id == w.evil_plan.get("scapegoat", ""):
			lines.append(Mind.say(n, "I've thought as much myself."))
		elif target != null and target.is_evil():
			lines.append(Mind.say(n, "Hm. I'd not be so sure."))
		else:
			lines.append(Mind.say(n, "Maybe so."))
		return {"lines": lines, "agreement": 0.0}
	if target == n and c["type"] in ["evil", "demon", "lied", "notrole"]:
		agreement = 0.0
		reason = "it's about me, and I know it's false"
		Mind.set_trust(w, n, n.trust - 0.05, "the Demonologist argued against me to my face")
	elif target == n:
		agreement = 1.0
	elif ded.get("template", "") != "":
		var total = 0.0
		for e in ded["explanations"]:
			var wt = _expl_weight(w, n, e)
			weights[e["id"]] = snappedf(wt, 0.01)
			total += wt
		# Chosen explanation against the strongest alternative.
		var mine: float = weights.get(ded["chosen"], 0.0)
		var rival = 0.0
		for e in ded["explanations"]:
			if e["id"] != ded["chosen"]:
				rival = maxf(rival, weights[e["id"]])
		agreement = mine / maxf(mine + rival, 0.01)
		if agreement < 0.35:
			var best = 0
			var best_w = -1.0
			for e in ded["explanations"]:
				if weights[e["id"]] > best_w:
					best_w = weights[e["id"]]
					best = e["id"]
			for e in ded["explanations"]:
				if e["id"] == best and best != ded["chosen"]:
					reason = "more likely %s" % e["label"]
	elif ded.get("unfounded", false):
		if w.rng.randf() < ins:
			agreement = 0.0
			reason = ded.get("near", "") if ded.get("near", "") != "" else "those don't contradict each other"
		else:
			agreement = 0.35 * (1.0 - ins) + 0.2 * n.trust
	else:
		agreement = _support_strength(w, c, supports)
		if ins >= 0.67 and agreement < 0.3:
			reason = "that's not enough to go on"
	var quality = _quality(w, n, supports)
	var m: float = agreement * quality * (0.5 + n.trust) * repeat * scale
	_apply(w, n, ded, supports, m)
	if agreement >= 0.6 and m >= 0.1:
		Mind.set_trust(w, n, n.trust + 0.02, "the Demonologist made a sound argument")
	w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "template": ded.get("template", ""), "chosen": ded.get("chosen", 0),
		"weights": weights, "agreement": snappedf(agreement, 0.01), "quality": snappedf(quality, 0.01), "repeat": snappedf(repeat, 0.01),
		"scale": scale, "effect": snappedf(m, 0.01)}, "%s weighs '%s': agreement %.2f, effect %.2f%s" %
		[n.name, ded["text"], agreement, m, (" (" + reason + ")") if reason != "" else ""])
	if times > 0:
		lines.append(Mind.say(n, "You've told me that already."))
	elif agreement >= 0.6 and m >= 0.1:
		lines.append(Mind.say(n, "That's sound. " + _paraphrase(w, c)))
	elif agreement >= 0.35:
		lines.append(Mind.say(n, "Maybe. I'll think on it."))
	elif reason != "":
		lines.append(Mind.say(n, "I don't buy it: %s." % reason))
	else:
		lines.append(Mind.say(n, "I don't buy it."))
	return {"lines": lines, "agreement": agreement}

static func _paraphrase(w, c: Dictionary) -> String:
	var a = _nm(w, c.get("a", ""))
	match c["type"]:
		"evil", "demon":
			return "I'll keep a close eye on %s." % a
		"good":
			return "I'll take %s off my list." % a
		"protect":
			return "I'll see %s is looked after." % a
		"spare":
			return "I'll not vote to hang %s." % a
		"poisoned":
			return "So %s's reading that night can't be trusted." % a
		"lied":
			return "So %s lied to us." % a
		"role":
			return "So %s is the %s." % [a, C.role_name(c["role"])]
		"notrole":
			return "So %s isn't really the %s." % [a, C.role_name(c["role"])]
		"mistaken":
			return "I'll not lean on that one."
	return ""

static func _apply(w, n, ded: Dictionary, supports: Array, m: float) -> void:
	if m <= 0.005:
		return
	var c: Dictionary = ded["conclusion"]
	var a: String = c.get("a", "")
	var why = "the Demonologist argued: %s" % ded["text"]
	match c["type"]:
		"evil":
			Mind.adjust(w, n, a, 0.45 * m, why, "the Demonologist made a case against them")
		"demon":
			Mind.adjust(w, n, a, 0.55 * m, why, "the Demonologist made a case against them")
		"good":
			Mind.adjust(w, n, a, -0.4 * m, why)
			n.protect_pref[a] = n.protect_pref.get(a, 0.0) + 0.5 * m
		"protect":
			n.protect_pref[a] = n.protect_pref.get(a, 0.0) + m
			Mind.adjust(w, n, a, -0.15 * m, why)
		"spare":
			n.spare_pref[a] = n.spare_pref.get(a, 0.0) + m
			Mind.adjust(w, n, a, -0.15 * m, why)
		"role":
			if m >= 0.12:
				n.believed_roles[a] = c["role"]
			Mind.adjust(w, n, a, -0.1 * m, why)
		"notrole":
			Mind.adjust(w, n, a, 0.3 * m, why, "the Demonologist showed their claim is false")
		"lied":
			Mind.adjust(w, n, a, 0.3 * m, why, "the Demonologist caught them in a lie")
			for card in supports:
				if card["n"] == c.get("card", -1):
					_discount_reading(w, n, card, 0.5 * m)
		"poisoned":
			for card in supports:
				if card.get("kind", "") == "info" and card.get("source", "") == a and card.get("day", -1) == c.get("night", -2):
					_discount_reading(w, n, card, 0.8 * m)
			w.dlog.think(n.id, "poison_belief", "Now doubts %s's reading from night %d (weight %.2f)." % [a, c.get("night", -1), m])
		"mistaken":
			for card in supports:
				if card["n"] == c.get("card", -1):
					_discount_reading(w, n, card, 0.3 * m)
