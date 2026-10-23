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
	_routes()
	_patterns()
	_live()
	print("Live activity: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", label)

func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "hill" if id == "a" else "square"})
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": {"events": [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}, {"kind": "demon_death", "subjects": ["f"], "at": {"day": 2}}]},
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}

func _sight(id: String, person: String, night: int, block: String, kind: String = "sighting") -> Dictionary:
	return {"id": id, "fact_id": id, "kind": kind, "source": "player", "subject": person, "subjects": [person], "night": night, "block": block, "data": {}, "role": "", "observed_at": {"day": night, "phase": "evening" if kind == "evening" else "night"}}

func _trace(night: int) -> Dictionary:
	return {"id": "trace%d" % night, "kind": "trace", "source": "evidence", "night": night, "subject": "", "data": {"material": "market", "scene_block": "square", "scene": "scene%d" % night}, "observed_at": {"day": night, "phase": "evening"}}

func _routes() -> void:
	var view = _view()
	var first = _sight("vigil", "a", 1, "market")
	var second = _sight("hearsay", "a", 1, "docks")
	var watch = {"id": "watch", "kind": "report", "source": "b", "role": "nightwatch", "night": 1, "data": {"block": "market", "seen": []}, "observed_at": {"day": 1, "phase": "night"}}
	check(not Activity.routes(view, [first, watch]).okay, "complete Watch list conflicts with omitted passer on watched block")
	first.block = "docks"
	check(Activity.routes(view, [first, watch]).okay, "Watch omission does not put everyone at home")
	first.block = "market"
	var routes = Activity.routes(view, [first, second])
	check(routes.okay and routes.forced_lamp == ["a"], "two nonhome blocks require lamp tour under direct roads")
	var claim = {"id": "claim", "kind": "claim", "source": "a", "subject": "a", "role": "medium", "data": {}}
	check(not Activity.routes(view, [first, second, claim]).okay, "different accepted gift cannot excuse a lamp-only route")
	check(Activity.routes(view, [first, _sight("homeblock", "a", 1, "hill")]).okay, "home block and one destination are compatible")
	var empty = {"id": "empty", "kind": "coverage", "source": "player", "night": 1, "block": "market", "excluded": []}
	check(not Activity.routes(view, [empty, first]).okay, "empty complete vigil contradicts a positive crossing")
	empty.excluded = ["a"]
	check(Activity.routes(view, [empty, first]).okay, "coverage exclusions are honored")
	var knowledge = {"self": "a", "good": ["a"], "own_role": "warden", "own_outings": {"1": false}}
	check(not Activity.routes(view, [first], {}, knowledge).okay, "firsthand home memory constrains routes")
	var world = {"evil": 3, "demon": 1, "marked": 2, "modifier": "marked", "holders": 4}
	check(not Solver.Roles.fits(view, world, [first, second], {}), "lamp-only route cannot silently be assigned to an evil candidate")
	world.evil = 96
	world.demon = 5
	check(Solver.Roles.fits(view, world, [first, second], {}), "lamp-only route admits an appropriate good identity")

