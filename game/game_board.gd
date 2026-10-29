## Case-board card management, corroboration, filtering, timeline assembly, and
## deduction linking/filing/deletion for `Game`.
##
## Extracted from `game/game.gd`; `Game` retains thin forwarding methods so all
## UI panels (`ui/`) and test suites can continue calling `g.<fn>(...)` unchanged.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Argue = preload("res://sim/argue.gd")
const CardModel = preload("res://game/card_model.gd")


## Using a confidential card at the meeting breaks your word to whoever told you: a trust
## blow (like a broken offer), unless they've since gone public themselves.
static func _break_confidences(g, nums: Array) -> void:
	for num in nums:
		if not g.confidences.has(num):
			continue
		var n = g.w.by_id[g.confidences[num]]
		g.confidences.erase(num)
		if not n.alive or n.claim_public:
			continue
		# 0.05 for the open, 0.15 typical, 0.25 for the very private.
		var loss: float = Tuning.Trust.CONFIDENCE_BROKEN_BASE + Tuning.Trust.CONFIDENCE_BROKEN_PRIVACY * n.traits.get("privacy", 0.5)
		Mind.set_trust(g.w, n, n.trust - loss, "the Demonologist broke my confidence (card #%d) at the meeting" % num)
		g.w.dlog.add("player_confidence_broken", "player", n.id, {"card": num})
		g._narr("%s stiffens. You promised to keep that between you." % n.name)


static func _facts(g, facts: Array) -> void:
	for f in facts:
		if f.get("silent", false):
			_silent_corroboration(g, f)
			continue
		var num: int = add_card(g, f)
		if f.get("confidential", "") != "":
			g.confidences[num] = f["confidential"]
		g._ev({"k": "card", "n": num})


## Public setup facts (where everyone lives and works) mint hidden profile receipts
## rather than main-board cards, keeping the Case Board uncluttered while Workshop
## Profile Info nodes cite exact normalized original receipts.
static func _home_cards(g) -> void:
	var people: Array = g.w.npcs.duplicate()
	people.sort_custom(func(a, b): return a.name < b.name)
	for n in people:
		add_profile_receipt(g, {
			"kind": "home",
			"subject": [n.id],
			"block": n.home_block,
			"day": 0,
			"phase": 0,
			"source": "town",
			"class": "concrete",
			"text": "%s lives on %s." % [n.name, C.block_name(n.home_block)],
		})
		add_profile_receipt(g, {
			"kind": "work",
			"subject": [n.id],
			"loc": n.work,
			"block": g.w.loc_block(n.work),
			"work_phases": n.work_phases.duplicate(),
			"occupation": n.occupation,
			"day": 0,
			"phase": 0,
			"source": "town",
			"class": "concrete",
			"text": "%s works %s at %s." % [n.name, C.phase_list(n.work_phases), g.w.loc_name(n.work)],
		})


static func add_profile_receipt(g, fact: Dictionary) -> int:
	if fact.has("text"):
		fact = fact.duplicate()
		fact["text"] = C.natural_nights(fact["text"])
	var key: String = fact.get("text", "")
	var disc: Dictionary = _disclosure(g, fact)
	if fact.get("source", "") == "town":
		disc = {"day": 0, "phase": 0, "via": "town", "public": true}
	const PROFILE_RECEIPT_BASE = 10000
	if g._profile_card_keys.has(key):
		var existing_num: int = g._profile_card_keys[key]
		_disclose(g.profile_receipts[-existing_num - PROFILE_RECEIPT_BASE - 1], disc)
		return existing_num
	var fk: String = Mind.fact_id(fact) if fact.get("kind", "") in CardModel.MERGE_KINDS else ""
	if fk != "" and g._profile_fact_keys.has(fk):
		var n0: int = g._profile_fact_keys[fk]
		_disclose(g.profile_receipts[-n0 - PROFILE_RECEIPT_BASE - 1], disc)
		g._profile_card_keys[key] = n0
		return n0
	var card: Dictionary = fact.duplicate()
	card["n"] = -(PROFILE_RECEIPT_BASE + g.profile_receipts.size() + 1)
	if not card.has("day"):
		card["day"] = g.w.day
	if not card.has("class"):
		card["class"] = Mind.evidence_class(card)
	card["when"] = CardModel.when(card, g.w.day, _phase_now(g))
	card["learned"] = [disc]
	card["view"] = "profile"
	card["profile_receipt"] = true
	g.profile_receipts.append(card)
	g._profile_card_keys[key] = card["n"]
	if fk != "":
		g._profile_fact_keys[fk] = card["n"]
	return card["n"]


