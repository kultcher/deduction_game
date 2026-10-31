## Deterministic, bounded hypothesis testing. Never consumes the referee's worlds.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const Graph = preload("res://workshop/case_graph.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Profiler = preload("res://workshop/profiler.gd")
static var matches: Dictionary = {}
static var reuse_matches = true # developer A/B switch, not a reasoning-budget change
static var preparations: Dictionary = {}
static var reuse_preparations = true

static var unlimited_cards = false # developer experiment (autoplay --no-attention): every listener reads every card

static func profile(insight: float) -> Dictionary:
	var result: Dictionary
	if insight < Tuning.Workshop.INSIGHT_LOW_CUTOFF:
		result = Tuning.Workshop.PROFILE_LOW.duplicate()
	elif insight < Tuning.Workshop.INSIGHT_MEDIUM_CUTOFF:
		result = Tuning.Workshop.PROFILE_MEDIUM.duplicate()
	else:
		result = Tuning.Workshop.PROFILE_HIGH.duplicate()
	if unlimited_cards:
		result.cards = 1000 # links, support and rival budgets are unchanged
	return result

static func prepare(view: Dictionary, value: Dictionary, listener: Dictionary) -> Dictionary:
	var inputs = [view, value, listener.get("reasoning_mode", "full"), listener.get("insight", 0.5),
		listener.get("npc_trust", {}), listener.get("suspicion", {}), listener.get("knowledge", {})]
	var key = hash(inputs)
	if reuse_preparations and preparations.has(key) and preparations[key].inputs == inputs:
		return preparations[key].result.duplicate(true)
	var result = _prepare(view, value, listener)
	if reuse_preparations:
		if preparations.size() >= 256:
			preparations.erase(preparations.keys()[0])
		preparations[key] = {"inputs": inputs.duplicate(true), "result": result.duplicate(true)}
	return result

static func _prepare(view: Dictionary, value: Dictionary, listener: Dictionary) -> Dictionary:
	var full = Graph.compile_case(view, value)
	if full.conclusion.type == "conflict":
		var scope = Graph.roots(value, full.get("conflict_scope", []))
		full.cards = full.cards.filter(func(id): return id in scope)
	var limits = profile(listener.get("insight", 0.5))
	var bounded: bool = listener.get("reasoning_mode", "full") == "bounded"
	if bounded and listener.knowledge.has("attention_reports"):
		for id in listener.knowledge.get("own_reports", []):
			if id not in full.cards:
				full.cards.append(id)
	var cards = Solver.selected(view, full)
	var all_card_ids: Array = cards.map(func(c): return c.id)
	var personal: Array = listener.knowledge.get("attention_reports", listener.knowledge.get("own_reports", []))
	# The submission is in front of the listener. Insight limits connections and
	# rival search, not whether these observations are read. Everything else,
	# including private reports, competes for the remaining card budget.
	var focused: bool = listener.knowledge.has("presented_reports")
	var presented: Array = cards.filter(func(c): return c.id in listener.knowledge.get("presented_reports", [])).map(func(c): return c.id)
	var groups: Array = []
	var assigned: Array = []
	for line in value.get("lines", []):
		if line.relation == "supports":
			var roots = Graph.roots(value, line.cards).filter(func(id): return id in full.cards)
			if roots.is_empty():
				continue
			for r_id in roots.duplicate():
				for partner_id in _linked_counterparts(view, full, r_id, all_card_ids):
					if partner_id not in roots:
						roots.append(partner_id)
			assigned.append_array(roots)
			_add_group(view, groups, line.id, roots, full.conclusion.target, listener)
	var bg_ids: Array = listener.knowledge.get("own_reports", []) if focused and not value.get("lines", []).is_empty() else []
	var unassigned: Array = cards.filter(func(c): return c.id not in assigned and c.id not in bg_ids).map(func(c): return c.id)
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
	var ranked: Array = cards.filter(func(c): return (c.id in keep or c.id in bg_ids) and c.id not in presented and (focused or c.id not in personal))
	ranked.sort_custom(func(a, b):
		var x = _salience(a, full.conclusion.target, listener, Domain.live(view))
		var y = _salience(b, full.conclusion.target, listener, Domain.live(view))
		return x > y if not is_equal_approx(x, y) else Solver.semantic_key(a) < Solver.semantic_key(b))
	var remaining: int = maxi(0, limits.cards - presented.size()) if focused else limits.cards
	keep = presented + ranked.slice(0, remaining if bounded else ranked.size()).map(func(c): return c.id)
	if not focused:
		for id in personal:
			if cards.any(func(c): return c.id == id) and id not in keep:
				keep.append(id)
	# Never attend to a challenged report, disputed alibi, or explained outing while
	# dropping the linked card that disproves or explains it.
	var idx_k: int = 0
	while idx_k < keep.size():
		var c_id: String = keep[idx_k]
		for partner_id in _linked_counterparts(view, full, c_id, all_card_ids):
			if partner_id not in keep:
				keep.append(partner_id)
		idx_k += 1
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
		"private_reports": personal.duplicate(),
		"private_checks": direct_checks(view, full, listener.knowledge)}

