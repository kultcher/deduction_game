## The deduction schema (split from sim/argue.gd, purge phase 1, docs/legacy_retirement_plan.md):
## card assertions, the contradiction template library the case board files with, and the
## conclusion vocabulary (types, builder, text, keys, filing checks). The board, the Case
## Workshop canvas and presentation all use it; no NPC belief effects live here.
##
## A card carries assertions (small typed facts). Linking cards runs every template over
## every pair of assertions from different cards. A match lists possible explanations; the
## player picks one, which becomes a conclusion (a "deduction" card).
extends RefCounted

const C = preload("res://sim/content.gd")
const Gifts = preload("res://sim/gifts.gd")

## Conclusion types. The player builds them as "<name> <is / is not / should be> <status>".
const CONCLUSION_TYPES = ["good", "evil", "demon", "minion", "notdemon", "role", "notrole", "lied", "truthful", "misled", "unreliable", "protect", "spare",
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
const ACCUSING = ["evil", "demon", "minion", "lied", "notrole", "unreliable", "suspicious"]

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
	"secret_claim": [["a sighting of them out at night", "their confessed secret may explain the movement"],
		["a reading implicating them (if they claim Marked)", "the reading may reflect their secret"]],
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
			out.append({"t": "secret_claim", "who": card.get("owner", subj[0] if not subj.is_empty() else src), "mod": card.get("mod", ""), "src": src, "card": n})
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
		"home":
			if not subj.is_empty():
				out.append({"t": "profile_home", "who": subj[0], "block": card.get("block", ""), "src": src, "card": n})
		"work":
			if not subj.is_empty():
				out.append({"t": "profile_spot", "who": subj[0], "loc": card.get("loc", ""), "src": src, "card": n})
		"haunt":
			if not subj.is_empty():
				for hloc in card.get("locs", [card.get("loc", "")]):
					if hloc != "":
						out.append({"t": "profile_spot", "who": subj[0], "loc": hloc, "src": src, "card": n})
		"bond":
			if subj.size() == 2:
				out.append({"t": "profile_bond", "people": subj.duplicate(), "src": src, "card": n})
		"trace":
			if card.get("trace_family", "") != "":
				out.append({"t": "trace_struct", "family": card.get("trace_family", ""), "locs": card.get("locs", []), "home_block": card.get("trace_home_block", ""), "evening_block": card.get("trace_evening_block", ""), "victim": card.get("victim", ""), "victim_block": card.get("victim_block", card.get("block", "")), "day": day, "src": src, "card": n})
			else:
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
			if dc.get("type", "") in ["evil", "demon", "minion"]:
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
	# Deduplicate by template + cards + subject: one receipt can place several people.
	var seen = {}
	var uniq: Array = []
	for m in matches:
		var key = m["template"] + ":" + str(m["cards"]) + ":" + str(m["subject"])
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
	# Confessions are testimony, not a hard clear. The player can argue an innocent
	# explanation; listeners can still doubt the person who supplied it.
	if ta == "secret_claim" and tb == "out" and a["who"] == b["who"] and a.get("mod", "") in ["", "lovers", "sleepwalker"]:
		var sc = {"type": "secret_mod", "mod": "lovers"} if a.get("mod", "") == "lovers" else {"type": "secret"}
		var sx: Array = [_clear(w, a["who"], sc, "%s's confessed secret explains being out" % _nm(w, a["who"]))]
		if _is_npc(w, a["src"]):
			sx.append(_lied(w, a["src"], a["card"]))
		var sm = _mk(w, "secret_explains_movement", "%s has an account of an innocent secret that could explain being out on night %d." % [_nm(w, a["who"]), b["night"]], cards, sx, a["who"], [])
		sm["relation"] = "inference"
		return sm
	if ta == "secret_claim" and a.get("mod", "") == "marked" and tb == "reading" and b["role"] in ["seer", "dowser", "hearthwitch", "archivist", "gravedigger", "martyr"] and a["who"] in Gifts.implicated({"role": b["role"], "data": b["data"]}):
		var mx: Array = [_clear(w, a["who"], {"type": "marked"}, "%s may read as evil because they are Marked" % _nm(w, a["who"]))]
		if _is_npc(w, a["src"]):
			mx.append(_lied(w, a["src"], a["card"]))
		var mm = _mk(w, "marked_explains_reading", "%s is said to be Marked, which could explain the reading against them." % _nm(w, a["who"]), cards, mx, a["who"], [])
		mm["relation"] = "inference"
		return mm
	# A death-scene trace points to a block for the evening; someone was there then.
	if ta == "trace" and tb == "at" and b["block"] == a["block"] and b["day"] == a["day"] and b["phase"] == C.EVENING:
		var m4 = _mk(w, "trace_match", "The trace says the killer spent the evening of day %d on %s, and %s was there." %
			[a["day"], C.block_name(a["block"]), _nm(w, b["who"])], cards,
			[_accuse(w, b["who"], "demon", "%s is the demon" % _nm(w, b["who"])),
			_clear(w, b["who"], {"type": "notdemon"}, "%s is not the demon: someone else on %s was the killer" % [_nm(w, b["who"]), C.block_name(a["block"])])],
			b["who"], [])
		m4["relation"] = "inference"
		return m4
	if ta == "trace_struct" or tb == "trace_struct":
		var tr_a: Dictionary = a if ta == "trace_struct" else b
		var oth: Dictionary = b if ta == "trace_struct" else a
		var ot: String = oth["t"]
		var fam: String = tr_a["family"]
		if fam == "locations" and ot == "profile_spot" and oth["loc"] in tr_a["locs"]:
			var ml = _mk(w, "trace_match", "The scene trace points to %s, and %s frequents %s." %
				[C.loc_list_or(tr_a["locs"]), _nm(w, oth["who"]), w.loc_name(oth["loc"])], cards,
				[_accuse(w, oth["who"], "demon", "%s is the demon" % _nm(w, oth["who"])),
				_clear(w, oth["who"], {"type": "notdemon"}, "%s is not the demon: someone else tied to %s left the trace" % [_nm(w, oth["who"]), C.loc_list_or(tr_a["locs"])])],
				oth["who"], [])
			ml["relation"] = "inference"
			return ml
		if fam == "quarter" and ((ot == "profile_home" and oth["block"] == tr_a["home_block"]) or (ot == "at" and oth["day"] == tr_a["day"] and oth["phase"] == C.EVENING and oth["block"] == tr_a["evening_block"])):
			var mq = _mk(w, "trace_match", "The scene trace matches %s's quarter or evening whereabouts." % _nm(w, oth["who"]), cards,
				[_accuse(w, oth["who"], "demon", "%s is the demon" % _nm(w, oth["who"])),
				_clear(w, oth["who"], {"type": "notdemon"}, "%s is not the demon: someone else matching that quarter left the trace" % _nm(w, oth["who"]))],
				oth["who"], [])
			mq["relation"] = "inference"
			return mq
		if fam == "connection":
			var c_who = ""
			if ot == "profile_home" and oth["block"] == tr_a["victim_block"]:
				c_who = oth["who"]
			elif ot == "profile_bond" and tr_a["victim"] in oth["people"]:
				c_who = oth["people"][0] if oth["people"][1] == tr_a["victim"] else oth["people"][1]
			elif ot == "talked" and oth["day"] == tr_a["day"] and (oth["a"] == tr_a["victim"] or oth["b"] == tr_a["victim"]):
				c_who = oth["b"] if oth["a"] == tr_a["victim"] else oth["a"]
			if c_who != "":
				var mc = _mk(w, "trace_match", "The unforced-entry trace connects %s to %s." % [_nm(w, c_who), _nm(w, tr_a["victim"])], cards,
					[_accuse(w, c_who, "demon", "%s is the demon" % _nm(w, c_who)),
					_clear(w, c_who, {"type": "notdemon"}, "%s is not the demon: someone else connected to %s left the trace" % [_nm(w, c_who), _nm(w, tr_a["victim"])])],
					c_who, [])
				mc["relation"] = "inference"
				return mc
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
				acc["base_who"] = x
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
	# Your vigil saw everyone whose night destination was that block (or who walked the lamp route).
	if ta == "vigil" and tb == "out" and a["block"] == b["block"] and a["night"] == b["night"] and not (b["who"] in a["seen"]) and _is_npc(w, b["src"]):
		if w.by_id.has(b["who"]) and w.by_id[b["who"]].home_block == a["block"] and not b.get("dest", false) and not b.get("lamp", false):
			near.append("a vigil on %s watches for activity arriving on that block; %s lives there and could have been glimpsed leaving for another block." % [C.block_name(a["block"]), _nm(w, b["who"])])
		else:
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
		"minion":
			return "%s is a minion" % a
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

## A key for "the same conclusion": type, person and its qualifier.
static func conclusion_key(c: Dictionary) -> String:
	if c.get("type", "") == "conflict":
		return "conflict:" + ",".join(PackedStringArray(c.get("group", [])))
	return "%s:%s:%s:%s" % [c.get("type", ""), c.get("a", ""), c.get("role", c.get("mod", "")), str(c.get("night", c.get("card", "")))]

## Three-valued trace relevance from ONLY discovered board/profile receipts (`matches` | `unknown` | `contradicts`).
## Never consults hidden NPC haunts, unobserved history, or unlearned relationships.
static func trace_fit_from_receipts(person_id: String, trace_card: Dictionary, receipts: Array) -> String:
	var fam: String = str(trace_card.get("trace_family", ""))
	var night: int = int(trace_card.get("crime_night", trace_card.get("day", -1)))
	if fam == "locations":
		var locs: Array = trace_card.get("locs", [])
		var work_loc: String = ""
		var haunts: Array = []
		for r in receipts:
			if r.get("deleted", false) or person_id not in r.get("subject", []):
				continue
			var rkind: String = str(r.get("kind", ""))
			if rkind == "work":
				work_loc = str(r.get("loc", ""))
			elif rkind == "haunt":
				for hl in r.get("locs", [r.get("loc", "")]):
					if hl != "" and hl not in haunts:
						haunts.append(hl)
		if work_loc != "" and work_loc in locs:
			return "matches"
		for hl in haunts:
			if hl in locs:
				return "matches"
		if work_loc != "" and haunts.size() >= 2:
			return "contradicts"
		return "unknown"
	elif fam == "quarter":
		var hb: String = str(trace_card.get("trace_home_block", ""))
		var eb: String = str(trace_card.get("trace_evening_block", ""))
		var known_home: String = ""
		var evening_blocks: Array = []
		for r in receipts:
			if r.get("deleted", false):
				continue
			var rkind: String = str(r.get("kind", ""))
			var subjs: Array = r.get("subject", [])
			if person_id in subjs:
				if rkind == "home":
					known_home = str(r.get("block", ""))
				elif rkind == "work":
					var phases: Array = r.get("work_phases", [])
					var wloc: String = str(r.get("loc", ""))
					if C.EVENING in phases and C.LOCATIONS.has(wloc):
						var wb: String = str(C.LOCATIONS[wloc]["block"])
						if wb not in evening_blocks:
							evening_blocks.append(wb)
				elif rkind in ["sighting", "conversation"] and int(r.get("day", -2)) == night and int(r.get("phase", -1)) == C.EVENING:
					var sb: String = str(r.get("block", ""))
					if sb != "" and sb not in evening_blocks:
						evening_blocks.append(sb)
		if known_home != "" and known_home == hb:
			return "matches"
		if eb != "" and eb in evening_blocks:
			return "matches"
		if known_home != "" and known_home != hb and not evening_blocks.is_empty() and eb not in evening_blocks:
			return "contradicts"
		return "unknown"
	elif fam == "connection":
		var victim: String = str(trace_card.get("victim", ""))
		var vblock: String = str(trace_card.get("scene_block", ""))
		var known_home: String = ""
		var has_bond: bool = false
		var shared_day: bool = false
		var victim_day_locs: Dictionary = {}
		var person_day_phases: Dictionary = {}
		for r in receipts:
			if r.get("deleted", false):
				continue
			var rkind: String = str(r.get("kind", ""))
			var subjs: Array = r.get("subject", [])
			if rkind == "home":
				if person_id in subjs:
					known_home = str(r.get("block", ""))
				if vblock == "" and victim != "" and victim in subjs:
					vblock = str(r.get("block", ""))
			elif rkind == "bond" and person_id in subjs and victim != "" and victim in subjs:
				has_bond = true
			elif rkind in ["sighting", "conversation"] and int(r.get("day", -2)) == night and int(r.get("phase", -1)) in [C.MORNING, C.AFTERNOON, C.EVENING]:
				if person_id in subjs and victim != "" and victim in subjs:
					shared_day = true
				var ph: int = int(r.get("phase", -1))
				var rloc: String = str(r.get("loc", ""))
				if victim != "" and victim in subjs and rloc != "":
					victim_day_locs[ph] = rloc
				if person_id in subjs:
					person_day_phases[ph] = rloc if rloc != "" else ("block:" + str(r.get("block", "")))
		for ph_k in victim_day_locs:
			if person_day_phases.get(ph_k, "") == victim_day_locs[ph_k]:
				shared_day = true
		if has_bond or (known_home != "" and vblock != "" and known_home == vblock) or shared_day:
			return "matches"
		if known_home != "" and vblock != "" and known_home != vblock and person_day_phases.size() >= 2:
			return "contradicts"
		return "unknown"
	# Legacy block-only trace cards: check discovered home/work receipts only.
	var blk: String = str(trace_card.get("block", ""))
	if blk == "":
		return "unknown"
	var l_home: String = ""
	var l_work_blk: String = ""
	for r in receipts:
		if r.get("deleted", false) or person_id not in r.get("subject", []):
			continue
		if r.get("kind", "") == "home":
			l_home = str(r.get("block", ""))
		elif r.get("kind", "") == "work":
			var wloc2: String = str(r.get("loc", ""))
			l_work_blk = str(C.LOCATIONS[wloc2]["block"]) if C.LOCATIONS.has(wloc2) else str(r.get("block", ""))
	if (l_home != "" and l_home == blk) or (l_work_blk != "" and l_work_blk == blk):
		return "matches"
	if l_home != "" and l_work_blk != "":
		return "contradicts"
	return "unknown"

## Do these cards actually say something about the conclusion's subject?
## Uses only discovered `known_receipts` (falling back to `cards`) so filing never leaks hidden truth.
static func bears_on(w, c: Dictionary, cards: Array, known_receipts: Array = []) -> bool:
	if c.get("type", "") == "conflict":
		return c.get("group", []).size() >= 2
	var a: String = c.get("a", "")
	var pool: Array = known_receipts if not known_receipts.is_empty() else cards
	for x in cards:
		if a in x.get("subject", []) or x.get("source", "") == a or a in x.get("data", {}).get("pair", []):
			return true
		if x.get("kind", "") == "trace" and w.by_id.has(a):
			if trace_fit_from_receipts(a, x, pool) != "contradicts":
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
	# A family hint is deliberately weaker than a complete role claim. Q4 allows
	# the player to offer that tentative support for innocence; the evaluator
	# weighs it as fallible speech, rather than declaring a healthy good gift.
	if c["type"] == "good" and cards.any(func(card): return card.get("kind") == "hint" and card.get("source") == a and card.get("subject", []) == [a] and card.get("package", "") in C.HINT_PACKAGES):
		return ""
	for x in cards:
		var src: String = x.get("source", "")
		var via: String = x.get("via", "")
		if src != a and via != a:
			return ""
	return "That only restates what %s has said about themselves. You need evidence from someone or something else." % _nm(w, a)
