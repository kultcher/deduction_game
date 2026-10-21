## Small exhaustive constraint solver. Receives public evidence only, never hidden truth.
## Counts measure compatible assignments, NOT posterior probabilities.
extends RefCounted

const Graph = preload("res://workshop/case_graph.gd")
static var universes: Dictionary = {}
static var report_matches: Dictionary = {}
static var movement_cache: Dictionary = {}

static func empty_case() -> Dictionary:
	return {"id": "case-1", "version": 1, "cards": [], "positions": {}, "answers": {}, "reasons": {},
		"citations": {}, "conflict_scope": [], "challenges": {}, "derived": [], "lines": [],
		"conclusion": {"type": "evil", "target": "constance", "at": "opening through day 3"}}

static func card_by_id(view: Dictionary, id: String) -> Dictionary:
	for card in view.cards:
		if card.id == id:
			return card
	return {}

static func selected(view: Dictionary, case_data: Dictionary) -> Array:
	# Semantic identity is independent of wrapper id and presentation venue.
	var cards: Array = []
	var keys: Array = []
	for id in case_data.cards:
		var card = card_by_id(view, id)
		if not card.is_empty() and semantic_key(card) not in keys:
			cards.append(card)
			keys.append(semantic_key(card))
	return cards

static func semantic_key(card: Dictionary) -> String:
	if card.has("fact_id"):
		return card.fact_id
	var data: Dictionary = card.get("data", {}).duplicate(true)
	for key in ["pair", "group", "seen"]:
		if data.has(key):
			data[key].sort()
	return JSON.stringify([card.get("kind"), card.get("source"), card.get("role"), card.get("observed_at"), data, card.get("subject"), card.get("block")])

static func analyze(view: Dictionary, case_data: Dictionary, knowledge: Dictionary = {}) -> Dictionary:
	case_data = Graph.compile_case(view, case_data)
	var cards = selected(view, case_data)
	if case_data.conclusion.type == "conflict":
		cards = cards.filter(func(c): return c.id in Graph.roots(case_data, case_data.conflict_scope))
	var base = solve(view, cards, {}, {}, knowledge)
	var proposed = solve(view, cards, case_data.positions, case_data.answers, knowledge)
	var errors = validate_answers(view, case_data) + case_data.get("graph_errors", [])
	var conclusion: Dictionary = case_data.conclusion
	if conclusion.type in ["evil", "good", "marked"] and not proposed.worlds.is_empty() and not proposed.worlds.any(func(w): return holds(view, w, conclusion)):
		errors.append("The conclusion contradicts every world allowed by these premises and choices.")
	var n = 0
	var alternative = {}
	for world in base.worlds:
		if holds(view, world, conclusion):
			n += 1
		elif alternative.is_empty():
			alternative = describe_world(view, world)
	var status = "incomplete"
	if not errors.is_empty() or proposed.worlds.is_empty() or not proposed.movement_ok:
		status = "conflicting"
	elif proposed.worlds.size() == 1:
		status = "coherent"
	var entailment = "possible"
	if base.worlds.is_empty() or not base.movement_ok:
		entailment = "conflicting"
	elif conclusion.type == "conflict":
		entailment = "unsupported"
	elif n == base.worlds.size():
		entailment = "forced"
	elif n == 0:
		entailment = "unsupported"
	if conclusion.type == "conflict" and (base.worlds.is_empty() or not base.movement_ok):
		entailment = "forced"
	var conflicts: Array = []
	if base.worlds.is_empty() or not base.movement_ok:
		conflicts = minimal_conflicts(view, cards, knowledge)
	return {"status": status, "entailment": entailment, "compatible": base.worlds.size(), "supporting": n,
		"proposed": proposed.worlds.size(), "alternative": alternative, "errors": errors,
		"movement": proposed.movement, "movement_ok": proposed.movement_ok,
		"assumptions": assumption_labels(view, cards), "unresolved": unresolved(view, proposed.worlds), "conflicts": conflicts}

static func minimal_conflicts(view: Dictionary, cards: Array, knowledge: Dictionary = {}) -> Array:
	# Shrink one conflict, then explore excluding each member to discover other cores.
	# This avoids enumerating every unrelated subset for a simple alibi conflict.
	cards = cards.filter(func(c): return c.kind in ["report", "sighting", "alibi"])
	var result: Array = []
	_find_conflicts(view, cards, knowledge, result, {})
	return result

