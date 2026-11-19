## "X is the Demon" about someone already hanged means "X was the Demon when hanged"
## (Michael, Nov 19): the world's Demon is the Demon now, so a hanged Demon whose Scion rose
## sits in that world as an evil non-Demon (the succession the movement model and the role
## constraints already read). The premise holds in both kinds of world; "is not the Demon"
## is its complement. A person not hanged keeps the plain question.
##   godot --headless --path . --script res://tools/test_demon_when_hanged.gd
extends SceneTree

const Solver = preload("res://workshop/solver.gd")
const Eval = preload("res://workshop/case_eval.gd")
const History = preload("res://workshop/live_history.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Support = preload("res://workshop/support_model.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


## Seven people; g is hanged on day 2 with six alive; c died to the Demon on night 1, e on
## night 2 (after the hanging).
func _view(minions: Array) -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square", "alive": id not in ["c", "e", "g"]})
	var events = [
		{"kind": "demon_death", "subjects": ["c"], "at": {"day": 1, "phase": "night"}},
		{"kind": "execution", "subjects": ["g"], "at": {"day": 2, "phase": "evening"}},
		{"kind": "demon_death", "subjects": ["e"], "at": {"day": 2, "phase": "night"}}]
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Current alignment",
		"script_minions": minions, "timeline": History.from_events(events)}


