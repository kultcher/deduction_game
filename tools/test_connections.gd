## The connections belief model, step 1 (workshop/connections.gd; Project doc
## belief-model-direction, "Phase 6 spec"): the switch and the single-card values.
##
## - The switch is off by default, and with it off a refresh carries no trace of the model.
## - With it on, every card a listener holds counts, including the ones its attention left
##   out; the ones it rejects from its own knowledge don't.
## - Each chance is the baseline (the standing view and the public record) plus every
##   card's own lean, in log-odds. The "before" side stays today's.
## - Headline reading (a low-Insight listener taking a strong reading at its word) is off.
## - Turning the switch back off gives today's refresh again, exactly.
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Connections = preload("res://workshop/connections.gd")
const CaseEval = preload("res://workshop/case_eval.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	check(not Tuning.Workshop.CONNECTIONS, "the model is off in Tuning")
	check(Connections.enabled == Tuning.Workshop.CONNECTIONS, "the runtime switch starts from the Tuning value")
	_arithmetic()
	_game(900, 7, 3)
	_game(902, 10, 3)
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	print("Connections: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _arithmetic() -> void:
	check(is_equal_approx(Connections.chance(Connections.logit(0.3)), 0.3), "log-odds and back is the same chance")
	check(is_equal_approx(Connections.logit(0.0), Connections.logit(Connections.CLIP)) and is_equal_approx(Connections.logit(1.0), -Connections.logit(0.0)), "a chance is clipped before it becomes log-odds")
	var bare: Dictionary = Connections.template({"id": "x", "cards": ["a", "b"], "lines": [{"id": "l"}], "reading_challenges": {"a": {}}, "answers": {"q": {}}, "conclusion": {"type": "suspicious", "target": "t", "at": "Now"}}, "p")
	check(bare.cards.is_empty() and bare.lines.is_empty() and bare.reading_challenges.is_empty() and bare.answers.is_empty(), "the bare case carries no cards, lines, answers or challenges")
	check(bare.conclusion == {"type": "evil", "target": "p", "at": "Now"}, "the bare case asks a plain evil question at the case's own time")
	check(Connections.case_for(bare, ["b", "a"]).cards == ["a", "b"] and bare.cards.is_empty(), "a set of cards is one case whatever order it comes in")


func _proposal(g, n) -> Dictionary:
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	return g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {}).duplicate(true)


func _same_effects(a: Dictionary, b: Dictionary) -> bool:
	if a.get("effects", {}).keys() != b.get("effects", {}).keys():
		return false
	for id in a.effects:
		for field in ["requested", "prior", "posterior", "alignment_signal", "headline_signal", "route"]:
			if a.effects[id].get(field) != b.effects[id].get(field):
				return false
	return true


func _game(seed_v: int, npcs: int, day: int) -> void:
	Connections.enabled = false
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, npcs)
	var guard := 0
	while g.state != "over" and guard < 600 and not (g.state == "meeting" and g.w.day >= day):
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	var tag: String = "seed %d" % seed_v
	if g.state != "meeting":
		check(false, "%s reaches the day-%d meeting" % [tag, day])
		return
	var listeners: Array = g.w.living().filter(func(n): return not n.is_evil())
	check(listeners.size() >= 2, "%s has good listeners to test (%d)" % [tag, listeners.size()])
	var left_out_counted := 0
	var held_total := 0
	var headline_seen := 0
	for n in listeners:
		var off: Dictionary = _proposal(g, n)
		if off.get("effects", {}).is_empty():
			continue
		check(not off.has("connections"), "%s %s: off, the refresh carries nothing of the model" % [tag, n.id])
		Connections.enabled = true
		var on: Dictionary = _proposal(g, n)
		Connections.enabled = false
		var again: Dictionary = _proposal(g, n)
		check(_same_effects(off, again), "%s %s: off again, the refresh is exactly what it was" % [tag, n.id])
		if not on.has("connections"):
			check(false, "%s %s: on, the refresh carries the model's breakdown" % [tag, n.id])
			continue
		var c: Dictionary = on.connections
		var reasoning: Dictionary = on.reasoning
		var rejected: Array = reasoning.private_checks.get("rejected", [])
		var held: Array = []
		for id in reasoning.considered + reasoning.ignored:
			if id not in rejected and id not in held:
				held.append(id)
		held.sort()
		var keys: Array = c.items.map(func(it): return it.key)
		keys.sort()
		held_total += held.size()
		check(keys == held, "%s %s: every held card is an item, and no rejected one (%d cards, %d rejected)" % [tag, n.id, held.size(), rejected.size()])
		left_out_counted += reasoning.ignored.filter(func(id): return id in keys).size()
		check(c.judgements == held.size() + 1, "%s %s: one judgement a card, plus the baseline" % [tag, n.id])
		# Each chance is the standing view plus every card's own lean.
		var sums_ok := true
		var prior_ok := true
		var effect_ok := true
		var plain_ok := true
		for id in c.posterior:
			var total: float = 0.0
			for it in c.items:
				total += float(it.lean.get(id, 0.0))
			var settled: bool = c.baseline[id] <= Connections.FIXED or c.baseline[id] >= 1.0 - Connections.FIXED
			var want: float = c.baseline[id] if settled else Connections.chance(Connections.logit(c.baseline[id]) + total)
			if absf(want - float(c.posterior[id])) > 1e-9:
				sums_ok = false
			# The "before" side is today's: the same standing view either way.
			if off.effects.has(id) and absf(float(off.effects[id].prior) - float(c.prior[id])) > 1e-9:
				prior_ok = false
			if not on.effects.has(id):
				continue
			var e: Dictionary = on.effects[id]
			if e.route == "public_fact":
				continue
			if absf(float(e.posterior) - float(c.posterior[id])) > 1e-9 or absf(float(e.prior) - float(c.prior[id])) > 1e-9:
				effect_ok = false
			if float(off.effects.get(id, {}).get("headline_signal", 0.0)) > float(off.effects.get(id, {}).get("alignment_signal", 0.0)):
				headline_seen += 1
			# (The public curse pins its executed Revenant, whose chance is 1 before and after.)
			if float(e.prior) < 0.999 and absf(float(e.alignment_signal) - Tuning.Workshop.JURY_ALIGNMENT_COEFF * CaseEval.shift(float(e.prior), float(e.posterior))) > 1e-9:
				plain_ok = false
		check(sums_ok, "%s %s: each chance is the baseline plus every card's lean" % [tag, n.id])
		check(prior_ok, "%s %s: the before side is today's standing view" % [tag, n.id])
		check(effect_ok, "%s %s: the refresh's effects carry the model's chances" % [tag, n.id])
		check(plain_ok, "%s %s: no headline reading is blended in" % [tag, n.id])
	check(held_total > 0, "%s: listeners hold cards (%d)" % [tag, held_total])
	print("NOTE: %s: %d cards attention left out were counted; headline reading applied today in %d listener-person pairs" % [tag, left_out_counted, headline_seen])
	if npcs >= 10:
		check(left_out_counted > 0, "%s: cards attention left out still count" % tag)
