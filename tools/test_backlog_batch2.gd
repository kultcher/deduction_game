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