## Cards explicitly linked to disprove, challenge, or explain `card_id` stay bound to it
## so bounded attention cannot read a challenged claim while dropping its counter-evidence.
static func _linked_counterparts(view: Dictionary, full: Dictionary, card_id: String, available_ids: Array) -> Array:
	var result: Array = []
	var challenges: Dictionary = full.get("reading_challenges", {})
	if challenges.has(card_id):
		for sup_id in challenges[card_id].get("supports", []):
			if sup_id in available_ids and sup_id not in result:
				result.append(sup_id)
	for challenged_id in challenges:
		if card_id in challenges[challenged_id].get("supports", []) and challenged_id in available_ids and challenged_id not in result:
			result.append(challenged_id)
	for dispute in full.get("disputes", []):
		var reports: Array = dispute.get("reports", [])
		if card_id in reports:
			for other_id in reports:
				if other_id != card_id and other_id in available_ids and other_id not in result:
					result.append(other_id)
	var citations: Dictionary = full.get("citations", {})
	if not citations.is_empty():
		var card: Dictionary = Solver.card_by_id(view, card_id)
		var night: int = int(card.get("night", -1))
		if night >= 0:
			var subjects: Array = []
			if card.get("kind", "") == "sighting":
				subjects = card.get("subjects", [card.get("subject", "")])
			elif card.get("kind", "") == "report" and card.get("role", "") == "nightwatch":
				subjects = card.get("data", {}).get("seen", [])
			for subj in subjects:
				var key = "%s:%d" % [subj, night]
				var claim_id: String = citations.get(key, "")
				if claim_id != "" and claim_id in available_ids and claim_id not in result:
					result.append(claim_id)
	return result

static func _add_group(view: Dictionary, groups: Array, id: String, roots: Array, target: String, listener: Dictionary) -> void:
	var facts: Array = roots.map(func(root): return Solver.semantic_key(Solver.card_by_id(view, root)))
	facts.sort()
	var key = JSON.stringify(facts)
	for group in groups:
		if group.key == key:
			group.ids.append(id)
			return
	groups.append({"ids": [id], "key": key, "cards": roots, "score": _group_score(view, roots, target, listener)})

static func _salience(card: Dictionary, target: String, listener: Dictionary, live: bool = false) -> float:
	var score = 1.0 + listener.npc_trust.get(card.source, 0.5) * 0.1
	if card.kind == "report" and (card.role in ["surveyor", "rumormonger", "dowser", "clerk", "archivist", "seer"] or (live and card.role in ["nightwatch", "gravedigger", "veteran", "lamplighter", "medium", "martyr", "sexton"])):
		score += 3.0
	if card.get("subject", "") == target or target in card.get("data", {}).get("pair", []) or target in card.get("data", {}).get("group", []) or target in card.get("data", {}).get("seen", []):
		score += 2.0
	return score

