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

## Conclusion types. The player builds them as "<name> <is / is not / should be> <status>".
const CONCLUSION_TYPES = ["good", "evil", "demon", "notdemon", "role", "notrole", "lied", "truthful", "misled", "unreliable", "protect", "spare"]

## Builder vocabulary: verb -> [status, conclusion type] (role statuses are added per gift).
const BUILDER = {
	"is": [["good", "good"], ["evil", "evil"], ["the demon", "demon"], ["lying", "lied"], ["misled", "misled"], ["misled or lying", "unreliable"]],
	"is not": [["good", "evil"], ["evil", "good"], ["the demon", "notdemon"], ["lying", "truthful"]],
	"should be": [["protected", "protect"], ["spared from execution", "spare"]],
}

const RELATION_LEAD = {"contradiction": "These conflict:", "corroboration": "These agree:", "inference": "Put together:"}

## Old names kept working.
static func normalize(c: Dictionary) -> Dictionary:
	var t: String = c.get("type", "")
	if t == "poisoned" or t == "mistaken":
		c["type"] = "misled"
	return c

## Build a conclusion from builder pieces. Returns {} if the combination is invalid.
static func from_builder(who: String, verb: String, status: String, night: int = -1, card: int = -1) -> Dictionary:
	if C.ROLES.has(status) and status in C.GOOD_ROLES:
		if verb == "is":
			return {"type": "role", "a": who, "role": status}
		if verb == "is not":
			return {"type": "notrole", "a": who, "role": status}
		return {}
	for pair in BUILDER.get(verb, []):
		if pair[0] == status or pair[1] == status:
			var c = {"type": pair[1], "a": who}
			if pair[1] in ["misled", "unreliable"] and night >= 0:
				c["night"] = night
			if pair[1] in ["lied", "unreliable", "truthful"] and card > 0:
				c["card"] = card
			return c
	return {}

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
		"trace":
			out.append({"t": "trace", "block": card.get("block", ""), "day": day, "src": src, "card": n})
		"conversation":
			for who in subj:
				out.append({"t": "at", "who": who, "block": card.get("block", ""), "day": day, "phase": ph, "src": src, "card": n})
		"quiet":
			out.append({"t": "quiet", "night": card.get("night", day), "ward": card.get("ward", ""), "src": src, "card": n})
		"hint":
			if card.get("package", "") == "shelter":
				out.append({"t": "shelter_hint", "who": subj[0], "src": src, "card": n})
		"execution":
			# Hanged and the case went on: whoever it was, they weren't the demon.
			if not subj.is_empty():
				out.append({"t": "not_demon", "who": subj[0], "src": src, "card": n})
	return out

# ---------------------------------------------------------------- templates

static func _nm(w, id: String) -> String:
	return w.by_id[id].name if w.by_id.has(id) else id

static func _is_npc(w, id: String) -> bool:
	return w.by_id.has(id)

static func _lied(w, who: String, card: int) -> Dictionary:
	return {"kind": "lied", "label": "%s is lying (card #%d)" % [_nm(w, who), card], "blame": who, "card": card,
		"conclusion": {"type": "lied", "a": who, "card": card}}

static func _poisoned(w, who: String, night: int) -> Dictionary:
	return {"kind": "misled", "label": "%s is misled on night %d (poisoned or mistaken, not lying)" % [_nm(w, who), night], "blame": who,
		"conclusion": {"type": "misled", "a": who, "night": night}}

static func _notrole(w, who: String, role: String) -> Dictionary:
	return {"kind": "notrole", "label": "%s is not the %s" % [_nm(w, who), C.role_name(role)], "blame": who,
		"conclusion": {"type": "notrole", "a": who, "role": role}}

static func _mistaken(w, card: int, who: String) -> Dictionary:
	return {"kind": "misled", "label": "%s is misled (card #%d)" % [_nm(w, who), card], "blame": who, "card": card,
		"conclusion": {"type": "misled", "a": who, "card": card}}

