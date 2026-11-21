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
	if o.secret_mod == "ill_omened":
		return "is Ill-Omened, and hanging them would cost the town dear"
	return ""

## Claim `kind` (Marked, for now), publicly or to one listener. Records the claim, and for a
## real holder speaking publicly, that its burden is out. Returns {line, fact}.
static func claim(w, n, kind: String, public: bool, why: String, audience: String = "town", extra: Dictionary = {}) -> Dictionary:
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
	if kind == "ill_omened":
		var omen: Dictionary = _omen_words(w, n, rival, bool(extra.get("at_nomination", false)))
		line = omen["line"]
		text = omen["text"]
	elif kind == "unrequited" and w.by_id.has(str(extra.get("beloved", ""))):
		var bl = w.by_id[str(extra["beloved"])]
		var me: String = ("was at the graveyard, at %s's grave. I loved them, and now they'll never know" % bl.name) if not bl.alive else ("went to %s's door. I've cared for them a long while, and they've no idea" % bl.name)
		line = _mind().say_voiced(n, "confess_secret_private", "...I wasn't home. I %s. Please, keep it quiet." % me, {"secret": me})
		text = "%s admitted they have an unrequited love for %s." % [n.name, bl.name]
	elif not rival.is_empty() and not n.is_evil():
		# The real holder answers a claim already made: one of them is lying.
		var r = w.by_id[rival[0]]
		line = _mind().say_voiced(n, "burden_counterclaim_marked", "%s isn't Marked. I am: I've carried the mark since birth." % r.name, {"rival": r.name})
		text = "%s says they, not %s, carry the mark: a gift may read them as evil." % [n.name, r.name]
	else:
		line = _mind().say_voiced(n, "burden_claim_marked", "I've carried the mark since birth. A gift may read me as evil, but I am not.")
		text = "%s says they've carried the mark since birth: a gift may read them as evil." % n.name
	var told: Dictionary = told_at(w)
	var fact: Dictionary = {"kind": "secret", "subject": [n.id], "owner": n.id, "source": n.id, "secret_kind": kind,
		"mod": kind, "burden": true, "public": public, "text": text, "observed_at": told}
	fact.merge(extra, true)
	if not public:
		fact["private"] = true
		# Corroboration (Michael, Nov 21): when this listener heard it, so a later relay keeps the date.
		var key: String = "%s|%s" % [n.id, audience]
		if not w.burden_told.has(key):
			w.burden_told[key] = told
	var claim_data: Dictionary = {"kind": kind, "public": public, "evil": n.is_evil(), "why": why, "rival": rival}
	claim_data.merge(extra, true)
	w.dlog.add("burden_claim", n.id, audience, claim_data,
		"%s claims to be %s%s (%s)%s." % [n.name, C.secret_name(kind), " before the town" if public else " to " + audience, why, " [LIE]" if n.is_evil() else ""])
	if n.is_evil():
		w.dlog.think(n.id, "lie", "Claims to carry the mark, to explain %s." % why, {"lie": true, "burden": kind})
	return {"line": line, "fact": fact}

## When a telling happens, as a card dates it: the engine's phase (0 morning .. 3 night), so a
## morning testimony and an afternoon reading stay in order.
static func told_at(w) -> Dictionary:
	return {"day": w.day, "phase": int(w.phase)}

## A confidant passes on a burden it was told (or heard second-hand): the claimant stays the
## source and the original telling keeps its date; the confidant is `via`, whose credibility
## decides whether it's believed (Lantern, Nov 21). No `relay_source`: to the judge that means
## a Medium's relayed reading.
static func relay_fact(w, confidant, owner, said: String) -> Dictionary:
	var first_ear: String = str(confidant.known_secrets.get(owner.id, confidant.id))
	var told: Dictionary = w.burden_told.get("%s|%s" % [owner.id, first_ear], w.burden_told.get("%s|%s" % [owner.id, confidant.id], told_at(w)))
	return {"kind": "secret", "subject": [owner.id], "owner": owner.id, "source": owner.id, "via": confidant.id,
		"secret_kind": owner.secret_mod, "mod": owner.secret_mod, "burden": true,
		"public": false, "private": true, "observed_at": told,
		"text": "%s told you %s's secret: %s %s." % [confidant.name, owner.name, owner.name, said]}

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
	var kind: String = str(n.secret_mod)
	if n.silenced or not kind in ["marked", "ill_omened"] or not holds_known(n, kind) or n.dialogue_memory.get("burden_counterclaimed", false):
		return {}
	var others: Array = known_claimants(w, n, kind).filter(func(id): return id != n.id)
	if others.is_empty():
		return {}
	n.dialogue_memory["burden_counterclaimed"] = true
	return claim(w, n, kind, true, "someone else claimed my burden")

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
	return evil_burden_bluff(w, n, "marked", why)

