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
	# 4 burdens x 5 good holders = 20 layouts -> 42 * 20 = 840 worlds (burdens prototype: the
	# Lovers and Sleepwalker retired; Unrequited and Ill-Omened placed like the others)
	_check(worlds.size() == 840, "WorldDomain enumerates exactly 840 worlds with the script's secrets (%d)" % worlds.size())
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


## A claimed burden (burdens prototype; Michael, Nov 21, option B): a good claimant knows
## their own burden, so their claim holds; an evil one may be bluffing, weighed by the chance a
## good claimant would hold it. So a claim alone leaves its claimant as likely evil as before and
## makes them likely Marked; with one burden dealt, two claims can't both be honest, and both
## claimants look worse.
func _test_burden_claim() -> void:
	var RC = preload("res://workshop/role_constraints.gd")
	var was_bind: bool = RC.burden_claims_bind
	RC.burden_claims_bind = true
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": true})
	var claim = func(who: int, kind: String, cid: String) -> Dictionary:
		return {"id": cid, "fact_id": cid, "kind": "secret_claim", "source": people[who].id, "subject": people[who].id,
			"observed_at": {"day": 1, "phase": "day"}, "night": -1, "applies": {"from": 0, "through": 1},
			"data": {"secret_kind": kind}, "text": "%s claims a burden" % people[who].name}
	var view: Dictionary = {
		"people": people, "evil_count": 2, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": ["delusional", "marked", "ill_omened"], "roles": true, "identities": true, "bluffs": true},
	}
	var post = func(cards: Array, type: String, who: int) -> float:
		var cs = Solver.empty_case()
		cs.conclusion = {"type": type, "target": people[who].id, "at": "Original alignment"}
		cs.cards = cards.map(func(c): return c.id)
		view["cards"] = cards
		return float(CaseEval.evaluate(view, cs).posterior)
	var xm: Dictionary = claim.call(1, "marked", "bc1")
	var yi: Dictionary = claim.call(2, "ill_omened", "bc2")
	var prior: float = post.call([], "evil", 1)
	var alone: float = post.call([xm], "evil", 1)
	var marked: float = post.call([xm], "marked", 1)
	print("Marked claim: P(evil) %.3f -> %.3f, P(Marked) -> %.3f" % [prior, alone, marked])
	_check(absf(alone - prior) < 0.01 and marked > 0.6, "a Marked claim alone leaves its claimant's evil chance where it was and makes them likely Marked (%.3f -> %.3f; Marked %.3f)" % [prior, alone, marked])
	var x2: float = post.call([xm, yi], "evil", 1)
	var y2: float = post.call([xm, yi], "evil", 2)
	print("Two burden claims, one burden dealt: X %.3f, Y %.3f (prior %.3f)" % [x2, y2, prior])
	_check(x2 > prior + 0.15 and y2 > prior + 0.15, "with one burden dealt, two burden claims cast suspicion on both claimants (X %.3f, Y %.3f, prior %.3f)" % [x2, y2, prior])
	# Timing (Michael, Nov 21, revised): a claim that answers an evil reading of its claimant is
	# weighed by how often evil bluffs then, against a holder (measured, softened), so it leaves
	# the claimant about where the reading did; an earlier telling dates it and keeps it unprompted.
	var seer: Dictionary = {"id": "bs1", "fact_id": "bs1", "kind": "report", "role": "seer", "source": people[4].id,
		"observed_at": {"day": 0, "phase": "night"}, "reported_at": {"day": 1, "phase": "morning"}, "night": 0,
		"data": {"pair": [people[1].id, people[3].id], "yes": true}, "text": "Seer yes"}
	var late: Dictionary = claim.call(1, "marked", "bc4")
	late.observed_at = {"day": 1, "phase": "afternoon"}
	var early: Dictionary = claim.call(1, "marked", "bc5")
	early.observed_at = {"day": 0, "phase": "afternoon"}
	var read_only: float = post.call([seer], "evil", 1)
	var reactive: float = post.call([seer, late], "evil", 1)
	var dated: float = post.call([early, seer, late], "evil", 1)
	print("Seer yes: X evil %.3f; then X claims Marked %.3f; with an earlier telling %.3f" % [read_only, reactive, dated])
	_check(absf(reactive - read_only) < 0.05, "a Marked claim answering an evil reading leaves its claimant about where the reading left them (%.3f -> %.3f)" % [read_only, reactive])
	_check(dated < read_only, "an earlier telling dates the claim, so it isn't counted as answering the reading (%.3f against %.3f)" % [dated, read_only])
	var both: Array = Solver.solve(view, [xm, claim.call(2, "marked", "bc3")]).worlds
	var both_good: bool = both.any(func(w): return not (int(w.evil) & (1 << 1)) and not (int(w.evil) & (1 << 2)))
	_check(not both.is_empty() and not both_good, "two Marked claims can't both come from good people (%d worlds left)" % both.size())
	RC.burden_claims_bind = was_bind