static func _unreliable(w, who: String, night: int, card: int) -> Dictionary:
	var c = {"type": "unreliable", "a": who, "card": card}
	if night >= 0:
		c["night"] = night
	return {"kind": "unreliable", "label": "%s is misled or lying" % _nm(w, who), "blame": who, "card": card, "conclusion": c}

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
			if m == null:
				m = _match_support(w, a, b, killed)
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

## Explanations that accuse or clear someone outright (used by the support templates).
static func _accuse(w, who: String, type: String, label: String) -> Dictionary:
	return {"kind": "accuse", "label": label, "blame": who, "conclusion": {"type": type, "a": who}}

static func _clear(w, who: String, c: Dictionary, label: String) -> Dictionary:
	var cc = c.duplicate()
	cc["a"] = who
	return {"kind": "clear", "label": label, "blame": who, "conclusion": cc}

static func _cleared_how(a: Dictionary) -> String:
	if a["t"] == "killed":
		return "killed by the demon on night %d" % a["night"]
	if a["t"] == "not_demon":
		return "hanged without ending the case, so not the demon"
	return "shown to be the %s after their execution" % C.role_name(a["role"])

## Corroboration and inference: cards that don't conflict but, together, point somewhere.
static func _match_support(w, a: Dictionary, b: Dictionary, killed: Dictionary):
	var ta: String = a["t"]
	var tb: String = b["t"]
	var cards: Array = [a["card"], b["card"]]
	cards.sort()
	# Pair elimination: a reading names two people; one is cleared, which leaves the other.
	if ta == "reading" and (tb == "killed" or (tb == "not_demon" and a["role"] == "seer") or (tb == "was_role" and C.ROLES.get(b["role"], {}).get("align", "") == "good")):
		var d: Dictionary = a["data"]
		var pair: Array = []
		if a["role"] == "seer" and d.get("yes", false):
			pair = d["pair"]
		elif a["role"] == "archivist":
			pair = d["pair"]
		if pair.size() == 2 and b["who"] in pair:
			var other: String = pair[0] if pair[1] == b["who"] else pair[1]
			if killed.has(other) or other == b["who"]:
				return null
			var what = "the demon" if a["role"] == "seer" else "the Poisoner"
			var expls: Array = [_accuse(w, other, "demon" if a["role"] == "seer" else "evil", "%s is %s" % [_nm(w, other), what])]
			if a["role"] == "seer":
				expls.append(_clear(w, other, {"type": "good"}, "%s is the one who reads falsely as the demon (and is good)" % _nm(w, other)))
			expls.append(_poisoned(w, a["src"], a["night"]))
			expls.append(_lied(w, a["src"], a["card"]))
			var m = _mk(w, "pair_elimination", "%s's %s reading named %s and %s; %s was %s, which leaves %s." %
				[_nm(w, a["src"]), C.role_name(a["role"]), _nm(w, pair[0]), _nm(w, pair[1]), _nm(w, b["who"]), _cleared_how(b), _nm(w, other)],
				cards, expls, other, [a])
			m["relation"] = "inference"
			return m
	# A Clerk names a pair, one holding a gift; someone in the pair claims that gift.
	if ta == "claim" and tb == "reading" and b["role"] == "clerk" and a["src"] == a["who"] and b["src"] != a["who"]:
		var d2: Dictionary = b["data"]
		if a["who"] in d2.get("pair", []) and d2.get("role", "") == a["role"]:
			var other2: String = d2["pair"][0] if d2["pair"][1] == a["who"] else d2["pair"][1]
			var m2 = _mk(w, "claim_backed", "%s claims the %s, and %s's Clerk reading says one of %s and %s holds it." %
				[_nm(w, a["who"]), C.role_name(a["role"]), _nm(w, b["src"]), _nm(w, d2["pair"][0]), _nm(w, d2["pair"][1])], cards,
				[_clear(w, a["who"], {"type": "role", "role": a["role"]}, "%s is the %s" % [_nm(w, a["who"]), C.role_name(a["role"])]),
				_notrole(w, a["who"], a["role"]), _poisoned(w, b["src"], b["night"])], a["who"], [a])
			m2["explanations"][1]["label"] += " (%s holds it)" % _nm(w, other2)
			m2["relation"] = "corroboration"
			return m2
	# Two independent witnesses put the same person in the same place at the same time.
	if ta == tb and ta in ["out", "at"] and a["who"] == b["who"] and a["block"] == b["block"] and a["card"] < b["card"]:
		var same_time = a.get("night", -9) == b.get("night", -9) if ta == "out" else (a["day"] == b["day"] and a["phase"] == b["phase"])
		if same_time and a["src"] != b["src"] and a["src"] != a["who"] and b["src"] != b["who"] and _is_npc(w, a["src"]) and _is_npc(w, b["src"]):
			var m3 = _mk(w, "corroborated", "%s and %s both put %s on %s (%s)." %
				[_nm(w, a["src"]), _nm(w, b["src"]), _nm(w, a["who"]), C.block_name(a["block"]), _when(a)], cards,
				[_clear(w, a["src"], {"type": "truthful", "card": a["card"]}, "%s is telling the truth" % _nm(w, a["src"])),
				_clear(w, b["src"], {"type": "truthful", "card": b["card"]}, "%s is telling the truth" % _nm(w, b["src"]))], a["who"], [])
			m3["relation"] = "corroboration"
			return m3
	# Nobody died, and someone claims (or hints at) a protective gift.
	if ta == "quiet" and tb in ["claim", "shelter_hint"] and (tb == "shelter_hint" or b["role"] in ["warden", "veteran"]):
		var who: String = b["who"]
		var ward_note = ""
		if a["ward"] != "":
			ward_note = " (you had warded %s that night)" % _nm(w, a["ward"])
		var expls5: Array = []
		var what = "a protective gift" if tb == "shelter_hint" else "the " + C.role_name(b["role"])
		if tb == "claim":
			expls5.append(_clear(w, who, {"type": "role", "role": b["role"]}, "%s is %s, and it worked" % [_nm(w, who), what]))
			expls5.append(_notrole(w, who, b["role"]))
			expls5[1]["label"] += " (the quiet night had another cause%s)" % (": your ward, or the demon held back" if ward_note != "" else ", or the demon held back")
		else:
			expls5.append(_clear(w, who, {"type": "role", "role": "warden"}, "%s is the Warden" % _nm(w, who)))
			expls5.append(_clear(w, who, {"type": "role", "role": "veteran"}, "%s is the Veteran" % _nm(w, who)))
			expls5.append(_lied(w, who, b["card"]))
		var m5 = _mk(w, "quiet_night", "Nobody died on night %d%s, and %s claims %s." % [a["night"], ward_note, _nm(w, who), what], cards, expls5, who, [])
		m5["relation"] = "corroboration"
		return m5
	# A death-scene trace points to a block for the evening; someone was there then.
	if ta == "trace" and tb == "at" and b["block"] == a["block"] and b["day"] == a["day"] and b["phase"] == C.EVENING:
		var m4 = _mk(w, "trace_match", "The trace says the killer spent the evening of day %d on %s, and %s was there." %
			[a["day"], C.block_name(a["block"]), _nm(w, b["who"])], cards,
			[_accuse(w, b["who"], "demon", "%s is the demon" % _nm(w, b["who"])),
			_clear(w, b["who"], {"type": "notdemon"}, "%s is not the demon: someone else on %s was the killer" % [_nm(w, b["who"]), C.block_name(a["block"])])],
			b["who"], [])
		m4["relation"] = "inference"
		return m4
	return null

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
	var expls: Array = [_poisoned(w, a["src"], a["night"]), _lied(w, a["src"], a["card"])]
	if a["role"] == "seer":
		# A yes can be honest: one of the pair may be the soul who reads falsely as the demon.
		expls.append({"kind": "herring", "blame": "",
			"label": "%s's reading was honest: one of %s is the one who reads falsely as the demon" %
				[_nm(w, a["src"]), " and ".join(PackedStringArray(named.map(func(x): return _nm(w, x))))],
			"conclusion": {"type": "truthful", "a": a["src"], "card": a["card"]}})
	return _mk(w, "reading_vs_dead", "%s's %s reading pointed only at people the demon has since killed (%s)." %
		[_nm(w, a["src"]), C.role_name(a["role"]), ", ".join(PackedStringArray(named.map(func(x): return _nm(w, x))))], cards,
		expls, "", [a])

