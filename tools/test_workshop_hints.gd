extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Speech = preload("res://workshop/speech_evidence.gd")
const C = preload("res://sim/content.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_probabilities()
	for size in [7, 10]:
		_live(size)
	print("Gift hints: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _probabilities() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d"]:
		people.append({"id": id, "name": id, "home": "square"})
	var card = {"id": "hint", "kind": "gift_hint", "source": "a", "subject": "a", "night": -1,
		"observed_at": {"day": 1, "phase": "morning"}, "data": {"package": "official", "roles": C.HINT_PACKAGES.official.roles.duplicate()}}
	var view = {"people": people, "cards": [card], "evil_count": 2, "alignment_epoch": "Original alignment", "world_options": {"modifiers": ["marked"]}}
	var value = Solver.empty_case()
	value.conclusion = {"type": "evil", "target": "a", "at": view.alignment_epoch}
	var before = Eval.evaluate(view, value)
	value.cards = [card.id]
	var after = Eval.evaluate(view, value)
	check(after.posterior < before.posterior and after.posterior > 0.3, "a tentative good-gift family weakly supports the claim without proving innocence")
	var repeat = card.duplicate(true)
	repeat.id = "retelling"
	repeat.observed_at.day = 2
	view.cards.append(repeat)
	value.cards.append(repeat.id)
	check(Eval.evaluate(view, value).people == after.people, "repeated family hints do not stack across dates")
	var claim = {"id": "claim", "kind": "claim", "source": "a", "subject": "a", "role": "surveyor", "data": {}, "observed_at": card.observed_at}
	view.cards.append(claim)
	value.cards.append(claim.id)
	check(Eval.evaluate(view, value).people == after.people, "a matching declaration retains the same weak family support")
	claim.role = "seer"
	var contradicted = Eval.evaluate(view, value)
	check(contradicted.posterior > before.posterior and contradicted.posterior < 0.7, "an incompatible gift declaration weakly undermines the earlier family claim")
	claim["quoted"] = true
	check(Speech.factors([card, claim])[0].log2_ratio < 0.0, "a quoted rival declaration is not an endorsed contradiction")
	var other = card.duplicate(true)
	other.id = "other-family"
	other.data = {"package": "night_sight", "roles": C.HINT_PACKAGES.night_sight.roles.duplicate()}
	check(Speech.factors([card, other])[0].log2_ratio > 0.0, "mutually incompatible families weaken the source rather than selecting a role")
	card["quoted"] = true
	check(Speech.factors([card]).is_empty(), "quoting a hint does not silently endorse its claim")

func _live(size: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, size)
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
	var raw = {"kind": "hint", "source": target.id, "subject": [target.id], "day": 1, "phase": 0,
		"package": "official", "roles": C.HINT_PACKAGES.official.roles.duplicate(), "text": "A gift of official business"}
	var number = g.add_card(raw)
	var receipt = Live.Evidence.normalize_card(g.board[number - 1])
	var input = g.workshop_snapshot([], observer.id)
	var adapted = Live.Assess.activity_card(receipt, input)
	check(adapted.get("kind") == "gift_hint" and adapted.get("role", "") == "" and adapted.night == -1 and adapted.data.roles == C.HINT_PACKAGES.official.roles, "a family hint preserves its alternatives without asserting a specific role or outing")
	var ded = g.file_deduction({"type": "good", "a": target.id}, [number])
	check(ded > 0, "a gift-family claim can support a filed case")
	if ded < 1:
		return
	g.strict_evaluator = true
	for n in g.w.living():
		var result = g._evaluate_deduction(n, g.board[ded - 1], 1.0, false)
		var listener = n.shadow if n.is_evil() else n
		check(result.get("workshop", false) and listener.workshop_state.active and receipt.id in listener.workshop_state.facts, "strict hint presentation uses shared ownership for " + n.id)
	for changes in [{"source": "outsider"}, {"subject": [observer.id]}, {"package": "invented"}, {"roles": ["seer"]}, {"roles": "surveyor"}, {"day": -1}]:
		var bad = raw.duplicate(true)
		bad.merge(changes, true)
		check(Live.Assess.activity_card(Live.Evidence.normalize_card(bad), input).is_empty(), "invalid gift-family payload is rejected without parsing prose")
	g.workshop_retract(ded, observer.id)
	check(receipt.id not in observer.workshop_state.facts, "withdrawing the sole hint endorsement retracts its evidence")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
