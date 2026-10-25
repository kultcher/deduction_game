extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const C = preload("res://sim/content.gd")
var checks = 0
var fails = 0

func _init() -> void:
	check(C.SHARED_EXECUTION_PRIORITY_WEIGHT == 0.0, "Q3 stays deferred with a fixed zero action weight")
	for size in [7, 10]:
		_live(size)
	_decisions()
	print("Shared action plumbing: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _live(size: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, size)
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener != null:
				listener.info_log = []
				listener.known_claims = {}
				listener.beliefs = []
				listener.ledger = {}
				listener.workshop_state = {"enabled": true, "reasoning_mode": "full", "confidence_mode": "scale"}
	var source = g.w.living_good()[0]
	var target = g.w.living_good()[1]
	var reading = {"day": 0, "phase": 0, "role": "surveyor", "data": {"count": 2}, "text": "Two evil blocks"}
	for n in g.w.living():
		Mind.apply_info(g.w, n, source, reading, 0.5)
		var listener = n.shadow if n.is_evil() else n
		check(listener.workshop_state.active and listener.workshop_state.action.basis == "attended_posterior" and not listener.workshop_state.action.tuned, "a live shared solve supplies an explicitly provisional action for " + n.id)
		var key: String = n.id + (":cover" if n.is_evil() else ":good")
		var proposal: Dictionary = g._workshop_evaluations[key].proposal
		check(proposal.action.execution_priority.keys() == proposal.effects.keys() and proposal.effects.keys().all(func(id): return is_equal_approx(Mind.execution_priority(listener, id), proposal.effects[id].posterior)), "action inputs reuse the attended posterior without another solve")
		check(Mind.execution_priority_contribution(listener, target.id) == 0.0, "the new action input makes no decision contribution")
	var observer = target
	var before = observer.suspicion.duplicate(true)
	var rng = g.w.rng.state
	var action = observer.workshop_state.action.duplicate(true)
	Mind.recompute_beliefs(g.w, observer, "same action inputs")
	check(observer.workshop_state.action == action and observer.suspicion == before and g.w.rng.state == rng, "action refresh is repeatable and changes neither evidence nor RNG")
	g.set_workshop_effects(false)
	check(g.w.living().all(func(n): return not (n.shadow if n.is_evil() else n).workshop_state.has("action")), "disabling shared assessment removes every good/cover action")
	check(Mind.execution_priority(observer, source.id) == 0.0, "inactive action reads supply no stale score")
	g.set_workshop_effects(true)
	check(observer.workshop_state.active and observer.workshop_state.has("action"), "supported evidence restores its action with ownership")
	# Anonymous accounts are now weak teller testimony, without a gift identity.
	Mind.apply_info(g.w, observer, source, reading, 0.25, source.id, true)
	check(observer.workshop_state.active and observer.workshop_state.has("action"), "supported anonymous testimony retains a current shared action")
	# A genuine capability failure must still remove the previous action.
	var invalid: Dictionary = reading.duplicate(true)
	invalid.data.count = 99
	Mind.apply_info(g.w, observer, source, invalid, 0.5)
	check(not observer.workshop_state.active and not observer.workshop_state.has("action") and Mind.execution_priority(observer, source.id) == 0.0, "invalid report content clears the previous action")
	check(Shared.evaluate({"ready": false}, {}, {}).is_empty() and not Shared.evaluate({"ready": true, "empty": true}, {}, {}).has("action"), "failed and evidence-free plans do not manufacture an action")

func _decisions() -> void:
	var g = Game.new()
	g.workshop_effects = false
	g.detailed_logging = true
	g.new_case(7101, 7)
	var w = g.w
	w.workshop_refresh = Callable() # Hold controlled action inputs fixed for parity.
	w.day = 3
	w.meeting = {"block": "", "nominated": []}
	var listener = w.living_good()[0]
	var target = w.living_good()[1]
	listener.ledger = {}
	listener.known_claims = {}
	listener.cleared = {}
	listener.traits.confidence = 0.5
	listener.trust_at_reconsider = listener.trust
	for id in listener.suspicion:
		listener.suspicion[id] = 0.1
	var rng = w.rng.state
	for suspicion in [-0.2, 0.45, 0.5, 0.62, 0.9, 1.6]:
		listener.suspicion[target.id] = suspicion
		var votes: Array = []
		var nominations: Array = []
		for priority in [0.0, 1.0]:
			listener.workshop_state = {"active": true, "action": {"execution_priority": {target.id: priority}}}
			votes.append(Mind.vote(w, listener, target.id, "player", false, "", 0))
			nominations.append(Mind._good_nomination(w, listener, w.meeting, ""))
		check(votes[0] == votes[1] and nominations[0] == nominations[1], "zero weight preserves voting and nomination at suspicion " + str(suspicion))
	var evaluations = w.dlog.trace_events().filter(func(event): return event.type == "decision" and event.data.kind == "vote" and event.data.stage == "evaluation" and event.actor == listener.id)
	for index in range(0, evaluations.size(), 2):
		var low: Dictionary = evaluations[index].data.details
		var high: Dictionary = evaluations[index + 1].data.details
		check(low.score == high.score and low.margin == high.margin and low.threshold == high.threshold and low.parts == high.parts, "zero weight preserves the exact vote equation and margin")
		check(low.shared_execution_priority == 0.0 and high.shared_execution_priority == 1.0 and high.shared_execution_weight == 0.0, "decision traces expose the unused shared input and its zero coefficient")
	check(w.rng.state == rng, "the action plumbing draws no game RNG")
	listener.workshop_state.active = false
	check(Mind.execution_priority(listener, target.id) == 0.0, "even a stored maximum score is ignored after ownership is inactive")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
