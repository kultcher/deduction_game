extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Support = preload("res://workshop/support_model.gd")
const Solver = preload("res://workshop/solver.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_run()
	print("Medium relay: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", label)

func _run() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var medium = g.w.npcs[0]
	var dead = g.w.npcs[1]
	var pair: Array = g.w.npcs.filter(func(n): return n != medium and n != dead).slice(0, 2).map(func(n): return n.id)
	g.add_card({"kind": "death", "source": "player", "subject": [dead.id], "night": 1, "text": "Public death"})
	var entry = {"role": "seer", "day": 0, "data": {"pair": pair, "yes": true}, "text": "Original Seer reading", "why": "HIDDEN CAUSE", "true": false, "fake": true}
	var number = g.add_card({"kind": "info", "source": medium.id, "subject": [], "role": "medium", "day": 2, "phase": 3,
		"data": {"dead": dead.id, "item": {"type": "reading", "entry": entry, "lie": true}}, "text": "Medium repeats dead Seer"})
	var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	var view = Live.view(g)
	var card = Solver.card_by_id(view, id)
	check(card.role == "seer" and card.source == dead.id and card.relay_source == medium.id, "relay retains original evaluator and both speakers")
	check(card.observed_at.day == 0 and card.relay_observed_at.day == 2, "original reading and Medium acquisition keep distinct times")
	var serialized = JSON.stringify(Live.Evidence.normalize_card(g.board[number - 1]))
	check(not serialized.contains("HIDDEN CAUSE") and not serialized.contains('"fake"') and not serialized.contains('"lie"'), "nested referee cause fields do not cross the evidence boundary")
	var board = Canvas.new(view)
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "evil", "target": pair[0], "at": "Original alignment"}
	board.connect_cards("e:" + id, root)
	var value = board.compile(root)
	check(Live.status(g, value).ready, "supported Medium reading uses live evaluator")
	var prepared = Live.Assess.prepare(_ghost_input(g, value))
	check(prepared.ready, "Medium source knowledge is complete for neutral assessment")
	var listener = Ghost.profile(prepared.view.people)
	var attention = preload("res://workshop/reasoner.gd").prepare(prepared.view, prepared.case, listener)
	var mixture = Support._mixture(prepared.view, attention.case, listener, attention, false, {})
	check(mixture.atoms.any(func(a): return a.key == "source:" + medium.id) and mixture.atoms.any(func(a): return a.key == "source:" + dead.id), "credibility distinguishes Medium transmission from original speaker")
	var preview = Ghost.live(Live.snapshot(g, value))
	check(preview.ready, "Medium gets neutral preview")
	var full = Support.assess(prepared.view, prepared.case, listener)
	listener.npc_trust[medium.id] = 0.0
	var distrusted = Support.assess(prepared.view, prepared.case, listener)
	check(distrusted.report_acceptance[id] < full.report_acceptance[id], "distrusting Medium lowers relay acceptance")
	listener.npc_trust[medium.id] = 0.5
	listener.npc_trust[dead.id] = 0.0
	distrusted = Support.assess(prepared.view, prepared.case, listener)
	check(distrusted.report_acceptance[id] < full.report_acceptance[id], "distrusting original source also lowers relay acceptance")
	var original = Live.Evidence.normalize_card({"kind": "info", "source": dead.id, "subject": [], "role": "seer", "day": 0, "phase": 3, "data": entry.data, "text": entry.text})
	var direct = card.duplicate(true)
	for key in ["relay_source", "relay_observed_at", "relay_role", "logical_origin", "accuracy_origin"]:
		direct.erase(key)
	direct.id = original.id
	direct.fact_id = original.id
	check(Support._contributing(prepared.view, [card, direct]).size() == 1, "relay and direct copy count as one original reading")
	var direct_number = g.add_card({"kind": "info", "source": dead.id, "subject": [], "role": "seer", "day": 0, "phase": 3, "data": entry.data, "text": entry.text})
	var combined = Canvas.new(Live.view(g))
	combined.nodes[combined.selected].conclusion = value.conclusion.duplicate(true)
	combined.connect_cards("e:" + id, combined.selected)
	combined.connect_cards("e:" + Live.Evidence.normalize_card(g.board[direct_number - 1]).id, combined.selected)
	var combined_input = _ghost_input(g, combined.compile(combined.selected))
	var combined_prepared = Live.Assess.prepare(combined_input)
	check(combined_prepared.ready, "direct reading and Medium copy can share a live case")
	var combined_cards: Array = combined_prepared.view.cards
	check(combined_cards.size() == 2 and combined_cards[0].accuracy_origin == combined_cards[1].accuracy_origin and combined_cards[0].accuracy_origin.begins_with("health:"), "original health is shared separately from receipt route weights")
	var comparison_listener = Ghost.profile(combined_prepared.view.people)
	comparison_listener.knowledge.good = [medium.id]
	var both = Support.assess(combined_prepared.view, combined_prepared.case, comparison_listener)
	var direct_only = combined_prepared.case.duplicate(true)
	direct_only.cards = [original.id]
	direct_only.lines = []
	var just_original = Support.assess(combined_prepared.view, direct_only, comparison_listener)
	check(is_equal_approx(both.agreement, just_original.agreement), "a faithful relay does not corroborate an already-present identical original")
	var wrapped = combined_cards.filter(func(c): return c.has("relay_source"))[0]
	var index: int = combined_prepared.view.people.map(func(p): return p.id).find(medium.id)
	var possible = Solver.solve(combined_prepared.view, [], {medium.id: "good", dead.id: "good"}).worlds
	var evil_free: Dictionary = possible[0].duplicate(true)
	evil_free.modifier = "delusional"
	evil_free.marked = -1
	evil_free.holders = 1 << index
	check(not Solver.Roles.fits(combined_prepared.view, evil_free, [wrapped], {}), "Delusional Medium cannot supply a healthy transmission")
	evil_free.holders = 1 << combined_prepared.view.people.map(func(p): return p.id).find(pair[0])
	Solver.Roles.reuse = false
	var uncached = Solver.Roles.fits(combined_prepared.view, evil_free, [wrapped], {})
	Solver.Roles.reuse = true
	check(Solver.Roles.fits(combined_prepared.view, evil_free, [wrapped], {}) == uncached, "relay health cache distinguishes Delusional holder assignments")
	var filed = Live.file(g, value)
	check(filed > 0, "Medium filing preserves original outer receipt")
	var npc = g.w.living_good().filter(func(n): return n != medium and n != dead)[0]
	npc.info_log = []
	npc.known_claims = {}
	npc.ledger = {}
	npc.beliefs = []
	npc.role = "warden"
	npc.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	g.set_workshop_effects(true)
	var response = g._evaluate_deduction(npc, g.board[filed - 1], 1.0)
	check(response.get("workshop", false), "Medium presentation reaches shared owner")
	var before: Dictionary = npc.workshop_state.get("requested", {}).duplicate(true)
	response = g._evaluate_deduction(npc, g.board[filed - 1], 1.0)
	check(response.get("repeated", false) and npc.workshop_state.get("requested", {}) == before, "Medium repeat does not stack")
	g.set_workshop_effects(false)
	check(board.add_modifier("e:" + id, "lying") != "", "ambiguous relay blame cannot silently accuse the wrong speaker")
	var alive_input = _ghost_input(g, value)
	alive_input.public_events = []
	check(not Live.Assess.prepare(alive_input).ready, "Medium needs public death timing rather than hidden death flags")
	var nested = g.board[number - 1].duplicate(true)
	nested.data.item.entry.role = "medium"
	var nested_receipt = Live.Evidence.normalize_card(nested)
	check(Live.Assess.medium_card(nested_receipt, _ghost_input(g, value)).is_empty(), "nested Medium chains explicitly remain unsupported")
	var second = g.board[number - 1].duplicate(true)
	second.data = {"dead": dead.id, "item": {"type": "sighting", "who": pair[0], "block": "square", "night": 1}}
	var sight = Live.Assess.medium_card(Live.Evidence.normalize_card(second), _ghost_input(g, value))
	check(not sight.is_empty() and sight.kind == "sighting" and sight.night == 1, "Medium sighting inherits the original night and movement logic")
	var opinion = Live.Evidence.normalize_card({"kind": "info", "source": npc.id, "subject": [], "role": "medium", "day": 2, "phase": 3, "data": {"dead": dead.id, "item": {"type": "suspicion", "about": pair[0]}}, "text": "Unsupported private opinion"})
	check(not preload("res://workshop/shared_ledger.gd").supported(opinion), "Medium opinions remain outside alignment evidence")
	var independent = _ghost_input(g, value)
	independent.evidence.append(opinion)
	independent.private_evidence.append(opinion.id)
	check(Live.Assess.prepare(independent).ready, "independent unsupported private Medium knowledge does not block a supported case")

func _ghost_input(g, value: Dictionary) -> Dictionary:
	var input = Live.snapshot(g, value)
	var ghost = Ghost.profile(input.people)
	input.listener = {"id": ghost.id, "name": ghost.name, "trust": 0.5, "confidence": 0.5, "insight": 0.5, "npc_trust": ghost.npc_trust, "suspicion": ghost.suspicion, "discounted": {}, "own_gift": ""}
	return input