static func _mk(w, template: String, text: String, cards: Array, expls: Array, subject: String, asserts: Array) -> Dictionary:
	# Where someone could be either lying or misled, also offer "misled or lying".
	var extra: Array = []
	for e in expls:
		if e["kind"] == "lied":
			for f in expls:
				if f["kind"] == "misled" and f["blame"] == e["blame"]:
					var u = _unreliable(w, e["blame"], f["conclusion"].get("night", -1), e["card"])
					var dup = false
					for x in extra:
						if x["blame"] == u["blame"]:
							dup = true
					if not dup:
						extra.append(u)
	expls = expls + extra
	for e in expls:
		for s in asserts:
			if s["card"] == e.get("card", -1):
				e["assert"] = s
	return {"template": template, "text": text, "cards": cards, "explanations": expls, "subject": subject, "relation": "contradiction"}

# ---------------------------------------------------------------- conclusions

static func conclusion_text(w, c: Dictionary) -> String:
	c = normalize(c)
	var a = _nm(w, c.get("a", ""))
	var night = (" on night %d" % c["night"]) if c.has("night") else ""
	var about = (" (card #%d)" % c["card"]) if c.get("card", -1) > 0 else ""
	match c["type"]:
		"evil":
			return "%s is evil" % a
		"demon":
			return "%s is the demon" % a
		"good":
			return "%s is good" % a
		"notdemon":
			return "%s is not the demon" % a
		"role":
			return "%s is the %s" % [a, C.role_name(c["role"])]
		"notrole":
			return "%s is not the %s" % [a, C.role_name(c["role"])]
		"lied":
			return "%s is lying%s" % [a, about]
		"truthful":
			return "%s is not lying%s" % [a, about]
		"misled":
			return "%s is misled%s%s" % [a, night, about]
		"unreliable":
			return "%s is misled or lying%s%s" % [a, night, about]
		"protect":
			return "%s should be protected" % a
		"spare":
			return "%s should be spared from execution" % a
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
		"misled":
			var t = w.by_id.get(who)
			return 0.25 + (0.1 if t != null and t.claim_public and t.claimed_role in C.INFO_ROLES else 0.0)
		"accuse":
			if who == n.id:
				return 0.0
			return maxf(0.15 + Mind.susp(n, who) * 1.2 - (n.npc_trust.get(who, 0.5) - 0.5) * 0.5, 0.02)
		"clear":
			if who == n.id:
				return 3.0
			return maxf(0.3 + (0.6 - Mind.susp(n, who)) * 0.6 + (n.npc_trust.get(who, 0.5) - 0.5) * 0.4, 0.05)
		"herring":
			var src: String = e["conclusion"]["a"]
			return 0.3 + 0.4 * (1.0 - clampf(Mind.susp(n, src), 0.0, 1.0)) + (0.1 if src == n.id else 0.0)
		"unreliable":
			var lie = _expl_weight(w, n, {"kind": "lied", "blame": who})
			var mis = _expl_weight(w, n, {"kind": "misled", "blame": who})
			return lie + mis
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
		"good", "protect", "spare", "notdemon", "truthful":
			for card in supports:
				s += Mind.defend_strength(card, a.id)
			return clampf(s, 0.0, 1.0)
		"misled", "unreliable":
			for card in supports:
				if card.get("kind", "") == "info" and card.get("source", "") == a.id and (not c.has("night") or card.get("day", -1) == c["night"]):
					return 0.5
			return 0.2
		"role":
			for card in supports:
				if card.get("kind", "") == "claim" and card.get("source", "") == a.id and card.get("role", "") == c.get("role", ""):
					return 0.5
			return 0.2
	return 0.2

