extends SceneTree
const Activity = preload("res://workshop/live_activity.gd")
const Solver = preload("res://workshop/solver.gd")
const Ghost = preload("res://workshop/ghost_juror.gd")
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	for home in Activity.C.BLOCKS:
		for destination in Activity.C.BLOCKS:
			var sum = 0.0
			for route in Activity.demon_routes(home, destination):
				sum += route.weight
				check(route.path[0] == home and route.path.back() == destination and route.weight > 0, "a detour preserves its actual endpoints")
			check(is_equal_approx(sum, 1.0), "detours redistribute rather than add path probability")
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": "hill" if id == "a" else "square"})
	var view = {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true, "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]},
		"timeline": {"events": [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1, "phase": "night"}}]}}
	var off: String = Activity.C.BLOCKS.keys().filter(func(block): return block not in Activity.C.route("hill", "square"))[0]
	var elsewhere = {"id": "elsewhere", "kind": "sighting", "source": "player", "subject": "a", "subjects": ["a"], "night": 1, "block": off, "data": {}, "observed_at": {"day": 1, "phase": "night"}}
	var at_scene: Dictionary = elsewhere.duplicate(true)
	at_scene.id = "scene"
	at_scene.block = "square"
	var off_like: float = Activity._likelihood(view, [elsewhere], people[0], "demon")
	var scene_like: float = Activity._likelihood(view, [at_scene], people[0], "demon")
	check(off_like > 0 and off_like < scene_like * 0.1, "off-route sighting is strong finite evidence against the killer")
	var claim = {"id": "claim", "kind": "claim", "source": "a", "subject": "a", "role": "warden", "data": {}, "observed_at": {"day": 1, "phase": "morning"}}
	var cards: Array = [elsewhere, at_scene, claim]
	view.cards = cards
	var notes: Array = Activity.relationships(view, cards)
	check(notes.any(func(note): return note.begins_with("Seen elsewhere:")) and notes.any(func(note): return note.begins_with("Scattered sightings:")), "movement exposes both relationships without another evidence factor")
	var value = Solver.empty_case()
	value.cards = cards.map(func(card): return card.id)
	value.conclusion = {"type": "suspicious", "target": "a", "at": view.alignment_epoch}
	var preview = Ghost.evaluate(view, value)
	check(preview.ready and preview.proposal.response.contains("Seen elsewhere:") and preview.proposal.response.contains("Scattered sightings:"), "neutral preview and listener response use those same relationship notes")
	_parked()
	print("Sighting mechanics: %d checks; failures: %d" % [checks, fails])
	quit(1 if fails else 0)

func _parked() -> void:
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	g.w.day = 2
	var goods: Array = g.w.living_good()
	var observer = goods[0]
	var source = goods[1]
	var target = goods[2]
	observer.info_log = []
	observer.known_claims = {}
	observer.beliefs = []
	observer.ledger = {}
	var reading = {"role": "nightwatch", "day": 1, "phase": 3, "data": {"block": "square", "seen": [target.id]}, "text": "Night Watch crossing", "shared": false}
	Mind.apply_info(g.w, observer, source, reading, 1.0)
	var eid: String = Mind.info_eid(source.id, reading)
	check(observer.workshop_state.owned.has(eid) and observer.ledger[eid].applied.values().all(func(x): return is_zero_approx(x)), "legacy night-sighting scale is parked with its shared reading owner")
	var before: Dictionary = observer.workshop_state.requested.duplicate(true)
	var old: Array = observer.ledger[eid].effects.duplicate(true)
	for effect in observer.ledger[eid].effects:
		effect[1] *= 20
	Mind.recompute_beliefs(g.w, observer, " (parked scale probe)")
	check(observer.workshop_state.requested == before and observer.ledger[eid].applied.values().all(func(x): return is_zero_approx(x)), "changing parked native sighting coefficients cannot change shared beliefs")
	observer.ledger[eid].effects = old
	g.set_workshop_effects(false)
	check(observer.ledger[eid].applied.values().any(func(x): return not is_zero_approx(x)), "native comparison mode restores the compatibility sighting effect")
