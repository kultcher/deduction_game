## Backing a case builds trust (BACKLOG, Michael, Nov 18):
## - a good NPC warms a little to those who vote the same way it does;
## - and to someone who nominates or accuses a person it already suspects;
## - (the reading-based steps moved to "Trust from readings that confirm what I know or
##   strongly believe", Michael, Nov 19; a plain reading changes no trust here);
## - evil NPCs' own trust isn't moved, and nothing changes for an NPC that doesn't agree.
extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Mind = preload("res://sim/mind.gd")
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
	_votes()
	_backing()
	_readings_unchanged()
	print("Agreement trust: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _world():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	return g.w

func _votes() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var evil = w.evil_team()[0]
	var a = goods[0]
	var b = goods[1]
	var c = goods[2]
	var nominee = goods[3]
	for x in [a, b, c, evil]:
		x.npc_trust = {}
	Social.vote_agreement_trust(w, nominee.id, [a.id, b.id, evil.id], [c.id])
	var step: float = Tuning.Social.TRUST_VOTED_FOR
	_check(is_equal_approx(a.npc_trust.get(b.id, 0.5), 0.5 + step), "a good voter warms to another who voted the same way (%.3f)" % a.npc_trust.get(b.id, 0.5))
	_check(is_equal_approx(a.npc_trust.get(evil.id, 0.5), 0.5 + step), "including an evil one, who looks like an ally")
	_check(not a.npc_trust.has(c.id), "not to one who voted the other way")
	_check(evil.npc_trust.is_empty(), "an evil voter's own trust doesn't move")
	_check(not c.npc_trust.has(a.id), "a lone voter on its side gains nothing")
	# A second ballot the same day adds nothing: a day of agreeing is one agreement.
	Social.vote_agreement_trust(w, goods[4].id, [a.id, b.id], [])
	_check(is_equal_approx(a.npc_trust.get(b.id, 0.5), 0.5 + step), "a second agreeing vote the same day adds nothing")
	w.day += 1
	Social.vote_agreement_trust(w, goods[4].id, [a.id, b.id], [])
	_check(is_equal_approx(a.npc_trust.get(b.id, 0.5), 0.5 + 2.0 * step), "the next day's agreement counts again")

func _backing() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var l = goods[0]
	var other = goods[1]
	var accuser = goods[2]
	var target = goods[3]
	l.npc_trust = {}
	other.npc_trust = {}
	l.suspicion[target.id] = Tuning.Meeting.NOMINATION_FLOOR + 0.1
	other.suspicion[target.id] = 0.05
	Social.backing_trust(w, target.id, accuser.id, "accused %s, whom I suspect too" % target.id)
	_check(l.npc_trust.get(accuser.id, 0.5) > 0.5, "someone accusing a person I suspect gains my trust")
	_check(not other.npc_trust.has(accuser.id), "not the trust of someone who doesn't suspect them")
	_check(not target.npc_trust.has(accuser.id) or target.npc_trust[accuser.id] <= 0.5, "nor the accused's")

func _readings_unchanged() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var l = goods[0]
	var teller = goods[1]
	l.npc_trust = {}
	Mind.apply_info(w, l, teller, {"day": 1, "role": "seer", "data": {"pair": [l.id, goods[2].id], "yes": false}, "text": "clears me"}, 1.0)
	_check(not l.npc_trust.has(teller.id), "a reading that clears me changes no trust here (that's the later confirmation item)")
