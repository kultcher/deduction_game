extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const Assess = preload("res://workshop/live_assessment.gd")
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

func report(id: String, source: String, role: String, data: Dictionary, night: int = 0) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": role, "data": data,
		"night": night, "observed_at": {"day": night, "phase": "night"}}

func _run() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id.to_upper(), "home": "square"})
	var view = {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment",
		"world_options": {"modifiers": ["marked", "delusional", "lovers", "sleepwalker"], "roles": true, "identities": true}}
	var world = {"evil": 96, "demon": 5, "marked": 4, "modifier": "marked", "holders": 16}
	var knowledge = {"self": "a", "good": ["a"], "own_role": "seer"}
	var clerk = report("clerk", "b", "clerk", {"pair": ["c", "d"], "role": "warden"})
	var matching = {"id": "claim", "kind": "claim", "source": "c", "role": "warden", "data": {}}
	check(Solver.Roles.fits(view, world, [clerk, matching], knowledge), "Clerk and matching claim admit a unique good-role completion")
	var outsider: Dictionary = matching.duplicate(true)
	outsider.source = "e"
	check(not Solver.Roles.fits(view, world, [clerk, outsider], knowledge), "outside unique-role claim conflicts with Clerk pair")
	var evil_claim: Dictionary = matching.duplicate(true)
	evil_claim.source = "g"
	check(not Solver.Roles.fits(view, world, [evil_claim], knowledge), "granting a good-role claim excludes an evil claimant")
	check(not Solver.Roles.fits(view, world, [clerk], knowledge, {"clerk": {"positive": ["f"]}}), "Clerk answer cannot designate someone outside its pair")
	var archivist = report("arch", "c", "archivist", {"pair": ["f", "d"], "role": "poisoner"})
	check(not Solver.Roles.fits(view, world, [archivist], knowledge), "Demon alone cannot satisfy a named-minion ping")
	archivist.data.pair = ["g", "d"]
	check(Solver.Roles.fits(view, world, [archivist], knowledge), "named minion plus good candidate fits Archivist")
	archivist.data.pair = ["d", "e"]
	check(not Solver.Roles.fits(view, world, [archivist], knowledge), "two good candidates cannot satisfy Archivist")
	var no = report("no", "a", "seer", {"pair": ["g", "b"], "yes": false})
	check(Solver.Roles.fits(view, world, [no], knowledge), "healthy Seer negative permits a minion")
	no.data.pair = ["f", "b"]
	check(not Solver.Roles.fits(view, world, [no], knowledge), "healthy negative excludes the Demon")
	var first = report("first", "a", "seer", {"pair": ["b", "c"], "yes": true})
	var second = report("second", "a", "seer", {"pair": ["d", "e"], "yes": true}, 1)
	var no_mark: Dictionary = world.duplicate(true)
	no_mark.marked = 0
	no_mark.holders = 1
	check(not Solver.Roles.fits(view, no_mark, [first, second], knowledge), "disjoint positives cannot use two different Red Herrings")
	check(Solver.Roles.fits(view, world, [first, second], knowledge), "one Red Herring and a different Marked ping explain disjoint positives")
	var negative = report("negative", "a", "seer", {"pair": ["b", "c"], "yes": false}, 1)
	check(not Solver.Roles.fits(view, no_mark, [first, negative], knowledge), "persistent Red Herring cannot switch off between readings")
	var marked: Dictionary = world.duplicate(true)
	marked.marked = 1
	marked.holders = 2
	check(Solver.Roles.fits(view, marked, [first, negative], knowledge), "Marked can explain same-pair no/yes without impairment")
	check(Solver.Roles.fits(view, marked, [first], knowledge, {"first": {"positive": ["b"], "registration": "red_herring"}}), "Red Herring may also be Marked")
	check(not Solver.Roles.fits(view, marked, [first, negative], knowledge, {"first": {"positive": ["b"], "registration": "red_herring"}}), "explicit Red Herring answer must fit later negatives")
	check(Assess.Domain.gift_time(first), "Night-zero Seer reading is supported")
	view.cards = [clerk]
	var solved = Solver.solve(view, [clerk], {"c": "evil"}, {}, knowledge)
	check(not solved.worlds.is_empty(), "Clerk survives another candidate being evil")
	check(solved.worlds.all(func(w): return not (w.evil & 8)), "Clerk plus candidate elimination forces remaining holder good")
	check(not Solver.position_holds(view, world, "g", "demon") and Solver.position_holds(view, world, "g", "minion"), "Demon/minion premise predicates distinguish identities")
	_challenges(view, knowledge, first, negative)
	var cached = Solver.solve(view, [clerk], {"c": "evil"}, {}, knowledge)
	Solver.Roles.reuse = false
	var uncached = Solver.solve(view, [clerk], {"c": "evil"}, {}, knowledge)
	Solver.Roles.reuse = true
	check(cached == uncached, "role completion caching preserves exact solver results")
	_live()
	_claim_routes()
	await _ui()
	print("Clerk/Archivist/Seer checks: %d; failures: %d" % [checks, fails])
	quit(1 if fails else 0)

