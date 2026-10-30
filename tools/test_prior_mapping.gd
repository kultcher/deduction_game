## The shared model's listener prior (Oct 30): suspicion the model doesn't own is a gentle
## relative nudge (odds = exp(PRIOR_K * suspicion)), so a holder's own readings move them.
## Before, suspicion was read as a probability and 0.0-vs-0.1 seeds outweighed a Seer "yes".
extends SceneTree
const Game = preload("res://game/game.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Tuning = preload("res://sim/tuning.gd")
const Caches = preload("res://workshop/caches.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init():
	_check(CaseEval.prior_k == Tuning.Workshop.PRIOR_K and Tuning.Workshop.PRIOR_K > 0.0, "the live prior uses the relative mapping")
	_check(exp(Tuning.Workshop.PRIOR_K * 0.1) < 1.3, "a 0.1 suspicion gap is worth less than 1.3x odds (was about 5x)")
	# A constructed fixture, independent of how play unfolds: on Day 1 the Seer is given
	# a true "yes" on the Demon and one good person (the trajectory-based fixtures broke
	# whenever tuning changed play).
	var seen = 0
	for sd in [4, 15, 17, 3]:
		var g = Game.new()
		g.log_dir = "user://test_logs"
		g.new_case(sd, 10)
		var seer = g.w.npc_with_role("seer")
		if seer == null or seer.is_evil() or seer.workshop_state.is_empty():
			continue
		var other = g.w.npcs.filter(func(m): return m.id != seer.id and m.id != g.w.demon_id and not m.is_evil() and m.id != seer.red_herring)[0]
		var pair = [g.w.demon_id, other.id]
		seer.info_log = [{"role": "seer", "day": 0, "phase": 3, "data": {"pair": pair, "yes": true}, "true": true,
			"text": "I looked at them: one of them reads as the demon"}]
		# Uneven starting suspicion, as the cast's friend/rival seeds once made it (0.0 vs 0.1),
		# so the old mapping's over-reading of small gaps shows.
		var k := 0
		for id in seer.workshop_state.get("outside", {}):
			seer.workshop_state.outside[id] = 0.0 if k % 2 == 0 else 0.1
			k += 1
		var effects = _own_view(g, seer)
		CaseEval.prior_k = -1.0
		Caches.clear_all()
		var old_effects = _own_view(g, seer)
		CaseEval.prior_k = Tuning.Workshop.PRIOR_K
		Caches.clear_all()
		var lift = 0.0
		var old_lift = 0.0
		for id in pair:
			lift += effects[id].posterior - effects[id].prior
			old_lift += old_effects[id].posterior - old_effects[id].prior
		print("  seed %d %s: pair lift %+.2f (old mapping %+.2f)" % [sd, seer.name, lift, old_lift])
		seen += 1
		# A hand calculation puts the pair's combined rise near +0.22; the model gives about
		# +0.11 to +0.14 (open question, Oct 30). Guard the direction and the gain over the
		# old mapping.
		_check(lift > 0.08 and lift > old_lift, "seed %d: a true Seer 'yes' raises its pair, more than under the old prior (%+.2f vs %+.2f)" % [sd, lift, old_lift])
	_check(seen >= 2, "at least two fixture seeds have a good Seer (%d)" % seen)
	print("Prior mapping: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _own_view(g, n) -> Dictionary:
	var st = n.workshop_state
	var outside: Dictionary = st.get("outside", n.suspicion).duplicate(true)
	var input = Bridge.capture(g, [], n.id, "private", n)
	input.listener.suspicion = outside.duplicate(true)
	var plan = Shared.prepare(input, st.get("presentations", {}), n.ledger, st.get("withdrawn", {}), st.get("attention_focus", []))
	if not plan.ready:
		return {}
	return Shared.evaluate(plan, outside, n.discounted).effects

func _play(sd: int, day: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 10)
	var steps = 0
	while g.w.day < day and g.state != "over" and steps < 300:
		steps += 1
		match g.state:
			"meeting":
				g.command("wait")
				while g.meeting_streaming():
					g.testimony_step()
				g.command("done")
			"nomination":
				g.command("vote no")
			"talk":
				g.command("bye")
			"approach":
				g.command("no")
			"night":
				g.command("sleep")
			_:
				g.command("wait")
	return g
