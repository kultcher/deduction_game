## The Gravedigger in a reluctant town (Michael, Nov 17 and Nov 21): a good Gravedigger
## always leans a little toward nominating and voting to hang, since its gift reads the
## hanged. It's a hidden motive: in the nomination's logged score and the vote's parts, never
## said. It stays after a hanging and with a broken gift (which it can't know), and never
## applies to evil or another role.
extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 2
	var n = g.w.living_good()[0]
	n.role = "gravedigger"
	var gd = C.role_def("gravedigger")
	var lean: float = Tuning.Roles.GRAVEDIGGER.hanging_lean
	_check(is_equal_approx(gd.nomination_lean(g.w, n), lean), "a good Gravedigger leans toward nominating")
	var parts: Dictionary = {}
	gd.score_vote_reluctance(g.w, n, g.w.living_good()[1].id, 0.3, 0.0, parts)
	_check(is_equal_approx(float(parts.get("gravedigger_wants_hanging", 0.0)), lean), "and toward voting to hang, as a logged vote part")
	_check(lean > 0.0 and lean <= 0.15, "the lean is modest")
	var other = g.w.living_good()[1]
	other.role = "seer"
	_check(is_zero_approx(C.role_def("seer").nomination_lean(g.w, other)), "other roles have no lean")
	var e = g.w.npcs.filter(func(m): return m.is_evil())[0]
	var real_role: String = e.role
	e.role = "gravedigger"
	_check(is_zero_approx(gd.nomination_lean(g.w, e)), "evil never takes the lean")
	e.role = real_role
	n.poisoned = true
	_check(is_equal_approx(gd.nomination_lean(g.w, n), lean), "a broken gift it can't know about keeps the lean")
	n.poisoned = false
	g.w.executions.append({"day": 1, "id": other.id})
	_check(is_equal_approx(gd.nomination_lean(g.w, n), lean), "the lean stays after someone has been hanged")
	parts = {}
	gd.score_vote_reluctance(g.w, n, g.w.living_good()[1].id, 0.3, 0.0, parts)
	_check(is_equal_approx(float(parts.get("gravedigger_wants_hanging", 0.0)), lean), "and so does the vote part")
	print("Gravedigger lean: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
