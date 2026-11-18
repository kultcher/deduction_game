## Backing a case builds trust (BACKLOG, Michael, Nov 18):
## - a good NPC warms a little to those who vote the same way it does;
## - and to someone who nominates or accuses a person it already suspects;
## - a reading that clears a good listener raises its trust in the teller, and one that agrees
##   with the listener's own reading does too, by less;
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
	_readings()
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

func _readings() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var l = goods[0]
	var teller = goods[1]
	var x = goods[2]
	var y = goods[3]
	l.npc_trust = {}
	# A Seer "neither is the Demon" over the listener: it clears them.
	Mind.apply_info(w, l, teller, {"day": 1, "role": "seer", "data": {"pair": [l.id, x.id], "yes": false}, "text": "clears me"}, 1.0)
	var after_clear: float = l.npc_trust.get(teller.id, 0.5)
	_check(is_equal_approx(after_clear, 0.5 + Tuning.Roles.WARDEN_SAVE_TRUST), "a reading that clears me raises my trust in its teller (%.3f)" % after_clear)
	Mind.apply_info(w, l, teller, {"day": 1, "role": "seer", "data": {"pair": [l.id, x.id], "yes": false}, "text": "clears me"}, 1.0)
	_check(is_equal_approx(l.npc_trust.get(teller.id, 0.5), after_clear), "hearing the same reading again adds nothing")
	# The listener's own reading pointed at y; a teller's Dowser count pointing at y agrees.
	var t2 = goods[4]
	l.info_log.append({"day": 1, "role": "seer", "data": {"pair": [y.id, x.id], "yes": true}, "text": "mine", "shared": false, "true": true})
	Mind.apply_info(w, l, t2, {"day": 2, "role": "dowser", "data": {"group": [y.id, goods[5].id], "count": 1, "block": "market"}, "text": "agrees"}, 1.0)
	_check(is_equal_approx(l.npc_trust.get(t2.id, 0.5), 0.5 + Tuning.Social.TRUST_VOTED_FOR), "a reading that agrees with my own raises my trust a little (%.3f)" % l.npc_trust.get(t2.id, 0.5))
	# A reading that neither clears me nor agrees with me changes nothing.
	var t3 = goods[5]
	Mind.apply_info(w, l, t3, {"day": 2, "role": "seer", "data": {"pair": [goods[6].id, t2.id], "yes": false}, "text": "unrelated"}, 1.0)
	_check(not l.npc_trust.has(t3.id), "an unrelated reading changes nothing")
	# An evil listener's own trust doesn't move.
	var e = w.evil_team()[0]
	e.npc_trust = {}
	Mind.apply_info(w, e, teller, {"day": 2, "role": "seer", "data": {"pair": [e.id, x.id], "yes": false}, "text": "clears evil"}, 1.0)
	_check(not e.npc_trust.has(teller.id), "an evil listener's own trust doesn't move")