func _patterns() -> void:
	var view = _view()
	var sight = _sight("sight", "a", 1, "square")
	var evening = _sight("evening", "a", 1, "market", "evening")
	var cards: Array = [sight, evening, _trace(1)]
	var factors = Activity.factors(view, cards, {})
	check(factors.size() == 1 and factors[0].joint_live, "all suspects share a single joint movement/trace factor")
	var world = {"evil": 3, "demon": 0}
	var original = Activity.score(world, factors[0])
	var duplicate = sight.duplicate(true)
	duplicate.id = "different description"
	var repeated = Activity.score(world, Activity.factors(view, cards + [duplicate], {})[0])
	check(is_equal_approx(original, repeated), "two sightings of one crossing do not multiply an outing")
	var duplicate_trace: Dictionary = cards[2].duplicate(true)
	duplicate_trace.id = "copied soot"
	check(is_equal_approx(original, Activity.score(world, Activity.factors(view, cards + [duplicate_trace], {})[0])), "duplicate physical scene sample does not multiply trace")
	var second: Array = cards + [_sight("sight2", "a", 2, "square"), _sight("evening2", "a", 2, "market", "evening"), _trace(2)]
	check(Activity.score(world, Activity.factors(view, second, {})[0]) > original, "matching a second night's movements and trace adds support")
	var alternative = evening.duplicate(true)
	alternative.block = "docks"
	check(Activity.score(world, Activity.factors(view, [sight, alternative, cards[2]], {})[0]) < original, "incompatible evening material weakens the suspected killer explanation")
	var claim = {"id": "claim", "kind": "claim", "source": "a", "subject": "a", "role": "medium", "data": {}}
	check(Activity.score(world, Activity.factors(view, cards + [claim], {})[0]) < original, "legitimate walking gift makes an outing less incriminating")
	var bare = Activity.factors(view, [_trace(1), _trace(2)], {})[0]
	check(is_equal_approx(bare.profiles[0].demon, bare.profiles[1].demon), "repeated material without candidate evening evidence does not identify a suspect")
	view.cards = cards
	var value = Solver.empty_case()
	value.cards = cards.map(func(c): return c.id)
	value.conclusion = {"type": "suspicious", "target": "a", "at": "Original alignment"}
	var ghost = Ghost.evaluate(view, value)
	check(ghost.ready and ghost.proposal.effects.a.requested > 0, "joint trace/movement comparison reaches suspicion effects")
	var clone = view.duplicate(true)
	clone.timeline = {"events": []}
	check(Activity.factors(view, cards, {}) != Activity.factors(clone, cards, {}), "activity cache includes public event changes")

func _live() -> void:
	var g = Game.new()
	g.new_case(692, 7)
	g.w.dlog.detailed = false
	var target = g.w.npcs[0]
	var victim = g.w.npcs[1]
	g.add_card({"kind": "death", "source": "player", "subject": [victim.id], "night": 1, "text": "Public victim"})
	var number = g.add_card({"kind": "trace", "source": "evidence", "subject": [], "day": 1, "phase": 2,
		"material": "market", "block": "market", "scene": "scene_" + victim.id, "scene_block": victim.home_block, "victim": victim.id, "crime_night": 1, "text": "Structured scene trace"})
	var evening = g.add_card({"kind": "sighting", "source": "player", "subject": [target.id], "day": 1, "phase": 2, "block": "market", "text": "Evening observation"})
	var board = Canvas.new(Live.view(g))
	var root: String = board.selected
	board.nodes[root].conclusion = {"type": "suspicious", "target": target.id, "at": "Original alignment"}
	for n in [number, evening]:
		var id: String = Live.Evidence.normalize_card(g.board[n - 1]).id
		board.connect_cards("e:" + id, root)
	var value = board.compile(root)
	check(Live.status(g, value).ready, "live structured trace and evening evidence are supported")
	var preview = Ghost.live(Live.snapshot(g, value))
	check(preview.ready, "live trace receives neutral numeric preview")
	var filed = Live.file(g, value)
	check(filed > 0 and g.board[filed - 1].supports.size() == 2, "trace filing keeps both exact originals")
	var listener = g.w.living_good().filter(func(n): return n != target and n != victim)[0]
	listener.info_log = []
	listener.known_claims = {}
	listener.ledger = {}
	listener.role = "warden"
	listener.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
	g.set_workshop_effects(true)
	var response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("workshop", false), "trace presentation uses actual shared owner")
	var before: Dictionary = listener.workshop_state.get("requested", {}).duplicate(true)
	response = g._evaluate_deduction(listener, g.board[filed - 1], 1.0)
	check(response.get("repeated", false) and listener.workshop_state.get("requested", {}) == before, "repeated trace presentation does not stack")
	g.set_workshop_effects(false)
	var legacy = g.add_card({"kind": "trace", "source": "evidence", "subject": [], "day": 1, "phase": 2, "block": "market", "text": "Old trace without scene metadata"})
	var legacy_id: String = Live.Evidence.normalize_card(g.board[legacy - 1]).id
	var old_view = Live.view(g)
	check(Solver.card_by_id(old_view, legacy_id).support_note.begins_with("FALLBACK"), "old unstructured trace clearly flags fallback")
