## Player-raised questions about a report. Never consult referee truth.
extends RefCounted
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
static var cache: Dictionary = {}
static var fraction_cache: Dictionary = {}
const MODES = ["misled", "lying", "unlikely"]

static func valid(view: Dictionary, id: String, value) -> bool:
	var card = Solver.card_by_id(view, id)
	return value is Dictionary and value.get("mode") in MODES and card.get("kind") == "report" and not card.has("relay_source") and not card.get("testimony_only", false) and (value.mode != "unlikely" or card.get("role") == "surveyor") and value.get("supports", []) is Array and value.get("supports", []).all(func(root): return root != id and not Solver.card_by_id(view, root).is_empty())

static func quality(listener: Dictionary, source: String) -> float:
	if source == listener.id or source == "evidence":
		return 1.0
	if source == "player":
		return clampf(listener.trust, 0.0, 1.0)
	return clampf(0.2 + 0.65 * listener.npc_trust.get(source, 0.5) - 0.35 * listener.suspicion.get(source, 0.1), 0.05, 0.95)

static func assess(view: Dictionary, value: Dictionary, listener: Dictionary, cards: Array) -> Dictionary:
	var selected: Dictionary = value.get("reading_challenges", {})
	if selected.is_empty():
		return {"reports": {}, "sources": {}, "results": []}
	var input = [view.people, view.get("timeline", {}), view.get("live_activity", false), view.get("world_options", {}), view.evil_count, selected, cards, listener.knowledge, listener.suspicion, listener.npc_trust, listener.trust]
	var key = hash(input)
	if cache.has(key) and cache[key].input == input:
		return cache[key].result
	var result = {"reports": {}, "sources": {}, "results": []}
	var reference = null
	for id in selected:
		if not valid(view, id, selected[id]) or not cards.any(func(c): return c.id == id):
			continue
		var challenge: Dictionary = selected[id]
		var report = Solver.card_by_id(view, id)
		# All challenges share the listener's baseline. Filter the hypothetical good
		# claimant below instead of solving that same baseline once per report.
		if reference == null:
			reference = Solver.solve(view, [], {}, {}, listener.knowledge).worlds
		var counted = _fraction(view, report, listener.knowledge, reference)
		var fraction: float = counted.fraction
		var has_reference: bool = counted.possible
		var grounds: Array = cards.filter(func(c): return c.id in challenge.get("supports", []) and c.id != id and not c.get("quoted", false) and quality(listener, c.source) >= 0.4)
		var conflict = false
		var strength = 1.0
		if not grounds.is_empty():
			var alone = Solver.solve(view, grounds, {}, {}, listener.knowledge)
			var together = Solver.solve(view, grounds + [report], {}, {}, listener.knowledge)
			conflict = not alone.worlds.is_empty() and alone.movement_ok and (together.worlds.is_empty() or not together.movement_ok)
			for ground in grounds:
				strength = minf(strength, quality(listener, ground.source))
		var supported = (fraction == 0.0 and has_reference) or conflict or (challenge.mode == "unlikely" and fraction < 0.05 and has_reference)
		var accuracy_agreement = 0.0
		var multiplier = 1.0
		var note = "You question that report, but the cited evidence does not establish a problem."
		if supported:
			accuracy_agreement = 0.8 * strength if conflict else (0.9 if fraction == 0.0 else 0.6)
			multiplier = 1.0 - (0.65 * strength if conflict else (0.75 if fraction == 0.0 else 0.35))
			note = "The report conflicts with the cited evidence. Its contents deserve less weight; the cause remains uncertain." if conflict else ("That report cannot fit the established facts under its good, healthy-source assumptions." if fraction == 0.0 else "That count requires an unusually restrictive town layout. I will treat it with some caution, though it may be accurate.")
		elif challenge.mode == "unlikely":
			note = "That count fits ordinary town layouts. Calling it unlikely supplies no reason to discount it."
		if challenge.mode == "misled" and report.role == "seer" and report.data.yes:
			var joint = Solver.solve(view, grounds + [report], {}, {}, listener.knowledge)
			var pair_indices: Array = report.data.pair.map(func(person): return Solver.person_index(view, person))
			if not grounds.is_empty() and not joint.worlds.is_empty() and joint.worlds.all(func(w): return w.has("demon") and w.demon not in pair_indices):
				supported = true
				accuracy_agreement = 0.8 * strength
				multiplier = 1.0 # The gift can function correctly and still mislead.
				note = "Together these readings exclude the Demon from that pair. A Red Herring or Marked registration can mislead an honest Seer without a broken gift."
			elif not supported:
				note = "A Red Herring or Marked registration could mislead an honest Seer. This modifier alone does not establish that explanation."
		var hearing: float = clampf(float(challenge.get("weight", 1.0)), 0.0, 1.0)
		accuracy_agreement *= hearing
		multiplier = 1.0 - hearing * (1.0 - multiplier)
		var cause_agreement: float = accuracy_agreement
		if challenge.mode == "lying":
			# Discrepancy alone does not identify the dishonest source. Disposition
			# can favor that hypothesis, but cannot create evidence for it.
			cause_agreement *= 1.0 - quality(listener, report.source)
			if report.source != listener.id and report.role == listener.knowledge.get("own_role", ""):
				cause_agreement = hearing # firsthand knowledge of a unique gift claim
				note = "They claim the unique gift I know I hold. Impairment cannot explain that role claim."
			if report.source in listener.knowledge.good:
				cause_agreement = 0.0
				note += " My established good-alignment knowledge does not support the evil-reader explanation."
			if cause_agreement >= 0.6:
				result.sources[report.source] = minf(result.sources.get(report.source, 1.0), 1.0 - 0.3 * cause_agreement)
			else:
				note += " I am not convinced the reader deliberately lied."
		elif challenge.mode == "misled" and supported:
			note += " Misled can include impairment or a gift's misleading registration; it does not establish poisoning."
		result.reports[id] = multiplier
		result.results.append({"card": id, "mode": challenge.mode, "supported": supported, "fraction": fraction,
			"agreement": cause_agreement, "accuracy_agreement": accuracy_agreement, "multiplier": multiplier, "source": report.source, "note": note})
	if cache.size() >= 64:
		cache.clear()
	cache[key] = {"input": input.duplicate(true), "result": result}
	return result