static func receipt_by_number(g, num: int) -> Dictionary:
	const PROFILE_RECEIPT_BASE = 10000
	if num >= 1 and num <= g.board.size():
		return g.board[num - 1]
	var idx: int = -num - PROFILE_RECEIPT_BASE - 1
	if idx >= 0 and idx < g.profile_receipts.size():
		return g.profile_receipts[idx]
	return {}


static func all_receipts(g) -> Array:
	return g.board + g.profile_receipts


static func profile_receipts_for(g, id: String, facet: String = "") -> Array:
	var allowed_kinds: Array = {
		"": ["home", "work", "haunt", "trait", "bond"],
		"home_work": ["home", "work"],
		"haunts": ["haunt"],
		"personality": ["trait"],
		"bonds": ["bond"],
	}.get(facet, [])
	return g.profile_receipts.filter(func(c): return c.get("kind", "") in allowed_kinds and id in c.get("subject", []))


static func add_card(g, fact: Dictionary) -> int:
	if fact.has("text"):
		fact = fact.duplicate()
		fact["text"] = C.natural_nights(fact["text"])
	var key: String = fact.get("text", "")
	var disc: Dictionary = _disclosure(g, fact)
	if g._card_keys.has(key):
		_disclose(g.board[g._card_keys[key] - 1], disc)
		return g._card_keys[key]
	# The same fact reaching you again (told privately, then publicly; relayed by someone
	# else) is one card with another disclosure, not a second card.
	var fk: String = Mind.fact_id(fact) if fact.get("kind", "") in CardModel.MERGE_KINDS else ""
	if fk != "" and g._fact_keys.has(fk):
		var n0: int = g._fact_keys[fk]
		_disclose(g.board[n0 - 1], disc)
		g._card_keys[key] = n0
		return n0
	var card: Dictionary = fact.duplicate()
	card["n"] = g.board.size() + 1
	if not card.has("day"):
		card["day"] = g.w.day
	if not card.has("class"):
		card["class"] = Mind.evidence_class(card)
	card["when"] = CardModel.when(card, g.w.day, _phase_now(g))
	card["learned"] = [disc]
	card["view"] = CardModel.view_of(card)
	g.board.append(card)
	g._card_keys[key] = card["n"]
	if fk != "":
		g._fact_keys[fk] = card["n"]
	_link_corroboration(g, card)
	return card["n"]


# ---------------------------------------------------------------- corroboration

## What a card says happened, independent of who said it: "who was where, when" for each
## person it places, and "these two talked" for a conversation. Two cards from different
## sources that share a key back each other up.
static func core_keys(card: Dictionary) -> Array:
	var k: String = card.get("kind", "")
	if not (k in ["sighting", "conversation"]):
		return []
	var out: Array = []
	var subj: Array = card.get("subject", [])
	for who in subj:
		out.append("at:%s|%d|%d|%s" % [who, card.get("day", -1), card.get("phase", -1), card.get("block", "")])
	if k == "conversation" and subj.size() == 2:
		var pr: Array = subj.duplicate()
		pr.sort()
		out.append("talk:%s|%d|%d" % [",".join(PackedStringArray(pr)), card.get("day", -1), card.get("phase", -1)])
	return out


static func _corroborate(card: Dictionary, src: String) -> void:
	if src == "" or src == card.get("source", "") or src in card.get("subject", []):
		return
	var cb: Array = card.get("corroborated_by", [])
	if not (src in cb):
		cb.append(src)
	card["corroborated_by"] = cb


static func _link_corroboration(g, card: Dictionary) -> void:
	var mine: Array = core_keys(card)
	if mine.is_empty():
		return
	for other in g.board:
		if other == card or other.get("deleted", false) or other.get("source", "") == card.get("source", ""):
			continue
		var theirs: Array = core_keys(other)
		if theirs.any(func(x): return x in mine):
			_corroborate(other, card.get("source", ""))
			_corroborate(card, other.get("source", ""))


