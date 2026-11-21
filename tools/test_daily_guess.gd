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

	# Codex on #496: a Scion's hidden promotion (it leaves minion_ids) doesn't remove a circle.
	var gs = _game(10)
	var before_n: int = DailyGuess.slots(gs).size()
	if not gs.w.minion_ids.is_empty():
		gs.w.minion_ids.remove_at(0)
	check(DailyGuess.slots(gs).size() == before_n, "a Minion leaving the roster mid-case (a Scion's promotion) keeps its circle")

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
	# (Earlier checks used both Demon changes; give this view a fresh budget.)
	var st: Dictionary = g.get_meta(DailyGuess.META_LOCKED)
	st["demon_changes"] = 0
	g.set_meta(DailyGuess.META_LOCKED, st)
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
	# (This game has used both Demon changes by now: keep the locked Demon, change a Minion.)
	w.picks[0] = DailyGuess.locked(g)[0]
	w._pick(1, people[6])
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

	# The Demon guess limit (Michael, Nov 21): the first pick free, then two changes; Minion
	# picks and types free; clearing counts; a changed Demon asks first.
	var g3 = _game(10)
	var sc3 = g3.w.case_script
	var ids: Array = g3.w.npcs.map(func(n): return n.id)
	var first: Array = DailyGuess.prefill(g3)
	first[0] = {"id": ids[0], "type": sc3.demons[0]}
	DailyGuess.apply(g3, first)
	check(DailyGuess.demon_changes_left(g3) == DailyGuess.DEMON_CHANGES, "the first Demon pick is free")
	var mins: Array = DailyGuess.prefill(g3)
	mins[1] = {"id": ids[1], "type": sc3.minions[0]}
	DailyGuess.apply(g3, mins)
	var retype: Array = DailyGuess.prefill(g3)
	retype[1] = {"id": ids[2], "type": ""}
	retype[0]["type"] = sc3.demons[-1]
	DailyGuess.apply(g3, retype)
	check(DailyGuess.demon_changes_left(g3) == DailyGuess.DEMON_CHANGES, "Minion picks and type changes are free")
	var swap: Array = DailyGuess.prefill(g3)
	swap[0] = {"id": ids[3], "type": sc3.demons[0]}
	check(DailyGuess.changes_demon(g3, swap), "swapping the Demon guess is a change")
	DailyGuess.apply(g3, swap)
	check(DailyGuess.demon_changes_left(g3) == DailyGuess.DEMON_CHANGES - 1, "a Demon change uses one up")
	var clear: Array = DailyGuess.prefill(g3)
	clear[0] = {"id": "", "type": sc3.demons[0]}
	DailyGuess.apply(g3, clear)
	check(DailyGuess.demon_changes_left(g3) == 0, "clearing a locked Demon counts as a change")
	var refill: Array = DailyGuess.prefill(g3)
	refill[0] = {"id": ids[4], "type": sc3.demons[0]}
	DailyGuess.apply(g3, refill)
	check(DailyGuess.verdict(g3)[ids[4]] == sc3.demons[0], "after a clear, a new Demon pick is a first pick again")
	var over: Array = DailyGuess.prefill(g3)
	over[0] = {"id": ids[5], "type": sc3.demons[0]}
	check(not DailyGuess.apply(g3, over) and DailyGuess.verdict(g3)[ids[4]] == sc3.demons[0], "with no changes left, the Demon guess can't change")
	var m3 = _Host.new()
	m3.g = g3
	root.add_child(m3)
	var w5 = DailyGuess.open(m3, func(_ok): pass, Callable())
	check(w5._circles[0].face.disabled and w5._circles[0].face.tooltip_text == DailyGuess.NO_CHANGES_TIP, "with none left, the Demon picker is disabled, with its tooltip")
	# Codex on #496: once frozen, the Demon can't be taken by a Minion circle, and a lock that
	# can't be saved leaves the window open.
	w5._pick(1, ids[4])
	check(w5.picks[0].id == ids[4] and w5.picks[1].id != ids[4], "a frozen Demon can't be moved into a Minion circle")
	w5._open_picker(1, w5._circles[1].face)
	var frozen_btn = w5._picker.find_child("Pick_" + ids[4], true, false)
	check(frozen_btn != null and frozen_btn.disabled, "the Minion picker shows the frozen Demon disabled")
	var closed5: Array = []
	w5._on_done = func(ok): closed5.append(ok)
	w5.picks[0] = {"id": ids[6], "type": sc3.demons[0]}
	w5._finish(true)
	check(closed5.is_empty() and DailyGuess.verdict(g3)[ids[4]] == sc3.demons[0], "a lock that can't be saved keeps the window open")

	var g4 = _game(10)
	var ids4: Array = g4.w.npcs.map(func(n): return n.id)
	var p4: Array = DailyGuess.prefill(g4)
	p4[0] = {"id": ids4[0], "type": g4.w.case_script.demons[0]}
	DailyGuess.apply(g4, p4)
	var m4 = _Host.new()
	m4.g = g4
	root.add_child(m4)
	var closed: Array = []
	var w6 = DailyGuess.open(m4, func(ok): closed.append(ok), Callable())
	w6.confirm()
	check(closed == [true] and w6._change_dialog == null, "an unchanged Demon confirms at once")
	var w7 = DailyGuess.open(m4, func(ok): closed.append(ok), Callable())
	w7._pick(0, ids4[1])
	w7.confirm()
	check(closed.size() == 1 and w7._change_dialog != null and w7._change_dialog.dialog_text == DailyGuess.CHANGE_DIALOG % DailyGuess.DEMON_CHANGES, "a changed Demon asks first, with the count")
	w7._change_dialog.confirmed.emit()
	check(closed == [true, true] and DailyGuess.verdict(g4)[ids4[1]] != "?", "confirming the dialog locks the change")

	print("Daily evil-team guess: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


class _Host extends Control:
	var g
