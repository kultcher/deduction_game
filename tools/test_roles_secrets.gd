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
	_test_omen_window()
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
	# Impossible pairs (Michael, Nov 21): the deal's placement table never puts some burdens on
	# some gifts, so a good person can't truly claim both; one general rule, read from the table.
	var gift = func(who: int, role: String, cid: String) -> Dictionary:
		return {"id": cid, "fact_id": cid, "kind": "claim", "source": people[who].id, "subject": people[who].id, "role": role,
			"observed_at": {"day": 1, "phase": "morning"}, "text": "%s claims %s" % [people[who].name, role]}
	view.world_options.modifiers = ["delusional", "marked", "ill_omened", "unrequited"]
	var good_of = func(cards: Array, who: int) -> int:
		return Solver.solve(view, cards).worlds.filter(func(w): return not (int(w.evil) & (1 << who))).size()
	var pairs: Array = [
		["unrequited", "lamplighter", "seer", "Unrequited with a night-walking gift (a Lamplighter)"],
		["marked", "rumormonger", "seer", "a burden with the Rumormonger (never its lone holder)"],
	]
	for pr in pairs:
		var with_gift: int = good_of.call([gift.call(3, pr[1], "pg1"), claim.call(3, pr[0], "pb1")], 3)
		var gift_alone: int = good_of.call([gift.call(3, pr[1], "pg1")], 3)
		var allowed: int = good_of.call([gift.call(3, pr[2], "pg2"), claim.call(3, pr[0], "pb1")], 3)
		_check(with_gift == 0 and gift_alone > 0 and allowed > 0,
			"%s: no good claimant can claim both (%d good worlds; the gift alone %d; with a %s instead %d)" % [pr[3], with_gift, gift_alone, pr[2], allowed])
	# Unclaimed holders too (Michael, Nov 21): a good claimed gift can't hold a burden the deal
	# keeps off it, even with no burden claim. Count the good-claimant worlds where they hold one.
	var holding = func(role: String, kinds: Array) -> int:
		var ws: Array = Solver.solve(view, [gift.call(3, role, "ph1")]).worlds
		return ws.filter(func(w): return not (int(w.evil) & (1 << 3)) and (
			("marked" in kinds and int(w.get("marked", -1)) == 3)
			or (str(w.get("modifier", "")) in kinds and str(w.get("modifier", "")) != "marked" and int(w.get("holders", 0)) & (1 << 3)))).size()
	var all_burdens: Array = ["delusional", "marked", "ill_omened", "unrequited"]
	var lamp_u: int = holding.call("lamplighter", ["unrequited"])
	var lamp_other: int = holding.call("lamplighter", ["delusional", "marked", "ill_omened"])
	var rumor_any: int = holding.call("rumormonger", all_burdens)
	var seer_u: int = holding.call("seer", ["unrequited"])
	_check(lamp_u == 0 and lamp_other > 0, "a good claimed Lamplighter is never an unclaimed Unrequited holder (%d worlds), but may hold another burden (%d)" % [lamp_u, lamp_other])
	_check(rumor_any == 0, "a good claimed Rumormonger holds no burden at all (%d worlds)" % rumor_any)
	_check(seer_u > 0, "a good claimed Seer may still hold Unrequited unclaimed (%d worlds)" % seer_u)
	RC.burden_claims_bind = was_bind


## Ill-Omened (burdens prototype): a reading inside a hanged claimant's window is unhealthy in
## worlds where the claimant truly held the burden (every good person was poisoned), so it
## counts for less than the same reading outside one, but not nothing (the claimant may have
## bluffed).
func _test_omen_window() -> void:
	var people: Array = []
	for i in range(7):
		people.append({"id": C.CAST[i].id, "name": C.CAST[i].name, "home": C.BLOCKS.keys()[i % 4], "alive": i != 0})
	var view: Dictionary = {
		"people": people, "evil_count": 2, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": ["delusional", "marked", "unrequited", "ill_omened"], "roles": true, "identities": true, "bluffs": true},
	}
	var seer: Dictionary = {"id": "os1", "fact_id": "os1", "kind": "report", "role": "seer", "source": people[4].id,
		"observed_at": {"day": 2, "phase": "night"}, "night": 2, "data": {"pair": [people[1].id, people[3].id], "yes": true}, "text": "Seer yes"}
	var post = func(cards: Array) -> float:
		var cs = Solver.empty_case()
		cs.conclusion = {"type": "demon", "target": people[1].id, "at": "Original alignment"}
		cs.cards = cards.map(func(c): return c.id)
		view["cards"] = cards
		preload("res://workshop/caches.gd").clear_all()
		return float(CaseEval.evaluate(view, cs).posterior)
	# The hanged claimant restated Ill-Omened at the nomination (a real hanging arms the omen
	# only then), so the listener holds the claim in both arms.
	var omen_claim: Dictionary = {"id": "oc1", "fact_id": "oc1", "kind": "secret_claim", "source": people[0].id, "subject": people[0].id,
		"observed_at": {"day": 2, "phase": "afternoon"}, "night": -1, "applies": {"from": 0, "through": 2},
		"data": {"secret_kind": "ill_omened"}, "text": "claims Ill-Omened at the nomination"}
	var prior: float = post.call([omen_claim])
	var plain: float = post.call([omen_claim, seer])
	var poisoned: Dictionary = seer.duplicate(true)
	poisoned["omen_claimants"] = [people[0].id]
	var under: float = post.call([omen_claim, poisoned])
	print("Omen window: P(the Seer's pair-mate is the Demon) prior %.3f, the yes %.3f, the yes under a fallen omen %.3f" % [prior, plain, under])
	_check(under < plain - 0.02 and under > prior, "a reading under a fallen omen counts for less than the same reading, but still counts (%.3f < %.3f, > %.3f)" % [under, plain, prior])
