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
	_live()
	_menu()
	print("Demon when hanged: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## On a real game's live universe, with a hanging written into the public timeline: the
## judge's mask agrees with Solver.holds in every world, and holds in more worlds than the
## plain "X is the world's Demon" (the succession worlds).
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


## What the Workshop offers for a hanged person (Michael, Nov 19): "was the Demon when
## hanged" only where a Scion is possible, never the negative; the living keep both.
func _menu() -> void:
	var with_scion = CanvasModel.new(_view(["scion", "poisoner"]))
	var no_scion = CanvasModel.new(_view(["poisoner"]))
	check(with_scion.premise_offered("demon", "g") and not with_scion.premise_offered("notdemon", "g"), "a hanged person: \"was the Demon\" is offered with a Scion on the script, \"is not the Demon\" never")
	check(not no_scion.premise_offered("demon", "g") and not no_scion.premise_offered("notdemon", "g"), "with no Scion on the script, no Demon premise is offered on a hanged person")
	check(with_scion.premise_offered("demon", "a") and with_scion.premise_offered("notdemon", "a") and no_scion.premise_offered("demon", "a"), "the living keep both Demon premises")
	check(with_scion.premise_text("demon", "g") == CanvasModel.HANGED_DEMON_TEXT and with_scion.premise_text("demon", "a") == CanvasModel.PREMISE_TEXT.demon, "a hanged person's premise reads in the past tense; the living's doesn't")
