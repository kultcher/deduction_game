## Deterministic, bounded hypothesis testing. Never consumes the referee's worlds.
extends RefCounted
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Profiler = preload("res://workshop/profiler.gd")
static var matches: Dictionary = {}
static var reuse_matches = true # developer A/B switch, not a reasoning-budget change

static func profile(insight: float) -> Dictionary:
	if insight < 0.34:
		return {"name": "Low", "cards": 3, "lines": 1, "support": 8, "rivals": 0, "complete": false}
	if insight < 0.67:
		return {"name": "Medium", "cards": 5, "lines": 2, "support": 48, "rivals": 16, "complete": false}
	return {"name": "High", "cards": 10, "lines": 6, "support": 840, "rivals": 840, "complete": true}

static func prepare(view: Dictionary, value: Dictionary, listener: Dictionary) -> Dictionary:
	var full = Graph.compile_case(view, value)
	if full.conclusion.type == "conflict":
		var scope = Graph.roots(value, full.get("conflict_scope", []))
		full.cards = full.cards.filter(func(id): return id in scope)
	var limits = profile(listener.get("insight", 0.5))
	var bounded: bool = listener.get("reasoning_mode", "full") == "bounded"
	var cards = Solver.selected(view, full)
	var groups: Array = []
	var assigned: Array = []
	for line in value.get("lines", []):
		if line.relation == "supports":
			var roots = Graph.roots(value, line.cards).filter(func(id): return id in full.cards)
			if roots.is_empty():
				continue
			assigned.append_array(roots)
			_add_group(view, groups, line.id, roots, full.conclusion.target, listener)
	var unassigned: Array = cards.filter(func(c): return c.id not in assigned).map(func(c): return c.id)
	if not unassigned.is_empty():
		_add_group(view, groups, "", unassigned, full.conclusion.target, listener)
	groups.sort_custom(func(a, b): return a.score > b.score if not is_equal_approx(a.score, b.score) else a.key < b.key)
	var keep: Array = []
	var kept_lines: Array = []
	var connections: Array = []
	for i in range(groups.size()):
		if bounded and i >= limits.lines:
			continue
		keep.append_array(groups[i].cards)
		kept_lines.append_array(groups[i].ids)
		connections.append(groups[i].key)
	var ranked: Array = cards.filter(func(c): return c.id in keep and c.id not in listener.knowledge.get("own_reports", []))
	ranked.sort_custom(func(a, b):
		var x = _salience(a, full.conclusion.target, listener)
		var y = _salience(b, full.conclusion.target, listener)
		return x > y if not is_equal_approx(x, y) else Solver.semantic_key(a) < Solver.semantic_key(b))
	keep = ranked.slice(0, limits.cards if bounded else ranked.size()).map(func(c): return c.id)
	for id in listener.knowledge.get("own_reports", []):
		if cards.any(func(c): return c.id == id):
			keep.append(id)
	var raw = value.duplicate(true)
	raw.cards = keep
	raw.derived = []
	raw.lines = raw.get("lines", []).filter(func(line): return line.relation == "supports" and line.id in kept_lines)
	for line in raw.lines:
		line.cards = Graph.roots(value, line.cards).filter(func(id): return id in keep)
	var attended = Graph.compile_case(view, raw)
	# Graph expansion must not reintroduce an unattended source or fault premise.
	attended.cards = keep
	attended.lines = []
	return {"case": attended, "profile": limits.name if bounded else "Full",
		"limits": limits, "considered": keep, "ignored": cards.filter(func(c): return c.id not in keep).map(func(c): return c.id),
		"lines": kept_lines, "connections": connections,
		"ignored_lines": value.get("lines", []).filter(func(line): return line.relation == "supports" and line.id not in kept_lines).map(func(line): return line.id),
		"private_reports": listener.knowledge.get("own_reports", []).duplicate(),
		"private_checks": direct_checks(view, full, listener.knowledge)}

static func _add_group(view: Dictionary, groups: Array, id: String, roots: Array, target: String, listener: Dictionary) -> void:
	var facts: Array = roots.map(func(root): return Solver.semantic_key(Solver.card_by_id(view, root)))
	facts.sort()
	var key = JSON.stringify(facts)
	for group in groups:
		if group.key == key:
			group.ids.append(id)
			return
	groups.append({"ids": [id], "key": key, "cards": roots, "score": _group_score(view, roots, target, listener)})