## Cards you've already got for a conversation (for "don't tell me what I saw myself").
static func seen_pairs(g) -> Dictionary:
	var out = {}
	for c in g.board:
		if c.get("kind", "") == "conversation" and c.get("source", "") == "player":
			for k in core_keys(c):
				if k.begins_with("talk:"):
					out[k] = c["n"]
	return out


## A fact an NPC passes over in silence because you saw it yourself: no new card, they're
## just recorded as backing yours.
static func _silent_corroboration(g, f: Dictionary) -> void:
	var keys: Array = core_keys(f)
	for c in g.board:
		if c.get("deleted", false):
			continue
		if core_keys(c).any(func(x): return x in keys):
			_corroborate(c, f.get("source", ""))


## The current time slot as the board counts it (the meeting and the night belong to the
## evening and night of the day they're in).
static func _phase_now(g) -> int:
	return C.NIGHT if g.state == "night" else g.w.phase


## When, how and from whom you heard this fact (public = at a town meeting).
static func _disclosure(g, fact: Dictionary) -> Dictionary:
	var via: String = fact.get("via", fact.get("source", ""))
	return {"day": g.w.day, "phase": _phase_now(g), "via": via, "public": g.state in ["meeting", "nomination"]}


static func _disclose(card: Dictionary, disc: Dictionary) -> void:
	var ls: Array = card.get("learned", [])
	for d in ls:
		if d["day"] == disc["day"] and d["phase"] == disc["phase"] and d["via"] == disc["via"] and d["public"] == disc["public"]:
			return
	ls.append(disc)
	card["learned"] = ls


## Board hint: pairs of cards (among the most recent) that a template would recognise,
## so you know a link is there to be made. Doesn't say what it shows.
static func find_links(g, limit: int = 40) -> Array:
	var pool: Array = g.board.filter(func(c): return not c.get("deleted", false) and not (c["kind"] in ["home", "haunt"]))
	pool = pool.slice(maxi(0, pool.size() - limit))
	var found: Array = []
	var seen = {}
	for i in range(pool.size()):
		for j in range(i + 1, pool.size()):
			var res: Dictionary = Argue.check(g.w, [pool[i], pool[j]])
			for m in res["matches"]:
				var key = str(m["cards"])
				if not seen.has(key):
					seen[key] = true
					found.append({"cards": m["cards"], "relation": m.get("relation", "contradiction")})
	return found


# ---------------------------------------------------------------- case work (stage 3)

## Filter the board by a text query. Terms joined with "+" must all match ("greta+night"):
## a person (by, about or via), a block or place, a kind or class, d2 / n1 (a day or a
## night), "night" / "day", or any text.
static func filter_cards(g, filter: String) -> Array:
	var f = filter.strip_edges().to_lower()
	var base: Array = g.board.filter(func(c): return not c.get("deleted", false) and (g.show_hidden or not c.get("hidden", false)))
	if f == "":
		return base
	var terms: Array = Array(f.split("+", false)).map(func(x): return x.strip_edges()).filter(func(x): return x != "")
	var out: Array = base
	for t in terms:
		out = _filter_term(g, out, t)
	return out


static func _filter_term(g, cards: Array, f: String) -> Array:
	# "-sighting" (or any term with a leading minus) leaves those cards out.
	if f.begins_with("-") and f.length() > 1:
		var drop: Array = _filter_term(g, cards, f.substr(1)).map(func(c): return c["n"])
		return cards.filter(func(c): return not (c["n"] in drop))
	var blk: String = g.find_block(f)
	var lc: String = g.find_location(f) if blk == "" else ""
	var person = g.find_npc(f, true)
	var out: Array = []
	for c in cards:
		var ok = false
		var is_night: bool = c.get("phase", -1) == C.NIGHT or c["kind"] in ["vigil", "alibi"] or (c.get("when", {}).get("phase", -1) == C.NIGHT)
		if c["kind"] == f or c.get("class", "") == f:
			ok = true
		elif f in ["night", "nights"]:
			ok = is_night
		elif f in ["day", "daytime"]:
			ok = not is_night and c.get("phase", -1) >= 0
		elif person != null and (person.id in c.get("subject", []) or c.get("source", "") == person.id or c.get("via", "") == person.id or person.id in CardModel.about(c)):
			ok = true
		elif blk != "" and (c.get("block", "") == blk or g.w.loc_block(c.get("loc", "")) == blk):
			ok = true
		elif lc != "" and c.get("loc", "") == lc:
			ok = true
		elif f.length() >= 2 and f[0] in ["d", "n"] and f.substr(1).is_valid_int():
			var num: int = f.substr(1).to_int()
			ok = c.get("day", -99) == num and ((f[0] == "n") == is_night)
		elif f in c["text"].to_lower():
			ok = true
		if ok:
			out.append(c)
	return out


