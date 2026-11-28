## Playtest 52102 fixes in the game's screens (Coroner, Nov 27): the daily guess window's picks
## are the player's verdict in the case summary and the theory line, and 'grimoire lies' dates
## a reading by the night it reads, not the night it was logged. (The townsfolk list's freeze is
## checked in test_control_flow.)
##   godot --headless --path . --script res://tools/test_playtest_52102.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const GameScreens = preload("res://game/game_screens.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
const DailyGuess = preload("res://ui/daily_guess.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _case():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 10)
	return g

func _run() -> void:
	_window_verdict()
	_lie_nights()
	_guess_source()
	_text_gaps()
	_approved_wording()
	print("Playtest 52102: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _window_verdict() -> void:
	var g = _case()
	var w = g.w
	var demon: String = w.demon_id
	var minions: Array = w.minion_ids.duplicate()
	check(GameScreens.effective_guesses(g) == g.guesses, "with nothing locked in the window, the profile's guesses stand")
	# Lock the true evil team in the window, the Demon untyped and the Minions untyped.
	var picks: Array = [{"id": demon, "type": ""}]
	for m in minions:
		picks.append({"id": m, "type": ""})
	check(DailyGuess.apply(g, picks), "the window locks its picks")
	check(g.guesses.is_empty() or CaseMetrics.demon_guesses(g.guesses).is_empty(), "and still never writes to the profile")
	var eff: Dictionary = GameScreens.effective_guesses(g)
	check(CaseMetrics.demon_guesses(eff) == [demon], "an untyped Demon pick counts as the Demon guess")
	var sorted_minions: Array = minions.duplicate()
	sorted_minions.sort()
	check(CaseMetrics.minion_guesses(eff) == sorted_minions, "untyped Minion picks count as Minion guesses")
	var snap: Dictionary = GameScreens.capture_prediction(g, "before_execution", {})
	var summary: Dictionary = CaseMetrics.summarize(w, snap, false, g.board, g.prediction_snapshots)
	check(summary["demon_identified"] and summary["minion_identified"], "so the summary credits the window's verdict (it read 'not recorded' in 52102)")
	var line: String = GameScreens.theory_status(g)
	check(w.by_id[demon].name in line and not "Demon: not recorded" in line, "the theory line shows the window's Demon (%s)" % line)
	check(minions.all(func(m): return ("%s (Minion)" % w.by_id[m].name) in line), "and an untyped Minion as plain Minion, not a guessed type")
	# Codex on #571: a confirmed window with every circle cleared is an empty verdict; the
	# profile's guesses don't come back.
	g.set_guess(demon, "demon", 3)
	var empty: Array = picks.map(func(p): return {"id": "", "type": ""})
	DailyGuess.apply(g, empty)
	var cleared: Dictionary = GameScreens.effective_guesses(g)
	check(CaseMetrics.demon_guesses(cleared).is_empty() and CaseMetrics.minion_guesses(cleared).is_empty(), "a window confirmed with every circle cleared is an empty verdict, even with profile guesses")
	check("Demon: not recorded" in GameScreens.theory_status(g), "and the theory line says so")

func _lie_nights() -> void:
	var g = _case()
	var w = g.w
	var liar = w.npcs[0]
	w.day = 2
	w.set_log_time()
	w.dlog.add("fake_info", liar.id, "", {"day": 1, "role": "clerk", "text": "One of two is the Lamplighter.", "why": "evil fabrication"}, "held back and told on night 2")
	var out: String = GameScreens._lies(g)
	var row: String = Array(out.split("\n")).filter(func(l): return "One of two is the Lamplighter" in l)[0] if "One of two is the Lamplighter" in out else ""
	check(row.strip_edges().begins_with("N1"), "a night-1 fabrication told on night 2 reads N1 (%s)" % row.strip_edges())
	w.dlog.add("fake_info", liar.id, "", {"day": 2, "phase": C.AFTERNOON, "role": "clerk", "text": "A day reading.", "why": "evil fabrication"}, "a day-phase bluff")
	out = GameScreens._lies(g)
	check(Array(out.split("\n")).any(func(l): return "A day reading" in l and l.strip_edges().begins_with("D2")), "a day-phase reading reads by its day")

func _guess_source() -> void:
	var g = _case()
	var a = g.w.npcs[0]
	var b = g.w.npcs[1]
	g.set_guess(a.id, "demon", 2, "profile_menu")
	check(str(g.guess_history[-1].get("source", "")) == "profile_menu", "a guess set from the profile's menu logs where it came from (52102, seq 558)")
	g.command("guess %s demon" % b.name.to_lower())
	check(g.guess_history[-1].get("who", "") == b.id and not g.guess_history[-1].has("source"), "a typed guess carries no source, as before")

func _text_gaps() -> void:
	var g = _case()
	var n = g.w.npcs[2]
	n.silenced = true
	var opts: String = preload("res://game/game_conversation.gd")._talk_options(g, n)
	check(not "ask" in opts and "present" in opts and "bye" in opts, "a silenced person isn't offered questions (seq 747): %s" % opts)
	n.silenced = false
	check("ask gift" in preload("res://game/game_conversation.gd")._talk_options(g, n), "anyone else still is")
	var out: String = g.command("guess %s minion" % g.w.npcs[3].name.to_lower())
	check("Name the Minion's gift" in out, "a generic Minion guess says how to name one (seq 556)")

## Michael, Nov 27: the nine 52102 wording drafts, approved as written.
func _approved_wording() -> void:
	var g = _case()
	var n = g.w.npcs[4]
	n.claim_public = true
	var opts: String = preload("res://game/game_conversation.gd")._talk_options(g, n)
	check("ask gift (their readings)" in opts, "(d) after a claim, the gift question says it's about their readings")
	g.w.day = 1
	check("ask seen today" in preload("res://game/game_conversation.gd")._talk_options(g, n) and not "yesterday" in preload("res://game/game_conversation.gd")._talk_options(g, n), "(e) on the first day only 'ask seen today'")
	g.w.day = 2
	check("ask seen yesterday [morning|afternoon|evening]" in preload("res://game/game_conversation.gd")._talk_options(g, n), "(e) later, yesterday with its phase")
	check(C.ROLES["demon"]["desc"] == "Kills one person each night (not the night before you arrived), walking to their block to do it.", "(h, i) the Demon's description")
	check(["confessor", "monitor", "psychologist"].all(func(r): return C.ROLES[r]["desc"].begins_with("Each night (not the night before you arrived),")), "(h) the other three night gifts")
	var src: String = FileAccess.get_file_as_string("res://game/game_meeting.gd") + FileAccess.get_file_as_string("res://game/game_day_night.gd") + FileAccess.get_file_as_string("res://game/game_conversation.gd")
	for line in [", or 'clemency' to spare them", "No one rises to speak for or against %s.", "You promised %s a vigil on %s tonight.",
			"(you may still move once within %s: 'go <place>')", "e.g. 'go town hall', or a crime scene by the victim's name"]:
		check(line in src, "the approved line is in place: %s" % line)
