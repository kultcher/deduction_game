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
const Gifts = preload("res://sim/gifts.gd")

## Conclusion types. The player builds them as "<name> <is / is not / should be> <status>".
const CONCLUSION_TYPES = ["good", "evil", "demon", "notdemon", "role", "notrole", "lied", "truthful", "misled", "unreliable", "protect", "spare",
	"suspicious", "secret", "marked", "red_herring", "secret_mod"]

## Builder vocabulary: verb -> [status, conclusion type] (role statuses are added per gift).
const BUILDER = {
	"is": [["good", "good"], ["evil", "evil"], ["the demon", "demon"], ["lying", "lied"], ["misled", "misled"], ["misled or lying", "unreliable"],
		["suspicious", "suspicious"], ["hiding a secret", "secret"]],
	"is not": [["good", "evil"], ["evil", "good"], ["the demon", "notdemon"], ["lying", "truthful"]],
	"should be": [["protected", "protect"], ["spared from execution", "spare"]],
}

## "Misread": good people whose gifts read them falsely (more kinds, such as a minion that
## reads as good, can join later).
const MISREAD = [["Marked", "marked"], ["the Seer's red herring", "red_herring"]]
## Secrets that can be concluded (Marked sits under Misread).
const SECRET_CONCLUSIONS = [["Delusional", "delusional"], ["a Secret Lover", "lovers"], ["a Sleepwalker", "sleepwalker"]]
## Conclusions that speak against someone (as opposed to for them).
const ACCUSING = ["evil", "demon", "lied", "notrole", "unreliable", "suspicious"]

## What each kind of fact can be linked with, for the "what can this be part of?" helper:
## fact type -> [[what the other piece would be, what it shows]]. Teaching text, not logic;
## keep it in step with the templates below.
const TEMPLATE_HINTS = {
	"out": [["their own word that they were home that night", "they lied, or the witness did"],
		["a sighting of them that night on a block off their way from home", "someone isn't telling the truth (or they walk the lamp route)"],
		["your vigil on that block that night, which didn't see them", "the sighting is wrong"],
		["a Night Watch report on that block that night that leaves them out", "the Watch, or the witness, isn't straight with you"],
		["another witness putting them there too", "the sighting holds"]],
	"home": [["a sighting of them out that night", "someone lied"],
		["something from their block dropped that night", "someone from their block was out"]],
	"at": [["a sighting of them elsewhere at the same time", "two places at once: someone lied"],
		["a death-scene trace pointing to that block, on that evening", "they were near where the killer spent the evening"],
		["another witness putting them there", "the sighting holds"]],
	"claim": [["someone else claiming the same gift", "one of them is lying"],
		["a Clerk reading that names them for that gift", "the claim is backed"],
		["a quiet night (if they claim Warden or Veteran)", "their gift may have worked"],
		["a Gravedigger's result for them", "the claim was true or false"],
		["their refusal to share readings", "the claim may be a cover"],
		["a different gift they claimed before", "their story changed"]],
	"reading": [["someone in the pair cleared (killed, hanged, proven good)", "it points at the other"],
		["another reading pointing at one of the same people", "the overlap is the likely one"],
		["the same reader reading the same people differently", "the gift failed one night"],
		["a reading that clears all but one of a group", "it leaves the last one"],
		["both named people proven good", "the reading is false"],
		["a death that contradicts it", "the reader was misled or lying"]],
	"killed": [["a reading naming them in a pair", "pair elimination: it points at the other"],
		["their claim to be the Veteran", "the demon can't kill a Veteran (unless poisoned)"]],
	"not_demon": [["a Seer reading naming them in a pair", "it points at the other (unless a Scion took over)"],
		["a Martyr's word that they'd die for them", "they read as evil, or the Martyr lied"]],
	"proven_good": [["a reading naming them in a pair", "it points at the other"],
		["a reading naming them with someone else proven good", "the reading is false"]],
	"trace": [["someone seen on that block that evening", "they were near where the killer spent the evening"]],
	"dropped": [["someone who lives on that block saying they were home that night", "someone from the block was out"]],
	"withheld": [["their claim to that gift", "they're hiding something, or just cautious"]],
	"vigil": [["a sighting of someone on that block that night", "your vigil says otherwise"],
		["a Night Watch report on the same block", "compare who each of you saw"]],
	"quiet": [["someone claiming the Warden or Veteran", "their gift may have worked"]],
	"talked": [["a card implicating one of the two as evil", "the other may be their partner"]],
	"lives": [["two sightings of them in one night", "whether one way from home covers both"]],
}

## The helper: for a card, what it could be linked with, and what that would show.
static func hints_for(card: Dictionary) -> Array:
	var out: Array = []
	var seen = {}
	for a in assertions(card):
		for h in TEMPLATE_HINTS.get(a["t"], []):
			var key = h[0]
			if not seen.has(key):
				seen[key] = true
				out.append(h)
	return out

static func is_evil_role(r: String) -> bool:
	return C.ROLES.has(r) and C.ROLES[r].get("align", "good") == "evil"

const RELATION_LEAD = {"contradiction": "These conflict:", "corroboration": "These agree:", "inference": "Put together:"}

## Old names kept working.
static func normalize(c: Dictionary) -> Dictionary:
	var t: String = c.get("type", "")
	if t == "poisoned" or t == "mistaken":
		c["type"] = "misled"
	return c

## The people a set of cards rests on: who said or reported them (and who claimed what).
## Excludes you, physical evidence, and anyone the demon killed (known good).
static func group_of(w, cards: Array) -> Array:
	var out: Array = []
	for x in cards:
		var ids: Array = []
		var src: String = x.get("source", "")
		if w.by_id.has(src):
			ids.append(src)
		if x.get("kind", "") == "claim":
			ids += x.get("subject", [])
		for id in ids:
			if w.by_id.has(id) and not (id in out) and not (not w.by_id[id].alive and w.by_id[id].death_cause == "demon"):
				out.append(id)
	out.sort()
	return out

static func conflict_of(w, cards: Array) -> Dictionary:
	return {"type": "conflict", "a": "", "group": group_of(w, cards)}

static func _names(w, ids: Array) -> String:
	var names: Array = ids.map(func(x): return _nm(w, x))
	if names.size() <= 1:
		return "".join(PackedStringArray(names))
	return ", ".join(PackedStringArray(names.slice(0, names.size() - 1))) + " and " + names[-1]

