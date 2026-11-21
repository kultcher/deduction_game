## Burdens, NPC side (burdens prototype, Michael Nov 20; docs/design/burdens.md, sections 2,
## 7 and 9). What a known burden's holder says and when, and evil's burden bluffs.
##
## Stage 1 is Marked, now known to its holder:
##   - its disclosure is tiered (MARKED_SHARE): announced at the first meeting, shared
##     privately with whoever it trusts (the share scales with trust, to the player as to a
##     friend), or held until it's nominated or a reading names it evil;
##   - the forced reveal is "I've carried the mark since birth", in answer to a reading that
##     calls it evil, at the meeting or in private;
##   - burdens are unique, so a second claim is a lie and the real holder counter-claims.
## Evil bluffs a burden reactively (an evil reading of it calls for Marked), only from burdens
## on the script, never one already claimed, always on top of its gift bluff, and bolder as
## the days pass with no burden claimed (damped by its caution, so day 1 is very rare).
extends RefCounted

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Gifts = preload("res://sim/gifts.gd")

static func _mind():
	return load("res://sim/mind.gd")

static func _evil():
	return load("res://sim/evil.gd")

# ---------------------------------------------------------------- who carries what

## A good NPC carrying `kind`, and knowing it.
static func holds_known(n, kind: String) -> bool:
	return not n.is_evil() and n.secret_mod == kind and bool(n.burden_self_known)

static func on_script(w, kind: String) -> bool:
	return w.case_script != null and kind in w.case_script.secrets

## Who has claimed `kind`, in order (publicly or to anyone): burdens are unique.
static func claimants(w, kind: String) -> Array:
	return w.burden_claims.get(kind, [])

## Who has claimed `kind` before the town: what everyone, evil included, can know.
static func public_claimants(w, kind: String) -> Array:
	return w.burden_claims.get(kind + ":public", [])

## Claims of `kind` that `n` knows of: the public ones, and any told to it privately.
static func known_claimants(w, n, kind: String) -> Array:
	var out: Array = public_claimants(w, kind).duplicate()
	for owner in n.known_secrets:
		if owner in claimants(w, kind) and not owner in out:
			out.append(owner)
	return out

static func any_public_claim(w) -> bool:
	for k in w.burden_claims:
		if str(k).ends_with(":public") and not w.burden_claims[k].is_empty():
			return true
	return false

## What `n` says it carries ("" if nothing): the real burden, once it has said so, or evil's bluff.
static func claimed_by(w, n) -> String:
	for k in w.burden_claims:
		if not str(k).ends_with(":public") and n.id in w.burden_claims[k]:
			return k
	return ""

## The days since the first day with no burden claimed: evil's "bolder with silence".
static func silent_days(w) -> int:
	return 0 if any_public_claim(w) else maxi(0, w.day - 1)

# ---------------------------------------------------------------- Marked's disclosure tier

## The holder's disposition, drawn once from its own seeded draw (so the world's stream
## doesn't move): "public", "private" or "held" (MARKED_SHARE, Michael Nov 20).
static func marked_style(w, n) -> String:
	if not n.dialogue_memory.has("burden_style"):
		var r := RandomNumberGenerator.new()
		r.seed = hash([w.seed_value, n.id, "burden_style"])
		var x: float = r.randf()
		var share: Dictionary = Tuning.Burden.MARKED_SHARE
		n.dialogue_memory["burden_style"] = "public" if x < share.public else ("private" if x < share.public + share.private else "held")
	return str(n.dialogue_memory["burden_style"])

# ---------------------------------------------------------------- the words

## The burden in the town's words, as a gossip line or a card: "carries the mark: a gift may
## read them as evil". "" for a hidden burden or none.
static func phrase(o) -> String:
	if not o.secret.is_empty():
		return str(o.secret.get("text", ""))
	if o.secret_mod == "marked":
		return "carries the mark: a gift may read them as evil"
	return ""

