## The daily evil-team guess (ui/daily_guess.gd; Michael, Nov 21): the circles follow the
## script's evil count, the Demon picker crosses out the Demon's victims, the window prefills
## from and writes to the private theory, and Confirm, Skip and "Don't ask again" behave.
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

	# Prefill: nothing guessed yet, so the circles are empty; a single-Demon script gives the type.
	var picks: Array = DailyGuess.prefill(g)
	check(picks.all(func(p): return p.id == ""), "with no guesses, every circle starts empty")
	check(picks[0].type == (sc.demons[0] if sc.demons.size() == 1 else ""), "the Demon's type is prefilled only on a single-Demon script (got '%s')" % picks[0].type)

	# The Demon picker crosses out those the Demon killed; Minion pickers don't.
	var victim = g.w.living_good()[0]
	victim.alive = false
	victim.death_cause = "demon"
	check(not DailyGuess.pickable(g, "demon", victim.id), "the Demon picker crosses out someone the Demon killed")
	check(DailyGuess.pickable(g, "minion", victim.id), "a Minion picker leaves them selectable")
	var hanged = g.w.living_good()[0]
	hanged.alive = false
	hanged.death_cause = "executed"
	check(DailyGuess.pickable(g, "demon", hanged.id), "someone hanged can still be picked as the Demon")
	victim.alive = true
	victim.death_cause = ""
	hanged.alive = true
	hanged.death_cause = ""

	# Apply: the picks become the private theory.
	var people: Array = g.w.npcs.map(func(n): return n.id)
	var demon_type: String = sc.demons[0]
	var picks2: Array = [{"id": people[0], "type": demon_type}]
	for i in range(1, ss.size()):
		picks2.append({"id": people[i], "type": sc.minions[0] if i == 1 else ""})
	check(DailyGuess.apply(g, picks2), "applying the picks succeeds")
	check(g.guesses[people[0]].guess == demon_type, "the Demon circle writes the Demon's type (got %s)" % g.guesses[people[0]].guess)
	check(g.guesses[people[1]].guess == sc.minions[0], "a Minion circle with a type writes that type")
	if ss.size() > 2:
		check(g.guesses[people[2]].guess == "evil", "a Minion circle without a type writes plain evil")
	check(int(g.guesses[people[0]].confidence) == DailyGuess.DEFAULT_CONFIDENCE, "a new guess takes the default confidence")

	# Prefill reads them back.
	var back: Array = DailyGuess.prefill(g)
	check(back[0].id == people[0] and back[0].type == demon_type, "the window prefills the Demon guess")
	check(back[1].id == people[1] and back[1].type == sc.minions[0], "it prefills a typed Minion guess first")

	# Dropping someone from the circles clears their evil guess; other guesses stay.
	g.set_guess(people[5], "good", 2)
	var picks3: Array = back.duplicate(true)
	picks3[0] = {"id": people[3], "type": demon_type}
	DailyGuess.apply(g, picks3)
	check(g.guesses[people[3]].guess == demon_type and g.guesses[people[0]].guess == "?", "moving the Demon guess clears the old one")
	check(g.guesses[people[5]].guess == "good", "a 'good' guess outside the circles is left alone")

	# The view: built over a stand-in parent, Confirm writes and calls back; Skip doesn't write.
	var m = _Host.new()
	m.g = g
	root.add_child(m)
	var done: Array = []
	var off: Array = []
	var v = DailyGuess.open(m, func(ok): done.append(ok), func(): off.append(true))
	check(v.get_node_or_null("DailyGuess") == null and m.get_node_or_null("DailyGuess") == v, "the window opens over the main screen")
	check(v._circles.size() == ss.size(), "it shows one circle per slot (got %d)" % v._circles.size())
	check(v._circles[0].name.text == g.w.by_id[people[3]].name, "the Demon circle shows the current guess's name")
	v._open_picker(0, v._circles[0].face)
	var picker = v._picker
	check(picker != null and picker.find_child("Pick_" + people[4], true, false) != null, "the picker lists the cast's portraits")
	v._pick(0, people[4])
	check(v.picks[0].id == people[4], "picking a portrait fills the circle")
	v._pick(1, people[4])
	check(v.picks[1].id == people[4] and v.picks[0].id == "", "a person sits in one circle at a time")
	v._pick(0, people[6])
	v._finish(true)
	check(done == [true], "Confirm calls back with confirmed")
	check(g.guesses[people[6]].guess == demon_type, "Confirm writes the new Demon guess")
	var before = g.guesses.duplicate(true)
	var v2 = DailyGuess.open(m, func(ok): done.append(ok), func(): off.append(true))
	v2._pick(0, people[7])
	v2._finish(false)
	check(done == [true, false] and g.guesses == before, "Skip calls back and writes nothing")
	var v3 = DailyGuess.open(m, func(ok): done.append(ok), func(): off.append(true))
	(v3.find_child("DontAsk", true, false) as Button).pressed.emit()
	check(off == [true] and done.size() == 3 and done[2] == false, "'Don't ask again' turns it off for the case and closes like Skip")

	print("Daily evil-team guess: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


class _Host extends Control:
	var g
