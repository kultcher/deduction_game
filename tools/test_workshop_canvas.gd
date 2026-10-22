extends SceneTree
const Session = preload("res://workshop/session.gd")
const Model = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Jury = preload("res://workshop/jury.gd")
var checks = 0
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var s = Session.new(692)
	var board = Model.new(s.scenario.public_view)
	check(board.nodes.values().filter(func(n): return n.kind == "evidence").size() == 16, "all fixture evidence has one distinct canvas copy")
	board.mockup()
	var main: String = board.selected
	var hollis: String = board.nodes.keys().filter(func(id): return board.nodes[id].kind == "premise" and board.nodes[id].conclusion.get("target") == "hollis")[0]
	var accusation = board.compile(main)
	check(accusation.cards.size() == 5 and accusation.disputes.size() == 1, "mockup compiles the reading chain and challenged alibi into one case")
	check(s.validate_case(accusation) == "", "canvas case passes the same input validation as list cases")
	var analysis = Solver.analyze(board.view, accusation)
	check(analysis.compatible == 2 and analysis.movement_ok and analysis.errors.is_empty(), "quoting a challenged alibi no longer asserts home and out together")
	var roots = board.compile(hollis)
	check(roots.cards == ["dowse", "rumor", "survey"], "Merrin's shared links contribute one original report")
	var flat = Model.new(board.view)
	var flat_root = flat.add_premise("hollis", "evil", Vector2.ZERO)
	for id in ["survey", "rumor", "dowse"]:
		flat.connect_cards("e:" + id, flat_root)
	var neutral: Dictionary = s.baseline[3].duplicate(true)
	for id in neutral.npc_trust:
		neutral.npc_trust[id] = 0.5
		neutral.suspicion[id] = 0.1
	var linked = Jury.evaluate(board.view, roots, neutral.duplicate(true))
	var directly = Jury.evaluate(board.view, flat.compile(flat_root), neutral.duplicate(true))
	check(linked.agreement == directly.agreement and linked.suspicion_delta == directly.suspicion_delta, "Merrin through Bart/Fenwick and three direct links have identical evidential value")
	for insight in [0.1, 0.5, 0.9]:
		var bounded = neutral.duplicate(true)
		bounded.reasoning_mode = "bounded"
		bounded.insight = insight
		check(Jury.evaluate(board.view, roots, bounded.duplicate(true)).agreement == Jury.evaluate(board.view, flat.compile(flat_root), bounded.duplicate(true)).agreement, "the same chained/direct roots also agree under bounded Insight %.1f" % insight)
	var structure = flat.add_premise("constance", "support", Vector2.ZERO)
	flat.nodes[structure].positions = {"nisha": "evil"}
	flat.nodes[flat_root].positions = {"nisha": "good"}
	flat.connect_cards(structure, flat_root)
	check(not Solver.analyze(flat.view, flat.compile(flat_root)).errors.is_empty(), "incompatible assumptions on a root and supporting premise are exposed")
	var nested = flat.add_premise("constance", "support", Vector2.ZERO)
	flat.nodes[nested].positions = {"nisha": "good"}
	flat.connect_cards(nested, structure)
	flat.nodes[flat_root].positions = {}
	check(not Solver.analyze(flat.view, flat.compile(flat_root)).errors.is_empty(), "conflicting assumptions inside a nested branch cannot silently overwrite each other")
	board.nodes["e:rumor"].at = [987.0, 333.0]
	check(Jury.evaluate(board.view, board.compile(hollis), neutral.duplicate(true)).agreement == linked.agreement, "physical layout cannot alter conviction")
	var no_alibi = accusation.duplicate(true)
	no_alibi.cards = ["survey", "rumor", "dowse"]
	no_alibi.lines = []
	no_alibi.disputes = []
	var before = Jury.evaluate(board.view, no_alibi, neutral.duplicate(true))
	var after = Jury.evaluate(board.view, accusation, neutral.duplicate(true))
	check(after.agreement > before.agreement and after.assessment.compatible == before.assessment.compatible, "challenged alibi favors Constance without deleting the Nisha alternative")
	check(after.response.contains("not proof") and after.support_model.factors.size() == 1, "false alibi remains one explicit circumstantial factor, not proof of evil")
	var duplicate_dispute = accusation.duplicate(true)
	duplicate_dispute.disputes.append(duplicate_dispute.disputes[0].duplicate(true))
	check(Jury.evaluate(board.view, duplicate_dispute, neutral.duplicate(true)).agreement == after.agreement, "repeating the same contradiction cannot multiply its factor")
	var watch_case = accusation.duplicate(true)
	watch_case.cards = ["survey", "rumor", "dowse", "watch1", "alibi1"]
	watch_case.lines = []
	watch_case.disputes = [{"reports": ["alibi1", "watch1"], "challenged": "alibi1", "preferred": "watch1"}]
	var impaired_watch = neutral.duplicate(true)
	impaired_watch.reading_reliability[Solver.semantic_key(Solver.card_by_id(board.view, "watch1"))] = 0.0
	var doubted = Jury.evaluate(board.view, watch_case, impaired_watch)
	check(doubted.support_model.factors.is_empty() and doubted.support_model.quoted_cards == ["alibi1"], "rejecting the observation removes the false-alibi factor without endorsing the quoted alibi")
	var unframed = accusation.duplicate(true)
	unframed.disputes = []
	check(not Solver.analyze(board.view, unframed).movement_ok, "the same accounts still conflict if both are endorsed")
	check(Solver.analyze(board.view, accusation).movement_ok, "framed/unframed movement caches do not leak into each other")
	var doubter = neutral.duplicate(true)
	doubter.reasoning_mode = "bounded"
	doubter.insight = 0.9
	check(Jury.evaluate(board.view, accusation, doubter).reasoning.status != "inconsistent", "bounded reasoning also understands a challenged statement")
	check(flat.connect_cards(flat_root, "e:rumor") != "", "circular premise/evidence links are refused")
	var gift = Model.new(board.view)
	check(gift.connect_cards("e:gift_claim", "e:vigil1") == "" and gift.links[0].kind == "explains_outing", "an applicable walking claim defaults to an outing explanation")
	check(gift.connect_cards("e:vigil1", gift.selected) == "" and gift.compile(gift.selected).citations.get("constance:1") == "gift_claim", "role links compile to the same explicit gift citation as the old editor")
	gift.nodes["e:vigil1"].reasons = {"constance:1": "evil"}
	check(gift.compile(gift.selected).reasons["constance:1"] == "evil", "an explicit outing answer overrides the automatic gift-explanation default")
	var wrong_gift = Model.new(board.view)
	wrong_gift.connect_cards("e:gift_claim", "e:alibi1")
	check(wrong_gift.links[0].kind == "read_together", "a walking claim does not explain a report that the person stayed home")
	var conflict_root = board.add_premise("constance", "conflict", Vector2.ZERO)
	var merged: String = board.nodes.keys().filter(func(id): return board.nodes[id].kind == "contradiction")[0]
	board.connect_cards(merged, conflict_root)
	check(Solver.analyze(board.view, board.compile(conflict_root)).entailment == "forced" and Jury.evaluate(board.view, board.compile(conflict_root), neutral.duplicate(true)).suspicion_delta == 0, "a conflict premise can ask about the original accounts without assigning alignment guilt")
	board.unlink(merged, conflict_root)
	var group: String = board.nodes.keys().filter(func(id): return board.nodes[id].kind == "contradiction")[0]
	check(board.nodes["e:alibi1"].get("merged") == group and board.nodes["e:vigil1"].get("merged") == group, "merged contradiction retains both hidden original copies")
	var saved = JSON.parse_string(JSON.stringify(board.export_data()))
	var restored = Model.new(board.view)
	check(restored.restore(saved, s) == "" and restored.compile(main) == board.compile(main), "canvas layout and graph semantics survive JSON restoration")
	var corrupt = saved.duplicate(true)
	corrupt.nodes[group].dispute.preferred = "rumor"
	var unchanged = restored.export_data()
	check(restored.restore(corrupt, s) != "" and restored.export_data() == unchanged, "invalid contradiction provenance is rejected atomically")
	board.unmerge(group)
	check(not board.nodes["e:alibi1"].has("merged") and not board.nodes["e:vigil1"].has("merged") and board.compile(main).disputes.is_empty(), "unlink restores the original cards and removes the false-alibi interpretation")
	var deleted = Model.new(board.view)
	var disposable = deleted.add_premise("constance", "suspicious", Vector2.ZERO)
	deleted.connect_cards("e:vigil1", disposable)
	deleted.connect_cards("e:alibi1", disposable)
	deleted.connect_cards("e:vigil1", "e:alibi1")
	deleted.remove_premise(disposable)
	check(Model.new(board.view).restore(JSON.parse_string(JSON.stringify(deleted.export_data())), s) == "", "removing a premise also cleans merged originals' retained link references")
	await _ui()
	print("Workshop canvas: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _ui() -> void:
	var scene = load("res://ui/case_workshop.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var canvas = scene.canvas
	var original: Array = scene.board.nodes["e:survey"].at.duplicate()
	var point: Vector2 = canvas.hit["e:survey"].position + Vector2(35, 55)
	_mouse(canvas, point, true)
	var motion = InputEventMouseMotion.new()
	motion.position = point + Vector2(55, 25)
	canvas._gui_input(motion)
	_mouse(canvas, motion.position, false)
	check(scene.board.nodes["e:survey"].at != original, "left-drag moves the actual evidence card")
	scene._open_answer("e:rumor")
	var slot = scene.find_child("Answer_rumor_0", true, false)
	slot.select(2)
	slot.item_selected.emit(2)
	check(scene.board.nodes["e:rumor"].answers.rumor.positive == ["nisha"], "answer-window signal updates the shared evidence answer")
	scene.answer_window.close_requested.emit()
	check("Marked: Nisha" in canvas.body("e:rumor"), "the closed card displays its answered result")
	await process_frame
	var link_point: Vector2 = canvas._link_rect(canvas.hit["e:rumor"]).get_center()
	_mouse(canvas, link_point, true)
	_mouse(canvas, link_point, false)
	var dest: Vector2 = canvas.hit["e:survey"].position + Vector2(20, 65)
	_mouse(canvas, dest, true)
	_mouse(canvas, dest, false)
	check(scene.board.links.any(func(e): return e.from == "e:rumor" and e.to == "e:survey") and canvas.drag == "", "Link then destination connects actual cards without starting a drag")
	scene.board.nodes["e:vigil1"].at = [100.0, 150.0]
	scene.board.nodes["e:alibi1"].at = [500.0, 150.0]
	canvas.queue_redraw()
	await process_frame
	await process_frame
	link_point = canvas._link_rect(canvas.hit["e:vigil1"]).get_center()
	_mouse(canvas, link_point, true)
	_mouse(canvas, link_point, false)
	dest = canvas.hit["e:alibi1"].position + Vector2(20, 65)
	_mouse(canvas, dest, true)
	_mouse(canvas, dest, false)
	check(scene.board.nodes[scene.board.selected].kind == "contradiction", "linking the actual vigil and alibi cards automatically merges the contradiction")
	scene._context(scene.board.selected)
	scene.context_menu.id_pressed.emit(2)
	scene.context_menu.hide()
	check(not scene.board.nodes["e:alibi1"].has("merged"), "right-click Unlink restores the original evidence cards")
	scene.find_child("LoadMockup", true, false).pressed.emit()
	check(scene.board.nodes.values().any(func(n): return n.kind == "contradiction"), "Load mockup assembles the requested merged-contradiction case")
	var preview_before = JSON.stringify([scene.session.history, scene.session.listeners, scene.board.export_data()])
	await scene._preview_effectiveness()
	check(scene.preview_window.visible and "Neutral reference" in scene.preview_output.text, "manual canvas preview opens a separate neutral response window")
	check(preview_before == JSON.stringify([scene.session.history, scene.session.listeners, scene.board.export_data()]), "preview leaves the case and remembered jury discussion untouched")
	scene.preview_window.hide()
	scene._present()
	check(scene.jury_window.visible and scene.session.last_results.size() == 4 and scene.session.last_results.all(func(r): return r.assessment.movement_ok), "Present evaluates the connected case and opens the separate jury window")
	scene.jury_window.hide()
	scene.remember.button_pressed = true
	scene._present()
	check(scene.session.last_results.all(func(r): return r.repeated and is_zero_approx(r.suspicion_delta)), "canvas presentations retain no-repeat-farming behavior")
	scene.jury_window.hide()
	var path = "user://workshop-canvas-test.json"
	scene._save(path)
	var results = scene.session.last_results.duplicate(true)
	var exported = scene.board.export_data()
	scene.board.reset()
	scene._open(path)
	check(scene.board.export_data() == exported and scene.session.last_results == results, "Save/Open restores the canvas and replays the jury history exactly: " + scene.status.text)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame

func _mouse(canvas, at: Vector2, pressed: bool) -> void:
	var event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	canvas._gui_input(event)

func check(okay: bool, label: String) -> void:
	checks += 1
	if okay:
		print("PASS: " + label)
	else:
		fails += 1
		push_error("FAIL: " + label)