## The same draw for any known burden evil might bluff (Ill-Omened at a nomination too).
static func evil_burden_bluff(w, n, kind: String, why: String) -> bool:
	if not n.is_evil() or not on_script(w, kind) or not known_claimants(w, n, kind).is_empty():
		return false
	if str(w.evil_plan.get("bluffs", {}).get(n.id, "")) == "" and not n.turned:
		return false
	if w.evil_plan.has("burden_bluffs") and w.evil_plan["burden_bluffs"].has(n.id):
		return str(w.evil_plan["burden_bluffs"][n.id]) == kind
	var p: float = Tuning.Burden.BLUFF_REACTIVE + Tuning.Burden.BLUFF_SILENCE_PER_DAY * silent_days(w)
	if w.public_claims.any(func(pc): return str(pc.get("role", "")) == "rumormonger"):
		p *= Tuning.Burden.BLUFF_RUMORMONGER_DAMP
	p *= 1.0 - _evil().caution(w, n)
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed_value, w.day, n.id, "burden_bluff", why] if kind == "marked" else [w.seed_value, w.day, n.id, "burden_bluff", kind, why])
	var draw: float = r.randf()
	w.dlog.think(n.id, "burden_bluff", "Evil: bluff %s to %s? -> %s (p=%.2f)" % [C.secret_name(kind), ("explain " + why) if kind == "marked" else why, "yes" if draw < p else "no", p], {"result": draw < p, "p": p, "why": why, "kind": kind})
	if draw >= p:
		return false
	if not w.evil_plan.has("burden_bluffs"):
		w.evil_plan["burden_bluffs"] = {}
	w.evil_plan["burden_bluffs"][n.id] = kind
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

# ---------------------------------------------------------------- Ill-Omened (stage 2)

## Its words (Michael's revised wording, Nov 21): never the effect, only a cost to the town.
static func _omen_words(w, n, rival: Array, at_nomination: bool) -> Dictionary:
	if not rival.is_empty() and not n.is_evil():
		var r = w.by_id[rival[0]]
		return {"line": _mind().say_voiced(n, "burden_ill_omened_counterclaim", "That isn't true of %s. The omen is mine. There's only one." % r.name, {"claimant": r.name}),
			"text": "%s says they, not %s, are Ill-Omened: hanging them would cost the town." % [n.name, r.name]}
	if at_nomination:
		return {"line": _mind().say_voiced(n, "burden_ill_omened_nomination", "I am Ill-Omened. Hang me, and it'll come with a cost to us all."),
			"text": "%s, nominated, says they are Ill-Omened: hanging them would cost the town." % n.name}
	return {"line": _mind().say_voiced(n, "burden_ill_omened_early", "Be careful where this goes. I'm Ill-Omened, and hanging me would cost the town."),
		"text": "%s says they are Ill-Omened: hanging them would cost the town." % n.name}

## Nominated: a real holder always cites the omen (Michael: "always cites it before an
## execution"), restating it if it said so earlier. Evil restates a bluff it already made, or
## may start one now with the same reactive draw as Marked, if the omen is on the script and
## unclaimed. Only this restatement arms the omen (a hard rule, Nov 20). {} if nothing is said.
static func omen_at_nomination(w, n) -> Dictionary:
	if n.silenced:
		return {}
	var real: bool = holds_known(n, "ill_omened")
	if not real and not (n.is_evil() and (claimed_by(w, n) == "ill_omened" or evil_burden_bluff(w, n, "ill_omened", "stay off the rope"))):
		return {}
	w.omen_restated[n.id] = w.day
	return claim(w, n, "ill_omened", true, "nominated for hanging", "town", {"at_nomination": true})