func _challenges(view: Dictionary, knowledge: Dictionary, positive: Dictionary, negative: Dictionary) -> void:
	view.cards = [positive, negative]
	var listener = Ghost.profile(view.people)
	listener.knowledge = knowledge.duplicate(true)
	listener.npc_trust.a = 1.0
	var value = Solver.empty_case()
	value.conclusion.at = view.alignment_epoch
	value.cards = [positive.id, negative.id]
	value.reading_challenges = {positive.id: {"mode": "misled", "supports": [negative.id]}}
	var result = preload("res://workshop/reading_challenges.gd").assess(view, value, listener, [positive, negative])
	check(result.results[0].supported and result.results[0].multiplier == 1.0, "healthy Marked/Red Herring misdirection is recognized without discounting its registration")
	check(result.results[0].note.contains("without a broken gift"), "Misled feedback distinguishes registration from impairment")
	value.reading_challenges = {negative.id: {"mode": "misled", "supports": [positive.id]}}
	result = preload("res://workshop/reading_challenges.gd").assess(view, value, listener, [positive, negative])
	check(not result.results[0].supported and result.results[0].multiplier == 1.0, "same-pair flip supplies no automatic poisoning discount")
	var claimant = report("rival", "b", "seer", {"pair": ["c", "d"], "yes": false})
	view.cards = [claimant]
	value.cards = [claimant.id]
	value.reading_challenges = {claimant.id: {"mode": "lying", "supports": []}}
	result = preload("res://workshop/reading_challenges.gd").assess(view, value, listener, [claimant])
	check(result.results[0].agreement == 1.0 and result.sources.has("b"), "firsthand unique-role contradiction can support dishonesty")
	value.reading_challenges[claimant.id].mode = "misled"
	var analysis = Solver.analyze(view, value, knowledge)
	check(analysis.proposed == 0, "Misled cannot excuse a duplicate unique role known firsthand")

func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var source = g.w.npcs[0]
	var targets: Array = g.w.npcs.filter(func(n): return n != source)
	var pair: Array = [targets[0].id, targets[1].id]
	for role in ["clerk", "archivist", "seer"]:
		var data: Dictionary = {"pair": pair, "role": "warden" if role == "clerk" else "poisoner"}
		if role == "seer":
			data = {"pair": pair, "yes": false}
		var number = g.add_card({"kind": "info", "role": role, "source": source.id, "subject": pair,
			"day": 0, "phase": 3, "data": data, "text": "Regression new role: " + role})
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion.target = pair[0]
		var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
		board.connect_cards("e:" + id, root)
		var value = board.compile(root)
		check(Live.status(g, value).ready, role + " has complete live capability")
		var preview = Ghost.live(Live.snapshot(g, value))
		check(preview.ready and preview.proposal.assessment.compatible > 0, role + " neutral preview evaluates legal explanations")
		var filed = Live.file(g, value)
		check(filed > 0 and g.board[filed - 1].supports == [number], role + " filing preserves exact source receipt")
		var listener = g.w.living_good().filter(func(n): return n != source and n.id not in pair)[0]
		listener.info_log = []
		listener.known_claims = {}
		listener.ledger = {}
		listener.role = "warden"
		listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		g.set_workshop_effects(true)
		var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("workshop", false), role + " reaches actual shared NPC presentation")
		var vector: Dictionary = listener.workshop_state.requested.duplicate(true)
		response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.repeated and listener.workshop_state.requested == vector, role + " presentation is repeat-stable")
		for type in ["demon", "minion"]:
			board.nodes[root].conclusion.type = type
			var identities = Ghost.live(Live.snapshot(g, board.compile(root)))
			check(identities.ready, role + " supports explicit " + type + " questions")
			check(Live.file(g, board.compile(root)) > 0, type + " premise files through the native board")
		g.set_workshop_effects(false)

