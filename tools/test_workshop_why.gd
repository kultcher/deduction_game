## The "why" breakdown (workshop/case_why.gd, game/workshop_why.gd): developer inspection of
## what a case's cards are worth and why a listener moved as far as they did. It must
## report the solver's own numbers, and it must change nothing.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Tuning = preload("res://sim/tuning.gd")
const DevLog = preload("res://sim/devlog.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Why = preload("res://workshop/case_why.gd")
const WorkshopWhy = preload("res://game/workshop_why.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_evidence()
	_card_statuses()
	_presentation()
	_already_held()
	_extras()
	_vote_bar()
	_recording()
	_neutral_when_on()
	_menu()
	print("Workshop why: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(insight: float = 0.5):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 0.6
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = insight
	n.traits.confidence = 0.5
	return g

func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	return g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if day == 0 else 0, "data": data,
		"text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})

## A canvas case "target is <type>" over these board cards.
func _value(g, type: String, target, numbers: Array) -> Dictionary:
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var premise = model.add_premise(target.id, type, Vector2(0, 0))
	var wanted: Array = numbers.map(func(n): return preload("res://workshop/live_evidence.gd").normalize_card(g.board[n - 1]).id)
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and nd.card in wanted:
			model.connect_cards(id, premise)
	return model.compile(premise)

func _prepared(g, value: Dictionary) -> Dictionary:
	var input = Live.snapshot(g, value)
	input.private_evidence = []
	input.evidence = input.evidence.filter(func(e): return e.id in input.selected)
	input.listener = {"id": "ghost", "name": "Test juror", "trust": 0.5, "confidence": 0.5,
		"insight": 0.5, "npc_trust": {}, "suspicion": {}, "source_doubt": {}, "own_gift": "", "legacy_evidence": []}
	return Assess.prepare(input)

func _state(g) -> Dictionary:
	var people: Array = []
	for n in g.w.npcs:
		people.append({"real": DevLog.npc_state(n), "ws": n.workshop_state.duplicate(true), "ledger": n.ledger.duplicate(true),
			"shadow": DevLog.npc_state(n.shadow) if n.shadow != null else {},
			"shadow_ws": n.shadow.workshop_state.duplicate(true) if n.shadow != null else {},
			"shadow_rng": n.shadow.shadow_rng.state if n.shadow != null else 0})
	return {"people": people, "rng": g.w.rng.state, "board": g.board.duplicate(true), "log": g.w.dlog.entries.size(),
		"plans": g._workshop_plans.duplicate(true), "evaluations": g._workshop_evaluations.duplicate(true),
		"reason_ctx": Shared.last_reason_ctx.duplicate(true), "unlimited": Reasoner.unlimited_cards,
		"reuse": Reasoner.reuse_preparations, "capture": CaseEval.capture_worlds, "captured": CaseEval.captured.size()}

## The evidence half on the test juror: the chain, the world share and the alternatives
## are the solver's own numbers.
func _evidence() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	var value: Dictionary = _value(g, "evil", p[3], [dowser])
	var prepared: Dictionary = _prepared(g, value)
	check(prepared.ready, "the test juror can judge the case")
	var view_before: String = JSON.stringify(prepared.view.cards)
	var case_before: String = JSON.stringify(prepared.case)
	var b: Dictionary = Why.evidence(prepared.view, prepared.case)
	check(JSON.stringify(prepared.view.cards) == view_before and JSON.stringify(prepared.case) == case_before, "the breakdown leaves its inputs untouched")
	check(not CaseEval.capture_worlds and CaseEval.captured.is_empty(), "the world-capture switch is put back")
	var ev: Dictionary = CaseEval.evaluate(prepared.view, prepared.case)
	check(is_equal_approx(b.posterior, ev.posterior) and is_equal_approx(b.lr, ev.lr), "its verdict is CaseEval's own (%.4f, LR %.3f)" % [b.posterior, b.lr])
	var chain: Array = b.chain
	check(chain.size() == 4 and chain[0].stage == "before" and chain[3].stage == "heard", "the chain runs before -> honest -> face -> heard")
	check(is_equal_approx(chain[0].p, 2.0 / 7.0), "with no cards the test juror starts at the base rate (%.4f)" % chain[0].p)
	check(chain[1].p >= chain[2].p - 1e-9 and chain[2].p >= chain[3].p - 1e-9, "each allowance can only cost the premise (%.3f >= %.3f >= %.3f)" % [chain[1].p, chain[2].p, chain[3].p])
	check(is_equal_approx(chain[3].p, b.posterior), "the last step is the verdict")
	check(chain[1].p > chain[0].p, "an honest 2-of-3 count raises its members")
	# With a good, healthy Dowser, 2 of the 3 named register evil: p3 is one of them in
	# two of the three ways to choose (a little less, since a Marked member may register).
	check(chain[1].p > 0.5 and chain[1].p <= 2.0 / 3.0 + 1e-6, "if the Dowser is honest, p3 is one of the two in up to 2/3 of the worlds (%.4f)" % chain[1].p)
	# World share against a brute count over the universe.
	var row: Dictionary = b.cards[0]
	var card: Dictionary = Solver.card_by_id(prepared.view, row.id)
	var universe: Array = Solver.universe(prepared.view)
	var idx: Array = [p[3].id, p[4].id, p[5].id].map(func(id): return Solver.person_index(prepared.view, id))
	var holds := 0
	var valid := 0
	for world in universe:
		if not Solver.source_valid(prepared.view, world, card):
			continue
		valid += 1
		var evil_n := 0
		for i in idx:
			if (int(world.evil) >> i) & 1 == 1:
				evil_n += 1
		# A Marked member may register either way; count only the plain worlds' rule here.
		if evil_n == 2:
			holds += 1
	var brute: float = float(holds) / float(valid)
	print("dowser 2-of-3: world share %.4f, brute count %.4f, q used %.4f" % [row.world_share, brute, row.q_used])
	check(absf(float(row.world_share) - brute) < 0.06, "the card's world share matches a count over the worlds (%.3f vs %.3f)" % [row.world_share, brute])
	check(is_equal_approx(float(row.q_used), CaseEval.chance_content(prepared.view, card)), "q is the model's own chance_content")
	check(row.status == "counted" and float(row.adds) > 1.0, "the card counts, and the premise is stronger with it (x%.2f)" % row.adds)
	check(is_equal_approx(float(row.adds), b.lr), "a one-card case's strength is that card's contribution")
	# Alternatives.
	var alt: Dictionary = b.alternatives
	check(absf(float(alt.left) - (1.0 - b.posterior)) < 1e-6, "what's left is 1 - posterior (%.4f)" % alt.left)
	var total := 0.0
	for grp in alt.groups:
		total += float(grp.share)
	check(absf(total - 1.0) < 1e-6, "the alternative groups partition what's left")
	check(alt.groups.any(func(grp): return grp.key == "teller:" + p[2].id), "one alternative is that the Dowser can't be taken at their word")
	check(alt.groups.any(func(grp): return grp.key == "other"), "another is that the count is true and the two are the other pair")
	check(Why.strongest_alternative(prepared.view, b) != "", "the strongest alternative is named")
	var text: String = Why.describe(prepared.view, b)
	check(text.contains("holds in") and text.contains("What's left"), "the readout has the per-card share and the alternatives")

## Cards that carry nothing, and cards that argue the other way, are labelled.
func _card_statuses() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	# A Lamplighter's bare count of walkers names nobody: it fits nearly every world.
	var vague = _read(g, p[1], "lamplighter", 0, {"count": 1})
	var prepared: Dictionary = _prepared(g, _value(g, "evil", p[3], [dowser, vague]))
	check(prepared.ready, "the two-card case can be judged (%s)" % str(prepared.get("issues", [])))
	if not prepared.ready:
		return
	var b: Dictionary = Why.evidence(prepared.view, prepared.case)
	var by_role: Dictionary = {}
	for row in b.cards:
		by_role[row.role] = row
	print("statuses: " + ", ".join(PackedStringArray(b.cards.map(func(r): return "%s %s=%s (x%.3f, share %.2f)" % [r.source, r.role, r.status, float(r.get("adds", 1.0)), float(r.get("world_share", -1.0))]))))
	check(by_role.dowser.status == "counted", "the count of two counts")
	check(by_role.lamplighter.status in ["fits_most_worlds", "no_effect"], "a bare Lamplighter count is functionally irrelevant here (%s)" % by_role.lamplighter.status)
	check(float(by_role.lamplighter.world_share) >= Why.TYPICAL_SHARE, "because it holds in nearly every world (%.2f)" % float(by_role.lamplighter.world_share))
	check(Why.describe(prepared.view, b).contains(Why.STATUS_TEXT[by_role.lamplighter.status]), "and the readout says so")
	# A second Dowser who clears the same three argues against "p3 is evil".
	var g2 = _game()
	var p2: Array = g2.w.npcs
	var two = _read(g2, p2[2], "dowser", 1, {"group": [p2[3].id, p2[4].id, p2[5].id], "count": 2})
	var clear = _read(g2, p2[6], "dowser", 2, {"group": [p2[3].id, p2[4].id, p2[5].id], "count": 0})
	var prepared2: Dictionary = _prepared(g2, _value(g2, "evil", p2[3], [two, clear]))
	check(prepared2.ready, "the conflicting case can be judged (%s)" % str(prepared2.get("issues", [])))
	if not prepared2.ready:
		return
	var b2: Dictionary = Why.evidence(prepared2.view, prepared2.case)
	var zero: Dictionary = b2.cards.filter(func(r): return r.source == p2[6].id)[0]
	check(zero.status == "argues_against" and float(zero.adds) < 1.0, "a count of zero over the same three argues against the premise (x%.3f)" % float(zero.adds))
	# Status overrides for a real listener.
	var opts := {"attended": [b.cards[0].id], "rejected": [b.cards[0].id], "held": [b.cards[1].id], "per_card": false}
	var c: Dictionary = Why.evidence(prepared.view, prepared.case, {}, opts)
	check(c.cards[0].status == "rejected" and c.cards[1].status == "not_attended" and c.cards[1].held, "rejected, unattended and already-held cards are marked")
	check(not c.cards[0].has("world_share"), "per_card=false skips the per-card runs")

## The belief half for a real listener: it reproduces what the presentation did, and
## reading it changes nothing.
func _presentation() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var n = p[0]
	Mind.refresh_beliefs(g.w, n, " (baseline)")
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	var number: int = Live.file(g, _value(g, "evil", p[3], [dowser]), 0)
	check(number > 0, "the case files (%s)" % g.last_error)
	var card: Dictionary = g.board[number - 1]
	var missing: Dictionary = WorkshopWhy.presentation(g, n, card)
	check(not missing.get("ready", true), "nothing to explain before the case is presented")
	var was: Dictionary = WorkshopWhy.before(n)
	var before: float = Mind.susp(n, p[3].id)
	g._evaluate_deduction(n, card, 1.0, false, "meeting")
	var after: float = Mind.susp(n, p[3].id)
	var state_before: Dictionary = _state(g)
	var b: Dictionary = WorkshopWhy.presentation(g, n, card, "meeting", was)
	check(_state(g) == state_before, "reading the breakdown changes no mind, plan, cache switch, RNG or log")
	check(b.get("ready", false), "the breakdown is ready (%s)" % str(b.get("issues", [])))
	if not b.get("ready", false):
		return
	print(b.text)
	var chain: Array = b.chain
	var stages: Array = chain.map(func(s): return s.stage)
	check(stages == ["certain", "face", "heard", "attention", "new", "resistance", "applied"], "the chain has every stage (%s)" % str(stages))
	var by: Dictionary = {}
	for s in chain:
		by[s.stage] = float(s.move)
	check(by.certain >= by.face - 1e-6, "settling it outright is the ceiling (%.3f >= %.3f)" % [by.certain, by.face])
	check(by.face >= by.heard - 1e-6, "face value is at least what they hear (%.3f >= %.3f)" % [by.face, by.heard])
	check(by.face > 0.0, "the Dowser count would raise p3 at face value")
	check(absf(by.applied - (after - before)) < 0.03, "the applied step is what the presentation did (%.3f vs %.3f)" % [by.applied, after - before])
	check(b.held == 0 and b.cards_n == 1, "nothing was already held")
	check(is_equal_approx(by.attention, by["new"]), "with nothing held, attention and new agree")
	check(not b.biggest_loss.is_empty(), "the biggest loss is named (%s)" % b.biggest_loss.get("label", ""))
	check(b.evidence.cards.size() == 1 and b.evidence.cards[0].has("reliability") and float(b.evidence.cards[0].reliability) < 0.99, "this listener hears the reading below full weight (%.2f)" % float(b.evidence.cards[0].get("reliability", 1.0)))
	check(b.evidence.chain[2].p > b.evidence.chain[3].p, "so hearing costs the premise something (%.3f -> %.3f)" % [b.evidence.chain[2].p, b.evidence.chain[3].p])
	check(b.text.contains("Biggest loss") and b.text.contains("Action:"), "the readout names the loss and the vote bar")
	# The subject of a case knows their own alignment.
	var subject_was: Dictionary = WorkshopWhy.before(p[3])
	if not p[3].is_evil():
		g._evaluate_deduction(p[3], card, 1.0, false, "meeting")
		var s: Dictionary = WorkshopWhy.presentation(g, p[3], card, "meeting", subject_was)
		check(s.get("is_subject", false) and s.chain.is_empty(), "the subject gets no chain")

## A card the listener already held adds nothing when it is presented again.
func _already_held() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var n = p[0]
	Mind.refresh_beliefs(g.w, n, " (baseline)")
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	var first: int = Live.file(g, _value(g, "evil", p[3], [dowser]), 0)
	g._evaluate_deduction(n, g.board[first - 1], 1.0, false, "meeting")
	var second: int = Live.file(g, _value(g, "evil", p[4], [dowser]), 0)
	var was: Dictionary = WorkshopWhy.before(n)
	g._evaluate_deduction(n, g.board[second - 1], 1.0, false, "meeting")
	var b: Dictionary = WorkshopWhy.presentation(g, n, g.board[second - 1], "meeting", was)
	check(b.get("ready", false) and b.held == 1, "the reading is marked as already held")
	if not b.get("ready", false):
		return
	check(b.evidence.cards[0].held and b.text.contains("already held"), "and the card row says so")
	var by: Dictionary = {}
	for s in b.chain:
		by[s.stage] = float(s.move)
	print("already held: face %+.3f, attention %+.3f, new %+.3f" % [by.face, by.attention, by["new"]])
	check(by.face > by["new"] + 0.02, "as news it would have moved them; as a repeat it moves them less (%.3f vs %.3f)" % [by.face, by["new"]])

## What a challenge, the citing and a change of view did, each against its own rerun.
func _extras() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var n = p[0]
	Mind.refresh_beliefs(g.w, n, " (baseline)")
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	var other = _read(g, p[5], "dowser", 1, {"group": [p[3].id, p[4].id, p[6].id], "count": 0})
	var first: int = Live.file(g, _value(g, "evil", p[3], [dowser, other]), 0)
	g._evaluate_deduction(n, g.board[first - 1], 1.0, false, "meeting")
	var value: Dictionary = _value(g, "evil", p[5], [dowser, other])
	var other_id: String = preload("res://workshop/live_evidence.gd").normalize_card(g.board[other - 1]).id
	value.reading_challenges[other_id] = {"mode": "lying", "supports": []}
	var second: int = Live.file(g, value, 0)
	check(second > 0, "a case with a challenge files (%s)" % g.last_error)
	var was: Dictionary = WorkshopWhy.before(n)
	g._evaluate_deduction(n, g.board[second - 1], 1.0, false, "meeting")
	var state_before: Dictionary = _state(g)
	var b: Dictionary = WorkshopWhy.presentation(g, n, g.board[second - 1], "meeting", was)
	check(_state(g) == state_before, "the extra reruns change nothing either")
	check(b.get("ready", false), "the breakdown is ready (%s)" % str(b.get("issues", [])))
	if not b.get("ready", false):
		return
	print(b.text)
	check(b.challenges.size() == 1 and b.challenges[0].card == other_id and b.challenges[0].mode == "lying" and b.challenges[0].source == p[5].id,
		"the case's one challenge is listed (%s)" % str(b.challenges.map(func(c): return c.mode)))
	if b.challenges.size() == 1:
		var ch: Dictionary = b.challenges[0]
		check(is_equal_approx(ch.target_with, b.effect.posterior), "its 'with' side is the applied belief")
		check(ch.target_without >= 0.0 and ch.target_without <= 1.0 and ch.multiplier >= 0.0 and ch.multiplier <= 1.0, "its 'without' side and multiplier are in range")
		check(b.text.contains("Challenge on #%d" % other) and b.text.contains("Without this challenge"), "and the readout prints it")
	check(b.trust.has("cards"), "trust changes are reported (%d)" % b.trust.cards.size())
	for t in b.trust.cards:
		check(float(t.was) != float(t.now) and b.text.contains("Citing changed"), "a changed reliability is printed (%.2f -> %.2f)" % [t.was, t.now])
	check(b.has("view_change"), "the view change is reported")
	if not b.view_change.is_empty():
		var vc: Dictionary = b.view_change
		check(is_equal_approx(vc.target_now, b.effect.posterior) and is_equal_approx(vc.target_was, b.effect.posterior_without), "its before and after are the chain's")
		check(vc.left.all(func(id): return id not in vc.entered), "no card both left and entered")
		check(b.text.contains("Change of view") and b.text.contains("With their old view kept"), "and the readout prints it")
	# No challenge, no before(): neither section claims anything.
	var plain: Dictionary = WorkshopWhy.presentation(g, n, g.board[first - 1], "meeting")
	check(plain.get("ready", false) and plain.challenges.is_empty() and plain.view_change.is_empty(), "a case without a challenge or a recorded view lists neither")

## The vote bar in the readout is the one a real vote uses.
func _vote_bar() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var n = p[0]
	Mind.refresh_beliefs(g.w, n, " (baseline)")
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	var number: int = Live.file(g, _value(g, "evil", p[3], [dowser]), 0)
	var was: Dictionary = WorkshopWhy.before(n)
	g._evaluate_deduction(n, g.board[number - 1], 1.0, false, "meeting")
	var b: Dictionary = WorkshopWhy.presentation(g, n, g.board[number - 1], "meeting", was)
	check(b.has("action"), "the readout has the action bars")
	if not b.has("action"):
		return
	g.w.meeting = {"block": "", "block_count": 0, "nominated": [], "vote_parts": {}}
	MindMeeting.vote(g.w, n, p[3].id, "player", false, "", 0)
	var real: Dictionary = g.w.meeting.vote_parts.get(n.id, {})
	check(not real.is_empty(), "the real vote recorded its parts")
	if not real.is_empty():
		check(absf(float(real.margin) - float(b.action.vote_margin)) < 1e-6, "the readout's margin is the vote's (%.4f vs %.4f)" % [b.action.vote_margin, real.margin])

## g.workshop_why records one breakdown per listener; off (the default) records nothing.
func _recording() -> void:
	for on in [false, true]:
		var g = _game()
		var p: Array = g.w.npcs
		g.workshop_why = on
		for q in p:
			Mind.refresh_beliefs(g.w, q, " (baseline)")
		var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
		var number: int = Live.file(g, _value(g, "evil", p[3], [dowser]), 0)
		g._evaluate_deduction(p[0], g.board[number - 1], 1.0, false, "meeting")
		var logged: Array = g.w.dlog.entries.filter(func(e): return e.type == "workshop_why")
		if on:
			check(g.workshop_whys.size() == 1 and logged.size() == 1, "recording on: one breakdown kept and one dev-log entry")
			if logged.size() == 1:
				var d: Dictionary = logged[0].data
				check(d.has("chain") and d.has("cards") and d.has("alternatives") and str(logged[0].reason).begins_with("Why "), "the log entry carries the chain, the cards and a one-line reason")
				check(d.cards[0].has("world_share") and d.cards[0].has("q_used") and d.cards[0].has("status"), "each logged card has its status, world share and q")
			g._evaluate_deduction(p[0], g.board[number - 1], 1.0, false, "meeting")
			check(g.workshop_whys.size() == 1, "an unchanged repeat records nothing more")
		else:
			check(g.workshop_whys.is_empty() and logged.is_empty(), "recording off: nothing is computed or logged")

## Recording changes no belief: the same presentations with it on and off leave every mind
## and the world RNG identical.
func _neutral_when_on() -> void:
	var states: Array = []
	for on in [false, true]:
		var g = _game()
		var p: Array = g.w.npcs
		g.workshop_why = on
		for q in p:
			Mind.refresh_beliefs(g.w, q, " (baseline)")
		var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
		var seer = _read(g, p[1], "seer", 1, {"pair": [p[3].id, p[6].id], "yes": true})
		var first: int = Live.file(g, _value(g, "evil", p[3], [dowser]), 0)
		var second: int = Live.file(g, _value(g, "demon", p[3], [dowser, seer]), 0)
		for q in p:
			if q.alive:
				g._evaluate_deduction(q, g.board[first - 1], 1.0, false, "meeting")
		for q in p:
			if q.alive:
				g._evaluate_deduction(q, g.board[second - 1], 1.0, false, "meeting")
		for q in p:
			Mind.refresh_beliefs(g.w, q, " (after)")
		var people: Array = []
		for q in p:
			people.append({"real": DevLog.npc_state(q), "suspicion": q.suspicion.duplicate(true), "trust": q.trust,
				"requested": q.workshop_state.get("requested", {}).duplicate(true),
				"shadow": DevLog.npc_state(q.shadow) if q.shadow != null else {},
				"shadow_suspicion": q.shadow.suspicion.duplicate(true) if q.shadow != null else {},
				"shadow_rng": q.shadow.shadow_rng.state if q.shadow != null else 0})
		states.append({"people": people, "rng": g.w.rng.state, "whys": g.workshop_whys.size()})
	check(states[0].people == states[1].people, "every mind ends the same with recording on")
	check(states[0].rng == states[1].rng, "and the world RNG is untouched")
	check(states[0].whys == 0 and states[1].whys > 0, "while the breakdowns were recorded (%d)" % states[1].whys)

## The Workshop's Debug menu carries the three entries.
func _menu() -> void:
	var script = load("res://ui/live_case_workshop.gd")
	check(script != null, "the Workshop UI script loads")
	if script == null:
		return
	var items: Dictionary = script.get_script_constant_map().get("DebugItem", {})
	check(items.has("WHY") and items.has("WHY_RECORD") and items.has("WHY_SHOW"), "its Debug menu has the why entries")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