static func _find_conflicts(view: Dictionary, cards: Array, knowledge: Dictionary, result: Array, visited: Dictionary) -> void:
	var ids: Array = cards.map(func(c): return c.id)
	var key = str(ids)
	if visited.has(key):
		return
	visited[key] = true
	var solved = solve(view, cards, {}, {}, knowledge)
	if not solved.worlds.is_empty() and solved.movement_ok:
		return
	var core = cards.duplicate()
	for card in cards:
		var trial = core.filter(func(c): return c.id != card.id)
		var tested = solve(view, trial, {}, {}, knowledge)
		if tested.worlds.is_empty() or not tested.movement_ok:
			core = trial
	var conflict: Array = core.map(func(c): return c.id)
	if not result.has(conflict):
		result.append(conflict)
	for card in core:
		_find_conflicts(view, cards.filter(func(c): return c.id != card.id), knowledge, result, visited)

static func solve(view: Dictionary, cards: Array, positions: Dictionary = {}, answers: Dictionary = {}, knowledge: Dictionary = {}) -> Dictionary:
	var ids: Array = view.people.map(func(p): return p.id)
	var universe_key = str([ids.size(), view.evil_count])
	if not universes.has(universe_key):
		var all_worlds: Array = []
		for evil in range(1 << ids.size()):
			if popcount(evil) == view.evil_count:
				for marked in range(ids.size()):
					if not evil & (1 << marked):
						all_worlds.append({"evil": evil, "marked": marked})
		universes[universe_key] = all_worlds
	var worlds: Array = universes[universe_key].duplicate()
	for id in knowledge.get("good", []):
		worlds = worlds.filter(func(w): return _position_holds(ids, w, id, "good"))
	for id in positions:
		worlds = worlds.filter(func(w): return _position_holds(ids, w, id, positions[id]))
	for card in cards:
		if card.kind != "report":
			continue
		var positive: Array = answers.get(card.id, {}).get("positive", []).duplicate()
		positive.sort()
		var key = JSON.stringify([view.people, view.evil_count, card.source, card.role, card.data, positive])
		if not report_matches.has(key):
			if report_matches.size() > 512:
				report_matches.clear()
			var matches = {}
			for world in universes[universe_key]:
				if _report_holds(view, world, card, {"positive": positive}):
					matches[world.evil * ids.size() + world.marked] = true
			report_matches[key] = matches
		var accepted: Dictionary = report_matches[key]
		worlds = worlds.filter(func(w): return accepted.has(w.evil * ids.size() + w.marked))
	var movement_cards: Array = cards.filter(func(c): return c.kind in ["sighting", "alibi"] or (c.kind == "report" and c.get("role", "") in ["nightwatch", "lamplighter"]))
	var movement_key = JSON.stringify([ids, movement_cards, answers])
	if not movement_cache.has(movement_key):
		if movement_cache.size() > 256:
			movement_cache.clear()
		movement_cache[movement_key] = _movement(view, movement_cards, answers)
	var movement: Dictionary = movement_cache[movement_key]
	return {"worlds": worlds, "movement": movement.nights, "movement_ok": movement.okay}

static func popcount(bits: int) -> int:
	var count = 0
	while bits:
		bits &= bits - 1
		count += 1
	return count

static func _position_holds(ids: Array, world: Dictionary, id: String, position: String) -> bool:
	if id not in ids:
		return false
	var index = ids.find(id)
	var evil: bool = (world.evil & (1 << index)) != 0
	match position:
		"evil": return evil
		"good": return not evil
		"marked": return world.marked == index
	return true

