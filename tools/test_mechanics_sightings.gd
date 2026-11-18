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
	_talk_sightings()
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
	check(observer.workshop_state.owned.has(eid) and observer.ledger[eid].effects.is_empty(), "night-sighting reading stores receipt-only empty effects under its shared owner")
	var before: Dictionary = observer.workshop_state.requested.duplicate(true)
	Mind.refresh_beliefs(g.w, observer, " (receipt-only sighting probe)")
	check(observer.workshop_state.requested == before and observer.ledger[eid].effects.is_empty(), "recomputing sighting beliefs is stable with empty ledger effects")

## Seeing two people talk gives three cards: each one's own sighting, and the talk
## (playtest triage 1.7). Visiting the spot later adds nothing new.
func _talk_sightings() -> void:
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	# Two people out at the same place (so neither already has a sighting elsewhere this
	# phase; the fixture once moved one, which broke whenever play changed).
	var out: Array = g.w.living().filter(func(n): return not n.at_home())
	var pair: Array = []
	for x in out:
		for y in out:
			if pair.is_empty() and x != y and x.loc == y.loc:
				pair = [x, y]
	check(pair.size() == 2, "(fixture) two people out at the same place")
	if pair.size() < 2:
		return
	var a = pair[0]
	var b = pair[1]
	for n in g.w.living():
		n.busy_with = ""
	a.busy_with = b.id
	b.busy_with = a.id
	var before: int = g.board.size()
	g._card_conversations()
	var sighted = func(n): return g.board.any(func(c): return c.kind == "sighting" and c.subject == [n.id] and c.loc == a.loc and int(c.day) == g.w.day and int(c.phase) == g.w.phase)
	check(sighted.call(a) and sighted.call(b), "each talker has their own sighting card (a working one counts)")
	check(g.board.slice(before).any(func(c): return c.kind == "conversation" and a.id in c.subject and b.id in c.subject), "the talk itself is a card")
	var after: int = g.board.size()
	g._card_conversations()
	check(not g.board.slice(after).any(func(c): return c.kind == "sighting"), "seeing the same talk again adds no new sightings")
	# Visiting the spot in the same phase: the visit's sighting of each talker is the same
	# fact (source, person, day, phase, block), so it merges into the talk's sighting card
	# (Seneschal, Nov 18: BACKLOG "Conversation sightings should also cover location sightings").
	g.loc = a.loc
	var at_visit: int = g.board.size()
	g._observe()
	var dup = func(n): return g.board.slice(at_visit).any(func(c): return c.kind == "sighting" and c.subject == [n.id] and int(c.phase) == g.w.phase)
	check(not dup.call(a) and not dup.call(b), "visiting the spot in the same phase adds no second sighting of either talker")
	_visit_then_talk()


## The other order: the visit first, then seeing them talk in the same phase.
func _visit_then_talk() -> void:
	var g = Game.new()
	g.new_case(692, 10)
	g.w.dlog.detailed = false
	var out: Array = g.w.living().filter(func(n): return not n.at_home())
	var pair: Array = []
	for x in out:
		for y in out:
			if pair.is_empty() and x != y and x.loc == y.loc and not x.loc.begins_with("home_"):
				pair = [x, y]
	if pair.size() < 2:
		check(false, "(fixture) two people out at the same place")
		return
	for n in g.w.living():
		n.busy_with = ""
	g.loc = pair[0].loc
	g._observe()
	var seen_first = func(n): return g.board.filter(func(c): return c.kind == "sighting" and c.subject == [n.id] and int(c.day) == g.w.day and int(c.phase) == g.w.phase).size()
	var before_a: int = seen_first.call(pair[0])
	pair[0].busy_with = pair[1].id
	pair[1].busy_with = pair[0].id
	g._card_conversations()
	check(before_a == 1 and seen_first.call(pair[0]) == 1 and seen_first.call(pair[1]) == 1, "a visit then the talk in the same phase: still one sighting card each")
	check(g.board.any(func(c): return c.kind == "conversation" and pair[0].id in c.subject and pair[1].id in c.subject), "and the talk is its own card")