## Build a conclusion from builder pieces. Returns {} if the combination is invalid.
## status is the label the player reads ("evil" in "is not evil"), or with by_value the
## stored conclusion type (the builder's drop-down metadata). Labels and types swap under
## "is not" ("is not evil" = good), so the two must never be matched against each other.
static func from_builder(who: String, verb: String, status: String, night: int = -1, card: int = -1, by_value: bool = false) -> Dictionary:
	if C.ROLES.has(status) and status != "demon":
		if verb == "is":
			return {"type": "role", "a": who, "role": status}
		if verb == "is not":
			return {"type": "notrole", "a": who, "role": status}
		return {}
	if verb == "is":
		for pair in MISREAD:
			if status == pair[1] or (not by_value and status.to_lower() == pair[0].to_lower()):
				return {"type": pair[1], "a": who}
		for pair in SECRET_CONCLUSIONS:
			if status == pair[1] or (not by_value and status.to_lower() == pair[0].to_lower()):
				return {"type": "secret_mod", "a": who, "mod": pair[1]}
	var hit: Array = []
	for pair in BUILDER.get(verb, []):
		if (pair[1] if by_value else pair[0]) == status:
			hit = pair
			break
	if hit.is_empty() and not by_value:
		for pair in BUILDER.get(verb, []):
			if pair[1] == status:
				hit = pair
				break
	if hit.is_empty():
		return {}
	var c = {"type": hit[1], "a": who}
	if hit[1] in ["misled", "unreliable"] and night >= 0:
		c["night"] = night
	if hit[1] in ["lied", "unreliable", "truthful"] and card > 0:
		c["card"] = card
	return c

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
					# Someone's own account of where their night took them (a watch kept, a door
					# guarded, the hearth of the dead) names a destination; the lamp route
					# passes every block.
					var own = subj.size() == 1 and subj[0] == src
					var dest = own and (card.get("watch_claim", false) or card.has("guard_claim") or (card.has("duty_claim") and card.get("duty", "") != "lamplighter"))
					var lamp = own and card.has("duty_claim") and card.get("duty", "") == "lamplighter"
					for who in subj:
						out.append({"t": "out", "who": who, "block": card["block"], "night": day, "src": src, "card": n, "dest": dest, "lamp": lamp})
			else:
				for who in subj:
					out.append({"t": "at", "who": who, "block": card.get("block", ""), "day": day, "phase": ph, "src": src, "card": n})
		"vigil":
			out.append({"t": "vigil", "block": card["block"], "night": day, "seen": [], "src": src, "card": n})
		"secret":
			if card.has("block"):
				out.append({"t": "out", "who": card["owner"], "block": card["block"], "night": day, "src": src, "card": n, "dest": true})
		"home":
			out.append({"t": "lives", "who": subj[0], "block": card.get("block", ""), "src": src, "card": n})
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
				out.append({"t": "out", "who": src, "block": d["block"], "night": day, "src": src, "card": n, "dest": true})
			if role2 == "gravedigger":
				out.append({"t": "was_role", "who": d["executed"], "role": d["role"], "src": src, "night": day, "card": n})
				if C.ROLES.get(d["role"], {}).get("align", "") == "evil":
					out.append({"t": "believed_evil", "who": d["executed"], "eid": "", "src": src, "card": n})
		"death":
			out.append({"t": "killed", "who": subj[0], "night": card.get("night", day - 1), "src": src, "card": n})
		"trace":
			out.append({"t": "trace", "block": card.get("block", ""), "day": day, "src": src, "card": n})
		"dropped":
			out.append({"t": "dropped", "material": card.get("material", ""), "block": card.get("block", ""), "night": day, "src": src, "card": n})
		"conversation":
			for who in subj:
				out.append({"t": "at", "who": who, "block": card.get("block", ""), "day": day, "phase": ph, "src": src, "card": n})
			if subj.size() == 2:
				out.append({"t": "talked", "a": subj[0], "b": subj[1], "day": day, "phase": ph, "src": src, "card": n})
		"quiet":
			out.append({"t": "quiet", "night": card.get("night", day), "ward": card.get("ward", ""), "src": src, "card": n})
		"hint":
			if card.get("package", "") == "shelter":
				out.append({"t": "shelter_hint", "who": subj[0], "src": src, "card": n})
		"martyr":
			# The Martyr died in the nominee's place: both proven good, for all to see.
			for who in subj:
				out.append({"t": "proven_good", "who": who, "how": "martyr", "src": src, "card": n, "group": subj.duplicate()})
		"deduction":
			var dc: Dictionary = card.get("conclusion", {})
			if dc.get("type", "") in ["good", "marked", "red_herring"] or (dc.get("type", "") == "secret_mod" and dc.get("mod", "") != "delusional"):
				out.append({"t": "proven_good", "who": dc.get("a", ""), "how": "deduced", "src": src, "card": n})
			if dc.get("type", "") in ["evil", "demon"]:
				out.append({"t": "believed_evil", "who": dc.get("a", ""), "eid": "arg:" + conclusion_key(dc), "src": src, "card": n})
			if dc.get("type", "") in ["misled", "unreliable"] and dc.has("night"):
				out.append({"t": "ded_misled", "who": dc.get("a", ""), "night": dc["night"], "src": src, "card": n})
		"execution":
			# Hanged and the case went on: whoever it was, they weren't the demon, unless five or
			# more were alive at the hanging, when a Scion could have taken the demon's place.
			if not subj.is_empty():
				out.append({"t": "not_demon", "who": subj[0], "src": src, "card": n, "scion_possible": card.get("alive_before", 99) >= 5})
		"refusal":
			if card.get("withheld", false) and not subj.is_empty():
				out.append({"t": "withheld", "who": subj[0], "role": card.get("role", ""), "src": src, "card": n, "fear": card.get("fear", false)})
	return out

# ---------------------------------------------------------------- templates

static func _nm(w, id: String) -> String:
	return w.by_id[id].name if w.by_id.has(id) else id

## A source named in a sentence: "you", "the evidence", or the person.
static func _who_saw(w, src: String) -> String:
	if src == "player":
		return "You"
	if src == "evidence":
		return "The evidence"
	return _nm(w, src)

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
	for m3 in _match_groups(w, asserts):
		matches.append(m3)
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
			# In an agreement or an inference, "the reader was wrong" (or "the claim is
			# false") is a rival the town weighs against your conclusion, not something
			# these cards show; in a contradiction every explanation is a way out of a real
			# clash.
			var ex: Dictionary = m["explanations"][i]
			if m.get("relation", "contradiction") != "contradiction" and ex["kind"] in ["lied", "misled", "unreliable", "notrole"] and not ex.get("fileable", false):
				ex["rival_only"] = true
		uniq.append(m)
	var near_u: Array = []
	for r in near:
		if not (r in near_u):
			near_u.append(r)
	return {"matches": uniq, "near": near_u}

## The way from someone's home to a block, as the town's roads run (public knowledge).
static func _way(home: String, block: String) -> String:
	return " → ".join(PackedStringArray(C.route(home, block).map(func(x): return C.block_name(x))))

## Night sightings of one person on two blocks: fine if one route from home covers both.
static func _match_route(w, a: Dictionary, b: Dictionary, cards: Array, near: Array):
	var who: String = a["who"]
	if not w.by_id.has(who):
		return null
	if a.get("lamp", false) or b.get("lamp", false):
		near.append("%s says they walked the lamp route, which passes every block." % _nm(w, who))
		return null
	var home: String = w.by_id[who].home_block
	var dest_a: Dictionary = a if a.get("dest", false) else (b if b.get("dest", false) else {})
	var text = ""
	if not dest_a.is_empty():
		var other: Dictionary = b if dest_a == a else a
		if other.get("dest", false) and other["block"] != dest_a["block"]:
			text = "%s can't have ended the night on both %s and %s on night %d." % [_nm(w, who), C.block_name(dest_a["block"]), C.block_name(other["block"]), a["night"]]
		elif other["block"] in C.route(home, dest_a["block"]):
			near.append("%s lives on %s; the way to %s (%s) passes %s, so cards #%d and #%d fit together." %
				[_nm(w, who), C.block_name(home), C.block_name(dest_a["block"]), _way(home, dest_a["block"]), C.block_name(other["block"]), a["card"], b["card"]])
			return null
		else:
			text = "%s lives on %s. The way to %s, where card #%d puts the end of their night, runs %s and doesn't pass %s (card #%d)." % \
				[_nm(w, who), C.block_name(home), C.block_name(dest_a["block"]), dest_a["card"], _way(home, dest_a["block"]), C.block_name(other["block"]), other["card"]]
	else:
		for d in C.BLOCKS:
			var r: Array = C.route(home, d)
			if a["block"] in r and b["block"] in r:
				near.append("%s lives on %s; a walk to %s (%s) passes both %s and %s, so cards #%d and #%d fit together." %
					[_nm(w, who), C.block_name(home), C.block_name(d), _way(home, d), C.block_name(a["block"]), C.block_name(b["block"]), a["card"], b["card"]])
				return null
		text = "%s lives on %s, and no single way from there passes both %s and %s, yet cards #%d and #%d put them on both on night %d." % \
			[_nm(w, who), C.block_name(home), C.block_name(a["block"]), C.block_name(b["block"]), a["card"], b["card"], a["night"]]
	var ex: Array = _place_expls(w, a, b)
	ex.append(_clear(w, who, {"type": "role", "role": "lamplighter"}, "%s was walking the lamp route (the Lamplighter)" % _nm(w, who)))
	var m = _mk(w, "off_route", text, cards, ex, who, [a, b])
	return m

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
	if a["t"] == "proven_good":
		return "proven good when the Martyr died in their place" if a.get("how", "") == "martyr" else "good (your deduction, card #%d)" % a["card"]
	if a["t"] == "killed":
		return "killed by the demon on night %d" % a["night"]
	if a["t"] == "not_demon":
		if a.get("scion_possible", false):
			return "hanged without ending the case (so not the demon, unless a Scion took over)"
		return "hanged without ending the case, so not the demon"
	return "shown to be the %s after their execution" % C.role_name(a["role"])