## Claim `kind` (Marked, for now), publicly or to one listener. Records the claim, and for a
## real holder speaking publicly, that its burden is out. Returns {line, fact}.
static func claim(w, n, kind: String, public: bool, why: String, audience: String = "town") -> Dictionary:
	for k in [kind, kind + ":public"]:
		if not w.burden_claims.has(k):
			w.burden_claims[k] = []
	var rival: Array = known_claimants(w, n, kind).filter(func(id): return id != n.id)
	if not n.id in w.burden_claims[kind]:
		w.burden_claims[kind].append(n.id)
	if public and not n.id in w.burden_claims[kind + ":public"]:
		w.burden_claims[kind + ":public"].append(n.id)
	if public and not n.is_evil():
		n.secret_known = true
	var line: Dictionary
	var text: String
	if not rival.is_empty() and not n.is_evil():
		# The real holder answers a claim already made: one of them is lying.
		var r = w.by_id[rival[0]]
		line = _mind().say_voiced(n, "burden_counterclaim_marked", "%s isn't Marked. I am: I've carried the mark since birth." % r.name, {"rival": r.name})
		text = "%s says they, not %s, carry the mark: a gift may read them as evil." % [n.name, r.name]
	else:
		line = _mind().say_voiced(n, "burden_claim_marked", "I've carried the mark since birth. A gift may read me as evil, but I am not.")
		text = "%s says they've carried the mark since birth: a gift may read them as evil." % n.name
	var fact: Dictionary = {"kind": "secret", "subject": [n.id], "owner": n.id, "source": n.id, "secret_kind": kind,
		"mod": kind, "burden": true, "public": public, "text": text}
	if not public:
		fact["private"] = true
	w.dlog.add("burden_claim", n.id, audience, {"kind": kind, "public": public, "evil": n.is_evil(), "why": why, "rival": rival},
		"%s claims to be %s%s (%s)%s." % [n.name, C.secret_name(kind), " before the town" if public else " to " + audience, why, " [LIE]" if n.is_evil() else ""])
	if n.is_evil():
		w.dlog.think(n.id, "lie", "Claims to carry the mark, to explain %s." % why, {"lie": true, "burden": kind})
	return {"line": line, "fact": fact}

# ---------------------------------------------------------------- when it comes out

## A reading that calls `id` evil (or the Demon): what Marked explains.
static func calls_evil(rd: Dictionary, id: String) -> bool:
	return id in Gifts.implicated(rd)

## At the first meeting, a "public" holder announces it, unasked.
static func testimony_claim(w, n) -> Dictionary:
	if n.silenced or not holds_known(n, "marked") or claimed_by(w, n) != "" or w.day > 1:
		return {}
	if marked_style(w, n) != "public":
		return {}
	return claim(w, n, "marked", true, "being plain with the town from the start")

## A real holder whose burden someone else has claimed counter-claims at its next meeting
## turn, whatever its tier: a second claim means a liar (burdens are unique).
static func counterclaim(w, n) -> Dictionary:
	if n.silenced or not holds_known(n, "marked") or n.dialogue_memory.get("burden_counterclaimed", false):
		return {}
	var others: Array = known_claimants(w, n, "marked").filter(func(id): return id != n.id)
	if others.is_empty():
		return {}
	n.dialogue_memory["burden_counterclaimed"] = true
	return claim(w, n, "marked", true, "someone else claimed my burden")

## The forced reveal: a reading that calls them evil, faced at the meeting or in private.
## A real holder always gives it (Michael: held until "named in an evil reading"); evil may
## bluff it (evil_marked_bluff). Returns {} if not.
static func answer_evil_reading(w, n, rd: Dictionary, public: bool, audience: String = "town") -> Dictionary:
	if n.silenced or not calls_evil(rd, n.id):
		return {}
	if public and n.id in public_claimants(w, "marked"):
		# Already said before the town: the same words again, no new claim.
		return {"line": _mind().say_voiced(n, "burden_claim_marked", "I've carried the mark since birth. A gift may read me as evil, but I am not."), "fact": {}}
	if holds_known(n, "marked"):
		if public and n.secret_known:
			# Already out before the town: the same words again, no new claim.
			return {"line": _mind().say_voiced(n, "burden_claim_marked", "I've carried the mark since birth. A gift may read me as evil, but I am not."), "fact": {}}
		return claim(w, n, "marked", public, "a reading that named me evil", audience)
	if n.is_evil() and (claimed_by(w, n) == "marked" or evil_marked_bluff(w, n, "a reading that named me evil")):
		return claim(w, n, "marked", public, "a reading that named it evil", audience)
	return {}

