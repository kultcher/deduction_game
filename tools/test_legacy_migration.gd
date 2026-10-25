## Live migration contracts: reversibility, preflight atomicity and explicit failure.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const LiveCanvas = preload("res://game/workshop_canvas.gd")
const Profiler = preload("res://workshop/profiler.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_reversible_totals()
	_strict_submission()
	_revisions_and_repeats()
	print("Legacy migration: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _clean():
	var g = Game.new()
	g.log_dir = "res://logs/migration/tests"
	g.detailed_logging = true
	g.new_case(54875, 10)
	check(g.workshop_effects, "ordinary games enable shared evaluation by default")
	g.set_workshop_effects(false)
	for real in g.w.npcs:
		var n = real.shadow if real.is_evil() else real
		if n == null:
			continue
		n.workshop_state = {}
		n.ledger = {}
		n.info_log = []
		n.known_claims = {}
		n.beliefs = []
		n.role = "warden"
		for id in n.suspicion:
			n.suspicion[id] = 0.3
	g.set_workshop_effects(true)
	return g

func _reversible_totals() -> void:
	var g = _clean()
	var n = g.w.living_good()[0]
	var source = g.w.npcs.filter(func(p): return p != n)[0]
	var target = g.w.npcs.filter(func(p): return p != n and p != source)[0]
	g.set_workshop_effects(false)
	for delta in [3.0, -6.0]:
		var before: float = n.suspicion[target.id]
		Mind.ledger_hear(g.w, n, "saturation", [[target.id, delta, false, "reversible", ""]], 1.0)
		check(is_equal_approx(n.suspicion[target.id], before + delta), "ledger retains the whole contribution beyond a display bound")
		check(Mind.susp(n, target.id) == clampf(before + delta, 0.0, 1.5), "consumers see bounded suspicion")
		n.ledger.saturation.weight = 0.0
		Mind.recompute_beliefs(g.w, n, "withdraw saturated entry")
		check(is_equal_approx(n.suspicion[target.id], before), "withdrawing a saturated contribution restores the exact baseline")
		n.ledger.erase("saturation")
	n.suspicion[target.id] = 0.1
	Mind.apply_info(g.w, n, source, {"role": "dowser", "day": 1, "phase": 0, "data": {"group": [target.id], "count": 0}}, 1.0)
	check(n.suspicion[target.id] < 0.0, "a clearing reading can cross the lower bound")
	g.set_workshop_effects(true)
	check(n.workshop_state.active and not n.workshop_state.owned.is_empty(), "a previously saturated clearing reading acquires shared ownership")
	target.alive = false
	target.death_cause = "demon"
	Mind.recompute_beliefs(g.w, n, "demon-victim reading")
	check(n.workshop_state.active, "a reading naming a demon victim does not prevent migration")
	var total: float = n.suspicion[target.id]
	Mind.adjust(g.w, n, target.id, 0.1, "counterevidence", "", false)
	check(is_equal_approx(n.suspicion[target.id], total + 0.1), "demon victims remain open to counterevidence")

func _strict_submission() -> void:
	var g = _clean()
	g.strict_evaluator = true
	var target = g.w.living_good()[0]
	var totem = g.add_card({"kind": "totem", "source": "evidence", "subject": [target.id], "block": "unknown", "day": 1, "phase": 0, "text": "An incomplete totem receipt."})
	var ded = g.file_deduction({"type": "evil", "a": target.id}, [totem])
	var check = g.workshop_readiness(g.board[ded - 1], g.w.living(), [], "deduction", "meeting")
	check(not check.ready and check.listeners.size() == g.w.living().size(), "readiness checks the entire real audience")
	check(check.issues.any(func(s): return "totem" in s), "unsupported reason names the totem card")
	var before = _state(g)
	g.state = "meeting"
	g.presented_today = false
	var reply = g.command("present %d" % ded)
	check("Cannot present" in reply and "totem" in reply, "strict meeting submission explains the unsupported card")
	check(not g.presented_today and _state(g) == before, "blocked meeting spends no floor, RNG, trust or belief")
	g.state = "talk"
	g.talk_with = target
	g.questions_left = 3
	g.command("convince %d" % ded)
	check(g.questions_left == 3 and _state(g) == before, "blocked private presentation spends no question or social effect")
	g.state = "nomination"
	g.w.meeting = {"pending": {"nominee": target.id, "by": "player"}}
	g.statement_used = false
	var vote_reply = g.command("accuse %d" % ded)
	check("Cannot present" in vote_reply and not g.statement_used and _state(g) == before, "blocked nomination does not spend the statement or disclose evidence")
	check(g.w.dlog.trace_events().any(func(e): return e.type == "workshop_fallback"), "every rejected submission records a fallback reason")
	g.strict_evaluator = false
	g.state = "talk"
	g.questions_left = 3
	var ordinary = g.command("convince %d" % ded)
	# No legacy route for presentations (Oct 25): ordinary play blocks it too, with the reason.
	check("Cannot present" in ordinary and g.questions_left == 3 and g.shared_fallbacks.size() > 0, "ordinary play blocks an unsupported presentation with its reason and records the fallback")

func _state(g) -> String:
	return JSON.stringify([g.w.rng.state, g.w.npcs.map(func(n): return [n.trust, n.pressure, n.suspicion, n.ledger, n.secret_spread, n.workshop_state, n.shadow.suspicion if n.shadow != null else {}])])

func _revision_fixture():
	var g = _clean()
	var n = g.w.living_good()[0]
	n.workshop_state.reasoning_mode = "full"
	n.workshop_state.confidence_mode = "scale"
	var people: Array = g.w.npcs.filter(func(p): return p != n)
	var source = people[0]
	var target = people[1]
	var other = people[2]
	var a = g.add_card({"kind": "info", "source": source.id, "role": "dowser", "day": 1, "phase": 0,
		"data": {"group": [target.id, other.id], "count": 1}, "text": "One registration in the pair."})
	var b = g.add_card({"kind": "info", "source": source.id, "role": "dowser", "day": 2, "phase": 0,
		"data": {"group": [other.id], "count": 0}, "text": "The other person registered clean."})
	var canvas = Canvas.new(LiveCanvas.view(g))
	canvas.nodes[canvas.selected].conclusion.target = target.id
	return {"g": g, "n": n, "target": target, "canvas": canvas,
		"a": "e:" + Shared.Evidence.normalize_card(g.board[a - 1]).id,
		"b": "e:" + Shared.Evidence.normalize_card(g.board[b - 1]).id}

func _revisions_and_repeats() -> void:
	var fixture = _revision_fixture()
	var g = fixture.g
	var n = fixture.n
	var canvas = fixture.canvas
	canvas.connect_cards(fixture.a, canvas.selected)
	var original = LiveCanvas.file(g, canvas.compile(canvas.selected))
	g._evaluate_deduction(n, g.board[original - 1], 1.0, true)
	var effect: float = n.workshop_state.requested.get(fixture.target.id, 0.0)
	var beliefs: Dictionary = n.suspicion.duplicate(true)
	canvas.connect_cards(fixture.b, canvas.selected)
	var revised = LiveCanvas.file(g, canvas.compile(canvas.selected), original)
	check(revised > original and g.board[original - 1].superseded_by == revised and g.board[revised - 1].revises == original, "revisions preserve both historical card numbers")
	check(n.suspicion == beliefs and n.workshop_state.presentations.has(str(original)), "filing alone leaves the listener on the version actually heard")
	g._evaluate_deduction(n, g.board[revised - 1], 1.0, true)
	check(n.workshop_state.facts.size() == 2 and n.workshop_state.requested.get(fixture.target.id, 0.0) >= effect, "new corroboration counts in full without demoting the old support")
	var control = _revision_fixture()
	control.canvas.connect_cards(control.a, control.canvas.selected)
	control.canvas.connect_cards(control.b, control.canvas.selected)
	var fresh = LiveCanvas.file(control.g, control.canvas.compile(control.canvas.selected))
	control.g._evaluate_deduction(control.n, control.g.board[fresh - 1], 1.0, true)
	for pair in [[g, n], [control.g, control.n]]:
		pair[1].trust = 0.7
		Mind.recompute_beliefs(pair[0].w, pair[1], "fixed trust parity")
	var equal = true
	for id in n.workshop_state.requested:
		equal = equal and absf(n.workshop_state.requested[id] - control.n.workshop_state.requested.get(id, 0.0)) < 0.000001
	check(equal, "a revised case has the same evidence effect as first hearing its complete support")
	g._evaluate_deduction(n, g.board[revised - 1], 0.6, true, "meeting")
	g.state = "talk"
	g.talk_with = n
	g.questions_left = 3
	g.free_repeats = 0
	var unchanged = _state(g)
	Profiler.start()
	var reply = g.command("convince %d" % revised)
	var profile = Profiler.finish()
	check("I heard you say that at the meeting" in reply and g.questions_left == 3 and g.free_repeats == 1, "a meeting repeat is acknowledged and free once per conversation")
	check(profile.counters.values().count(1) > 0 and profile.rows.all(func(row): return row.stage != "joint_effects" and row.stage != "jury"), "an unchanged repeat does not run the evaluator again")
	check(unchanged == _state(g), "the free repeat changes no beliefs, pressure, trust or RNG")
	g.command("convince %d" % revised)
	check(g.questions_left == 2, "a second repeat still costs a question")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