## Corroboration and inference: cards that don't conflict but, together, point somewhere.
static func _match_support(w, a: Dictionary, b: Dictionary, killed: Dictionary):
	var ta: String = a["t"]
	var tb: String = b["t"]
	var cards: Array = [a["card"], b["card"]]
	cards.sort()
	# Pair elimination: a reading names two people; one is cleared, which leaves the other.
	if ta == "reading" and (tb == "killed" or tb == "proven_good" or (tb == "not_demon" and a["role"] == "seer") or (tb == "was_role" and C.ROLES.get(b["role"], {}).get("align", "") == "good")):
		var d: Dictionary = a["data"]
		var pair: Array = []
		if a["role"] == "seer" and d.get("yes", false):
			pair = d["pair"]
		elif a["role"] == "archivist":
			pair = d["pair"]
		if pair.size() == 2 and b["who"] in pair:
			var other: String = pair[0] if pair[1] == b["who"] else pair[1]
			if killed.has(other) or other == b["who"] or other in b.get("group", []):
				return null
			var what = "the demon" if a["role"] == "seer" else "the " + C.role_name(d.get("role", "poisoner"))
			var expls: Array = [_accuse(w, other, "demon" if a["role"] == "seer" else "evil", "%s is %s" % [_nm(w, other), what])]
			if a["role"] == "seer":
				expls.append(_clear(w, other, {"type": "good"}, "%s is the one who reads falsely as the demon (and is good)" % _nm(w, other)))
			if b["t"] == "not_demon" and b.get("scion_possible", false):
				expls.append(_accuse(w, b["who"], "demon", "%s was the demon, and a Scion took over when they hanged" % _nm(w, b["who"])))
			expls.append(_poisoned(w, a["src"], a["night"]))
			expls.append(_lied(w, a["src"], a["card"]))
			var m = _mk(w, "pair_elimination", "%s's %s reading named %s and %s; %s was %s, which leaves %s." %
				[_nm(w, a["src"]), C.role_name(a["role"]), _nm(w, pair[0]), _nm(w, pair[1]), _nm(w, b["who"]), _cleared_how(b), _nm(w, other)],
				cards, expls, other, [a])
			m["relation"] = "inference"
			return m
	# A Martyr said they'd die for X; X was hanged, and the Martyr still stands.
	if ta == "reading" and a["role"] == "martyr" and a["data"].get("chosen", false) and tb == "not_demon" and b["who"] == a["data"].get("target", "") and not killed.has(a["src"]):
		var x: String = b["who"]
		var mt: String = a["src"]
		var ex_m: Array = [_accuse(w, x, "evil", "%s was evil, so the Martyr's gift let them hang" % _nm(w, x)),
			_clear(w, x, {"type": "marked"}, "%s was Marked: good, but read as evil" % _nm(w, x)),
			_lied(w, mt, a["card"])]
		if _is_npc(w, mt):
			ex_m.append(_poisoned(w, mt, b.get("night", a["night"])))
		var m_m = _mk(w, "martyr_no_save", "%s said they'd give their life for %s. %s was hanged, and %s still stands." % [_nm(w, mt), _nm(w, x), _nm(w, x), _nm(w, mt)],
			cards, ex_m, x, [a])
		# The Martyr's word and what happened at the gallows clash: every way out is fair.
		m_m["relation"] = "contradiction"
		return m_m
	# Two readings that point toward evil overlap in exactly one person.
	if ta == "reading" and tb == "reading" and a["card"] < b["card"]:
		var ia: Array = Gifts.implicated({"role": a["role"], "data": a["data"]}).filter(func(x): return not killed.has(x))
		var ib: Array = Gifts.implicated({"role": b["role"], "data": b["data"]}).filter(func(x): return not killed.has(x))
		var both: Array = ia.filter(func(x): return x in ib)
		if both.size() == 1 and ia.size() > 1 and ib.size() > 1:
			var x: String = both[0]
			var seers = a["role"] == "seer" and b["role"] == "seer"
			var ex_o: Array = []
			if seers:
				ex_o.append(_accuse(w, x, "demon", "%s is the demon" % _nm(w, x)))
				ex_o.append(_clear(w, x, {"type": "good"}, "%s is the one who reads falsely as the demon (and is good)" % _nm(w, x)))
			else:
				ex_o.append(_accuse(w, x, "evil", "%s is evil" % _nm(w, x)))
			for s2 in [a, b]:
				if _is_npc(w, s2["src"]):
					ex_o.append(_poisoned(w, s2["src"], s2["night"]))
			var mo = _mk(w, "overlap", "%s's %s reading and %s's %s reading both point toward evil, and the only person in both is %s." %
				[_nm(w, a["src"]), C.role_name(a["role"]), _nm(w, b["src"]), C.role_name(b["role"]), _nm(w, x)], cards, ex_o, x, [a, b])
			mo["relation"] = "inference"
			return mo
	# A reading that says one of a few is evil, and another that clears all but one of them.
	if ta == "reading" and tb == "reading" and a["card"] != b["card"]:
		var da: Dictionary = a["data"]
		var one_of = (a["role"] in ["dowser", "hearthwitch"] and da.get("count", 0) == 1) or (a["role"] == "seer" and da.get("yes", false))
		var grp: Array = Gifts.implicated({"role": a["role"], "data": da}).filter(func(x): return not killed.has(x))
		var clr: Array = Gifts.clears({"role": b["role"], "data": b["data"]})
		var left: Array = grp.filter(func(x): return not (x in clr))
		if one_of and grp.size() >= 2 and left.size() == 1 and grp.size() > left.size():
			var y: String = left[0]
			var ex_s: Array = [_accuse(w, y, "demon" if a["role"] == "seer" else "evil", "%s is %s" % [_nm(w, y), "the demon" if a["role"] == "seer" else "the evil one"])]
			if a["role"] == "seer":
				ex_s.append(_clear(w, y, {"type": "good"}, "%s is the one who reads falsely as the demon (and is good)" % _nm(w, y)))
			for s3 in [a, b]:
				if _is_npc(w, s3["src"]):
					ex_s.append(_poisoned(w, s3["src"], s3["night"]))
			var ms = _mk(w, "group_elimination", "%s's %s reading says one of %s is %s; %s's %s reading clears the rest, which leaves %s." %
				[_nm(w, a["src"]), C.role_name(a["role"]), _names(w, grp), "the demon" if a["role"] == "seer" else "evil", _nm(w, b["src"]), C.role_name(b["role"]), _nm(w, y)],
				cards, ex_s, y, [a, b])
			ms["relation"] = "inference"
			return ms
	# Claims an information gift but won't share what it has shown them.
	if ta == "claim" and tb == "withheld" and a["who"] == b["who"] and a["role"] == b["role"] and C.has_readings(a["role"]):
		var mw = _mk(w, "withholding", "%s claims the %s but won't share its readings." % [_nm(w, a["who"]), C.role_name(a["role"])], cards,
			[_accuse(w, a["who"], "evil", "%s is hiding something: the claim is a cover" % _nm(w, a["who"])),
			_notrole(w, a["who"], a["role"]),
			_clear(w, a["who"], {"type": "good"}, ("%s is afraid, as they said: telling would make them the demon's next mark" if b.get("fear", false) else "%s is simply cautious") % _nm(w, a["who"]))], a["who"], [a])
		mw["relation"] = "inference"
		return mw
	# A Clerk names a pair, one holding a gift; someone in the pair claims that gift.
	if ta == "claim" and tb == "reading" and b["role"] == "clerk" and a["src"] == a["who"] and b["src"] != a["who"]:
		var d2: Dictionary = b["data"]
		if a["who"] in d2.get("pair", []) and d2.get("role", "") == a["role"]:
			var other2: String = d2["pair"][0] if d2["pair"][1] == a["who"] else d2["pair"][1]
			var other_is = _notrole(w, a["who"], a["role"])
			other_is["label"] = "%s is lying about the %s: %s is the %s" % [_nm(w, a["who"]), C.role_name(a["role"]), _nm(w, other2), C.role_name(a["role"])]
			other_is["fileable"] = true
			# Evil's own move: a fake Clerk reading vouching for a teammate's bluffed gift.
			var together = _accuse(w, a["who"], "evil", "%s and %s are working together: both lying (so %s is evil)" % [_nm(w, b["src"]), _nm(w, a["who"]), _nm(w, a["who"])])
			var m2 = _mk(w, "claim_backed", "%s claims the %s, and %s's Clerk reading says one of %s and %s holds it." %
				[_nm(w, a["who"]), C.role_name(a["role"]), _nm(w, b["src"]), _nm(w, d2["pair"][0]), _nm(w, d2["pair"][1])], cards,
				[_clear(w, a["who"], {"type": "role", "role": a["role"]}, "%s is the %s" % [_nm(w, a["who"]), C.role_name(a["role"])]),
				other_is, together, _poisoned(w, b["src"], b["night"])], a["who"], [a])
			m2["relation"] = "corroboration"
			return m2
	# Two independent witnesses put the same person in the same place at the same time.
	if ta == tb and ta in ["out", "at"] and a["who"] == b["who"] and a["block"] == b["block"] and a["card"] < b["card"]:
		var same_time = a.get("night", -9) == b.get("night", -9) if ta == "out" else (a["day"] == b["day"] and a["phase"] == b["phase"])
		# One of the two may be you (or physical evidence): a witness backing what you saw.
		if same_time and a["src"] != b["src"] and a["src"] != a["who"] and b["src"] != b["who"] and (_is_npc(w, a["src"]) or _is_npc(w, b["src"])):
			var ex3: Array = []
			for s3 in [a, b]:
				if _is_npc(w, s3["src"]):
					ex3.append(_clear(w, s3["src"], {"type": "truthful", "card": s3["card"]}, "%s is telling the truth" % _nm(w, s3["src"])))
			var m3 = _mk(w, "corroborated", "%s and %s both put %s on %s (%s)." %
				[_who_saw(w, a["src"]), _who_saw(w, b["src"]), _nm(w, a["who"]), C.block_name(a["block"]), _when(a)], cards,
				ex3, a["who"], [])
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
	# Something from block M was dropped on night N; someone who lives on M says they were home.
	if ta == "dropped" and tb == "home" and w.by_id.has(b["who"]) and w.by_id[b["who"]].home_block == a["material"] and b["night"] == a["night"]:
		var who6: String = b["who"]
		var m6 = _mk(w, "dropped_vs_home", "Someone from %s was out on night %d (%s found at %s), and %s, who lives there, says they were home." %
			[C.block_name(a["material"]), a["night"], C.BLOCKS[a["material"]]["trace"], C.block_name(a["block"]), _nm(w, who6)], cards,
			[_lied(w, who6, b["card"]), _clear(w, who6, {"type": "truthful", "card": b["card"]}, "%s is telling the truth: someone else from %s was out" % [_nm(w, who6), C.block_name(a["material"])])],
			who6, [b])
		m6["relation"] = "inference"
		return m6
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

