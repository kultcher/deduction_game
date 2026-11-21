## The Unrequited walk in the judge (burdens prototype; Michael, Nov 21: placed holders). In a
## world where a good person holds Unrequited, the movement model scores them on their own
## column: they visit the beloved's block on most nights (UNREQUITED_VISIT_CHANCE, forced the
## night after a missed one once they've visited; sim/burdens.gd unrequited_visit), so a night
## walk there is explained, and a walk elsewhere isn't. The beloved is anyone else, or the one
## their own claim names. C# (the kernel) and the GDScript mirror agree.
##   godot --headless --path . --script res://tools/test_burden_unrequited_walk.gd
extends SceneTree

const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Caches = preload("res://workshop/caches.gd")
const RC = preload("res://workshop/role_constraints.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## A hand-built town: "a" lives on the Hill, "b" (the beloved in the claim) on the Docks.
func _view(cards: Array, unrequited: bool) -> Dictionary:
	var people: Array = []
	var homes: Dictionary = {"a": "hill", "b": "docks", "c": "market", "d": "square", "e": "market", "f": "square", "g": "docks"}
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": homes[id], "alive": true})
	var mods: Array = ["delusional", "marked", "ill_omened"] + (["unrequited"] if unrequited else [])
	return {"people": people, "cards": cards, "evil_count": 2, "day": 4, "alignment_epoch": "Original alignment", "live_activity": true,
		"world_options": {"roles": true, "identities": true, "modifiers": mods}}

func _out(id: String, night: int, block: String) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": night, "block": block,
		"data": {}, "role": "", "hearing_weight": 1.0, "observed_at": {"day": night, "phase": "night"}}

func _vigil(id: String, night: int, block: String) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "coverage", "source": "player", "night": night, "block": block, "excluded": [],
		"observed_at": {"day": night, "phase": "night"}}

func _claim(beloved: String) -> Dictionary:
	var data: Dictionary = {"secret_kind": "unrequited"}
	if beloved != "":
		data["beloved"] = beloved
	return {"id": "uc", "fact_id": "uc", "kind": "secret_claim", "source": "a", "subject": "a", "observed_at": {"day": 3, "phase": "morning"},
		"night": -1, "applies": {"from": 0, "through": 3}, "data": data, "text": "a claims Unrequited"}

func _p(cards: Array, unrequited: bool) -> float:
	Caches.clear_all()
	var view: Dictionary = _view(cards, unrequited)
	var c = Solver.empty_case()
	c.conclusion = {"type": "evil", "target": "a", "at": view.alignment_epoch}
	c.cards = cards.map(func(x): return x.id)
	return float(CaseEval.evaluate(view, c, CaseEval.neutral_listener(view)).get("posterior", -1.0))

func _odds(p: float) -> float:
	return p / maxf(1.0 - p, 1e-9)