## Link cards: run the contradiction templates. Returns the check result and remembers it.
static func link_cards(g, nums: Array) -> Dictionary:
	var cards: Array = []
	for x in nums:
		if x >= 1 and x <= g.board.size():
			cards.append(g.board[x - 1])
	var res: Dictionary = Argue.check(g.w, cards)
	var options: Array = []
	for m in res["matches"]:
		if m.get("relation", "contradiction") == "contradiction":
			var grp: Array = Argue.group_of(g.w, cards.filter(func(x): return x["n"] in m["cards"]))
			if grp.size() >= 2:
				var cc = {"type": "conflict", "a": "", "group": grp}
				options.append({"match": m, "expl": {"id": 0, "kind": "conflict", "blame": "", "conclusion": cc,
					"label": "Something doesn't add up (no explanation chosen): one of %s is misled or lying" % Argue._names(g.w, grp)}})
		for e in m["explanations"]:
			# Alternatives the town weighs, but that nothing in these cards supports, aren't
			# offered for filing.
			if not e.get("rival_only", false):
				options.append({"match": m, "expl": e})
	g.last_link = {"cards": nums.duplicate(), "result": res, "options": options}
	g.w.dlog.add("player_link", "player", "", {"cards": nums, "matches": res["matches"].map(func(m): return m["template"]),
		"near": res["near"]}, "matched" if not res["matches"].is_empty() else "no template matched (flag for template work)")
	return g.last_link