## Templates over several cards at once.
static func _match_groups(w, asserts: Array) -> Array:
	var out: Array = []
	var claims = {}
	for a in asserts:
		if a["t"] == "claim" and a["src"] == a["who"]:
			claims[a["who"]] = a
	# A reading that names two people (one is the demon / one holds a minion's gift), when
	# both are proven good: the reading is false.
	var good_by = {}
	for a in asserts:
		if a["t"] == "proven_good" and not good_by.has(a["who"]):
			good_by[a["who"]] = a
	for a in asserts:
		if a["t"] != "reading":
			continue
		var pr: Array = []
		if a["role"] == "seer" and a["data"].get("yes", false):
			pr = a["data"].get("pair", [])
		elif a["role"] == "archivist":
			pr = a["data"].get("pair", [])
		if pr.size() != 2 or not (good_by.has(pr[0]) and good_by.has(pr[1])):
			continue
		var g0: Dictionary = good_by[pr[0]]
		var g1: Dictionary = good_by[pr[1]]
		if g0["card"] == a["card"] or g1["card"] == a["card"]:
			continue
		var cards_g: Array = [a["card"], g0["card"]]
		if not (g1["card"] in cards_g):
			cards_g.append(g1["card"])
		cards_g.sort()
		var what = "the demon" if a["role"] == "seer" else "the " + C.role_name(a["data"].get("role", "poisoner"))
		var ex_g: Array = [_lied(w, a["src"], a["card"]), _poisoned(w, a["src"], a["night"])]
		if a["role"] == "seer":
			ex_g.append(_clear(w, pr[0], {"type": "red_herring"}, "%s is the Seer's red herring" % _nm(w, pr[0])))
			ex_g.append(_clear(w, pr[1], {"type": "red_herring"}, "%s is the Seer's red herring" % _nm(w, pr[1])))
		else:
			ex_g.append(_clear(w, pr[0], {"type": "marked"}, "%s is Marked (reads as evil)" % _nm(w, pr[0])))
			ex_g.append(_clear(w, pr[1], {"type": "marked"}, "%s is Marked (reads as evil)" % _nm(w, pr[1])))
		var m_g = _mk(w, "pair_both_good", "%s's %s reading says one of %s and %s is %s, but both are good (%s; %s)." %
			[_nm(w, a["src"]), C.role_name(a["role"]), _nm(w, pr[0]), _nm(w, pr[1]), what, _cleared_how(g0), _cleared_how(g1)],
			cards_g, ex_g, a["src"], [a])
		m_g["relation"] = "contradiction"
		out.append(m_g)
	for a in asserts:
		# A Clerk names two people, one holding a gift, but both claim other gifts.
		if a["t"] == "reading" and a["role"] == "clerk":
			var pair: Array = a["data"].get("pair", [])
			var r: String = a["data"].get("role", "")
			if pair.size() == 2 and claims.has(pair[0]) and claims.has(pair[1]) and claims[pair[0]]["role"] != r and claims[pair[1]]["role"] != r:
				var c0: Dictionary = claims[pair[0]]
				var c1: Dictionary = claims[pair[1]]
				var cards: Array = [a["card"], c0["card"], c1["card"]]
				cards.sort()
				var m = _mk(w, "clerk_vs_claims", "%s's Clerk reading says one of %s and %s is the %s, but %s claims the %s and %s the %s." %
					[_nm(w, a["src"]), _nm(w, pair[0]), _nm(w, pair[1]), C.role_name(r), _nm(w, pair[0]), C.role_name(c0["role"]), _nm(w, pair[1]), C.role_name(c1["role"])],
					cards, [_poisoned(w, a["src"], a["night"]), _lied(w, a["src"], a["card"]), _lied(w, pair[0], c0["card"]), _lied(w, pair[1], c1["card"])], "", [a, c0, c1])
				out.append(m)
		# Association: someone implicated as evil, seen talking (repeatedly?) with Y.
		if a["t"] == "believed_evil" and w.by_id.has(a["who"]):
			var x: String = a["who"]
			var partners = {}
			for b in asserts:
				if b["t"] == "talked" and x in [b["a"], b["b"]]:
					var y: String = b["b"] if b["a"] == x else b["a"]
					if not partners.has(y):
						partners[y] = []
					if not (b["card"] in partners[y]):
						partners[y].append(b["card"])
			for y in partners:
				var conv: Array = partners[y]
				var cards2: Array = [a["card"]] + conv
				cards2.sort()
				var acc = _accuse(w, y, "evil", "%s is %s's partner (evil)" % [_nm(w, y), _nm(w, x)])
				acc["kind"] = "associate"
				acc["times"] = conv.size()
				acc["base_eid"] = a["eid"]
				acc["base_src"] = a["src"]
				var m2 = _mk(w, "association", "%s is implicated as evil, and was seen talking with %s%s." %
					[_nm(w, x), _nm(w, y), (" %d times" % conv.size()) if conv.size() > 1 else ""], cards2,
					[acc, _clear(w, y, {"type": "good"}, "%s is good, and was being worked on (or just a friend)" % _nm(w, y))], y, [])
				m2["relation"] = "inference"
				out.append(m2)
		# Vindication: if the Gravedigger was poisoned that night, the Poisoner was alive, so
		# the dead person they named wasn't the Poisoner.
		if a["t"] == "ded_misled":
			for b in asserts:
				if b["t"] == "was_role" and b["src"] == a["who"] and b["night"] == a["night"] and b["role"] == "poisoner":
					var cards3: Array = [a["card"], b["card"]]
					cards3.sort()
					var m3 = _mk(w, "vindication", "If %s was poisoned on night %d, the Poisoner was alive that night, so %s (already hanged) wasn't the Poisoner, and wasn't the demon either." %
						[_nm(w, a["who"]), a["night"], _nm(w, b["who"])], cards3,
						[_clear(w, b["who"], {"type": "good"}, "%s was good" % _nm(w, b["who"])),
						_clear(w, a["who"], {"type": "truthful", "card": b["card"]}, "%s wasn't misled after all (their report stands)" % _nm(w, a["who"]))], b["who"], [])
					m3["relation"] = "inference"
					out.append(m3)
	return out

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
	# Two blocks in one night. Walkers are seen anywhere along their way, so this only
	# conflicts when no single route from their home takes in both (or the way to a
	# destination they named doesn't pass the other block).
	if ta == "out" and tb == "out" and a["who"] == b["who"] and a["block"] != b["block"] and a["card"] < b["card"]:
		if a["night"] == b["night"]:
			var m_r = _match_route(w, a, b, cards, near)
			if m_r != null:
				return m_r
		else:
			near.append("cards #%d and #%d are about %s on different nights (%d vs %d)." % [a["card"], b["card"], _nm(w, a["who"]), a["night"], b["night"]])
	if ta == "out" and tb == "home" and a["who"] == b["who"]:
		if a["night"] == b["night"]:
			var said = ("%s says they were home on night %d" % [_nm(w, a["who"]), a["night"]]) if b["src"] == b["who"] else \
				("%s says %s stayed home on night %d" % [_nm(w, b["src"]), _nm(w, a["who"]), a["night"]])
			return _mk(w, "out_vs_home", "%s, but card #%d puts them out on %s." %
				[said, a["card"], C.block_name(a["block"])], cards, _place_expls(w, a, b), a["who"], [a, b])
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
		"conflict":
			return "Something doesn't add up: one of %s is misled or lying" % _names(w, c.get("group", []))
		"suspicious":
			return "%s is suspicious" % a
		"secret":
			return "%s is hiding a secret (an innocent one)" % a
		"marked":
			return "%s is Marked (good, but may read as evil)" % a
		"red_herring":
			return "%s is the Seer's red herring (good, but reads as the demon)" % a
		"secret_mod":
			match c.get("mod", ""):
				"delusional":
					return "%s is Delusional (their gift tells them nothing true)" % a
				"lovers":
					return "%s is a Secret Lover" % a
				"sleepwalker":
					return "%s is a Sleepwalker" % a
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