func _init() -> void:
	var was_bind: bool = RC.burden_claims_bind
	RC.burden_claims_bind = true
	var twice: Array = [_out("o1", 1, "docks"), _out("o2", 2, "docks")]
	# 1. Seen out on the beloved's block twice: with Unrequited dealt, the walks may be visits.
	var prior_u: float = _p([], true)
	var prior_n: float = _p([], false)
	var with_u: float = _p(twice, true)
	var without_u: float = _p(twice, false)
	var shift_u: float = _odds(with_u) / _odds(prior_u)
	var shift_n: float = _odds(without_u) / _odds(prior_n)
	print("Seen out on the Docks on nights 1 and 2: %.3f -> %.3f evil with Unrequited dealt; %.3f -> %.3f without (odds x%.2f against x%.2f)" % [prior_u, with_u, prior_n, without_u, shift_u, shift_n])
	check(with_u < without_u and shift_u < shift_n, "two walks to one block count for less when Unrequited is dealt (%.3f against %.3f)" % [with_u, without_u])
	# 2. A claim naming the beloved explains walks to their block, not walks elsewhere.
	var elsewhere: Array = [_out("o1", 1, "market"), _out("o2", 2, "market")]
	var named_there: float = _p(twice + [_claim("b")], true)
	var named_elsewhere: float = _p(elsewhere + [_claim("b")], true)
	var plain_elsewhere: float = _p(elsewhere, true)
	print("Claims Unrequited for b (the Docks): out on the Docks twice %.3f evil; out on the Market twice %.3f (no claim %.3f)" % [named_there, named_elsewhere, plain_elsewhere])
	check(named_there < named_elsewhere, "a named beloved explains walks to their block (%.3f), not to another (%.3f)" % [named_there, named_elsewhere])
	check(named_elsewhere >= plain_elsewhere - 0.005, "walks elsewhere: the claim with a named beloved doesn't help (%.3f against %.3f without it)" % [named_elsewhere, plain_elsewhere])
	# 3. Two missed nights in a row after a visit can't happen to a holder (a missed night
	# forces the next): the holder's own column, against a good person's.
	var view_u: Dictionary = _view([], true)
	var a: Dictionary = view_u.people[0]
	var one_miss: Array = [_out("o1", 1, "docks"), _vigil("v2", 2, "docks"), _out("o3", 3, "docks")]
	var two_miss: Array = [_out("o1", 1, "docks"), _vigil("v2", 2, "docks"), _vigil("v3", 3, "docks")]
	var r_one: float = Activity.unrequited_likelihood(_view(one_miss, true), one_miss, a) / Activity._likelihood(_view(one_miss, true), one_miss, a, "good")
	var r_two: float = Activity.unrequited_likelihood(_view(two_miss, true), two_miss, a) / Activity._likelihood(_view(two_miss, true), two_miss, a, "good")
	print("Holder against plain good: visit, miss, visit x%.2f; visit, miss, miss x%.2f" % [r_one, r_two])
	check(r_one > 1.0 and r_two < r_one * 0.5, "two missed nights running after a visit count against holding it (x%.2f against x%.2f)" % [r_two, r_one])
	# 3b. A claim that explains evidence already against its claimant is weighed as a bluff
	# might be (Michael, Nov 21): told after the sightings, the Unrequited claim takes the
	# reactive weight; told before them (an earlier telling), full credit; a burden that
	# doesn't explain walks (Marked) isn't made reactive by a sighting.
	var early: Dictionary = _claim("b")
	early.id = "uc0"; early.fact_id = "uc0"
	early.observed_at = {"day": 0, "phase": "afternoon"}
	var marked: Dictionary = _claim("")
	marked.id = "mc"; marked.fact_id = "mc"
	marked.data = {"secret_kind": "marked"}
	var fl: Callable = func(cards: Array) -> Array:
		var f: Array = RC.burden_claim_factors(_view(cards, true), cards)
		return f.map(func(x): return bool(x[3]))
	var late_flag: Array = fl.call(twice + [_claim("b")])
	var early_flag: Array = fl.call(twice + [early])
	var marked_flag: Array = fl.call(twice + [marked])
	var told_before: float = _p(twice + [early], true)
	print("Seen out on the Docks twice, then claims Unrequited for b: %.3f evil (reactive %s); told before the walks: %.3f (reactive %s); a Marked claim after them reactive %s" % [named_there, late_flag, told_before, early_flag, marked_flag])
	check(late_flag == [true], "an Unrequited claim told after the claimant was seen out is reactive (%s)" % [late_flag])
	check(early_flag == [false] and told_before < named_there, "an earlier telling keeps full credit (%.3f against %.3f)" % [told_before, named_there])
	check(marked_flag == [false], "a sighting doesn't make a Marked claim reactive (%s)" % [marked_flag])
	# 4. The kernel and the mirror agree.
	var sets: Array = [twice, elsewhere, twice + [_claim("b")], elsewhere + [_claim("b")], one_miss, two_miss, []]
	var worst: float = 0.0
	for cards in sets:
		var view: Dictionary = _view(cards, true)
		for person in view.people:
			var cs: float = Activity.unrequited_likelihood(view, cards, person)
			var gd: float = Activity._unrequited_likelihood_gd(view, cards, person)
			worst = maxf(worst, absf(cs - gd) / maxf(absf(gd), 1e-300))
	check(worst < 1e-9, "C# and GDScript agree on the holder column (worst relative gap %s)" % str(worst))
	RC.burden_claims_bind = was_bind
	print("Unrequited walk: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
