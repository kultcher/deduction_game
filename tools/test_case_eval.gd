## CaseEval foundation checks (docs/CASE_REASONING.md).
## Runs the six model-v5 checkpoint specimens through the new evaluator, prints how each
## compares with the old model, and asserts the semantics the new model must keep.
##   godot --headless --path . --script res://tools/test_case_eval.gd
extends SceneTree

const CaseEval = preload("res://workshop/case_eval.gd")
const Solver = preload("res://workshop/solver.gd")
const PATH = "res://tests/fixtures/workshop_checkpoint_v5.json"

var fails = 0

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	var data = JSON.parse_string(FileAccess.open(PATH, FileAccess.READ).get_as_text())
	var by_name = {}
	print("specimen | old stance (agreement) | new: listener prior -> posterior, category | neutral category | top rivals")
	for ex in data.examples:
		by_name[ex.name] = ex
		var r = CaseEval.evaluate(ex.view, ex.case, ex.listener)
		var n = CaseEval.evaluate(ex.view, ex.case)
		var old_claim = ex.expected.claims[0]
		print("%s | %s (%.2f) | %.2f -> %.2f, %s | %s | %s" % [ex.name, old_claim.stance, ex.expected.agreement, r.prior, r.posterior, r.category, n.category,
			", ".join(PackedStringArray(r.rivals.map(func(x): return "%s %.2f" % [x.id, x.posterior])))])
	var core = by_name["core"]
	_private_state_parity(core)
	_solver_cache_parity(core)
	var target: String = core.case.conclusion.target
	var rc = CaseEval.evaluate(core.view, core.case, core.listener)
	# Collateral: the readings raise Hollis even when the headline isn't settled (v5 too).
	_check(rc.people.hollis.posterior > rc.people.hollis.prior, "core: Hollis rises as a consequence of the readings (%.2f -> %.2f)" % [rc.people.hollis.prior, rc.people.hollis.posterior])
	# The Constance/Nisha alternative stays open: Nisha is a live rival, and the case isn't strong.
	_check(rc.rivals.any(func(x): return x.id == "nisha") or rc.people.nisha.posterior > 0.2, "core: Nisha remains a live alternative (%.2f)" % rc.people.nisha.posterior)
	_check(CaseEval.evaluate(core.view, core.case).category != "strong", "core: the three readings alone don't strongly settle %s" % target)
	# Repeating a card adds nothing (one witness counts once).
	var twice = core.case.duplicate(true)
	twice.cards = core.case.cards + [core.case.cards[0]]
	var r2 = CaseEval.evaluate(core.view, twice, core.listener)
	_check(absf(r2.posterior - rc.posterior) < 1e-9, "a repeated card counts once")
	# Answers are the player's theory, never extra evidence.
	var answered = core.case.duplicate(true)
	answered["answers"] = {"rumor": {"positive": ["nisha"]}}
	var ra = CaseEval.evaluate(core.view, answered, core.listener)
	_check(absf(ra.posterior - rc.posterior) < 1e-9 and ra.theory_fit < 1.0, "answers change the theory's fit (%.2f), not the evidence" % ra.theory_fit)
	# The Surveyor could be counting a Marked Bart: the single card can't be strong.
	var mb = by_name["surveyor_could_be_marked"]
	_check(CaseEval.evaluate(mb.view, mb.case).category in ["none", "weak", "contradicts"], "one Surveyor count alone is at most weak evidence about Constance")
	# A doubted source counts for less.
	var doubt = core.listener.duplicate(true)
	doubt["reading_reliability"] = {"report:bart:survey": 0.5, "report:merrin:rumor": 0.5, "report:fenwick:dowse": 0.5}
	var rd = CaseEval.evaluate(core.view, core.case, doubt)
	_check(absf(rd.people.hollis.posterior - rd.people.hollis.prior) < absf(rc.people.hollis.posterior - rc.people.hollis.prior),
		"doubting the readings weakens their consequences (Hollis shift %.2f vs %.2f)" % [rd.people.hollis.posterior - rd.people.hollis.prior, rc.people.hollis.posterior - rc.people.hollis.prior])
	# Strength labels exist for the board.
	var st = CaseEval.strength(core.view, core.case)
	_check(st.text != "", "strength label: %s %s" % [st.text, st.reason])
	# Timing: ten listeners (the town) on the converging case, cold then warm.
	var conv = by_name["converging_intermediates"]
	Solver.universes.clear()
	Solver.report_matches.clear()
	CaseEval._valid_cache.clear()
	var t0 = Time.get_ticks_usec()
	for i in range(10):
		CaseEval.evaluate(conv.view, conv.case, conv.listener)
	var cold = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for i in range(10):
		CaseEval.evaluate(conv.view, conv.case, conv.listener)
	var warm = (Time.get_ticks_usec() - t0) / 1000.0
	print("timing: ten listener evaluations, %d worlds: cold %.0f ms, warm %.0f ms" % [Solver.universe(conv.view).size(), cold, warm])
	_check(warm < 1000.0, "ten listener evaluations run in about a second or less (%.0f ms)" % warm)
	print("CASE EVAL FAILURES: %d" % fails)
	quit(1 if fails else 0)

