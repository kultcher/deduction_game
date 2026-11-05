## The town's vibe check on the Demonologist (evening tavern gossip): average rapport and
## competence of the living good townsfolk, 0.1-wide bands centred on 0.5, a trend since the
## player last heard it, an outlier note, evil and the dead left out, no RNG draws.
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_bands()
	_test_town_vibe()
	_test_tavern_line()
	print("Town vibe: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _game(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	if g.state == "approach":
		g.command("decline")
	return g


func _set_all(g, rap: float, cred: float) -> void:
	for n in g.w.npcs:
		n.trust = rap
		n.credibility = cred


func _test_bands() -> void:
	var cases = [[0.1, 0], [0.249, 0], [0.25, 1], [0.349, 1], [0.35, 2], [0.449, 2], [0.45, 3], [0.5, 3], [0.549, 3],
		[0.55, 4], [0.65, 5], [0.749, 5], [0.75, 6], [0.95, 6]]
	var ok = true
	for c in cases:
		if Social.vibe_band(c[0]) != c[1]:
			ok = false
			print("  band(%.3f) = %d, want %d" % [c[0], Social.vibe_band(c[0]), c[1]])
	_check(ok, "bands are 0.1 wide and centred on neutral (0.45-0.55 undecided; edges go up)")


func _test_town_vibe() -> void:
	var g = _game(8501)
	var w = g.w
	_set_all(g, 0.5, 0.5)
	for n in w.evil_team():
		n.trust = 0.0
		n.credibility = 0.0
	var v: Dictionary = Social.town_vibe(g)
	_check(is_equal_approx(v.rapport, 0.5) and v.rapport_band == 3 and "hasn't made up its mind" in v.line, "evil's view is left out (evil at 0 doesn't drag a neutral town down)")
	_check("unproven" in v.line and v.trend.is_empty(), "first hearing: no trend")
	var good: Array = w.living().filter(func(n): return not n.is_evil())
	var dead = good[0]
	dead.trust = 0.0
	dead.alive = false
	v = Social.town_vibe(g)
	_check(is_equal_approx(v.rapport, 0.5), "the dead are left out")
	dead.alive = true
	dead.trust = 0.5
	for n in good:
		n.trust += 0.04
		n.credibility -= 0.05
	v = Social.town_vibe(g)
	_check("warming since you last listened" in v.line and "slipping" in v.line, "moves since the last hearing are called out (rapport up, competence down)")
	for n in good:
		n.trust += 0.02
	v = Social.town_vibe(g)
	_check(not v.trend.has("rapport") and not ("warming since" in v.line), "a drift under the trend threshold isn't called out")
	_set_all(g, 0.8, 0.8)
	good[1].trust = 0.3
	g.town_vibe_heard = {}
	v = Social.town_vibe(g)
	_check("someone still doesn't trust you" in v.line, "one good townsfolk well below the average gets a note")
	var rng_before = w.rng.state
	Social.town_vibe(g)
	_check(w.rng.state == rng_before, "the vibe check draws nothing from the world RNG")


func _test_tavern_line() -> void:
	var g = _game(8502)
	g.w.phase = C.EVENING
	var r: Dictionary = Social.tavern_evening_gossip(g)
	_check(r.lines.any(func(l): return "And about you, Demonologist" in str(l)), "evening tavern gossip always includes the town's opinion of you")
	_check(not r.get("vibe", {}).is_empty() and not g.town_vibe_heard.is_empty(), "and remembers what you heard, for next time's trend")