static func _salience(card: Dictionary, target: String, listener: Dictionary) -> float:
	var score = 1.0 + listener.npc_trust.get(card.source, 0.5) * 0.1
	if card.kind == "report" and card.role in ["surveyor", "rumormonger", "dowser"]:
		score += 3.0
	if card.get("subject", "") == target or target in card.get("data", {}).get("pair", []) or target in card.get("data", {}).get("group", []) or target in card.get("data", {}).get("seen", []):
		score += 2.0
	return score

static func _group_score(view: Dictionary, ids: Array, target: String, listener: Dictionary) -> float:
	var score = 0.0
	for id in ids:
		var card = Solver.card_by_id(view, id)
		if not card.is_empty():
			score = maxf(score, _salience(card, target, listener))
	return score

static func search(view: Dictionary, case_data: Dictionary, cards: Array, listener: Dictionary, limits: Dictionary) -> Dictionary:
	var span = Profiler.open("candidate_search")
	var result = _search(view, case_data, cards, listener, limits)
	Profiler.count("candidates_tested", result.tested)
	Profiler.close(span)
	return result

static func _search(view: Dictionary, case_data: Dictionary, cards: Array, listener: Dictionary, limits: Dictionary) -> Dictionary:
	var local = _local_conflict(cards)
	if not local.is_empty() or not case_data.get("graph_errors", []).is_empty() or not Solver.validate_answers(view, case_data).is_empty():
		return {"status": "inconsistent", "support": {}, "rival": {}, "tested": 0, "support_tested": 0,
			"rivals_tested": 0, "rivals_exhausted": true, "support_exhausted": true, "limited": false, "local_conflict": local}
	var support = _find(view, cards, case_data, listener, limits.support, true, case_data.positions, case_data.answers)
	var rival = {"world": {}, "tested": 0, "exhausted": false}
	if limits.rivals > 0:
		if limits.complete or support.world.is_empty():
			rival = _find(view, cards, case_data, listener, limits.rivals, false, {}, {})
		else:
			rival = _swaps(view, cards, case_data, listener, support.world, limits.rivals)
	var result = "unresolved"
	if not support.world.is_empty():
		result = "rival_found" if not rival.world.is_empty() else ("entailed_in_attention" if rival.exhausted else "provisional")
	elif not rival.world.is_empty():
		result = "counterexample_found"
	elif support.exhausted and rival.exhausted:
		result = "inconsistent"
	return {"status": result, "support": support.world, "rival": rival.world, "tested": support.tested + rival.tested,
		"support_tested": support.tested, "rivals_tested": rival.tested, "rivals_exhausted": rival.exhausted,
		"support_exhausted": support.exhausted, "limited": not rival.exhausted}

static func _local_conflict(cards: Array) -> Array:
	# Direct two-account contradiction, not a complete multi-card theorem search.
	for home in cards:
		if home.kind != "alibi" or home.get("quoted", false):
			continue
		for sight in cards:
			if home.get("night", -1) != sight.get("night", -2):
				continue
			if (sight.kind == "sighting" and sight.subject == home.subject) or (sight.kind == "report" and sight.role == "nightwatch" and home.subject in sight.data.seen):
				return [home.id, sight.id]
	return []

