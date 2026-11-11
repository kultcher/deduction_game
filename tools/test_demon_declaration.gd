## The demon-type declaration (game/demon_declaration.gd; belief-model Phase 2).
extends SceneTree

const Game = preload("res://game/game.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Declaration = preload("res://game/demon_declaration.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const Credibility = preload("res://game/credibility.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const Tuning = preload("res://sim/tuning.gd")

var fails = 0
var checks = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _game(demons: Array, seed_v: int = 4242, force: String = ""):
	var g = Game.new()
	g.detailed_logging = false
	var sc = ScriptDef.default_script()
	sc.demons = demons.duplicate()
	if force != "":
		sc.forced = sc.forced.filter(func(r): return not r in sc.demons) + [force]
	g.new_case(seed_v, 7, sc)
	return g

func _init() -> void:
	# One-kind scripts start declared and can't be changed.
	var g1 = _game(["demon"])
	_check(g1.w.declared_demon_type == "walker", "a walker-only script starts declared walker")
	_check(Declaration.blocked(g1.w) != "", "a one-kind script offers no declaration")
	_check(Declaration.declare(g1, "hexer") != "" and g1.w.declared_demon_type == "walker", "declaring on a one-kind script is refused")
	var gh = _game(["daykiller"])
	_check(gh.w.declared_demon_type == "hexer", "a Hexer-only script starts declared hexer")

	# A two-kind script starts undeclared.
	var g = _game(["demon", "daykiller"])
	var w = g.w
	_check(w.declared_demon_type == "" and Declaration.blocked(w) == "", "a two-kind script starts undeclared, and the declaration is open")
	_check(str(Bridge.capture(g, []).rules.declared_demon) == "", "the view carries no declaration before one is made")
	_check(Declaration.declare(g, "sideways") != "" and w.declared_demon_type == "", "an unknown kind is refused")

	var cred0: Dictionary = {}
	for n in w.living():
		cred0[n.id] = n.credibility
	GameMeeting._meeting_command(g, "declare", "hexer")
	_check(w.declared_demon_type == "hexer" and w.declaration_day == w.day, "'declare hexer' sets the town's declaration")
	_check(w.living().all(func(n): return is_equal_approx(n.credibility, cred0[n.id])), "a first declaration costs nothing")
	_check(Declaration.dawn_offset(w) == 0.0, "no standing offset after a first declaration")
	_check(str(Bridge.capture(g, []).rules.declared_demon) == "hexer", "the declaration reaches every view's rules")
	_check(w.dlog.entries.any(func(e): return e.type == "declaration" and e.data.type == "hexer"), "the declaration is logged")
	_check(Declaration.declare(g, "walker") != "" and w.declared_demon_type == "hexer", "only one declaration a day")

	# Next day: changing it is a straight credibility penalty with everyone.
	w.day += 1
	_check(Declaration.declare(g, "hexer") != "", "re-declaring the same kind is refused")
	_check(Declaration.declare(g, "walker") == "" and w.declared_demon_type == "walker", "a change is accepted the next day")
	var p: float = Tuning.Trust.CRED_DECLARATION_CHANGE
	_check(w.living().all(func(n): return is_equal_approx(n.credibility, clampf(cred0[n.id] - p, Tuning.Trust.CRED_MIN, Tuning.Trust.CRED_MAX))), "a change cuts every NPC's credibility by %.2f" % p)
	_check(w.living().filter(func(n): return n.shadow != null).all(func(n): return is_equal_approx(n.shadow.credibility, n.credibility)), "evil NPCs' shadow minds pay it too")
	_check(is_equal_approx(Declaration.dawn_offset(w), p), "the change stays in the dawn target")

	# The view's declaration sets the mix; the developer override still wins.
	var view: Dictionary = {"script_demons": ["demon", "daykiller"]}
	_check(is_equal_approx(LiveActivity.day_demon_share(view), 0.5), "undeclared: the script's mix")
	view["declared_demon_type"] = "hexer"
	_check(LiveActivity.day_demon_share(view) == 1.0, "declared hexer: day demon only")
	view["declared_demon_type"] = "walker"
	_check(LiveActivity.day_demon_share(view) == 0.0, "declared walker: no day demon")
	LiveActivity.declared_demon_type = "hexer"
	_check(LiveActivity.day_demon_share(view) == 1.0, "the developer override wins over the view")
	LiveActivity.declared_demon_type = ""

	_belief_check()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

## Play a two-kind game to a later meeting: declaring moves the town's beliefs, and the
## right kind raises the town's mean chance on the true Demon over the wrong kind.
func _suspicion(g, id: String) -> float:
	var s := 0.0
	var k := 0
	for n in g.w.living_good():
		if n.id != id:
			s += float(n.suspicion.get(id, 0.0))
			k += 1
	return s / maxf(1.0, k)

func _to_meeting(seed_v: int, force: String):
	var g = _game(["demon", "daykiller"], seed_v, force)
	var guard := 0
	while g.state != "over" and not (g.state == "meeting" and g.w.day >= 3) and guard < 300:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	return g

func _belief_check() -> void:
	var moved := 0
	var right_higher := 0
	var games := 0
	for run in [[11, "demon"], [12, "demon"], [13, "demon"], [15, "demon"], [12, "daykiller"], [13, "daykiller"], [16, "daykiller"], [17, "daykiller"]]:
		# Each game is played and declared before the next is built: a new case resets
		# shared static state the earlier game's refresh would read.
		var g = _to_meeting(run[0], run[1])
		if g.state != "meeting":
			continue
		games += 1
		var demon: String = g.w.demon_id
		var truth: String = Declaration.type_of(g.w.by_id[demon].role)
		var before: float = _suspicion(g, demon)
		GameMeeting._meeting_command(g, "declare", truth)
		var right: float = _suspicion(g, demon)
		# The same game replayed, declared wrong (one declaration each, so no penalty either way).
		var g2 = _to_meeting(run[0], run[1])
		GameMeeting._meeting_command(g2, "declare", "walker" if truth == "hexer" else "hexer")
		var wrong: float = _suspicion(g2, demon)
		print("  seed %d (%s): town on the Demon %.3f undeclared, %.3f declared right, %.3f declared wrong" % [run[0], truth, before, right, wrong])
		if absf(right - before) > 0.001 or absf(wrong - before) > 0.001:
			moved += 1
		if right > wrong:
			right_higher += 1
	_check(games >= 3, "enough games reach a day-3 meeting (%d)" % games)
	# Not every game: a town holding no movement or day evidence on the Demon has nothing to reweigh.
	_check(moved * 4 >= games * 3, "declaring moves the town's beliefs on the Demon in most games (%d of %d)" % [moved, games])
	_check(right_higher * 2 > games, "the right kind puts more on the Demon than the wrong kind (%d of %d)" % [right_higher, games])
