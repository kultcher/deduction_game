## The Sexton walks every block on the night it tolls the bell (Michael, Nov 21; reading
## interpretation, "Walking every block"). Its own toll report names the night, and the
## movement model reads a good Sexton's walk that night as a tour of every block, as it does a
## Lamplighter's every night. So a sighting of the Sexton out on its toll night doesn't count
## against it, while the same sighting on another night does. C# and the GDScript mirror agree.
##   godot --headless --path . --script res://tools/test_sexton_toll_tour.gd
extends SceneTree

const Solver = preload("res://workshop/solver.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Activity = preload("res://workshop/live_activity.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveAssessment = preload("res://workshop/live_assessment.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## A hand-built town: the listener "a"; the Sexton "s" on the Market, who says it tolled on
## night 2; "t" says it saw "s" on the Docks.
func _view(cards: Array, unrequited: bool = false) -> Dictionary:
	var people: Array = []
	var homes: Dictionary = {"a": "hill", "s": "market", "t": "square", "c": "market", "d": "square", "e": "docks", "f": "docks"}
	for id in ["a", "s", "t", "c", "d", "e", "f"]:
		people.append({"id": id, "name": id, "home": homes[id], "alive": true})
	return {"people": people, "cards": cards, "evil_count": 2, "day": 3, "alignment_epoch": "Original alignment", "live_activity": true,
		"world_options": {"roles": true, "identities": true, "modifiers": ["delusional", "marked"] + (["unrequited"] as Array if unrequited else [])}}

func _claim() -> Dictionary:
	return {"id": "c_s", "fact_id": "c_s", "kind": "claim", "source": "s", "subject": ["s"], "role": "sexton",
		"observed_at": {"day": 1, "phase": "afternoon"}, "reported_at": {"day": 1, "phase": "afternoon"}}

func _toll(night: int) -> Dictionary:
	return {"id": "toll", "fact_id": "toll", "kind": "report", "source": "s", "role": "sexton", "night": night, "data": {"night": night},
		"observed_at": {"day": night, "phase": "night"}, "reported_at": {"day": night + 1, "phase": "afternoon"}}

func _seen(id: String, night: int, block: String, by: String = "t") -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "sighting", "source": by, "subject": "s", "subjects": ["s"], "night": night, "block": block,
		"data": {}, "role": "", "observed_at": {"day": night, "phase": "night"}, "reported_at": {"day": night + 1, "phase": "morning"}}

func _p(cards: Array, target: String, fresh: bool = true) -> float:
	if fresh:
		Caches.clear_all()
	var view: Dictionary = _view(cards)
	var listener: Dictionary = CaseEval.neutral_listener(view)
	listener["id"] = "a"
	listener["knowledge"] = listener.get("knowledge", {}).duplicate(true)
	listener.knowledge["self"] = "a"
	listener.knowledge["good"] = ["a"]
	var c = Solver.empty_case()
	c.conclusion = {"type": "evil", "target": target, "at": view.alignment_epoch}
	c.cards = cards.map(func(x): return x.id)
	return float(CaseEval.evaluate(view, c, listener).get("posterior", -1.0))

