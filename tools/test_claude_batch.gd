## Claude's Oct 26 batch: replies match beliefs, coherent evil stories, one defence per
## incident, Demon victims' sincerity, the Rumormonger setup rule, Workshop links.
##   godot --headless --path . --script res://tools/test_claude_batch.gd
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Presentation = preload("res://game/workshop_presentation.gd")
const Evil = preload("res://sim/evil.gd")
var fails = 0
var checks = 0

func _init() -> void:
	_stance_from_belief()
	_one_night_story()
	print("Claude batch: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	return g

func _stance_from_belief() -> void:
	_check(Presentation.belief_stance("evil", 0.2, 0.3) == "accept", "a 0.10 rise toward 'evil' is acceptance")
	_check(Presentation.belief_stance("evil", 0.2, 0.23) == "partial", "a 0.03 rise is partial")
	_check(Presentation.belief_stance("evil", 0.2, 0.2) == "reject", "no movement is no")
	_check(Presentation.belief_stance("good", 0.4, 0.3) == "accept", "for 'good', suspicion falling is acceptance")
	var g = _game(4401)
	var n = g.w.living_good()[0]
	var t = g.w.living_good()[1]
	n.suspicion[t.id] = 0.32
	var couldnt = "I could not follow your explanation through within what I considered. That does not prove it wrong."
	var said: String = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "reject", couldnt)
	_check(said.begins_with(couldnt) and said.ends_with("Even so, it does change how I see %s." % t.name), "couldn't follow, but moved: the reason stays and the stance follows the belief (%s)" % said)
	n.suspicion[t.id] = 0.2
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.")
	_check(said == "It holds together, but it doesn't change my mind about %s." % t.name, "convinced in words but unmoved: says so (%s)" % said)
	n.suspicion[t.id] = 0.8
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.8, "accept", "Taken together, those reports convince me. If anything, it points me toward Agnes.")
	_check(said == "If anything, it points me toward Agnes. I'd already come to that about %s." % t.name, "already convinced: says so and keeps the other reasons (%s)" % said)
	n.suspicion[t.id] = 0.3
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.")
	_check(said == "Taken together, those reports convince me.", "when words and belief agree, the reply is unchanged")
	n.suspicion[t.id] = 0.2
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.", true)
	_check(said == "I'd already taken that into account.", "a retold case they'd already weighed: says so (%s)" % said)
	said = Presentation._belief_stance_text(g, n, "conflict", t.id, 0.2, "accept", "Those accounts cannot all be accurate.")
	_check(said == "Those accounts cannot all be accurate.", "conflicts are left alone")

## One story per evil member per night: a made-up sighting repeats that night's fake watch
## report, never someone else (Constance, 54875).
func _one_night_story() -> void:
	var same = 0
	var other_block_quiet = 0
	var tried = 0
	for sd in range(4410, 4430):
		var g = _game(sd)
		var w = g.w
		var m = w.minion()
		var goods: Array = w.living_good()
		var x = goods[0]
		var block: String = m.home_block
		m.info_log.append({"day": 1, "role": "nightwatch", "fake": true, "shared": false, "true": false,
			"data": {"block": block, "seen": [x.id]}, "text": "I watched it: I saw %s pass by" % x.name})
		w.day = 2
		tried += 1
		var r = Evil.fake_night_sighting(w, m, 1)
		if r != null and r["who"] == x.id:
			same += 1
		var away: String = C_other(block)
		if Evil.fake_night_sighting(w, m, 1, away, "street") == null:
			other_block_quiet += 1
	_check(same == tried, "a window sighting repeats the member's own watch report for that night (%d/%d)" % [same, tried])
	_check(other_block_quiet == tried, "and nothing is invented on another block")

func C_other(block: String) -> String:
	for b in preload("res://sim/content.gd").BLOCKS:
		if b != block:
			return b
	return block