static func _report_holds(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	if card.kind != "report":
		return true
	var ids: Array = view.people.map(func(p): return p.id)
	if world.evil & (1 << ids.find(card.source)):
		return false # An accepted healthy gift assumes a good source at the reading's time.
	var d: Dictionary = card.data
	if card.role == "rumormonger":
		var marked: String = ids[world.marked]
		return marked in d.pair and (answer.get("positive", []).is_empty() or marked in answer.positive)
	if card.role not in ["surveyor", "dowser"]:
		return true
	# A Marked person may register either way, independently for each reading.
	for mark_reads in [false, true]:
		var positive: Array = []
		for i in range(ids.size()):
			if world.evil & (1 << i) or (i == world.marked and mark_reads):
				positive.append(ids[i])
		var count = 0
		if card.role == "surveyor":
			var blocks: Array = []
			for p in view.people:
				if p.id in positive and p.home not in blocks:
					blocks.append(p.home)
			count = blocks.size()
		else:
			count = d.group.filter(func(id): return id in positive).size()
		if count == d.count and answer.get("positive", []).all(func(id): return id in positive):
			return true
	return false

static func _movement(view: Dictionary, cards: Array, answers: Dictionary) -> Dictionary:
	var ids: Array = view.people.map(func(p): return p.id)
	var nights = {}
	var okay = true
	for night in [1, 2]:
		var relevant: Array = cards.filter(func(c): return c.get("night", -1) == night and (c.kind in ["sighting", "alibi"] or c.get("role", "") in ["nightwatch", "lamplighter"]))
		if relevant.is_empty():
			continue
		var possibilities: Array = []
		for mask in range(1 << ids.size()):
			var valid = true
			for card in relevant:
				var required: Array = []
				if card.kind == "sighting":
					required = [card.subject]
				elif card.kind == "alibi":
					if mask & (1 << ids.find(card.subject)):
						valid = false
				elif card.role == "nightwatch":
					required = card.data.seen + [card.source]
				elif card.role == "lamplighter":
					required = [card.source] + answers.get(card.id, {}).get("positive", [])
					if popcount(mask & ~(1 << ids.find(card.source))) != card.data.count:
						valid = false
				for id in required:
					if not (mask & (1 << ids.find(id))):
						valid = false
				if not valid:
					break
			if valid:
				possibilities.append(mask)
		var forced: Array = []
		for i in range(ids.size()):
			if not possibilities.is_empty() and possibilities.all(func(mask): return (mask & (1 << i)) != 0):
				forced.append(ids[i])
		nights[str(night)] = {"compatible": possibilities.size(), "forced_out": forced}
		okay = okay and not possibilities.is_empty()
	return {"okay": okay, "nights": nights}

static func holds(view: Dictionary, world: Dictionary, conclusion: Dictionary) -> bool:
	var ids: Array = view.people.map(func(p): return p.id)
	var index = ids.find(conclusion.target)
	if index < 0:
		return false
	match conclusion.type:
		"evil", "suspicious": return (world.evil & (1 << index)) != 0
		"good": return (world.evil & (1 << index)) == 0
		"marked": return world.marked == index
	return false

static func describe_world(view: Dictionary, world: Dictionary) -> Dictionary:
	var ids: Array = view.people.map(func(p): return p.id)
	return {"evil": ids.filter(func(id): return (world.evil & (1 << ids.find(id))) != 0), "marked": ids[world.marked]}

static func unresolved(view: Dictionary, worlds: Array) -> Array:
	var result: Array = []
	if worlds.is_empty():
		return result
	for p in view.people:
		var i: int = view.people.find(p)
		var evil_count = worlds.filter(func(w): return (w.evil & (1 << i)) != 0).size()
		if evil_count > 0 and evil_count < worlds.size():
			result.append(p.id)
	return result

static func assumption_labels(view: Dictionary, cards: Array) -> Array:
	var result: Array = []
	for card in cards:
		if card.kind == "report":
			result.append("%s: %s held %s, was good and healthy at %s %s, and reported honestly." % [card.id, person_name(view, card.source), card.role, card.observed_at.phase, card.observed_at.day])
		elif card.kind == "alibi":
			result.append("%s: accept the home alibi as accurate." % card.id)
	return result

static func validate_answers(view: Dictionary, case_data: Dictionary) -> Array:
	var errors: Array = []
	for id in case_data.answers:
		if id not in case_data.cards:
			continue
		var card = card_by_id(view, id)
		var positive: Array = case_data.answers[id].get("positive", [])
		var maximum: int = 1 if card.get("role", "") == "rumormonger" else card.get("data", {}).get("count", 10)
		if positive.size() > maximum:
			errors.append("%s: there are more answers than positive slots." % id)
		var unique: Array = []
		for person in positive:
			if person not in view.people.map(func(p): return p.id):
				errors.append("%s: choose a known person." % id)
				continue
			if person in unique:
				errors.append("%s: the same person fills two slots." % id)
			unique.append(person)
		if card.get("role", "") == "dowser" and not positive.all(func(p): return p in card.data.group):
			errors.append("%s: choose people in this reading's group." % id)
		if card.get("role", "") == "lamplighter" and card.source in positive:
			errors.append("%s: the count excludes the Lamplighter." % id)
		if card.get("role", "") == "surveyor":
			var blocks: Array = []
			for person in positive:
				var matches: Array = view.people.filter(func(p): return p.id == person)
				if matches.is_empty():
					continue
				var home: String = matches[0].home
				if home in blocks:
					errors.append("%s: each slot needs a different block." % id)
				blocks.append(home)
		if card.get("role", "") == "rumormonger" and not positive.all(func(p): return p in card.data.pair):
			errors.append("%s: choose someone in the named pair." % id)
	return errors

static func person_name(view: Dictionary, id: String) -> String:
	for p in view.people:
		if p.id == id:
			return p.name
	return id
