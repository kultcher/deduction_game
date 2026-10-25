extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Editor = preload("res://ui/live_case_workshop.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Mind = preload("res://sim/mind.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
var checks = 0
var fails = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var listener = g.w.living_good()[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.ledger = {}
	listener.role = "warden"
	var source = g.w.npcs.filter(func(n): return n != listener)[0]
	var candidates = g.w.npcs.filter(func(n): return n != listener and n != source)
	var target = candidates[0]
	var a = candidates[1]
	var b = candidates[2]
	var read = g.add_card({"kind": "info", "source": source.id, "subject": [target.id, a.id, b.id], "role": "dowser",
		"day": 1, "phase": 0, "data": {"group": [target.id, a.id, b.id], "count": 3}, "text": "Dowser read: three registrations."})
	var trace = g.add_card({"kind": "trace", "source": "player", "subject": [target.id], "day": 1, "phase": 0, "block": "market", "text": "Market soot from the scene."})
	var rng: int = g.w.rng.state
	var view = Live.view(g)
	check(g.w.rng.state == rng, "building the live library does not advance the world RNG")
	check(view.cards.size() == g.board.filter(func(c): return c.kind != "deduction" and not c.get("deleted", false)).size(), "all real board evidence, including unsupported cards, appears in the live library")
	check(not JSON.stringify(view).contains("true_role") and not view.has("truth"), "the live canvas contains player receipts rather than hidden roles")
	var board = Canvas.new(view)
	var root_id: String = board.selected
	board.nodes[root_id].conclusion.target = target.id
	var report_id: String = Live.Evidence.normalize_card(g.board[read - 1]).id
	var trace_id: String = Live.Evidence.normalize_card(g.board[trace - 1]).id
	board.connect_cards("e:" + report_id, root_id)
	var child: String = board.add_premise(a.id, "evil", Vector2(300, 300))
	board.connect_cards("e:" + report_id, child)
	board.connect_cards(child, root_id)
	board.nodes["e:" + report_id].answers[report_id] = {"positive": [target.id, a.id], "slots": [target.id, a.id, ""]}
	board.nodes[child].positions[b.id] = "marked"
	var value = board.compile(root_id)
	check(Live.status(g, value).ready, "reading case with answers, local assumptions and intermediate claims is supported")
	_flags(g, value)
	var number = Live.file(g, value)
	check(number > 0 and g.board[number - 1].workshop_case == value, "filing retains the full compiled graph")
	var second_case: Dictionary = value.duplicate(true)
	second_case.argument_root = "another draft"
	var other = Live.file(g, second_case)
	check(other != number and g.board[number - 1].workshop_case == value, "separate drafts with identical headlines and evidence do not overwrite each other")
	var input = g.workshop_snapshot([number], listener.id)
	var prepared = Assess.prepare(input)
	check(prepared.ready and prepared.case.answers == value.answers, "live transport preserves reading answers")
	check(prepared.case.arguments == value.arguments and prepared.case.lines == value.lines, "live transport preserves scoped claims, assumptions and paths")
	check(g.w.rng.state == rng, "filing and support inspection do not use world randomness")
	g.set_workshop_effects(true)
	var before = listener.suspicion.duplicate(true)
	var result = g._evaluate_deduction(listener, g.board[number - 1], 1.0)
	check(result.get("workshop", false), "filed live canvas uses the new assessment path")
	check(listener.workshop_state.facts.size() == 1, "two lines citing one reading share one original fact")
	check(g.workshop_deliveries[-1].model == "shared", "actual shared delivery is explicitly recorded")
	var requested = listener.workshop_state.requested.duplicate(true)
	result = g._evaluate_deduction(listener, g.board[number - 1], 1.0)
	check(result.repeated and listener.workshop_state.requested == requested, "unchanged canvas repeat does not stack suspicion")
	board.nodes[root_id].positions[target.id] = "good"
	board.version += 1
	var changed = board.compile(root_id)
	var revised = Live.file(g, changed, number)
	check(revised > number and g.board[number - 1].superseded_by == revised and listener.workshop_state.requested == requested, "a revision gets a new number, marks its predecessor and leaves listener beliefs untouched")
	var previous = number
	number = revised
	result = g._evaluate_deduction(listener, g.board[number - 1], 1.0)
	check(result.get("workshop", false) and not result.repeated, "changed hypotheses produce a fresh assessment rather than an unchanged reply")
	check(listener.workshop_state.presentations[str(number)].arguments[0].workshop_case.positions == changed.positions, "the listener's endorsement is replaced by the heard revision")
	check(not listener.workshop_state.presentations.has(str(previous)), "hearing a revision retires the previous endorsement")
	board.connect_cards("e:" + trace_id, root_id)
	var mixed = board.compile(root_id)
	var status = Live.status(g, mixed)
	check(not status.ready and not status.blocked and status.issues.any(func(s): return "trace" in s), "mixed trace/reading chain remains usable and clearly requires fallback")
	check("NOT interpreted" in status.warning, "fallback warning names the lost canvas interpretation")
	number = Live.file(g, mixed, number)
	result = g._evaluate_deduction(listener, g.board[number - 1], 1.0)
	# No legacy route for presentations (Oct 25): an unsupported graph is blocked, not judged natively.
	check(result.get("blocked", false) and not result.get("workshop", false), "unsupported revised graph is blocked with its reason, not judged by native rules")
	check(not listener.workshop_state.get("presentations", {}).has(str(number)), "a blocked revision leaves no shared endorsement behind")
	g.workshop_retract(number, listener.id)
	check(listener.ledger.get("arg:workshop:%d" % number, {}).get("weight", 0.0) == 0.0, "developer withdrawal leaves no canvas contribution")
	board.unlink("e:" + trace_id, root_id)
	board.nodes[root_id].positions.clear()
	number = Live.file(g, board.compile(root_id), number)
	result = g._evaluate_deduction(listener, g.board[number - 1], 1.0)
	check(result.get("workshop", false), "removing unsupported evidence allows supported interpretation again")
	check(listener.workshop_state.facts.size() == 1, "fallback recovery retains a single original owner")
	g.workshop_retract(number, listener.id)
	check(listener.workshop_state.facts.is_empty(), "withdrawal removes the canvas endorsement when it has no independent owner")
	var missing = board.compile(root_id)
	g.board[read - 1].deleted = true
	check(Live.status(g, missing).blocked and Live.file(g, missing, number) < 0, "missing original evidence blocks filing instead of silently weakening the case")
	g.board[read - 1].deleted = false
	g.set_workshop_effects(false)
	g._start_meeting()
	g.workshop_deliveries.clear()
	g.command("present %d" % number)
	check(g.presented_today and g.workshop_deliveries.size() == g.w.living().size(), "ordinary typed meeting commands still complete synchronously without a progress callback")
	g.set_workshop_effects(true)
	await _ui(g, report_id, trace_id)
	await _flow()
	await _main_ui()
	print("Live canvas: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _flags(g, value: Dictionary) -> void:
	var future: Dictionary = value.duplicate(true)
	future["future_semantic_feature"] = true
	check(not Live.status(g, future).ready, "new unrecognized graph features cannot silently acquire supported status")
	for field in ["reasons", "citations", "disputes", "faults", "temporal_positions", "derived", "challenges"]:
		var changed: Dictionary = value.duplicate(true)
		changed[field] = ["unsupported choice"] if field in ["disputes", "temporal_positions", "derived"] else {"unsupported": true}
		var status = Live.status(g, changed)
		check(not status.ready and status.issues.any(func(issue): return field in issue), "unhandled %s explicitly flags the entire case" % field)
	var input = Live.snapshot(g, value)
	input.listener = {"id": "ghost", "name": "Ghost", "trust": 0.5, "confidence": 0.5, "insight": 0.5,
		"npc_trust": {}, "suspicion": {}, "discounted": {}, "own_gift": ""}
	input.public_events.append({"kind": "curse", "subjects": [], "at": {"day": 1, "phase": "evening"}})
	check(not Assess.prepare(input).ready, "public alignment-transition history explicitly requires fallback")
	input.public_events.clear()
	for receipt in input.evidence:
		if receipt.id in input.selected:
			receipt.observed_at = {"day": 1, "phase": "night"}
	check(Assess.prepare(input).issues.any(func(issue): return "gift interval" in issue), "out-of-scope reading time is reported rather than treated as a healthy reading")
	var board = Canvas.new(Live.view(g))
	var main: String = board.selected
	var conflict: String = board.add_premise(value.conclusion.target, "conflict", Vector2.ZERO)
	board.connect_cards("e:" + value.cards[0], conflict)
	board.connect_cards(conflict, main)
	var quoted = Live.snapshot(g, board.compile(main))
	check(Shared.endorsed_facts(quoted, quoted.root).is_empty(), "a conflict intermediate quotes reports without endorsing their contents")
	check(not Live.status(g, board.compile(main)).ready, "an embedded conflict is flagged until both quotation ownership and scoped assessment are supported")
	var group: String = board.add_premise(value.conclusion.target, "support", Vector2.ZERO)
	board.connect_cards(conflict, group)
	board.connect_cards(group, main)
	check(Live.status(g, board.compile(main)).issues.any(func(issue): return "quoted-evidence" in issue), "nested quotation through a grouping card is explicitly flagged instead of endorsing the quoted reports")

func _ui(g, report_id: String, trace_id: String) -> void:
	root.size = Vector2i(1400, 950)
	root.content_scale_size = Vector2i(1400, 950)
	var editor = Editor.new()
	editor.g = g
	root.add_child(editor)
	# A fresh Workshop starts blank; these checks argue the old preset premise.
	editor.set_premise_field(editor.case_root, "type", "evil")
	editor.set_premise_field(editor.case_root, "person", editor.board._default_target())
	await process_frame
	check(editor.canvas.size.x > 1000 and editor.canvas.size.y > 200, "live editor fills the available window and leaves room for its canvas")
	check(editor.board.view.live and not editor.board.nodes.values().any(func(n): return n.kind == "evidence"), "opening the live Workshop does not automatically transfer board evidence")
	var headline: String = editor.board.selected
	var report_number: int = g.board.filter(func(c): return c.kind != "deduction" and Live.Evidence.normalize_card(c).id == report_id)[0].n
	var trace_number: int = g.board.filter(func(c): return c.kind != "deduction" and Live.Evidence.normalize_card(c).id == trace_id)[0].n
	editor.add_evidence(report_number)
	check(editor.board.nodes.has("e:" + report_id) and not editor.board.nodes.has("e:" + trace_id), "explicit transfer adds only the selected original card")
	var count: int = editor.board.nodes.size()
	editor.add_evidence(report_number)
	check(editor.board.nodes.size() == count and editor.board.selected == "e:" + report_id, "transferring an existing card focuses its copy without duplication")
	editor.board.connect_cards("e:" + report_id, headline)
	editor.board.selected = headline
	editor._session_changed()
	check(editor.support_label.text.begins_with("Ready") or "listeners" in editor.support_label.text, "supported reading case has a visible evaluator label")
	editor._open_answer("e:" + report_id)
	check(editor.case_box.get_child_count() > 0, "reading answers open using live people and receipts")
	editor.answer_window.hide()
	editor.add_evidence(trace_number)
	check(editor.board.nodes.has("e:" + trace_id), "unsupported evidence can also be transferred explicitly")
	editor.board.connect_cards("e:" + trace_id, headline)
	editor.board.selected = headline
	editor._session_changed()
	check("can't be judged" in editor.support_label.text and "trace" in editor.support_label.tooltip_text, "mixed graph warning is visible without running a preview (reasons in the tooltip)")
	editor._open_answer("e:" + trace_id)
	check(editor.case_box.get_child_count() > 0, "unsupported card can be inspected without fixture logic")
	editor.answer_window.hide()
	editor._store()
	var saved = editor.board.export_data()
	var generated = g.add_card({"kind": "trace", "source": "player", "subject": [], "day": 2, "phase": 0, "block": "docks", "text": "New scene evidence, not selected for Workshop."})
	editor.refresh()
	check(editor.board.export_data() == saved and not editor.board.nodes.has("e:" + Live.Evidence.normalize_card(g.board[generated - 1]).id), "newly generated evidence and refresh leave transferred cards, layout, links and answers unchanged")
	var reopened = Editor.new()
	reopened.g = g
	root.add_child(reopened)
	await process_frame
	check(reopened.board.export_data() == saved, "reopening restores only the player's previously transferred evidence")
	reopened.queue_free()
	var screenshot_index = OS.get_cmdline_user_args().find("--screenshot")
	if screenshot_index >= 0 and DisplayServer.get_name() != "headless":
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[screenshot_index + 1])
	g.new_case(693, 10)
	editor.refresh()
	check(editor.files.is_empty() and editor.board.links.is_empty() and editor.board.view.people.size() == 10 and not editor.board.nodes.values().any(func(n): return n.kind == "evidence"), "new case clears the graph and starts without transferred evidence")
	check(g.workshop_effects and g.workshop_deliveries.is_empty(), "case reset retains shared evaluation and clears presentation feedback")
	editor.queue_free()
	await process_frame

func _flow() -> void:
	# These reports come from the native gift generator in a real ten-person
	# case, rather than the bounded 692 Workshop fixture or hand-picked readings.
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	g.w._day_gifts()
	var reports: Array = []
	for person in g.w.npcs:
		for reading in person.info_log:
			if reading.role in Assess.ROLES:
				reports.append(g.add_card({"kind": "info", "source": person.id, "subject": [], "role": reading.role,
					"day": reading.day, "phase": reading.get("phase", 3 if reading.day == 0 else 0),
					"data": reading.data, "text": "Native %s: %s" % [reading.role, reading.text]}))
	check(not reports.is_empty(), "native world supplies supported readings for the playable-flow smoke test")
	var board = Canvas.new(Live.view(g))
	var root_id: String = board.selected
	var target = g.w.living_good()[0]
	var listener = g.w.living_good().filter(func(n): return n != target)[0]
	board.nodes[root_id].conclusion.target = target.id
	for number in reports:
		board.connect_cards("e:" + Live.Evidence.normalize_card(g.board[number - 1]).id, root_id)
	var number = Live.file(g, board.compile(root_id))
	check(number > 0 and Live.status(g, board.compile(root_id)).ready, "native reports form a supported filed canvas case")
	g.set_workshop_effects(true)
	g.state = "talk"
	g.talk_with = listener
	g.questions_left = 3
	g.command("convince %d" % number)
	check(g.questions_left == 2 and not g.workshop_deliveries.is_empty(), "private canvas presentation uses the normal conversation question budget")
	check(g.workshop_deliveries[-1].model == "shared", "native-generated private case reaches the shared evaluator")
	g.command("bye")
	g.w.phase = 2
	g._start_meeting()
	g.workshop_deliveries.clear()
	var started = Time.get_ticks_msec()
	var progress_count: Array = [0]
	await g.workshop_command("present %d" % number, func(_name):
		progress_count[0] += 1
		check(g.workshop_presenting and "still being assessed" in g.command("wait"), "town progress yields with ordinary actions locked")
		await process_frame)
	print("Live ten-person town presentation: %d ms; %d listener records" % [Time.get_ticks_msec() - started, g.workshop_deliveries.size()])
	check(g.presented_today and g.workshop_deliveries.size() == g.w.living().size(), "meeting canvas case reaches every living listener using the ordinary floor action")
	check(progress_count[0] == g.w.living().size() and not g.workshop_presenting, "town presentation yields before each listener and releases the action lock")
	check(g.workshop_deliveries.all(func(d): return d.model == "shared" or not d.issues.is_empty()), "every town listener has either a shared evaluation or explicit fallback feedback")
	var delivery_count: int = g.workshop_deliveries.size()
	g.command("present %d" % number)
	check(g.workshop_deliveries.size() == delivery_count, "canvas presentation cannot bypass the once-per-meeting floor limit")
	g.command("nominate " + target.id)
	check(g.state == "nomination", "ordinary nomination follows the case presentation")
	g.workshop_deliveries.clear()
	await g.workshop_command("accuse %d" % number, func(_name): await process_frame)
	check(g.statement_used and g.workshop_deliveries.size() == g.w.living().size() - 1, "nomination statement evaluates the graph for eligible listeners")
	g.command("accuse %d" % number)
	check(g.workshop_deliveries.size() == g.w.living().size() - 1, "canvas cannot bypass the one-statement nomination limit")
	g.command("vote no")
	if g.state == "meeting":
		g._close_meeting()
	if g.state == "night":
		g.command("sleep")
	check(g.w.day >= 2 or g.w.game_over, "normal execution and night resolution finish after the canvas presentations")
	g.new_case(692, 10)
	check(g.workshop_draft.is_empty() and g.workshop_deliveries.is_empty() and g.workshop_effects, "restarting the same seed clears canvas ownership and feedback while retaining shared evaluation")

func _main_ui() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.show_script_at_start = false
	root.add_child(main)
	await process_frame
	await process_frame
	main.roles_win.hide()
	main._on_more(4)
	await process_frame
	var editor = main.case_view.workshop.editor
	# A fresh Workshop starts blank; these checks argue the old preset premise.
	editor.set_premise_field(editor.case_root, "type", "evil")
	editor.set_premise_field(editor.case_root, "person", editor.board._default_target())
	check(editor.g == main.g and editor.board.view.get("live", false), "main menu opens the live editor rather than the fixture canvas")
	check(main.get_window().gui_embed_subwindows, "Workshop dialogs are embedded in the game window")
	check([editor.answer_window, editor.preview_window, editor.progress_window, editor.context_menu].all(func(window): return window.transient and not window.transient_to_focused and window.is_embedded()), "live answer, results, progress and context windows are embedded transient dialogs")
	check(not main.g.prediction_spoiled and main.g.workshop_effects, "opening the live editor preserves shared evaluation without enabling debug spoilers")
	var number: int = main.g.board[0].n
	main.case_view.show_card_menu(number, Vector2i(200, 200))
	main.case_view.card_menu.id_pressed.emit(main.case_view.CardAction.WORKSHOP)
	check(editor.board.selected == "e:" + Live.Evidence.normalize_card(main.g.board[number - 1]).id, "case-board context action focuses the same original evidence in the live editor")
	editor._open_answer(editor.board.selected)
	await process_frame
	main.get_window().grab_focus()
	await process_frame
	check(editor.answer_window.visible, "answer panel stays open when the game window regains focus")
	editor.answer_window.close_requested.emit()
	editor.board.connect_cards(editor.board.selected, editor.case_root)
	editor.board.selected = editor.case_root
	main.g.state = "talk"
	main.g.talk_with = main.g.w.living_good()[0]
	main.g.questions_left = 3
	editor._session_changed()
	var filed_number: int = editor._file()
	editor._withdraw_window()
	var withdrawal: Window = editor.get_children().filter(func(child): return child is Window and child.title.begins_with("Developer withdrawal"))[0]
	check(withdrawal.visible and withdrawal.transient and withdrawal.is_embedded(), "dynamically created withdrawal panel is also an embedded dialog")
	withdrawal.close_requested.emit()
	await editor._send("convince %d" % filed_number)
	check("New shared evaluator" in editor.result_output.text and main.g.questions_left == 2, "live screen submits a home-context case through the main callback and displays shared delivery")
	check(not editor.progress_window.visible and not editor.presenting, "presentation progress closes and releases the editor after delivery")
	editor.preview_window.hide()
	main.seed_box.value = 693
	main._new_case()
	check(editor.g == main.g and editor.board.links.is_empty() and main.case_view.workshop.is_collapsed(), "new case rebinds and resets the live editor and collapses the sheet")
	main.queue_free()
	await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("FAIL: " + label)