## Earlier, under pressure (Michael: "sometimes earlier, if pressure is high or the town is
## already turning on them"): the first time it's accused before the town, a real holder warns
## once. Evil doesn't: its bluff waits for the nomination, where it's needed.
static func omen_early_warning(w, n) -> Dictionary:
	if n.silenced or not holds_known(n, "ill_omened") or n.id in public_claimants(w, "ill_omened"):
		return {}
	return claim(w, n, "ill_omened", true, "the town turning on me", "town", {"at_nomination": false})

## The cost of hanging a publicly claimed Ill-Omened, as a vote term: about enough to cancel
## the player's yes for a median-trust listener (design §9 item 9). Derived from that bump, so
## no new constant. Evil's good self weighs it too, so evil votes as its good self would.
static func omen_vote_cost(w, nominee: String) -> float:
	if not nominee in public_claimants(w, "ill_omened"):
		return 0.0
	return -(Tuning.Meeting.PLAYER_VOTE_YES_SLOPE * 0.5 + Tuning.Meeting.PLAYER_VOTE_YES_OFFSET)

## A hanging: if it restated the omen at today's nomination, the town marks it, and if it was
## the real holder, every good person is poisoned from now until the next night but one
## begins (the night after the hanging and the following day; design §9 item 5). A bluffer's
## hanging poisons nobody, and nobody can tell (item 6).
static func on_executed(w, n) -> void:
	if int(w.omen_restated.get(n.id, -1)) != w.day:
		return
	var real: bool = n.secret_mod == "ill_omened" and not n.is_evil()
	# Public: the town saw a claimed Ill-Omened hanged. Whether the poison fell stays hidden.
	w.public_event("omen_hanged", [n.id], "world")
	w.dlog.add("omen_hanged", "world", n.id, {"day": w.day},
		"%s, who claimed to be Ill-Omened when nominated, is hanged.%s" % [n.name, "" if real else " [BLUFF: no effect]"])
	if not real:
		return
	w.omen_nights.append({"executed": n.id, "day": w.day, "night": w.day})
	for m in w.npcs:
		if m.alive and not m.is_evil():
			m.omen_poisoned_day = w.day
	w.dlog.add("omen_poison", "world", n.id, {"executed": n.id, "day": w.day, "from_night": w.day, "until": w.day + 1},
		"The omen falls: every good person's gift fails from this night until the next night begins.")

## The start of a night: the omen's poison lifts once the night after the hanging and the
## following day have passed.
static func lift_omen(w) -> void:
	for m in w.npcs:
		if int(m.omen_poisoned_day) >= 0 and w.day > int(m.omen_poisoned_day):
			m.omen_poisoned_day = -1

# ---------------------------------------------------------------- Unrequited (stage 2)

## At the deal: the holder's errand (the confession paths read `secret`), and trust in the
## beloved near the maximum, so it takes more to sway them against them (Michael, Nov 20).
static func setup_unrequited(w) -> void:
	for n in w.npcs:
		if n.secret_mod != "unrequited" or n.beloved == "" or n.is_evil():
			continue
		var b = w.by_id[n.beloved]
		n.secret = {"kind": "unrequited", "burden": true, "beloved": b.id, "dest": b.home_block,
			"text": "has an unrequited love for %s" % b.name,
			"me": "went to %s's door. I've cared for them a long while, and they've no idea" % b.name}
		n.npc_trust[b.id] = 1.0 - Tuning.Setup.INITIAL_TRUST_JITTER
		n.suspicion[b.id] = minf(float(n.suspicion.get(b.id, Tuning.Setup.INITIAL_SUSPICION_BASE)), Tuning.Setup.INITIAL_SUSPICION_BASE + Tuning.Setup.INITIAL_SUSPICION_FRIEND)

