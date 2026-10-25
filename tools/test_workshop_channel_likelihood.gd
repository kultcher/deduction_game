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
	var corrupt = copy.duplicate(true)
	corrupt.data.yes = false
	check(not Model.assess(view, [first, corrupt], {}, single_rates, q).issues.is_empty(), "conflicting payloads cannot silently reuse an original content identity")
	_claims(view, first)
	_testimony(view, first)
	print("Channel likelihood: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _claims(view: Dictionary, report: Dictionary) -> void:
	var claim = {"id": "claim", "kind": "claim", "source": "a", "role": "seer", "observed_at": {"day": 1, "phase": "night"}, "data": {}}
	var again = claim.duplicate(true)
	again.id = "claim-tomorrow"
	again.observed_at.day = 2
	var rates = {"gift_honesty:a": 0.8, "gift_accuracy:a:1": {"healthy": 0.9, "impaired": 0.0}}
	var q = {"one": 0.5, "claim": 0.01, "claim-tomorrow": 0.01}
	var once = Model.assess(view, [claim], {}, rates, q)
	var repeated = Model.assess(view, [claim, again], {}, rates, q)
	check(_close(once.post, repeated.post), "repeating the same gift declaration tomorrow supplies no independent likelihood")
	var universe = Solver.universe(view)
	check(range(universe.size()).all(func(index): return is_equal_approx(once.post[index], 0.2 if universe[index].evil & 1 else 1.0)), "a role declaration has finite shared honesty, without an extra arbitrary false-content penalty")
	var private_claim = Model.assess(view, [claim, again], {}, rates, q, [claim.id])
	check(_close(private_claim.base, private_claim.post), "restating an already privately known declaration cannot improve the case over its own baseline")
	var reading = Model.assess(view, [report], {}, rates, q)
	var with_claim = Model.assess(view, [report, claim], {}, rates, q)
	check(_close(reading.post, with_claim.post), "an explicit declaration adds nothing beyond the same declaration already inherent in a named reading")

func _testimony(view: Dictionary, report: Dictionary) -> void:
	var activity_view = view.duplicate(true)
	activity_view.live_activity = true
	var alibi = {"id": "alibi", "kind": "alibi", "source": "a", "subject": "a", "subjects": ["a"], "night": 1, "block": "", "observed_at": {"day": 1, "phase": "night"}}
	var sighting = {"id": "seen", "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": 1, "block": "square", "observed_at": {"day": 1, "phase": "night"}}
	var rates = {"gift_honesty:a": 0.8, "gift_accuracy:a:1": {"healthy": 0.9, "impaired": 0.0}, "testimony_honesty:a": 0.6}
	var q = {"one": 0.5, "alibi": 0.001}
	var without_alibi = Model.assess(activity_view, [report, sighting], {}, rates, q)
	var caught = Model.assess(activity_view, [report, sighting, alibi], {}, rates, q)
	check(_sum(caught.post) > 0.0 and range(caught.post.size()).all(func(index): return is_equal_approx(caught.post[index], 0.4 * without_alibi.post[index])), "a directly refuted alibi selects the testimony-dishonesty state without changing the gift likelihood or declaring guilt")
	check(is_equal_approx(caught.acceptance.one, without_alibi.acceptance.one) and caught.acceptance.alibi == 0.0, "catching a whereabouts lie leaves the independent gift channel's acceptance intact")

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
