## Independent constraint oracle plus exact shared/scalar assessment comparisons.
extends SceneTree
const Session = preload("res://workshop/session.gd")
const Solver = preload("res://workshop/solver.gd")
const Support = preload("res://workshop/support_model.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Jury = preload("res://workshop/jury.gd")
var checks = 0
var fails = 0

func _initialize() -> void:
	var view: Dictionary = Session.new(692).scenario.public_view.duplicate(true)
	var rumor = Solver.card_by_id(view, "rumor")
	var ids: Array = view.people.map(func(p): return p.id)
	var world = {"evil": 0, "marked": ids.find(rumor.data.pair[0])}
	Solver._cached_people = null
	Solver._cached_ids = []
	check(Solver._report_holds(view, world, rumor, {}), "cold direct Rumormonger check initializes its own roster cache")
	var other = view.duplicate(true)
	other.people.reverse()
	Solver.person_ids(other)
	check(Solver._report_holds(view, world, rumor, {}), "Rumormonger check refreshes after a different roster ordering")
	Solver.person_ids(view)
	TimeModel._person_index(view, ids[0])
	Domain._person_index(view, ids[0])
	view.people.reverse()
	check(Solver.person_index(view, ids[0]) == ids.size() - 1, "in-place roster edits invalidate Solver's index snapshot")
	check(TimeModel._person_index(view, ids[0]) == ids.size() - 1 and Domain._person_index(view, ids[0]) == ids.size() - 1, "chronology and modifier indices also invalidate after in-place edits")
	view.people.reverse()
	check(Solver.solve(view, [], {"nisha": "marked", "constance": "marked"}).worlds.is_empty(), "two different Marked assignments cannot overwrite one another")
	check(Solver.solve(view, [], {"missing-person": "evil"}).worlds.is_empty(), "invalid identity cannot silently satisfy an evil position")
	var before = Solver.solve(view, [Solver.card_by_id(view, "survey")]).worlds
	for p in view.people:
		p.home = "market"
	check(not before.is_empty() and Solver.solve(view, [Solver.card_by_id(view, "survey")]).worlds.is_empty(), "editing homes invalidates Surveyor masks even when IDs/setup are unchanged")
	view = Session.new(692).scenario.public_view.duplicate(true)
	var card = Solver.card_by_id(view, "survey")
	var universe_key = str([Solver.person_ids(view), view.evil_count, view.get("chronology", {}), view.get("world_options", {})])
	var key = hash([universe_key, view.people, card.kind, card.get("event", ""), card.source, card.get("role", ""), card.observed_at, card.data, []])
	Solver.report_matches[key] = {"inputs": ["simulated hash collision"], "accepted": PackedByteArray()}
	check(Solver.solve(view, [card]).worlds == before, "exact report inputs reject a colliding cache entry")
	for fixture in ["core", "movement", "poison", "revenant"]:
		var session = Session.new(692, fixture)
		var v: Dictionary = session.scenario.public_view
		var reports: Array = v.cards.filter(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"])
		for selected in [[reports[0]], reports.slice(0, 2), reports]:
			_oracle(v, selected, {}, {}, {}, v.alignment_epoch)
		_oracle(v, reports, {"nisha": "marked"}, {}, {"good": ["bart"]}, v.alignment_epoch)
		_oracle(v, reports, {}, {reports[0].id: {"positive": ["hollis"]}}, {}, v.alignment_epoch)
		if fixture == "revenant":
			_oracle(v, reports, {}, {}, {}, "during curse", [{"at": "during curse", "positions": {"merrin": "evil"}}])
		var proposal = session.case_data.duplicate(true)
		proposal.cards = reports.map(func(c): return c.id)
		if fixture == "movement":
			proposal.cards.append_array(["soot2", "evening2"])
		var listener = Ghost.profile(v.people)
		listener.reading_reliability[Solver.semantic_key(reports[0])] = 0.65
		_batch(v, proposal, listener, fixture)
		proposal.positions.nisha = "marked"
		proposal.answers[reports[0].id] = {"positive": ["hollis"]}
		_batch(v, proposal, listener, fixture + " conditional")
		Support.reuse_batches = false
		var scalar = Jury.evaluate(v, proposal, listener.duplicate(true))
		Support.reuse_batches = true
		check(Jury.evaluate(v, proposal, listener.duplicate(true)) == scalar, fixture + " complete jury agrees exactly with separate assessment plans")
	# Live modifier domains also retain exactly the same survivor order.
	var live = Session.new(692).scenario.public_view.duplicate(true)
	live.world_options = {"modifiers": ["marked", "delusional", "lovers", "sleepwalker"]}
	var reports: Array = live.cards.filter(func(c): return c.kind == "report" and c.role in ["surveyor", "rumormonger", "dowser"])
	_oracle(live, reports, {}, {}, {}, live.alignment_epoch)
	_oracle(live, reports, {"hollis": "evil"}, {}, {"good": ["bart"]}, live.alignment_epoch)
	var proposal = Solver.empty_case()
	proposal.cards = reports.map(func(c): return c.id)
	var listener = Ghost.profile(live.people)
	_batch(live, proposal, listener, "live")
	var limits = {"support": 48, "rivals": 48, "complete": true}
	Reasoner.reuse_matches = false
	var expected = Reasoner.search(live, proposal, reports, listener, limits)
	Reasoner.reuse_matches = true
	Reasoner.search(live, proposal, reports, listener, limits)
	check(Reasoner.search(live, proposal, reports, listener, limits) == expected, "whole-query reuse preserves exact bounded search result and effort")
	proposal.conclusion.target = "missing-person"
	proposal.conclusion.type = "good"
	Reasoner.reuse_matches = false
	expected = Reasoner.search(live, proposal, reports, listener, limits)
	Reasoner.reuse_matches = true
	check(Reasoner.search(live, proposal, reports, listener, limits) == expected and expected.support.is_empty(), "fast candidate holds cannot treat an unknown target as good")
	print("Workshop efficiency: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _batch(view: Dictionary, proposal: Dictionary, listener: Dictionary, label: String) -> void:
	var shared = {"enabled": true}
	for person in view.people:
		for type in ["evil", "good"]:
			var question = proposal.duplicate(true)
			question.conclusion = {"target": person.id, "type": type, "at": proposal.conclusion.at}
			var prepared = Reasoner.prepare(view, question, listener)
			var scalar = Support.assess(view, question, listener, {}, prepared)
			check(Support.assess(view, question, listener, {}, prepared, shared) == scalar, "%s %s %s shared/scalar equality" % [label, person.id, type])
	# Same context must not retain stale source quality or first-hand knowledge.
	var changed = listener.duplicate(true)
	changed.suspicion[view.people[0].id] = 0.95
	changed.knowledge.good = [view.people[-1].id]
	var prepared = Reasoner.prepare(view, proposal, changed)
	check(Support.assess(view, proposal, changed, {}, prepared, shared) == Support.assess(view, proposal, changed, {}, prepared), label + " shared plan invalidates changed beliefs/knowledge")

func _oracle(view: Dictionary, cards: Array, positions: Dictionary, answers: Dictionary, knowledge: Dictionary, epoch: String, temporal: Array = []) -> void:
	# Deliberately use the original array/string report predicates, independent of
	# the optimized report masks, cached index mappings and bitwise position filter.
	var expected: Array = []
	for world in Solver.solve(view, []).worlds:
		var valid = not Domain.live(view) or Domain.claims_compatible(cards, knowledge)
		for id in knowledge.get("good", []):
			valid = valid and Solver.position_holds(view, world, id, "good", knowledge.get("good_epoch", epoch))
		for id in positions:
			valid = valid and Solver.position_holds(view, world, id, positions[id], epoch)
		for assignment in temporal:
			for id in assignment.positions:
				valid = valid and Solver.position_holds(view, world, id, assignment.positions[id], assignment.at)
		for card in cards:
			valid = valid and _report(view, world, card, answers.get(card.id, {}))
		if valid:
			expected.append(world)
	check(Solver.solve(view, cards, positions, answers, knowledge, epoch, temporal).worlds == expected, "indexed report intersection matches independent predicates and order")

func _report(view: Dictionary, world: Dictionary, card: Dictionary, answer: Dictionary) -> bool:
	var ids: Array = view.people.map(func(p): return p.id)
	if TimeModel.evil_index(view, world, ids.find(card.source), card.observed_at):
		return false
	if Domain.live(view):
		if not Domain.healthy(view, world, card.source) or not Domain.gift_time(card):
			return false
		if card.role == "rumormonger":
			return Domain.rumor(view, world, card, answer)
	if card.role == "rumormonger":
		return ids[world.marked] in card.data.pair and (answer.get("positive", []).is_empty() or ids[world.marked] in answer.positive)
	for reads in [false, true]:
		var positive: Array = []
		for i in range(ids.size()):
			if TimeModel.evil_index(view, world, i, card.observed_at) or (i == world.marked and reads):
				positive.append(ids[i])
		var blocks: Array = []
		for p in view.people:
			if p.id in positive and p.home not in blocks:
				blocks.append(p.home)
		var count: int = blocks.size() if card.role == "surveyor" else card.data.group.filter(func(id): return id in positive).size()
		if count == card.data.count and answer.get("positive", []).all(func(id): return id in positive):
			return true
	return false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