## Tonight's visit, or "": the beloved's block, or Chapel Hill once they're dead (their
## grave), on UNREQUITED_VISIT_CHANCE of nights by the holder's own seeded draw (so the
## world's stream doesn't move). Not on a night it's already out on other business.
static func unrequited_visit(w, n) -> String:
	if n.secret_mod != "unrequited" or n.is_evil() or n.beloved == "" or n.out_last_night or not w.by_id.has(n.beloved):
		return ""
	if n.dialogue_memory.get("unrequited_spell_broken", false):
		return ""
	# Never two nights running without a visit (Michael, Nov 21): a night missed forces the next.
	var last: int = int(n.dialogue_memory.get("unrequited_last_visit", w.day - 1))
	var due: bool = w.day - last >= 2
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed_value, w.day, n.id, "unrequited_visit"])
	if not due and r.randf() >= Tuning.Burden.UNREQUITED_VISIT_CHANCE:
		return ""
	n.dialogue_memory["unrequited_last_visit"] = w.day
	var b = w.by_id[n.beloved]
	if not b.alive:
		n.secret["dest"] = "hill"
		n.secret["me"] = "was at the graveyard, at %s's grave. I loved them, and now they'll never know" % b.name
		return "hill"
	return b.home_block if b.home_block != n.home_block else ""

## What any Unrequited confession or gossip adds to its fact: the beloved, the burden flag,
## the date and the card's words ("X admitted they have an unrequited love for Y", §9 item 11).
## Empty for any other secret.
static func errand_extras(w, o) -> Dictionary:
	if str(o.secret.get("kind", "")) != "unrequited":
		return {}
	var b = w.by_id.get(str(o.secret.get("beloved", "")))
	if b == null:
		return {}
	return {"secret_kind": "unrequited", "mod": "unrequited", "burden": true, "beloved": b.id,
		"observed_at": told_at(w), "text": "%s admitted they have an unrequited love for %s." % [o.name, b.name]}

static func with_errand(w, o, fact: Dictionary) -> Dictionary:
	fact.merge(errand_extras(w, o), true)
	return fact

## Defending within reason (§9 item 13): a reading it would volunteer that implicates the
## beloved moderately to strongly (them among two at most) is held back, with a logged reason.
## Only what it volunteers: pressed, or nominated itself, it gives it up.
static func withholds_for_beloved(w, n, entry: Dictionary) -> bool:
	if n.secret_mod != "unrequited" or n.is_evil() or n.beloved == "" or n.dialogue_memory.get("unrequited_spell_broken", false):
		return false
	var who: Array = Gifts.implicated(entry)
	if not n.beloved in who or who.size() > 2:
		return false
	if str(w.meeting.get("pending", {}).get("nominee", "")) == n.id:
		return false
	var key: String = "unrequited_withheld:%s" % str(entry.get("day", -1))
	if not n.dialogue_memory.get(key, false):
		n.dialogue_memory[key] = true
		w.dlog.think(n.id, "withhold", "Holds back a reading against %s, whom they love: not on so little." % w.by_id[n.beloved].name, {"burden": "unrequited", "beloved": n.beloved})
	return true

