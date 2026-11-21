## The daily evil-team guess (ui/daily_guess.gd; Michael, Nov 21, grim_reveal.md "Corrections"):
## the circles follow the script's evil count, the Demon picker crosses out the Demon's victims,
## the window keeps its own locked guesses (the verdict), profile picks prefill empty circles
## greyed without being written back, and Confirm, Skip and "Don't ask again" behave.
##   godot --headless --path . --script res://tools/test_daily_guess.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const DailyGuess = preload("res://ui/daily_guess.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _game(size: int) -> Game:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.detailed_logging = false
	g.new_case(692, size)
	return g

func _init() -> void:
	# The circles: the Demon, then one per Minion in play.
	for size in [7, 10]:
		var g = _game(size)
		var ss: Array = DailyGuess.slots(g)
		check(ss.size() == 1 + g.w.minion_ids.size() and ss[0].role == "demon" and ss.slice(1).all(func(s): return s.role == "minion"),
			"%d-NPC town: a Demon circle and %d Minion circles (got %d)" % [size, g.w.minion_ids.size(), ss.size()])
		check(ss[0].types == g.w.case_script.demons and (ss.size() < 2 or ss[1].types == g.w.case_script.minions),
			"%d-NPC town: the type menus list the script's Demons and Minions" % size)

	var g = _game(10)
	var sc = g.w.case_script
	var ss: Array = DailyGuess.slots(g)
	var people: Array = g.w.npcs.map(func(n): return n.id)
	var demon_type: String = sc.demons[0]

	# Nothing locked or noted yet: every circle starts empty, the Demon's type given on a
	# single-Demon script.
	var picks: Array = DailyGuess.prefill(g)
	check(picks.all(func(p): return p.id == ""), "with nothing locked or noted, every circle starts empty")
	check(picks[0].type == (sc.demons[0] if sc.demons.size() == 1 else ""), "the Demon's type is prefilled only on a single-Demon script (got '%s')" % picks[0].type)

	# The Demon picker crosses out those the Demon killed; Minion pickers don't.
	var victim = g.w.living_good()[0]
	victim.alive = false
	victim.death_cause = "demon"
	check(not DailyGuess.pickable(g, "demon", victim.id), "the Demon picker crosses out someone the Demon killed")
	check(DailyGuess.pickable(g, "minion", victim.id), "a Minion picker leaves them selectable")
	victim.alive = true
	victim.death_cause = ""

	# The hybrid: profile picks prefill empty circles, greyed, and confirming locks them in.
	g.set_guess(people[0], demon_type, 3)
	g.set_guess(people[1], sc.minions[0], 2)
	var profile_before = g.guesses.duplicate(true)
	var pre: Array = DailyGuess.prefill(g)
	check(pre[0].id == people[0] and pre[0].from_profile, "a Demon pick in the profile prefills the Demon circle, greyed")
	check(pre[1].id == people[1] and pre[1].from_profile and pre[1].type == sc.minions[0], "a Minion pick in the profile prefills a Minion circle, greyed")
	check(DailyGuess.verdict(g)[people[0]] == "?", "a profile pick isn't the verdict until it's confirmed")
	DailyGuess.apply(g, pre)
	check(DailyGuess.verdict(g)[people[0]] == demon_type and DailyGuess.verdict(g)[people[1]] == sc.minions[0], "confirming locks the prefilled picks in as the verdict")
	check(not DailyGuess.prefill(g)[0].from_profile, "once locked, the circle isn't greyed")

	# The window never writes back to the profile.
	var picks2: Array = DailyGuess.prefill(g)
	picks2[0] = {"id": people[3], "type": demon_type}
	DailyGuess.apply(g, picks2)
	check(g.guesses == profile_before, "locking a new guess leaves the profile notes alone")
	check(DailyGuess.verdict(g)[people[3]] == demon_type and DailyGuess.verdict(g)[people[0]] == "?", "the verdict follows the latest lock")
	var lock: Dictionary = g.get_meta(DailyGuess.META_LOCKED)
	check(lock.history.size() == 2 and int(lock.history[-1].day) == g.w.day, "each confirm is kept as a dated entry")
	check(DailyGuess.prefill(g)[0].id == people[3] and not DailyGuess.prefill(g)[0].from_profile, "a locked circle shows the locked guess, not the profile's")

	# Codex on #496: two Minion circles can't share a type. The second becomes plain evil.
	if ss.size() > 2:
		var dup: Array = [{"id": people[3], "type": demon_type}, {"id": people[1], "type": sc.minions[0]}, {"id": people[2], "type": sc.minions[0]}]
		DailyGuess.apply(g, dup)
		var v: Dictionary = DailyGuess.verdict(g)
		check(v[people[1]] == sc.minions[0] and v[people[2]] == "evil", "a repeated Minion type keeps the first and keeps the second as evil (got %s, %s)" % [v[people[1]], v[people[2]]])

	# Codex on #496: an untyped Demon (a multi-Demon script) reopens in the Demon circle.
	var untyped: Array = [{"id": people[8], "type": ""}]
	for i in range(1, ss.size()):
		untyped.append({"id": people[i], "type": ""})
	DailyGuess.apply(g, untyped)
	var again: Array = DailyGuess.prefill(g)
	check(again[0].id == people[8] and again[0].type == "", "an untyped Demon guess reopens in the Demon circle (got %s)" % again[0].id)
	check(again.slice(1).map(func(p): return p.id) == untyped.slice(1).map(func(p): return p.id), "the Minion circles reopen unchanged")

	# The view: Confirm locks and calls back; Skip and "Don't ask again" lock nothing.
	var m = _Host.new()
	m.g = g
	root.add_child(m)
	var done: Array = []
	var off: Array = []
	var w = DailyGuess.open(m, func(ok): done.append(ok), func(): off.append(true))
	check(m.get_node_or_null("DailyGuess") == w, "the window opens over the main screen")
	check(w._circles.size() == ss.size(), "it shows one circle per slot (got %d)" % w._circles.size())
	check(w.find_child("FadeLine", true, false) == null, "there's no line on the fade (Michael)")
	check(w._circles[0].name.text == g.w.by_id[people[8]].name, "the Demon circle shows the locked guess's name")
	w._open_picker(0, w._circles[0].face)
	check(w._picker != null and w._picker.find_child("Pick_" + people[4], true, false) != null, "the picker lists the cast's portraits")
	w._pick(0, people[4])
	check(w.picks[0].id == people[4], "picking a portrait fills the circle")
	w._pick(1, people[4])
	check(w.picks[1].id == people[4] and w.picks[0].id == "", "a person sits in one circle at a time")
	if w._circles.size() > 2:
		w._pick_type(1, sc.minions[0])
		w._pick_type(2, sc.minions[0])
		check(w.picks[2].type == sc.minions[0] and w.picks[1].type == "", "choosing a type already in another circle moves it")
	w._pick(0, people[6])
	w._finish(true)
	check(done == [true] and DailyGuess.verdict(g)[people[6]] != "?", "Confirm locks the new guess and calls back")
	var before = g.get_meta(DailyGuess.META_LOCKED).duplicate(true)
	var w2 = DailyGuess.open(m, func(ok): done.append(ok), func(): off.append(true))
	w2._pick(0, people[7])
	w2._finish(false)
	check(done == [true, false] and g.get_meta(DailyGuess.META_LOCKED) == before, "Skip calls back and locks nothing")
	var w3 = DailyGuess.open(m, func(ok): done.append(ok), func(): off.append(true))
	(w3.find_child("DontAsk", true, false) as Button).pressed.emit()
	check(off == [true] and done.size() == 3 and done[2] == false, "'Don't ask again' turns it off for the case and closes like Skip")

	# The profile note shows only while a circle is greyed.
	var g2 = _game(7)
	var demon2 = g2.w.npcs[0]
	g2.set_guess(demon2.id, g2.w.case_script.demons[0], 3)
	var m2 = _Host.new()
	m2.g = g2
	root.add_child(m2)
	var w4 = DailyGuess.open(m2, func(_ok): pass, Callable())
	check(w4._note.visible and w4._circles[0].face.modulate == DailyGuess.GREYED, "a profile pick shows greyed, with the note")
	w4._pick(0, g2.w.npcs[1].id)
	check(not w4._note.visible and w4._circles[0].face.modulate == Color(1, 1, 1), "picking someone new clears the grey and the note")

	print("Daily evil-team guess: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


class _Host extends Control:
	var g
