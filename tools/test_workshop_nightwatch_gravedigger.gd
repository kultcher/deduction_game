extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const History = preload("res://workshop/live_history.gd")
const Assess = preload("res://workshop/live_assessment.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_semantics()
	_live()
	print("Night Watch / Gravedigger: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", label)

func report(id: String, source: String, role: String, data: Dictionary, night: int = 1) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": role, "data": data, "night": night, "observed_at": {"day": night, "phase": "night"}}

func _semantics() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var view = {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}
	var world = {"evil": 96, "demon": 5, "marked": 4, "modifier": "marked", "holders": 16}
	var knowledge = {"self": "a", "good": ["a"], "own_role": "warden"}
	var grave = report("grave", "b", "gravedigger", {"executed": "g", "role": "poisoner"})
	check(Solver.Roles.fits(view, world, [grave], knowledge), "named minion role fits actual minion")
	grave.data.executed = "f"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "Demon cannot fill named minion role")
	grave.data.role = "demon"
	check(Solver.Roles.fits(view, world, [grave], knowledge), "Demon role report fixes Demon identity")
	grave.data.executed = "e"
	check(Solver.Roles.fits(view, world, [grave], knowledge), "Marked may register as Demon without being evil")
	grave.data.executed = "d"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "ordinary good cannot register as Demon")
	grave.data.role = "warden"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "executed good-role read conflicts with firsthand unique role")
	grave.data.executed = "a"
	check(Solver.Roles.fits(view, world, [grave], knowledge), "good-role read corroborates firsthand holder")
	grave.data.role = "seer"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "good role report must fit original role identity")
	grave.data.executed = "g"
	check(not Solver.Roles.fits(view, world, [grave], knowledge), "evil target cannot fill good gift")
	grave.data.executed = "e"
	grave.data.role = "poisoner"
	var other: Dictionary = world.duplicate(true)
	other.marked = 3
	other.holders = 8
	check(not Solver.Roles.fits(view, other, [grave], knowledge), "role cache distinguishes different Marked holders")
	var timeline = History.from_events([
		{"kind": "execution", "subjects": ["f"], "at": {"day": 1}},
		{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}},
		{"kind": "martyr", "subjects": ["b", "c"], "by": "b", "at": {"day": 2}}])
	view.timeline = timeline
	check(not History.alive_at_night(view, "f", 1), "execution precedes same-night movement")
	check(History.alive_at_night(view, "g", 1) and not History.alive_at_night(view, "g", 2), "Demon victim participates in death-night readings")
	check(not History.alive_at_night(view, "b", 2) and History.alive_at_night(view, "c", 2), "Martyr substitution kills only the Martyr")
	check(History.executed(view, "f", 1) and not History.executed(view, "g", 1), "execution bookkeeping does not confuse night deaths")
	check(History.observer_alive(view, "f", {"day": 1, "phase": "morning"}) and not History.observer_alive(view, "f", {"day": 1, "phase": "night"}), "execution-day daytime reading precedes death while night reading does not")
	var watch = report("watch", "c", "nightwatch", {"block": "square", "seen": ["d", "e"]})
	var home = {"id": "home", "kind": "alibi", "source": "d", "subject": "d", "night": 1, "observed_at": {"day": 1, "phase": "night"}}
	check(not Solver.solve(view, [watch, home], {}, {}, knowledge).movement_ok, "Watch list challenges each named person's home alibi")
	check(Solver.solve(view, [watch], {}, {}, knowledge).movement["1"].forced_out.has("c"), "watcher is also out on duty")
	check(Assess.Domain.gift_time(watch), "Night Watch night interval is supported")
	watch.observed_at.phase = "morning"
	check(not Assess.Domain.gift_time(watch), "daytime Watch payload cannot masquerade as night evidence")

func _live() -> void:
	for role in ["nightwatch", "gravedigger"]:
		var g = Game.new()
		g.new_case(692, 7)
		g.w.dlog.detailed = false
		var source = g.w.npcs[0]
		var target = g.w.npcs[1]
		g.add_card({"kind": "execution", "source": "player", "subject": [target.id], "day": 1, "phase": 2, "text": "Public execution fixture"})
		var data: Dictionary = {"block": "square", "seen": [target.id]} if role == "nightwatch" else {"executed": target.id, "role": "poisoner"}
		var night: int = 0 if role == "nightwatch" else 1
		var number = g.add_card({"kind": "info", "source": source.id, "role": role, "day": night, "phase": 3, "data": data, "text": "New supported report " + role})
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion.target = target.id
		var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
		board.connect_cards("e:" + id, root)
		var value = board.compile(root)
		check(Live.status(g, value).ready, role + " live case is supported")
		check(not Solver.card_by_id(board.view, id).support_note.begins_with("FALLBACK"), role + " live card label announces support")
		var preview = Ghost.live(Live.snapshot(g, value))
		check(preview.ready and preview.proposal.assessment.compatible > 0, role + " ghost preview finds legal explanations")
		var filed = Live.file(g, value)
		check(filed > 0 and g.board[filed - 1].supports == [number], role + " filing preserves exact original")
		var listener = g.w.living_good().filter(func(n): return n != source and n != target)[0]
		listener.info_log = []
		listener.known_claims = {}
		listener.ledger = {}
		listener.role = "warden"
		listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		g.set_workshop_effects(true)
		var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("workshop", false), role + " actual NPC delivery uses shared evaluator")
		var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
		response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, role + " repeat does not stack effects")
		check(board.add_modifier("e:" + id, "misled") == "", role + " supports Misled attachment")
		check(Live.status(g, board.compile(root)).ready, role + " attached modifier preserves live capability")
		g.set_workshop_effects(false)
		if role == "gravedigger":
			g.board[0]["deleted"] = true
			# Public process receipts remain the only authority; no hidden execution query.
			g.board = g.board.filter(func(c): return c.kind != "execution")
			for i in range(g.board.size()):
				g.board[i].n = i + 1
			check(not Live.status(g, value).ready, "missing execution history is explicit fallback")