## One NPC weighs a deduction card. scale: 1.0 privately, 0.6 at the meeting.
## "X is misled or lying" contains "X is lying" and "X is misled": it doesn't compete
## with them as an alternative.
static func _overlaps(e1: Dictionary, e2: Dictionary) -> bool:
	if e1.is_empty() or e2.is_empty():
		return false
	var c1: Dictionary = e1.get("conclusion", {})
	var c2: Dictionary = e2.get("conclusion", {})
	if c1.get("a", "") != c2.get("a", ""):
		return false
	var t = [c1.get("type", ""), c2.get("type", "")]
	return "unreliable" in t and ("lied" in t or "misled" in t)

static func evaluate(w, n, ded: Dictionary, board: Array, scale: float) -> Dictionary:
	var lines: Array = []
	var c: Dictionary = normalize(ded["conclusion"])
	var target = w.by_id.get(c.get("a", ""))
	var supports: Array = board.filter(func(x): return x["n"] in ded["supports"])
	# Repetition follows the conclusion and the facts behind it, not the card's wording.
	var facts: Array = supports.map(func(x): return Mind.fact_id(x))
	facts.sort()
	var key: String = "ded:%s|%s" % [conclusion_key(c), ",".join(PackedStringArray(facts))]
	var times: int = n.heard.get(key, 0)
	n.heard[key] = times + 1
	var ins = n.traits.get("insight", 0.5)
	var weights = {}
	var agreement = 0.0
	var reason = ""
	if n.is_evil():
		if target != null and target.is_evil() and c["type"] in ["evil", "demon", "lied", "notrole"]:
			Evil.add_intel(w, n, "player_suspects", target.id, 0.0, "the Demonologist argues: %s" % conclusion_text(w, c))
		w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "evil": true}, "Evil hears the argument: %s" % ded["text"])
		var seen = false
		for k in n.heard:
			if k != key and k.begins_with("ded:%s|" % conclusion_key(c)):
				seen = true
		lines.append(_evil_mask(w, n, c, times, seen))
		return {"lines": lines, "agreement": 0.0}
	var self_misled = target == n and c["type"] in ["misled", "unreliable"]
	if self_misled:
		# They know they aren't lying, so "misled or lying" reads as "misled" to them.
		# Whether they accept their gift failed depends on how sure of themselves they are.
		c = c.duplicate()
		c["type"] = "misled"
		ded = ded.duplicate()
		ded["conclusion"] = c
		agreement = 0.35 + 0.55 * (1.0 - Mind.trait_of(n, "confidence"))
		reason = "self_misled"
	elif target == n and c["type"] in ["evil", "demon", "lied", "notrole"]:
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
		var chosen_e: Dictionary = {}
		for e in ded["explanations"]:
			if e["id"] == ded["chosen"]:
				chosen_e = e
		var rival = 0.0
		for e in ded["explanations"]:
			if e["id"] != ded["chosen"] and not _overlaps(chosen_e, e):
				rival = maxf(rival, weights[e["id"]])
		agreement = mine / maxf(mine + rival, 0.01)
		if agreement < 0.35:
			var best = 0
			var best_w = -1.0
			for e in ded["explanations"]:
				if weights[e["id"]] > best_w and not _overlaps(chosen_e, e):
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
	# Evidence already used against this person (told directly, or in an earlier argument)
	# counts for less: re-wrapping a card in a new deduction isn't new evidence.
	var novel = 1.0
	if c["type"] in ["evil", "demon", "lied", "notrole", "unreliable"] and not facts.is_empty():
		var fresh_n = 0
		for f in facts:
			if not n.used_facts.has(f + ">" + c.get("a", "")):
				fresh_n += 1
		novel = 0.35 + 0.65 * float(fresh_n) / facts.size()
		for f in facts:
			n.used_facts[f + ">" + c.get("a", "")] = true
	var base: float = agreement * quality * scale * novel
	var gain = _apply(w, n, ded, supports, base)
	var m: float = base * (0.5 + n.trust)
	var repeat = novel
	if agreement >= 0.6 and gain >= 0.1:
		Mind.set_trust(w, n, n.trust + 0.02, "the Demonologist made a sound argument")
	w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "template": ded.get("template", ""), "chosen": ded.get("chosen", 0),
		"weights": weights, "agreement": snappedf(agreement, 0.01), "quality": snappedf(quality, 0.01), "repeat": snappedf(repeat, 0.01),
		"scale": scale, "effect": snappedf(m, 0.01)}, "%s weighs '%s': agreement %.2f, effect %.2f%s" %
		[n.name, ded["text"], agreement, m, (" (" + reason + ")") if reason != "" else ""])
	if times > 0:
		lines.append(Mind.say(n, "You've told me that already."))
	elif self_misled:
		lines.append(Mind.say(n, "I'm no liar. But my gift may have failed me; I'll grant that." if agreement >= 0.5 else
			"I'm no liar, and I trust what my gift showed me. But I'll think on it."))
	elif agreement >= 0.6 and m >= 0.1:
		lines.append(Mind.say(n, "That's sound. " + _paraphrase(w, c)))
	elif agreement >= 0.6 and gain < 0.02:
		lines.append(Mind.say(n, "I'd come to that already."))
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
		"misled":
			return "So %s's information can't be trusted, though not through any fault of theirs." % a
		"unreliable":
			return "So whatever the reason, %s's word can't be trusted there." % a
		"notdemon":
			return "I'll not count %s as the demon." % a
		"truthful":
			return "I'll take %s at their word, then." % a
		"lied":
			return "So %s lied to us." % a
		"role":
			return "So %s is the %s." % [a, C.role_name(c["role"])]
		"notrole":
			return "So %s isn't really the %s." % [a, C.role_name(c["role"])]
	return ""