## Compare compressed private-reading states against the original dense 3^n
## enumeration. Compression may change runtime, never a probability or consequence.
func _private_state_parity(example: Dictionary) -> void:
	var view: Dictionary = example.view.duplicate(true)
	var own: Array = view.cards.filter(func(c): return c.kind == "report").slice(0, 3)
	var correlated: Dictionary = own[0].duplicate(true)
	correlated.id += ":later-observation"
	correlated["fact_id"] = correlated.id
	correlated.observed_at.day += 1
	view.cards.append(correlated)
	own.append(correlated)
	var value = Solver.empty_case()
	value.conclusion = example.case.conclusion.duplicate(true)
	value.cards = view.cards.filter(func(c): return c not in own).map(func(c): return c.id)
	var listener: Dictionary = example.listener.duplicate(true)
	listener.knowledge.own_reports = own.map(func(c): return c.id)
	var compact = CaseEval.evaluate(view, value, listener)
	var cc = CaseEval.compile(view, Solver.selected(view, value), value, own)
	var saved = CaseEval._own_counts(view, cc, own)
	var ns = int(pow(3, own.size()))
	var codes: Array = []
	for i in range(ns):
		var code = PackedByteArray()
		code.resize(own.size())
		var v = i
		for j in range(own.size() - 1, -1, -1):
			code[j] = v % 3
			v /= 3
		codes.append(code)
	var counts = PackedFloat64Array()
	counts.resize(cc.team.size() * ns)
	counts.fill(0.0)
	var indices = PackedInt32Array()
	for i in range(cc.class_of.size()):
		var full = codes.find(saved.codes[saved.of[i]])
		indices.append(full)
		counts[cc.class_of[i] * ns + full] += 1.0
	var key = hash([cc.key, own.map(func(c): return c.get("fact_id", c.id))])
	CaseEval._own_cache[key] = {"states": ns, "counts": counts, "of": indices, "codes": codes}
	var dense = CaseEval.evaluate(view, value, listener)
	CaseEval._own_cache[key] = saved
	_check(absf(compact.posterior - dense.posterior) < 1e-9 and compact.people == dense.people and compact.acceptance == dense.acceptance, "sparse private states preserve dense probabilities, collateral effects and reading acceptance")
	_check(saved.states < ns, "private states allocate only combinations present in legal worlds (%d instead of %d)" % [saved.states, ns])

func _solver_cache_parity(example: Dictionary) -> void:
	var cards = Solver.selected(example.view, example.case)
	Solver.reuse_solves = false
	var reference = Solver.solve(example.view, cards, {}, {}, example.listener.knowledge)
	Solver.reuse_solves = true
	var first = Solver.solve(example.view, cards, {}, {}, example.listener.knowledge)
	var repeat = Solver.solve(example.view, cards, {}, {}, example.listener.knowledge)
	_check(reference == first and first == repeat, "memoized solves preserve the exhaustive answer")
	var changed = example.listener.knowledge.duplicate(true)
	changed.good = example.view.people.map(func(p): return p.id)
	_check(Solver.solve(example.view, cards, {}, {}, changed).worlds.is_empty(), "solver memo invalidates when listener knowledge changes")
	var detailed = Solver.analyze(example.view, example.case, example.listener.knowledge)
	var live = Solver.analyze(example.view, example.case, example.listener.knowledge, false)
	detailed.erase("conflicts")
	live.erase("conflicts")
	_check(detailed == live, "deferring conflict enumeration changes no live assessment result")
