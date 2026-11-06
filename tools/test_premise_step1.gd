## Premises pass step 1 (docs/premises_plan.md): a presented premise shapes beliefs by its
## target (the target takes the full effect, everyone else the Insight spillover, and the
## shaping is remembered), a clearly wrong premise costs trust, a rejected premise steers no
## preference, the movement notes only follow killer-side premises, and the test juror says
## when a defence's evidence points the other way.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Tuning = preload("res://sim/tuning.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Presentations = preload("res://sim/dialogue_presentations.gd")
const Canvas = preload("res://game/workshop_canvas.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_spillover()
	_trust_cost()
	_preference()
	_movement_notes()
	_preview_hint()
	_codex_review()
	print("Premises step 1: %d checks, %d failures" % [checks, fails])
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
			p.npc_trust[id] = 1.0
	var n = g.w.npcs[0]
	n.alignment = "good"
	n.role = "warden"
	n.traits.insight = insight
	n.traits.confidence = 0.5
	# Full reasoning: Insight then changes only the spillover, not the attention budget.
	n.workshop_state["reasoning_mode"] = "full"
	return g

func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	return g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if day == 0 else 0, "data": data,
		"text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})

## A Dowser "2 among p3, p4, p5": it raises all three, so a case about p3 spills onto p4, p5.
func _case(g, type: String, target) -> int:
	var p: Array = g.w.npcs
	var dowser = _read(g, p[2], "dowser", 1, {"group": [p[3].id, p[4].id, p[5].id], "count": 2})
	return g.file_deduction({"type": type, "a": target.id}, [dowser])

func _moves(insight: float) -> Dictionary:
	var g = _game(insight)
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	Mind.refresh_beliefs(g.w, n, " (baseline)")
	var before: Dictionary = n.suspicion.duplicate(true)
	var number = _case(g, "evil", p[3])
	g._evaluate_deduction(n, g.board[number - 1], 1.0, false)
	var after: Dictionary = n.suspicion.duplicate(true)
	Mind.refresh_beliefs(g.w, n, " (later refresh)")
	return {"target": after[p[3].id] - before[p[3].id], "other": after[p[4].id] - before[p[4].id],
		"remembered": is_equal_approx(after[p[4].id], n.suspicion[p[4].id]) and is_equal_approx(after[p[3].id], n.suspicion[p[3].id]),
		"spill": float(n.workshop_state.get("presentation_agreement", {}).size())}

func _spillover() -> void:
	var low: Dictionary = _moves(0.0)
	var high: Dictionary = _moves(1.0)
	print("spillover: low Insight target %+.4f other %+.4f; high Insight target %+.4f other %+.4f" % [low.target, low.other, high.target, high.other])
	check(low.target > 0.0 and high.target > 0.0 and is_equal_approx(low.target, high.target), "the premise's target takes the full effect at any Insight")
	check(low.other > 0.0 and high.other > low.other, "everyone else moves less, and less still at low Insight")
	var ratio: float = low.other / high.other if high.other != 0.0 else 0.0
	var expected: float = Tuning.Workshop.PREMISE_SPILLOVER_MIN / Tuning.Workshop.PREMISE_SPILLOVER_MAX
	check(absf(ratio - expected) < 0.02, "the spillover runs from %.0f%% to %.0f%% of the case's effect (low/high %.3f, expected %.3f)" % [100 * Tuning.Workshop.PREMISE_SPILLOVER_MIN, 100 * Tuning.Workshop.PREMISE_SPILLOVER_MAX, ratio, expected])
	check(low.remembered and high.remembered, "the shaping is remembered: a later refresh reproduces it")
	check(high.other < high.target, "a case moves its target more than the people it only mentions")

func _trust_cost() -> void:
	var p: Array
	# Wrong: "p3 is good" against a Dowser count that puts two of three evil.
	var g = _game()
	var n = g.w.npcs[0]
	p = g.w.npcs
	var wrong = _case(g, "good", p[3])
	var t0: float = n.trust
	var r = g._evaluate_deduction(n, g.board[wrong - 1], 1.0, false)
	print("wrong premise: agreement %.3f, trust %.3f -> %.3f" % [r.agreement, t0, n.trust])
	check(r.agreement <= Tuning.Trust.PRESENTATION_WRONG_AGREEMENT, "the evidence clearly argues against the premise")
	check(is_equal_approx(n.trust, t0 - Tuning.Trust.PRESENTATION_WRONG_COST), "a clearly wrong premise costs the trust a good one earns")
	var t1: float = n.trust
	g._evaluate_deduction(n, g.board[wrong - 1], 1.0, false)
	check(is_equal_approx(n.trust, t1), "repeating it costs nothing more")
	# Right: "p3 is evil" on the same cards earns the reward, not the cost.
	var g2 = _game()
	var n2 = g2.w.npcs[0]
	var right = _case(g2, "evil", g2.w.npcs[3])
	var t2: float = n2.trust
	var r2 = g2._evaluate_deduction(n2, g2.board[right - 1], 1.0, false)
	print("right premise: agreement %.3f, trust %.3f -> %.3f" % [r2.agreement, t2, n2.trust])
	check(n2.trust >= t2, "a supported premise never costs trust")

func _preference() -> void:
	# Rejected: "p3 is good" against the evidence steers no protection.
	var g = _game()
	var n = g.w.npcs[0]
	var p: Array = g.w.npcs
	var rejected = _case(g, "good", p[3])
	g._evaluate_deduction(n, g.board[rejected - 1], 1.0, false)
	check(float(n.protect_pref.get(p[3].id, 0.0)) == 0.0, "a rejected 'X is good' doesn't steer Warden and Martyr picks toward X")
	# Accepted: a Dowser clear of p6 backs "p6 is good".
	var g2 = _game()
	var n2 = g2.w.npcs[0]
	var q: Array = g2.w.npcs
	var clear = _read(g2, q[2], "dowser", 1, {"group": [q[6].id], "count": 0})
	var accepted = g2.file_deduction({"type": "good", "a": q[6].id}, [clear])
	var r = g2._evaluate_deduction(n2, g2.board[accepted - 1], 1.0, false)
	print("accepted defence: agreement %.3f, protect %.3f" % [r.agreement, float(n2.protect_pref.get(q[6].id, 0.0))])
	check(r.agreement >= Tuning.Workshop.PREMISE_PREF_MIN_AGREEMENT and float(n2.protect_pref.get(q[6].id, 0.0)) > 0.0, "an accepted 'X is good' still steers protection toward X")
	Mind.refresh_beliefs(g2.w, n2, " (later refresh)")
	check(float(n2.protect_pref.get(q[6].id, 0.0)) > 0.0, "the accepted preference survives a later refresh")

func _movement_notes() -> void:
	var g = _game()
	var n = null
	for p in g.w.npcs:
		if Presentations.Dialogue.has_voice(p.id):
			n = p
			break
	if n == null:
		check(false, "a voiced listener exists for the movement-notes check")
		return
	var other = g.w.npcs.filter(func(p): return p != n)[0]
	var ev = {"movement": ["Seen elsewhere: %s's sighting on night 1 places them away from the victim." % other.name]}
	var assessment = {"case_eval": ev, "reasoning": {"status": "provisional"}, "agreement": 0.7, "path_kind": "reading"}
	var view = {"listener": {"reasoning_mode": "full"}}
	var killer = Presentations.render_workshop_reply(g.w, n, {"type": "evil", "a": other.id}, [other.id], assessment, view, {}, "accept", false, false, "Those reports convince me.", {})
	var role = Presentations.render_workshop_reply(g.w, n, {"type": "role", "a": other.id, "role": "warden"}, [other.id], assessment, view, {}, "accept", false, false, "Those reports convince me.", {})
	check(killer.text.length() > role.text.length(), "the 'seen elsewhere' note follows a killer-side premise (%d chars) but not a role premise (%d)" % [killer.text.length(), role.text.length()])

func _preview_hint() -> void:
	var view = {"people": [{"id": "x", "name": "Xan"}, {"id": "y", "name": "Yara"}]}
	var ev = {"impossible": false, "people": {"x": {"prior": 0.3, "posterior": 0.5}, "y": {"prior": 0.3, "posterior": 0.3}}}
	var result = {}
	Canvas.feedback(view, {"conclusion": {"type": "good", "target": "x"}, "answers": {}, "positions": {}}, ev, result)
	check(result.get("against", "") == "x" and str(result.get("raises_text", "")).contains("Xan"), "a defence whose cards make its subject look worse says so (%s)" % result.get("raises_text", ""))
	var calm = {}
	var ev2 = {"impossible": false, "people": {"x": {"prior": 0.3, "posterior": 0.1}}}
	Canvas.feedback(view, {"conclusion": {"type": "good", "target": "x"}, "answers": {}, "positions": {}}, ev2, calm)
	check(not calm.has("against"), "a defence the cards support has no such note")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)


