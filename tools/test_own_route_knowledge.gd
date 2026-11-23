## A listener knows where it walked on its own nights out (reading-note gap 2, Nov 21:
## everyone knows their own whereabouts). WorkshopBridge.own_home passes the blocks it walked
## (out_nights), the movement model reads them as a soft alibi of its own (FlagKnownRoute in
## C#), so a sighting of it on a block it never walked weighs against whoever told it, as a
## sighting of it on a night at home already did. C# and the GDScript mirror agree.
##   godot --headless --path . --script res://tools/test_own_route_knowledge.gd
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

## A hand-built town: the listener "a" lives on the Hill and walked to the Square on night 1;
## "t" (on the Market) says it saw "a" on the Docks that night.
func _view(cards: Array, own_out: Dictionary) -> Dictionary:
	var people: Array = []
	var homes: Dictionary = {"a": "hill", "t": "market", "c": "market", "d": "square", "e": "docks", "f": "square", "g": "docks"}
	for id in ["a", "t", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": homes[id], "alive": true})
	var view: Dictionary = {"people": people, "cards": cards, "evil_count": 2, "day": 3, "alignment_epoch": "Original alignment", "live_activity": true,
		"world_options": {"roles": true, "identities": true, "modifiers": ["delusional", "marked"]}}
	if not own_out.is_empty():
		view["own_home"] = {"self": "a", "block": "hill", "nights": {}, "out_nights": own_out}
	return view

func _seen(id: String, night: int, block: String) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "sighting", "source": "t", "subject": "a", "subjects": ["a"], "night": night, "block": block,
		"data": {}, "role": "", "observed_at": {"day": night, "phase": "night"}, "reported_at": {"day": night + 1, "phase": "morning"}}

func _p(cards: Array, own_out: Dictionary, target: String) -> float:
	Caches.clear_all()
	var view: Dictionary = _view(cards, own_out)
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
	var walked: Dictionary = {"1": ["hill", "square"]}
	var docks: Dictionary = _seen("s1", 1, "docks")
	var square: Dictionary = _seen("s2", 1, "square")
	var base_t: float = _p([], walked, "t")
	var off_route: float = _p([docks], walked, "t")
	var off_route_unknown: float = _p([docks], {}, "t")
	var on_route: float = _p([square], walked, "t")
	var on_route_unknown: float = _p([square], {}, "t")
	print("t says it saw a on the Docks; a walked to the Square: t %.3f -> %.3f evil (%.3f when a doesn't know its route); seen on the Square instead: %.3f (%.3f not knowing)" % [base_t, off_route, off_route_unknown, on_route, on_route_unknown])
	check(off_route > off_route_unknown + 0.05, "a sighting of the listener off the route it walked counts against its teller (%.3f against %.3f)" % [off_route, off_route_unknown])
	# (A true sighting still places its teller out on that block, which can raise them on its
	# own: compare with the listener not knowing its route.)
	check(on_route <= on_route_unknown + 0.02, "a true sighting on its route isn't held against its teller (%.3f against %.3f)" % [on_route, on_route_unknown])
	# The two kernels agree on the listener's own column.
	var view: Dictionary = _view([docks], walked)
	var cards: Array = [docks] + Activity.own_home_cards(view)
	var a: Dictionary = view.people[0]
	var cs: float = Activity._likelihood(view, cards, a, "good")
	var gd: float = Activity._likelihood_gd(view, cards, a, "good")
	check(absf(cs - gd) <= 1e-9 * maxf(1.0, absf(gd)), "C# and GDScript agree on the walk's likelihood (%s against %s)" % [cs, gd])
	print("Own route knowledge: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
