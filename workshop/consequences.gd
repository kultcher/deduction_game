## One frozen evidence set, several consequences. Claims are questions to
## assess, never additional reports. All projections use the same attention set.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const Support = preload("res://workshop/support_model.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Theory = preload("res://workshop/theory.gd")
const Movement = preload("res://workshop/movement_model.gd")
const Protection = preload("res://workshop/live_protection.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Profiler = preload("res://workshop/profiler.gd")

static func assess(view: Dictionary, value: Dictionary, baseline: Dictionary, pattern_fn: Callable, common_key: String, primary_theory: Dictionary) -> Dictionary:
	var span = Profiler.open("consequences")
	var result = _assess(view, value, baseline, pattern_fn, common_key, primary_theory)
	Profiler.close(span)
	return result

static func _assess(view: Dictionary, value: Dictionary, baseline: Dictionary, pattern_fn: Callable, common_key: String, primary_theory: Dictionary) -> Dictionary:
	var attention = Reasoner.prepare(view, value, baseline)
	var effects = {}
	var projections = {}
	var theories: Dictionary = baseline.get("theories", {}).duplicate(true)
	# One listener and one frozen attention set. Full queries can share a mixture
	# plan even with answers/positions; their conditional checks remain separate.
	var shared = {"enabled": baseline.get("reasoning_mode", "full") == "full" and baseline.get("confidence_mode", "scale") == "scale"}
	var challenged = Support.ReadingChallenges.assess(view, attention.case, baseline, Solver.selected(view, attention.case).filter(func(c): return c.id not in attention.private_checks.rejected))
	var protection = Protection.assess(view, Solver.selected(view, attention.case).filter(func(c): return c.id not in attention.private_checks.rejected), baseline)
	for person in view.people:
		var evil_case: Dictionary = attention.case.duplicate(true)
		evil_case.conclusion = {"type": "evil", "target": person.id, "at": value.conclusion.at}
		var prepared = _prepared(view, attention, evil_case, baseline)
		var clone = baseline.duplicate(true)
		var reasoning = Support.explain(view, evil_case, clone, prepared)
		var theory = primary_theory if person.id == value.conclusion.target and value.conclusion.type in ["evil", "good", "suspicious"] else Theory.prepare(view, evil_case, clone, reasoning, common_key + person.id)
		for key in clone.get("theories", {}):
			if key.begins_with(person.id + "|"):
				theories[key] = clone.theories[key]
		var evil = Support.assess(view, evil_case, baseline, theory.bias, prepared, shared)
		var good_case = evil_case.duplicate(true)
		good_case.conclusion.type = "good"
		var good_prepared = _prepared(view, attention, good_case, baseline)
		var good = Support.assess(view, good_case, baseline, theory.bias, good_prepared, shared)
		# Subtract what the listener's private evidence and priors already explained.
		# Comparing evil and good also lets exonerating evidence reduce suspicion.
		var contrast: float = evil.evidence_agreement - good.evidence_agreement
		var alignment: float = 0.45 * (clampf(contrast, -1.0, 1.0) if Movement.available(view) else contrast)
		var pattern_case = evil_case.duplicate(true)
		pattern_case.conclusion.type = "suspicious"
		pattern_case.cards = pattern_case.cards.filter(func(id): return id not in prepared.private_checks.rejected)
		var pattern: Dictionary = pattern_fn.call(view, pattern_case, baseline)
		var circumstantial: float = 0.0 if Movement.available(view) else 0.3 * pattern.weight
		# Existing pattern tuning and the world comparison can describe the SAME
		# incident. Use the stronger route, never sum them. Slice 4 replaces this
		# provisional envelope with a causal movement/trace model.
		var net_weight: float = circumstantial if circumstantial > absf(alignment) else alignment
		var protection_signal: float = -protection.get(person.id, {}).get("weight", 0.0)
		if absf(protection_signal) > absf(net_weight):
			net_weight = protection_signal
		for challenge in challenged.results:
			if challenge.mode == "lying" and challenge.source == person.id and challenge.agreement >= 0.6:
				net_weight = maxf(net_weight, 0.12 * challenge.agreement)
		if prepared.private_checks.fatal or not attention.case.get("graph_errors", []).is_empty() or not Solver.validate_answers(view, attention.case).is_empty():
			net_weight = 0.0
		if TimeModel.known_good(view, baseline.knowledge, person.id, value.conclusion.at):
			net_weight = 0.0
		if value.conclusion.type == "conflict":
			net_weight = 0.0 # Identifying inconsistent testimony is not an accusation.
		var confidence: float = 1.0 if baseline.get("confidence_mode", "scale") == "persistence" else 1.4 - 0.8 * baseline.confidence
		var effect: float = net_weight * (0.5 + baseline.trust) * confidence
		effects[person.id] = {"requested": effect, "alignment_signal": alignment, "pattern_signal": circumstantial,
			"route": "protection" if protection_signal != 0.0 and net_weight == protection_signal else ("circumstantial" if circumstantial > absf(alignment) else "alignment"), "protection_signal": protection_signal,
			"evil_agreement": evil.agreement, "good_agreement": good.agreement,
			"evil_change": evil.evidence_agreement, "good_change": good.evidence_agreement,
			"cards": attention.considered.duplicate(), "theory": theory, "reasoning": reasoning.status}
		projections[person.id] = {"evil": evil, "good": good, "bias": theory.bias}
	var arguments = _arguments(view, value)
	var claims: Array = []
	var by_id = {}
	for argument in arguments:
		var scoped = _scope(view, argument.case, attention.considered)
		var prepared = _prepared(view, attention, scoped, baseline)
		var thought = Support.explain(view, scoped, baseline, prepared)
		var bias: Dictionary = projections[scoped.conclusion.target].bias
		var support = Support.assess(view, scoped, baseline, bias, prepared)
		var pattern_case = scoped.duplicate(true)
		pattern_case.cards = pattern_case.cards.filter(func(id): return id not in prepared.private_checks.rejected)
		var pattern: Dictionary = pattern_fn.call(view, pattern_case, baseline)
		var agreement: float = support.agreement
		if scoped.conclusion.type == "suspicious":
			agreement = maxf(agreement, pattern.agreement if pattern.weight > 0 else 0.0)
			if Movement.available(view) and support.evidence_agreement > 0:
				agreement = maxf(agreement, 0.5)
		elif scoped.conclusion.type == "conflict":
			agreement = 1.0 if thought.status == "inconsistent" or not thought.private_checks.rejected.is_empty() else 0.0
		if thought.private_checks.fatal:
			agreement = 0.0
		var note = "Another explanation remains possible."
		if scoped.cards.is_empty():
			note = "No attended evidence was offered for this claim."
		elif thought.private_checks.fatal:
			note = " ".join(PackedStringArray(thought.private_checks.objections))
		elif scoped.conclusion.type == "suspicious" and pattern.weight > 0:
			note = "The observations give a circumstantial reason for suspicion; they do not establish evil."
		elif scoped.conclusion.type == "suspicious" and Movement.available(view) and support.evidence_agreement > 0:
			note = "The joint movement and trace comparison gives a circumstantial reason for suspicion; it does not establish evil."
		elif scoped.conclusion.type == "conflict":
			note = "The considered accounts conflict; that does not identify deliberate deception or evil." if agreement > 0 else "I have not established a conflict in the considered accounts."
		elif thought.status == "entailed_in_attention":
			note = "This follows from the reports I granted, if those reports are sound."
		elif thought.status == "provisional":
			note = "This fits the evidence I checked; I have not checked another explanation."
		elif thought.status == "inconsistent":
			note = "The premises I checked cannot all hold together."
		elif Movement.available(view) and agreement >= 0.6 and thought.status == "rival_found":
			note = "Another explanation still fits, but the joint movement and trace comparison favors this claim."
		var scoped_protection = Protection.assess(view, Solver.selected(view, scoped).filter(func(c): return c.id not in prepared.private_checks.rejected), baseline)
		if scoped.conclusion.type == "good" and scoped_protection.has(scoped.conclusion.target) and not thought.private_checks.fatal:
			agreement = maxf(agreement, minf(0.55, 0.35 + scoped_protection[scoped.conclusion.target].weight))
			note = "A quiet night fits this protection claim, but it does not establish that an attack targeted their protection. Other explanations remain."
		var item = {"id": argument.id, "label": argument.label, "conclusion": scoped.conclusion.duplicate(true),
			"parents": argument.parents.duplicate(), "cards": scoped.cards.duplicate(),
			"ignored": Graph.compile_case(view, argument.case).cards.filter(func(id): return id not in scoped.cards),
			"agreement": agreement, "stance": _stance(agreement), "status": thought.status,
			"conditional_mass": support.conditional_mass, "forced_mass": support.forced_mass,
			"note": note, "links": [], "support_model": support, "reasoning": thought}
		claims.append(item)
		by_id[argument.id] = item
	# Link diagnostics remove only evidence exclusive to that input. Shared roots
	# remain through sibling inputs. These differences are explanatory, not bonuses.
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
			var without = _scope(view, parent_argument.case, parent.cards.filter(func(id): return id not in exclusive))
			var reduced = Support.assess(view, without, baseline, projections[parent.conclusion.target].bias, _prepared(view, attention, without, baseline))
			var contribution: float = parent.support_model.agreement - reduced.agreement
			var relation = "shared" if exclusive.is_empty() else ("strengthens" if contribution > 0.0000001 else ("weakens" if contribution < -0.0000001 else "no_preference"))
			var remaining: bool = not parent.reasoning.rival.is_empty()
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
	return {"effects": effects, "claims": claims, "theories": theories, "considered": attention.considered,
		"rule": "One signed effect per person from the same starting beliefs and attended evidence. Intermediate claims add no evidence. Alignment and overlapping pattern routes use the stronger absolute effect, never their sum."}

static func _prepared(view: Dictionary, attention: Dictionary, scoped: Dictionary, listener: Dictionary) -> Dictionary:
	var result = attention.duplicate(true)
	result.case = scoped
	result.considered = scoped.cards.duplicate()
	result.private_checks = Reasoner.direct_checks(view, scoped, listener.knowledge)
	return result

static func _scope(view: Dictionary, value: Dictionary, ids: Array) -> Dictionary:
	var result = Graph.compile_case(view, value)
	result.cards = result.cards.filter(func(id): return id in ids)
	result.test_factors = result.test_factors.filter(func(f): return f.routes.any(func(route): return route.all(func(id): return id in result.cards)))
	for factor in result.test_factors:
		factor.routes = factor.routes.filter(func(route): return route.all(func(id): return id in result.cards))
	result.quoted_cards = result.quoted_cards.filter(func(id): return id in result.cards)
	return result

static func _arguments(view: Dictionary, value: Dictionary) -> Array:
	if value.has("arguments"):
		return value.arguments
	# List-lab cases have one level of lines. Preserve the same claim semantics.
	var result: Array = [{"id": "root", "label": "%s is %s" % [Solver.person_name(view, value.conclusion.target), value.conclusion.type], "parents": [], "case": value, "inputs": []}]
	for line in value.get("lines", []):
		if line.relation != "supports":
			continue
		result[0].inputs.append({"id": line.id, "cards": Graph.roots(value, line.cards)})
		if not line.has("conclusion"):
			continue
		var scoped = value.duplicate(true)
		scoped.cards = Graph.roots(value, line.cards)
		scoped.lines = [line]
		scoped.conclusion = line.conclusion.duplicate(true)
		result.append({"id": line.id, "label": line.label, "parents": ["root"], "case": scoped, "inputs": []})
	return result

static func _stance(agreement: float) -> String:
	return "accept" if agreement >= Tuning.Workshop.STANCE_ACCEPT else ("partial" if agreement >= Tuning.Workshop.STANCE_PARTIAL else "reject")
