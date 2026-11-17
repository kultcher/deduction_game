## Playtest triage items from Nov 16: a far sighting's crowd count (8.2), the Augur's
## sightings hint (5.10), a Lovers confession proving the partner (5.9), the canvas's
## shift+left-drag box, and left- or right-drag pan (8.1, changed by Michael Nov 17).
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
	_augur_two_phases()
	_lovers()
	_canvas_drag()
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


## The same unseen people may be there morning and afternoon: the count is the larger
## phase's, not the sum (Codex, #162).
func _augur_two_phases() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var augur = p[2]
	g.w.day = 2
	g.board.clear()
	g._fact_keys.clear()
	g.add_card({"kind": "info", "source": augur.id, "role": "augur", "day": 1, "phase": 2, "data": {"yes": true}, "text": "%s augur day 1: crossed the demon" % augur.id})
	for ph in [0, 1]:
		g.add_card({"kind": "sighting", "subject": [augur.id], "source": "player", "block": "docks", "loc": "wharf", "day": 1, "phase": ph, "crowd_unseen": 2, "text": "You saw the Augur (+2 people there), phase %d." % ph})
	var view: Dictionary = Live.view(g)
	var card: Dictionary = {}
	for c in view.cards:
		if str(c.get("role", "")) == "augur":
			card = c
	var hint: String = Live.augur_sightings(view, card)
	check(hint.ends_with("+at least 2 unknowns"), "two phases with two unseen each: at least 2, not 4 (%s)" % hint)


## 5.9: a Lovers confession names the other, and proves both halves.
func _lovers() -> void:
	var g = null
	var x = null
	for seed_v in range(100000, 100200):
		var t = Game.new()
		t.detailed_logging = false
		t.new_case(seed_v, 7)
		var found: Array = t.w.npcs.filter(func(n): return n.lover != "" and str(n.secret.get("kind", "")) == "lover")
		if not found.is_empty():
			g = t
			x = found[0]
			break
	check(g != null, "(fixture) a game with Lovers")
	if g == null:
		return
	var partner = g.w.by_id[x.lover]
	g.w.day = 2
	var conf: int = g.add_card({"kind": "secret", "subject": [x.id], "owner": x.id, "source": x.id, "block": partner.home_block, "day": 1, "phase": 3,
		"secret_kind": "lover", "mod": "lovers", "partner": partner.id, "text": "%s confessed: %s" % [x.name, x.secret.text]})
	var view: Dictionary = Live.view(g)
	var card: Dictionary = {}
	for c in view.cards:
		if str(c.get("kind", "")) == "secret_claim":
			card = c
	check(str(card.get("data", {}).get("partner", "")) == partner.id, "the confession card names the partner (%s)" % str(card.get("data", {})))
	var CanvasModel = preload("res://workshop/canvas_model.gd")
	var cases: Dictionary = {}
	for who in [partner, g.w.npcs.filter(func(n): return n != x and n != partner)[0]]:
		var m = CanvasModel.new(view)
		var prem: String = m.add_premise(who.id, "secret_mod", Vector2.ZERO)
		m.nodes[prem].conclusion["mod"] = "lovers"
		for id in m.nodes:
			if m.nodes[id].kind == "evidence" and m.nodes[id].card == card.id:
				m.connect_cards(id, prem)
		cases[who.id] = Live.test_juror(g, m.compile(prem), false)
	var on_partner: Dictionary = cases[partner.id]
	var other_id: String = cases.keys().filter(func(k): return k != partner.id)[0]
	check(on_partner.get("ready", false) and str(on_partner.get("category", "")) == "strong" and float(on_partner.get("lr", 0.0)) > 1000.0, "the confession proves the partner holds the Lovers secret (%s)" % str(on_partner))
	check(cases[other_id].get("ready", false) and float(cases[other_id].get("lr", 1.0)) < float(on_partner.get("lr", 0.0)), "and says nothing of the kind about anyone else (x%.2f against x%.2f)" % [float(cases[other_id].get("lr", 0.0)), float(on_partner.get("lr", 0.0))])


## 8.1, as Michael changed it on Nov 17: on empty canvas a shift+left-drag draws a selection
## box, and a plain left-drag (or a right-drag) pans.
func _canvas_drag() -> void:
	var CanvasModel = preload("res://workshop/canvas_model.gd")
	var CanvasView = preload("res://ui/workshop_canvas_view.gd")
	var g = _game()
	var m = CanvasModel.new(Live.view(g))
	var prem: String = m.add_premise(g.w.npcs[0].id, "evil", Vector2.ZERO)
	var v = CanvasView.new()
	root.add_child(v)
	v.model = m
	v.hit = {prem: Rect2(100, 100, 50, 50)}
	var press = func(button: int, at: Vector2, down: bool, shift: bool = false):
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.position = at
		e.pressed = down
		e.shift_pressed = shift
		v._gui_input(e)
	var move = func(at: Vector2):
		var e := InputEventMouseMotion.new()
		e.position = at
		v._gui_input(e)
	press.call(MOUSE_BUTTON_LEFT, Vector2(10, 10), true, true)
	move.call(Vector2(200, 200))
	press.call(MOUSE_BUTTON_LEFT, Vector2(200, 200), false, true)
	check(v.group == [prem], "a shift+left-drag on empty canvas box-selects the card inside (%s)" % str(v.group))
	var before: Vector2 = v.pan
	press.call(MOUSE_BUTTON_RIGHT, Vector2(300, 300), true)
	move.call(Vector2(340, 320))
	press.call(MOUSE_BUTTON_RIGHT, Vector2(340, 320), false)
	check(v.pan == before + Vector2(40, 20), "a right-drag on empty canvas pans (%s -> %s)" % [str(before), str(v.pan)])
	press.call(MOUSE_BUTTON_LEFT, Vector2(10, 10), true)
	press.call(MOUSE_BUTTON_LEFT, Vector2(10, 10), false)
	check(v.group.is_empty() and v.pan == before + Vector2(40, 20), "a left click on empty canvas clears the box and doesn't pan")
	var before_left: Vector2 = v.pan
	press.call(MOUSE_BUTTON_LEFT, Vector2(300, 300), true)
	move.call(Vector2(330, 310))
	press.call(MOUSE_BUTTON_LEFT, Vector2(330, 310), false)
	check(v.pan == before_left + Vector2(30, 10) and v.group.is_empty(), "a plain left-drag on empty canvas pans (%s -> %s)" % [str(before_left), str(v.pan)])
	v.queue_free()
