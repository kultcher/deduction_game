## Playtest triage items from Nov 16: a far sighting's crowd count (8.2), the Augur's
## sightings hint (5.10).
extends SceneTree

const Game = preload("res://game/game.gd")
const GameScreens = preload("res://game/game_screens.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_crowd()
	_augur()
	print("Triage Nov 16: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	return g


## 8.2: a sighting from afar notes how many more people were at that place, unseen.
func _crowd() -> void:
	var g = _game()
	var w = g.w
	var people: Array = w.living()
	var far_block: String = ""
	var far_loc: String = ""
	for b in ["docks", "square", "market", "hill"]:
		if b != w.loc_block(g.loc) and not w.locations_on(b).is_empty():
			far_block = b
			far_loc = w.locations_on(b).filter(func(l): return not str(l).begins_with("home_"))[0]
			break
	check(far_loc != "", "(fixture) a public place off the player's block (%s)" % far_loc)
	g.moved = true
	for n in people:
		n.busy_with = ""
		n.working = false
		n.loc = g.loc if not str(g.loc).begins_with("home_") else n.home
	var worker = people[0]
	worker.loc = far_loc
	worker.working = true
	for n in people.slice(1, 3):
		n.loc = far_loc
	var fact: Dictionary = {"kind": "sighting", "subject": [worker.id], "loc": far_loc, "block": far_block, "text": "You saw %s working there." % worker.name}
	GameScreens._mark_crowd(g, fact)
	check(int(fact.get("crowd_unseen", 0)) == 2 and "(+2 people there)" in str(fact.text), "a far sighting notes the two people there you couldn't make out (%s)" % str(fact))
	var alone: Dictionary = {"kind": "sighting", "subject": [worker.id], "loc": g.loc, "text": "You saw them."}
	GameScreens._mark_crowd(g, alone)
	check(not alone.has("crowd_unseen") and alone.text == "You saw them.", "one where you see everyone notes nothing")


## 5.10: the Augur's reading names nobody; its hint lists who your sightings put on its block.
func _augur() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var augur = p[2]
	g.w.day = 2
	g.board.clear()  # only this fixture's cards (the game makes its own work sightings)
	g._fact_keys.clear()
	g.add_card({"kind": "info", "source": augur.id, "role": "augur", "day": 1, "phase": 2, "data": {"yes": true}, "text": "%s augur day 1: crossed the demon" % augur.id})
	g.add_card({"kind": "sighting", "subject": [augur.id], "source": "player", "block": "docks", "loc": "wharf", "day": 1, "phase": 0, "text": "You saw the Augur."})
	g.add_card({"kind": "sighting", "subject": [p[3].id], "source": "player", "block": "docks", "loc": "mill", "day": 1, "phase": 0, "crowd_unseen": 2, "text": "You saw p3 (+2 people there)."})
	g.add_card({"kind": "sighting", "subject": [p[4].id], "source": "player", "block": "hill", "loc": "chapel", "day": 1, "phase": 0, "text": "You saw p4 elsewhere."})
	g.add_card({"kind": "sighting", "subject": [p[5].id], "source": "player", "block": "docks", "loc": "mill", "day": 1, "phase": 1, "text": "You saw p5 in the afternoon, Augur unplaced."})
	g.add_card({"kind": "sighting", "subject": [p[6].id], "source": "player", "block": "docks", "loc": "mill", "day": 2, "phase": 0, "text": "Another day."})
	var view: Dictionary = Live.view(g)
	var card: Dictionary = {}
	for c in view.cards:
		if str(c.get("role", "")) == "augur":
			card = c
	check(not card.is_empty(), "(fixture) the Augur reading is in the view")
	var hint: String = Live.augur_sightings(view, card)
	var nm = func(i): return Solver.person_name(view, p[i].id)
	check(hint.begins_with("Sightings: ") and nm.call(3) in hint and hint.ends_with("+at least 2 unknowns"), "the hint names who you saw on the Augur's block that morning, and the unknowns there (%s)" % hint)
	check(nm.call(2) not in hint, "not the Augur itself")
	check(nm.call(4) not in hint, "not someone on another block")
	check(nm.call(5) not in hint, "not a phase you didn't see where the Augur was")
	check(nm.call(6) not in hint, "not another day")
	var lone = Game.new()
	lone.detailed_logging = false
	lone.new_case(692, 7)
	lone.add_card({"kind": "info", "source": lone.w.npcs[2].id, "role": "augur", "day": 1, "phase": 2, "data": {"yes": false}, "text": "no crossing"})
	var lv: Dictionary = Live.view(lone)
	var lc: Dictionary = {}
	for c in lv.cards:
		if str(c.get("role", "")) == "augur":
			lc = c
	check(Live.augur_sightings(lv, lc) == "", "with no sighting of the Augur that day, there's no hint")