static func _group_score(view: Dictionary, ids: Array, target: String, listener: Dictionary) -> float:
	var score = 0.0
	for id in ids:
		var card = Solver.card_by_id(view, id)
		if not card.is_empty():
			score = maxf(score, _salience(card, target, listener, Domain.live(view)))
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
			if (sight.kind == "sighting" and home.subject in sight.get("subjects", [sight.subject])) or (sight.kind == "report" and sight.role == "nightwatch" and home.subject in sight.data.seen):
				return [home.id, sight.id]
	return []

static func _find(view: Dictionary, cards: Array, case_data: Dictionary, listener: Dictionary, budget: int, want: bool, positions: Dictionary, answers: Dictionary) -> Dictionary:
	if Domain.live(view):
		return _find_live(view, cards, case_data, listener, budget, want, positions, answers)
	var ids: Array = Solver.person_ids(view)
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

static func _live_person_priority(id: String, is_target: bool, cards: Array, listener: Dictionary, want: bool, type: String) -> float:
	var score: float = listener.suspicion.get(id, 0.1)
	for card in cards:
		if card.get("quoted", false):
			continue
		if card.kind == "report":
			var role: String = card.get("role", "")
			var d: Dictionary = card.get("data", {})
			if role in ["dowser", "hearthwitch"] and id in d.get("group", d.get("nbrs", [])):
				score += 2.0 if int(d.get("count", 0)) > 0 else -2.0
			elif role == "seer" and id in d.get("pair", []):
				score += 2.0 if d.get("yes", false) else -2.0
			elif role == "archivist" and id in d.get("pair", []):
				score += 2.0
			elif role == "clerk" and id in d.get("pair", []):
				score -= 1.5
			elif role == "nightwatch" and id in d.get("seen", []):
				score += 1.5
		elif card.kind == "sighting" and id in card.get("subjects", [card.get("subject", "")]):
			score += 1.5
	var evil_target: bool = want if type in ["evil", "suspicious", "demon", "minion"] else not want
	if is_target:
		score += 10.0 if evil_target else -10.0
	return score

static func _variant_priority(candidate: Dictionary, target_idx: int, want: bool, type: String, pos_marked_mask: int, pos_demon_mask: int, neg_demon_mask: int) -> float:
	var s: float = 0.0
	var m: int = int(candidate.marked)
	if m >= 0:
		if (pos_marked_mask & (1 << m)) != 0:
			s += 4.0
		if type == "marked" and ((m == target_idx) == want):
			s += 4.0
	else:
		s += 1.0
	var d: int = int(candidate.get("demon", -1))
	if d >= 0:
		if (pos_demon_mask & (1 << d)) != 0:
			s += 4.0
		if (neg_demon_mask & (1 << d)) != 0:
			s -= 4.0
		if type == "demon" and ((d == target_idx) == want):
			s += 4.0
		elif type == "minion" and ((d != target_idx) == want):
			s += 2.0
	return s

static func _matches(view: Dictionary, world: Dictionary, cards: Array, knowledge: Dictionary, positions: Dictionary, answers: Dictionary, epoch: String = "", temporal_positions: Array = [], claims_checked: bool = false) -> bool:
	if not claims_checked and Domain.live(view) and not Domain.claims_compatible(cards, knowledge):
		return false
	for id in knowledge.get("good", []):
		if not Solver.position_holds(view, world, id, "good", knowledge.get("good_epoch", epoch)):
			return false
	for fact in knowledge.get("timed_good", []):
		if TimeModel.evil_at(view, world, fact.person, fact.at):
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
	return Solver.Roles.fits(view, world, cards, knowledge, answers)

static func _swaps(view: Dictionary, cards: Array, case_data: Dictionary, listener: Dictionary, seed: Dictionary, budget: int) -> Dictionary:
	if Domain.live(view):
		return _find_live(view, cards, case_data, listener, budget, false, {}, {}, int(seed.get("evil", 0)))
	var ids: Array = Solver.person_ids(view)
	var evil: Array = ids.filter(func(id): return seed.evil & (1 << ids.find(id)))
	var good: Array = ids.filter(func(id): return not seed.evil & (1 << ids.find(id)))
	evil.sort_custom(func(a, b): return a == case_data.conclusion.target if a == case_data.conclusion.target or b == case_data.conclusion.target else a < b)
	# Test single-variable swaps (where Marked stays fixed) before coupled 2-variable
	# Evil <-> Marked swaps so Low Insight catches simple pair rivals while deeper
	# coupled role-swaps require Medium/High Insight.
	good.sort_custom(func(a, b): return b == ids[seed.marked] if a == ids[seed.marked] or b == ids[seed.marked] else a < b)
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

