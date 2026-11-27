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

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## A hand-built town: the listener "a"; the Sexton "s" on the Market, who says it tolled on
## night 2; "t" says it saw "s" on the Docks.
func _view(cards: Array) -> Dictionary:
	var people: Array = []
	var homes: Dictionary = {"a": "hill", "s": "market", "t": "square", "c": "market", "d": "square", "e": "docks", "f": "docks"}
	for id in ["a", "s", "t", "c", "d", "e", "f"]:
		people.append({"id": id, "name": id, "home": homes[id], "alive": true})
	return {"people": people, "cards": cards, "evil_count": 2, "day": 3, "alignment_epoch": "Original alignment", "live_activity": true,
		"world_options": {"roles": true, "identities": true, "modifiers": ["delusional", "marked"]}}

func _claim() -> Dictionary:
	return {"id": "c_s", "fact_id": "c_s", "kind": "claim", "source": "s", "subject": ["s"], "role": "sexton",
		"observed_at": {"day": 1, "phase": "afternoon"}, "reported_at": {"day": 1, "phase": "afternoon"}}

func _toll(night: int) -> Dictionary:
	return {"id": "toll", "fact_id": "toll", "kind": "report", "source": "s", "role": "sexton", "night": night, "data": {"night": night},
		"observed_at": {"day": night, "phase": "night"}, "reported_at": {"day": night + 1, "phase": "afternoon"}}

func _seen(id: String, night: int, block: String) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "sighting", "source": "t", "subject": "s", "subjects": ["s"], "night": night, "block": block,
		"data": {}, "role": "", "observed_at": {"day": night, "phase": "night"}, "reported_at": {"day": night + 1, "phase": "morning"}}

func _p(cards: Array, target: String) -> float:
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
	print("Sexton toll tour: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
