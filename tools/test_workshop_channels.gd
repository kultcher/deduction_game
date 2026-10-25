extends SceneTree
const Channels = preload("res://workshop/evidence_channels.gd")
const Roles = preload("res://workshop/role_constraints.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var view = {"alignment_epoch": "Original alignment", "people": [{"id": "a", "home": "square"}, {"id": "b", "home": "market"}, {"id": "c", "home": "hill"}, {"id": "d", "home": "docks"}], "world_options": {"roles": true}}
	var first = _report("first", "a", 1, "night")
	var day = _report("day", "a", 2, "morning")
	var later = _report("later", "a", 2, "night")
	var alibi = {"id": "alibi", "kind": "alibi", "source": "a", "subject": "a", "night": 1, "observed_at": first.observed_at}
	var plan = Channels.compile(view, [first, day, later, alibi])
	check(plan.issues.is_empty() and plan.channels.size() == 4, "three reports use one gift-honesty, two accuracy windows and a separate testimony channel")
	check(plan.statements[0].content == plan.statements[1].content and plan.statements[0].content != plan.statements[2].content, "poison uncertainty is shared through the following day, then expires at the next night")
	var state = _all(plan)
	state[_index(plan, "gift_accuracy:a:1")] = 0
	var impaired = Channels.materialize(plan, state)
	check("first" not in impaired.accurate and "day" not in impaired.accurate and "later" in impaired.accurate and "alibi" in impaired.accurate, "impairment relaxes exactly its gift window, leaving testimony and later readings intact")
	check(impaired.cards.any(func(card): return card.kind == "claim" and card.source == "a" and card.role == "seer"), "a good-faith inaccurate report retains its gift declaration")
	state = _all(plan)
	state[_index(plan, "testimony_honesty:a")] = 0
	var dishonest_alibi = Channels.materialize(plan, state)
	check("alibi" not in dishonest_alibi.accurate and "first" in dishonest_alibi.accurate and "later" in dishonest_alibi.accurate, "a whereabouts lie does not invalidate gift readings")
	state = _all(plan)
	state[_index(plan, "gift_honesty:a")] = 0
	var lying = Channels.materialize(plan, state)
	check(lying.accurate == ["alibi"] and lying.statements.size() == 4 and not lying.cards.any(func(card): return card.kind == "claim"), "gift dishonesty is shared across reports while the heard statements remain recorded")
	var weights = {}
	for channel in plan.channels:
		weights[channel.key] = 1.0
	weights["gift_accuracy:a:1"] = 0.7
	var states = Channels.states(plan, weights)
	check(states.size() == 2 and is_equal_approx(states[0].weight + states[1].weight, 1.0), "fixed assumptions do not branch, and uncertain channel mass sums to one")
	var both = 0.0
	for item in states:
		var materialized = Channels.materialize(plan, item.state)
		if "first" in materialized.accurate and "day" in materialized.accurate:
			both += item.weight
	check(is_equal_approx(both, 0.7), "two readings in one window pay the shared accuracy probability once, not squared")
	var duplicate = _report("duplicate-role", "b", 1, "night")
	var rival = Channels.compile(view, [first, duplicate])
	state = _all(rival)
	var world = {"evil": 1 << 3, "marked": 2, "demon": 3}
	check(not Roles.fits(view, world, Channels.materialize(rival, state).cards, {}), "two truthful claims to the same unique gift cannot coexist")
	state[_index(rival, "gift_accuracy:b:1")] = 0
	check(not Roles.fits(view, world, Channels.materialize(rival, state).cards, {}), "impairment alone cannot excuse an impossible duplicate gift claim")
	state[_index(rival, "gift_honesty:b")] = 0
	check(Roles.fits(view, world, Channels.materialize(rival, state).cards, {}), "a dishonest claim is a legal alternative without declaring its good speaker evil")
	_medium(view, first)
	var quoted = first.duplicate(true)
	quoted.quoted = true
	var quotation = Channels.compile(view, [quoted])
	check(quotation.channels.is_empty() and Channels.materialize(quotation, PackedByteArray()).cards == [quoted], "quoting a report retains the statement without assuming its honesty or accuracy")
	var malformed = first.duplicate(true)
	malformed.observed_at.phase = "unknown"
	check(not Channels.compile(view, [malformed]).issues.is_empty(), "unknown original timing cannot silently select a poison window")
	malformed.erase("observed_at")
	check(not Channels.compile(view, [malformed]).issues.is_empty(), "missing original timing is rejected before canonicalizing the predicate")
	print("Evidence channels: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _medium(view: Dictionary, first: Dictionary) -> void:
	var relay = first.duplicate(true)
	relay.id = "relay"
	relay.accuracy_origin = first.id
	relay.relay_source = "c"
	relay.relay_observed_at = {"day": 3, "phase": "night"}
	var plan = Channels.compile(view, [first, relay])
	check(plan.channels.size() == 5 and plan.channels.filter(func(channel): return channel.key == "gift_accuracy:a:1").size() == 1, "a faithful Medium relay shares the original gift's accuracy and adds its own channel and route")
	var state = _all(plan)
	var faithful = Channels.materialize(plan, state)
	check(faithful.cards.filter(func(card): return card.kind == "report").size() == 1 and faithful.accurate.size() == 2 and faithful.cards.any(func(card): return card.get("relay_source") == "c"), "two faithful paths emit the original predicate once, while retaining the separate Medium visit and route acceptance")
	state[_index(plan, "gift_accuracy:a:1")] = 0
	var original_impaired = Channels.materialize(plan, state)
	check(original_impaired.cards.any(func(card): return card.kind == "claim" and card.source == "c" and card.role == "medium") and original_impaired.cards.any(func(card): return card.get("relay_source") == "c"), "a faithful relay keeps the Medium's gift and visit when the original reading was impaired")
	state = _all(plan)
	state[_index(plan, "gift_accuracy:c:3")] = 0
	var medium_impaired = Channels.materialize(plan, state)
	check("first" in medium_impaired.accurate and "relay" not in medium_impaired.accurate and medium_impaired.cards.any(func(card): return card.kind == "claim" and card.source == "c") and not medium_impaired.cards.any(func(card): return card.has("relay_source")), "a misled Medium retains its gift, without erasing the independently heard original or asserting the visit")
	state = _all(plan)
	state[_index(plan, "transmission:relay")] = 0
	var bad_route = Channels.materialize(plan, state)
	check(bad_route.accurate == ["first"] and not bad_route.cards.any(func(card): return card.source == "c" or card.has("relay_source")), "rejecting the transmission drops only that relay, without discrediting the original source")

func _report(id: String, source: String, day: int, phase: String) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": "seer", "observed_at": {"day": day, "phase": phase}, "night": day, "data": {"pair": ["c", "d"], "yes": true}}

func _all(plan: Dictionary) -> PackedByteArray:
	var state = PackedByteArray()
	state.resize(plan.channels.size())
	state.fill(1)
	return state

func _index(plan: Dictionary, key: String) -> int:
	return plan.channels.map(func(channel): return channel.key).find(key)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