static func _find_live(view: Dictionary, cards: Array, value: Dictionary, listener: Dictionary, budget: int, want: bool, positions: Dictionary, answers: Dictionary, seed_evil: int = 0) -> Dictionary:
	var tested = 0
	# A candidate's constraint check is independent of which person's alignment
	# is being queried. Reuse only checks the search actually elects to perform:
	# candidate order, tested counts, limits and exhaustion remain unchanged.
	var inputs = [view.people, view.evil_count, view.get("chronology", {}), view.get("timeline", {}), view.get("live_activity", false), view.world_options,
		listener.knowledge, cards, positions, answers, value.conclusion.at, value.get("temporal_positions", [])]
	var key = hash(inputs)
	if reuse_matches and (not matches.has(key) or matches[key].inputs != inputs):
		if matches.size() >= 32:
			matches.clear()
		var n_worlds = Solver.universe(view).size()
		var table = PackedByteArray()
		table.resize(n_worlds)
		table.fill(255) # 255 = unknown, 0 = false, 1 = true
		matches[key] = {"inputs": inputs.duplicate(true), "table": table, "queries": {}}
	# Repeating the exact bounded query reuses its original result, including
	# tested counts and exhaustion. No larger budget or other target inherits it.
	var query_key = JSON.stringify([value.conclusion, budget, want, seed_evil, listener.get("suspicion", {})])
	if reuse_matches and matches[key].queries.has(query_key):
		Profiler.count("candidate_query_cache_hit")
		return matches[key].queries[query_key].duplicate(true)
	var table: PackedByteArray = matches[key].table if reuse_matches else PackedByteArray()
	var use_table: bool = reuse_matches and not table.is_empty()
	var hits = 0
	var misses = 0
	# Role ownership is a property of the selected reports and private knowledge,
	# independent of the candidate's alignment/modifier assignment.
	var claims_ok: bool = Domain.claims_compatible(cards, listener.knowledge)
	if not claims_ok:
		return _finish_live(key, query_key, {}, 0, seed_evil == 0, 0, 0)

	var candidates: Array = _ordered_live_candidates(view, cards, value, listener, want, positions, answers, seed_evil)
	for candidate in candidates:
		if tested >= budget:
			return _finish_live(key, query_key, {}, tested, false, hits, misses)
		tested += 1
		var c_idx: int = int(candidate.get("__i", -1))
		var fits: bool
		if use_table and c_idx >= 0 and table[c_idx] != 255:
			hits += 1
			fits = table[c_idx] == 1
		else:
			misses += 1
			fits = claims_ok and _matches(view, candidate, cards, listener.knowledge, positions, answers, value.conclusion.at, value.get("temporal_positions", []), true)
			if use_table and c_idx >= 0:
				table[c_idx] = 1 if fits else 0
		if fits:
			return _finish_live(key, query_key, candidate, tested, false, hits, misses)
	return _finish_live(key, query_key, {}, tested, seed_evil == 0, hits, misses)