## File a deduction card. conclusion: {type, a, role?, night?, card?}. Returns the card
## number, or -1 if refused (reason in last_error).
static func file_deduction(g, conclusion: Dictionary, supports: Array, match_info: Dictionary = {}, chosen: int = 0, workshop_filing: bool = false) -> int:
	conclusion = Argue.normalize(conclusion.duplicate())
	var pool: Array = all_receipts(g)
	var cards: Array = pool.filter(func(x): return x["n"] in supports and not x.get("deleted", false))
	# The same conclusion from the same cards gets the same footing however it was built:
	# if a template among the supports offers this conclusion, use it.
	if conclusion.get("type", "") == "conflict":
		if conclusion.get("group", []).is_empty():
			conclusion["group"] = Argue.group_of(g.w, cards)
		if match_info.is_empty():
			for m in Argue.check(g.w, cards)["matches"]:
				if m.get("relation", "contradiction") == "contradiction":
					match_info = m
					chosen = 0
					break
	elif match_info.is_empty() and not supports.is_empty():
		for m in Argue.check(g.w, cards)["matches"]:
			for e in m["explanations"]:
				if Argue.conclusion_key(Argue.normalize(e["conclusion"].duplicate())) == Argue.conclusion_key(conclusion):
					match_info = m
					chosen = e["id"]
					break
			if not match_info.is_empty():
				break
	g.last_error = Argue.filing_problem(g.w, conclusion, supports, pool, not match_info.is_empty())
	if g.last_error != "":
		g.w.dlog.add("deduction_refused", "player", conclusion.get("a", ""), {"conclusion": conclusion, "supports": supports}, g.last_error)
		return -1
	var rank = {"speech": 0, "circumstantial": 1, "concrete": 2}
	var cls = "concrete"
	for x in supports:
		var rec: Dictionary = receipt_by_number(g, x)
		var cc: String = rec.get("class", "circumstantial")
		if rank.get(cc, 1) < rank[cls]:
			cls = cc
	if match_info.is_empty() and rank[cls] > 1:
		cls = "circumstantial" # an inference is never stronger than circumstantial on its own
	# Unfounded = the cards don't actually bear on the person (not merely "no template").
	var unfounded: bool = match_info.is_empty() and not Argue.bears_on(g.w, conclusion, cards)
	var basis = ""
	if not match_info.is_empty():
		basis = " (from #%s: %s)" % [", #".join(PackedStringArray(match_info["cards"].map(func(x): return str(x)))), match_info["text"]]
	else:
		var labels: Array = supports.map(func(x): return ("P%d" % (-x - 10000)) if x <= -10000 else ("#%d" % x))
		basis = " (because %s%s)" % [", ".join(PackedStringArray(labels)), "; unfounded" if unfounded else "; your inference"]
	var subj: Array = conclusion.get("group", []).duplicate() if conclusion.get("type", "") == "conflict" else ([conclusion["a"]] if conclusion.has("a") else [])
	var near = ""
	if unfounded:
		var nr: Array = Argue.check(g.w, cards)["near"]
		if not nr.is_empty():
			near = nr[0]
	var card = {
		"kind": "deduction",
		"subject": subj,
		"source": "player",
		"class": cls,
		"conclusion": conclusion,
		"supports": supports.duplicate(),
		"template": match_info.get("template", ""),
		"explanations": match_info.get("explanations", []),
		"chosen": chosen,
		"unfounded": unfounded,
		"near": near,
		"relation": match_info.get("relation", ""),
		"text": "Deduction: %s%s [basis: %s]." % [Argue.conclusion_text(g.w, conclusion), basis, cls],
	}
	if workshop_filing:
		card.text += " [Workshop filing %d]" % (g.board.size() + 1)
	var n: int = add_card(g, card)
	g.w.dlog.add("deduction", "player", conclusion.get("a", ""), {"card": n, "conclusion": conclusion, "supports": supports,
		"template": card["template"], "unfounded": unfounded, "class": cls}, card["text"])
	return n


