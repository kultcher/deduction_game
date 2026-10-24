extends SceneTree
const Channels = preload("res://workshop/evidence_channels.gd")
const Model = preload("res://workshop/channel_likelihood.gd")
const Solver = preload("res://workshop/solver.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d"]:
		people.append({"id": id, "name": id, "home": "square"})
	var view = {"people": people, "evil_count": 1, "alignment_epoch": "Original alignment",
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked", "delusional"]}}
	var first = _report("one", "a")
	var second = _report("two", "b")
	var plan = Channels.compile(view, [first, second])
	var rates = _rates(plan, 0.8)
	var q = {"one": 0.5, "two": 0.5}
	var result = Model.assess(view, [first, second], {}, rates, q)
	var dense = Model.assess(view, [first, second], {}, rates, q, [], false)
	check(result.states < dense.states and _close(result.base, dense.base) and _close(result.post, dense.post) and result.acceptance.keys().all(func(id): return is_equal_approx(result.acceptance[id], dense.acceptance[id])), "eliminating irrelevant channels matches full enumeration for every world's likelihood and report acceptance")
	check(result.issues.is_empty() and _sum(result.post) > 0.0 and not result.consistent, "duplicate gift claims retain positive likelihood through dishonesty alternatives")
	check(result.base.size() == Solver.universe(view).size() and Array(result.base).all(func(value): return is_equal_approx(value, 1.0)), "case-only uncertainty integrates out of the private baseline")
	check(result.acceptance.one > 0.0 and result.acceptance.two > 0.0 and result.acceptance.one < 1.0, "competing reports have finite acceptance without assuming every source truthful")
	var knowledge = {"good": ["b"]}
	rates["gift_honesty:a"] = 1.0
	rates["gift_honesty:b"] = 1.0
	rates["gift_accuracy:b:1"] = {"healthy": 0.0, "impaired": 0.0}
	var impaired = Model.assess(view, [first, second], knowledge, rates, q)
	check(is_zero_approx(_sum(impaired.post)), "an impaired rival still truthfully claims the same unique gift, so impairment cannot repair the duplication")
	rates["gift_honesty:b"] = 0.0
	var lying = Model.assess(view, [first, second], knowledge, rates, q)
	check(_sum(lying.post) > 0.0, "a known good person can lie about their gift without making all worlds impossible")
	var universe = Solver.universe(view)
	check(range(universe.size()).all(func(index): return is_zero_approx(lying.post[index]) or not (universe[index].evil & (1 << 1))), "the dishonesty alternative preserves the listener's separate good knowledge")
	# Adding the submitted report must not alter the private-only denominator.
	rates = _rates(plan, 0.8)
	var submitted = Model.assess(view, [first, second], {}, rates, q, [first.id])
	var private_only = Model.assess(view, [first], {}, rates, q)
	check(_close(submitted.base, private_only.post), "private baseline marginalization excludes the submitted statement and its latent assumptions")
	# A Delusional source is certainly impaired in that hypothetical world, but an
	# inaccurate reading can still give this content by chance.
	var single_plan = Channels.compile(view, [first])
	var single_rates = _rates(single_plan, 1.0)
	var single = Model.assess(view, [first], {}, single_rates, q)
	var impaired_worlds = range(universe.size()).filter(func(index): return universe[index].modifier == "delusional" and universe[index].holders == 1 and not (universe[index].evil & 1))
	check(not impaired_worlds.is_empty() and impaired_worlds.all(func(index): return is_equal_approx(single.post[index], 0.5) and single.held.one[index] == 0.0), "hypothetical impairment relaxes the content with its finite false-content likelihood")
	# Several receipts of the original content are one observation, including when
	# that original content is inaccurate. They cannot square its chance penalty.
	var copy = first.duplicate(true)
	copy.id = "copy"
	copy.accuracy_origin = "one"
	single_rates["gift_honesty:a"] = 0.0
	var repeated = Model.assess(view, [first, copy], {}, single_rates, q)
	check(Array(repeated.post).all(func(value): return is_equal_approx(value, 0.5)), "repeat routes price one inaccurate original content once")
	var repeated_again = Model.assess(view, [first, copy], {}, single_rates, q)
	check(repeated_again.post == repeated.post and repeated_again.base == repeated.base, "cached conditional solves do not accumulate likelihoods or mutate prior results")
	print("Channel likelihood: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _report(id: String, source: String) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": "seer", "observed_at": {"day": 1, "phase": "night"}, "night": 1, "data": {"pair": ["c", "d"], "yes": true}}

func _rates(plan: Dictionary, honesty: float) -> Dictionary:
	var rates = {}
	for channel in plan.channels:
		rates[channel.key] = {"healthy": 0.9, "impaired": 0.0} if channel.kind == "gift_accuracy" else honesty
	return rates

func _sum(values: PackedFloat64Array) -> float:
	var total = 0.0
	for value in values:
		total += value
	return total

func _close(a: PackedFloat64Array, b: PackedFloat64Array) -> bool:
	return a.size() == b.size() and range(a.size()).all(func(index): return is_equal_approx(a[index], b[index]))

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
