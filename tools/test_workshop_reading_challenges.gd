extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Editor = preload("res://ui/live_case_workshop.gd")
var checks = 0
var fails = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _run() -> void:
	_alibis()
	_readings()
	_ownership()
	_restore()
	await _ui()
	print("Reading challenge checks: %d; failures: %d" % [checks, fails])
	quit(1 if fails else 0)

func _alibis() -> void:
	var g = Game.new()
	g.new_case(44814, 10)
	g.w.dlog.detailed = false
	var n = g.w.by_id.nisha
	n.history[g.w.time_key(1, 3)] = "night:docks"
	var vigil = g.add_card({"kind": "sighting", "source": "player", "subject": ["constance", "nisha"], "vigil": true,
		"day": 1, "phase": 3, "block": "square", "text": "Regression vigil: Constance and Nisha on the Square."})
	var home = g.add_card({"kind": "alibi", "source": "nisha", "subject": ["nisha"], "day": 1, "phase": 3,
		"block": "docks", "text": "Regression Nisha says she was home."})
	for reverse in [false, true]:
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion = {"target": "nisha", "type": "suspicious", "at": "Original alignment"}
		var v: String = "e:" + Live.Evidence.normalize_card(g.board[vigil - 1]).id
		var h: String = "e:" + Live.Evidence.normalize_card(g.board[home - 1]).id
		board.connect_cards(h, root)
		check(board.connect_cards(h if reverse else v, v if reverse else h) == "", "either direction connects")
		var merged: String = board.selected
		check(board.nodes[merged].kind == "contradiction", "second vigil subject merges with matching alibi")
		board.connect_cards(merged, root)
		var value = board.compile(root)
		check(value.cards.size() == 2 and value.disputes.size() == 1, "both receipts survive even when the alibi was already linked to the premise")
		check(Live.status(g, value).ready, "live alibi challenge has an evaluator")
		var preview = Ghost.live(Live.snapshot(g, value))
		check(preview.ready and preview.proposal.effects.nisha.requested > 0, "ghost sees circumstantial suspicion")
		var filed = Live.file(g, value)
		check(g.board[filed - 1].supports.size() == 2, "filing retains both original board cards")
		g.set_workshop_effects(true)
		var response = g._evaluate_deduction(n, g.board[filed - 1], 1.0)
		if not response.get("workshop", false):
			print("Alibi fallback: ", n.workshop_state.get("issues", []), " / ", response)
			var captured = g.workshop_snapshot([filed], n.id)
			print("Prepare: ", Live.Assess.prepare(captured).issues)
			print("Union: ", preload("res://workshop/shared_ledger.gd").prepare(g.workshop_snapshot([], n.id), {str(filed): captured}, n.ledger).issues)
		check(response.get("workshop", false), "live presentation uses shared evaluation")
		check(response.get("repeated", false) or str(response.get("lines", [])).contains("Fine, I was out"), "good NPC admits a known false home account or retains that response on repetition")
		var applied = n.workshop_state.requested.duplicate(true)
		g._evaluate_deduction(n, g.board[filed - 1], 1.0)
		check(n.workshop_state.requested == applied, "repeated alibi challenge does not stack")
		board.unmerge(merged)
		check(board.nodes.has(v) and board.nodes.has(h), "unmerge restores both originals")
	n.secret_mod = "sleepwalker"
	check(g.workshop_snapshot([], n.id).listener.own_outings.get("1") == false, "live adapter cannot give a Sleepwalker knowledge of an unremembered outing")

