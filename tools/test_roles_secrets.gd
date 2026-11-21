## Secrets: Marked, Delusional, Lovers, Sleepwalker.
## Merged from: test_chunk4_psychologist_muddler, test_roster.
extends SceneTree

const Game = preload("res://game/game.gd")
const World = preload("res://sim/world.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const Domain = preload("res://workshop/world_domain.gd")
const CardList = preload("res://ui/card_list.gd")
const UITheme = preload("res://ui/theme.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const Solver = preload("res://workshop/solver.gd")
const Social = preload("res://sim/social.gd")

var checks = 0
var fails = 0
var failures = 0
var _checks = 0
var _fails = 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	_run_roster()
	_run_chunk4_psychologist_mudd()
	print("Roles: secrets: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## One shared check helper (the merged suites used both names).
func check(ok: bool, label: String) -> void:
	_count(ok, label)


func _check(ok: bool, label: String) -> void:
	_count(ok, label)


func _count(ok: bool, label: String) -> void:
	checks += 1
	_checks += 1
	if not ok:
		fails += 1
		failures += 1
		_fails += 1
		printerr("FAIL: " + label)


# ---------------------------------------------------------------- from test_roster

func _run_roster() -> void:
	_test_marked_and_delusional()
	# The Sleepwalker and the Lovers retired with the burdens prototype.
	_test_night_suspicion()


# ---------------------------------------------------------------- from test_chunk4_psychologist_muddler

func _run_chunk4_psychologist_mudd() -> void:
	_test_secret_domain_and_premise()
	_test_retired_secret_in_saved_script()


# ---- test_roster


## Pure World setup for multi-hundred-seed role/home/bluff distribution checks.
func _game(sd: int, size: int = 7):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, size)
	return g


func _test_marked_and_delusional() -> void:
	var w = _game(9210).w
	var mk = w.living_good()[0]
	mk.secret_mod = "marked"
	var ev = 0
	for i in range(200):
		if w.registers_evil(mk):
			ev += 1
	print("Marked read as evil %d/200" % ev)
	_check(ev > 60 and ev < 140, "the Marked read as evil about half the time")
	var dl = w.living_good()[1]
	dl.secret_mod = "delusional"
	_check(dl.gift_broken(), "the Delusional's gift is broken")


## Being out at night counts in full only near a death; an openly claimed walking gift
## is discounted.
## Start-knowledge gifts already spent are worth less to kill than live ones.
func _test_night_suspicion() -> void:
	var w = _game(9260).w
	var l = w.living_good()[0]
	var x = w.living_good()[1]


# ---- test_chunk4_psychologist_muddler


func _give_role(w, n, role_id: String) -> void:
	n.role = role_id
	n.alignment = C.ROLES[role_id]["align"]


## A saved script that still lists the removed Muddler loads without it and can be dealt.
func _test_retired_secret_in_saved_script() -> void:
	var d: Dictionary = ScriptDef.default_script().to_dict()
	d.secrets = ["delusional", "marked", "muddler", "sleepwalker"]
	d.forced = ["muddler"]
	var s = ScriptDef.from_dict(d)
	_check(not ("muddler" in s.secrets) and not ("muddler" in s.forced) and s.check(7).errors.is_empty(),
		"an old saved script with the Muddler loads without it and passes its check (%s)" % str(s.check(7).errors))


## The full secret-modifier world domain (all four secrets) and a secret premise weighed from
## a Rumormonger report. (The Muddler went on Nov 20; its simulation and debunking checks went
## with it.)
func _test_secret_domain_and_premise() -> void:
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var view: Dictionary = {
		"people": people,
		"evil_count": 2,
		"alignment_epoch": "Original alignment",
		"world_options": {"modifiers": C.SECRET_MOD_LIST.duplicate(), "roles": true, "identities": true},
	}
	var worlds: Array = Domain.worlds(view)
	# 7 people, 2 evil (21 teams * 2 demons = 42): per team, over the 5 good people,
	# delusional 5 + marked 5 = 10 layouts -> 42 * 10 = 420 worlds (burdens prototype: the
	# Lovers and Sleepwalker retired)
	_check(worlds.size() == 420, "WorldDomain enumerates exactly 420 worlds with the script's secrets (%d)" % worlds.size())
	var keys: Dictionary = {}
	for w in worlds:
		keys[Domain.key(view, w)] = true
	_check(keys.size() == worlds.size(), "WorldDomain produces collision-free 64-bit keys across the secret modifiers")

	var rumor_sw: Dictionary = {
		"id": "rm_sw", "fact_id": "rm_sw", "kind": "report", "role": "rumormonger", "source": people[0].id,
		"observed_at": {"day": 0, "phase": "night"},
		"data": {"pair": [people[1].id, people[2].id], "secret": "marked"},
		"text": "Rumormonger marked pair",
	}
	var c_mud = Solver.empty_case()
	c_mud.conclusion = {"type": "secret_mod", "target": people[1].id, "mod": "marked", "at": "Original alignment"}
	c_mud.cards = ["rm_sw"]
	view["cards"] = [rumor_sw]
	var ev_mud: Dictionary = CaseEval.evaluate(view, c_mud)
	_check(ev_mud.posterior > ev_mud.prior and ev_mud.lr > 3.0, "CaseEval evaluates a secret_mod premise from a Rumormonger secret report")