## Codex review of PR #92.
func _codex_review() -> void:
	# 1. The "without" side drops a shaped card, not every other card of a non-alignment
	# presentation that shares it.
	var presentations := {"a": {"selected": ["A"], "arguments": []}, "m": {"selected": ["A", "B"], "arguments": []}, "o": {"selected": ["C"], "arguments": []}}
	var rest: Dictionary = Shared.without_shaping(presentations, {"keys": ["a", "m"], "trim": ["m"], "cards": ["A"]})
	check(not rest.has("a") and rest.has("m") and rest.m.selected == ["B"] and rest.has("o"),
		"the comparison plan drops shaped cards only; a Marked presentation keeps its own (%s)" % [rest])
	# 2. A presentation-backed argument (a cited deduction) needs the same acceptance as a
	# presented premise before it sets a protect preference.
	var g = _game()
	var n = g.w.npcs[0]
	var t = g.w.npcs[1]
	for agreement in [0.3, 0.7]:
		n.ledger = {"workshop:tell:k:%s" % t.id: {"weight": agreement, "justs": [], "rel": [], "meta": {"kind": "arg", "workshop_case": "k", "conclusion": {"type": "good", "a": t.id}}}}
		Mind._refresh_ledger_preferences(g.w, n)
		var has_pref: bool = float(n.protect_pref.get(t.id, 0.0)) > 0.0
		check(has_pref == (agreement >= Tuning.Workshop.PREMISE_PREF_MIN_AGREEMENT), "a cited defence at agreement %.1f %s a protect preference" % [agreement, "sets" if has_pref else "doesn't set"])