## Parse "conclude <name> <is | is not | should be> <status> [night N] [about #N] [because <#> ...]".
static func _parse_conclusion(g, rest: String) -> Dictionary:
	var usage = "Usage: conclude <name> <is | is not | should be> <status> [night N] [because <card#> ...]. Status: good, evil, the demon, a gift (seer, poisoner...), lying, misled, misled or lying, suspicious, hiding a secret, Marked, the Seer's red herring, Delusional, a Secret Lover, a Sleepwalker; should be protected / spared."
	var text = " " + rest.to_lower().strip_edges() + " "
	var supports: Array = []
	var bi = text.find(" because ")
	if bi >= 0:
		for q in text.substr(bi + 9).split(" ", false):
			var num = q.trim_prefix("#").to_int()
			if num >= 1 and num <= g.board.size() and not g.board[num - 1].get("deleted", false):
				supports.append(num)
		text = text.substr(0, bi + 1)
	var night = -1
	var ni = text.find(" night ")
	if ni >= 0:
		var after = text.substr(ni + 7).split(" ", false)
		if after.size() > 0 and after[0].is_valid_int():
			night = after[0].to_int()
		text = text.substr(0, ni + 1)
		if text.ends_with(" on "):
			text = text.substr(0, text.length() - 3)
	var card = -1
	var ai = text.find(" about #")
	if ai >= 0:
		card = text.substr(ai + 8).split(" ", false)[0].to_int()
		text = text.substr(0, ai + 1)
	var words = text.split(" ", false)
	if words.size() < 3:
		return {"error": usage}
	var group_lead = 0
	if words[0] in ["someone", "somebody"]:
		group_lead = 1
	elif words.size() > 3 and words[0] == "one" and words[1] == "of" and words[2] in ["these", "them", "those"]:
		group_lead = 3
	if group_lead > 0:
		if supports.is_empty() and not g.last_link.is_empty():
			supports = g.last_link["cards"].duplicate()
		var tail = " ".join(words.slice(group_lead)).strip_edges()
		if not (tail in ["is misled or lying", "are misled or lying", "is lying or misled", "doesn't add up", "is wrong"]):
			return {"error": "For a group, say: conclude one of these is misled or lying because <cards>."}
		var gcards: Array = g.board.filter(func(x): return x["n"] in supports)
		return {"conclusion": Argue.conflict_of(g.w, gcards), "supports": supports}
	var who = g.find_npc(words[0], true)
	if who == null:
		return {"error": "Who is '%s'?" % words[0]}
	var verb = ""
	var rest_i = 1
	if words[1] == "should" and words.size() > 2 and words[2] == "be":
		verb = "should be"
		rest_i = 3
	elif words[1] in ["isnt", "isn't"] or (words[1] == "is" and words.size() > 2 and words[2] == "not"):
		verb = "is not"
		rest_i = 2 if words[1] != "is" else 3
	elif words[1] == "is":
		verb = "is"
		rest_i = 2
	else:
		return {"error": usage}
	var status = " ".join(words.slice(rest_i)).strip_edges().trim_prefix("the ").strip_edges()
	if status == "demon":
		status = "the demon"
	if status in ["spared", "spared from execution"]:
		status = "spared from execution"
	var role: String = g.find_role(status)
	if role != "" and role != "demon":
		status = role
	match status:
		"a secret", "hiding a secret", "a secret (innocent)":
			status = "hiding a secret"
		"red herring", "the red herring", "the seer's red herring", "a red herring":
			status = "the Seer's red herring"
		"a lover", "a secret lover", "lover", "lovers":
			status = "a Secret Lover"
		"a sleepwalker", "sleepwalker":
			status = "a Sleepwalker"
	var c = Argue.from_builder(who.id, verb, status, night, card)
	if c.is_empty():
		return {"error": "'%s %s' isn't something you can conclude. %s" % [verb, status, usage]}
	if supports.is_empty() and not g.last_link.is_empty():
		supports = g.last_link["cards"].duplicate()
	if c["type"] in ["lied", "unreliable", "truthful"] and not c.has("card"):
		for x in supports:
			if g.board[x - 1].get("source", "") == who.id:
				c["card"] = x
				break
	return {"conclusion": c, "supports": supports}


static func _link_command(g, rest: String) -> void:
	var nums: Array = []
	for q in rest.split(" ", false):
		var num = q.trim_prefix("#").to_int()
		if num >= 1 and num <= g.board.size() and not (num in nums):
			nums.append(num)
	if nums.size() < 1 or nums.size() > 3:
		g._err("Usage: link <card#> <card#> [card#]   (1-3 cards; see 'board')")
		return
	var lk: Dictionary = link_cards(g, nums)
	var res: Dictionary = lk["result"]
	if res["matches"].is_empty():
		g._narr("Nothing links those cards: no conflict, corroboration or inference the town would recognise.")
		for r in res["near"].slice(0, 2):
			g._narr("  Close, but " + r)
		g._prompt("You can still argue from them: 'conclude <name> is <status> because <cards>'. If the cards bear on that person it's your own inference; if not, it's unfounded.")
		return
	for m in res["matches"]:
		g._narr("%s %s" % [Argue.RELATION_LEAD[m.get("relation", "contradiction")], m["text"]])
	var k = 0
	for o in lk["options"]:
		k += 1
		g._narr("  %d. %s" % [k, o["expl"]["label"]])
	g._prompt("'conclude <number>' to file the explanation you believe, or write your own: 'conclude <name> is <status> because <cards>'.")


static func _conclude_command(g, rest: String) -> void:
	var r = rest.strip_edges()
	if r.is_valid_int() and not g.last_link.is_empty():
		var k = r.to_int()
		var opts: Array = g.last_link["options"]
		if k < 1 or k > opts.size():
			g._err("Pick one of the numbered explanations from your last 'link'.")
			return
		var o: Dictionary = opts[k - 1]
		var n: int = file_deduction(g, o["expl"]["conclusion"], o["match"]["cards"], o["match"], o["expl"]["id"])
		if n < 0:
			g._err(g.last_error)
			return
		g._narr("Filed.")
		g._ev({"k": "card", "n": n})
		return
	var p: Dictionary = _parse_conclusion(g, r)
	if p.has("error"):
		g._err(p["error"])
		return
	var n2: int = file_deduction(g, p["conclusion"], p["supports"])
	if n2 < 0:
		g._err(g.last_error)
		return
	var d2: Dictionary = g.board[n2 - 1]
	g._narr("Filed%s." % (" (unfounded: those cards don't bear on them)" if d2["unfounded"] else
		(" (backed by: %s)" % d2["template"]) if d2["template"] != "" else " (your inference)"))
	g._ev({"k": "card", "n": n2})


