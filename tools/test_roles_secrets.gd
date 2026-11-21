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
	_test_burden_claim()
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


## A claimed burden (burdens prototype): a good claimant knows their own burden, so their
## Marked claim holds; an evil claimant may be bluffing. So a lone claim makes "X is Marked"
## likely but not certain (X may be evil), and two claims can't both come from good people.
func _test_burden_claim() -> void:
	var RC = preload("res://workshop/role_constraints.gd")
	var was_bind: bool = RC.burden_claims_bind
	RC.burden_claims_bind = true
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var claim = func(who: int, cid: String) -> Dictionary:
		return {"id": cid, "fact_id": cid, "kind": "secret_claim", "source": people[who].id, "subject": people[who].id,
			"observed_at": {"day": 1, "phase": "day"}, "night": -1, "applies": {"from": 0, "through": 1},
			"data": {"secret_kind": "marked"}, "text": "%s says they are Marked" % people[who].name}
	var view: Dictionary = {
		"people": people, "evil_count": 2, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": ["delusional", "marked"], "roles": true, "identities": true, "bluffs": true},
	}
	var c1: Dictionary = claim.call(1, "bc1")
	var c2: Dictionary = claim.call(2, "bc2")
	view["cards"] = [c1]
	var case_m = Solver.empty_case()
	case_m.conclusion = {"type": "marked", "target": people[1].id, "at": "Original alignment"}
	case_m.cards = ["bc1"]
	var ev: Dictionary = CaseEval.evaluate(view, case_m)
	print("Marked claim: P(claimant is Marked) %.3f -> %.3f" % [ev.prior, ev.posterior])
	# Counted over the worlds: a good claimant must hold it (5 teams of 15 leave the claimant
	# good, 1 layout each: 30 worlds); an evil claimant's claim says nothing (6 teams, 10
	# layouts: 120). So 30 / 150 = 0.2, from a prior of 1 in 14.
	_check(absf(ev.posterior - 0.2) < 0.01, "a lone Marked claim lifts its claimant's chance of being Marked to the honest count (%.3f -> %.3f, want 0.200)" % [ev.prior, ev.posterior])
	# The usual case: the claim answers a Seer's yes on the claimant. Being Marked then explains
	# the reading, and the claim moves it further.
	var seer: Dictionary = {"id": "bs1", "fact_id": "bs1", "kind": "report", "role": "seer", "source": people[4].id,
		"observed_at": {"day": 0, "phase": "night"}, "night": 0, "data": {"pair": [people[1].id, people[3].id], "yes": true}, "text": "Seer yes"}
	view["cards"] = [seer]
	var case_r = Solver.empty_case()
	case_r.conclusion = case_m.conclusion
	case_r.cards = ["bs1"]
	var ev_r: Dictionary = CaseEval.evaluate(view, case_r)
	view["cards"] = [seer, c1]
	var case_rc = Solver.empty_case()
	case_rc.conclusion = case_m.conclusion
	case_rc.cards = ["bs1", "bc1"]
	var ev_rc: Dictionary = CaseEval.evaluate(view, case_rc)
	print("Seer yes on the claimant: P(Marked) %.3f without the claim, %.3f with it" % [ev_r.posterior, ev_rc.posterior])
	_check(ev_rc.posterior > ev_r.posterior + 0.1 and ev_rc.posterior < 0.95, "after a Seer's yes, the Marked claim raises the claimant's chance of being Marked, short of certain (%.3f -> %.3f)" % [ev_r.posterior, ev_rc.posterior])
	view["cards"] = [c1]
	var both: Array = Solver.solve(view, [c1, c2]).worlds
	var both_good: bool = both.any(func(w): return not (int(w.evil) & (1 << 1)) and not (int(w.evil) & (1 << 2)))
	_check(not both.is_empty() and not both_good, "two Marked claims can't both come from good people (%d worlds left)" % both.size())
	RC.burden_claims_bind = was_bind