## Private sharing (the "private" tier): with a listener it trusts, the share rising with
## that trust. Weight for the peer-talk draw; 0 for anyone not sharing.
static func private_share_weight(w, s, trust: float) -> float:
	if not holds_known(s, "marked") or marked_style(w, s) == "held":
		return 0.0
	return Tuning.Burden.MARKED_PRIVATE_SHARE_SCALE * maxf(0.0, trust - Tuning.Burden.MARKED_PRIVATE_SHARE_FLOOR)

## To the player, in the same breath as telling its gift privately: a draw against trust.
static func tell_player(w, n) -> Dictionary:
	if not holds_known(n, "marked") or marked_style(w, n) == "held" or n.dialogue_memory.get("burden_told_player", false):
		return {}
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed_value, w.day, n.id, "burden_tell_player"])
	if r.randf() >= clampf((n.trust - Tuning.Burden.MARKED_PRIVATE_SHARE_FLOOR) * Tuning.Burden.MARKED_PRIVATE_SHARE_SCALE, 0.0, 1.0):
		return {}
	n.dialogue_memory["burden_told_player"] = true
	return claim(w, n, "marked", false, "trusting the Demonologist", "player")

# ---------------------------------------------------------------- evil's bluff

## Does evil bluff Marked now, to explain `why`? Only if Marked is on the script, nobody has
## claimed it, and it holds a gift bluff (a burden sits on top of a gift, Michael Q17). Its
## own seeded draw: REACTIVE, halved if a Rumormonger is publicly claimed (it could name the
## real holder), raised by the days of silence, damped by its caution.
static func evil_marked_bluff(w, n, why: String) -> bool:
	if not n.is_evil() or not on_script(w, "marked") or not known_claimants(w, n, "marked").is_empty():
		return false
	if str(w.evil_plan.get("bluffs", {}).get(n.id, "")) == "" and not n.turned:
		return false
	if w.evil_plan.has("burden_bluffs") and w.evil_plan["burden_bluffs"].has(n.id):
		return str(w.evil_plan["burden_bluffs"][n.id]) == "marked"
	var p: float = Tuning.Burden.BLUFF_REACTIVE + Tuning.Burden.BLUFF_SILENCE_PER_DAY * silent_days(w)
	if w.public_claims.any(func(pc): return str(pc.get("role", "")) == "rumormonger"):
		p *= Tuning.Burden.BLUFF_RUMORMONGER_DAMP
	p *= 1.0 - _evil().caution(w, n)
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed_value, w.day, n.id, "burden_bluff", why])
	var draw: float = r.randf()
	w.dlog.think(n.id, "burden_bluff", "Evil: bluff Marked to explain %s? -> %s (p=%.2f)" % [why, "yes" if draw < p else "no", p], {"result": draw < p, "p": p, "why": why})
	if draw >= p:
		return false
	if not w.evil_plan.has("burden_bluffs"):
		w.evil_plan["burden_bluffs"] = {}
	w.evil_plan["burden_bluffs"][n.id] = "marked"
	return true

## Proactive, at the meeting: evil claims Marked unprompted only after days of silence, at the
## same public tier a real holder would, damped by its caution ("bolder with silence follows
## the same rules as good", Michael Q16). Very rare on day 1.
static func evil_silence_claim(w, n) -> Dictionary:
	if n.silenced or not n.is_evil() or not on_script(w, "marked") or not known_claimants(w, n, "marked").is_empty():
		return {}
	if str(w.evil_plan.get("bluffs", {}).get(n.id, "")) == "":
		return {}
	var p: float = Tuning.Burden.MARKED_SHARE.public * (Tuning.Burden.SILENCE_START + Tuning.Burden.SILENCE_PER_DAY * silent_days(w)) * (1.0 - _evil().caution(w, n))
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed_value, w.day, n.id, "burden_silence_claim"])
	if r.randf() >= p:
		return {}
	if not w.evil_plan.has("burden_bluffs"):
		w.evil_plan["burden_bluffs"] = {}
	w.evil_plan["burden_bluffs"][n.id] = "marked"
	return claim(w, n, "marked", true, "the town's silence about burdens (p=%.3f)" % p)