## Count distinct alignment/modifier layouts, ignoring redundant Demon identities.
## Report and role tables are compiled once; no per-world strings or role-cache hash.
static func _fraction(view: Dictionary, report: Dictionary, knowledge: Dictionary, reference: Array) -> Dictionary:
	var input = [Solver._universe_key(view), view.people, view.get("timeline", {}), view.get("live_activity", false), report, Solver._query_knowledge(knowledge)]
	var key = hash(input)
	if fraction_cache.has(key) and fraction_cache[key].input == input:
		return fraction_cache[key].result
	var universe: Array = Solver.universe(view)
	var table: PackedByteArray = Solver.report_table(view, report)
	var roles: PackedByteArray = Solver.Roles.fits_table(view, universe, [report], knowledge)
	var compatible: bool = Domain.claims_compatible([report], knowledge)
	var indices = {}
	for i in range(universe.size()):
		indices[Solver.TimeModel.key(view, universe[i])] = i
	var denominator = {}
	var numerator = {}
	var n: int = view.people.size()
	for world in reference:
		if not Solver.position_holds(view, world, report.source, "good", knowledge.get("good_epoch", "")) or not Domain.healthy(view, world, report.source):
			continue
		var modifier: int = Domain.C.SECRET_MOD_LIST.find(world.get("modifier", "marked"))
		var base_key: int = (int(world.evil) * 4 + modifier) * (1 << n) + int(world.get("holders", 1 << world.marked))
		denominator[base_key] = true
		var i: int = indices[Solver.TimeModel.key(view, world)]
		if compatible and table[i] != 0 and roles[i] != 0:
			numerator[base_key] = true
	var result = {"fraction": float(numerator.size()) / maxf(denominator.size(), 1), "possible": not denominator.is_empty()}
	if fraction_cache.size() >= 128:
		fraction_cache.clear()
	fraction_cache[key] = {"input": input.duplicate(true), "result": result}
	return result
