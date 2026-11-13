## The connections belief model, step 1 (workshop/connections.gd; Project doc
## belief-model-direction, "Phase 6 spec"): the switch and the single-card values.
##
## - The switch is off by default, and with it off a refresh carries no trace of the model.
## - With it on, every card a listener holds counts once, alone or in a built-in pairing
##   (test_connections_pairings), including the ones its attention left out; the ones it
##   rejects from its own knowledge don't.
## - Each chance is the baseline (the standing view and the public record) plus every
##   card's own lean and what the core adds (test_connections_core), in log-odds, then one
##   common shift so the chances still sum to the baseline's (the evil count). The "before"
##   side stays today's.
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
	var scores: Array = [2.0, 0.5, -1.0, -1.5]
	var shift: float = Connections.common_shift(scores, 2.0)
	var total := 0.0
	for x in scores:
		total += Connections.chance(float(x) + shift)
	check(absf(total - 2.0) < 1e-9, "the common shift makes the chances sum to the target (%.6f)" % total)
	check(is_zero_approx(Connections.common_shift([0.0, 0.0], 1.0)), "chances that already sum to the target aren't shifted")


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
		# Every held card sits in exactly one item (a plain card or a built-in pairing).
		var keys: Array = []
		var twice := false
		for it in c.items:
			if it.kind == "day":
				continue  # the Hexer's day connection re-reads cards that sit elsewhere
			for id in it.cards:
				if id in keys:
					twice = true
				keys.append(id)
		keys.sort()
		held_total += held.size()
		check(keys == held and not twice, "%s %s: every held card is in exactly one item, and no rejected one (%d cards, %d items, %d rejected)" % [tag, n.id, held.size(), c.items.size(), rejected.size()])
		left_out_counted += reasoning.ignored.filter(func(id): return id in keys).size()
		check(c.judgements <= 3 * c.items.size() + 6, "%s %s: at most two judgements an item and one more to test it against the core, plus the baseline and the core's own (%d for %d items)" % [tag, n.id, c.judgements, c.items.size()])
		# Each chance is the standing view plus every card's own lean and the core's.
		var sums_ok := true
		var sum_base := 0.0
		var sum_post := 0.0
		var prior_ok := true
		var effect_ok := true
		var plain_ok := true
		for id in c.posterior:
			var total: float = float(c.core.lean.get(id, 0.0))
			for it in c.items:
				total += float(it.lean.get(id, 0.0))
			var settled: bool = c.baseline[id] <= Connections.FIXED or c.baseline[id] >= 1.0 - Connections.FIXED
			var want: float = c.baseline[id] if settled else Connections.chance(Connections.logit(c.baseline[id]) + total + float(c.shift))
			if c.core.proved.has(id):
				want = float(c.core.proved[id])
			sum_base += float(c.baseline[id])
			sum_post += float(c.posterior[id])
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
		check(sums_ok, "%s %s: each chance is the baseline plus every card's lean and the core's, plus the common shift" % [tag, n.id])
		check(absf(sum_post - sum_base) < 1e-6, "%s %s: the chances still sum to the baseline's (%.4f; the town has %d evil)" % [tag, n.id, sum_post, int(g.w.by_id.values().filter(func(x): return x.is_evil()).size())])
		check(prior_ok, "%s %s: the before side is today's standing view" % [tag, n.id])
		check(effect_ok, "%s %s: the refresh's effects carry the model's chances" % [tag, n.id])
		check(plain_ok, "%s %s: no headline reading is blended in" % [tag, n.id])
	check(held_total > 0, "%s: listeners hold cards (%d)" % [tag, held_total])
	print("NOTE: %s: %d cards attention left out were counted; headline reading applied today in %d listener-person pairs" % [tag, left_out_counted, headline_seen])
	if npcs >= 10:
		check(left_out_counted > 0, "%s: cards attention left out still count" % tag)