## A key for "the same conclusion": type, person and its qualifier.
static func conclusion_key(c: Dictionary) -> String:
	return "%s:%s:%s:%s" % [c.get("type", ""), c.get("a", ""), c.get("role", ""), str(c.get("night", c.get("card", "")))]

## What accepting a conclusion does to the listener, as ledger effects at weight 1.
static func effects_of(w, c: Dictionary, supports: Array, why: String) -> Array:
	var a: String = c.get("a", "")
	var e: Array = []
	match c["type"]:
		"evil":
			Mind._eff(e, a, 0.45, why, "the Demonologist made a case against them")
		"demon":
			Mind._eff(e, a, 0.55, why, "the Demonologist made a case against them")
		"good":
			Mind._eff(e, a, -0.4, why)
			Mind._eff(e, "pref:protect:" + a, 0.5, why, "", false)
		"protect":
			Mind._eff(e, "pref:protect:" + a, 1.0, why, "", false)
			Mind._eff(e, a, -0.15, why)
		"spare":
			Mind._eff(e, "pref:spare:" + a, 1.0, why, "", false)
			Mind._eff(e, a, -0.15, why)
		"role":
			Mind._eff(e, "role:%s:%s" % [a, c["role"]], 1.0, why, "", false)
			Mind._eff(e, a, -0.1, why)
			# Believing a's claim makes anyone else claiming that gift a liar.
			for pc in w.public_claims:
				if pc["role"] == c["role"] and pc["who"] != a:
					Mind._eff(e, pc["who"], 0.3, why + " (so their rival claim is false)", "their claim clashes with someone I believe")
		"notrole":
			Mind._eff(e, a, 0.3, why, "the Demonologist showed their claim is false")
		"lied":
			Mind._eff(e, a, 0.3, why, "the Demonologist caught them in a lie")
			for card in supports:
				if card["n"] == c.get("card", -1) and card.get("kind", "") == "info":
					Mind._eff(e, "disc:%s:%d" % [card["source"], card.get("day", -1)], 0.5, why, "", false)
		"misled", "unreliable":
			var night: int = c.get("night", -1)
			if night < 0 and c.has("card"):
				for card in supports:
					if card["n"] == c["card"] and card.get("kind", "") == "info":
						night = card.get("day", -1)
			Mind._eff(e, "disc:%s:%s" % [a, str(night) if night >= 0 else "*"], 0.8 if c["type"] == "misled" else 0.5, why, "", false)
			if c["type"] == "unreliable":
				Mind._eff(e, a, 0.12, why)
		"notdemon":
			Mind._eff(e, a, -0.25, why)
		"truthful":
			Mind._eff(e, a, -0.15, why)
	return e

