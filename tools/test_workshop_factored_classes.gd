## The compact kernel must agree with exact enumeration for every legal world,
## including modifier worlds that share an alignment but differ in gift health.
extends SceneTree
const Model = preload("res://workshop/channel_likelihood.gd")
const Factored = preload("res://workshop/factored_channels.gd")
const Channels = preload("res://workshop/evidence_channels.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
var checks = 0
var fails = 0

func _init() -> void:
	for count in [7, 10]:
		var people: Array = []
		for index in range(count):
			people.append({"id": "p%d" % index, "name": "Person %d" % index, "home": ["square", "market", "hill", "docks"][index % 4]})
		var view = {"people": people, "evil_count": 2 if count == 7 else 3, "alignment_epoch": "Original alignment",
			"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional", "lovers", "sleepwalker"]}}
		var cards: Array = [
			{"id": "survey", "kind": "report", "source": "p0", "role": "surveyor", "night": 0, "observed_at": {"day": 0, "phase": "night"}, "data": {"count": 2}},
			{"id": "dowsing", "kind": "report", "source": "p1", "role": "dowser", "night": -1, "observed_at": {"day": 1, "phase": "morning"}, "data": {"group": ["p2", "p3", "p4"], "count": 1}},
			{"id": "seer", "kind": "report", "source": "p2", "role": "seer", "night": 1, "observed_at": {"day": 1, "phase": "night"}, "data": {"pair": ["p3", "p4"], "yes": true}}]
		_compare(view, cards, {"self": people.back().id, "own_role": "warden", "good": [people.back().id]}, ["survey"])
		if count == 7:
			var relay = cards[2].duplicate(true)
			relay.id = "medium"
			relay.accuracy_origin = "seer"
			relay.relay_source = "p1"
			relay.relay_observed_at = {"day": 3, "phase": "night"}
			view.live_activity = true
			view.timeline = {"events": [{"kind": "demon_death", "subjects": ["p2"], "at": {"day": 2, "phase": "night"}}]}
			_compare(view, [cards[2], relay], {"self": people.back().id, "own_role": "warden", "good": [people.back().id]}, [])
	print("Factored channel class parity: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _compare(view: Dictionary, cards: Array, knowledge: Dictionary, own: Array) -> void:
	view.cards = cards
	var value = Solver.empty_case()
	value.cards = cards.map(func(card): return card.id)
	value.conclusion = {"type": "evil", "target": "p0", "at": view.alignment_epoch}
	var cc = Eval.compile(view, cards, value)
	var rates = {}
	var q = {}
	for channel in Channels.compile(view, cards).channels:
		rates[channel.key] = {"healthy": 0.83, "impaired": 0.0} if channel.kind == "gift_accuracy" else 0.72
	for card in cards:
		q[card.get("accuracy_origin", card.id)] = Eval.chance_content(view, card)
	var exact = Model.assess(view, cards, knowledge, rates, q, own, false)
	var compact = Factored.assess(view, cards, knowledge, rates, q, own, cc.rep, cc.count)
	var base_matches = true
	var post_matches = true
	var held_matches = true
	for world in range(cc.class_of.size()):
		var group: int = cc.class_of[world]
		base_matches = base_matches and is_equal_approx(exact.base[world], compact.base[group])
		post_matches = post_matches and is_equal_approx(exact.post[world], compact.post[group])
		for id in exact.held:
			held_matches = held_matches and is_equal_approx(exact.held[id][world], compact.held[id][group])
	check(base_matches and post_matches and held_matches, "class representatives and eliminated channels preserve every world's private, submitted and accepted-content likelihoods")
	check(exact.acceptance.keys().all(func(id): return is_equal_approx(exact.acceptance[id], compact.acceptance[id])) and exact.consistent == compact.consistent, "class multiplicity preserves acceptance and consistency, including relays")
	check(compact.post.size() <= exact.post.size() and (cards.any(func(card): return card.has("relay_source")) or compact.post.size() < exact.post.size()), "ordinary reports evaluate fewer representatives; relays retain every distinct required modifier state")
	var again = Factored.assess(view, cards, knowledge, rates, q, own, cc.rep, cc.count)
	check(again.post == compact.post and again.base == compact.base, "reusing conditional programs preserves the exact compact output")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
