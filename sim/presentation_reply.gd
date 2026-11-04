## How a listener answers the player's presentation, around the shared model's judgement
## (legacy purge phase 4a, docs/legacy_retirement_plan.md). The Workshop judges evidence
## (`w.workshop_present`, WorkshopPresentation). This module does what it doesn't:
##   - repeat bookkeeping (`n.heard`), so a case told twice is recognised;
##   - evil listeners' masked answers, and their good self via the shadow (step 2);
##   - social speech: protect / spare preferences and bare beliefs with no evidence.
##     These are never evidence (decision Q4); they only feed the listener's own
##     protect / spare / believed-role preferences through an `arg:` ledger entry.
## There is no template evaluator behind it any more: a presentation the Workshop cannot
## judge is blocked at the gate (GamePresentation._presentation_gate) with its reason.
extends RefCounted

const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const Deduction = preload("res://sim/deduction.gd")
const Tuning = preload("res://sim/tuning.gd")

const ACCUSING = Deduction.ACCUSING
## Conclusions that speak for someone (the rest of the social ones speak against).
const POSITIVE = ["good", "notdemon", "protect", "spare", "truthful", "role", "secret", "marked", "red_herring"]


static func evaluate(w, n, ded: Dictionary, board: Array, scale: float, speak: bool = true) -> Dictionary:
	var lines: Array = []
	var c: Dictionary = Deduction.normalize(ded["conclusion"])
	var target = w.by_id.get(c.get("a", ""))
	var supports: Array = board.filter(func(x): return x["n"] in ded["supports"])
	# Repetition follows the conclusion and the facts behind it, not the card's wording.
	var facts: Array = supports.map(func(x): return Mind.fact_id(x))
	facts.sort()
	var key: String = "ded:%s|%s" % [Deduction.conclusion_key(c), ",".join(PackedStringArray(facts))]
	var times: int = n.heard.get(key, 0)
	n.heard[key] = times + 1
	var trace_id = w.dlog.decision(n.id, "argument", "start", null,
		{"conclusion": c, "fact_ids": facts, "card": ded.get("n", 0),
			"ledger_id": "arg:" + Deduction.conclusion_key(c),
			"repeat_count": times, "scale": scale}, c.get("a", ""))
	var audience = "player" if scale >= 1.0 else "town"
	var delivery_memory: Dictionary = n.dialogue_memory if speak and not n.silenced else n.dialogue_memory.duplicate(true)
	if n.is_evil():
		return _evil(w, n, ded, board, scale, c, target, facts, key, times, audience, delivery_memory, trace_id)
	if w.workshop_present.is_valid():
		var interpreted: Dictionary = w.workshop_present.call(n, ded, [], "deduction", "private" if scale >= 1.0 else ("nomination" if scale <= 0.5 else "meeting"), speak)
		if not interpreted.is_empty():
			return interpreted
	return _social(w, n, ded, board, scale, c, target, supports, facts, times, audience, delivery_memory, trace_id)


# ---------------------------------------------------------------- evil listeners

static func _evil(w, n, ded: Dictionary, board: Array, scale: float, c: Dictionary, target, facts: Array,
		key: String, times: int, audience: String, delivery_memory: Dictionary, trace_id: int) -> Dictionary:
	var lines: Array = []
	var workshop_covered = false
	if target != null and target.is_evil() and c["type"] in ACCUSING:
		Evil.add_intel(w, n, "player_suspects", target.id, 0.0, "the Demonologist argues: %s" % Deduction.conclusion_text(w, c))
	w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "evil": true}, "Evil hears the argument: %s" % ded["text"])
	var seen = false
	for k in n.heard:
		if k != key and k.begins_with("ded:%s|" % Deduction.conclusion_key(c)):
			seen = true
	var mask = _evil_mask(w, n, c, times, seen)
	var approved = descriptor(w, c, facts, mask.get("stance", "partial"))
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
				if not Mind.evil_override(w, n, "argument", stakes, dev, "%s (good self: %s, evil: %s)" % [Deduction.conclusion_text(w, c), mine["stance"], approved["stance"]]):
					approved = mine.duplicate(true)
	if times > 0 and not workshop_covered:
		var prior: Dictionary = delivery_memory.get("decisions", {}).get(JSON.stringify([audience, Deduction.conclusion_key(c)]), {})
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
				lines.append(Presentations.render_evil_override(w, n, c, str(approved.get("stance", "partial")), bool(approved.get("already", false)), times > 0 and delivery_memory.get("decisions", {}).has(JSON.stringify([audience, Deduction.conclusion_key(c)])), audience, canon_ev, delivery_memory))
		else:
			lines.append(line(n, approved, audience, delivery_memory))
	w.dlog.add("argument_stance", n.id, c.get("a", ""), {"key": Deduction.conclusion_key(c), "stance": approved["stance"], "evil": true, "repeat": times > 0})
	w.dlog.decision(n.id, "argument", "outcome", approved, {"route": "evil_mask",
		"agreement": 0.0, "updates_real_beliefs": false, "repeat_count": times}, c.get("a", ""), trace_id)
	return {"lines": lines, "agreement": 0.0, "repeated": times > 0, "dialogue": approved, "workshop": workshop_covered}


## An evil listener's stated reason for not being convinced, drawn from the same kinds of
## reason good listeners give (another explanation, shaky evidence, a likelier suspect),
## so evil replies aren't all "the evidence doesn't establish that". Deterministic per
## listener and argument: no game RNG is drawn.
static func _evil_reason(w, n, c: Dictionary, ded: Dictionary, approved: Dictionary) -> void:
	var h: int = absi(hash(n.id + "|" + Deduction.conclusion_key(c)))
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