## Is the card this "lied" conclusion points at one of n's own statements that n knows is
## false?
static func _own_lie(w, n, c: Dictionary, supports: Array) -> bool:
	for card in supports:
		if c.has("card") and card.get("n", -1) != c["card"]:
			continue
		if card.get("source", "") != n.id:
			continue
		for s in assertions(card):
			if s.get("who", "") == n.id and _knows_false(w, n, s) == 1:
				return true
	return false

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
		"associate":
			if who == n.id:
				return 0.0
			var cred = 0.0
			if e.get("base_eid", "") != "" and n.ledger.has(e["base_eid"]):
				cred = clampf(n.ledger[e["base_eid"]]["weight"] * 1.5, 0.0, 1.0)  # how much they bought "X is evil"
			elif e.get("base_src", "") != "" and w.by_id.has(e["base_src"]):
				cred = _cred(w, n, e["base_src"]) * 0.8  # a Gravedigger's verdict, as credible as its source
			return maxf(0.05 + 0.25 * e.get("times", 1) * cred + 0.9 * cred * 0.5 + Mind.susp(n, who) * 0.6, 0.02)
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
		"suspicious":
			for card in supports:
				var rel2 = 1.0 if a.id in card.get("subject", []) or card.get("source", "") == a.id else 0.3
				s += Mind.card_strength(w, card, a) * rel2
			return clampf(0.2 + s / 1.5, 0.0, 0.8)
		"secret", "marked", "red_herring", "secret_mod":
			for card in supports:
				s += Mind.defend_strength(card, a.id)
			return clampf(0.25 + s, 0.0, 0.8)
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

