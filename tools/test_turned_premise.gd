## "X was turned by the curse" (BACKLOG "Time-scoped Revenant possession premise", [decided]).
## The Revenant's curse already has its own time in the judge: the turned soul is evil only
## while it holds (workshop/chronology.gd). "X is evil during the curse" also holds where X was
## evil all along, so it casts doubt on X's whole history. This premise names the turning
## itself: good before, evil only during, good again after. It never exposes who was turned:
## it's a hypothesis weighed over the worlds, like any premise.
##   godot --headless --path . --script res://tools/test_turned_premise.gd
extends SceneTree

const Eval = preload("res://workshop/case_eval.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const History = preload("res://workshop/live_history.gd")
const Solver = preload("res://workshop/solver.gd")
const Assess = preload("res://workshop/live_assessment.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


## Seven people; g (the Revenant) is hanged on day 2 with a, b and c voting yes, and its
## curse fires. c died the night before, so a and b are the souls it could turn.
func _view(lifted: bool) -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square", "alive": id != "g"})
	var events = [
		{"kind": "demon_death", "subjects": ["c"], "at": {"day": 1, "phase": "night"}},
		{"kind": "vote", "subjects": ["g"], "at": {"day": 2, "phase": "evening"}, "data": {"nominee": "g", "yes": ["a", "b", "c"], "outcome": "on_block"}},
		{"kind": "execution", "subjects": ["g"], "at": {"day": 2, "phase": "evening"}},
		{"kind": "curse", "subjects": ["g"], "by": "g", "at": {"day": 2, "phase": "evening"}}]
	if lifted:
		events.append({"kind": "curse_lifted", "subjects": ["town"], "at": {"day": 4, "phase": "afternoon"}})
	var now = {"day": 5 if lifted else 3, "phase": "morning"}
	var history = History.chronology(events, people, now)
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Current alignment",
		"world_options": {"modifiers": ["marked"], "roles": true, "identities": true},
		"chronology": history.value, "timeline": History.from_events(events)}


func _init() -> void:
	var view: Dictionary = _view(true)
	var worlds: Array = Solver.universe(view)
	check(not worlds.is_empty() and view.chronology.has("curse"), "a public curse gives a timed universe (%d worlds)" % worlds.size())
	var turned_a: Dictionary = {"type": "turned", "target": "a", "at": "Current alignment"}
	var mask: PackedByteArray = Eval._premise_mask(view, turned_a)
	var agree: bool = mask.size() == worlds.size()
	var n_turned := 0
	var history_kept := true
	var evil_now_not_turned := 0
	for i in range(worlds.size()):
		var w: Dictionary = worlds[i]
		agree = agree and (mask[i] == 1) == Solver.holds(view, w, turned_a)
		if mask[i] == 1:
			n_turned += 1
			# Turned: good before the curse and after it, evil only while it held.
			history_kept = history_kept and not TimeModel.evil_at(view, w, "a", "Original alignment") \
				and TimeModel.evil_at(view, w, "a", "during curse") and not TimeModel.evil_at(view, w, "a", "after restoration")
		elif TimeModel.evil_at(view, w, "a", "during curse"):
			evil_now_not_turned += 1
	check(agree, "the judge's premise mask and the solver's holds agree in every world")
	check(n_turned > 0 and history_kept, "in every world where a was turned, a is good before the curse, evil during it and good after (%d worlds)" % n_turned)
	check(evil_now_not_turned > 0, "\"evil during the curse\" also holds where a was evil all along; \"turned\" doesn't (%d such worlds)" % evil_now_not_turned)
	var b_mask: PackedByteArray = Eval._premise_mask(view, {"type": "turned", "target": "b", "at": "Current alignment"})
	var both := 0
	var neither := 0
	for i in range(worlds.size()):
		both += 1 if mask[i] == 1 and b_mask[i] == 1 else 0
		neither += 1 if mask[i] == 0 and b_mask[i] == 0 else 0
	check(both == 0 and neither == 0, "the curse turns exactly one of its eligible souls in every world")
	# As a case: a prior between nothing and certainty, with no evidence.
	var value: Dictionary = Solver.empty_case()
	value.conclusion = turned_a
	var ev: Dictionary = Eval.evaluate(view, value, Eval.neutral_listener(view))
	print("turned a: prior %.3f posterior %.3f" % [float(ev.get("prior", -1)), float(ev.get("posterior", -1))])
	check(not ev.get("impossible", false) and float(ev.prior) > 0.05 and float(ev.prior) < 0.95, "\"a was turned\" is a real question before any evidence (%.3f)" % float(ev.prior))
	# The Workshop refuses it where it can't apply.
	var no_curse: Dictionary = view.duplicate(true)
	no_curse.erase("chronology")
	var c_val: Dictionary = Solver.empty_case()
	c_val.conclusion = {"type": "turned", "target": "a", "at": "Current alignment"}
	check(not Assess.conclusion_issues(no_curse, c_val).is_empty(), "with no curse announced, the premise is refused")
	c_val.conclusion.target = "d"
	check(not Assess.conclusion_issues(view, c_val).is_empty(), "someone who didn't vote to hang the Revenant can't have been turned")
	c_val.conclusion.target = "g"
	check(not Assess.conclusion_issues(view, c_val).is_empty(), "the hanged Revenant itself can't have been turned")
	c_val.conclusion.target = "a"
	check(Assess.conclusion_issues(view, c_val).is_empty(), "a surviving yes-voter can be argued turned")
	check("turned" in Assess.CONCLUSIONS, "the live Workshop accepts the premise type")
	# A filed case's card and the listeners' memories name the claim (Codex on #301).
	var Game = preload("res://game/game.gd")
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(1, 7)
	var who = g.w.npcs[0]
	check(g.Deduction.conclusion_text(g.w, {"type": "turned", "a": who.id}) == "%s was turned by the curse" % who.name, "a filed turned case reads with the person's name")
	check(g.Deduction.conclusion_text(g.w, {"type": "demon", "a": who.id}) == "%s is the demon" % who.name, "the living keep \"is the demon\"")
	who.alive = false
	who.death_cause = "executed"
	check(g.Deduction.conclusion_text(g.w, {"type": "demon", "a": who.id}) == "%s was the Demon when hanged" % who.name, "a hanged person's filed Demon case reads as the canvas does")
	print("Turned premise: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
