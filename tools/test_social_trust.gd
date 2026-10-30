## Social and trust pass, phase 1 (Oct 30, docs/social_trust_pass.md).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Credibility = preload("res://game/credibility.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _game(sd: int = 4):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 10)
	return g

func _init():
	var g = _game()
	var w = g.w
	# Setup: bonds don't touch suspicion; rapport doesn't depend on Privacy.
	# (The shared model's own vector is applied at case start; the layer it doesn't own is the setup.)
	var flat = w.npcs.all(func(n): return n.workshop_state.is_empty() or n.workshop_state.get("outside", {}).values().all(func(s): return is_equal_approx(s, Tuning.Setup.INITIAL_SUSPICION_BASE)))
	_check(flat, "friends, rivals and Lovers all start at the base suspicion")
	_check(w.npcs.all(func(n): return n.trust >= 0.375 - 0.0001 and n.trust <= 0.525 + 0.0001), "starting rapport is base 0.425 plus jitter, whatever the Privacy")
	_check(w.npcs.all(func(n): return is_equal_approx(n.credibility, Tuning.Trust.CREDIBILITY_START)), "credibility starts neutral")
	# Fading slights.
	var n = w.living_good()[0]
	n.trust = 0.6
	Mind.set_trust(w, n, 0.4, "the Demonologist pressed me too hard")
	var g0: Dictionary = n.grievances.back()
	Mind.fade_slights(w, n)
	_check(absf(n.trust - (0.4 + 0.2 * Tuning.Trust.GRIEVANCE_FADE)) < 0.001, "a night gives back a quarter of a slight (%.3f)" % n.trust)
	for i in range(10):
		Mind.fade_slights(w, n)
	_check(g0.serious and absf(n.trust - (0.4 + 0.2 * Tuning.Trust.SERIOUS_FADE_LIMIT)) < 0.001, "a serious slight fades only halfway (%.3f)" % n.trust)
	var m = w.living_good()[1]
	m.trust = 0.5
	Mind.set_trust(w, m, 0.49, "a question too many")
	_check(m.friction > 0.0 and m.grievances.is_empty(), "small slights collect as friction, not grievances")
	for i in range(20):
		Mind.fade_slights(w, m)
	_check(absf(m.trust - 0.5) < 0.001, "friction fades back fully")
	# Gossip cutoff gone.
	m.traits.gossip = 0.05
	m.pressure = 0.0
	_check(Mind._gossip_share(w, m, "test") >= 1, "the least talkative still share one thing")
	# Credibility from the track record: claims that agree with the listener's own reading
	# raise it; claims against it lower it.
	var g2 = _game(15)
	var listener = g2.w.npc_with_role("seer")
	var reading: Dictionary = listener.info_log[0]
	var pair: Array = reading.data.pair
	var agree: String = "evil" if reading.data.yes else "good"
	var disagree: String = "good" if reading.data.yes else "evil"
	for id in pair:
		Credibility.record(listener, agree, id, 1)
	Credibility.dawn(g2)
	_check(listener.credibility > 0.5, "claims that match the listener's own %s reading raise credibility (%.3f)" % [agree, listener.credibility])
	listener.claim_record = {}
	listener.credibility = 0.5
	for id in pair:
		Credibility.record(listener, disagree, id, 1)
	Credibility.dawn(g2)
	_check(listener.credibility < 0.5, "claims against the listener's own reading lower credibility (%.3f)" % listener.credibility)
	listener.claim_record = {}
	listener.credibility = 0.5
	Credibility.dawn(g2)
	_check(is_equal_approx(listener.credibility, 0.5), "with no claims, credibility doesn't move")
	print("Social trust: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