static func _find(view: Dictionary, cards: Array, case_data: Dictionary, listener: Dictionary, budget: int, want: bool, positions: Dictionary, answers: Dictionary) -> Dictionary:
	if Domain.live(view):
		return _find_live(view, cards, case_data, listener, budget, want, positions, answers)
	var ids: Array = view.people.map(func(p): return p.id)
	var good: Array = listener.knowledge.get("good", []).duplicate()
	for card in cards:
		if card.kind == "report" and card.source not in good:
			good.append(card.source)
	var marked_options = ids.duplicate()
	for card in cards:
		if card.kind == "report" and card.role == "rumormonger":
			marked_options = marked_options.filter(func(id): return id in card.data.pair)
	var target: String = case_data.conclusion.target
	marked_options.sort_custom(func(a, b):
		var prefer_target: bool = not want if case_data.conclusion.type in ["evil", "suspicious"] else want
		return a == target if prefer_target and (a == target or b == target) else (b == target if not prefer_target and (a == target or b == target) else a < b))
	var tested = 0
	var movement = Solver.movement_for(view, cards, answers, listener.knowledge)
	for marked in marked_options:
		var pool: Array = ids.filter(func(id): return id not in good and id != marked)
		pool.sort_custom(func(a, b):
			var x = _candidate_priority(a, target, cards, listener, want, case_data.conclusion.type)
			var y = _candidate_priority(b, target, cards, listener, want, case_data.conclusion.type)
			return x > y if not is_equal_approx(x, y) else a < b)
		for mask in range(1 << pool.size()):
			if Solver.popcount(mask) != view.evil_count:
				continue
			var evil = 0
			for i in range(pool.size()):
				if mask & (1 << i):
					evil |= 1 << ids.find(pool[i])
			var world = {"evil": evil, "marked": ids.find(marked)}
			for candidate in TimeModel.expand(view, world):
				if Solver.holds(view, candidate, case_data.conclusion) != want:
					continue
				if tested >= budget:
					return {"world": {}, "tested": tested, "exhausted": false}
				tested += 1
				if movement.okay and _matches(view, candidate, cards, listener.knowledge, positions, answers, case_data.conclusion.at, case_data.get("temporal_positions", [])):
					return {"world": candidate, "tested": tested, "exhausted": false}
	return {"world": {}, "tested": tested, "exhausted": true}

static func _candidate_priority(id: String, target: String, cards: Array, listener: Dictionary, want: bool, type: String) -> float:
	var score: float = listener.suspicion.get(id, 0.1)
	for card in cards:
		if card.kind == "report" and card.role == "dowser" and id in card.data.group:
			score += 2.0
	var evil_target: bool = want if type in ["evil", "suspicious"] else not want
	if id == target:
		score += 10.0 if evil_target else -10.0
	return score

static func _matches(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, positions: Dictionary, answers: Dictionary, epoch: String = "", temporal_positions: Array = []) -> bool:
	if Domain.live(view) and not Domain.claims_compatible(cards, knowledge):
		return false
	var ids: Array = view.people.map(func(p): return p.id)
	for id in knowledge.get("good", []):
		if not Solver.position_holds(view, world, id, "good", knowledge.get("good_epoch", epoch)):
			return false
	for id in positions:
		if not Solver.position_holds(view, world, id, positions[id], epoch):
			return false
	for assignment in temporal_positions:
		for id in assignment.positions:
			if not Solver.position_holds(view, world, id, assignment.positions[id], assignment.at):
				return false
	for card in cards:
		if not Solver._report_holds(view, world, card, answers.get(card.id, {})):
			return false
	return true

static func _swaps(view: Dictionary, cards: Array, case_data: Dictionary, listener: Dictionary, seed: Dictionary, budget: int) -> Dictionary:
	if Domain.live(view):
		return _find_live(view, cards, case_data, listener, budget, false, {}, {})
	var ids: Array = view.people.map(func(p): return p.id)
	var evil: Array = ids.filter(func(id): return seed.evil & (1 << ids.find(id)))
	var good: Array = ids.filter(func(id): return not seed.evil & (1 << ids.find(id)))
	evil.sort_custom(func(a, b): return a == case_data.conclusion.target if a == case_data.conclusion.target or b == case_data.conclusion.target else a < b)
	good.sort_custom(func(a, b): return a == ids[seed.marked] if a == ids[seed.marked] or b == ids[seed.marked] else a < b)
	var tested = 0
	var movement = Solver.movement_for(view, cards, {}, listener.knowledge)
	for outgoing in evil:
		for incoming in good:
			var candidate = {"evil": (seed.evil & ~(1 << ids.find(outgoing))) | (1 << ids.find(incoming)), "marked": seed.marked}
			if incoming == ids[seed.marked]:
				candidate.marked = ids.find(outgoing)
			if seed.has("converted"):
				candidate["converted"] = seed.converted
				if candidate.evil & (1 << candidate.converted):
					continue
			if Solver.holds(view, candidate, case_data.conclusion):
				continue
			if tested >= budget:
				return {"world": {}, "tested": tested, "exhausted": false}
			tested += 1
			if movement.okay and _matches(view, candidate, cards, listener.knowledge, {}, {}, case_data.conclusion.at):
				return {"world": candidate, "tested": tested, "exhausted": false}
	return {"world": {}, "tested": tested, "exhausted": false} # swaps are never an exhaustive proof