static func evaluate(w, n, ded: Dictionary, board: Array, scale: float, speak: bool = true) -> Dictionary:
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
	var explanation_trace: Array = []
	var route = ""
	var trace_id = w.dlog.decision(n.id, "argument", "start", null,
		{"conclusion": c, "fact_ids": facts, "card": ded.get("n", 0),
			"ledger_id": "arg:" + conclusion_key(c), "template": ded.get("template", ""),
			"repeat_count": times, "scale": scale}, c.get("a", ""))
	var agreement = 0.0
	var reason = ""
	var alternative = ""
	var audience = "player" if scale >= 1.0 else "town"
	var delivery_memory: Dictionary = n.dialogue_memory if speak and not n.silenced else n.dialogue_memory.duplicate(true)
	if n.is_evil():
		var workshop_covered = false
		if target != null and target.is_evil() and c["type"] in ACCUSING:
			Evil.add_intel(w, n, "player_suspects", target.id, 0.0, "the Demonologist argues: %s" % conclusion_text(w, c))
		w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "evil": true}, "Evil hears the argument: %s" % ded["text"])
		var seen = false
		for k in n.heard:
			if k != key and k.begins_with("ded:%s|" % conclusion_key(c)):
				seen = true
		var mask = _evil_mask(w, n, c, times, seen)
		var approved = _argument_descriptor(w, c, facts, mask.get("stance", "partial"))
		approved["special"] = mask.get("special", "")
		approved["already"] = mask.get("already", false)
		if approved["stance"] != "accept" and approved["special"] == "":
			_evil_reason(w, n, c, ded, approved)
		# Shadow self (step 2): answer as their good self would, unless breaking cover is
		# worth it. Arguments about themselves keep the mask ("it's about me").
		if C.SHADOW_SELF and (times == 0 or n.workshop_state.get("enabled", false)) and (target != n or n.workshop_state.get("enabled", false)):
			var sr = Mind.shadow_eval(w, n, func(sh): return evaluate(w, sh, ded, board, scale, false))
			workshop_covered = sr != null and sr.get("workshop", false)
			if target != n and sr != null and sr.has("dialogue") and sr["dialogue"].get("stance", "") != approved["stance"]:
				var mine: Dictionary = sr["dialogue"]
				var rank = {"reject": 0, "partial": 1, "accept": 2}
				var dev = absf(rank.get(mine["stance"], 1) - rank.get(approved["stance"], 1)) / 2.0
				var stakes = _evil_argument_stakes(w, n, c, target)
				if not Mind.evil_override(w, n, "argument", stakes, dev, "%s (good self: %s, evil: %s)" % [conclusion_text(w, c), mine["stance"], approved["stance"]]):
					approved = mine.duplicate(true)
		if times > 0 and not workshop_covered:
			var prior: Dictionary = delivery_memory.get("decisions", {}).get(JSON.stringify([audience, conclusion_key(c)]), {})
			# Reuse their expressed position, not new private strategy. A new audience
			# gets a cautious answer without pretending it heard the earlier reply.
			for field in ["stance", "special", "reason", "alternative", "source", "preferred"]:
				if prior.has(field):
					approved[field] = prior[field]
		if not n.silenced:
			lines.append(_argument_line(n, approved, audience, delivery_memory))
		w.dlog.add("argument_stance", n.id, c.get("a", ""), {"key": conclusion_key(c), "stance": approved["stance"], "evil": true, "repeat": times > 0})
		w.dlog.decision(n.id, "argument", "outcome", approved, {"route": "evil_mask",
			"agreement": 0.0, "updates_real_beliefs": false, "repeat_count": times}, c.get("a", ""), trace_id)
		return {"lines": lines, "agreement": 0.0, "repeated": times > 0, "dialogue": approved, "workshop": workshop_covered}
	if w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(n, ded, [], "deduction", "private" if scale >= 1.0 else ("nomination" if scale <= 0.5 else "meeting"), speak)
		if not interpreted.is_empty():
			return interpreted
	# Caught in a lie they know they told (a good NPC hiding a gift or a secret): they don't
	# pretend to themselves it's false.
	var own_lie = target == n and c["type"] in ["lied", "unreliable"] and _own_lie(w, n, c, supports)
	var self_misled = target == n and c["type"] in ["misled", "unreliable"] and not own_lie
	var conflict = c["type"] == "conflict"
	var in_group = conflict and n.id in c.get("group", [])
	if conflict:
		route = "conflict"
		# "Something doesn't add up." Backed by a contradiction, anyone can see the clash;
		# otherwise it rests on how far they trust you, and sharp people want to see it.
		if ded.get("template", "") != "" and ded.get("relation", "contradiction") == "contradiction":
			agreement = 0.55 + 0.35 * ins
		elif ded.get("unfounded", false):
			agreement = 0.0 if w.rng.randf() < ins else 0.3
		else:
			agreement = clampf((0.3 + 0.35 * n.trust) * (1.25 - 0.6 * ins), 0.0, 1.0)
		if agreement < 0.35 and ins >= 0.5:
			reason = "I don't see what doesn't add up"
		if in_group:
			agreement = minf(agreement, 0.35 + 0.55 * (1.0 - Mind.trait_of(n, "confidence")))
			reason = "in_group"
	elif self_misled:
		route = "self_misled"
		# They know they aren't lying, so "misled or lying" reads as "misled" to them.
		# Whether they accept their gift failed depends on how sure of themselves they are.
		c = c.duplicate()
		c["type"] = "misled"
		ded = ded.duplicate()
		ded["conclusion"] = c
		agreement = 0.35 + 0.55 * (1.0 - Mind.trait_of(n, "confidence"))
		reason = "self_misled"
	elif own_lie:
		route = "own_lie"
		agreement = 0.0
		reason = "own_lie"
	elif target == n and c["type"] in ["evil", "demon", "lied", "notrole", "suspicious"]:
		route = "own_knowledge_rejection"
		agreement = 0.0
		reason = "it's about me, and I know it's false"
		Mind.set_trust(w, n, n.trust - 0.05, "the Demonologist argued against me to my face")
	elif target == n:
		route = "self_support"
		agreement = 1.0
	elif ded.get("template", "") != "":
		route = "template_contest"
		var total = 0.0
		for e in ded["explanations"]:
			var wt = _expl_weight(w, n, e)
			weights[e["id"]] = snappedf(wt, 0.01)
			if w.dlog.detailed:
				explanation_trace.append({"id": e["id"], "label": e.get("label", ""),
					"kind": e.get("kind", ""), "raw_weight": wt,
					"used_weight": weights[e["id"]], "chosen": e["id"] == ded["chosen"]})
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
				if weights[e["id"]] > rival:
					alternative = e["label"]
				rival = maxf(rival, weights[e["id"]])
		agreement = mine / maxf(mine + rival, 0.01)
		w.dlog.decision(n.id, "argument", "contest", agreement,
			{"chosen_weight": mine, "strongest_rival_weight": rival,
				"denominator_floor": 0.01, "explanations": explanation_trace,
				"strongest_alternative": alternative, "overlapping_alternatives_excluded": true}, c.get("a", ""), trace_id)
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
		route = "unfounded"
		if w.rng.randf() < ins:
			agreement = 0.0
			reason = ded.get("near", "") if ded.get("near", "") != "" else "those don't contradict each other"
		else:
			agreement = 0.35 * (1.0 - ins) + 0.2 * n.trust
	else:
		route = "generic_support"
		agreement = _support_strength(w, c, supports)
		if ins >= 0.67 and agreement < 0.3:
			reason = "that's not enough to go on"
	var quality = _quality(w, n, supports)
	var doubtful_source = ""
	var least_credit = 0.3
	for support in supports:
		var source: String = support.get("source", "")
		var credit = _cred(w, n, source)
		if w.by_id.has(source) and source != n.id and credit < least_credit:
			least_credit = credit
			doubtful_source = w.by_id[source].name
	# Evidence already used against this person (told directly, or in an earlier argument)
	# counts for less: re-wrapping a card in a new deduction isn't new evidence.
	var novel = 1.0
	if c["type"] in ACCUSING and not facts.is_empty():
		var fresh_n = 0
		for f in facts:
			if not n.used_facts.has(f + ">" + c.get("a", "")):
				fresh_n += 1
		novel = 0.35 + 0.65 * float(fresh_n) / facts.size()
		for f in facts:
			n.used_facts[f + ">" + c.get("a", "")] = true
	var base: float = agreement * quality * scale * novel
	var gain = _apply(w, n, ded, supports, base, board, trace_id)
	var m: float = base * (0.5 + n.trust)
	var repeat = novel
	w.dlog.decision(n.id, "argument", "evaluation", agreement,
		{"route": route, "agreement": agreement, "quality": quality, "scale": scale,
			"novelty": novel, "base": base, "trust_at_apply": n.trust,
			"nominal_weight": m, "stored_weight_gain": gain, "reason": reason,
			"stance_thresholds": {"accept": 0.6, "partial": 0.35},
			"sound_argument_reward_gates": {"agreement_at_least": 0.6, "gain_at_least": 0.1}}, c.get("a", ""), trace_id)
	if agreement >= 0.6 and gain >= 0.1:
		Mind.set_trust(w, n, n.trust + 0.02, "the Demonologist made a sound argument")
	w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "template": ded.get("template", ""), "chosen": ded.get("chosen", 0),
		"weights": weights, "agreement": snappedf(agreement, 0.01), "quality": snappedf(quality, 0.01), "repeat": snappedf(repeat, 0.01),
		"scale": scale, "effect": snappedf(m, 0.01)}, "%s weighs '%s': agreement %.2f, effect %.2f%s" %
		[n.name, ded["text"], agreement, m, (" (" + reason + ")") if reason != "" else ""])
	var stance = "accept" if agreement >= 0.6 else "partial" if agreement >= 0.35 else "reject"
	var approved = _argument_descriptor(w, c, facts, stance)
	w.dlog.add("argument_stance", n.id, c.get("a", ""), {"key": conclusion_key(c), "stance": stance, "evil": false, "repeat": times > 0})
	# They agree, but it moved nothing: they'd already come to it themselves.
	approved["already"] = stance == "accept" and gain < 0.02 and times == 0
	if self_misled:
		approved["special"] = "I'm no liar. But my gift may have failed me; I'll grant that." if agreement >= 0.5 else "I'm no liar, and I trust what my gift showed me. But I'll think on it."
	elif in_group:
		approved["special"] = "I've told the truth. But something's off there, I'll grant you." if agreement >= 0.5 else "I've told the truth, and I stand by it. Look to the others."
	elif own_lie:
		# They know it's true. Owning it depends on how private they are and how hard they're
		# pressed; either way it isn't "false" to them.
		var p_admit = 0.2 + 0.45 * (1.0 - Mind.trait_of(n, "privacy")) + 0.3 * n.pressure + 0.3 * (n.trust - 0.5)
		if w.rng.randf() < p_admit:
			approved["special"] = "All right. I wasn't where I said I was. I had my reasons, and I wasn't ready to tell you."
			Mind.set_trust(w, n, n.trust + 0.02, "owned up to the Demonologist")
			w.dlog.think(n.id, "admit", "Admits the lie the Demonologist caught.")
		else:
			approved["special"] = "I've said what I've said."
			w.dlog.think(n.id, "lie", "Knows the lie was caught; won't admit it.", {"lie": true})
	elif target == n and agreement == 0.0:
		approved["special"] = "I don't buy it: it's about me, and I know it's false."
	elif not alternative.is_empty() and agreement < 0.6:
		approved["reason"] = "alternative" if agreement < 0.5 else "possible_alternative"
		approved["alternative"] = alternative
	elif quality < 0.35:
		approved["reason"] = "source" if doubtful_source != "" else "quality"
		approved["source"] = doubtful_source
	elif agreement < 0.6:
		approved["reason"] = "weak"
	if c["type"] in ["evil", "demon"] and target != n:
		var ranked: Array = Mind.ranked_suspects(w, n)
		if not ranked.is_empty() and ranked[0].id != c.get("a", "") and Mind.susp(n, ranked[0].id) > Mind.susp(n, c.get("a", "")) + 0.05:
			approved["preferred"] = ranked[0].name
	if not n.silenced:
		lines.append(_argument_line(n, approved, audience, delivery_memory))
	w.dlog.decision(n.id, "argument", "outcome", approved,
		{"route": route, "agreement": agreement, "stored_weight_gain": gain}, c.get("a", ""), trace_id)
	return {"lines": lines, "agreement": agreement, "repeated": times > 0, "dialogue": approved}

