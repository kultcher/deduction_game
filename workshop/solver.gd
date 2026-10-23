## Small exhaustive constraint solver. Receives public evidence only, never hidden truth.
## Counts measure compatible assignments, NOT posterior probabilities.
extends RefCounted
const Domain = preload("res://workshop/world_domain.gd")
const Roles = preload("res://workshop/role_constraints.gd")

const Graph = preload("res://workshop/case_graph.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Profiler = preload("res://workshop/profiler.gd")
static var universes: Dictionary = {}
static var report_matches: Dictionary = {}
static var movement_cache: Dictionary = {}
static var _cached_people = null
static var _cached_ids: Array = []
static var _cached_idx: Dictionary = {}
static var _cached_block_masks: Dictionary = {}

static func _ensure_people(view: Dictionary) -> void:
	if view.people == _cached_people:
		return
	_cached_people = view.people.duplicate(true)
	_cached_ids = []
	_cached_idx = {}
	_cached_block_masks = {}
	for i in range(view.people.size()):
		var p: Dictionary = view.people[i]
		_cached_idx[p.id] = i
		_cached_ids.append(p.id)
		_cached_block_masks[p.home] = _cached_block_masks.get(p.home, 0) | (1 << i)

static func person_index(view: Dictionary, id: String) -> int:
	_ensure_people(view)
	return _cached_idx.get(id, -1)

static func person_ids(view: Dictionary) -> Array:
	_ensure_people(view)
	return _cached_ids

static func empty_case() -> Dictionary:
	return {"id": "case-1", "version": 1, "cards": [], "positions": {}, "answers": {}, "reasons": {},
		"citations": {}, "conflict_scope": [], "challenges": {}, "reading_challenges": {}, "derived": [], "lines": [], "disputes": [], "faults": {}, "temporal_positions": [],
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
			if id in case_data.get("quoted_cards", []):
				card = card.duplicate(true)
				card["quoted"] = true
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
		cards = cards.filter(func(c): return c.id in Graph.roots(case_data, case_data.conflict_scope) or c.id in knowledge.get("own_reports", []))
	var base = solve(view, cards, {}, {}, knowledge)
	var proposed_cards = TimeModel.hypothetical_cards(view, case_data, cards)
	var positions: Dictionary = case_data.positions.duplicate(true)
	var challenge_errors: Array = []
	for id in case_data.get("reading_challenges", {}):
		var mode: String = case_data.reading_challenges[id].get("mode", "")
		if mode in ["misled", "lying"]:
			var source: String = card_by_id(view, id).get("source", "")
			var assumed: String = "good" if mode == "misled" else "evil"
			var allowed: Array = ["good", "marked"] if mode == "misled" else ["evil", "demon", "minion"]
			if positions.get(source, assumed) not in allowed:
				challenge_errors.append("The selected reader alignment conflicts with the %s explanation." % mode.capitalize())
			else:
				positions[source] = positions.get(source, assumed)
	var proposed = solve(view, proposed_cards, positions, case_data.answers, knowledge, case_data.conclusion.at, case_data.get("temporal_positions", []))
	var errors = validate_answers(view, case_data) + case_data.get("graph_errors", [])
	errors.append_array(challenge_errors)
	var conclusion: Dictionary = case_data.conclusion
	if conclusion.type in ["evil", "good", "marked"] and not proposed.worlds.is_empty() and not proposed.worlds.any(func(w): return holds(view, w, conclusion)):
		errors.append("The conclusion contradicts every world allowed by these premises and choices.")
	var n = 0
	var alternative = {}
	for world in base.worlds:
		if holds(view, world, conclusion):
			n += 1
		elif alternative.is_empty():
			alternative = describe_world(view, world, conclusion.at)
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
	return {"status": status, "entailment": entailment, "compatible": base.worlds.size(), "supporting": n, "hypothetically_released": cards.filter(func(c): return c not in proposed_cards).map(func(c): return c.id),
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

static func solve(view: Dictionary, cards: Array, positions: Dictionary = {}, answers: Dictionary = {}, knowledge: Dictionary = {}, epoch: String = "", temporal_positions: Array = []) -> Dictionary:
	var span = Profiler.open("constraint_solve")
	var result = _solve(view, cards, positions, answers, knowledge, epoch, temporal_positions)
	Profiler.close(span)
	return result

## Every legal world for this view (cached). Shared by the solve and by CaseEval.
static func universe(view: Dictionary) -> Array:
	return universes[_universe_key(view)] if universes.has(_universe_key(view)) else _build_universe(view)

static func _universe_key(view: Dictionary) -> String:
	return str([person_ids(view), view.evil_count, view.get("chronology", {}), view.get("world_options", {})])

static func _build_universe(view: Dictionary) -> Array:
	var ids: Array = person_ids(view)
	var key = _universe_key(view)
	if universes.size() >= 16:
		universes.clear()
	var all_worlds: Array = []
	if Domain.live(view):
		all_worlds = Domain.worlds(view)
	else:
		for evil in range(1 << ids.size()):
			if popcount(evil) == view.evil_count:
				for marked in range(ids.size()):
					if not evil & (1 << marked):
						all_worlds.append_array(TimeModel.expand(view, {"evil": evil, "marked": marked}))
	universes[key] = all_worlds
	return all_worlds

## For one report (or curse event) card: a byte per universe world, 1 where the card's
## content holds as a healthy reading from a good source (cached by exact inputs).
static func report_table(view: Dictionary, card: Dictionary, positive: Array = []) -> PackedByteArray:
	var universe_key = _universe_key(view)
	var universe: Array = universe(view)
	positive = positive.duplicate()
	positive.sort()
	# Homes affect Surveyor blocks; kind/event distinguish public process cards.
	# Hashes accelerate lookup, but exact snapshots guard collisions and edits.
	var inputs = [universe_key, view.people, view.get("timeline", {}), card.kind, card.get("event", ""), card.source,
		card.get("role", ""), card.observed_at, card.data, positive]
	var key = hash(inputs)
	if not report_matches.has(key) or report_matches[key].inputs != inputs:
		if report_matches.size() > 512:
			report_matches.clear()
		var accepted = PackedByteArray()
		accepted.resize(universe.size())
		# Worlds differing only in the demon's identity share one answer.
		var groups = sig_groups(view)
		var rep: PackedInt32Array = groups.rep
		var of: PackedInt32Array = groups.of
		var answers = PackedByteArray()
		answers.resize(rep.size())
		if card.kind == "report":
			# A valid source (vectorised), then the content where it matters.
			var valid: PackedByteArray = valid_table(view, card)
			var trivial: bool = card.get("role", "") not in CONTENT_ROLES
			for g in range(rep.size()):
				answers[g] = 0 if valid[rep[g]] == 0 else (1 if trivial or _report_content(view, universe[rep[g]], card, {"positive": positive}) else 0)
		else:
			for g in range(rep.size()):
				answers[g] = 1 if _report_holds(view, universe[rep[g]], card, {"positive": positive}) else 0
		for i in range(universe.size()):
			accepted[i] = answers[of[i]]
		report_matches[key] = {"inputs": inputs.duplicate(true), "accepted": accepted}
	return report_matches[key].accepted

## A world's key without the demon's identity. Report contents and source validity
## never read it, so worlds differing only there share one answer. -1: no key.
static func content_sig(view: Dictionary, world: Dictionary) -> int:
	if not world.has("__key"):
		return -1
	if world.has("demon"):
		return int(world.__key) / (view.people.size() + 1)
	return int(world.__key)

## Roles whose report content can fail in a world (the rest only need a valid source).
const CONTENT_ROLES = ["surveyor", "dowser", "rumormonger", "nightwatch"]

static var _bits: Dictionary = {}

## Per universe: each world's evil bits and Delusional holders' bits, and whether any
## world has a conversion history (fixture curse worlds).
static func world_bits(view: Dictionary) -> Dictionary:
	var key = _universe_key(view)
	if _bits.has(key):
		return _bits[key]
	if _bits.size() > 16:
		_bits.clear()
	var universe: Array = universe(view)
	var evil = PackedInt64Array()
	var deluded = PackedInt64Array()
	evil.resize(universe.size())
	deluded.resize(universe.size())
	var plain = true
	for i in range(universe.size()):
		var w: Dictionary = universe[i]
		evil[i] = int(w.evil)
		deluded[i] = int(w.get("holders", 0)) if w.get("modifier", "") == "delusional" else 0
		if w.has("converted"):
			plain = false
	_bits[key] = {"evil": evil, "deluded": deluded, "plain": plain}
	return _bits[key]

## source_valid for every world of the universe.
static func valid_table(view: Dictionary, card: Dictionary) -> PackedByteArray:
	var universe: Array = universe(view)
	var t = PackedByteArray()
	t.resize(universe.size())
	t.fill(0)
	if card.kind != "report":
		t.fill(1)
		return t
	var live: bool = Domain.live(view)
	# Gift timing and the source being alive don't vary by world.
	if live and (not Domain.gift_time(card) or not preload("res://workshop/live_history.gd").observer_alive(view, card.source, card.observed_at)):
		return t
	var bits = world_bits(view)
	var source: int = person_ids(view).find(card.source)
	if live and bits.plain:
		# No conversions: a good source that isn't Delusional.
		if source >= 0:
			var bit: int = 1 << source
			var evil: PackedInt64Array = bits.evil
			var deluded: PackedInt64Array = bits.deluded
			for i in range(universe.size()):
				t[i] = 0 if (evil[i] & bit) or (deluded[i] & bit) else 1
		return t
	var groups = sig_groups(view)
	var rep: PackedInt32Array = groups.rep
	var of: PackedInt32Array = groups.of
	var answers = PackedByteArray()
	answers.resize(rep.size())
	for g in range(rep.size()):
		answers[g] = 1 if source_valid(view, universe[rep[g]], card) else 0
	for i in range(universe.size()):
		t[i] = answers[of[i]]
	return t

static var _sig_groups: Dictionary = {}

## Per universe: worlds grouped by content_sig (dense ids, one representative each).
## Worlds without a key get a group of their own.
static func sig_groups(view: Dictionary) -> Dictionary:
	var key = _universe_key(view)
	if _sig_groups.has(key):
		return _sig_groups[key]
	if _sig_groups.size() > 16:
		_sig_groups.clear()
	var universe: Array = universe(view)
	var index = {}
	var rep = PackedInt32Array()
	var of = PackedInt32Array()
	of.resize(universe.size())
	for i in range(universe.size()):
		var sig: int = content_sig(view, universe[i])
		var g: int = index.get(sig, -1) if sig >= 0 else -1
		if g < 0:
			g = rep.size()
			rep.append(i)
			if sig >= 0:
				index[sig] = g
		of[i] = g
	_sig_groups[key] = {"rep": rep, "of": of}
	return _sig_groups[key]

## Whether a card is constrained by a report table (reports, and the curse event).
static func tabled(card: Dictionary) -> bool:
	return card.kind == "report" or (card.kind == "event" and card.get("event") == "curse")

## The source-side conditions of _report_holds: a good, healthy source able to read then.
## Where this fails, the report says nothing about the world (CaseEval: likelihood q).
static func source_valid(view: Dictionary, world: Dictionary, card: Dictionary) -> bool:
	if card.kind != "report":
		return true
	if TimeModel.evil_at(view, world, card.source, card.observed_at):
		return false
	if Domain.live(view):
		if not Domain.healthy(view, world, card.source) or not Domain.gift_time(card):
			return false
		if not preload("res://workshop/live_history.gd").observer_alive(view, card.source, card.observed_at):
			return false
	return true

static func _solve(view: Dictionary, cards: Array, positions: Dictionary = {}, answers: Dictionary = {}, knowledge: Dictionary = {}, epoch: String = "", temporal_positions: Array = []) -> Dictionary:
	# Report masks use the universe's array index, including distinct conversion
	# histories. Keep the worlds themselves unchanged for explanations/checkpoints.
	var universe: Array = universe(view)
	var tables: Array = []
	for card in cards:
		if not tabled(card):
			continue
		tables.append(report_table(view, card, answers.get(card.id, {}).get("positive", [])))
	var worlds: Array = []
	if tables.is_empty():
		worlds = universe.duplicate()
	else:
		for i in range(universe.size()):
			var accepted = true
			for table in tables:
				if table[i] == 0:
					accepted = false
					break
			if accepted:
				worlds.append(universe[i])
	if Domain.live(view) and not Domain.claims_compatible(cards, knowledge):
		worlds = []
	var has_curse: bool = view.get("chronology", {}).has("curse")
	if not has_curse and temporal_positions.is_empty():
		var must_be_good: int = 0
		for id in knowledge.get("good", []):
			var idx = person_index(view, id)
			if idx >= 0:
				must_be_good |= (1 << idx)
		var must_be_evil: int = 0
		var marked_req: int = -2
		var other_positions: Array = []
		for id in positions:
			var idx = person_index(view, id)
			if idx < 0:
				if positions[id] in ["evil", "marked", "unmarked"]:
					worlds = []
				continue
			var pos_val = positions[id]
			if pos_val == "good":
				must_be_good |= (1 << idx)
			elif pos_val == "evil":
				must_be_evil |= (1 << idx)
			elif pos_val == "marked":
				if marked_req >= 0 and marked_req != idx:
					worlds = [] # One world cannot have two different Marked people.
				marked_req = idx
			else:
				other_positions.append({"id": id, "pos": pos_val})
		if must_be_good != 0 or must_be_evil != 0 or marked_req != -2:
			worlds = worlds.filter(func(w):
				if (w.evil & must_be_good) != 0:
					return false
				if (w.evil & must_be_evil) != must_be_evil:
					return false
				if marked_req >= 0 and w.marked != marked_req:
					return false
				return true)
		for entry in other_positions:
			worlds = worlds.filter(func(w): return position_holds(view, w, entry.id, entry.pos, epoch))
	else:
		for id in knowledge.get("good", []):
			worlds = worlds.filter(func(w): return position_holds(view, w, id, "good", knowledge.get("good_epoch", epoch)))
		for id in positions:
			worlds = worlds.filter(func(w): return position_holds(view, w, id, positions[id], epoch))
		for assignment in temporal_positions:
			for id in assignment.positions:
				worlds = worlds.filter(func(w): return position_holds(view, w, id, assignment.positions[id], assignment.at))
	var movement_cards: Array = cards.filter(func(c): return c.kind in ["sighting", "alibi"] or (c.kind == "report" and c.get("role", "") in ["nightwatch", "lamplighter"]))
	if view.get("world_options", {}).get("roles", false):
		worlds = worlds.filter(func(w): return Roles.fits(view, w, cards, knowledge, answers))
	var movement = movement_for(view, cards if view.get("live_activity", false) else movement_cards, answers, knowledge)
	return {"worlds": worlds, "movement": movement.nights, "movement_ok": movement.okay}

static func movement_for(view: Dictionary, cards: Array, answers: Dictionary = {}, knowledge: Dictionary = {}) -> Dictionary:
	if preload("res://workshop/live_activity.gd").available(view):
		return preload("res://workshop/live_activity.gd").routes(view, cards, answers, knowledge)
	var ids: Array = view.people.map(func(p): return p.id)
	var movement_cards: Array = cards.filter(func(c): return c.kind in ["sighting", "alibi"] or (c.kind == "report" and c.get("role", "") in ["nightwatch", "lamplighter"]))
	var movement_key = JSON.stringify([ids, movement_cards, answers, knowledge])
	if not movement_cache.has(movement_key):
		if movement_cache.size() > 256:
			movement_cache.clear()
		movement_cache[movement_key] = _movement(view, movement_cards, answers, knowledge)
	return movement_cache[movement_key]

static func popcount(bits: int) -> int:
	var count = 0
	while bits:
		bits &= bits - 1
		count += 1
	return count

static func position_holds(view: Dictionary, world: Dictionary, id: String, position: String, epoch: String = "") -> bool:
	if position in ["demon", "minion"]:
		var i: int = person_index(view, id)
		return i >= 0 and (world.get("demon", -1) == i if position == "demon" else ((world.evil & (1 << i)) != 0 and world.get("demon", -1) != i))
	if position in ["marked", "unmarked"]:
		var index: int = person_index(view, id)
		if index < 0:
			return false
		return world.marked == index if position == "marked" else world.marked != index
	var evil: bool = TimeModel.evil_at(view, world, id, view.alignment_epoch if epoch == "" else epoch)
	return evil if position == "evil" else not evil

static func _report_holds(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	_ensure_people(view)
	if card.kind == "event" and card.get("event") == "curse":
		return answer.get("positive", []).is_empty() or view.people[world.get("converted", -1)].id in answer.positive
	if card.kind != "report":
		return true
	# An accepted healthy gift assumes a good source at the reading's time.
	return source_valid(view, world, card) and _report_content(view, world, card, answer)

## What a report says, given a valid source (see source_valid): does it hold here?
static func _report_content(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	_ensure_people(view)
	if Domain.live(view):
		if card.role == "nightwatch" and card.data.seen.any(func(id): return not preload("res://workshop/live_history.gd").alive_at_night(view, id, card.night)):
			return false
		if card.role == "rumormonger":
			return Domain.rumor(view, world, card, answer)
	var d: Dictionary = card.data
	if card.role == "rumormonger":
		var marked: int = world.marked
		var marked_id: String = _cached_ids[marked] if marked >= 0 and marked < _cached_ids.size() else ""
		return marked_id in d.pair and (answer.get("positive", []).is_empty() or marked_id in answer.positive)
	if card.role not in ["surveyor", "dowser"]:
		return true
	# A Marked person may register either way, independently for each reading.
	var evil_bits: int = world.evil
	if world.has("converted") and world.converted >= 0:
		if TimeModel.evil_index(view, world, world.converted, card.observed_at):
			evil_bits |= (1 << world.converted)
	var ans_pos = answer.get("positive", [])
	var ans_mask: int = 0
	for id in ans_pos:
		ans_mask |= (1 << person_index(view, id))
	var group_mask: int = 0
	if card.role == "dowser":
		for id in d.group:
			group_mask |= (1 << person_index(view, id))
	var is_surveyor: bool = card.role == "surveyor"
	var target_count: int = d.count
	_ensure_people(view)
	var b_masks: Array = _cached_block_masks.values()
	for mark_reads in [false, true]:
		var pos_mask: int = evil_bits | ((1 << world.marked) if (mark_reads and world.marked >= 0) else 0)
		if (pos_mask & ans_mask) != ans_mask:
			continue
		var count: int = 0
		if is_surveyor:
			for b in b_masks:
				if (pos_mask & b) != 0:
					count += 1
		else:
			count = popcount(pos_mask & group_mask)
		if count == target_count:
			return true
	return false

static func _movement(view: Dictionary, cards: Array, answers: Dictionary, knowledge: Dictionary = {}) -> Dictionary:
	var ids: Array = view.people.map(func(p): return p.id)
	var nights = {}
	var okay = true
	var observed_nights: Array = []
	for card in cards:
		if card.get("night", -1) >= 0 and card.night not in observed_nights:
			observed_nights.append(card.night)
	for night in observed_nights:
		var relevant: Array = cards.filter(func(c): return not c.get("quoted", false) and c.get("night", -1) == night and (c.kind in ["sighting", "alibi"] or c.get("role", "") in ["nightwatch", "lamplighter"]))
		if relevant.is_empty():
			continue
		var possibilities: Array = []
		for mask in range(1 << ids.size()):
			var valid = true
			var own: String = knowledge.get("self", "")
			if own in ids and knowledge.get("own_outings", {}).has(str(night)):
				if ((mask & (1 << ids.find(own))) != 0) != knowledge.own_outings[str(night)]:
					continue
			for card in relevant:
				var required: Array = []
				if card.kind == "sighting":
					required = card.get("subjects", [card.subject])
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
	var index: int = person_index(view, conclusion.target)
	if index < 0:
		return false
	match conclusion.type:
		"demon", "minion": return position_holds(view, world, conclusion.target, conclusion.type, conclusion.at)
		"evil", "suspicious": return TimeModel.evil_index(view, world, index, conclusion.at)
		"good": return not TimeModel.evil_index(view, world, index, conclusion.at)
		"marked": return world.marked == index
	return false

static func describe_world(view: Dictionary, world: Dictionary, epoch: String = "") -> Dictionary:
	var ids: Array = person_ids(view)
	var result = {"evil": ids.filter(func(id): return TimeModel.evil_at(view, world, id, view.alignment_epoch if epoch == "" else epoch)), "marked": ids[world.marked] if world.marked >= 0 else ""}
	if Domain.live(view):
		result["modifier"] = world.modifier
		if world.has("demon"):
			result["demon"] = ids[world.demon]
		result["holders"] = ids.filter(func(id): return world.holders & (1 << ids.find(id)))
	if world.has("converted"):
		result["converted"] = ids[world.converted]
	return result

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
			result.append("%s: challenge the home alibi using the linked observation; falsity is conditional on that observation, and does not prove intent or evil." % card.id if card.get("quoted", false) else "%s: accept the home alibi as accurate." % card.id)
	return result

static func validate_answers(view: Dictionary, case_data: Dictionary) -> Array:
	var errors: Array = []
	for id in case_data.answers:
		if id not in case_data.cards:
			continue
		var card = card_by_id(view, id)
		var positive: Array = case_data.answers[id].get("positive", [])
		var maximum: int = (0 if card.data.get("yes") == false else 1) if card.get("role") == "seer" else (1 if card.get("role", "") in ["rumormonger", "clerk", "archivist"] else card.get("data", {}).get("count", 10))
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
		if card.get("role", "") in ["clerk", "archivist", "seer"] and not positive.all(func(p): return p in card.data.pair):
			errors.append("%s: choose a person in this reading's pair." % id)
		if card.get("role") == "seer" and case_data.answers[id].get("registration", "") not in ["", "demon", "marked", "red_herring"]:
			errors.append("%s: choose a valid registration explanation." % id)
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