static func _find_live(view: Dictionary, cards: Array, value: Dictionary, listener: Dictionary, budget: int, want: bool, positions: Dictionary, answers: Dictionary) -> Dictionary:
	var tested = 0
	# A candidate's constraint check is independent of which person's alignment
	# is being queried. Reuse only checks the search actually elects to perform:
	# candidate order, tested counts, limits and exhaustion remain unchanged.
	var inputs = [view.people, view.evil_count, view.get("chronology", {}), view.world_options,
		listener.knowledge, cards, positions, answers, value.conclusion.at, value.get("temporal_positions", [])]
	var key = hash(inputs)
	if reuse_matches and (not matches.has(key) or matches[key].inputs != inputs):
		if matches.size() >= 32:
			matches.clear()
		matches[key] = {"inputs": inputs.duplicate(true), "results": {}}
	var known: Dictionary = matches[key].results if reuse_matches else {}
	# Enumerate the public legal domain, not worlds filtered by the referee. The
	# same hard test budget applies, and exhaustion alone can certify a conclusion.
	for candidate in Domain.worlds(view):
		if Solver.holds(view, candidate, value.conclusion) != want:
			continue
		if tested >= budget:
			return {"world": {}, "tested": tested, "exhausted": false}
		tested += 1
		var world_key = TimeModel.key(view, candidate)
		var fits: bool
		if reuse_matches and known.has(world_key):
			Profiler.count("candidate_cache_hit")
			fits = known[world_key]
		else:
			Profiler.count("candidate_cache_miss")
			fits = _matches(view, candidate, cards, listener.knowledge, positions, answers, value.conclusion.at, value.get("temporal_positions", []))
			if reuse_matches:
				known[world_key] = fits
		if fits:
			return {"world": candidate, "tested": tested, "exhausted": false}
	return {"world": {}, "tested": tested, "exhausted": true}

static func direct_checks(view: Dictionary, case_data: Dictionary, knowledge: Dictionary) -> Dictionary:
	var objections: Array = []
	var rejected: Array = []
	var fatal = false
	if case_data.conclusion.type == "evil" and TimeModel.known_good(view, knowledge, case_data.conclusion.target, case_data.conclusion.at):
		objections.append("I know I was good at that time; this accusation cannot be right about me.")
		fatal = true
	for id in knowledge.get("good", []):
		if case_data.positions.get(id, "") == "evil" and TimeModel.known_good(view, knowledge, id, case_data.conclusion.at):
			objections.append("Your explanation makes someone I know was good evil.")
			fatal = true
	var self_id: String = knowledge.get("self", "")
	for assignment in case_data.get("temporal_positions", []):
		for id in assignment.positions:
			if assignment.positions[id] == "evil" and TimeModel.known_good(view, knowledge, id, assignment.at):
				objections.append("Your dated explanation makes someone evil when I know they were good.")
				fatal = true
	for card in Solver.selected(view, case_data):
		if card.get("quoted", false):
			continue
		if card.kind == "report" and card.source == self_id:
			for id in knowledge.get("own_reports", []):
				var received = Solver.card_by_id(view, id)
				if received.get("role") == card.role and received.get("observed_at") == card.observed_at and received.get("data") != card.data:
					objections.append("%s is not the result I received. That does not tell us whether my actual gift result was healthy." % card.id)
					rejected.append(card.id)
		var night: String = str(card.get("night", -1))
		if self_id == "" or not knowledge.get("own_outings", {}).has(night):
			continue
		var was_out: bool = knowledge.own_outings[night]
		if card.kind == "report" and card.role == "lamplighter" and self_id in case_data.answers.get(card.id, {}).get("positive", []) and not was_out:
			objections.append("Your answer to %s says I was out, but I know I was home." % card.id)
			fatal = true
		var says_out: bool = (card.kind == "sighting" and card.subject == self_id) or (card.kind == "report" and card.role == "nightwatch" and self_id in card.data.seen)
		if says_out and not was_out:
			objections.append("%s conflicts with my firsthand knowledge that I was home on night %s; the report may be wrong." % [card.id, night])
			rejected.append(card.id)
		if card.kind == "alibi" and card.subject == self_id and was_out:
			objections.append("%s says I was home, but I know I went out on night %s." % [card.id, night])
			rejected.append(card.id)
	return {"fatal": fatal, "objections": objections, "rejected": rejected}