## An evil listener's stated reason for not being convinced, drawn from the same kinds of
## reason good listeners give (another explanation, shaky evidence, a likelier suspect),
## so evil replies aren't all "the evidence doesn't establish that". Deterministic per
## listener and argument: no game RNG is drawn.
static func _evil_reason(w, n, c: Dictionary, ded: Dictionary, approved: Dictionary) -> void:
	var h: int = absi(hash(n.id + "|" + conclusion_key(c)))
	var alts: Array = ded.get("explanations", []).filter(func(e): return e.get("id", -1) != ded.get("chosen", 0))
	var pick: int = h % 4
	if pick <= 1 and not alts.is_empty():
		approved["reason"] = "alternative" if pick == 0 else "possible_alternative"
		approved["alternative"] = alts[(h / 4) % alts.size()]["label"]
	elif pick == 2:
		approved["reason"] = "quality"
	else:
		approved["reason"] = "weak"
	var sg = w.by_id.get(w.evil_plan.get("scapegoat", ""))
	if c["type"] in ["evil", "demon"] and sg != null and sg.alive and sg.id != c.get("a", "") and sg != n and (h / 16) % 2 == 0:
		approved["preferred"] = sg.name

static func _argument_descriptor(w, c: Dictionary, facts: Array, stance: String) -> Dictionary:
	return {"kind": "argument", "key": conclusion_key(c), "facts": facts.duplicate(), "stance": stance,
		"claim": conclusion_text(w, c).trim_prefix("Something doesn't add up: "), "target_id": c.get("a", ""),
		"accusing": c.get("type", "") in ACCUSING}

static func _argument_line(n, approved: Dictionary, audience: String, memory: Dictionary) -> Dictionary:
	return Mind.say(n, Mind.Dialogue.decision(n.id, approved, audience, memory)["text"])

static func _paraphrase(w, c: Dictionary) -> String:
	var a = _nm(w, c.get("a", ""))
	match c["type"]:
		"conflict":
			return "I'll take what %s say with a pinch of salt." % _names(w, c.get("group", []))
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
		"suspicious":
			return "I'll watch %s more closely." % a
		"secret", "secret_mod":
			return "That would explain a few things about %s." % a
		"marked", "red_herring":
			return "Then %s's readings against them count for less." % a
	return ""

