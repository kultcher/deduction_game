## The legacy template evaluator (stage 3): how NPCs weighed the player's arguments under the
## native rules. Only the native/fallback paths and the bot use it; retired in purge phases 3-4
## (docs/legacy_retirement_plan.md). The deduction schema moved to sim/deduction.gd; the
## forwarders below keep existing `Argue.*` callers working.
extends RefCounted

const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const Gifts = preload("res://sim/gifts.gd")
const Deduction = preload("res://sim/deduction.gd")

# Deduction schema constants and functions, forwarded for existing callers.
const CONCLUSION_TYPES = Deduction.CONCLUSION_TYPES
const BUILDER = Deduction.BUILDER
const MISREAD = Deduction.MISREAD
const SECRET_CONCLUSIONS = Deduction.SECRET_CONCLUSIONS
const ACCUSING = Deduction.ACCUSING
const TEMPLATE_HINTS = Deduction.TEMPLATE_HINTS
const RELATION_LEAD = Deduction.RELATION_LEAD

static func hints_for(card: Dictionary) -> Array:
	return Deduction.hints_for(card)
static func is_evil_role(r: String) -> bool:
	return Deduction.is_evil_role(r)
static func normalize(c: Dictionary) -> Dictionary:
	return Deduction.normalize(c)
static func group_of(w, cards: Array) -> Array:
	return Deduction.group_of(w, cards)
static func conflict_of(w, cards: Array) -> Dictionary:
	return Deduction.conflict_of(w, cards)
static func _names(w, ids: Array) -> String:
	return Deduction._names(w, ids)
static func from_builder(who: String, verb: String, status: String, night: int = -1, card: int = -1, by_value: bool = false) -> Dictionary:
	return Deduction.from_builder(who, verb, status, night, card, by_value)
static func assertions(card: Dictionary) -> Array:
	return Deduction.assertions(card)
static func _nm(w, id: String) -> String:
	return Deduction._nm(w, id)
static func check(w, cards: Array) -> Dictionary:
	return Deduction.check(w, cards)
static func _clear(w, who: String, c: Dictionary, label: String) -> Dictionary:
	return Deduction._clear(w, who, c, label)
static func conclusion_text(w, c: Dictionary) -> String:
	return Deduction.conclusion_text(w, c)
static func conclusion_key(c: Dictionary) -> String:
	return Deduction.conclusion_key(c)
static func trace_fit_from_receipts(person_id: String, trace_card: Dictionary, receipts: Array) -> String:
	return Deduction.trace_fit_from_receipts(person_id, trace_card, receipts)
static func bears_on(w, c: Dictionary, cards: Array, known_receipts: Array = []) -> bool:
	return Deduction.bears_on(w, c, cards, known_receipts)
static func filing_problem(w, c: Dictionary, supports: Array, board: Array, matched: bool) -> String:
	return Deduction.filing_problem(w, c, supports, board, matched)

static func _mistaken(w, card: int, who: String) -> Dictionary:
	return {"kind": "misled", "label": "%s is misled (card #%d)" % [_nm(w, who), card], "blame": who, "card": card,
		"conclusion": {"type": "misled", "a": who, "card": card}}

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
			if not h.begins_with("night:"):
				return 1
			if s.get("dest", false):
				return -1 if h.substr(6) == s["block"] else 1
			# A sighting can be on the way, not only at the recorded destination.
			return -1 if n.role == "lamplighter" or s["block"] in C.route(n.home_block, h.substr(6)) else 1
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
	var conclusion: Dictionary = e.get("conclusion", {})
	# Firsthand role knowledge constrains explanations about oneself, never other people.
	if conclusion.get("a", "") == n.id and conclusion.get("type", "") == "role" and conclusion.get("role", "") != n.role:
		return 0.0
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
			if Mind.demon_victim(w, who):
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
			elif e.get("base_who", "") != "" and n.suspicion.has(e["base_who"]) and Mind.susp(n, e["base_who"]) > 0.1:
				# Shared presentations keep no `arg:` entry (purge 2c): how far they believe
				# "X is evil" is their shared suspicion of X above the flat 0.1 start.
				cred = clampf((Mind.susp(n, e["base_who"]) - 0.1) * 2.0, 0.0, 1.0)
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
		if C.SHADOW_SELF:
			var sr = Mind.shadow_eval(w, n, func(sh): return evaluate(w, sh, ded, board, scale, false))
			workshop_covered = sr != null and sr.get("workshop", false)
			if target != n and sr != null and sr.has("dialogue"):
				var mine: Dictionary = sr["dialogue"]
				if mine.get("stance", "") == approved["stance"]:
					approved = mine.duplicate(true)
				else:
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
			if workshop_covered:
				if approved.has("voiced_text"):
					var v_shadow: String = Mind.Dialogue.apply_tics(n.id, str(approved["voiced_text"]), delivery_memory)
					lines.append({"speaker": n.id, "name": n.name, "text": v_shadow, "statement": str(approved.get("special", v_shadow))})
				else:
					var canon_ev: String = Mind.Dialogue.decision(n.id, approved, audience, delivery_memory.duplicate(true))["text"]
					lines.append(Presentations.render_evil_override(w, n, c, str(approved.get("stance", "partial")), bool(approved.get("already", false)), times > 0 and delivery_memory.get("decisions", {}).has(JSON.stringify([audience, conclusion_key(c)])), audience, canon_ev, delivery_memory))
			else:
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
	if c["type"] in ["evil", "demon", "minion"] and target != n:
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
	if c["type"] in ["evil", "demon", "minion"] and sg != null and sg.alive and sg.id != c.get("a", "") and sg != n and (h / 16) % 2 == 0:
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

