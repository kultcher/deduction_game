## The grim reveal, stage 1 (ui/reveal/reveal_plan.gd, ui/reveal/reveal_overlay.gd): plays
## passive games to their end and checks the reveal's order (deaths in order, the Demon last,
## a final-three game's last hanging last), its key moments and fakeouts, the sealed verdict
## (frozen at the last meeting, or sealed after an overnight ending), and the overlay's flow.
##   godot --headless --path . --script res://tools/test_grim_reveal.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const RevealPlan = preload("res://ui/reveal/reveal_plan.gd")
const RevealOverlay = preload("res://ui/reveal/reveal_overlay.gd")
const DailyGuess = preload("res://ui/daily_guess.gd")
const Main = preload("res://ui/main.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## A passive game played to its end. Before the first meeting closes, the player names the
## true Demon (so the verdict has something right in it) and a good person as a Minion.
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
			g.set_guess(demon.id, demon.role, 3)
			var good = g.w.living_good()[0]
			g.set_guess(good.id, "evil", 2)
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
		if Main.ended_at_meeting(g):
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
		var v = Main.sealed_verdict(at_meeting)
		check(v != null, "a case that ended at a meeting needs no seal: the theory frozen before the hanging is the verdict")
		_check_overlay(at_meeting, v)
	if overnight != null:
		check(Main.sealed_verdict(overnight) == null, "a case that ended overnight asks for the seal first")
		_check_seal(overnight)
	print("Grim reveal (stage 1): %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _check_plan(g: Game) -> void:
	var w = g.w
	var verdict: Dictionary = Main.sealed_verdict(g, true)
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

func _check_overlay(g: Game, verdict: Dictionary) -> void:
	var host = Control.new()
	root.add_child(host)
	var v = RevealOverlay.open(host, g, verdict)
	check(v.get_node_or_null("Stage/Card") != null and v.index == 0, "the overlay opens on the first person's card")
	check(v.get_node("Stage/Lead").text == v.plan.lead.text, "the lead line shows")
	check(v.find_child("TownRow", true, false).get_child_count() == g.w.npcs.size(), "the town row shows every portrait")
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

func _check_seal(g: Game) -> void:
	var host = _Host.new()
	host.g = g
	root.add_child(host)
	var theory = g.guesses.duplicate(true)
	var w = DailyGuess.open(host, func(_ok): pass, Callable(), true)
	check(w.find_child("Skip", true, false).visible == false and w.find_child("DontAsk", true, false).visible == false, "the seal window offers only the seal")
	var demon = g.w.npcs.filter(func(n): return C.is_demon(n.role))[0]
	w._pick(0, demon.id)
	w._finish(true)
	check(g.guesses == theory, "sealing doesn't touch the frozen theory")
	var sealed = Main.sealed_verdict(g)
	check(sealed != null and sealed.get(demon.id, "") == w.picks[0].type if w.picks[0].type != "" else sealed.get(demon.id, "") == "evil",
		"the seal becomes the verdict")


class _Host extends Control:
	var g
