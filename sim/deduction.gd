## The conclusion vocabulary (types, normalising, text, keys, filing checks) and card
## assertions, used by the board, the Case Workshop canvas and presentations. The old
## two-card template matcher and its `link` / `conclude` commands were retired in legacy
## purge phase 4 (docs/legacy_retirement_plan.md): cases are built in the Workshop.
extends RefCounted

const C = preload("res://sim/content.gd")

## Conclusion types. The player builds them as "<name> <is / is not / should be> <status>".
const CONCLUSION_TYPES = ["good", "evil", "demon", "minion", "notdemon", "role", "notrole", "lied", "truthful", "misled", "unreliable", "protect", "spare",
	"suspicious", "secret", "marked", "red_herring", "secret_mod"]

## Conclusions that speak against someone (as opposed to for them).
const ACCUSING = ["evil", "demon", "minion", "lied", "notrole", "unreliable", "suspicious"]

static func is_evil_role(r: String) -> bool:
	return C.ROLES.has(r) and C.ROLES[r].get("align", "good") == "evil"

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

# ---------------------------------------------------------------- names

static func _nm(w, id: String) -> String:
	return w.by_id[id].name if w.by_id.has(id) else id

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
