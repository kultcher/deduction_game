extends SceneTree
const Activity = preload("res://workshop/live_activity.gd")
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
	print("Lamplighter: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", label)

func _constraints() -> void:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "square"})
	var view = {"people": people, "cards": [], "day": 2, "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": [], "deaths": {}}, "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}
	var lamp = {"id": "lamp", "kind": "report", "source": "a", "role": "lamplighter", "night": 1, "data": {"count": 3}, "observed_at": {"day": 1, "phase": "night"}}
	var sight = {"id": "sight", "kind": "sighting", "source": "player", "subjects": ["b", "c"], "subject": "b", "night": 1, "block": "square"}
	var cards: Array = [lamp, sight]
	for id in ["d", "e", "f"]:
		cards.append({"id": "home" + id, "kind": "alibi", "source": "player", "subject": id, "night": 1})
	var result = Activity.routes(view, cards)
	check(result.okay and "g" in result.nights["1"].forced_out, "count plus sightings and home alibis identifies final outing")
	check("a" in result.nights["1"].forced_out, "Lamplighter's own tour is separate from the count")
	check(Activity.routes(view, [lamp]).okay, "unanswered count requires no minimum number of named people")
	var extra = sight.duplicate(true)
	extra.id = "extra"
	extra.subjects = ["d", "e"]
	check(not Activity.routes(view, [lamp, sight, extra]).okay, "four established other outings conflict with count three")
	check(Activity.routes(view, [lamp], {"lamp": {"positive": ["b"]}}).okay, "partial player answer leaves unresolved slots")
	view.cards = [lamp]
	var value = Solver.empty_case()
	value.cards = ["lamp"]
	value.answers.lamp = {"positive": ["a"]}
	check(not Solver.validate_answers(view, value).is_empty(), "answer cannot count Lamplighter as an other person")
	view.timeline.deaths = {"g": 1}
	check(not Activity.routes(view, cards).okay, "already-dead resident cannot fill a later night's remaining slot")
	view.timeline.deaths.g = 2
	check(Activity.routes(view, cards).okay, "person dying that night still counts as an outing")
	view.timeline.deaths = {}
	var factors = Activity.factors(view, cards, {})
	check(factors[0].profiles[6].good < 1.0, "forced outing enters joint activity likelihood")
	lamp.data.count = 0
	check(Activity.routes(view, [lamp]).okay, "zero other outings still permits Lamplighter tour")
	check(not Activity.routes(view, [lamp, sight]).okay, "positive sighting contradicts zero-other count")

func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var source = g.w.npcs[0]
	var number = g.add_card({"kind": "info", "source": source.id, "subject": [], "role": "lamplighter", "day": 1, "phase": 3, "data": {"count": 3}, "text": "Three others out on N1"})
	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "suspicious", "target": g.w.npcs[1].id, "at": "Original alignment"}
	var id: String = Live.Evidence.normalize_card(g.board[number - 1]).id
	board.connect_cards("e:" + id, root)
	var value = board.compile(root)
	check(Live.status(g, value).ready, "Lamplighter live card is supported")
	check(Ghost.live(Live.snapshot(g, value)).ready, "Lamplighter neutral preview succeeds")
	var filed = Live.file(g, value)
	check(filed > 0, "Lamplighter filing succeeds: " + g.last_error)
	if filed < 1:
		return
	var listener = g.w.living_good().filter(func(n): return n != source)[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.ledger = {}
	listener.role = "seer"
	listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	g.set_workshop_effects(true)
	var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("workshop", false), "Lamplighter reaches real shared delivery")
	var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
	response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, "Lamplighter presentation is repeat stable")
	check(board.add_modifier("e:" + id, "misled") == "", "Lamplighter permits supported reading challenges")
	check(Live.status(g, board.compile(root)).ready, "Lamplighter modifier stays in live evaluator")
	g.set_workshop_effects(false)
