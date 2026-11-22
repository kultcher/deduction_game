## The execution and the night's reveal (Michael, Nov 22; ui/pacing/): the beats each builds
## from the world, in Michael's words, and the overlay's flow: a click lands or moves on, a
## Continue waits, Skip ends it, reduced motion halves the pauses. Presentation only.
##   godot --headless --path . --script res://tools/test_pacing.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const PacingPlans = preload("res://ui/pacing/pacing_plans.gd")
const PacingOverlay = preload("res://ui/pacing/pacing_overlay.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _types(beats: Array) -> Array:
	return beats.map(func(b): return str(b.type))

func _texts(beats: Array) -> Array:
	return beats.filter(func(b): return b.type == "headline").map(func(b): return str(b.text))

func _run() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 10)
	var w = g.w
	var a = w.npcs[0]
	var b = w.npcs[1]
	var c = w.npcs[2]
	var rng_before = w.rng.state

	# The execution.
	var ex: Array = PacingPlans.execution(w, a.id)
	check(_types(ex) == ["fade", "portrait", "headline", "beat", "mark", "beat", "headline", "continue"], "a hanging: fade, portrait, headline, beat, the mark, beat, headline, Continue")
	check((PacingPlans.EXEC_ABOVE % PacingPlans._named(w, a.id)) in _texts(ex) and PacingPlans.EXEC_BELOW in _texts(ex), "in Michael's words, the name in its colour")
	check(PacingPlans.execution(w, "").is_empty(), "no hanging, no sequence")
	var mt: Array = PacingPlans.execution(w, b.id, {"martyr": a.id, "saved": b.id})
	check(mt.filter(func(x): return x.type == "portrait")[0].id == a.id and (PacingPlans.MARTYR_ABOVE % [PacingPlans._named(w, a.id), PacingPlans._named(w, b.id)]) in _texts(mt), "a Martyr: their own portrait, dying in the saved one's place")

	# The night.
	var alive: Array = w.npcs.map(func(n): return n.id)
	a.death_cause = "demon"
	w.deaths_last_night = [a.id]
	var one: Array = PacingPlans.night(w, "You kept watch.", alive)
	check(_types(one).slice(0, 4) == ["fade", "panel", "continue", "clear"], "the night's result first, held for Continue")
	var wheels: Array = one.filter(func(x): return x.type == "wheel")
	check(wheels.size() == 1 and wheels[0].victim == a.id and wheels[0].kill and wheels[0].people.size() == alive.size(), "one kill, one wheel of everyone alive, landing on the victim")
	check(PacingPlans.NIGHT_HEAD in _texts(one) and (PacingPlans.KILL_BELOW % PacingPlans._named(w, a.id)) in _texts(one), "the red lead and the grim end, in Michael's words")
	b.death_cause = "demon"
	w.deaths_last_night = [a.id, b.id]
	var two: Array = PacingPlans.night(w, "", alive)
	var w2: Array = two.filter(func(x): return x.type == "wheel")
	check(w2.size() == 2 and w2[1].people.size() == alive.size() - 1 and not w2[1].people.any(func(p): return p.id == a.id), "two kills: a second wheel without the first victim")
	check(PacingPlans.AGAIN in _texts(two) and not "panel" in _types(two), "...and the fiend was not finished; no result panel when the night said nothing")
	c.death_cause = "brute"
	w.deaths_last_night = [c.id]
	var quiet: Array = PacingPlans.night(w, "", alive)
	var qw: Array = quiet.filter(func(x): return x.type == "wheel")
	check(qw.size() == 1 and not qw[0].kill and PacingPlans.QUIET_BELOW in _texts(quiet), "no Demon kill: the harmless fakeout, in blue words")
	check(qw[0].victim == PacingPlans.night(w, "", alive)[ _types(quiet).find("wheel")].victim, "the fakeout lands the same way each time for a night")
	w.deaths_last_night = []
	var warded: Array = PacingPlans.night(w, "", alive, b.id)
	check(warded.filter(func(x): return x.type == "wheel")[0].victim == b.id, "a ward that held: the fakeout lands on the warded door")
	check(w.rng.state == rng_before, "building the beats moves no RNG")

	# The overlay's flow.
	var host = Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var ended: Array = []
	var o = PacingOverlay.open(host, w, PacingPlans.execution(w, a.id), false, func(): ended.append(true))
	check(o.index == 0 and o.get_node_or_null("Skip") != null, "it opens on the first beat, with Skip")
	var guard := 0
	while o.index < ex.size() - 1 and guard < 50:
		o.click()
		o._process(0.01)
		guard += 1
	check(o._waiting and o.get_node("Continue").visible, "clicking through reaches the Continue")
	check(o.get_node("Above").text.contains(a.name) and o.get_node("Below").text.contains("evil still lurks"), "both headlines are up")
	o.click()
	check(ended == [true], "Continue at the end closes it and says so")
	await process_frame
	var o2 = PacingOverlay.open(host, w, PacingPlans.night(w, "", alive), true, func(): ended.append(true))
	check(o2.reduced_motion and is_equal_approx(o2._secs(1.0), 0.5), "reduced motion halves the pauses (small call)")
	o2.finish()
	check(ended.size() == 2, "Skip or Esc ends the whole sequence")
	await process_frame
	check(host.get_child_count() == 0, "and the overlay is gone")
	# Codex on #537: a kill that ends the game brings no dawn, but it still plays (then the reveal).
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	root.add_child(scene)
	await process_frame
	var g2 = Game.new()
	g2.detailed_logging = false
	g2.new_case(692, 10)
	scene.g = g2
	var v = g2.w.npcs[4]
	v.alive = false
	v.death_cause = "demon"
	g2.w.deaths_last_night = [v.id]
	g2.w.game_over = true
	var final_plan: Array = scene._pacing_plan([{"k": "narration", "text": "You sleep."}, {"k": "headline", "kind": "ending", "text": "Defeat"}])
	check(final_plan.any(func(x): return x.type == "wheel" and x.victim == v.id and x.kill), "a game-ending kill still gets its wheel, though no dawn comes")
	check(scene._pacing_plan([{"k": "headline", "kind": "phase", "text": "Afternoon"}]).is_empty(), "an ordinary phase change plays nothing")
	# Codex on #537: a spent ward that saved nobody doesn't decide the fakeout; a save does.
	v.death_cause = ""
	v.alive = true
	g2.w.deaths_last_night = []
	g2.w.game_over = false
	g2.w.day = 3
	var warded_id: String = g2.w.npcs[6].id
	g2.ward_log[2] = warded_id
	g2.w.ward_saves = []
	var dawn: Array = [{"k": "headline", "kind": "dawn", "text": "Day 3 Dawns"}]
	g2.remove_meta("paced")
	var spent: Array = scene._pacing_plan(dawn).filter(func(x): return x.type == "wheel")
	check(spent.size() == 1 and spent[0].victim == PacingPlans._fakeout(g2.w, g2.w.npcs.filter(func(n): return n.alive).map(func(n): return n.id)), "a ward that saved nobody: the usual fakeout draw")
	check(scene._pacing_plan(dawn).is_empty(), "the same night doesn't play twice (look repeats the morning's header)")
	g2.remove_meta("paced")
	g2.w.ward_saves = [{"night": 2, "target": warded_id}]
	var saved: Array = scene._pacing_plan(dawn).filter(func(x): return x.type == "wheel")
	check(saved.size() == 1 and saved[0].victim == warded_id, "a ward that held: the fakeout lands on that door")
	# Codex on #537: the condemned's last words finish on the courtroom stage before it opens.
	var stage = scene.meeting_view.stage
	stage.queue.append({"speaker": v.id, "name": v.name, "text": "Remember me kindly.", "expression": "", "log": {}})
	scene._open_pacing_when_settled(PacingPlans.execution(g2.w, v.id), [])
	await process_frame
	check(scene.get_node_or_null("Pacing") == null, "while last words are still on the stage, the hanging waits")
	stage.queue.clear()
	scene.meeting_view.settled.emit()
	await process_frame
	check(scene.get_node_or_null("Pacing") != null, "and it plays once the stage has settled")
	scene.queue_free()
	print("Pacing: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
