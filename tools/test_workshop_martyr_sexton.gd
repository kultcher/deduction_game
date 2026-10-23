extends SceneTree
const Solver = preload("res://workshop/solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")
var checks = 0
var fails = 0

func _init() -> void:
	_constraints()
	_live()
	print("Martyr / Sexton: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", label)

func _report(id: String, source: String, role: String, data: Dictionary, night: int) -> Dictionary:
	return {"id": id, "kind": "report", "source": source, "role": role, "night": night, "data": data, "observed_at": {"day": night, "phase": "night"}}

func _constraints() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var view = {"people": people, "cards": [], "day": 3, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": [], "deaths": {}}, "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}
	var world = {"evil": 96, "demon": 5, "marked": 4, "modifier": "marked", "holders": 16}
	var chosen = _report("chosen", "a", "martyr", {"target": "f", "chosen": true}, 1)
	check(Solver.Roles.fits(view, world, [chosen], {}), "a Martyr's choice does not establish that chosen person is good")
	var other = chosen.duplicate(true)
	other.data.target = "d"
	check(not Solver.Roles.fits(view, world, [chosen, other], {}), "one Martyr cannot truthfully claim two choices")
	var outcome = _report("outcome", "a", "martyr", {"target": "e", "evil": true}, 2)
	check(not Solver.Roles.fits(view, world, [outcome], {}), "Martyr outcome needs a matching public execution")
	view.timeline["executions"] = {"2": ["e"]}
	check(Solver.Roles.fits(view, world, [outcome], {}), "healthy Martyr's evil-registration outcome permits Marked")
	outcome.data.target = "d"
	view.timeline.executions["2"] = ["d"]
	check(not Solver.Roles.fits(view, world, [outcome], {}), "ordinary good cannot explain healthy evil-registration outcome")
	outcome.data.target = "g"
	view.timeline.executions["2"] = ["g"]
	check(Solver.Roles.fits(view, world, [outcome], {}), "evil chosen target explains failure to substitute")
	var substitution = {"id": "public", "kind": "event", "event": "martyr", "source": "player", "data": {"martyr": "a", "saved": "b"}}
	check(Solver.Roles.fits(view, world, [substitution], {}), "public substitution assigns unique good Martyr and good saved participant")
	substitution.data.saved = "g"
	check(not Solver.Roles.fits(view, world, [substitution], {}), "public substitution cannot save an evil participant")
	substitution.data.saved = "b"
	var claim = {"id": "claim", "kind": "claim", "source": "c", "subject": "c", "role": "martyr"}
	check(not Solver.Roles.fits(view, world, [substitution, claim], {}), "public Martyr identity challenges another person's role claim")
	var sexton = _report("toll", "a", "sexton", {"night": 2}, 2)
	check(not Solver.Roles.fits(view, world, [sexton], {}), "healthy Sexton cannot activate with seven living")
	view.timeline.deaths = {"d": 1, "e": 1, "g": 2}
	check(Solver.Roles.fits(view, world, [sexton], {}), "four publicly living residents permit Sexton activation")
	var watch = _report("watch", "b", "nightwatch", {"block": "square", "seen": []}, 2)
	check(not Solver.Roles.fits(view, world, [sexton, watch], {}), "healthy knell conflicts with a working walking gift")
	var lamp = _report("lamp", "b", "lamplighter", {"count": 1}, 2)
	check(not Solver.Roles.fits(view, world, [sexton, lamp], {}), "healthy knell conflicts with lamp count even if count is small")
	var sight = {"id": "out", "kind": "sighting", "source": "player", "subject": "c", "subjects": ["c"], "night": 2, "block": "market"}
	check(Solver.Roles.fits(view, world, [sexton, sight], {}), "secret outings remain possible during a working knell")
	var seer = _report("seer", "b", "seer", {"pair": ["c", "f"], "yes": true}, 2)
	check(Solver.Roles.fits(view, world, [sexton, seer], {}), "knell permits nonwalking gifts")
	var twice = _report("twice", "a", "sexton", {"night": 3}, 3)
	check(not Solver.Roles.fits(view, world, [sexton, twice], {}), "Sexton activation is once per case")
	view.timeline.events = [{"kind": "demon_death", "subjects": ["c"], "at": {"day": 2}}]
	check(not Solver.Roles.fits(view, world, [sexton], {}), "healthy knell conflicts with a Demon kill that night")

func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	g.w.day = 4
	var source = g.w.npcs[0]
	var target = g.w.npcs[4]
	for i in range(1, 4):
		g.add_card({"kind": "execution", "source": "player", "subject": [g.w.npcs[i].id], "day": i, "phase": 2, "text": "Public execution %d" % i})
	for role in ["martyr", "sexton"]:
		var data: Dictionary = {"target": target.id, "chosen": true} if role == "martyr" else {"night": 3}
		var number = g.add_card({"kind": "info", "source": source.id, "subject": [], "role": role, "day": 3 if role == "sexton" else 1, "phase": 3, "data": data, "text": role + " use claim"})
		var board = Canvas.new(Live.view(g))
		var root: String = board.selected
		board.nodes[root].conclusion = {"type": "suspicious", "target": target.id, "at": "Original alignment"}
		var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
		board.connect_cards("e:" + id, root)
		var value = board.compile(root)
		check(Live.status(g, value).ready, role + " actual use report has live support")
		check(Ghost.live(Live.snapshot(g, value)).ready, role + " actual use report previews")
		var filed = Live.file(g, value)
		check(filed > 0, role + " use claim files")
		var listener = g.w.living_good().filter(func(n): return n != source)[0]
		listener.info_log = []
		listener.known_claims = {}
		listener.beliefs = []
		listener.ledger = {}
		listener.role = "warden"
		listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
		g.set_workshop_effects(true)
		var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("workshop", false), role + " actual presentation uses shared owner")
		var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
		response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
		check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, role + " presentation repeat is stable")
		g.set_workshop_effects(false)
		check(board.add_modifier("e:" + id, "misled") == "", role + " supports reading modifier")
		check(Live.status(g, board.compile(root)).ready, role + " modifier retains capability")
		if role == "martyr":
			var execution = g.add_card({"kind": "execution", "source": "player", "subject": [target.id], "day": 2, "phase": 2, "text": "Target executed after promise"})
			var changed_view = Live.view(g)
			board = Canvas.new(changed_view)
			root = board.selected
			board.nodes[root].conclusion.target = target.id
			board.connect_cards("e:" + id, root)
			board.connect_cards("e:" + Live.Evidence.normalize_card(g.board[execution - 1]).id, root)
			var status = Live.status(g, board.compile(root))
			check(not status.ready and status.issues.any(func(issue): return "dated outcome" in issue), "prior promise versus later execution explicitly flags missing temporal-health inference")