func _readings() -> void:
	var g = Game.new()
	g.new_case(44814, 10)
	g.w.dlog.detailed = false
	var count1 = g.add_card({"kind": "info", "role": "surveyor", "source": "greta", "subject": [],
		"day": 0, "phase": 3, "data": {"count": 1}, "text": "Regression Surveyor one block."})
	var count3 = g.add_card({"kind": "info", "role": "surveyor", "source": "greta", "subject": [],
		"day": 0, "phase": 3, "data": {"count": 3}, "text": "Regression Surveyor three blocks."})
	for number in [count1, count3]:
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion.target = "hollis"
		var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
		board.connect_cards("e:" + id, root)
		var original = Ghost.live(Live.snapshot(g, board.compile(root)))
		check(board.add_modifier("e:" + id, "unlikely") == "", "unlikely available on every Surveyor count")
		var modifier: String = board.selected
		var value = board.compile(root)
		check(value.cards == [id] and value.reading_challenges[id].mode == "unlikely", "attached modifier preserves a single original")
		var preview = Ghost.live(Live.snapshot(g, value))
		check(preview.ready, "live challenge preview supported")
		var finding: Dictionary = preview.proposal.reading_challenges[0]
		check(finding.supported == (number == count1), "rare and ordinary counts receive different challenge assessments")
		check(finding.multiplier < 1 if number == count1 else finding.multiplier == 1, "only grounded challenge discounts the report")
		if number == count1:
			check(finding.fraction > 0 and finding.fraction < 0.05, "rare result is possible, not proof of error")
		else:
			check(preview.proposal.effects == original.proposal.effects, "unsupported challenge adds no numeric effect")
		board.add_modifier("e:" + id, "misled")
		var unsupported = Ghost.live(Live.snapshot(g, board.compile(root)))
		check(unsupported.proposal.reading_challenges[0].multiplier == 1, "bare Misled modifier supplies no free discount")
		board.add_modifier("e:" + id, "lying")
		var lying = Ghost.live(Live.snapshot(g, board.compile(root)))
		check(lying.proposal.reading_challenges[0].agreement == 0, "bare allegation cannot discredit a source")
		board.remove_modifier(modifier)
		check(board.compile(root).reading_challenges.is_empty(), "removing modifier restores direct report support")
	var ordinary = 0
	var extremes = 0
	var valid_draws = true
	for _i in range(1000):
		var result: int = g.w.surveyor_result(3)
		valid_draws = valid_draws and result != 3 and result in [1, 2, 4]
		if result == 2:
			ordinary += 1
		else:
			extremes += 1
	check(ordinary > 750 and extremes > 0, "impaired Surveyor strongly favors ordinary counts but retains rare tails")
	check(valid_draws, "all impaired draws exclude the true result")

func _ui() -> void:
	var g = Game.new()
	g.new_case(44814, 10)
	g.w.dlog.detailed = false
	var number = g.add_card({"kind": "info", "role": "surveyor", "source": "greta", "day": 0, "phase": 3,
		"subject": [], "data": {"count": 3}, "text": "UI ordinary Surveyor regression."})
	var editor = Editor.new()
	editor.g = g
	root.add_child(editor)
	await process_frame

	var premise: String = editor.board.selected
	editor.add_evidence(number)
	var evidence: String = editor.board.selected
	editor._context(evidence)
	check(not editor.context_menu.is_item_disabled(editor.context_menu.get_item_index(202)), "ordinary Surveyor offers Unlikely without a menu spoiler")
	editor.context_menu.hide()
	editor._context_action(200)
	var modifier: String = editor.board.selected
	check(editor.board.nodes[modifier].kind == "modifier" and editor.board.nodes[modifier].mode == "misled", "actual context action attaches Misled card")
	editor.board.connect_cards(modifier, premise)
	editor._open_answer(modifier)
	var selectors: Array = editor.case_box.find_children("*", "OptionButton", true, false)
	check(selectors.size() == 1, "modifier inspection offers one explanation selector")
	selectors[0].item_selected.emit(1)
	check(editor.board.nodes[modifier].mode == "lying", "actual answer signal changes the proposed cause")
	editor.answer_window.hide()
	editor.board.selected = premise
	var filed: int = editor._file()
	check(filed > 0 and g.board[filed - 1].workshop_case.reading_challenges.size() == 1, "UI filing retains modifier semantics")
	check(editor.status.text.contains(str(number)), "filing feedback lists included originals")
	editor.refresh()
	check(editor.board.nodes.has(modifier), "live refresh retains attached modifier")
	editor._context(modifier)
	editor.context_menu.hide()
	editor._context_action(203)
	check(not editor.board.nodes.has(modifier) and editor.board.compile(premise).cards.size() == 1, "context removal keeps the underlying evidence linked")
	editor.queue_free()
	await process_frame