static func _ordered_live_candidates(view: Dictionary, cards: Array, value: Dictionary, listener: Dictionary, want: bool, positions: Dictionary, answers: Dictionary, seed_evil: int) -> Array:
	var universe: Array = Solver.universe(view)
	if universe.is_empty():
		return []
	var ids: Array = Solver.person_ids(view)
	var n_people: int = ids.size()
	var target_idx: int = Solver.person_index(view, value.conclusion.target)
	var type: String = value.conclusion.type
	var has_curse: bool = view.get("chronology", {}).has("curse")
	var target_bit: int = (1 << target_idx) if target_idx >= 0 else 0
	var plain: bool = not has_curse and value.get("temporal_positions", []).is_empty()
	var must_be_good: int = 0
	var must_be_evil: int = 0
	var no_delusion_mask: int = 0
	var marked_req: int = -2
	var unmarked_mask: int = 0
	var demon_req: int = -2
	var not_demon_mask: int = 0
	var req_modifier: String = ""
	var rumor_checks: Array = []
	var pos_marked_mask: int = 0
	var pos_demon_mask: int = 0
	var neg_demon_mask: int = 0
	if plain:
		for id in listener.knowledge.get("good", []):
			var idx: int = Solver.person_index(view, id)
			if idx >= 0:
				must_be_good |= (1 << idx)
		for id in positions:
			var idx: int = Solver.person_index(view, id)
			var pos_val: String = positions[id]
			if idx < 0:
				if pos_val in ["evil", "marked", "unmarked", "demon", "minion"]:
					return []
				continue
			match pos_val:
				"good":
					must_be_good |= (1 << idx)
				"evil":
					must_be_evil |= (1 << idx)
				"marked":
					if marked_req >= 0 and marked_req != idx:
						return []
					marked_req = idx
				"unmarked":
					unmarked_mask |= (1 << idx)
				"demon":
					if demon_req >= 0 and demon_req != idx:
						return []
					demon_req = idx
					must_be_evil |= (1 << idx)
				"minion":
					must_be_evil |= (1 << idx)
					not_demon_mask |= (1 << idx)
		for card in cards:
			if card.get("quoted", false):
				continue
			if card.kind == "report":
				var src_idx: int = Solver.person_index(view, card.source)
				if src_idx >= 0:
					must_be_good |= (1 << src_idx)
					if not card.get("testimony_only", false):
						no_delusion_mask |= (1 << src_idx)
				var role: String = card.get("role", "")
				var d: Dictionary = card.get("data", {})
				if role in ["dowser", "hearthwitch"] and int(d.get("count", 0)) > 0:
					for pid in d.get("group", d.get("nbrs", [])):
						var pidx: int = Solver.person_index(view, pid)
						if pidx >= 0:
							pos_marked_mask |= (1 << pidx)
				elif role == "seer":
					for pid in d.get("pair", []):
						var pidx: int = Solver.person_index(view, pid)
						if pidx >= 0:
							if d.get("yes", false):
								pos_demon_mask |= (1 << pidx)
								pos_marked_mask |= (1 << pidx)
							else:
								neg_demon_mask |= (1 << pidx)
				elif role == "archivist":
					for pid in d.get("pair", []):
						var pidx: int = Solver.person_index(view, pid)
						if pidx >= 0:
							neg_demon_mask |= (1 << pidx)
				elif role == "nightwatch":
					for pid in d.get("seen", []):
						var pidx: int = Solver.person_index(view, pid)
						if pidx >= 0:
							pos_demon_mask |= (1 << pidx)
				elif role == "rumormonger" and not card.get("testimony_only", false):
					var sec: String = d.get("secret", "marked")
					if req_modifier != "" and req_modifier != sec:
						return []
					req_modifier = sec
					var pair_mask: int = 0
					for pid in d.get("pair", []):
						var pidx: int = Solver.person_index(view, pid)
						if pidx >= 0:
							pair_mask |= (1 << pidx)
							pos_marked_mask |= (1 << pidx)
					var ans_mask: int = 0
					for pid in answers.get(card.id, {}).get("positive", []):
						var pidx: int = Solver.person_index(view, pid)
						if pidx >= 0:
							ans_mask |= (1 << pidx)
					rumor_checks.append({"source": src_idx, "pair": pair_mask, "ans": ans_mask})
			elif card.kind == "sighting":
				for pid in card.get("subjects", [card.get("subject", "")]):
					var pidx: int = Solver.person_index(view, pid)
					if pidx >= 0:
						pos_demon_mask |= (1 << pidx)
		if (must_be_good & must_be_evil) != 0:
			return []
		if marked_req >= 0 and ((must_be_evil & (1 << marked_req)) != 0 or (unmarked_mask & (1 << marked_req)) != 0):
			return []
		if demon_req >= 0 and ((must_be_good & (1 << demon_req)) != 0 or (not_demon_mask & (1 << demon_req)) != 0):
			return []
	var needs_demon: bool = type in ["demon", "notdemon", "minion", "misled", "unreliable"] or demon_req >= 0 or not_demon_mask != 0 or view.get("live_activity", false)
	var needs_marked: bool = type in ["marked", "misled", "unreliable"] or marked_req >= 0 or unmarked_mask != 0
	var needs_holders: bool = type == "secret_mod" or (req_modifier != "" and req_modifier != "marked")
	for card in cards:
		var role: String = card.get("role", "")
		if role in ["seer", "archivist", "gravedigger"] or card.get("kind", "") == "totem" or card.get("testimony_only", false):
			needs_demon = true
		if role in ["seer", "dowser", "surveyor", "rumormonger", "martyr", "gravedigger"] or card.get("testimony_only", false):
			needs_marked = true
		if role == "rumormonger" and card.get("data", {}).get("secret", "marked") != "marked":
			needs_holders = true
	var mediums: int = Solver.Roles.relay_mediums(ids, cards)
	var walkers: int = Solver.Roles.sleepwalk_claimants(ids, cards)
	var bits: Dictionary = Solver.world_bits(view)
	var evil_arr: PackedInt64Array = bits.evil
	var deluded_arr: PackedInt64Array = bits.deluded
	var fast_holds: bool = not has_curse and target_idx >= 0 and type in ["evil", "suspicious", "good"]
	var want_evil_bit: bool = (want if type != "good" else not want) if fast_holds else false
	var seen_eq: Dictionary = {}
	var by_team: Dictionary = {}
	var team_order: Array = []
	var n1: int = n_people + 2
	var holder_mult: int = (1 << (n_people + 3)) if (needs_holders or mediums != 0 or walkers != 0) else 1
	for i in range(universe.size()):
		var evil_bits: int = evil_arr[i]
		if fast_holds:
			if ((evil_bits & target_bit) != 0) != want_evil_bit:
				continue
		if plain:
			if (evil_bits & must_be_good) != 0 or (evil_bits & must_be_evil) != must_be_evil:
				continue
			if no_delusion_mask != 0 and (deluded_arr[i] & no_delusion_mask) != 0:
				continue
		var candidate: Dictionary = universe[i]
		if not fast_holds:
			var holds_val: bool
			if not has_curse and target_idx >= 0 and type == "marked":
				holds_val = candidate.marked == target_idx
			else:
				holds_val = Solver.holds(view, candidate, value.conclusion)
			if holds_val != want:
				continue
		var mod_str: String = candidate.get("modifier", "marked")
		var holders_bits: int = int(candidate.get("holders", (1 << candidate.marked) if candidate.marked >= 0 else 0))
		if plain:
			if marked_req >= 0 and candidate.marked != marked_req:
				continue
			if unmarked_mask != 0 and candidate.marked >= 0 and (unmarked_mask & (1 << candidate.marked)) != 0:
				continue
			var d_idx: int = int(candidate.get("demon", -1))
			if demon_req >= 0 and d_idx != demon_req:
				continue
			if not_demon_mask != 0 and d_idx >= 0 and (not_demon_mask & (1 << d_idx)) != 0:
				continue
			if req_modifier != "" and mod_str != req_modifier:
				continue
			var rumor_ok: bool = true
			for rm in rumor_checks:
				if (rm.source >= 0 and (holders_bits & ~(1 << rm.source)) == 0) or (holders_bits & rm.pair) == 0 or (rm.ans != 0 and (holders_bits & rm.ans) != rm.ans):
					rumor_ok = false
					break
			if not rumor_ok:
				continue
		var conv_part: int = int(candidate.get("converted", -1)) if has_curse else -1
		var demon_part: int = int(candidate.get("demon", -1)) if needs_demon else -1
		var marked_part: int = int(candidate.marked) if needs_marked else -1
		var holder_part: int = 0
		if needs_holders:
			holder_part = (Solver.C.SECRET_MOD_LIST.find(mod_str) + 1) * (1 << n_people) + holders_bits
		elif mediums != 0 and mod_str == "delusional" and (holders_bits & mediums) != 0:
			holder_part = (1 << n_people) + (holders_bits & mediums)
		elif walkers != 0 and mod_str == "sleepwalker" and (holders_bits & walkers) != 0:
			holder_part = (2 << n_people) + (holders_bits & walkers)
		var eq_key: int = (((evil_bits * n1 + conv_part + 1) * n1 + demon_part + 1) * n1 + marked_part + 1) * holder_mult + holder_part
		if seen_eq.has(eq_key):
			continue
		seen_eq[eq_key] = true
		var team_key: int = evil_bits * n1 + conv_part + 1
		if not by_team.has(team_key):
			by_team[team_key] = []
			team_order.append({"key": team_key, "evil": evil_bits})
		by_team[team_key].append(candidate)
	if team_order.is_empty():
		return []
	var person_scores = PackedFloat64Array()
	person_scores.resize(n_people)
	for i in range(n_people):
		person_scores[i] = _live_person_priority(ids[i], target_idx == i, cards, listener, want, type)
	for entry in team_order:
		var t_evil: int = entry.evil
		var s: float = 0.0
		for i in range(n_people):
			if t_evil & (1 << i):
				s += person_scores[i]
		if seed_evil != 0 and Solver.popcount(t_evil ^ seed_evil) == 2:
			s += 100.0
		entry["score"] = s
		var bucket: Array = by_team[entry.key]
		if bucket.size() > 1 and (pos_marked_mask != 0 or pos_demon_mask != 0 or neg_demon_mask != 0 or needs_marked or needs_demon):
			bucket.sort_custom(func(a, b):
				var va = _variant_priority(a, target_idx, want, type, pos_marked_mask, pos_demon_mask, neg_demon_mask)
				var vb = _variant_priority(b, target_idx, want, type, pos_marked_mask, pos_demon_mask, neg_demon_mask)
				return va > vb if not is_equal_approx(va, vb) else int(a.get("__i", 0)) < int(b.get("__i", 0)))
	team_order.sort_custom(func(a, b):
		return a.score > b.score if not is_equal_approx(a.score, b.score) else a.key < b.key)
	var ordered: Array = []
	var round_idx: int = 0
	var active_teams: int = team_order.size()
	while active_teams > 0:
		active_teams = 0
		for entry in team_order:
			var bucket: Array = by_team[entry.key]
			if round_idx < bucket.size():
				ordered.append(bucket[round_idx])
				if round_idx + 1 < bucket.size():
					active_teams += 1
		round_idx += 1
	return ordered