## What accepting a conclusion does to the listener, as ledger effects at weight 1.
static func _eff(effs: Array, target: String, delta: float, why: String, public_why: String = "", conf_scaled: bool = true) -> void:
	effs.append([target, delta, conf_scaled, why, public_why])

static func effects_of(w, c: Dictionary, supports: Array, why: String) -> Array:
	var a: String = c.get("a", "")
	var e: Array = []
	match c["type"]:
		"evil", "minion":
			_eff(e, a, 0.45, why, "the Demonologist made a case against them")
		"demon":
			_eff(e, a, 0.55, why, "the Demonologist made a case against them")
		"good":
			_eff(e, a, -0.4, why)
			_eff(e, "pref:protect:" + a, 0.5, why, "", false)
		"protect":
			_eff(e, "pref:protect:" + a, 1.0, why, "", false)
			_eff(e, a, -0.15, why)
		"spare":
			_eff(e, "pref:spare:" + a, 1.0, why, "", false)
			_eff(e, a, -0.15, why)
		"role":
			_eff(e, "role:%s:%s" % [a, c["role"]], 1.0, why, "", false)
			if is_evil_role(c["role"]):
				_eff(e, a, 0.5, why, "the Demonologist made a case they're one of the demon's")
				return e
			_eff(e, a, -0.1, why)
			# Believing a's claim makes anyone else claiming that gift a liar (now or later).
			_eff(e, "rivals:%s:%s" % [c["role"], a], 0.3, why + " (so a rival claim is false)", "their claim clashes with someone I believe")
		"notrole":
			_eff(e, a, 0.3, why, "the Demonologist showed their claim is false")
		"lied":
			_eff(e, a, 0.3, why, "the Demonologist caught them in a lie")
			for card in supports:
				if card["n"] == c.get("card", -1) and card.get("kind", "") == "info":
					_eff(e, "disc:%s:%d" % [card["source"], card.get("day", -1)], 0.5, why, "", false)
		"misled", "unreliable":
			var night: int = c.get("night", -1)
			if night < 0 and c.has("card"):
				for card in supports:
					if card["n"] == c["card"] and card.get("kind", "") == "info":
						night = card.get("day", -1)
			_eff(e, "disc:%s:%s" % [a, str(night) if night >= 0 else "*"], 0.8 if c["type"] == "misled" else 0.5, why, "", false)
			if c["type"] == "unreliable":
				_eff(e, a, 0.12, why)
		"notdemon":
			_eff(e, a, -0.25, why)
		"truthful":
			_eff(e, a, -0.15, why)
		"conflict":
			var grp: Array = c.get("group", [])
			for g in grp:
				_eff(e, "disc:%s:*" % g, 0.4 / maxf(1.0, grp.size()), why, "", false)
				_eff(e, g, 0.05, why)
		"suspicious":
			# A weak push: pressure, not proof.
			_eff(e, a, 0.15, why, "the Demonologist finds them suspicious")
		"secret":
			_eff(e, a, -0.12, why)
		"marked", "red_herring":
			_eff(e, a, -0.3 if c["type"] == "marked" else -0.4, why)
		"secret_mod":
			if c.get("mod", "") == "delusional":
				_eff(e, "disc:%s:*" % a, 0.7, why, "", false)
			else:
				_eff(e, a, -0.15, why)
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
	var c_meta: Dictionary = c.duplicate(true)
	if c_meta.get("type", "") in ["lied", "misled", "unreliable"] and int(c_meta.get("night", -1)) < 0 and c_meta.has("card"):
		for sc in supports:
			if sc.get("n", -2) == c_meta["card"] and sc.get("kind", "") == "info":
				c_meta["night"] = sc.get("day", -1)
	var h = Mind.ledger_hear(w, n, ledger_id, [], base * (0.5 + n.trust), [],
		{"kind": "arg", "base": base, "text": conclusion_text(w, c), "said": said, "supports": sup, "conclusion": c_meta,
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