func _init() -> void:
	var view: Dictionary = _view(["scion", "poisoner"])
	var g_i: int = Solver.person_index(view, "g")
	var a_i: int = Solver.person_index(view, "a")
	var demon_g: Dictionary = {"evil": (1 << g_i) | (1 << a_i), "demon": g_i}
	var rose: Dictionary = {"evil": (1 << g_i) | (1 << a_i), "demon": a_i}
	var minion_g: Dictionary = {"evil": (1 << g_i) | (1 << a_i), "demon": a_i}
	var good_g: Dictionary = {"evil": (1 << a_i) | (1 << Solver.person_index(view, "b")), "demon": a_i}
	check(Solver.hanged_demon(view, demon_g, "g") == 1, "a hanged person who is the world's Demon was the Demon when hanged")
	check(Solver.hanged_demon(view, rose, "g") == 1, "a hanged evil person whose world's Demon was alive at the hanging, with six alive and a Scion on the script: the Scion rose, so they were the Demon")
	check(Solver.hanged_demon(view, good_g, "g") == 0, "a hanged good person was not the Demon")
	check(Solver.hanged_demon(view, rose, "a") == -1, "someone not hanged keeps the plain question")
	var no_scion: Dictionary = _view(["poisoner"])
	check(Solver.hanged_demon(no_scion, minion_g, "g") == 0, "with no Scion on the script, a hanged evil non-Demon was only a Minion")
	check(Solver.holds(view, rose, {"type": "demon", "target": "g", "at": ""}) and not Solver.holds(view, rose, {"type": "notdemon", "target": "g", "at": ""}),
		"\"is the Demon\" holds and \"is not the Demon\" doesn't, in the succession world")
	check(Solver.holds(view, rose, {"type": "demon", "target": "a", "at": ""}), "the risen Scion is the Demon now (the plain question)")
	# Five alive at the hanging is the floor (the Scion's rule): with four, no succession.
	var small: Dictionary = _view(["scion"])
	small.people = small.people.slice(0, 5)
	small.timeline = History.from_events([
		{"kind": "demon_death", "subjects": ["c"], "at": {"day": 1, "phase": "night"}},
		{"kind": "execution", "subjects": ["e"], "at": {"day": 2, "phase": "evening"}}])
	var e_i: int = Solver.person_index(small, "e")
	var rose_small: Dictionary = {"evil": (1 << e_i) | (1 << a_i), "demon": a_i}
	check(Solver.hanged_demon(small, rose_small, "e") == 0, "with four alive at the hanging the Scion can't rise, so a hanged Minion was only a Minion")
	_refuted()
	_live()
	_menu()
	_refusals()
	_support(rose, demon_g, good_g)
	print("Demon when hanged: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## On a real game's live universe, with a hanging written into the public timeline: the
## judge's mask agrees with Solver.holds in every world, and holds in more worlds than the
## plain "X is the world's Demon" (the succession worlds).
## A reading that names the hanged person's role as a non-Demon (a Gravedigger's of the hanging,
## an Executor's of its target; Michael, Nov 19) refutes "was the Demon when hanged" in every
## world where its teller (and any relayer) is good. Where the teller is evil it can still hold.
func _refuted() -> void:
	var view: Dictionary = _view(["scion", "poisoner"])
	var i: Callable = func(id): return 1 << Solver.person_index(view, id)
	var gd: Dictionary = {"id": "gd1", "kind": "report", "role": "gravedigger", "source": "b", "data": {"executed": "g", "role": "poisoner"}}
	var ctx: Dictionary = Solver.hanged_context(view, "g", [gd])
	var rose_b_good: Dictionary = {"evil": i.call("g") | i.call("a"), "demon": Solver.person_index(view, "a")}
	var rose_b_evil: Dictionary = {"evil": i.call("g") | i.call("a") | i.call("b"), "demon": Solver.person_index(view, "a")}
	var demon_g: Dictionary = {"evil": i.call("g") | i.call("a"), "demon": Solver.person_index(view, "g")}
	check(Solver.hanged_demon_in(rose_b_good, ctx) == 0, "a good Gravedigger's \"g was the Poisoner\" refutes \"was the Demon when hanged\"")
	check(Solver.hanged_demon_in(rose_b_evil, ctx) == 1, "from an evil Gravedigger it doesn't")
	check(Solver.hanged_demon_in(demon_g, ctx) == 1, "where g is still the world's Demon, it holds")
	check(Solver.hanged_demon_in(rose_b_good, Solver.hanged_context(view, "g", [])) == 1, "without the reading, the Scion's succession holds as before")
	var relayed: Dictionary = {"id": "gd2", "kind": "report", "role": "gravedigger", "source": "b", "relay_source": "d", "data": {"executed": "g", "role": "poisoner"}}
	var rctx: Dictionary = Solver.hanged_context(view, "g", [relayed])
	check(Solver.hanged_demon_in(rose_b_good, rctx) == 0 and Solver.hanged_demon_in({"evil": i.call("g") | i.call("a") | i.call("d"), "demon": Solver.person_index(view, "a")}, rctx) == 1,
		"a relayed reading refutes it only where both the reader and the Medium are good")
	var ex: Dictionary = {"id": "ex1", "kind": "report", "role": "executor", "source": "b", "data": {"target": "g", "role": "poisoner"}}
	check(Solver.hanged_demon_in(rose_b_good, Solver.hanged_context(view, "g", [ex])) == 0, "an Executor's reading of its target refutes it too")
	var names_demon: Dictionary = {"id": "gd3", "kind": "report", "role": "gravedigger", "source": "b", "data": {"executed": "g", "role": "demon"}}
	var quoted: Dictionary = {"id": "gd4", "kind": "report", "role": "gravedigger", "source": "b", "quoted": true, "data": {"executed": "g", "role": "poisoner"}}
	var own: Dictionary = {"id": "gd5", "kind": "report", "role": "gravedigger", "source": "g", "data": {"executed": "g", "role": "poisoner"}}
	check(Solver.hanged_refuters(view, [names_demon, quoted, own], "g").is_empty(), "a reading naming a Demon, a quoted one and the hanged person's own don't refute it")
	check(Solver.hanged_refuters(_view(["poisoner"]), [gd], "g") == [[Solver.person_index(view, "b"), -1]] and Solver.hanged_context(_view(["poisoner"]), "g", [gd]).refuters.is_empty(),
		"with no Scion on the script there is no succession to refute")


func _live() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(4460, 10)
	g.w.day = 3
	var view: Dictionary = Live.view(g)
	var x: String = view.people[0].id
	view["script_minions"] = ["scion", "poisoner"]
	# The judge's own views carry identities, so live worlds name the Demon (WorldDomain).
	view.world_options["identities"] = true
	view["timeline"] = History.from_events([{"kind": "execution", "subjects": [x], "at": {"day": 2, "phase": "evening"}}])
	var worlds: Array = Solver.universe(view)
	var q: Dictionary = {"type": "demon", "target": x, "at": view.alignment_epoch}
	var mask: PackedByteArray = Eval._premise_mask(view, q)
	var agree: bool = mask.size() == worlds.size() and worlds.size() > 0
	var held := 0
	var plain := 0
	var x_i: int = Solver.person_index(view, x)
	for i in range(worlds.size()):
		agree = agree and (mask[i] == 1) == Solver.holds(view, worlds[i], q)
		held += int(mask[i])
		plain += 1 if int(worlds[i].get("demon", -1)) == x_i else 0
	print("live: %d worlds, %d plain, %d when hanged" % [worlds.size(), plain, held])
	check(agree, "the judge's mask and the solver agree in every live world")
	check(held > plain and plain > 0, "\"was the Demon when hanged\" holds in the plain worlds and the succession worlds too (%d > %d)" % [held, plain])
	# A good-in-some-worlds Gravedigger's "x was the Poisoner" in the case: the premise mask follows
	# the case's own cards (its cache key carries them), and holds in fewer worlds.
	var teller: String = view.people[1].id
	var gd: Dictionary = {"id": "gd-live", "kind": "report", "role": "gravedigger", "source": teller, "data": {"executed": x, "role": "poisoner"}}
	var with_gd: PackedByteArray = Eval._premise_mask(view, q, [gd])
	var held_with := 0
	for i in range(with_gd.size()):
		held_with += int(with_gd[i])
	check(with_gd.size() == worlds.size() and held_with < held and held_with >= plain,
		"with a Gravedigger's reading of a Minion role in the case, it holds in fewer worlds (%d against %d; %d plain)" % [held_with, held, plain])
	check(Eval._premise_mask(view, q, []) == mask, "and the mask without it is unchanged, cached or not")


## What the Workshop offers for a hanged person (Michael, Nov 19): "was the Demon when
## hanged" only where a Scion is possible, never the negative; the living keep both.
func _menu() -> void:
	var with_scion = CanvasModel.new(_view(["scion", "poisoner"]))
	var no_scion = CanvasModel.new(_view(["poisoner"]))
	check(with_scion.premise_offered("demon", "g") and not with_scion.premise_offered("notdemon", "g"), "a hanged person: \"was the Demon\" is offered with a Scion on the script, \"is not the Demon\" never")
	check(not no_scion.premise_offered("demon", "g") and not no_scion.premise_offered("notdemon", "g"), "with no Scion on the script, no Demon premise is offered on a hanged person")
	check(with_scion.premise_offered("demon", "a") and with_scion.premise_offered("notdemon", "a") and no_scion.premise_offered("demon", "a"), "the living keep both Demon premises")
	check(with_scion.premise_text("demon", "g") == CanvasModel.HANGED_DEMON_TEXT and with_scion.premise_text("demon", "a") == CanvasModel.PREMISE_TEXT.demon, "a hanged person's premise reads in the past tense; the living's doesn't")


## A saved case that already uses a premise the menu no longer offers is refused, not
## judged (Herald, Nov 19): the judge's issues name why. The living keep both forms.
func _refusals() -> void:
	var with_scion: Dictionary = _view(["scion", "poisoner"])
	var no_scion: Dictionary = _view(["poisoner"])
	var case_of = func(type, target): return {"conclusion": {"type": type, "target": target, "at": ""}, "cards": []}
	check(Assess.conclusion_issues(with_scion, case_of.call("notdemon", "g")) == [Assess.HANGED_NOT_DEMON_ISSUE], "a saved \"is not the Demon\" about a hanged person is refused")
	check(Assess.conclusion_issues(no_scion, case_of.call("demon", "g")) == [Assess.HANGED_NO_SCION_ISSUE], "a saved \"was the Demon\" about a hanged person with no Scion on the script is refused")
	check(Assess.conclusion_issues(with_scion, case_of.call("demon", "g")).is_empty(), "with a Scion on the script, \"was the Demon when hanged\" is judged")
	check(Assess.conclusion_issues(no_scion, case_of.call("demon", "a")).is_empty() and Assess.conclusion_issues(no_scion, case_of.call("notdemon", "a")).is_empty(), "the living keep both Demon premises")


## The legacy judge's comparison agrees with the solver (Codex on #305): a succession world
## supports "was the Demon when hanged" rather than counting as a rival.
func _support(rose: Dictionary, demon_g: Dictionary, good_g: Dictionary) -> void:
	var view: Dictionary = _view(["scion", "poisoner"])
	view["world_options"] = {"identities": true}
	var q: Dictionary = {"type": "demon", "target": "g", "at": ""}
	rose = rose.merged({"marked": -1})
	good_g = good_g.merged({"marked": -1})
	var TimeModel = preload("res://workshop/chronology.gd")
	var ranks: Dictionary = {TimeModel.key(view, rose): 1.0, TimeModel.key(view, good_g): 1.0}
	var only_rose: Dictionary = Support._comparison(view, [rose], q, [], ranks)
	check(float(only_rose.support) > 0.0 and float(only_rose.rival) == 0.0, "the legacy comparison counts a succession world as support, not a rival (%s)" % only_rose)
	var only_good: Dictionary = Support._comparison(view, [good_g], q, [], ranks)
	check(float(only_good.support) == 0.0 and float(only_good.rival) > 0.0, "a world where the hanged person was good is the rival")
