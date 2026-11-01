extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
var checks = 0
var fails = 0

func _init() -> void:
	check(is_equal_approx(C.SHARED_EXECUTION_PRIORITY_WEIGHT, Tuning.Setup.SHARED_EXECUTION_PRIORITY_WEIGHT) and C.SHARED_EXECUTION_PRIORITY_WEIGHT > 0.0, "Phase 4.2 activates listener-mean-centered shared execution priority")
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
		check(listener.workshop_state.active and listener.workshop_state.action.basis == "listener_mean_centered" and listener.workshop_state.action.tuned, "a live shared solve supplies a tuned listener-mean-centered action for " + n.id)
		var key: String = n.id + (":cover" if n.is_evil() else ":good")
		var proposal: Dictionary = g._workshop_evaluations[key].proposal
		var l_mean: float = float(proposal.action.get("listener_mean", -1.0))
		check(proposal.action.execution_priority.keys() == proposal.effects.keys() and l_mean >= 0.0 and proposal.effects.keys().all(func(id):
			var post_v: float = float(proposal.effects[id].posterior)
			var ep_v: float = Mind.execution_priority(listener, id)
			return is_zero_approx(ep_v) if (id == listener.id or post_v <= l_mean + 1e-6) else ep_v > 0.0
		), "listener-mean centering zeroes bystanders at or below mean and elevates above-mean suspects without another solve")
		check(is_equal_approx(Mind.execution_priority_contribution(listener, target.id), C.SHARED_EXECUTION_PRIORITY_WEIGHT * Mind.execution_priority(listener, target.id)), "execution_priority_contribution scales priority by SHARED_EXECUTION_PRIORITY_WEIGHT")
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
	var wgt: float = C.SHARED_EXECUTION_PRIORITY_WEIGHT
	for suspicion in [-0.2, 0.38, 0.5, 0.62, 0.9, 1.6]:
		listener.suspicion[target.id] = suspicion
		var votes: Array = []
		var nominations: Array = []
		for priority in [0.0, 1.0]:
			listener.workshop_state = {"active": true, "action": {"execution_priority": {target.id: priority}}}
			votes.append(Mind.vote(w, listener, target.id, "player", false, "", 0))
			nominations.append(Mind._good_nomination(w, listener, w.meeting, ""))
		check((not votes[0] or votes[1]) and (nominations[0] == null or nominations[1] != null), "higher execution priority monotonically supports voting and nomination at suspicion " + str(suspicion))
		if is_equal_approx(suspicion, 0.38):
			check(not votes[0] and votes[1], "priority 1.0 bridges a 0.38-suspicion world-model standout across the 0.52 vote bar (0.38 + %.2f = %.2f)" % [wgt, 0.38 + wgt])
	var evaluations = w.dlog.trace_events().filter(func(event): return event.type == "decision" and event.data.kind == "vote" and event.data.stage == "evaluation" and event.actor == listener.id)
	for index in range(0, evaluations.size(), 2):
		var low: Dictionary = evaluations[index].data.details
		var high: Dictionary = evaluations[index + 1].data.details
		var expected_delta: float = 0.0 if float(low.score) == 0.0 and float(low.inputs.suspicion) <= 0.0 else wgt
		if float(low.inputs.suspicion) >= 0.0:
			check(is_equal_approx(float(high.score) - float(low.score), wgt) and is_equal_approx(float(high.margin) - float(low.margin), wgt) and is_equal_approx(float(low.threshold), float(high.threshold)), "priority 1.0 adds exact SHARED_EXECUTION_PRIORITY_WEIGHT to vote score and margin")
		check(low.shared_execution_priority == 0.0 and high.shared_execution_priority == 1.0 and is_equal_approx(float(high.shared_execution_weight), wgt), "decision traces expose the active shared input and coefficient")
	check(w.rng.state == rng, "the action plumbing draws no game RNG")
	listener.workshop_state.active = false
	check(Mind.execution_priority(listener, target.id) == 0.0, "even a stored maximum score is ignored after ownership is inactive")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
