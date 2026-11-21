## Premises pass step 2 (docs/premises_plan.md): a presented secret premise is the player's
## word (a card told by the player, weighted by credibility, checked at dawn); "suspicious"
## halves only what a case's cards add together, and pushes its target once; contradictions keep both cards; and
## a public role claim joins a case that cites it automatically.
extends SceneTree

const GamePresentation = preload("res://game/game_presentation.gd")
const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const C = preload("res://sim/content.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
var checks = 0
var fails = 0

func _init() -> void:
	# Premises pass step 2: a 'suspicious' case halves only what its cards add together, and presses its target.
	_secret_word()
	_secret_record()
	_suspicious()
	_contradiction_link()
	_auto_citation()
	_marked_answers()
	print("Premises step 2: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(credibility: float = 0.7):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
		p.trust = 0.7
		p.credibility = credibility
		p.trust_at_reconsider = 0.7
		for id in p.suspicion:
			p.suspicion[id] = 0.25
			p.npc_trust[id] = 1.0
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = 0.5
	n.traits.confidence = 0.5
	n.workshop_state["reasoning_mode"] = "full"
	return g

func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	return GameBoard.add_card(g, {"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if day == 0 else 0, "data": data,
		"text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})

## A Seer "yes" on p3 and p4, presented as "p3 holds <mod>". The baseline is the same
## presentation with the player's word switched off (same cards, same weighting).
## `off_script`: a secret taken off this game's script first, so the premise names a secret
## the case can't have.
func _seer_case(mod: String, credibility: float, words: bool = true, off_script: String = "") -> Dictionary:
	Shared.player_words = words
	var g = _game(credibility)
	if off_script != "" and g.w.case_script != null:
		g.w.case_script.secrets.erase(off_script)
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var seer = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	# "is Marked" is its own premise in the burdens prototype; a hidden burden stays "holds a secret".
	var number = GameBoard.file_deduction(g, {"type": "marked", "a": p[3].id} if mod == "marked" else {"type": "secret_mod", "a": p[3].id, "mod": mod}, [seer])
	var r = GamePresentation._evaluate_deduction(g, n, g.board[number - 1], 1.0, false)
	var cards: Array = g._workshop_plans.get(n.id + ":good", {}).get("prepared", {}).get("view", {}).get("cards", [])
	Shared.player_words = true
	var effects: Dictionary = g._workshop_evaluations.get(n.id + ":good", {}).get("proposal", {}).get("effects", {})
	return {"p3": n.suspicion[p[3].id], "p4": n.suspicion[p[4].id], "word": cards.any(func(c): return c.get("player_word", false)),
		"post3": float(effects.get(p[3].id, {}).get("posterior", 0.0)),
		"workshop": r.get("workshop", false), "modifiers": g.w.case_script.secrets if g.w.case_script != null else []}

func _secret_word() -> void:
	var base: Dictionary = _seer_case("marked", 0.7, false)
	var word: Dictionary = _seer_case("marked", 0.7)
	var base_low: Dictionary = _seer_case("marked", 0.2, false)
	var word_low: Dictionary = _seer_case("marked", 0.2)
	var foreign: Dictionary = _seer_case("sleepwalker", 0.7, true, "sleepwalker")
	print("secret word: modifiers %s; baseline p3 %.3f p4 %.3f; word p3 %.3f p4 %.3f; low credibility baseline p3 %.3f, word p3 %.3f" % [word.modifiers, base.p3, base.p4, word.p3, word.p4, base_low.p3, word_low.p3])
	check("marked" in word.modifiers and "sleepwalker" not in foreign.modifiers, "the fixture case has Marked, and the foreign one has no Sleepwalker")
	check(word.workshop and base.workshop and word.word and not base.word, "a presented secret premise adds the player's word to the listener's evidence")
	check(not foreign.word, "a secret this case can't have adds nothing")
	check(word.p3 < base.p3, "the word that p3 is Marked takes the Seer ping's blame off p3")
	check(word.p4 > base.p4, "and puts it on p4: if p3 is only Marked, the Demon may be p4")
	# In the solver's posterior. (Suspicion also carries the headline rule, which here pulls
	# against the word harder when the Seer card, heard through the player, is trusted more.)
	check(base_low.post3 - word_low.post3 < base.post3 - word.post3, "a listener who doubts the player believes the word less (posterior drop %.3f vs %.3f)" % [base_low.post3 - word_low.post3, base.post3 - word.post3])
	# Headline fix (Nov 6, with recency): a faint Seer ping no longer pulls a clearing back
	# by the whole gap, so the trusted player's word clears p3 more in suspicion too.
	check(word.p3 < word_low.p3, "a trusted player's word clears p3 more than a doubted one's (%.3f vs %.3f)" % [word.p3, word_low.p3])

func _secret_record() -> void:
	var g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var seer = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var number = GameBoard.file_deduction(g, {"type": "marked", "a": p[3].id}, [seer])
	GamePresentation._evaluate_deduction(g, n, g.board[number - 1], 1.0, false)
	var entry: Dictionary = n.claim_record.get("secret:" + p[3].id, {})
	check(entry.get("type", "") == "secret" and entry.get("mod", "") == "marked", "a presented secret premise joins the player's track record")
	var agreement = preload("res://game/credibility.gd")._agreement(g, n)
	check(agreement == null or agreement is float, "the dawn track-record check reads secret claims without error")

## A Dowser "2 among p3, p4, p5" presented as "p3 is <type>"; suspicion of p3 and p4 before
## and after, and p3's pressure.
func _dowser_case(type: String, g = null) -> Dictionary:
	if g == null:
		g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	Mind.refresh_beliefs(g.w, n, " (baseline)")
	var before: Dictionary = n.suspicion.duplicate(true)
	var pressure0: float = p[3].pressure
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	var number = GameBoard.file_deduction(g, {"type": type, "a": p[3].id}, [dowser])
	GamePresentation._evaluate_deduction(g, n, g.board[number - 1], 1.0, false)
	return {"g": g, "dowser": dowser, "t": n.suspicion[p[3].id] - before[p[3].id], "o": n.suspicion[p[4].id] - before[p[4].id],
		"pressure": p[3].pressure - pressure0, "before": before}

func _suspicious() -> void:
	var evil: Dictionary = _dowser_case("evil")
	var hedged: Dictionary = _dowser_case("suspicious")
	print("suspicious: evil target %+.4f other %+.4f; suspicious target %+.4f other %+.4f, pressure %+.4f" % [evil.t, evil.o, hedged.t, hedged.o, hedged.pressure])
	# The connections model (purge phase 2): a card counts in full whatever the premise, and
	# "suspicious" halves only what a case's cards add together, so a one-card suspicious
	# case moves beliefs as far as the same card argued as evil. (The earlier model heard
	# its cards at half weight.) Pressure is #155's: the cards' lift on the subject, scaled
	# and capped, half in private; test_connections_cases checks the arithmetic.
	check(evil.t > 0.0 and absf(hedged.t - evil.t) < 0.005, "a one-card suspicious case moves its target as far as the same card argued as evil")
	check(absf(hedged.o - evil.o) < 0.005, "and everyone else as far too")
	var cap: float = float(Tuning.Workshop.SUSPICIOUS_PRESSURE_PER_RISE.private) * Tuning.Workshop.SUSPICIOUS_PRESSURE_CONNECTIONS_CAP
	check(hedged.pressure > 0.0 and hedged.pressure <= cap + 0.000001, "it presses the target, at most the private cap (%.4f, cap %.4f)" % [hedged.pressure, cap])
	check(evil.pressure == 0.0, "an evil premise adds no such pressure")
	# Refile the same card as evil: the hedge is withdrawn and the full effect lands once.
	var g = hedged.g
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var pressure1: float = p[3].pressure
	var firm = GameBoard.file_deduction(g, {"type": "evil", "a": p[3].id}, [hedged.dowser])
	GamePresentation._evaluate_deduction(g, n, g.board[firm - 1], 1.0, false)
	check(absf((n.suspicion[p[3].id] - hedged.before[p[3].id]) - evil.t) < 0.005, "refiled as evil, the same card lands at full weight, once")
	check(is_equal_approx(p[3].pressure, pressure1), "refiling doesn't press the target again")
	# Refile as suspicious again: nothing changes.
	var again = GameBoard.file_deduction(g, {"type": "suspicious", "a": p[3].id}, [hedged.dowser])
	var held: Dictionary = n.suspicion.duplicate(true)
	GamePresentation._evaluate_deduction(g, n, g.board[again - 1], 1.0, false)
	check(absf(n.suspicion[p[3].id] - held[p[3].id]) < 0.005 and is_equal_approx(p[3].pressure, pressure1), "refiled as suspicious after evil, nothing changes")
	# Codex review of PR #93: a second suspicious filing about the same target presses only
	# for what its own cards add, not the first filing's remembered rise.
	var g2 = _game()
	var first: Dictionary = _dowser_case("suspicious", g2)
	var n2 = g2.w.npcs[0]
	var q: Array = g2.w.npcs
	var before2: float = q[3].pressure
	var unrelated = _read(g2, q[6], "dowser", 1, {"group": [q[5].id], "count": 0})
	var second = GameBoard.file_deduction(g2, {"type": "suspicious", "a": q[3].id}, [unrelated])
	GamePresentation._evaluate_deduction(g2, n2, g2.board[second - 1], 1.0, false)
	# Under connections a reading that clears someone else still lifts the target a little
	# (the evil count has fewer places to go), so the second filing presses. It presses for
	# its own cards, read from its own stored case, not for the first filing's rise: a
	# weaker card presses less (purge phase 2).
	check(first.pressure > 0.0 and q[3].pressure - before2 < first.pressure - 0.05,
		"a second suspicious filing with a weaker card presses less than the first (%+.4f vs the first's %+.4f)" % [q[3].pressure - before2, first.pressure])

func _node(model, view, pick: Callable) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and pick.call(Solver.card_by_id(view, nd.card)):
			return id
	return ""

## A night watch report and the alibi it contradicts stay two cards.
func _contradiction_link() -> void:
	var g = _game()
	var goods: Array = g.w.living_good()
	var watcher = goods[1]
	var seen = goods[2]
	g.w.day = 2
	GameBoard.add_card(g, {"kind": "alibi", "subject": [seen.id], "home": true, "day": 1, "phase": C.NIGHT, "source": seen.id, "block": seen.home_block, "text": "%s says they were home on night 1." % seen.name})
	GameBoard.add_card(g, {"kind": "info", "source": watcher.id, "role": "nightwatch", "day": 1, "phase": 3, "data": {"block": seen.home_block, "seen": [seen.id]}, "text": "%s's watch on night 1 saw %s" % [watcher.name, seen.name]})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true  # as in the live editor
	var alibi = _node(model, view, func(c): return c.kind == "alibi" and c.subject == seen.id)
	var report = _node(model, view, func(c): return c.kind == "report" and c.source == watcher.id)
	check(model.connect_cards(report, alibi) == "", "linking a watch report and the alibi it contradicts works")
	check(not model.nodes.values().any(func(n): return n.kind == "contradiction") and model.nodes.has(alibi) and model.nodes.has(report), "both cards stay on the canvas: no merged contradiction card")
	check(model.contradicted_by(alibi) == report and model.contradicted_by(report) == "", "the alibi is the contradicted card, contradicted by the report")
	var premise: String = model.add_premise(seen.id, "evil", Vector2(400, 40))
	model.connect_cards(report, premise)
	var value: Dictionary = model.compile(premise)
	check(alibi in model.ancestors(premise) and value.cards.has(model.nodes[alibi].card) and value.disputes.size() == 1, "a case citing one card brings in the other and the dispute")
	var session = preload("res://workshop/session.gd").new()
	session.scenario = {"public_view": view}
	var restored = CanvasModel.new(view)
	restored.contradiction_links = true
	var why: String = restored.restore(model.export_data(), session)
	check(why == "" and restored.contradicted_by(alibi) == report, "a saved canvas keeps the contradiction link (%s)" % why)
	check(model.report_doubtable(alibi) and model.doubt_report(alibi) == "" and model.contradicted_by(alibi) == "", "doubting the report removes the contradiction")
	var challenge: String = model.selected
	check(model.nodes[challenge].kind == "modifier" and model.nodes[challenge].mode == "lying" and model.links.any(func(e): return e.from == alibi and e.to == challenge), "and puts a suspected lie on the report, with the alibi as its grounds")
	# Codex review of PR #93: only the alibi linked to the premise. Doubting the report must
	# keep the report and its suspected lie in the case.
	var m2 = CanvasModel.new(view)
	m2.contradiction_links = true
	var alibi2 = _node(m2, view, func(c): return c.kind == "alibi" and c.subject == seen.id)
	var report2 = _node(m2, view, func(c): return c.kind == "report" and c.source == watcher.id)
	m2.connect_cards(report2, alibi2)
	var premise2: String = m2.add_premise(seen.id, "good", Vector2(400, 40))
	m2.connect_cards(alibi2, premise2)
	check(m2.doubt_report(alibi2) == "", "doubting the report works with only the alibi in the case")
	var compiled: Dictionary = m2.compile(premise2)
	check(compiled.cards.has(m2.nodes[report2].card) and not compiled.get("reading_challenges", {}).is_empty(),
		"the report and its suspected lie stay in the case (cards %s)" % [compiled.cards])

## An outing explained by a gift brings in the walker's claim from the board.
func _auto_citation() -> void:
	var g = _game()
	var goods: Array = g.w.living_good()
	var watcher = goods[1]
	var walker = goods[2]
	g.w.day = 2
	GameBoard.add_card(g, {"kind": "info", "source": watcher.id, "role": "nightwatch", "day": 1, "phase": 3, "data": {"block": walker.home_block, "seen": [walker.id]}, "text": "%s's watch on night 1 saw %s" % [watcher.name, walker.name]})
	GameBoard.add_card(g, {"kind": "claim", "subject": [walker.id], "role": "nightwatch", "source": walker.id, "day": 1, "text": "%s says they're the Night Watch." % walker.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var report = _node(model, view, func(c): return c.kind == "report" and c.source == watcher.id)
	var claim = _node(model, view, func(c): return c.kind == "claim" and c.subject == walker.id)
	check(report != "" and claim != "", "the fixture has a watch report and the walker's claim")
	var premise: String = model.add_premise(walker.id, "good", Vector2(400, 40))
	model.connect_cards(report, premise)
	var key: String = "%s:%d" % [walker.id, 1]
	model.nodes[report].reasons[key] = "gift"
	var value: Dictionary = model.compile(premise)
	var claim_card: String = model.nodes[claim].card
	check(value.citations.get(key, "") == claim_card and claim_card in value.cards and claim_card in model.auto_cards, "a gift explanation cites the claim on the board and brings its card in, unasked")
	model.nodes[report].citations[key] = "none"
	var declined: Dictionary = model.compile(premise)
	check(not declined.citations.has(key) and claim_card not in declined.cards, "declining the claim leaves it out")

func _marked_answers() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	g.w.day = 2
	GameBoard.add_card(g, {"kind": "info", "source": p[2].id, "role": "dowser", "day": 1, "phase": 0, "data": {"group": [p[3].id, p[4].id, p[5].id], "count": 1}, "text": "dowse"})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	model.marked_answers = false
	var card: Dictionary = view.cards.filter(func(c): return c.get("role", "") == "dowser")[0]
	var a1: Dictionary = model.apply_answer(card, {}, "pick", p[3].id)
	var a2: Dictionary = model.apply_answer(card, a1, "pick", p[3].id)
	check(p[3].id in a1.get("positive", []) and not a2.has("marked") and p[3].id not in a2.get("positive", []), "with Marked answers off, a face cycles registered -> clear, never 'registered as Marked'")
	check(not model.apply_answer({"kind": "report", "role": "seer", "data": {"pair": [p[3].id, p[4].id], "yes": true}}, {}, "reg", "marked").has("registration"), "and the Seer registration can't be set to Marked")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
