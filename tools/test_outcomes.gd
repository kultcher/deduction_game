## Regression checks for private theories, pre-outcome freezing and balance metrics.
## godot --headless --path . --script res://tools/test_outcomes.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Metrics = preload("res://game/case_metrics.gd")
var fails = 0

func fresh():
	var g = Game.new()
	g.log_dir = "user://test_outcome_logs"
	g.new_case(4242)
	return g

func finish_by_execution(g, id: String, yes: bool = true) -> String:
	g.state = "meeting"
	g.w.begin_meeting()
	g.w.meeting["block"] = id
	g.w.meeting["results"] = [{"nominee": id, "by": "player", "yes": [], "player_yes": yes}]
	g.town_quiet = true
	return g.command("done")

func _init() -> void:
	var g = fresh()
	var d: String = g.w.demon_id
	var m: String = g.w.minion_id
	var innocent = g.w.living_good()[0]
	g.set_note(d, "The night report conflicts with their account.")
	g.set_guess(innocent.id, "demon", 1)
	g.set_guess(d, "demon", 3)
	g.set_guess(m, "poisoner", 2)
	_check(Metrics.named_guesses(g.guesses, "demon") == [d], "a new demon guess replaces the previous candidate")
	_check(g.guess_history.size() == 3 and g.guess_history[0]["guesses"][innocent.id]["guess"] == "demon", "revisions retain earlier theories")
	g.set_guess(m, "poisoner", 2)
	_check(g.guess_history.size() == 3, "saving unchanged guesses is not a revision")
	var rng_state = g.w.rng.state
	var snap = g.capture_prediction("test")
	g.set_note(d, "Revised note")
	_check(snap["notes"][d] != g.notes[d] and g.w.rng.state == rng_state, "snapshots are immutable and consume no simulation randomness")
	_check(not "identified: correct" in g.command("theory"), "theory display provides no correctness feedback")
	var ending = finish_by_execution(g, d)
	_check(g.case_summary["both_identified"] and g.case_summary["town_saved"], "correct pre-execution identities and town survival are separate successes")
	_check("Demon identified: correct" in ending and "Minion identified: correct" in ending, "ending reports identification after resolution")
	var frozen = g.case_summary.duplicate(true)
	_check(not g.set_guess(innocent.id, "demon", 3) and g.case_summary == frozen, "post-reveal edits cannot change the scored theory")
	var types: Array = g.w.dlog.entries.map(func(e): return e["type"])
	_check(types.find("prediction_snapshot") < types.find("execution") and types.find("execution") < types.find("case_summary"), "prediction snapshots precede execution and final scoring")
	_check(g.case_summary["prediction"]["reason"] == "before_execution", "the latest pre-outcome snapshot is scored")
	var summary_events = g.w.dlog.entries.filter(func(e): return e["type"] == "case_summary")
	_check(summary_events.size() == 1, "one machine-readable case summary is logged")
	var log = FileAccess.get_file_as_string(g.log_paths[0])
	_check('"type":"case_summary"' in log or '"type": "case_summary"' in log, "automatic end-of-case log contains summary")
	g = fresh()
	finish_by_execution(g, g.w.demon_id)
	_check(g.case_summary["town_saved"] and not g.case_summary["demon_identified"] and g.case_summary["demon_guesses"].is_empty(), "winning without a theory earns no identification credit")
	g = fresh()
	g.set_guess(g.w.demon_id, "demon", 2)
	g.capture_prediction("before_night")
	g.w._finish("evil", "test loss")
	g.command("look")
	_check(g.case_summary["identified_but_lost"] and not g.case_summary["minion_identified"], "correct demon but no minion and a lost town receives distinct credit")
	g = fresh()
	g.debug = true
	g.set_guess(g.w.demon_id, "demon", 3)
	g.command("grimoire")
	finish_by_execution(g, g.w.demon_id)
	_check(g.case_summary["prediction_spoiled"] and not g.case_summary["demon_identified"], "opening the debug grimoire excludes identification credit")
	g = fresh()
	g.state = "meeting"
	g.w.begin_meeting()
	g.w.open_nomination("player", g.w.living_good()[0].id)
	g.state = "nomination"
	g.command("vote no")
	_check(g.prediction_snapshots[-1]["reason"] == "before_vote", "votes freeze a theory even when no guess is recorded")
	g._resolve_night()
	_check(g.prediction_snapshots[-1]["reason"] == "before_night", "night resolution freezes a theory")
	g = fresh()
	var goods = g.w.living_good()
	for i in range(3):
		g.w.executions.append({"day": i+1, "id": goods[i].id, "nominator": "player" if i == 0 else g.w.demon_id,
			"player_nominated": i == 0, "player_yes": i == 0})
	g.w.dlog.set_time(3, "Evening")
	g.w.dlog.add("player_statement", "player", goods[2].id, {"statement": "accuse"})
	var result = Metrics.summarize(g.w, g.capture_prediction("test"), false)
	_check(result["executions_good"] == 3 and result["wrongful_backed"] == 1 and result["wrongful_opposed"] == 1 and result["wrongful_mixed"] == 1,
		"execution attribution distinguishes backed, opposed and mixed actions")
	g.w.executions = []
	result = Metrics.summarize(g.w, {}, false)
	_check(result["wrongful_execution_fraction"] == null, "no executions has an undefined fraction, not a misleading zero")
	var total = Metrics.aggregate([result])
	_check(total["incomplete"] == 1 and total["win_rate"] == null, "incomplete cases are excluded from outcome rates")
	g.set_guess(g.w.demon_id, "demon", 2)
	g.new_case(4242)
	_check(g.guesses.is_empty() and g.guess_history.is_empty() and g.prediction_snapshots.is_empty() and g.case_summary.is_empty(), "reusing Game starts a clean theory history")
	print("FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1