## What answering as evil (rather than as its good self) buys an evil listener: protecting a
## teammate under fire, or pushing a case against the good (more for the scapegoat).
static func _evil_argument_stakes(w, n, c: Dictionary, target) -> float:
	if target == null:
		return 0.2
	var accusing = c["type"] in ACCUSING or (c["type"] == "role" and Deduction.is_evil_role(c.get("role", "")))
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
	var accusing = c["type"] in ACCUSING or (c["type"] == "role" and Deduction.is_evil_role(c.get("role", "")))
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


# ---------------------------------------------------------------- social speech

## A good listener's answer to speech the Workshop doesn't judge: a protect / spare
## preference, or a bare belief with no evidence. It weighs how far they trust the player
## and what they already believe about the person; it never changes suspicion. Accepted
## positions become protect / spare / believed-role preferences (Mind._apply_conclusion_pref).
static func _social(w, n, ded: Dictionary, board: Array, scale: float, c: Dictionary, target, supports: Array,
		facts: Array, times: int, audience: String, delivery_memory: Dictionary, trace_id: int) -> Dictionary:
	var lines: Array = []
	var agreement = 0.0
	var route = "social"
	if target == n and c["type"] in ["evil", "demon", "minion", "lied", "notrole", "suspicious", "unreliable"]:
		route = "own_knowledge_rejection"
		Mind.set_trust(w, n, n.trust - Tuning.Presentation.SELF_ACCUSED_TRUST_LOSS, "the Demonologist argued against me to my face")
	elif target == n:
		route = "self_support"
		agreement = 1.0
	elif target != null:
		var own: float = Mind.susp(n, target.id)
		var lean: float = (1.0 - own) if c["type"] in POSITIVE else own
		agreement = clampf(Tuning.Presentation.SOCIAL_TRUST_WEIGHT * n.trust + Tuning.Presentation.SOCIAL_BELIEF_WEIGHT * lean, 0.0, 1.0)
	var base: float = agreement * scale
	var gain = 0.0
	if base > Tuning.Presentation.SOCIAL_MIN_BASE:
		gain = _record(w, n, ded, c, supports, board, base, trace_id)
	w.dlog.decision(n.id, "argument", "evaluation", agreement,
		{"route": route, "agreement": agreement, "scale": scale, "base": base, "trust_at_apply": n.trust,
			"stored_weight_gain": gain, "stance_thresholds": {"accept": 0.6, "partial": 0.35}}, c.get("a", ""), trace_id)
	w.dlog.add("argument", n.id, c.get("a", ""), {"conclusion": c, "agreement": snappedf(agreement, 0.01), "scale": scale, "social": true},
		"%s weighs '%s' as speech: agreement %.2f" % [n.name, ded["text"], agreement])
	var stance = "accept" if agreement >= 0.6 else "partial" if agreement >= 0.35 else "reject"
	var approved = descriptor(w, c, facts, stance)
	w.dlog.add("argument_stance", n.id, c.get("a", ""), {"key": Deduction.conclusion_key(c), "stance": stance, "evil": false, "repeat": times > 0})
	approved["already"] = stance == "accept" and gain < 0.02 and times == 0
	if route == "own_knowledge_rejection":
		approved["special"] = "I don't buy it: it's about me, and I know it's false."
	elif agreement < 0.6:
		approved["reason"] = "weak"
	if c["type"] in ["evil", "demon", "minion"] and target != n:
		var ranked: Array = Mind.ranked_suspects(w, n)
		if not ranked.is_empty() and ranked[0].id != c.get("a", "") and Mind.susp(n, ranked[0].id) > Mind.susp(n, c.get("a", "")) + 0.05:
			approved["preferred"] = ranked[0].name
	if not n.silenced:
		lines.append(line(n, approved, audience, delivery_memory))
	w.dlog.decision(n.id, "argument", "outcome", approved,
		{"route": route, "agreement": agreement, "stored_weight_gain": gain}, c.get("a", ""), trace_id)
	return {"lines": lines, "agreement": agreement, "repeated": times > 0, "dialogue": approved}


## The accepted position, as an `arg:` ledger entry the preference pass reads. Social only:
## the shared model ignores `arg:` entries, so this never moves suspicion.
static func _record(w, n, ded: Dictionary, c: Dictionary, supports: Array, board: Array, base: float, trace_id: int) -> float:
	var ledger_id = "arg:" + Deduction.conclusion_key(c)
	if ded.has("workshop_case"):
		ledger_id = "arg:workshop:%d" % ded.n
	var h = Mind.ledger_hear(w, n, ledger_id, [], base * (0.5 + n.trust), [],
		{"kind": "arg", "base": base, "text": Deduction.conclusion_text(w, c),
			"said": "what you told me, that %s" % Deduction.conclusion_text(w, c),
			"supports": support_refs(supports, board), "conclusion": c.duplicate(true),
			"workshop_case": str(ded.get("n", 0)), "workshop_conclusion": c.type})
	w.dlog.decision(n.id, "argument", "ledger", h, {"ledger_id": ledger_id}, c.get("a", ""), trace_id)
	return h["gain"]


# ---------------------------------------------------------------- shared helpers

static func descriptor(w, c: Dictionary, facts: Array, stance: String) -> Dictionary:
	return {"kind": "argument", "key": Deduction.conclusion_key(c), "facts": facts.duplicate(), "stance": stance,
		"claim": Deduction.conclusion_text(w, c).trim_prefix("Something doesn't add up: "), "target_id": c.get("a", ""),
		"accusing": c.get("type", "") in ACCUSING}


static func line(n, approved: Dictionary, audience: String, memory: Dictionary) -> Dictionary:
	return Mind.say(n, Mind.Dialogue.decision(n.id, approved, audience, memory)["text"])


## Support references for a card list, looking through nested deductions to their roots.
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
