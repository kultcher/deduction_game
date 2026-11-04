## Case-board card management, corroboration, filtering, timeline assembly, and
## deduction linking/filing/deletion for `Game`.
##
## Extracted from `game/game.gd`; `Game` retains thin forwarding methods so all
## UI panels (`ui/`) and test suites can continue calling `g.<fn>(...)` unchanged.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Deduction = preload("res://sim/deduction.gd")
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


static func _deprecate_muddled_matches(g, src_id: String, role: String, day_val: int, muddled_data = null, superseded_by_num: int = 0, real_data = null) -> void:
	var Muddler = preload("res://sim/muddler.gd")
	for c in g.board:
		if c.get("deleted", false) or c.get("deprecated", false) or c.get("tavern_gossip", false):
			continue
		if str(c.get("kind", "")) != "info" or str(c.get("source", "")) != src_id or str(c.get("role", "")) != role or int(c.get("day", -2)) != day_val:
			continue
		if str(c.get("via", src_id)) == src_id:
			continue
		if muddled_data is Dictionary and c.get("data", {}) == muddled_data:
			Muddler.deprecate_card(c, src_id, superseded_by_num)
		elif real_data is Dictionary and c.get("data", {}) != real_data:
			Muddler.deprecate_card(c, src_id, superseded_by_num)

static func _facts(g, facts: Array) -> void:
	for f in facts:
		if f.get("kind", "") == "deprecate_muddle":
			_deprecate_muddled_matches(g, str(f.get("source", "")), str(f.get("role", "")), int(f.get("day", -1)), f.get("muddled_data", null))
			continue
		if f.get("silent", false):
			_silent_corroboration(g, f)
			continue
		var num: int = add_card(g, f)
		if f.get("kind", "") == "info" and str(f.get("via", f.get("source", ""))) == str(f.get("source", "")) and str(f.get("source", "")) not in ["", "rumour", "player"]:
			_deprecate_muddled_matches(g, str(f.get("source", "")), str(f.get("role", "")), int(f.get("day", -1)), null, num, f.get("data", {}))
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
	if src in ["", "rumour"] or card.get("tavern_gossip", false) or src == card.get("source", "") or src in card.get("subject", []):
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


## File a deduction card (the Case Workshop files its cases through this).
## conclusion: {type, a, role?, night?, card?}. Returns the card number, or -1 if
## refused (reason in last_error).
static func file_deduction(g, conclusion: Dictionary, supports: Array, workshop_filing: bool = false) -> int:
	conclusion = Deduction.normalize(conclusion.duplicate())
	var pool: Array = all_receipts(g)
	var cards: Array = pool.filter(func(x): return x["n"] in supports and not x.get("deleted", false))
	if conclusion.get("type", "") == "conflict" and conclusion.get("group", []).is_empty():
		conclusion["group"] = Deduction.group_of(g.w, cards)
	g.last_error = Deduction.filing_problem(g.w, conclusion, supports, pool, false)
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
	if rank[cls] > 1:
		cls = "circumstantial" # an inference is never stronger than circumstantial on its own
	# Unfounded = the cards don't actually bear on the person.
	var active_pool: Array = pool.filter(func(x): return not x.get("deleted", false))
	var unfounded: bool = not Deduction.bears_on(g.w, conclusion, cards, active_pool)
	var labels: Array = supports.map(func(x): return ("P%d" % (-x - 10000)) if x <= -10000 else ("#%d" % x))
	var basis = " (because %s%s)" % [", ".join(PackedStringArray(labels)), "; unfounded" if unfounded else "; your inference"]
	var subj: Array = conclusion.get("group", []).duplicate() if conclusion.get("type", "") == "conflict" else ([conclusion["a"]] if conclusion.has("a") else [])
	var card = {
		"kind": "deduction",
		"subject": subj,
		"source": "player",
		"class": cls,
		"conclusion": conclusion,
		"supports": supports.duplicate(),
		"unfounded": unfounded,
		"text": "Deduction: %s%s [basis: %s]." % [Deduction.conclusion_text(g.w, conclusion), basis, cls],
	}
	if workshop_filing:
		card.text += " [Workshop filing %d]" % (g.board.size() + 1)
	var n: int = add_card(g, card)
	g.w.dlog.add("deduction", "player", conclusion.get("a", ""), {"card": n, "conclusion": conclusion, "supports": supports,
		"unfounded": unfounded, "class": cls}, card["text"])
	return n


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
		for a in Deduction.assertions(c):
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
			var rumour: bool = c.get("tavern_gossip", false) or a.get("src", "") == "rumour"
			if not rows[who].has(key):
				rows[who][key] = []
			rows[who][key].append({"val": val, "confirmed": confirmed, "rumour": rumour, "card": c["n"]})
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
				var suffix: String = "" if v["confirmed"] else ("?" if v.get("rumour", false) else "~")
				var tag = v["val"] + suffix
				if not shown.has(tag):
					shown[tag] = true
					cell += ("/" if cell != "" else "") + tag
			line += "%-7s" % (cell if cell != "" else ".")
		out.append(line)
	out.append("Sq Square, Mk Market, Dk Docks, Hl Chapel Hill, hm home, XX killed. No mark = you saw it; ~ = someone told you; ? = tavern rumour.")
	return "\n".join(out)
