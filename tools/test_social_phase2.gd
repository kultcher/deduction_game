## Social and trust pass, phase 2 (Oct 30, docs/social_trust_pass.md).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const Social = preload("res://sim/social.gd")
const Jury = preload("res://workshop/jury.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init():
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(4, 10)
	var w = g.w
	var n = w.living_good()[0]
	# Disclosure mood: one sample per NPC per day, no world RNG.
	var state = w.rng.state
	var t1 = MindDialogue._target_tier(w, n)
	var t2 = MindDialogue._target_tier(w, n)
	_check(t1 == t2 and w.rng.state == state, "asking twice the same day gets the same disclosure mood and draws no RNG")
	# Secret-keeping gratitude shrinks.
	n.secret_known = true
	n.secret_spread = false
	n.trust = 0.3
	Mind.end_of_day_trust(w)
	var first: float = n.trust - 0.3
	var mid: float = n.trust
	Mind.end_of_day_trust(w)
	var second: float = n.trust - mid
	_check(first > 0.0 and absf(second - first * Tuning.Trust.SECRET_KEPT_DECAY) < 0.001, "the second night's secret-keeping gain is half the first (%.3f, %.3f)" % [first, second])
	# Gossip bond.
	var l = w.living_good()[1]
	var s = w.living_good()[2]
	var friend = w.living_good()[3]
	l.npc_trust[friend.id] = 0.8
	l.suspicion[s.id] = 0.1
	_check(Social.gossip_bond(l, s, {"kind": "opinion", "about": friend.id}) < 0.0, "running down someone the listener trusts costs the teller")
	_check(Social.gossip_bond(l, s, {"kind": "sighting", "about": w.living_good()[4].id}) > 0.0, "a believed share builds trust in the teller")
	l.suspicion[s.id] = 0.7
	_check(is_zero_approx(Social.gossip_bond(l, s, {"kind": "sighting", "about": w.living_good()[4].id})), "a share from a suspected teller builds nothing")
	# Grief only for a friend the mourner didn't believe evil.
	var ex = w.living_good()[5]
	var mourner = w.living_good()[6]
	mourner.npc_trust[ex.id] = 0.9
	mourner.trust = 0.6
	mourner.suspicion[ex.id] = 0.8
	w._grief(ex, {"by": "player", "yes": []})
	_check(is_equal_approx(mourner.trust, 0.6), "no grief over a friend the mourner believed evil")
	mourner.suspicion[ex.id] = 0.1
	w._grief(ex, {"by": "player", "yes": []})
	_check(mourner.trust < 0.6, "grief over a friend the mourner believed good")
	# Directional Confidence.
	var c: float = 1.4 - 0.8 * 0.9
	_check(is_equal_approx(Jury._directional(c, -0.1, 0.3, false), c), "a confident listener resists clearing someone they lean against")
	_check(is_equal_approx(Jury._directional(c, 0.1, 0.3, false), 1.0), "reinforcing evidence comes through at full strength")
	_check(is_equal_approx(Jury._directional(c, 0.1, 0.01, false), 1.0), "fresh evidence about someone with no lean comes through at full strength")
	print("Social phase 2: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
