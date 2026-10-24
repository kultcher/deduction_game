## The crowd can influence action without supplying alignment evidence.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
var checks = 0
var fails = 0

func _init() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = true
	g.new_case(7101, 7)
	var w = g.w
	var listener = w.living_good()[0]
	var target = w.npcs.filter(func(n): return n != listener)[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.ledger = {}
	listener.cleared = {}
	listener.role = "surveyor"
	listener.traits.confidence = 0.5
	w.day = 3
	w.meeting = {"block": "", "nominated": []}
	for id in listener.suspicion:
		listener.suspicion[id] = 0.1
	listener.suspicion[target.id] = 0.45
	var before = JSON.stringify([listener.suspicion, listener.ledger, listener.honesty, listener.discounted, listener.npc_trust, listener.trust, w.rng.state])
	for accuser in w.npcs:
		if accuser != listener and accuser != target:
			w.stances[accuser.id] = {"target": target.id, "day": w.day}
	Mind.refresh_consensus(w, listener, target.id)
	var pressure: float = listener.consensus_pressure[target.id]
	check(pressure > 0.1 and pressure <= Mind.CONSENSUS_CAP, "existing chorus weights and cap remain social pressure")
	check(before == JSON.stringify([listener.suspicion, listener.ledger, listener.honesty, listener.discounted, listener.npc_trust, listener.trust, w.rng.state]), "accusations change no evidence, credibility, trust or randomness")
	var pressured_vote: bool = Mind.vote(w, listener, target.id, "player", false, "", 0)
	var nomination = Mind._good_nomination(w, listener, w.meeting, "")
	listener.consensus_pressure[target.id] = 0.0
	listener.suspicion[target.id] += pressure
	var old_vote: bool = Mind.vote(w, listener, target.id, "player", false, "", 0)
	var old_nomination = Mind._good_nomination(w, listener, w.meeting, "")
	check(pressured_vote == old_vote, "the vote keeps the old score when the same crowd weight is moved out of suspicion")
	check(nomination != null and old_nomination != null and nomination.nominee == old_nomination.nominee and is_equal_approx(nomination.score, old_nomination.score), "nomination ranking, thresholds and score retain the existing crowd weight")
	listener.suspicion[target.id] -= pressure
	listener.consensus_pressure[target.id] = pressure
	var evaluations = w.dlog.trace_events().filter(func(e): return e.type == "decision" and e.data.kind == "vote" and e.data.stage == "evaluation" and e.actor == listener.id)
	check(evaluations.size() == 2 and is_equal_approx(evaluations[0].data.details.score, evaluations[1].data.details.score), "trace scores verify exact action equivalence")
	check(evaluations[0].data.details.parts.town_pressure > 0 and evaluations[1].data.details.parts.town_pressure == 0, "vote explanations distinguish evidence from social pressure")
	listener.suspicion[target.id] = -0.4
	listener.consensus_pressure[target.id] = 0.2
	check(Mind.susp(listener, target.id) == 0 and Mind.action_susp(listener, target.id) == 0, "action clamping uses the raw evidence sum before adding pressure")
	w.stances.clear()
	Mind.refresh_all_consensus(w)
	check(listener.consensus_pressure.get(target.id, 0.0) == 0, "withdrawing the final stance clears the social pressure")
	print("Social evidence boundary: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
