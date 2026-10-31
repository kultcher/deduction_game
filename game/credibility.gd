## Credibility (Oct 30, docs/social_trust_pass.md): how much an NPC takes the player's word,
## kept apart from rapport (n.trust, how they feel about you). It comes from the player's
## track record: the conclusions they argued to this NPC, checked each dawn against what
## the NPC now believes from their own evidence (without the player's presentations or
## what the player told them, so the check isn't circular). Proof, when it exists (a Demon
## victim, a Gravedigger reading, a caught lie), lands through those same beliefs.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const PublicEvidence = preload("res://workshop/public_evidence.gd")

const EVIL_LEANING = ["evil", "demon", "minion", "suspicious"]
const GOOD_LEANING = ["good"]
## Ledger entries that carry the player's word rather than the NPC's own evidence.
const PLAYER_WORD = ["tell:", "for:", "arg:", "workshop:tell:"]

## Does this ledger entry carry the player's word (a told card, an argument, a private
## Workshop presentation's tell), rather than the NPC's own evidence?
static func players_word(eid: String) -> bool:
	return PLAYER_WORD.any(func(p): return eid.begins_with(p))

## The player argued `type` about `target` to `n` (a presented case, a nomination, an
## accusation). Only alignment conclusions count; the latest direction per target stands,
## while a casual statement in the same direction never downgrades an existing formal weight.
static func record(n, type: String, target: String, day: int, weight: float = Tuning.Trust.CRED_WEIGHT_FORMAL) -> void:
	if target == "" or target == n.id:
		return
	var direction: String = "evil" if type in EVIL_LEANING else ("good" if type in GOOD_LEANING else "")
	if direction == "":
		return
	var eff_weight: float = clampf(weight, 0.05, 1.0)
	var prev: Dictionary = n.claim_record.get(target, {})
	if str(prev.get("type", "")) == direction:
		eff_weight = maxf(float(prev.get("weight", eff_weight)), eff_weight)
	var entry: Dictionary = {"type": direction, "day": day, "weight": eff_weight}
	n.claim_record[target] = entry
	if n.shadow != null:
		n.shadow.claim_record[target] = entry.duplicate(true)

## Every living NPC everyone heard it from: nominations and public accusations.
static func record_public(g, type: String, target: String, weight: float = Tuning.Trust.CRED_WEIGHT_FORMAL) -> void:
	for n in g.w.living():
		record(n, type, target, g.w.day, weight)

## Dawn: move each NPC's credibility toward their track-record target.
static func dawn(g) -> void:
	if not g.workshop_effects:
		return
	for n in g.w.living():
		if n.claim_record.is_empty():
			continue
		var mind = n.shadow if n.is_evil() and n.shadow != null else n
		if mind.workshop_state.is_empty():
			continue
		var agreement = _agreement(g, mind)
		if agreement == null:
			continue
		var target: float = 0.5 + Tuning.Trust.CRED_SPAN * float(agreement)
		var value: float = clampf(mind.credibility + (target - mind.credibility) * Tuning.Trust.CRED_STEP, Tuning.Trust.CRED_MIN, Tuning.Trust.CRED_MAX)
		var old_cred: float = mind.credibility
		g.w.dlog.trace_event("value_change", n.id, "player", {"quantity": "credibility",
			"from": old_cred, "to": value, "agreement": agreement, "claims": mind.claim_record.size()},
			"Track record: the player's claims against my own evidence")
		if absf(value - old_cred) >= 0.005:
			g.w.dlog.add("credibility", n.id, "player", {
				"from": snappedf(old_cred, 0.01),
				"to": snappedf(value, 0.01),
				"agreement": snappedf(float(agreement), 0.01),
				"claims": mind.claim_record.size(),
			}, "Track record: the player's claims against my own evidence")
		mind.credibility = value
		n.credibility = value

## Mean agreement in [-1, 1] between the player's recorded claims and the NPC's own view,
## or null when the view can't be prepared.
static func _agreement(g, n):
	var st: Dictionary = n.workshop_state
	var outside: Dictionary = st.get("outside", n.suspicion).duplicate(true)
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	var ledger = {}
	for eid in n.ledger:
		if not players_word(str(eid)):
			ledger[eid] = n.ledger[eid]
	var plan = Shared.prepare(input, {}, ledger, st.get("withdrawn", {}), st.get("attention_focus", []))
	if not plan.ready:
		return null
	var eval_res: Dictionary = Shared.evaluate(plan, outside, n.discounted)
	var effects: Dictionary = eval_res.get("effects", {})
	var people: Array = effects.keys().filter(func(id): return id != n.id)
	if people.is_empty():
		return null
	var mean := 0.0
	for id in people:
		mean += float(effects[id].posterior)
	mean /= people.size()
	if mean <= 0.0 or mean >= 1.0:
		return null  # an impossible or degenerate view says nothing about the player
	var all_ids: Array = plan.input.people.map(func(p): return p.id)
	var public_good: Array = eval_res.get("public_good", [])
	var demon_victims: Array = PublicEvidence.demon_victims(plan.input.public_events, all_ids)
	var cursed_origins: Array = []
	for ev in plan.input.get("public_events", []):
		if ev.get("kind", "") == "curse":
			for subj in ev.get("subjects", []):
				if subj not in cursed_origins:
					cursed_origins.append(subj)
	var total := 0.0
	var weight_sum := 0.0
	for target in n.claim_record:
		if not effects.has(target):
			continue
		var eff: Dictionary = effects[target]
		var p: float = float(eff.posterior)
		var p0: float = float(eff.get("prior", mean))
		var publicly_proven: bool = target in public_good or target in demon_victims or target in cursed_origins
		# Pending / Uninformed Gate: if this listener holds no public proof on `target`
		# and their strictly independent evidence has not moved `target` away from prior,
		# abstain rather than penalizing early detective work or self-validating player cases.
		if not publicly_proven and absf(p - p0) < Tuning.Trust.CRED_CORROBORATION_MIN:
			continue
		var a: float = (p - mean) / (1.0 - mean) if p >= mean else (p - mean) / maxf(mean, 1e-9)
		var signed_a: float = a if n.claim_record[target].type == "evil" else -a
		var claim_w: float = clampf(float(n.claim_record[target].get("weight", Tuning.Trust.CRED_WEIGHT_FORMAL)), 0.05, 1.0)
		total += claim_w * signed_a
		weight_sum += claim_w
	return total / weight_sum if weight_sum > 0.0 else null