static func _finish_live(key: int, query_key: String, world: Dictionary, tested: int, exhausted: bool, hits: int, misses: int) -> Dictionary:
	# Instrumentation stays outside the candidate loop, including when disabled.
	Profiler.count("candidate_cache_hit", hits)
	Profiler.count("candidate_cache_miss", misses)
	var result = {"world": world, "tested": tested, "exhausted": exhausted}
	if reuse_matches:
		if matches[key].queries.size() >= 128:
			matches[key].queries.clear()
		matches[key].queries[query_key] = result.duplicate(true)
	return result

static func direct_checks(view: Dictionary, case_data: Dictionary, knowledge: Dictionary) -> Dictionary:
	var objections: Array = []
	var rejected: Array = []
	var fatal = false
	if case_data.conclusion.type in ["evil", "demon", "minion"] and TimeModel.known_good(view, knowledge, case_data.conclusion.target, case_data.conclusion.at):
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
			for id in knowledge.get("attention_reports", knowledge.get("own_reports", [])):
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
		var says_out: bool = (card.kind == "sighting" and self_id in card.get("subjects", [card.subject])) or (card.kind == "report" and card.role == "nightwatch" and self_id in card.data.seen)
		if says_out and not was_out:
			objections.append("%s conflicts with my firsthand knowledge that I was home on night %s; the report may be wrong." % [card.id, night])
			rejected.append(card.id)
		if card.kind == "alibi" and card.subject == self_id and was_out:
			objections.append("%s says I was home, but I know I went out on night %s." % [card.id, night])
			rejected.append(card.id)
	return {"fatal": fatal, "objections": objections, "rejected": rejected}