## Take the argument in through the ledger. base excludes trust, so it can be re-weighed
## later. Returns the gain in weight (0 if they'd already accepted as much).
static func _apply(w, n, ded: Dictionary, supports: Array, base: float) -> float:
	var c: Dictionary = normalize(ded["conclusion"])
	if base <= 0.004:
		return 0.0
	var why = "the Demonologist argued: %s" % ded["text"]
	var said = "what you told me, that %s" % conclusion_text(w, c)
	var h = Mind.ledger_hear(w, n, "arg:" + conclusion_key(c), effects_of(w, c, supports, why), base * (0.5 + n.trust), [],
		{"kind": "arg", "base": base, "text": conclusion_text(w, c), "said": said})
	return h["gain"]

## An evil listener's reply: drawn from the same lines a good listener uses, according to
## what serves evil, so the wording carries no alignment tell.
static func _evil_mask(w, n, c: Dictionary, times: int, seen: bool) -> Dictionary:
	if times > 0:
		return Mind.say(n, "You've told me that already.")
	var target = w.by_id.get(c.get("a", ""))
	var accusing = c["type"] in ["evil", "demon", "lied", "notrole", "unreliable"]
	var serves = 0.5
	if target != null:
		if target == n and c["type"] in ["misled", "unreliable"]:
			return Mind.say(n, "I'm no liar. But my gift may have failed me; I'll grant that." if w.rng.randf() < 0.5 else
				"I'm no liar, and I trust what my gift showed me. But I'll think on it.")
		if target == n and accusing:
			return Mind.say(n, "I don't buy it: it's about me, and I know it's false.")
		if target.is_evil():
			serves = 0.1 if accusing else 0.9
		else:
			serves = 0.85 if accusing else 0.3
	var r = w.rng.randf()
	if serves >= 0.7 and seen:
		return Mind.say(n, "I'd come to that already.")
	if serves >= 0.7 and r < 0.65:
		return Mind.say(n, "That's sound. " + _paraphrase(w, c))
	if serves <= 0.2 and r < 0.4:
		return Mind.say(n, "I don't buy it.")
	return Mind.say(n, "Maybe. I'll think on it.")

