extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Speech = preload("res://workshop/speech_evidence.gd")
const Mind = preload("res://sim/mind.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_probabilities()
	for size in [7, 10]:
		_live(size)
	print("Refusals: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _probabilities() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d"]:
		people.append({"id": id, "name": id, "home": "square"})
	var card = {"id": "refusal", "kind": "refusal", "source": "a", "subject": "a", "night": -1,
		"observed_at": {"day": 1, "phase": "morning"}, "data": {"fear": false}}
	var view = {"people": people, "cards": [card], "evil_count": 2, "alignment_epoch": "Original alignment", "world_options": {"modifiers": ["marked"]}}
	var value = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": "a", "at": view.alignment_epoch}
	var before = Eval.evaluate(view, value)
	value.cards = [card.id]
	var after = Eval.evaluate(view, value)
	check(after.posterior > before.posterior and after.posterior < 0.7, "a refusal supplies weak suspicion, never certainty")
	card.data.fear = true
	var afraid = Eval.evaluate(view, value)
	check(afraid.posterior > before.posterior and afraid.posterior < after.posterior, "fear reduces the refusal signal without clearing the teller")
	var repeat = card.duplicate(true)
	repeat.id = "next-day-refusal"
	repeat.observed_at.day = 2
	view.cards.append(repeat)
	value.cards.append(repeat.id)
	check(Eval.evaluate(view, value).people == afraid.people, "a person's repeated reluctance does not stack across days")
	repeat.data.fear = false
	check(Eval.evaluate(view, value).people == after.people, "mixed refusals use the strongest observation once")
	var quoted = repeat.duplicate(true)
	quoted["quoted"] = true
	check(Speech.factors([quoted]).is_empty(), "quoting a refusal does not endorse it as suspicion evidence")
	check(Speech.factors([card, repeat]).size() == 1, "distinct wrappers retain one reluctance factor")

func _live(size: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, size)
	g.w.day = 2
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.known_claims = {}
			listener.beliefs = []
			listener.ledger = {}
			listener.workshop_state = {"enabled": true, "reasoning_mode": "full", "confidence_mode": "scale"}
	var target = g.w.living_good()[0]
	var observer = g.w.living_good()[1]
	var raw = {"kind": "refusal", "source": target.id, "subject": [target.id], "day": 1, "phase": 3,
		"fear": true, "text": "Refused to give their whereabouts, saying they were afraid"}
	var number = g.add_card(raw)
	var receipt = Live.Evidence.normalize_card(g.board[number - 1])
	var input = g.workshop_snapshot([], observer.id)
	var adapted = Live.Assess.activity_card(receipt, input)
	check(not adapted.is_empty() and adapted.night == -1 and adapted.data.fear, "a dated refusal preserves fear without asserting a night outing")
	check(preload("res://workshop/shared_ledger.gd").supported(receipt), "refusal receipts are shared evidence for the whole town")
	var ded = g.file_deduction({"type": "suspicious", "a": target.id}, [number])
	check(ded > 0, "a refusal can support a filed suspicion case")
	if ded < 1:
		return
	g.strict_evaluator = true
	for n in g.w.living():
		var result = g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
		var listener = n.shadow if n.is_evil() else n
		check(result.get("workshop", false) and listener.workshop_state.active and receipt.id in listener.workshop_state.facts, "strict refusal presentation uses shared ownership for " + n.id)
	var once = observer.suspicion.duplicate(true)
	var rng = g.w.rng.state
	var trust = observer.trust
	Mind.recompute_beliefs(g.w, observer, "refusal repeat")
	check(_close(once, observer.suspicion) and rng == g.w.rng.state and trust == observer.trust, "unchanged refusal refresh does not stack, reward or draw RNG")
	for changes in [{"source": "outsider"}, {"subject": [observer.id]}, {"fear": "yes"}, {"role": "invented"}, {"day": -1}]:
		var bad = raw.duplicate(true)
		bad.merge(changes, true)
		check(Live.Assess.activity_card(Live.Evidence.normalize_card(bad), input).is_empty(), "invalid refusal payload is rejected without guessing its meaning")
	# Revisions preserve the same root ownership mechanism used for all other cards.
	g.workshop_retract(ded, observer.id)
	check(receipt.id not in observer.workshop_state.facts, "withdrawing the sole refusal endorsement removes the evidence")

func _close(a: Dictionary, b: Dictionary) -> bool:
	for id in a:
		if absf(float(a[id]) - float(b.get(id, INF))) > 0.000001:
			return false
	return true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