## Evil's Unrequited bluff (§9 item 12), pressed with a sighting of itself on `block` on night
## `nd`: a beloved whose home fits. It answers only a sighting on the claimed beloved's block
## (their grave on Chapel Hill once they're dead) or one on its own block, "leaving home". It
## never answers a sighting that puts it on some other block. Once claimed, the same beloved
## must fit every later sighting. The shared reactive draw decides. {} if it doesn't.
static func evil_unrequited_bluff(w, n, nd: int, block: String) -> Dictionary:
	if not n.is_evil() or block == "" or not on_script(w, "unrequited"):
		return {}
	if not w.evil_plan.has("unrequited_beloved"):
		w.evil_plan["unrequited_beloved"] = {}
	var mine: String = str(w.evil_plan["unrequited_beloved"].get(n.id, ""))
	var pick: String = mine
	if pick == "":
		var fits: Array = []
		for m in w.npcs:
			if m == n:
				continue
			if block == n.home_block and m.alive:
				fits.append(m)
			elif m.alive and m.home_block == block:
				fits.append(m)
			elif not m.alive and block == "hill":
				fits.append(m)
		if fits.is_empty():
			return {}
		# The cover a good-looking beloved gives: a good one, if it can (never a teammate it
		# might drag down with it).
		var goods: Array = fits.filter(func(m): return not m.is_evil())
		var pool: Array = goods if not goods.is_empty() else fits
		pool.sort_custom(func(a, b): return a.id < b.id)
		var r := RandomNumberGenerator.new()
		r.seed = hash([w.seed_value, n.id, "unrequited_beloved", nd, block])
		pick = pool[r.randi_range(0, pool.size() - 1)].id
	var b = w.by_id[pick]
	var fit: bool = (block == "hill" and not b.alive) or (b.alive and (block == b.home_block or block == n.home_block))
	if not fit:
		return {}
	if mine == "" and not evil_burden_bluff(w, n, "unrequited", "explain being out on %s on night %d" % [C.block_name(block), nd]):
		return {}
	w.evil_plan["unrequited_beloved"][n.id] = pick
	return claim(w, n, "unrequited", false, "caught out on %s on night %d" % [C.block_name(block), nd], "player",
		{"beloved": pick, "block": block, "day": nd, "phase": C.NIGHT})

## The reveal's trust cost (Michael, Nov 21, option a): those who hear it lose trust in the
## Unrequited, by the secret-spread amount (SECRET_SPREAD_BASE + SECRET_SPREAD_PRIVACY x its
## Privacy). Once per listener. Evil listeners too: their good selves model the town.
static func reveal_cost(w, o, listeners: Array) -> void:
	if str(o.secret.get("kind", "")) != "unrequited":
		return
	var loss: float = Tuning.Trust.SECRET_SPREAD_BASE + Tuning.Trust.SECRET_SPREAD_PRIVACY * float(o.traits.get("privacy", 0.5))
	var heard: Dictionary = o.dialogue_memory.get("unrequited_reveal_heard", {})
	for l in listeners:
		if l == o or not l.alive or heard.has(l.id):
			continue
		heard[l.id] = true
		var before: float = float(l.npc_trust.get(o.id, 0.5))
		l.npc_trust[o.id] = clampf(before - loss, 0.0, 1.0)
		w.dlog.add("npc_trust", l.id, o.id, {"from": snappedf(before, 0.01), "to": snappedf(l.npc_trust[o.id], 0.01), "why": "unrequited_reveal"},
			"%s trusts %s less: they hid an unrequited love for %s." % [l.name, o.name, w.by_id[str(o.secret.get("beloved", ""))].name])
	o.dialogue_memory["unrequited_reveal_heard"] = heard

## The spell breaks (Michael, Nov 21): once its suspicion of the beloved reaches the level that
## drives a good NPC's accusations (ACCUSE_SUSPICION_PIVOT), the Unrequited says so before the
## town and gives the burden up. It stops shielding them and stops its visits. {} if not.
static func spell_breaks(w, n) -> Dictionary:
	if n.silenced or n.is_evil() or n.secret_mod != "unrequited" or n.beloved == "" or n.dialogue_memory.get("unrequited_spell_broken", false):
		return {}
	var b = w.by_id.get(n.beloved)
	if b == null or not b.alive or float(n.suspicion.get(b.id, 0.0)) < Tuning.Meeting.ACCUSE_SUSPICION_PIVOT:
		return {}
	n.dialogue_memory["unrequited_spell_broken"] = true
	n.secret_known = true
	w.dlog.think(n.id, "spell_breaks", "Can't keep believing %s is good: suspicion %.2f. Gives up the burden." % [b.name, float(n.suspicion[b.id])], {"burden": "unrequited", "beloved": b.id, "day": w.day})
	var line: Dictionary = _mind().say_voiced(n, "burden_unrequited_spell_breaks", "I kept telling myself %s was good. I can't keep telling myself that, not after this." % b.name, {"beloved": b.name})
	var fact: Dictionary = with_errand(w, n, {"kind": "secret", "subject": [n.id], "owner": n.id, "source": n.id, "public": true})
	fact["spell_broken"] = true
	reveal_cost(w, n, w.living())
	return {"line": line, "fact": fact}