## Hide a card from views (any card), or delete one of your own deductions.
static func hide_card(g, num: int, on: bool) -> String:
	if num < 1 or num > g.board.size() or g.board[num - 1].get("deleted", false):
		return "No such card."
	g.board[num - 1]["hidden"] = on
	return "Card #%d %s." % [num, "hidden ('showhidden' to see hidden cards)" if on else "shown again"]


static func delete_deduction(g, num: int) -> String:
	if num < 1 or num > g.board.size() or g.board[num - 1]["kind"] != "deduction" or g.board[num - 1].get("deleted", false):
		return "You can only delete your own deductions."
	g.board[num - 1]["deleted"] = true
	g.w.dlog.add("deduction_deleted", "player", "", {"card": num})
	return "Deduction #%d deleted." % num


## Timeline: who was where, by phase, from your board. * = you saw it, ~ = heard.
static func timeline_data(g, filter: String = "") -> Dictionary:
	var cols: Array = [{"label": "N0", "day": 0, "phase": C.NIGHT}]
	for d in range(1, g.w.day + 1):
		for p in [C.MORNING, C.AFTERNOON, C.EVENING, C.NIGHT]:
			if d == g.w.day and p > g.w.phase and g.state != "night":
				break
			cols.append({"label": ("N%d" % d) if p == C.NIGHT else "D%d%s" % [d, C.PHASES[p].substr(0, 1)], "day": d, "phase": p})
	var cards: Array = filter_cards(g, filter) if filter != "" else g.board
	var rows = {}
	for n in g.w.npcs:
		rows[n.id] = {}
	for c in cards:
		for a in Argue.assertions(c):
			var who: String = a.get("who", "")
			if not rows.has(who):
				continue
			var key = ""
			var val = ""
			match a["t"]:
				"at":
					key = "%d:%d" % [a["day"], a["phase"]]
					val = _abbr(a["block"])
				"out":
					key = "%d:%d" % [a["night"], C.NIGHT]
					val = _abbr(a["block"])
				"home":
					key = "%d:%d" % [a["night"], C.NIGHT]
					val = "hm"
				"killed":
					key = "%d:%d" % [a["night"], C.NIGHT]
					val = "XX"
				_:
					continue
			var confirmed: bool = a.get("src", "") == "player"
			if not rows[who].has(key):
				rows[who][key] = []
			rows[who][key].append({"val": val, "confirmed": confirmed, "card": c["n"]})
	return {"cols": cols, "rows": rows}


static func _abbr(b: String) -> String:
	return {"square": "Sq", "market": "Mk", "docks": "Dk", "hill": "Hl"}.get(b, "??")


static func _timeline(g, filter: String) -> String:
	var td: Dictionary = timeline_data(g, filter)
	var out = PackedStringArray()
	var head = "%-12s" % ""
	for col in td["cols"]:
		head += "%-7s" % col["label"]
	out.append(head)
	for n in g.w.npcs:
		var line = "%-12s" % (n.name if n.alive else n.name + "†")
		for col in td["cols"]:
			var key = "%d:%d" % [col["day"], col["phase"]]
			var cell = ""
			var vals: Array = td["rows"][n.id].get(key, [])
			var shown = {}
			for v in vals:
				var tag = v["val"] + ("" if v["confirmed"] else "~")
				if not shown.has(tag):
					shown[tag] = true
					cell += ("/" if cell != "" else "") + tag
			line += "%-7s" % (cell if cell != "" else ".")
		out.append(line)
	out.append("Sq Square, Mk Market, Dk Docks, Hl Chapel Hill, hm home, XX killed. No mark = you saw it; ~ = someone told you.")
	return "\n".join(out)
