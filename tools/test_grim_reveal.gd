## The grim reveal, stage 1 (ui/reveal/reveal_plan.gd, ui/reveal/reveal_overlay.gd): plays
## passive games to their end and checks the reveal's order (deaths in order, the Demon last,
## a final-three game's last hanging last), its key moments and fakeouts, the verdict (the last
## guesses locked in a daily window, whether the case ended at a meeting or overnight; no
## end-of-game seal, Michael Nov 21), and the overlay's flow.
##   godot --headless --path . --script res://tools/test_grim_reveal.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const RevealPlan = preload("res://ui/reveal/reveal_plan.gd")
const RevealOverlay = preload("res://ui/reveal/reveal_overlay.gd")
const DailyGuess = preload("res://ui/daily_guess.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## A passive game played to its end. At the first meeting the player locks in, in the daily
## window, the true Demon (so the verdict has something right in it) and a good person as a Minion.
func _play(seed_v: int, size: int) -> Game:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.detailed_logging = false
	g.new_case(seed_v, size)
	var guessed := false
	var guard := 0
	while g.state != "over" and guard < 600:
		guard += 1
		if g.state == "meeting" and not guessed:
			guessed = true
			var demon = g.w.npcs.filter(func(n): return C.is_demon(n.role))[0]
			var good = g.w.living_good()[0]
			var picks: Array = DailyGuess.prefill(g)
			picks[0] = {"id": demon.id, "type": demon.role}
			if picks.size() > 1:
				picks[1] = {"id": good.id, "type": ""}
			DailyGuess.apply(g, picks)
		var cmd: String = "look"
		match g.state:
			"approach": cmd = "decline"
			"day": cmd = "wait"
			"talk": cmd = "bye"
			"meeting": cmd = "done" if g.town_quiet else "wait"
			"nomination": cmd = "vote no"
			"night": cmd = "sleep"
		g.command(cmd)
	return g

func _init() -> void:
	var at_meeting: Game = null
	var overnight: Game = null
	for seed_v in range(1, 40):
		var g = _play(seed_v, 7)
		if not g.w.game_over:
			continue
		if _ended_at_meeting(g):
			if at_meeting == null:
				at_meeting = g
		elif overnight == null:
			overnight = g
		if at_meeting != null and overnight != null:
			break
	check(at_meeting != null, "found a passive game that ended at a meeting")
	check(overnight != null, "found a passive game that ended overnight")
	for g in [at_meeting, overnight]:
		if g == null:
			continue
		_check_plan(g)
	if at_meeting != null:
		_check_martyr(at_meeting)
		_check_overlay(at_meeting, DailyGuess.verdict(at_meeting))
	if overnight != null:
		var v: Dictionary = DailyGuess.verdict(overnight)
		check(v.values().any(func(x): return x != "?"), "after an overnight ending, the last locked guesses stand as the verdict")
	print("Grim reveal (stage 1): %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _check_plan(g: Game) -> void:
	var w = g.w
	var verdict: Dictionary = DailyGuess.verdict(g)
	var plan: Dictionary = RevealPlan.build(g, verdict)
	var ids: Array = plan.steps.map(func(s): return s.npc)
	var tag: String = "seed %d" % w.seed_value
	check(ids.size() == w.npcs.size() and ids.all(func(id): return ids.count(id) == 1), "%s: everyone is revealed once" % tag)
	var dead_order: Array = []
	for e in w.dlog.entries:
		if e["type"] in ["kill", "execution"] and not (e["target"] in dead_order):
			dead_order.append(e["target"])
	var last: String = RevealPlan.last_hanged(w)
	var final_three: bool = plan.final_three
	if final_three:
		check(ids[-1] == last, "%s: in a final-three game the last hanging is revealed last" % tag)
	else:
		check(C.is_demon(w.by_id[ids[-1]].role), "%s: the Demon is revealed last" % tag)
	var shown_dead: Array = ids.filter(func(id): return id in dead_order and id != last and not C.is_demon(w.by_id[id].role))
	var expect: Array = dead_order.filter(func(id): return id in shown_dead)
	check(shown_dead == expect, "%s: deaths and hangings come in the order they happened" % tag)
	var fakes: Array = []
	for i in range(plan.steps.size()):
		if plan.steps[i].fakeout_role != "":
			fakes.append(i)
	check(fakes.size() <= RevealPlan.FAKE_MAX and not (0 in fakes), "%s: at most two fakeouts, never on the first person (got %s)" % [tag, str(fakes)])
	check(not range(fakes.size() - 1).any(func(k): return fakes[k + 1] == fakes[k] + 1), "%s: never two fakeouts in a row" % tag)
	for i in fakes:
		var n = w.by_id[plan.steps[i].npc]
		check(plan.steps[i].fakeout_role != n.role, "%s: a fakeout lands first on a false role" % tag)
	check(RevealPlan.build(g, verdict).steps.map(func(s): return s.fakeout_role) == plan.steps.map(func(s): return s.fakeout_role),
		"%s: the same case gives the same fakeouts" % tag)
	check(plan.steps.all(func(s): return s.moments.size() <= RevealPlan.MAX_MOMENTS), "%s: at most two key moments a person" % tag)
	var dead_with_moment: bool = plan.steps.all(func(s): return not s.dead or not s.moments.is_empty())
	check(dead_with_moment, "%s: everyone who died has at least one key moment" % tag)
	var demon_step = plan.steps.filter(func(s): return C.is_demon(w.by_id[s.npc].role))[0]
	check(demon_step.get("guess_correct", false) and demon_step.guess == RevealPlan.GUESS_LINE % C.role_name(demon_step.role),
		"%s: the player's right Demon guess shows, marked right (got '%s')" % [tag, demon_step.guess])
	var wrong = plan.steps.filter(func(s): return s.guess != "" and not s.evil)
	check(not wrong.is_empty() and wrong.all(func(s): return not s.get("guess_correct", true)), "%s: a wrong guess is marked wrong" % tag)
	check(plan.steps.all(func(s): return s.align_text == (RevealPlan.ALIGN_EVIL if s.evil else RevealPlan.ALIGN_GOOD)), "%s: each card's alignment text matches" % tag)

## Codex on #499: a Martyr who died in another's place isn't reported as hanged.
func _check_martyr(g: Game) -> void:
	var n = g.w.npcs.filter(func(x): return not x.is_evil())[0]
	var keep = [n.alive, n.death_cause, n.death_day]
	n.alive = false
	n.death_cause = "martyr"
	n.death_day = 2
	var ms: Array = RevealPlan.key_moments(g, n)
	check(ms.has(RevealPlan.MOMENT_MARTYR % "second day") and not ms.any(func(x): return x.begins_with("Hanged")), "a Martyr's death reads as dying in another's place (got %s)" % str(ms))
	n.alive = keep[0]
	n.death_cause = keep[1]
	n.death_day = keep[2]

func _check_overlay(g: Game, verdict: Dictionary) -> void:
	var host = Control.new()
	root.add_child(host)
	var v = RevealOverlay.open(host, g, verdict)
	check(v.get_node_or_null("Stage/Card") != null and v.index == 0, "the overlay opens on the first person's card")
	check(v.get_node("Stage/Lead").text == v.plan.lead.text, "the lead line shows")
	check(v.find_child("TownRow", true, false).get_child_count() == g.w.npcs.size(), "the town row shows every portrait")
	# Codex on #499: a click on the reveal (not a button) reaches the overlay and moves it on.
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var was: int = v.index
	v.card.skip_to_end()
	v._gui_input(click)
	check(v.index == was + 1, "a click on the reveal moves on to the next person")
	check(v._stage.mouse_filter == Control.MOUSE_FILTER_PASS and v.card.mouse_filter != Control.MOUSE_FILTER_STOP, "the stage and the card pass clicks up to the overlay")
	var guard := 0
	while v._final == null and guard < 100:
		guard += 1
		v.next()
	check(v._final != null and not v._stage.visible, "Next through everyone reaches the final screen")
	var grid = v._final.find_child("TruthGrid", true, false)
	check(grid != null and grid.get_child_count() == 5 * (g.w.npcs.size() + 1), "the final screen lists every person's truth")
	var score: Array = v.verdict_score()
	check(score[0] >= 1 and score[1] == g.w.npcs.filter(func(n): return n.is_evil()).size(), "the summary counts the evil named rightly (got %s)" % str(score))
	check(v._final.find_child("Every lie", true, false) != null and v._final.find_child("Who told whom what", true, false) != null, "the detail views are tabs on the final screen")
	(v._final.find_child("WatchAgain", true, false) as Button).pressed.emit()
	check(v._stage.visible and v.index == 0, "Watch again starts the reveal over")
	(v.find_child("Skip", true, false) as Button).pressed.emit()
	check(v._final != null and not v._stage.visible, "Skip goes straight to the final screen")
	var reduced = RevealOverlay.open(host, g, verdict, Callable(), true)
	check(reduced.card.reduced_motion, "the reduced-motion setting reaches the card")

## Whether the case ended at a meeting: no kill after the last frozen theory.
func _ended_at_meeting(g) -> bool:
	var last_snap: int = -1
	var entries: Array = g.w.dlog.entries
	for i in range(entries.size()):
		if entries[i]["type"] == "prediction_snapshot":
			last_snap = i
	if last_snap < 0:
		return false
	for i in range(last_snap + 1, entries.size()):
		if entries[i]["type"] == "kill":
			return false
	return true

