extends SceneTree
const Game = preload("res://game/game.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Solver = preload("res://workshop/solver.gd")
const Eval = preload("res://workshop/case_eval.gd")
const Challenges = preload("res://workshop/reading_challenges.gd")
const Editor = preload("res://ui/live_case_workshop.gd")
const Live = preload("res://game/workshop_canvas.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Game.new()
	g.new_case(44814, 10)
	g.w.dlog.detailed = false
	var number = g.add_card({"kind": "info", "role": "surveyor", "source": "greta", "subject": [], "day": 0, "phase": 3, "data": {"count": 1}, "text": "Mechanics Surveyor."})
	var other = g.add_card({"kind": "info", "role": "dowser", "source": "odette", "subject": ["greta"], "day": 1, "phase": 1, "data": {"group": ["greta", "hollis"], "count": 1}, "text": "Independent mechanics support."})
	for type in ["notdemon", "secret_mod", "role", "notrole", "lied", "truthful", "misled", "unreliable"]:
		var conclusion = {"type": type, "a": "greta", "role": "surveyor", "mod": "delusional", "card": number}
		var filed = g.file_deduction(conclusion, [number, other], {}, 0, true)
		check(filed > 0, type + " files: " + g.last_error)
		var prepared = Assess.prepare(g.workshop_snapshot([filed], "nisha"))
		check(prepared.ready, type + " has a shared adapter: " + str(prepared.issues))
		if not prepared.ready:
			continue
		var result = Eval.evaluate(prepared.view, prepared.case, prepared.listener)
		check(not result.impossible and is_finite(result.posterior), type + " has a finite posterior")
		var response = g._evaluate_deduction(g.w.by_id.nisha, g.board[filed - 1], 1.0)
		check(response.get("workshop", false), type + " uses the shared judge in live delivery")
		if type == "notdemon":
			check(result.prior > 0.0 and result.prior < 1.0 and prepared.view.world_options.get("identities", false), "notdemon enables the same identity domain as demon")
			var opposite = prepared.case.duplicate(true)
			opposite.conclusion.type = "demon"
			check(is_equal_approx(result.posterior + Eval.evaluate(prepared.view, opposite, prepared.listener).posterior, 1.0), "notdemon negates the same identity question")
		if type == "secret_mod":
			for w in Solver.universe(prepared.view):
				if Solver.holds(prepared.view, w, prepared.case.conclusion):
					check(w.modifier == "delusional" and (w.holders & (1 << Solver.person_index(prepared.view, "greta"))) != 0, "modifier question uses the existing holder bits")
		if type == "unreliable":
			_fraction_parity(prepared)
	for type in ["secret", "red_herring"]:
		var filed = g.file_deduction({"type": type, "a": "greta"}, [number, other], {}, 0, true)
		check(not Assess.prepare(g.workshop_snapshot([filed], "nisha")).ready, type + " stays explicit without a represented fact")
	for type in ["protect", "spare"]:
		var filed = g.file_deduction({"type": type, "a": "greta"}, [number, other], {}, 0, true)
		var before: int = g.w.dlog.entries.filter(func(e): return e.type == "legacy_fallback").size()
		check(g._presentation_gate(g.board[filed - 1], [g.w.by_id.nisha], [], "", "meeting") and g._workshop_native_social, type + " is social speech")
		check(g.w.dlog.entries.filter(func(e): return e.type == "legacy_fallback").size() == before, type + " does not count as fallback")
	await _ui(g, number, other)
	print("Mechanics conclusion checks: %d; failures: %d" % [checks, fails])
	quit(1 if fails else 0)

func _ui(g, number: int, other: int) -> void:
	var editor = Editor.new()
	editor.g = g
	root.add_child(editor)
	await process_frame
	editor.add_evidence(number)
	editor.add_evidence(other)
	editor.premise_person.select(Solver.person_index(editor.board.view, "greta"))
	for type in ["secret_mod", "role", "unreliable"]:
		editor.premise_type.select(editor.premise_types().find(type))
		editor._add_premise()
		var id: String = editor.board.selected
		for n in [number, other]:
			editor.board.connect_cards("e:" + Live.Evidence.normalize_card(g.board[n - 1]).id, id)
		editor._open_answer(id)
		var choices: Array = editor.case_box.find_children("*", "OptionButton", true, false)
		check(not choices.is_empty(), type + " exposes its question controls")
		if type == "secret_mod":
			choices[0].item_selected.emit(Assess.C.SECRET_MOD_LIST.find("delusional"))
		elif type == "role":
			choices[0].item_selected.emit(Assess.C.GOOD_ROLES.find("surveyor"))
		else:
			choices[0].item_selected.emit(1)
		var filed: int = editor._file()
		check(filed > 0, type + " files from the actual editor: " + g.last_error)
		if filed > 0:
			var captured = Assess.prepare(g.workshop_snapshot([filed], "nisha"))
			check(captured.ready, type + " retains question parameters after UI filing: " + str(captured.issues))
		editor.answer_window.hide()
	editor.queue_free()
	await process_frame

func _fraction_parity(prepared: Dictionary) -> void:
	var view: Dictionary = prepared.view
	var listener: Dictionary = prepared.listener
	var report: Dictionary = view.cards.filter(func(c): return c.get("kind") == "report" and c.source == "greta")[0]
	var knowledge: Dictionary = listener.knowledge.duplicate(true)
	if report.source not in knowledge.good:
		knowledge.good.append(report.source)
	var reference: Array = Solver.solve(view, [], {}, {}, knowledge).worlds
	var denominator = {}
	var numerator = {}
	for world in reference:
		if not Solver.Domain.healthy(view, world, report.source):
			continue
		var key = str([world.evil, world.get("modifier", "marked"), world.get("holders", 1 << world.marked)])
		denominator[key] = true
		if Solver._report_holds(view, world, report, {}) and Solver.Roles.fits(view, world, [report], listener.knowledge) and Solver.Domain.claims_compatible([report], listener.knowledge):
			numerator[key] = true
	var expected: float = float(numerator.size()) / maxf(denominator.size(), 1)
	var actual = Challenges._fraction(view, report, listener.knowledge, Solver.solve(view, [], {}, {}, listener.knowledge).worlds)
	check(actual.fraction == expected and actual.possible == not denominator.is_empty(), "integer challenge counts match the original counting routine")
