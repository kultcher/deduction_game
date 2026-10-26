## Focused regressions for the ten approved Oct-25 backlog decisions.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Social = preload("res://sim/social.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")
const Argue = preload("res://sim/argue.gd")
var checks = 0
var fails = 0
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	_walker_wording()
	_medium_hearths()
	_neutral_opinion()
	print("Batch 2: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://batch2_tests"
	g.new_case(4242, 10)
	return g
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)
func _walker_wording() -> void:
	var g = fresh()
	var n = g.w.minion()
	var target = g.w.living_good()[0]
	for person in g.w.npcs:
		person.info_log = []
	g.w.evil_plan.fake_sightings = {n.id + ":3": {"who": target.id, "block": "market", "day": 3, "how": "window"}}
	var original = JSON.stringify(g.w.evil_plan.fake_sightings)
	for role in ["nightwatch", "warden", "lamplighter", "medium", "seer"]:
		n.claimed_role = role
		var expected_rng = RandomNumberGenerator.new()
		expected_rng.state = g.w.rng.state
		expected_rng.randi_range(0, 0) # The existing single-option w.pick call.
		var why = Evil.bluff_reason(g.w, n, target)
		check("night 3" in why, "every fake-sighting reason names its stored night")
		check(("duty" in why and not "window" in why) if role != "seer" else "window" in why, "claimed walking duties and window claims have distinct wording")
		check(g.w.rng.state == expected_rng.state and JSON.stringify(g.w.evil_plan.fake_sightings) == original, "wording preserves the existing choice RNG and cached frame")

func _medium_hearths() -> void:
	var g = fresh()
	var w = g.w
	var goods: Array = w.living_good()
	var m = goods[0]
	var older = goods[1]
	var recent = goods[2]
	var executed = goods[3]
	check(w._medium_choice(m) == "", "no Medium visit before any Demon death")
	for victim in [older, recent, executed]:
		victim.alive = false
		victim.beliefs = []
		victim.suspicion = {}
		victim.info_log = []
		victim.warden_log = {}
	older.death_cause = "demon"
	older.death_day = 1
	recent.death_cause = "demon"
	recent.death_day = 2
	executed.death_cause = "executed"
	executed.death_day = 9
	check([w._medium_choice(m), w._medium_choice(m), w._medium_choice(m)] == [recent.id, older.id, recent.id], "only Demon victims are visited; exhausted hearths revisit the newest")
	check(m.medium_visited.size() == 2, "revisits do not duplicate the visited set")
	recent.info_log = [{"role": "seer", "day": 1, "shared": false, "text": "first", "data": {}}, {"role": "seer", "day": 2, "shared": false, "text": "second", "data": {}}]
	var first = w._medium_item(m, recent, false)
	var second = w._medium_item(m, recent, false)
	check(first.type == "reading" and second.type == "reading" and first.entry.text == "first" and second.entry.text == "second", "a revisited hearth can reveal another untold reading")
	check(w._medium_item(m, recent, false).type == "nothing" and w._medium_item(m, older, false).type == "nothing", "exhausted and empty hearths report nothing new")
	var fake = w.minion()
	w.evil_plan.bluffs = {fake.id: "medium"}
	w.evil_plan.scapegoat = goods[4].id
	var state = w.rng.state
	check(Evil._fake_medium_item(w, fake, executed, goods[4].id).is_empty() and w.rng.state == state, "fake reports reject executed hearths without a random choice")
	var visited: Array = []
	for day in [3, 4, 5]:
		w.day = day
		Evil.make_fake_info(w)
		var entries: Array = fake.info_log.filter(func(e): return e.role == "medium" and e.day == day)
		check(entries.size() == 1, "the fake Medium produces one report on a visit/revisit")
		if entries.size() == 1:
			visited.append(entries[0].data.dead)
	check(visited == [recent.id, older.id, recent.id], "fake hearth sequence matches real eligibility and revisits")

func _neutral_opinion() -> void:
	var g = fresh()
	var w = g.w
	var n = w.living_good()[0]
	var t = w.living_good()[1]
	n.traits.gossip = 1.0
	n.traits.insight = 1.0
	n.npc_trust[t.id] = 0.5
	n.workshop_state = {}
	# Find both outcomes of the original roll, then exercise the boundary with
	# identical RNG states. Wording must not alter the draw, level or facts.
	var calm_state: int = 0
	var off_state: int = 0
	var probe = RandomNumberGenerator.new()
	for seed_value in range(1, 100):
		probe.seed = seed_value
		var before: int = probe.state
		if probe.randf() >= 0.2:
			calm_state = before
		else:
			off_state = before
		if calm_state != 0 and off_state != 0:
			break
	for alignment in ["good", "evil"]:
		n.alignment = alignment
		w.evil_plan.scapegoat = w.living_good().back().id
		if n.is_evil():
			Mind.shadow_run(w, n, func(sh): sh.workshop_state = {})
		for level in [0.34, 0.35, 0.44]:
			n.suspicion[t.id] = level
			if n.is_evil():
				n.shadow.suspicion[t.id] = level
			for state in [calm_state, off_state]:
				n.pressed_today = 0
				n.dialogue_memory = {}
				w.rng.state = state
				probe.state = state
				probe.randf()
				var reply = Mind.answer_opinion(w, n, t)
				var text: String = reply.lines[0].text
				check(w.rng.state == probe.state, "neutral wording preserves the original opinion RNG")
				check(Mind.susp(n, t.id) == level, "neutral wording preserves the underlying level")
				if state == off_state:
					check("something's off" in text and reply.facts.size() == 1, "existing suspicious-roll outcome is unchanged")
				else:
					check(("seems all right" in text) if level < 0.35 else ("don't really know %s that well" % t.name) in text, "neutral boundary uses the approved wording for either alignment")
					check(reply.facts.is_empty(), "a neutral or reassuring opinion creates no incriminating fact")