## A key for "the same conclusion": type, person and its qualifier.
static func conclusion_key(c: Dictionary) -> String:
	if c.get("type", "") == "conflict":
		return "conflict:" + ",".join(PackedStringArray(c.get("group", [])))
	return "%s:%s:%s:%s" % [c.get("type", ""), c.get("a", ""), c.get("role", c.get("mod", "")), str(c.get("night", c.get("card", "")))]

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
			if is_evil_role(c["role"]):
				Mind._eff(e, a, 0.5, why, "the Demonologist made a case they're one of the demon's")
				return e
			Mind._eff(e, a, -0.1, why)
			# Believing a's claim makes anyone else claiming that gift a liar (now or later).
			Mind._eff(e, "rivals:%s:%s" % [c["role"], a], 0.3, why + " (so a rival claim is false)", "their claim clashes with someone I believe")
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
		"conflict":
			var grp: Array = c.get("group", [])
			for g in grp:
				Mind._eff(e, "disc:%s:*" % g, 0.4 / maxf(1.0, grp.size()), why, "", false)
				Mind._eff(e, g, 0.05, why)
		"suspicious":
			# A weak push: pressure, not proof.
			Mind._eff(e, a, 0.15, why, "the Demonologist finds them suspicious")
		"secret":
			Mind._eff(e, a, -0.12, why)
		"marked", "red_herring":
			Mind._eff(e, a, -0.3 if c["type"] == "marked" else -0.4, why)
		"secret_mod":
			if c.get("mod", "") == "delusional":
				Mind._eff(e, "disc:%s:*" % a, 0.7, why, "", false)
			else:
				Mind._eff(e, a, -0.15, why)
	return e

## Take the argument in through the ledger. base excludes trust, so it can be re-weighed
## later. Returns the gain in weight (0 if they'd already accepted as much).
## The underlying claims an argument rests on. A deduction used as support is followed
## down to what *it* rests on, so discrediting the original evidence weakens the whole chain.
static func support_refs(cards: Array, board: Array, depth: int = 0) -> Array:
	var out: Array = []
	for card in cards:
		if card.get("kind", "") == "deduction" and depth < 4 and not board.is_empty():
			var inner: Array = board.filter(func(x): return x["n"] in card.get("supports", []))
			for r in support_refs(inner, board, depth + 1):
				out.append(r)
		else:
			out.append(Mind.support_ref(card))
	return out

static func _apply(w, n, ded: Dictionary, supports: Array, base: float, board: Array = [], trace_id: int = 0) -> float:
	var c: Dictionary = normalize(ded["conclusion"])
	if base <= 0.004:
		w.dlog.decision(n.id, "argument", "gate", false,
			{"gate": "base_too_small", "base": base, "must_exceed": 0.004}, c.get("a", ""), trace_id)
		return 0.0
	var why = "the Demonologist argued: %s" % ded["text"]
	var said = "what you told me, that %s" % conclusion_text(w, c)
	# Remember what the argument rests on: if that evidence is later discredited, the
	# conclusion weakens with it.
	var sup: Array = support_refs(supports, board)
	var ledger_id = "arg:" + conclusion_key(c)
	if ded.has("workshop_case"):
		ledger_id = "arg:workshop:%d" % ded.n
	var before: Dictionary = n.ledger.get(ledger_id, {}).duplicate(true) if w.dlog.detailed else {}
	var suspicion_before: Dictionary = n.suspicion.duplicate() if w.dlog.detailed else {}
	var h = Mind.ledger_hear(w, n, ledger_id, effects_of(w, c, supports, why), base * (0.5 + n.trust), [],
		{"kind": "arg", "base": base, "text": conclusion_text(w, c), "said": said, "supports": sup,
		"workshop_roots": Mind.WorkshopLedger.roots(supports, board), "workshop_case": str(ded.get("n", 0)), "workshop_conclusion": c.type})
	w.dlog.decision(n.id, "argument", "ledger", h, {"ledger_id": ledger_id,
		"before": before, "after": n.ledger.get(ledger_id, {}), "suspicion_before": suspicion_before,
		"suspicion_after": n.suspicion, "supports": sup}, c.get("a", ""), trace_id)
	return h["gain"]

## What answering as evil (rather than as its good self) buys an evil listener: protecting a
## teammate under fire, or pushing a case against the good (more for the scapegoat).
static func _evil_argument_stakes(w, n, c: Dictionary, target) -> float:
	if target == null:
		return 0.2
	var accusing = c["type"] in ACCUSING or (c["type"] == "role" and is_evil_role(c.get("role", "")))
	if target.is_evil():
		var v = Evil.teammate_value(w, target.id)
		return v * (0.3 + Evil.public_heat(w, target)) if accusing else 0.4 * v
	var sg = target.id == w.evil_plan.get("scapegoat", "")
	if accusing:
		return 0.25 + (0.35 if sg else 0.0)
	return 0.3 + (0.2 if Evil.intel_threat(n, target.id) > 0.0 else 0.0)

## An evil listener's reply: drawn from the same lines a good listener uses, according to
## what serves evil, so the wording carries no alignment tell.
static func _evil_mask(w, n, c: Dictionary, times: int, seen: bool) -> Dictionary:
	# Same branch order and RNG draws as the original mask; only its output is structured.
	if times > 0:
		return {"stance": "partial"}
	var target = w.by_id.get(c.get("a", ""))
	var accusing = c["type"] in ACCUSING or (c["type"] == "role" and is_evil_role(c.get("role", "")))
	var serves = 0.5
	if c["type"] == "conflict":
		var grp: Array = c.get("group", [])
		if n.id in grp:
			var agrees = w.rng.randf() < 0.5
			return {"stance": "partial", "special": "I've told the truth. But something's off there, I'll grant you." if agrees else "I've told the truth, and I stand by it. Look to the others."}
		serves = 0.15 if grp.any(func(x): return w.by_id[x].is_evil()) else 0.75
	elif target != null:
		if target == n and c["type"] in ["misled", "unreliable"]:
			var agrees = w.rng.randf() < 0.5
			return {"stance": "partial", "special": "I'm no liar. But my gift may have failed me; I'll grant that." if agrees else "I'm no liar, and I trust what my gift showed me. But I'll think on it."}
		if target == n and accusing:
			return {"stance": "reject", "special": "I don't buy it: it's about me, and I know it's false."}
		if target.is_evil():
			serves = 0.1 if accusing else 0.9
		else:
			serves = 0.85 if accusing else 0.3
	var r = w.rng.randf()
	if serves >= 0.7 and seen:
		return {"stance": "accept", "already": true}
	if serves >= 0.7 and r < 0.65:
		return {"stance": "accept"}
	if serves <= 0.2 and r < 0.4:
		return {"stance": "reject"}
	return {"stance": "partial"}

# ---------------------------------------------------------------- filing checks

## Do these cards actually say something about the conclusion's subject?
static func bears_on(w, c: Dictionary, cards: Array) -> bool:
	if c.get("type", "") == "conflict":
		return c.get("group", []).size() >= 2
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
	if c.get("type", "") == "conflict" and c.get("group", []).size() < 2:
		return "Those cards only rest on one person's word. Name them instead (e.g. 'is misled or lying')."
	var a: String = c.get("a", "")
	var cards: Array = board.filter(func(x): return x["n"] in supports)
	if cards.is_empty():
		return "Those cards aren't on your board."
	if matched:
		return ""
	var positive = (c["type"] in ["role", "good", "notdemon", "truthful", "protect", "spare", "secret", "marked", "red_herring"] and not is_evil_role(c.get("role", ""))) \
		or (c["type"] == "secret_mod" and c.get("mod", "") != "delusional")
	if not positive:
		return ""
	for x in cards:
		var src: String = x.get("source", "")
		var via: String = x.get("via", "")
		if src != a and via != a:
			return ""
	return "That only restates what %s has said about themselves. You need evidence from someone or something else." % _nm(w, a)
