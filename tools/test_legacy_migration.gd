## Live migration contracts: reversibility, preflight atomicity and explicit failure.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_reversible_totals()
	_strict_submission()
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
	var totem = g.add_card({"kind": "totem", "source": "evidence", "subject": [target.id], "block": target.home_block, "day": 1, "phase": 0, "text": "A totem was found."})
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
	check("Shared assessment unavailable" in ordinary and g.questions_left == 2, "ordinary play reports the fallback and retains the existing response")

func _state(g) -> String:
	return JSON.stringify([g.w.rng.state, g.w.npcs.map(func(n): return [n.trust, n.pressure, n.suspicion, n.ledger, n.secret_spread, n.workshop_state, n.shadow.suspicion if n.shadow != null else {}])])

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
