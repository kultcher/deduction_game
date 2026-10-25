## Public-case interpretation -> assessment -> replaceable ledger effect -> response.
## Deliberately keeps the existing game's trust/suspicion/confidence/stance vocabulary.
## This is a workshop adapter, not a balance change to Mind or Argue.
extends RefCounted

const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const Support = preload("res://workshop/support_model.gd")
const Theory = preload("res://workshop/theory.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Consequences = preload("res://workshop/consequences.gd")
const Movement = preload("res://workshop/movement_model.gd")
const Profiler = preload("res://workshop/profiler.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Protection = preload("res://workshop/live_protection.gd")
const TimeModel = preload("res://workshop/chronology.gd")

## Which engine judges cases (docs/CASE_REASONING.md): "case_eval" (likelihood-weighted
## worlds, one pass for every person) or "legacy" (model v5's credibility-state mixture
## and per-person consequence loop), kept for offline comparison only.
static var engine: String = "case_eval"

static func evaluate(view: Dictionary, case_data: Dictionary, listener: Dictionary, context: Dictionary = {}) -> Dictionary:
	var span = Profiler.open("jury")
	var result = _evaluate(view, case_data, listener, context)
	Profiler.close(span)
	return result

## The shared-union belief refresh: "given everything I hold, how do my suspicions
## move?" There is no headline claim, so no reply is built and every person,
## including the first in the list, gets the same per-person theory path. Returns
## effects, theories (also written to listener), reasoning (the attention used) and
## reading challenges. CaseEval engine only.
static func refresh(view: Dictionary, case_data: Dictionary, listener: Dictionary) -> Dictionary:
	var span = Profiler.open("jury_refresh")
	var old: Dictionary = listener.ledger.get(case_data.id, {})
	var old_effects: Dictionary = old.get("effects", {})
	if not old.is_empty() and old_effects.is_empty():
		old_effects = {old.target: {"applied": old.applied}}
	var before: Dictionary = listener.suspicion.duplicate(true)
	var baseline = listener.duplicate(true)
	for person in old_effects:
		baseline.suspicion[person] = snappedf(baseline.suspicion.get(person, 0.1) - old_effects[person].applied, 0.000000001)
	baseline.ledger = {}
	var signature_case = Graph.compile_case(view, case_data)
	signature_case.conclusion = {"type": "evil", "target": "all", "at": case_data.conclusion.at}
	var common_key = JSON.stringify(_canonical([_signature(view, signature_case), baseline.suspicion, baseline.npc_trust,
		baseline.knowledge, baseline.reading_reliability, baseline.trust, baseline.confidence,
		baseline.get("confidence_mode"), baseline.get("reasoning_mode"), baseline.get("insight")]))
	var consequences = _consequences_eval(view, case_data, baseline, {}, common_key, [], true)
	var effects = {}
	for person in view.people:
		var id: String = person.id
		if not consequences.effects.has(id):
			continue
		var entry: Dictionary = consequences.effects[id].duplicate(true)
		entry["baseline"] = baseline.suspicion.get(id, 0.1)
		entry["before"] = snappedf(before.get(id, 0.1), 0.000000001)
		entry["after"] = snappedf(clampf(entry.baseline + entry.requested, 0.0, 1.5), 0.000000001)
		entry["applied"] = snappedf(entry.after - entry.baseline, 0.000000001)
		entry["delta"] = snappedf(entry.after - entry.before, 0.000000001)
		entry["previous"] = old_effects.get(id, {}).get("applied", 0.0)
		effects[id] = entry
		listener.suspicion[id] = entry.after
	listener.ledger[case_data.id] = {"effects": effects.duplicate(true)}
	listener.theories = consequences.theories
	Profiler.close(span)
	return {"effects": effects, "reasoning": consequences.reasoning, "reading_challenges": consequences.reading_challenges,
		"effect_rule": consequences.rule}

static func _evaluate(view: Dictionary, case_data: Dictionary, listener: Dictionary, context: Dictionary = {}) -> Dictionary:
	var before: Dictionary = listener.suspicion.duplicate(true)
	var old: Dictionary = listener.ledger.get(case_data.id, {})
	var old_effects: Dictionary = old.get("effects", {})
	if not old.is_empty() and old_effects.is_empty():
		old_effects = {old.target: {"applied": old.applied}}
	# Retract the ENTIRE previous vector before evaluating any conclusion. Every
	# projection sees this same snapshot, including source credibility and priors.
	var baseline = listener.duplicate(true)
	for person in old_effects:
		baseline.suspicion[person] = snappedf(baseline.suspicion.get(person, 0.1) - old_effects[person].applied, 0.000000001)
	baseline.ledger = {}
	var primary_listener = baseline.duplicate(true)
	var modern: bool = engine == "case_eval"
	var result = _assess_target_eval(view, case_data, primary_listener, context) if modern else _assess_target(view, case_data, primary_listener, context)
	var signature_case = Graph.compile_case(view, case_data)
	signature_case.conclusion = {"type": "evil", "target": "all", "at": case_data.conclusion.at}
	var common_key = JSON.stringify(_canonical([_signature(view, signature_case), baseline.suspicion, baseline.npc_trust,
		baseline.knowledge, baseline.reading_reliability, baseline.trust, baseline.confidence,
		baseline.get("confidence_mode"), baseline.get("reasoning_mode"), baseline.get("insight")]))
	# context.headline_only: a scoped reply whose effects are never applied (the shared
	# union owns belief changes). Only the headline target's effect is computed; every
	# other person's projection, theory and CaseEval re-run is skipped.
	var only: Array = [case_data.conclusion.target] if context.get("headline_only", false) and view.people.any(func(p): return p.id == case_data.conclusion.target) else []
	var consequences = _consequences_eval(view, case_data, baseline, result, common_key, only) if modern else Consequences.assess(view, case_data, baseline, _pattern, common_key, result.theory)
	var effects = {}
	for person in view.people:
		var id: String = person.id
		if not consequences.effects.has(id):
			continue
		var entry: Dictionary = consequences.effects[id].duplicate(true)
		entry["baseline"] = baseline.suspicion.get(id, 0.1)
		entry["before"] = snappedf(before.get(id, 0.1), 0.000000001)
		entry["after"] = snappedf(clampf(entry.baseline + entry.requested, 0.0, 1.5), 0.000000001)
		entry["applied"] = snappedf(entry.after - entry.baseline, 0.000000001)
		entry["delta"] = snappedf(entry.after - entry.before, 0.000000001)
		entry["previous"] = old_effects.get(id, {}).get("applied", 0.0)
		effects[id] = entry
		listener.suspicion[id] = entry.after
	var target: String = case_data.conclusion.target
	listener.ledger[case_data.id] = primary_listener.ledger[case_data.id].duplicate(true)
	listener.ledger[case_data.id].effects = effects.duplicate(true)
	listener.ledger[case_data.id].applied = effects[target].applied
	listener.case_memory = primary_listener.case_memory.duplicate(true)
	listener.theories = consequences.theories
	# The headline's original confidence decision remains the reported decision.
	var theory_key: String = target + "|" + case_data.conclusion.at
	if case_data.conclusion.type in ["marked", "demon", "minion"]:
		theory_key += "|" + case_data.conclusion.type
	if primary_listener.theories.has(theory_key):
		listener.theories[theory_key] = primary_listener.theories[theory_key].duplicate(true)
	result["effects"] = effects
	var challenges = Support.ReadingChallenges.assess(view, case_data, baseline, Solver.selected(view, signature_case).filter(func(c): return c.id in result.reasoning.considered and c.id not in result.reasoning.private_checks.rejected))
	result["reading_challenges"] = challenges.results
	for challenge in challenges.results:
		result.response += " " + challenge.note
	result["claims"] = consequences.claims
	result["effect_rule"] = consequences.rule
	result.before_suspicion = effects[target].before
	result.after_suspicion = effects[target].after
	result.suspicion_delta = effects[target].delta
	result.calculation.old_case_effect = effects[target].previous
	result.calculation.new_case_effect = effects[target].applied
	result.calculation.rule = consequences.rule
	# Speak about accepted intermediate inferences separately from the headline.
	if not result.repeated:
		if effects[target].get("protection_signal", 0.0) < 0 and case_data.conclusion.type != "conflict":
			result.response += " The quiet night gives that protection claim some support, though other explanations remain."
		for claim in consequences.claims:
			if claim.conclusion.target != target and claim.conclusion.type == "evil" and claim.status == "entailed_in_attention" and claim.forced_mass > 0:
				result.response += " The reports I granted implicate %s, if sound. That conclusion does not by itself settle %s's alignment." % [Solver.person_name(view, claim.conclusion.target), Solver.person_name(view, target)]
				break
	return result

static func applied_to(entry: Dictionary, person: String) -> float:
	if entry.has("effects"):
		return float(entry.effects.get(person, {}).get("applied", 0.0))
	return float(entry.get("applied", 0.0)) if entry.get("target") == person else 0.0

static func _assess_target(view: Dictionary, case_data: Dictionary, listener: Dictionary, context: Dictionary = {}) -> Dictionary:
	var span = Profiler.open("headline")
	var result = _assess_target_inner(view, case_data, listener, context)
	Profiler.close(span)
	return result

static func _assess_target_inner(view: Dictionary, case_data: Dictionary, listener: Dictionary, context: Dictionary = {}) -> Dictionary:
	var original = case_data.duplicate(true)
	case_data = Graph.compile_case(view, case_data)
	var conclusion: Dictionary = case_data.conclusion
	var target: String = conclusion.target
	var before_suspicion: float = listener.suspicion.get(target, 0.1)
	var before_trust: float = listener.trust
	var old: Dictionary = listener.ledger.get(case_data.id, {})
	# Assess from the baseline without this case's own previous persuasion. Otherwise
	# accusing a witness would lower their credibility on every repetition.
	if not old.is_empty():
		listener.suspicion[old.target] = snappedf(listener.suspicion.get(old.target, 0.1) - old.applied, 0.000000001)
	var previous: Dictionary = listener.case_memory.get(case_data.id, {})
	var signature = _signature(view, case_data)
	var input_key = JSON.stringify(_canonical([signature, listener.get("reasoning_mode", "full"), listener.get("insight", 0.5),
		listener.get("confidence_mode", "scale"), listener.confidence, listener.trust, listener.npc_trust,
		listener.suspicion, listener.reading_reliability, listener.knowledge]))
	var repeated: bool = previous.get("input_key", "") == input_key
	var knowledge: Dictionary = listener.knowledge
	var full_case = case_data.duplicate(true)
	for id in knowledge.get("own_reports", []):
		if id not in full_case.cards:
			full_case.cards.append(id)
	var assessment = Solver.analyze(view, full_case, knowledge)
	var shared = Solver.analyze(view, case_data)
	var overall = Solver.solve(view, Solver.selected(view, full_case), {}, {}, knowledge)
	var logical_cards: Array = Solver.selected(view, case_data).filter(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"])
	var best = {"weight": 0.0, "agreement": 0.0, "quality": 0.0, "cards": [], "kind": "none"}
	# Consider independent support paths. Adding an optional premise cannot erase an
	# already valid smaller path; a contradiction in the asserted case can reopen it.
	# The legacy diagnostic enumerates every report subset. Live comparisons already
	# retain the real Argue result; avoid computing this superseded experiment too.
	var diagnostic_paths: int = 1 if Solver.Domain.live(view) else 1 << logical_cards.size()
	for mask in range(1, diagnostic_paths):
		var path: Array = []
		for i in range(logical_cards.size()):
			if mask & (1 << i):
				path.append(logical_cards[i].id)
		var subcase = Solver.empty_case()
		subcase.cards = path.duplicate()
		subcase.conclusion = conclusion
		for id in knowledge.get("own_reports", []):
			if id not in subcase.cards:
				subcase.cards.append(id)
		var analysis = Solver.analyze(view, subcase, knowledge)
		var agreement = 1.0 if analysis.entailment == "forced" else 0.0
		if analysis.entailment == "possible":
			agreement = _possibility_agreement(view, overall.worlds, conclusion, listener)
		if conclusion.type == "conflict":
			agreement = 0.0 # handled using the whole asserted set below
		var quality = _quality(view, path, listener)
		var weight = agreement * quality
		if weight > best.weight:
			best = {"weight": weight, "agreement": agreement, "quality": quality, "cards": path, "kind": "reading"}
		if shared.entailment == "possible" and conclusion.type != "conflict":
			var positions: Dictionary = case_data.positions.duplicate(true)
			positions.erase(target)
			var answers: Dictionary = case_data.answers.duplicate(true)
			if conclusion.type == "marked":
				for id in answers.keys():
					if Solver.card_by_id(view, id).get("role", "") == "rumormonger":
						answers.erase(id)
			var conditional_path = Solver.solve(view, Solver.selected(view, subcase), positions, answers, knowledge)
			if not conditional_path.worlds.is_empty() and conditional_path.worlds.all(func(w): return Solver.holds(view, w, conclusion)):
				if 0.4 * quality > best.weight:
					best = {"weight": 0.4 * quality, "agreement": 0.4, "quality": quality, "cards": path, "kind": "conditional"}
	var pattern = _pattern(view, case_data, listener)
	var legacy = best.duplicate(true)
	if Solver.Domain.live(view):
		legacy["omitted"] = true
	var reasoning = Support.explain(view, original, listener)
	if listener.get("reasoning_mode", "full") == "bounded":
		var attended: Dictionary = Reasoner.prepare(view, original, listener).case
		attended.cards = attended.cards.filter(func(id): return id not in reasoning.private_checks.rejected)
		pattern = _pattern(view, attended, listener)
		var considered_facts: Array = reasoning.considered.map(func(id): return Solver.semantic_key(Solver.card_by_id(view, id)))
		considered_facts.sort()
		input_key += JSON.stringify([considered_facts, reasoning.connections])
		repeated = previous.get("input_key", "") == input_key
	var theory = Theory.prepare(view, case_data, listener, reasoning, input_key)
	var combined = Support.assess(view, original, listener, theory.bias)
	var paths: Array = []
	for path in combined.paths:
		for id in path:
			if id not in paths:
				paths.append(id)
	if paths.is_empty():
		paths = logical_cards.map(func(c): return c.id)
	best = {"weight": combined.agreement, "agreement": combined.agreement, "quality": 1.0,
		"cards": paths, "kind": "conditional" if combined.conditional_mass > combined.forced_mass else "reading"}
	if conclusion.type == "suspicious" and pattern.weight > best.weight:
		best = pattern
	if conclusion.type == "suspicious" and Movement.available(view) and combined.evidence_agreement > 0:
		best.agreement = maxf(best.agreement, 0.5)
		best.weight = maxf(best.weight, 0.5)
	var conflict = assessment.status == "conflicting"
	if conclusion.type == "conflict":
		var detected: bool = (reasoning.status == "inconsistent" or not reasoning.private_checks.rejected.is_empty()) if listener.get("reasoning_mode", "full") == "bounded" else assessment.entailment == "forced"
		var agreement = 1.0 if detected else 0.0
		best = {"weight": agreement * _quality(view, case_data.cards, listener), "agreement": agreement, "quality": _quality(view, case_data.cards, listener), "cards": case_data.cards, "kind": "conflict"}
	elif listener.get("reasoning_mode", "full") != "bounded" and (not assessment.errors.is_empty() or (assessment.proposed == 0 and assessment.compatible > 0)):
		best.weight = 0.0
		best.agreement = 0.0
	if reasoning.private_checks.fatal:
		best.weight = 0.0
		best.agreement = 0.0
	var player_factor: float = 0.5 + listener.trust
	var confidence_factor: float = 1.0 if listener.get("confidence_mode", "scale") == "persistence" else 1.4 - 0.8 * listener.confidence
	# Venue is deliberately the same: no private/public/nomination duplicate effects.
	var strength: float = best.weight * player_factor * confidence_factor
	var coefficient: float = {"evil": 0.45, "demon": 0.45, "minion": 0.45, "good": -0.4, "marked": -0.1, "suspicious": 0.3, "conflict": 0.0}.get(conclusion.type, 0.0)
	var effect: float = strength * coefficient
	# Replace this case's complete prior effect, even if target/conclusion changed.
	var baseline: float = listener.suspicion.get(target, 0.1)
	listener.suspicion[target] = snappedf(clampf(baseline + effect, 0.0, 1.5), 0.000000001)
	var applied: float = snappedf(listener.suspicion[target] - baseline, 0.000000001)
	listener.ledger[case_data.id] = {"target": target, "applied": applied, "cards": best.cards.duplicate(), "version": case_data.version,
		"conclusion": conclusion.duplicate(true), "signature": signature, "report_acceptance": combined.report_acceptance.duplicate(true)}
	# No recurring trust reward for restating a case. Workshop trust is a controlled input.
	var changes = _changes(view, previous.get("case", {}), case_data)
	listener.case_memory[case_data.id] = {"signature": signature, "input_key": input_key, "version": case_data.version, "cards": case_data.cards.duplicate(), "strength": strength, "case": case_data.duplicate(true)}
	var objection = _objection(view, case_data, listener, shared, assessment, best, pattern)
	var stance = "accept" if best.agreement >= 0.6 else ("partial" if best.agreement >= 0.35 else "reject")
	var delta: float = listener.suspicion[target] - before_suspicion
	var response = ""
	if repeated:
		response = "That is the same case. Repeating it adds no new reason."
	elif conclusion.type == "conflict":
		response = "Those accounts cannot all be accurate. I have reopened which report to believe; this does not establish anyone's alignment." if best.agreement > 0 else "I don't see a conflict among the reports you selected."
	elif best.kind == "pattern" and best.weight > 0:
		response = "That gives me a reason to be suspicious, though it does not establish evil."
	elif conflict and conclusion.type != "conflict":
		response = "I cannot accept all those premises together. I give weight only to the explanations that survive doubting a report." if best.weight > 0 else "Your selected explanation does not fit. The underlying reports can still change my assessments."
	elif best.kind == "conditional":
		response = "That follows if I grant your extra choices. You still need to establish those choices."
	elif stance == "accept" and Movement.available(view) and assessment.entailment == "possible":
		response = "These observations make your explanation convincing to me, though an alternative remains logically possible."
	elif stance == "accept":
		response = "The conclusion follows if those reports are sound. My doubt is in the premises."
	elif combined.agreement < 0:
		response = "The supplied evidence weighs against that conclusion."
	elif assessment.entailment == "forced":
		response = "The inference follows if the reports are accurate. I give it some weight, but I still doubt the supporting reports."
	else:
		response = "I can see that possibility, but the reports also allow another explanation."
	if not combined.factors.is_empty():
		if combined.factors.any(func(label): return label.begins_with("Movement / trace")):
			response += " The routes, observation coverage and traces change which explanation I favor. Lawful activity and eligible passers remain alternatives; this is circumstantial evidence."
		else:
			response += " If the linked observation is accurate, the home alibi is false. That is circumstantial evidence, not proof of deliberate deception or evil." if combined.factors.any(func(label): return label.begins_with("Challenged home alibi")) else " The supplied test factor changes which remaining explanation I favor; it does not prove it."
	if listener.get("reasoning_mode", "full") == "bounded":
		objection = _bounded_objection(reasoning)
		if reasoning.private_checks.fatal:
			response = reasoning.private_checks.objections[0]
		elif conclusion.type == "conflict":
			response = "The accounts I considered cannot all be accurate. That does not identify anyone as evil." if best.agreement > 0 else "I have not established a conflict among the accounts I considered."
		elif best.weight < 0:
			response = "The evidence I considered weighs against this conclusion; my search was limited."
		elif not reasoning.support.is_empty() and reasoning.status == "provisional":
			response = "Your explanation fits what I considered. I am provisionally persuaded, but I have not checked another explanation." if stance == "accept" else "I found your explanation coherent, but I am not convinced by its support. I have not checked another explanation."
		elif reasoning.status == "rival_found":
			var alternative = Solver.describe_world(view, reasoning.rival, conclusion.at)
			response = "I checked another explanation and it also fits: %s evil; %s Marked. I cannot settle it from this alone." % [", ".join(PackedStringArray(alternative.evil.map(func(id): return Solver.person_name(view, id)))), Solver.person_name(view, alternative.marked)]
			if alternative.has("demon"):
				response += " In that explanation, %s is the Demon." % Solver.person_name(view, alternative.demon)
			if Movement.available(view) and stance == "accept":
				response = "I checked another explanation that also fits, but the movement and trace evidence makes your explanation more convincing. This is persuasion, not a proof that the alternative is impossible."
		elif reasoning.status == "entailed_in_attention":
			response = "The reports I considered force this if they are accurate."
		else:
			response = "I could not follow your explanation through within what I considered. That does not prove it wrong."
		if not reasoning.ignored.is_empty() or not reasoning.ignored_lines.is_empty():
			response += " I did not combine all the evidence in this case."
		if repeated:
			response = "That is the same case; I made the same checks. Repeating it adds no new reason."
	if not reasoning.private_checks.objections.is_empty():
		objection = " ".join(PackedStringArray(reasoning.private_checks.objections))
	if listener.get("reasoning_mode", "full") == "bounded" and combined.factors.any(func(label): return label.begins_with("Challenged home alibi")):
		response += " The linked observation challenges the home alibi; it does not by itself prove evil."
	if theory.mode == "persistence" and not repeated:
		response += " " + theory.note
	if not previous.is_empty() and not repeated and not changes.is_empty():
		response += " " + " ".join(PackedStringArray(changes))
	if not case_data.get("faults", {}).is_empty():
		response += " Your explanation needs impairment in the selected interval. That remains a hypothesis; readings outside it keep their own support."
	return {"listener": listener.id, "name": listener.name, "version": case_data.version, "stance": stance,
		"agreement": best.agreement, "quality": best.quality, "strength": strength, "path": best.cards,
		"path_kind": best.kind, "repeated": repeated, "response": response, "objection": objection, "changes": changes,
		"assessment": assessment, "shared_assessment": shared, "pattern": pattern, "support_model": combined, "legacy_path": legacy, "reasoning": reasoning, "theory": theory,
		"before_suspicion": before_suspicion, "after_suspicion": listener.suspicion[target], "suspicion_delta": delta,
		"before_trust": before_trust, "after_trust": listener.trust, "trust_delta": 0.0,
		"calculation": {"agreement": best.agreement, "premise_quality": best.quality, "player_factor": player_factor,
			"confidence_factor": confidence_factor, "coefficient": coefficient, "old_case_effect": old.get("applied", 0.0), "new_case_effect": applied,
			"venue": context.get("venue", "private"), "rule": "Replace this case's prior effect; never add it again. Trust is held fixed for controlled comparisons."}}

## The listener as CaseEval sees them: their suspicion and trust as priors, their own
## private readings folded into the starting view, and their reading reliability.
## Challenges the listener accepts (unlikely / misled / lying) scale the reliability of
## the challenged readings and sources.
static func _eval_listener(listener: Dictionary, own: Array, challenges: Dictionary = {}, attention: Dictionary = {}) -> Dictionary:
	var knowledge: Dictionary = listener.get("knowledge", {}).duplicate(true)
	if listener.get("reasoning_mode", "full") == "bounded" and knowledge.has("presented_reports") and not attention.is_empty():
		own = own.filter(func(id): return id in attention.considered)
	knowledge["own_reports"] = own
	return {"id": listener.get("id", "listener"), "suspicion": listener.get("suspicion", {}),
		"npc_trust": listener.get("npc_trust", {}), "knowledge": knowledge,
		"reading_reliability": listener.get("reading_reliability", {}),
		"challenge_reports": challenges.get("reports", {}), "challenge_sources": challenges.get("sources", {})}

## A bounded listener who looked for no rival explanation ("provisional"), or who
## checked that the attended reports force it ("entailed_in_attention"), takes a
## coherent case on trust: model v5's provisional conviction, scaled by how far they
## trust each source (Support.source_quality) and each reading. Supplied factors still
## move them.
## entailed: the listener checked that the attended reports force the conclusion, so
## with every reading credible they're fully convinced.
static func _provisional(view: Dictionary, conclusion: Dictionary, ev: Dictionary, cards: Array, listener: Dictionary, eval_listener: Dictionary, entailed: bool = false) -> float:
	var ratio: float = Support._direct_ratio(ev.factors.filter(func(f): return not f.get("joint_live", false)), conclusion)
	if cards.is_empty():
		return (2.0 if Movement.available(view) else 0.16) * (ratio / (1.0 + ratio) - 0.5)
	# Each source is credible with its quality; each of its readings, with that reading's
	# own reliability. Conviction is v5's for however many readings survive (two or
	# more: 0.76, one: 0.3), averaged over the chances.
	var by_source = {}
	for card in cards:
		if not by_source.has(card.source):
			by_source[card.source] = []
		by_source[card.source].append(minf(1.0, (1.0 - CaseEval.reading_error(view, card, eval_listener)) / (1.0 - CaseEval.DEFAULT_ERR)))
	var dist = PackedFloat64Array([1.0])  # chance of n credible readings
	for source in by_source:
		var quality: float = Support.source_quality(listener, source)
		var inner = PackedFloat64Array([1.0])  # given the source is credible
		for r in by_source[source]:
			var grown = PackedFloat64Array()
			grown.resize(inner.size() + 1)
			grown.fill(0.0)
			for n in range(inner.size()):
				grown[n] += inner[n] * (1.0 - r)
				grown[n + 1] += inner[n] * r
			inner = grown
		var next = PackedFloat64Array()
		next.resize(dist.size() + inner.size() - 1)
		next.fill(0.0)
		for a in range(dist.size()):
			next[a] += dist[a] * (1.0 - quality)
			for b in range(inner.size()):
				next[a + b] += dist[a] * quality * inner[b]
		dist = next
	var scale: float = 2.0 * ratio / (1.0 + ratio)
	var conviction = 0.0
	for n in range(1, dist.size()):
		conviction += dist[n] * (1.0 if entailed and n == cards.size() else minf(0.95, (0.76 if n >= 2 else 0.3) * scale))
	return conviction

## The cards a listener weighs for this case: their attention set (Insight limits it for
## bounded reasoners), without reports they know are false and without their own private
## readings, which are part of their starting view instead.
static func _eval_case(view: Dictionary, case_data: Dictionary, attention: Dictionary, listener: Dictionary) -> Dictionary:
	var scoped: Dictionary = attention.case.duplicate(true)
	var own: Array = listener.get("knowledge", {}).get("own_reports", [])
	scoped.cards = scoped.cards.filter(func(id): return id not in attention.private_checks.rejected and id not in own)
	scoped.conclusion = case_data.conclusion.duplicate(true)
	if case_data.conclusion.type in ["suspicious"]:
		scoped.conclusion.type = "evil"
	return scoped

## Headline judgment on the CaseEval engine. Same result shape as _assess_target_inner.
static func _assess_target_eval(view: Dictionary, case_data: Dictionary, listener: Dictionary, context: Dictionary = {}) -> Dictionary:
	var span = Profiler.open("headline")
	var original = case_data.duplicate(true)
	case_data = Graph.compile_case(view, case_data)
	var conclusion: Dictionary = case_data.conclusion
	var target: String = conclusion.target
	var before_suspicion: float = listener.suspicion.get(target, 0.1)
	var before_trust: float = listener.trust
	var old: Dictionary = listener.ledger.get(case_data.id, {})
	if not old.is_empty():
		listener.suspicion[old.target] = snappedf(listener.suspicion.get(old.target, 0.1) - old.applied, 0.000000001)
	var previous: Dictionary = listener.case_memory.get(case_data.id, {})
	var signature = _signature(view, case_data)
	var input_key = JSON.stringify(_canonical([signature, listener.get("reasoning_mode", "full"), listener.get("insight", 0.5),
		listener.get("confidence_mode", "scale"), listener.confidence, listener.trust, listener.npc_trust,
		listener.suspicion, listener.reading_reliability, listener.knowledge]))
	var repeated: bool = previous.get("input_key", "") == input_key
	var knowledge: Dictionary = listener.knowledge
	var full_case = case_data.duplicate(true)
	for id in knowledge.get("own_reports", []):
		if id not in full_case.cards:
			full_case.cards.append(id)
	# Live belief/attention/action never read the exhaustive minimal-conflict list.
	# Keep it available to the explicit diagnostic UI, out of every receipt refresh.
	var assessment = Solver.analyze(view, full_case, knowledge, false)
	var shared = Solver.analyze(view, case_data, {}, false)
	var reasoning = Support.explain(view, original, listener)
	var bounded: bool = listener.get("reasoning_mode", "full") == "bounded"
	if bounded:
		var considered_facts: Array = reasoning.considered.map(func(id): return Solver.semantic_key(Solver.card_by_id(view, id)))
		considered_facts.sort()
		input_key += JSON.stringify([considered_facts, reasoning.connections])
		repeated = previous.get("input_key", "") == input_key
	var theory = Theory.prepare(view, case_data, listener, reasoning, input_key)
	var attention = Reasoner.prepare(view, original, listener)
	var scoped = _eval_case(view, case_data, attention, listener)
	var challenges = Support.ReadingChallenges.assess(view, attention.case, listener, Solver.selected(view, attention.case).filter(func(c): return c.id not in attention.private_checks.rejected))
	var eval_listener = _eval_listener(listener, knowledge.get("own_reports", []), challenges, attention)
	eval_listener["theory_bias"] = theory.bias
	var ev = CaseEval.evaluate(view, scoped, eval_listener)
	var agreement: float = clampf(CaseEval.shift(ev.prior, ev.posterior), -1.0, 1.0)
	var contributing: Array = Solver.selected(view, scoped).filter(func(c): return Solver.tabled(c))
	if bounded and reasoning.status in ["provisional", "entailed_in_attention"] and ev.consistent and conclusion.type != "conflict":
		agreement = clampf(_provisional(view, conclusion, ev, contributing, listener, eval_listener, reasoning.status == "entailed_in_attention"), -1.0, 1.0)
	var pattern = _pattern(view, case_data, listener)
	if bounded:
		# Outings count only if the listener attended to them.
		var attended_case: Dictionary = attention.case.duplicate(true)
		attended_case.cards = attended_case.cards.filter(func(id): return id not in reasoning.private_checks.rejected)
		pattern = _pattern(view, attended_case, listener)
	var paths: Array = scoped.cards.filter(func(id): return Solver.tabled(Solver.card_by_id(view, id)))
	var best = {"weight": agreement, "agreement": agreement, "quality": 1.0, "cards": paths, "kind": "reading"}
	if conclusion.type == "suspicious" and pattern.weight > best.weight:
		best = pattern
	# The player's chosen answers and positions are a theory: if the conclusion follows
	# only once they're granted, say so. They never add evidence.
	if best.kind == "reading" and best.agreement < 0.6 and conclusion.type not in ["conflict", "suspicious"]:
		var positions: Dictionary = case_data.positions.duplicate(true)
		positions.erase(target)
		var answers: Dictionary = case_data.answers.duplicate(true)
		if not positions.is_empty() or not answers.is_empty() or not case_data.get("temporal_positions", []).is_empty():
			var chosen = Solver.solve(view, Solver.selected(view, full_case).filter(func(c): return c.id not in reasoning.private_checks.rejected), positions, answers, knowledge, conclusion.at, case_data.get("temporal_positions", []))
			if not chosen.worlds.is_empty() and chosen.worlds.all(func(w): return Solver.holds(view, w, conclusion)):
				best.kind = "conditional"
	var conflict = assessment.status == "conflicting" or not ev.consistent
	if conclusion.type == "conflict":
		var detected: bool = (reasoning.status == "inconsistent" or not reasoning.private_checks.rejected.is_empty()) if bounded else not ev.consistent
		var value = 1.0 if detected else 0.0
		best = {"weight": value, "agreement": value, "quality": 1.0, "cards": case_data.cards, "kind": "conflict"}
	if reasoning.private_checks.fatal or ev.impossible:
		best.weight = 0.0
		best.agreement = 0.0
	var player_factor: float = 0.5 + listener.trust
	var confidence_factor: float = 1.0 if listener.get("confidence_mode", "scale") == "persistence" else 1.4 - 0.8 * listener.confidence
	var strength: float = best.weight * player_factor * confidence_factor
	var coefficient: float = {"evil": 0.45, "demon": 0.45, "minion": 0.45, "good": -0.4, "marked": -0.1, "suspicious": 0.3, "conflict": 0.0}.get(conclusion.type, 0.0)
	var effect: float = strength * coefficient
	var baseline: float = listener.suspicion.get(target, 0.1)
	listener.suspicion[target] = snappedf(clampf(baseline + effect, 0.0, 1.5), 0.000000001)
	var applied: float = snappedf(listener.suspicion[target] - baseline, 0.000000001)
	listener.ledger[case_data.id] = {"target": target, "applied": applied, "cards": best.cards.duplicate(), "version": case_data.version,
		"conclusion": conclusion.duplicate(true), "signature": signature, "report_acceptance": ev.acceptance.duplicate(true)}
	var changes = _changes(view, previous.get("case", {}), case_data)
	listener.case_memory[case_data.id] = {"signature": signature, "input_key": input_key, "version": case_data.version, "cards": case_data.cards.duplicate(), "strength": strength, "case": case_data.duplicate(true)}
	var objection = _objection(view, case_data, listener, shared, assessment, best, pattern)
	var stance = "accept" if best.agreement >= 0.6 else ("partial" if best.agreement >= 0.35 else "reject")
	var response = _eval_response(view, case_data, best, stance, ev, conflict, repeated)
	if bounded:
		# What a bounded listener says reflects their own search, never the referee's.
		objection = _bounded_objection(reasoning)
		if reasoning.private_checks.fatal:
			response = reasoning.private_checks.objections[0]
		elif conclusion.type == "conflict":
			response = "The accounts I considered cannot all be accurate. That does not identify anyone as evil." if best.agreement > 0 else "I have not established a conflict among the accounts I considered."
		elif best.weight < 0:
			response = "The evidence I considered weighs against this conclusion; my search was limited."
		elif not reasoning.support.is_empty() and reasoning.status == "provisional":
			response = "Your explanation fits what I considered. I am provisionally persuaded, but I have not checked another explanation." if stance == "accept" else "I found your explanation coherent, but I am not convinced by its support. I have not checked another explanation."
		elif reasoning.status == "rival_found":
			var alternative = Solver.describe_world(view, reasoning.rival, conclusion.at)
			response = "I checked another explanation and it also fits: %s evil; %s Marked." % [", ".join(PackedStringArray(alternative.evil.map(func(id): return Solver.person_name(view, id)))), Solver.person_name(view, alternative.marked)]
			if alternative.has("demon"):
				response += " In that explanation, %s is the Demon." % Solver.person_name(view, alternative.demon)
			if stance == "accept":
				response += " Even so, the evidence favors your explanation." if ev.movement.is_empty() else " Even so, the movement and trace evidence makes your explanation more convincing. This is persuasion, not a proof that the alternative is impossible."
		elif reasoning.status == "entailed_in_attention":
			response = "The reports I considered force this if they are accurate."
		elif reasoning.status != "provisional":
			response = "I could not follow your explanation through within what I considered. That does not prove it wrong."
		if not reasoning.ignored.is_empty() or not reasoning.ignored_lines.is_empty():
			response += " I did not combine all the evidence in this case."
		if ev.movement.any(func(label): return label.begins_with("Challenged home alibi")):
			response += " The linked observation challenges the home alibi; it does not by itself prove evil."
		if repeated:
			response = "That is the same case; I made the same checks. Repeating it adds no new reason."
	if not reasoning.private_checks.objections.is_empty():
		objection = " ".join(PackedStringArray(reasoning.private_checks.objections))
	if theory.mode == "persistence" and not repeated:
		response += " " + theory.note
	if not previous.is_empty() and not repeated and not changes.is_empty():
		response += " " + " ".join(PackedStringArray(changes))
	if not case_data.get("faults", {}).is_empty():
		response += " Your explanation needs impairment in the selected interval. That remains a hypothesis; readings outside it keep their own support."
	var support_model = {"agreement": agreement, "evidence_agreement": agreement, "forced_mass": ev.posterior if ev.posterior >= 0.999 else 0.0,
		"conditional_mass": 0.0, "paths": [paths], "report_acceptance": ev.acceptance, "states": 1, "factors": ev.movement, "atoms": [], "credence": ev.credence,
		"quoted_cards": scoped.get("quoted_cards", []).duplicate(), "faults": [], "movement_comparison": [], "prior": ev.prior, "posterior": ev.posterior,
		"category": ev.category, "rivals": ev.rivals, "theory_fit": ev.theory_fit,
		"model": "CaseEval: likelihood-weighted worlds (docs/CASE_REASONING.md)."}
	Profiler.close(span)
	return {"listener": listener.id, "name": listener.name, "version": case_data.version, "stance": stance,
		"agreement": best.agreement, "quality": best.quality, "strength": strength, "path": best.cards,
		"path_kind": best.kind, "repeated": repeated, "response": response, "objection": objection, "changes": changes,
		"assessment": assessment, "shared_assessment": shared, "pattern": pattern, "support_model": support_model, "legacy_path": {"weight": 0.0, "omitted": true},
		"reasoning": reasoning, "theory": theory, "case_eval": ev,
		"before_suspicion": before_suspicion, "after_suspicion": listener.suspicion[target], "suspicion_delta": listener.suspicion[target] - before_suspicion,
		"before_trust": before_trust, "after_trust": listener.trust, "trust_delta": 0.0,
		"calculation": {"agreement": best.agreement, "premise_quality": best.quality, "player_factor": player_factor,
			"confidence_factor": confidence_factor, "coefficient": coefficient, "old_case_effect": old.get("applied", 0.0), "new_case_effect": applied,
			"venue": context.get("venue", "private"), "prior": ev.prior, "posterior": ev.posterior,
			"rule": "Replace this case's prior effect; never add it again. Trust is held fixed for controlled comparisons."}}

## What the listener says about the headline, from how far the case moved them.
static func _eval_response(view: Dictionary, case_data: Dictionary, best: Dictionary, stance: String, ev: Dictionary, conflict: bool, repeated: bool) -> String:
	var conclusion: Dictionary = case_data.conclusion
	if repeated:
		return "That is the same case. Repeating it adds no new reason."
	if conclusion.type == "conflict":
		return "Those accounts cannot all be accurate. I have reopened which report to believe; this does not establish anyone's alignment." if best.agreement > 0 else "I don't see a conflict among the reports you selected."
	if best.kind == "pattern" and best.weight > 0:
		return "That gives me a reason to be suspicious, though it does not establish evil."
	var response = ""
	if best.kind == "conditional":
		response = "That follows if I grant your extra choices. You still need to establish those choices."
	elif ev.impossible:
		response = "Your selected explanation does not fit what I know. The underlying reports can still change my assessments."
	elif conflict:
		response = "Those reports can't all be right together, so I'm weighing which of them to doubt."
	elif stance == "accept":
		response = "Taken together, those reports convince me." if ev.posterior >= 0.9 else "Those reports convince me, though another explanation is still possible."
	elif stance == "partial":
		response = "That moves me, but the reports also allow another explanation."
	elif best.agreement <= -0.2:
		response = "The supplied evidence weighs against that conclusion."
	elif best.agreement > 0.05:
		response = "I can see that possibility, but it doesn't settle much for me."
	else:
		response = "Those reports don't change my view of that."
	if stance != "accept" and not ev.rivals.is_empty():
		var rival: Dictionary = ev.rivals[0]
		if rival.shift > 0.2 and rival.posterior > 0.5:
			response += " If anything, it points me toward %s." % Solver.person_name(view, rival.id)
	if ev.movement.any(func(label): return label.begins_with("Movement / trace")):
		response += " The routes, observation coverage and traces change which explanation I favor. Lawful activity and eligible passers remain alternatives; this is circumstantial evidence."
	elif ev.movement.any(func(label): return label.begins_with("Challenged home alibi")):
		response += " If the linked observation is accurate, the home alibi is false. That is circumstantial evidence, not proof of deliberate deception or evil."
	elif not ev.movement.is_empty():
		response += " The supplied test factor changes which remaining explanation I favor; it does not prove it."
	return response

## Effects on everyone from one CaseEval pass over the same attended evidence, plus the
## intermediate claims. Same result shape as Consequences.assess.
## headline is {} for a belief refresh: no person is special, and refresh skips the
## intermediate claims and link diagnostics (they only explain a presented case).
static func _consequences_eval(view: Dictionary, value: Dictionary, baseline: Dictionary, headline: Dictionary, common_key: String, only: Array = [], refresh: bool = false) -> Dictionary:
	var span = Profiler.open("consequences")
	var attention = Reasoner.prepare(view, value, baseline)
	var compiled = Graph.compile_case(view, value)
	var scoped = _eval_case(view, compiled, attention, baseline)
	var attended: Array = Solver.selected(view, attention.case).filter(func(c): return c.id not in attention.private_checks.rejected)
	var challenged = Support.ReadingChallenges.assess(view, attention.case, baseline, attended)
	var eval_listener = _eval_listener(baseline, baseline.knowledge.get("own_reports", []), challenged, attention)
	var ev: Dictionary = CaseEval.evaluate(view, scoped, eval_listener)
	var protection = Protection.assess(view, attended, baseline)
	# The headline's own fatal check (say, accusing the listener) doesn't void what the
	# evidence says about everyone else: each person gets their own direct check.
	var invalid: bool = not attention.case.get("graph_errors", []).is_empty() or not Solver.validate_answers(view, attention.case).is_empty()
	var persistence: bool = baseline.get("confidence_mode", "scale") == "persistence"
	var confidence: float = 1.0 if persistence else 1.4 - 0.8 * baseline.confidence
	var theories: Dictionary = baseline.get("theories", {}).duplicate(true)
	var effects = {}
	for person in view.people:
		var id: String = person.id
		if not only.is_empty() and id not in only:
			continue
		var is_headline: bool = not headline.is_empty() and id == value.conclusion.target
		var theory: Dictionary = headline.theory if is_headline else {}
		# A refresh has no headline search; its effects all report the refresh itself.
		var status: String = headline.reasoning.status if not headline.is_empty() else "belief_refresh"
		var person_ev: Dictionary = ev
		if persistence:
			# A committed listener keeps a working theory per person and reads the
			# evidence through it (Theory bias), as the headline does.
			var evil_case: Dictionary = attention.case.duplicate(true)
			evil_case.conclusion = {"type": "evil", "target": id, "at": value.conclusion.at}
			# The explanation search only feeds Theory.prepare. Skip it when its result
			# would be unused: the headline's own theory, or a decision Theory already
			# has (unchanged inputs, or the fixed commitments a scoped reply inherits).
			if not is_headline or value.conclusion.type not in ["evil", "good", "suspicious"]:
				var known: Dictionary = Theory.cached(view, evil_case, baseline, common_key + id)
				if not known.is_empty():
					theory = known
				else:
					var clone = baseline.duplicate(true)
					var reasoning = Support.explain(view, evil_case, clone, Consequences._prepared(view, attention, evil_case, baseline))
					theory = Theory.prepare(view, evil_case, clone, reasoning, common_key + id)
					for key in clone.get("theories", {}):
						if key.begins_with(id + "|"):
							theories[key] = clone.theories[key]
			if not theory.get("bias", {}).is_empty():
				var biased = eval_listener.duplicate(true)
				biased["theory_bias"] = theory.bias
				person_ev = CaseEval.evaluate(view, scoped, biased)
		var odds: Dictionary = person_ev.people.get(id, {"prior": 0.0, "posterior": 0.0})
		var s: float = CaseEval.shift(odds.prior, odds.posterior) if not ev.impossible else 0.0
		var alignment: float = 0.45 * s
		var circumstantial = 0.0
		if not Movement.available(view):
			var pattern_case = attention.case.duplicate(true)
			pattern_case.conclusion = {"type": "suspicious", "target": id, "at": value.conclusion.at}
			pattern_case.cards = pattern_case.cards.filter(func(c): return c not in attention.private_checks.rejected)
			circumstantial = 0.3 * _pattern(view, pattern_case, baseline).weight
		var net_weight: float = circumstantial if circumstantial > absf(alignment) else alignment
		var protection_signal: float = -protection.get(id, {}).get("weight", 0.0)
		if absf(protection_signal) > absf(net_weight):
			net_weight = protection_signal
		for challenge in challenged.results:
			if challenge.mode == "lying" and challenge.source == id and challenge.agreement >= 0.6:
				net_weight = maxf(net_weight, 0.12 * challenge.agreement)
		var own_check: Dictionary = attention.case.duplicate(true)
		own_check.conclusion = {"type": "evil", "target": id, "at": value.conclusion.at}
		if invalid or Reasoner.direct_checks(view, own_check, baseline.knowledge).fatal or TimeModel.known_good(view, baseline.knowledge, id, value.conclusion.at) or value.conclusion.type == "conflict":
			net_weight = 0.0
		effects[id] = {"requested": net_weight * (0.5 + baseline.trust) * confidence, "alignment_signal": alignment, "pattern_signal": circumstantial,
			"route": "protection" if protection_signal != 0.0 and net_weight == protection_signal else ("circumstantial" if circumstantial > absf(alignment) else "alignment"),
			"protection_signal": protection_signal, "evil_agreement": odds.posterior, "good_agreement": 1.0 - odds.posterior,
			"evil_change": s, "good_change": -s, "prior": odds.prior, "posterior": odds.posterior,
			"cards": attention.considered.duplicate(), "theory": theory, "reasoning": status}
	var claims: Array = []
	var by_id = {}
	var arguments: Array = [] if refresh else Consequences._arguments(view, value)
	for argument in arguments:
		var claim_case = Consequences._scope(view, argument.case, attention.considered)
		claims.append(_eval_claim(view, argument, claim_case, attention, baseline, eval_listener))
		by_id[argument.id] = claims[-1]
	# Links: how the parent claim fares without the evidence only this branch brings.
	for argument in arguments:
		var child: Dictionary = by_id[argument.id]
		for parent_id in argument.parents:
			if not by_id.has(parent_id):
				continue
			var parent: Dictionary = by_id[parent_id]
			var parent_argument: Dictionary = arguments.filter(func(a): return a.id == parent_id)[0]
			var retained: Array = argument.get("without", {}).get(parent_id, [])
			if not argument.has("without"):
				for input in parent_argument.get("inputs", []):
					if input.id != argument.id:
						retained.append_array(input.cards)
			var exclusive: Array = child.cards.filter(func(id): return id not in retained)
			var without = Consequences._scope(view, parent_argument.case, parent.cards.filter(func(id): return id not in exclusive))
			var reduced = _eval_claim(view, parent_argument, without, attention, baseline, eval_listener)
			var contribution: float = parent.agreement - reduced.agreement
			var relation = "shared" if exclusive.is_empty() else ("strengthens" if contribution > 0.0000001 else ("weakens" if contribution < -0.0000001 else "no_preference"))
			var remaining: bool = not parent.reasoning.get("rival", {}).is_empty()
			var note = {"shared": "These original sources are already included through another connection.",
				"strengthens": "This branch's evidence strengthens the parent claim.",
				"weakens": "This branch's evidence weighs against the parent claim.",
				"no_preference": "This branch does not add a preference for the parent claim."}[relation]
			if child.stance == "reject":
				note += " I do not accept the intermediate claim; its label supplies no extra evidence."
			if remaining:
				note += " An alternative to the parent claim still fits what I checked."
			child.links.append({"parent": parent_id, "parent_label": parent.label, "relation": relation,
				"evidence_difference": contribution, "exclusive_cards": exclusive, "alternative_remains": remaining, "note": note})
	Profiler.close(span)
	return {"effects": effects, "claims": claims, "theories": theories, "considered": attention.considered,
		"reading_challenges": challenged.results,
		"reasoning": {"status": "belief_refresh", "impossible": ev.impossible, "profile": attention.profile, "considered": attention.considered.duplicate(),
			"ignored": attention.ignored.duplicate(), "ignored_lines": attention.ignored_lines.duplicate(), "private_checks": attention.private_checks.duplicate(true)},
		"rule": "One CaseEval pass over the attended evidence gives every person's change; intermediate claims add no evidence."}

## One claim (the headline or an intermediate) judged on the attended evidence it cites.
static func _eval_claim(view: Dictionary, argument: Dictionary, claim_case: Dictionary, attention: Dictionary, baseline: Dictionary, eval_listener: Dictionary) -> Dictionary:
	var checks = Reasoner.direct_checks(view, claim_case, baseline.knowledge)
	var scoped: Dictionary = claim_case.duplicate(true)
	var own: Array = baseline.knowledge.get("own_reports", [])
	scoped.cards = scoped.cards.filter(func(id): return id not in checks.rejected and id not in own)
	if scoped.conclusion.type == "suspicious":
		scoped.conclusion.type = "evil"
	var ev = CaseEval.evaluate(view, scoped, eval_listener)
	# The logical layer (what follows if the attended reports are sound) is the
	# reasoner's; how much the listener believes it is CaseEval's.
	var thought = Support.explain(view, claim_case, baseline, Consequences._prepared(view, attention, claim_case, baseline))
	var status: String = thought.status
	var agreement: float = clampf(CaseEval.shift(ev.prior, ev.posterior), -1.0, 1.0)
	var pattern: Dictionary = {"weight": 0.0}
	if claim_case.conclusion.type == "suspicious":
		var pattern_case = claim_case.duplicate(true)
		pattern_case.cards = pattern_case.cards.filter(func(id): return id not in checks.rejected)
		pattern = _pattern(view, pattern_case, baseline)
		agreement = maxf(agreement, pattern.agreement if pattern.weight > 0 else 0.0)
	if claim_case.conclusion.type == "conflict":
		agreement = 1.0 if status == "inconsistent" or not ev.consistent or not checks.rejected.is_empty() else 0.0
	if checks.fatal or ev.impossible:
		agreement = 0.0
	var note = "Another explanation remains possible."
	if claim_case.cards.is_empty():
		note = "No attended evidence was offered for this claim."
	elif checks.fatal:
		note = " ".join(PackedStringArray(checks.objections))
	elif claim_case.conclusion.type == "suspicious" and pattern.weight > 0:
		note = "The observations give a circumstantial reason for suspicion; they do not establish evil."
	elif claim_case.conclusion.type == "suspicious" and not ev.movement.is_empty() and agreement > 0:
		note = "The joint movement and trace comparison gives a circumstantial reason for suspicion; it does not establish evil."
	elif claim_case.conclusion.type == "conflict":
		note = "The considered accounts conflict; that does not identify deliberate deception or evil." if agreement > 0 else "I have not established a conflict in the considered accounts."
	elif status == "inconsistent" or not ev.consistent:
		note = "The premises I checked cannot all hold together."
	elif status == "entailed_in_attention":
		note = "This follows from the reports I granted, if those reports are sound."
	elif agreement >= 0.6:
		note = "The evidence favors this, though another explanation is still possible."
	elif status == "provisional":
		note = "This fits the evidence I checked; I have not checked another explanation."
	elif agreement <= -0.2:
		note = "The evidence weighs against this."
	var scoped_protection = Protection.assess(view, Solver.selected(view, claim_case).filter(func(c): return c.id not in checks.rejected), baseline)
	if claim_case.conclusion.type == "good" and scoped_protection.has(claim_case.conclusion.target) and not checks.fatal:
		agreement = maxf(agreement, minf(0.55, 0.35 + scoped_protection[claim_case.conclusion.target].weight))
		note = "A quiet night fits this protection claim, but it does not establish that an attack targeted their protection. Other explanations remain."
	return {"id": argument.id, "label": argument.label, "conclusion": claim_case.conclusion.duplicate(true),
		"parents": argument.parents.duplicate(), "cards": claim_case.cards.duplicate(),
		"ignored": Graph.compile_case(view, argument.case).cards.filter(func(id): return id not in claim_case.cards),
		"agreement": agreement, "stance": Consequences._stance(agreement), "status": status,
		"conditional_mass": 0.0, "forced_mass": 1.0 if status == "entailed_in_attention" and ev.consistent else 0.0,
		"note": note, "links": [], "support_model": {"agreement": agreement, "prior": ev.prior, "posterior": ev.posterior, "category": ev.category},
		"reasoning": thought}

static func _bounded_objection(reasoning: Dictionary) -> String:
	# Spoken objections use only this search, never the referee's alternative.
	var result: String = {"provisional": "I have not established that this is the only explanation.",
		"rival_found": "Both explanations fit the reports I granted for this comparison.",
		"entailed_in_attention": "This follows within the reports I considered, if they are accurate.",
		"inconsistent": "The accounts I checked cannot all be accurate together.",
		"counterexample_found": "I checked an alternative, but did not establish your proposed explanation.",
		"unresolved": "I could not make all the pieces fit, but I may be missing something."}.get(reasoning.status, "")
	if not reasoning.doubted.is_empty():
		result += " I still doubt these reports: " + ", ".join(PackedStringArray(reasoning.doubted)) + "."
	return result

static func _quality(view: Dictionary, ids: Array, listener: Dictionary) -> float:
	var sources: Array = []
	var quality = 1.0
	for id in ids:
		var card = Solver.card_by_id(view, id)
		if card.is_empty():
			continue
		var source: String = card.source
		if source == listener.id or source in sources:
			continue
		sources.append(source)
		if source == "player":
			quality *= 0.9
		else:
			quality *= clampf(0.2 + 0.65 * listener.npc_trust.get(source, 0.5) - 0.35 * listener.suspicion.get(source, 0.1), 0.05, 0.95)
	return quality

static func _possibility_agreement(view: Dictionary, worlds: Array, conclusion: Dictionary, listener: Dictionary) -> float:
	# Compare the listener's strongest supporting and rival explanations, as Argue
	# does. This is an uncalibrated disposition score, not a fraction of worlds.
	var supporting = 0.0
	var rival = 0.0
	for world in worlds:
		var score = 1.0
		for i in range(view.people.size()):
			var id: String = view.people[i].id
			var suspicion: float = listener.suspicion.get(id, 0.1)
			var trust: float = listener.npc_trust.get(id, 0.5)
			if world.evil & (1 << i):
				score *= maxf(0.15 + suspicion * 1.2 - (trust - 0.5) * 0.5, 0.02)
			else:
				score *= maxf(0.3 + (0.6 - suspicion) * 0.6 + (trust - 0.5) * 0.4, 0.05)
		if Solver.holds(view, world, conclusion):
			supporting = maxf(supporting, score)
		else:
			rival = maxf(rival, score)
	return 0.02 + 0.16 * supporting / maxf(supporting + rival, 0.000000001)

static func _pattern(view: Dictionary, case_data: Dictionary, listener: Dictionary) -> Dictionary:
	if Movement.available(view):
		return {"weight": 0.0, "agreement": 0.0, "quality": 0.0, "cards": [], "kind": "joint_movement", "incidents": 0, "alibi_conflicts": []}
	var target: String = case_data.conclusion.target
	var incidents = {}
	var contradictions: Array = []
	var cards = Solver.selected(view, case_data)
	for card in cards:
		var out: bool = (card.kind == "sighting" and target in card.get("subjects", [card.subject])) or (card.kind == "report" and card.get("role", "") == "nightwatch" and target in card.data.seen)
		if not out:
			continue
		var key = "%s:%d" % [target, card.night]
		var q = _quality(view, [card.id], listener)
		if not incidents.has(key) or q > incidents[key].quality:
			incidents[key] = {"quality": q, "card": card.id, "night": card.night}
	var weight = 0.0
	var path: Array = []
	for key in incidents:
		var incident: Dictionary = incidents[key]
		var explanation: String = case_data.reasons.get(key, "unexplained")
		var explained = 0.0
		if explanation == "gift":
			var claim = Graph.valid_citation(view, case_data, target, incident.night)
			if not claim.is_empty():
				explained = 0.8 * _quality(view, [claim.id], listener)
				path.append(claim.id)
		# Merely selecting 'gift' without supporting testimony is not an explanation.
		weight += 0.3 * incident.quality * (1.0 - explained)
		path.append(incident.card)
		for card in cards:
			if card.kind == "alibi" and card.subject == target and card.night == incident.night:
				weight += 0.2 * minf(incident.quality, _quality(view, [card.id], listener))
				contradictions.append(card.id)
				path.append(card.id)
	return {"weight": minf(weight, 0.8), "agreement": 0.5 if weight > 0 else 0.0, "quality": minf(weight / 0.5, 1.0),
		"cards": path, "kind": "pattern", "incidents": incidents.size(), "alibi_conflicts": contradictions}

static func _objection(view: Dictionary, case_data: Dictionary, listener: Dictionary, shared: Dictionary, assessment: Dictionary, best: Dictionary, pattern: Dictionary) -> String:
	if best.kind == "pattern" and best.weight > 0:
		if not pattern.alibi_conflicts.is_empty():
			return "The outing conflicts with the home alibi. Someone's account is wrong; that adds suspicion but does not identify evil."
		return "These are %d distinct outings. A credible night gift can explain an outing; seeing someone twice on one night is one incident." % pattern.incidents
	if assessment.status == "conflicting":
		if not assessment.errors.is_empty():
			return assessment.errors[0]
		if shared.status != "conflicting":
			return "That conflicts with my own gift or my knowledge that I am good."
		return "The asserted reports, answers or home alibis cannot all hold together. Remove or challenge a premise."
	if best.kind == "conditional":
		return "Your selected people narrow the world; choosing an answer does not establish it."
	if best.quality < 0.45 and not best.cards.is_empty():
		var weakest = ""
		var lowest = 2.0
		for id in best.cards:
			var q = _quality(view, [id], listener)
			if q < lowest:
				lowest = q
				weakest = id
		return "I am least convinced by %s's report (%s); its source and health assumptions still matter." % [Solver.person_name(view, Solver.card_by_id(view, weakest).source), weakest]
	if not assessment.alternative.is_empty() and assessment.entailment == "possible":
		var a: Dictionary = assessment.alternative
		if a.has("demon"):
			return "An alternative still fits with %s as the Demon; the other evil residents could be minions." % Solver.person_name(view, a.demon)
		return "An alternative still fits: %s evil; %s Marked." % [", ".join(PackedStringArray(a.evil.map(func(id): return Solver.person_name(view, id)))), Solver.person_name(view, a.marked)]
	if assessment.entailment == "unsupported":
		return "The accepted reports exclude that conclusion."
	return "This depends on the named sources being honest, holding their claimed gifts and being healthy at the reported times."

static func _signature(view: Dictionary, case_data: Dictionary) -> String:
	var keys: Array = Solver.selected(view, case_data).map(func(c): return Solver.semantic_key(c))
	for factor in preload("res://workshop/public_evidence.gd").factors(view):
		keys.append("public:" + factor.target + ":" + str(factor.log2_ratio))
	keys.sort()
	var answers = {}
	for card in Solver.selected(view, case_data):
		var positive: Array = case_data.answers.get(card.id, {}).get("positive", []).duplicate()
		if not positive.is_empty():
			positive.sort()
			answers[Solver.semantic_key(card)] = positive
	# Ignore wrapper ids, card/slot order, version and venue.
	var citations = {}
	for key in case_data.get("citations", {}):
		citations[key] = Solver.semantic_key(Solver.card_by_id(view, case_data.citations[key]))
	var scope: Array = Graph.roots(case_data, case_data.get("conflict_scope", [])).map(func(id): return Solver.semantic_key(Solver.card_by_id(view, id)))
	scope.sort()
	var factors: Array = []
	for factor in case_data.get("test_factors", []):
		if not is_zero_approx(float(factor.log2_ratio)):
			var routes: Array = []
			for route in factor.routes:
				var facts: Array = route.map(func(id): return Solver.semantic_key(Solver.card_by_id(view, id)))
				facts.sort()
				routes.append(JSON.stringify(facts))
			routes.sort()
			factors.append(JSON.stringify([factor.target, factor.log2_ratio, factor.events, routes]))
	factors.sort()
	var timed: Array = []
	for assignment in case_data.get("temporal_positions", []):
		for id in assignment.positions:
			var atom = [assignment.at, id, assignment.positions[id]]
			if atom not in timed:
				timed.append(atom)
	timed.sort_custom(func(a, b): return JSON.stringify(a) < JSON.stringify(b))
	var signature = JSON.stringify(_canonical([keys, case_data.positions, answers, case_data.reasons, citations, scope, case_data.get("challenges", {}), factors, case_data.conclusion, case_data.get("graph_errors", []), case_data.get("faults", {}), timed]))
	return signature if case_data.get("reading_challenges", {}).is_empty() else signature + JSON.stringify(_canonical(case_data.reading_challenges))

static func _canonical(value):
	if value is Dictionary:
		var result = {}
		var keys = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		return value.map(func(item): return _canonical(item))
	return value

static func _changes(view: Dictionary, previous: Dictionary, current: Dictionary) -> Array:
	var changes: Array = []
	if previous.is_empty():
		return changes
	for id in current.cards:
		if id not in previous.cards:
			var card = Solver.card_by_id(view, id)
			changes.append("You added %s's %s." % [Solver.person_name(view, card.source), card.get("role", card.kind)])
	for id in previous.cards:
		if id not in current.cards:
			var card = Solver.card_by_id(view, id)
			if card.is_empty():
				changes.append("You removed a previously cited report.")
			else:
				changes.append("You removed %s's %s." % [Solver.person_name(view, card.source), card.get("role", card.kind)])
	if previous.positions != current.positions:
		changes.append("You changed the assumed alignments or Marked identity.")
	if previous.answers != current.answers:
		changes.append("You changed the answers on your cards.")
	if previous.reasons != current.reasons:
		changes.append("You changed the explanations for the outings.")
	if previous.conclusion != current.conclusion:
		changes.append("You changed the conclusion.")
	return changes