func _init() -> void:
	var base: float = _p([_claim(), _toll(2)], "s")
	var on_toll: float = _p([_claim(), _toll(2), _seen("s2", 2, "docks")], "s")
	var off_toll: float = _p([_claim(), _toll(2), _seen("s1", 1, "docks")], "s")
	print("Sexton s, tolled on night 2: %.3f evil; seen on the Docks on night 2: %.3f; on night 1: %.3f" % [base, on_toll, off_toll])
	# It can even bear the toll out: a good Sexton is surely out that night, a lying one less often.
	check(on_toll <= base + 0.005, "a sighting of the Sexton out on its toll night doesn't count against it (%.3f against %.3f)" % [on_toll, base])
	check(off_toll > on_toll + 0.02, "the same sighting on a night it didn't toll does (%.3f against %.3f)" % [off_toll, on_toll])
	# The two kernels agree on the Sexton's column.
	var cards: Array = [_claim(), _toll(2), _seen("s2", 2, "docks")]
	var view: Dictionary = _view(cards)
	var s: Dictionary = view.people[1]
	for align in ["good", "minion"]:
		var cs: float = Activity._likelihood(view, cards, s, align)
		var gd: float = Activity._likelihood_gd(view, cards, s, align)
		check(absf(cs - gd) <= 1e-9 * maxf(1.0, absf(gd)), "C# and GDScript agree on the Sexton's walk (%s: %s against %s)" % [align, cs, gd])
	# The movement caches key on the toll report: the same sightings with and without it are
	# different inputs, so the order they're judged in doesn't matter (Codex on #562).
	Caches.clear_all()
	var warm_off: float = _p([_claim(), _seen("s2", 2, "docks")], "s", false)
	var warm_on: float = _p([_claim(), _toll(2), _seen("s2", 2, "docks")], "s", false)
	var cold_off: float = _p([_claim(), _seen("s2", 2, "docks")], "s")
	check(absf(warm_on - on_toll) < 1e-9, "with no toll judged first, the toll night still reads as a tour (%.3f against %.3f)" % [warm_on, on_toll])
	check(absf(_p([_claim(), _seen("s2", 2, "docks")], "s", false) - cold_off) < 1e-9 and absf(warm_off - cold_off) < 1e-9,
		"and the sighting without a toll is judged the same either way (%.3f against %.3f)" % [warm_off, cold_off])
	# The Sexton's own duty account ("I tolled the church bell and walked every parish"), a
	# sighting of itself, reads as its toll report for that night (Codex on #562).
	var duty_e: Dictionary = {"id": "duty", "fact_id": "duty", "kind": "sighting", "source": "s", "subjects": ["s"], "text": "",
		"observed_at": {"day": 2, "phase": "night"}, "content": {"block": "market", "duty_claim": true, "duty": "sexton"}}
	var duty: Dictionary = LiveAssessment.activity_card(duty_e, {"people": _view([]).people, "public_events": []})
	check(duty.get("kind", "") == "report" and duty.get("role", "") == "sexton" and int(duty.get("data", {}).get("night", -1)) == 2 and duty.get("duty_only", false),
		"a Sexton's duty account becomes a toll report for its night (%s)" % [duty])
	if duty.get("kind", "") == "report":
		duty["reported_at"] = {"day": 3, "phase": "afternoon"}
		var by_duty: float = _p([_claim(), duty, _seen("s2", 2, "docks")], "s")
		var duty_alone: float = _p([_claim(), duty], "s")
		check(by_duty <= duty_alone + 0.005, "a sighting on the night of the duty account doesn't count against it (%.3f against %.3f)" % [by_duty, duty_alone])
	# Seen on two blocks away from home on its toll night: only the walk of every block fits,
	# but that's the toll, not a sign of a hidden Lamplighter (Codex on #562).
	Caches.clear_all()
	var two: Array = [_claim(), _toll(2), _seen("s2", 2, "docks"), _seen("s3", 2, "hill", "d")]
	var rt: Dictionary = Activity.routes(_view(two), two)
	check(bool(rt.get("okay", false)) and rt.get("forced_lamp", []).is_empty(), "seen on two far blocks on its toll night, the Sexton is no inferred Lamplighter (%s)" % [rt.get("forced_lamp", [])])
	# A good Unrequited Sexton tolls first and doesn't visit that night (world_night.gd,
	# Burdens.unrequited_visit), so a sighting far from any beloved's way bears the toll out
	# in its holder column too (Codex on #562). The kernels agree.
	var holder_ratio = func(seen: Array) -> float:
		Caches.clear_all()
		var with_c: Array = [_claim(), _toll(2)] + seen
		var base_c: Array = [_claim(), _toll(2)]
		var vw: Dictionary = _view(with_c, true)
		var vb: Dictionary = _view(base_c, true)
		return Activity.unrequited_likelihood(vw, with_c, vw.people[1]) / Activity.unrequited_likelihood(vb, base_c, vb.people[1])
	var un_toll: float = holder_ratio.call([_seen("s3", 2, "hill", "d")])
	var un_off: float = holder_ratio.call([_seen("s3", 1, "hill", "d")])
	print("Unrequited Sexton, seen on the Hill: on its toll night x%.3f, on night 1 x%.3f" % [un_toll, un_off])
	check(un_toll > 0.9 and un_toll > un_off + 0.05, "an Unrequited Sexton seen on the Hill on its toll night isn't held to a visit (x%.3f against x%.3f)" % [un_toll, un_off])
	var uc: Array = [_claim(), _toll(2), _seen("s3", 2, "hill", "d"), _seen("s4", 1, "docks")]
	var uv: Dictionary = _view(uc, true)
	var u_cs: float = Activity.unrequited_likelihood(uv, uc, uv.people[1])
	var u_gd: float = Activity._unrequited_likelihood_gd(uv, uc, uv.people[1])
	check(absf(u_cs - u_gd) <= 1e-9 * maxf(1.0, absf(u_gd)), "C# and GDScript agree on the Unrequited Sexton's column (%s against %s)" % [u_cs, u_gd])
	print("Sexton toll tour: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