func _ui() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	var source = g.w.npcs[0]
	var pair: Array = g.w.npcs.filter(func(n): return n != source).slice(0, 2).map(func(n): return n.id)
	var number = g.add_card({"kind": "info", "role": "seer", "source": source.id, "subject": pair,
		"day": 0, "phase": 3, "data": {"pair": pair, "yes": true}, "text": "UI Seer registration regression."})
	var editor = Editor.new()
	editor.g = g
	root.add_child(editor)
	await process_frame

	editor.add_evidence(number)
	var evidence: String = editor.board.selected
	editor._open_answer(evidence)
	var selectors: Array = editor.case_box.find_children("*", "OptionButton", true, false)
	check(selectors.size() == 2, "live Seer answer offers person and registration-cause choices")
	selectors[0].item_selected.emit(1)
	selectors = editor.case_box.find_children("*", "OptionButton", true, false)
	selectors[1].item_selected.emit(2)
	var id: String = editor.board.nodes[evidence].card
	check(editor.board.nodes[evidence].answers[id].positive == [editor._report(id).data.pair[0]] and editor.board.nodes[evidence].answers[id].registration == "red_herring", "actual Seer UI retains chosen person and cause together")
	selectors = editor.case_box.find_children("*", "OptionButton", true, false)
	selectors[0].item_selected.emit(2)
	check(editor.board.nodes[evidence].answers[id].registration == "red_herring", "changing the selected person preserves the registration explanation")
	editor.answer_window.hide()
	check(str(editor.canvas.body(evidence)).contains("Red Herring"), "closed Seer card displays its registration explanation")
	editor._context(evidence)
	check(editor.context_menu.is_item_disabled(editor.context_menu.get_item_index(202)), "Unlikely stays visible but disabled for unsupported reading types")
	editor.context_menu.hide()
	editor.queue_free()
	await process_frame

func _claim_routes() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	var source = g.w.npcs[0]
	var pair: Array = g.w.npcs.filter(func(n): return n != source).slice(0, 2).map(func(n): return n.id)
	var reading = g.add_card({"kind": "info", "role": "clerk", "source": source.id, "subject": pair,
		"day": 0, "phase": 3, "data": {"pair": pair, "role": "warden"}, "text": "Claim-route Clerk regression."})
	var claim = g.add_card({"kind": "claim", "role": "warden", "source": pair[0], "subject": [pair[0]],
		"day": 1, "phase": 0, "text": "Claim-route Warden regression."})
	var board = Canvas.new(Live.view(g))
	var root_id: String = board.selected
	board.nodes[root_id].conclusion.target = pair[0]
	var reading_id: String = Live.Evidence.normalize_card(g.board[reading - 1]).id
	var claim_id: String = Live.Evidence.normalize_card(g.board[claim - 1]).id
	board.connect_cards("e:" + reading_id, root_id)
	var before = Ghost.live(Live.snapshot(g, board.compile(root_id)))
	board.connect_cards("e:" + claim_id, root_id)
	var after = Ghost.live(Live.snapshot(g, board.compile(root_id)))
	check(after.ready and after.proposal.effects[pair[0]].requested < before.proposal.effects[pair[0]].requested, "matching role claim adds conditional exoneration to Clerk evidence")
	var n = g.w.living_good().filter(func(p): return p != source and p.id not in pair)[0]
	n.info_log = []
	n.known_claims = {}
	n.ledger = {}
	n.role = "veteran"
	n.credibility = 0.0  # how far the player's word counts (credibility since Oct 30)
	var filed = Live.file(g, board.compile(root_id))
	var snapshot = g.workshop_snapshot([filed], n.id)
	snapshot.listener.discounted[pair[0] + ":*"] = 1.0
	var assessed = Assess.prepare(snapshot)
	check(assessed.ready and assessed.listener.reading_reliability[claim_id] == 1.0, "gift impairment cannot discount a role claim")
	var plan = preload("res://workshop/shared_ledger.gd").prepare(g.workshop_snapshot([], n.id), {str(filed): snapshot}, n.ledger)
	check(plan.ready and plan.prepared.listener.reading_reliability[claim_id] == 0.5, "player-only role-claim relay retains the player trust factor without a health assumption")