# ---------------------------------------------------------------- filing checks

## Do these cards actually say something about the conclusion's subject?
static func bears_on(w, c: Dictionary, cards: Array) -> bool:
	var a: String = c.get("a", "")
	for x in cards:
		if a in x.get("subject", []) or x.get("source", "") == a or a in x.get("data", {}).get("pair", []):
			return true
		if x.get("kind", "") == "trace" and w.by_id.has(a):
			var t = w.by_id[a]
			if x.get("block", "") == t.home_block or x.get("block", "") == w.loc_block(t.work):
				return true
	return false

## Is this deduction allowed? Returns "" if fine, otherwise a reason for the player.
## A deduction can rest on weak or secondhand evidence, but it can't simply restate what
## someone has said about themselves.
static func filing_problem(w, c: Dictionary, supports: Array, board: Array, matched: bool) -> String:
	if supports.is_empty():
		return "Pick at least one card as evidence."
	var a: String = c.get("a", "")
	var cards: Array = board.filter(func(x): return x["n"] in supports)
	if cards.is_empty():
		return "Those cards aren't on your board."
	if matched:
		return ""
	var positive = c["type"] in ["role", "good", "notdemon", "truthful", "protect", "spare"]
	if not positive:
		return ""
	for x in cards:
		var src: String = x.get("source", "")
		var via: String = x.get("via", "")
		if src != a and via != a:
			return ""
	return "That only restates what %s has said about themselves. You need evidence from someone or something else." % _nm(w, a)