func _ownership() -> void:
	var g = Game.new()
	g.new_case(44814, 10)
	g.w.dlog.detailed = false
	var n = g.w.by_id.nisha
	n.info_log = []
	n.known_claims = {}
	n.ledger = {}
	n.role = "warden"
	n.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	n.trust = 0.8
	n.npc_trust.greta = 0.9
	var number = g.add_card({"kind": "info", "role": "surveyor", "source": "greta", "day": 0, "phase": 3,
		"subject": [], "data": {"count": 1}, "text": "Owned Surveyor one regression."})
	var board = Canvas.new(Live.view(g))
	var root_id: String = board.selected
	board.nodes[root_id].conclusion.target = "hollis"
	var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	board.connect_cards("e:" + id, root_id)
	var filed = Live.file(g, board.compile(root_id))
	g.set_workshop_effects(true)
	g._evaluate_deduction(n, g.board[filed - 1], 1.0)
	var initial: Dictionary = n.workshop_state.requested.duplicate(true)
	board.add_modifier("e:" + id, "unlikely")
	var modifier: String = board.selected
	filed = Live.file(g, board.compile(root_id), filed)
	check(n.workshop_state.requested == initial, "editing and filing alone do not change live challenge effects")
	var response = g._evaluate_deduction(n, g.board[filed - 1], 1.0)
	check(response.get("workshop", false) and not response.get("reading_challenges", response.get("assessment", {}).get("reading_challenges", [])).is_empty(), "challenge reaches actual shared response")
	var challenged: Dictionary = n.workshop_state.requested.duplicate(true)
	check(challenged.get("hollis", 0.0) < initial.get("hollis", 0.0), "accepted skepticism reduces the actual owned report effect")
	g._evaluate_deduction(n, g.board[filed - 1], 1.0)
	check(n.workshop_state.requested == challenged, "repeated challenge cannot stack discount")
	board.remove_modifier(modifier)
	filed = Live.file(g, board.compile(root_id), filed)
	g._evaluate_deduction(n, g.board[filed - 1], 1.0)
	check(n.workshop_state.requested == initial, "heard revision retracts exclusive challenge and restores original report weight")
	g.workshop_retract(filed, n.id)
	check(n.workshop_state.get("requested", {}).values().all(func(v): return is_zero_approx(v)), "withdrawal removes case-only report and challenge effects")

func _restore() -> void:
	var session = preload("res://workshop/session.gd").new()
	var board = Canvas.new(session.scenario.public_view)
	var main: String = board.selected
	var reading: Dictionary = session.scenario.public_view.cards.filter(func(c): return c.kind == "report" and c.role == "surveyor")[0]
	board.connect_cards("e:" + reading.id, main)
	board.add_modifier("e:" + reading.id, "misled")
	var value = board.compile(main)
	var copy = Canvas.new(session.scenario.public_view)
	var error: String = copy.restore(JSON.parse_string(JSON.stringify(board.export_data())), session)
	check(error == "" and copy.compile(main) == value, "modifier graph and original provenance survive JSON restoration")
	var listener = session.listeners[0].duplicate(true)
	var result = preload("res://workshop/jury.gd").evaluate(session.scenario.public_view, value, listener)
	var changed: Dictionary = value.duplicate(true)
	changed.reading_challenges[reading.id].mode = "lying"
	var second = preload("res://workshop/jury.gd").evaluate(session.scenario.public_view, changed, listener)
	check(not result.repeated and not second.repeated, "changing the proposed cause invalidates remembered assessment")
