## Claude's Oct 26 batch: replies match beliefs, coherent evil stories, one defence per
## incident, Demon victims' sincerity, the Rumormonger setup rule, Workshop links.
##   godot --headless --path . --script res://tools/test_claude_batch.gd
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Presentation = preload("res://game/workshop_presentation.gd")
const Evil = preload("res://sim/evil.gd")
const Live = preload("res://game/workshop_canvas.gd")
const Solver = preload("res://workshop/solver.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const C = preload("res://sim/content.gd")
var fails = 0
var checks = 0

func _init() -> void:
	_stance_from_belief()
	_one_night_story()
	_victims_were_sincere()
	_alibi_against_report()
	_test_juror_feedback()
	_connections()
	print("Claude batch: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _game(sd: int):
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	return g

func _stance_from_belief() -> void:
	_check(Presentation.belief_stance("evil", 0.2, 0.3) == "accept", "a 0.10 rise toward 'evil' is acceptance")
	_check(Presentation.belief_stance("evil", 0.2, 0.23) == "partial", "a 0.03 rise is partial")
	_check(Presentation.belief_stance("evil", 0.2, 0.2) == "reject", "no movement is no")
	_check(Presentation.belief_stance("good", 0.4, 0.3) == "accept", "for 'good', suspicion falling is acceptance")
	var g = _game(4401)
	var n = g.w.living_good()[0]
	var t = g.w.living_good()[1]
	n.suspicion[t.id] = 0.32
	var couldnt = "I could not follow your explanation through within what I considered. That does not prove it wrong."
	var said: String = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "reject", couldnt)
	_check(said.begins_with(couldnt) and said.ends_with("Even so, it does change how I see %s." % t.name), "couldn't follow, but moved: the reason stays and the stance follows the belief (%s)" % said)
	n.suspicion[t.id] = 0.2
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.")
	_check(said == "It holds together, but it doesn't change my mind about %s." % t.name, "convinced in words but unmoved: says so (%s)" % said)
	n.suspicion[t.id] = 0.8
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.8, "accept", "Taken together, those reports convince me. If anything, it points me toward Agnes.")
	_check(said == "If anything, it points me toward Agnes. I'd already come to that about %s." % t.name, "already convinced: says so and keeps the other reasons (%s)" % said)
	n.suspicion[t.id] = 0.3
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.")
	_check(said == "Taken together, those reports convince me.", "when words and belief agree, the reply is unchanged")
	n.suspicion[t.id] = 0.2
	said = Presentation._belief_stance_text(g, n, "evil", t.id, 0.2, "accept", "Taken together, those reports convince me.", true)
	_check(said == "I'd already taken that into account.", "a retold case they'd already weighed: says so (%s)" % said)
	said = Presentation._belief_stance_text(g, n, "conflict", t.id, 0.2, "accept", "Those accounts cannot all be accurate.")
	_check(said == "Those accounts cannot all be accurate.", "conflicts are left alone")

## One story per evil member per night: a made-up sighting repeats that night's fake watch
## report, never someone else (Constance, 54875).
func _one_night_story() -> void:
	var same = 0
	var other_block_quiet = 0
	var tried = 0
	for sd in range(4410, 4430):
		var g = _game(sd)
		var w = g.w
		var m = w.minion()
		var goods: Array = w.living_good()
		var x = goods[0]
		var block: String = m.home_block
		m.info_log.append({"day": 1, "role": "nightwatch", "fake": true, "shared": false, "true": false,
			"data": {"block": block, "seen": [x.id]}, "text": "I watched it: I saw %s pass by" % x.name})
		w.day = 2
		tried += 1
		var r = Evil.fake_night_sighting(w, m, 1)
		if r != null and r["who"] == x.id:
			same += 1
		var away: String = C_other(block)
		if Evil.fake_night_sighting(w, m, 1, away, "street") == null:
			other_block_quiet += 1
	_check(same == tried, "a window sighting repeats the member's own watch report for that night (%d/%d)" % [same, tried])
	_check(other_block_quiet == tried, "and nothing is invented on another block")

func C_other(block: String) -> String:
	for b in preload("res://sim/content.gd").BLOCKS:
		if b != block:
			return b
	return block

## A Demon victim was good: evidence against them stops discounting their word.
func _victims_were_sincere() -> void:
	var g = _game(4431)
	var w = g.w
	var goods: Array = w.living_good()
	var listener = goods[0]
	var victim = goods[1]
	Mind.ledger_hear(w, listener, "test:frame", [[victim.id, 0.4, false, "seen out on the kill night", ""]], 1.0)
	var alive_honesty: float = listener.honesty.get(victim.id, 1.0)
	victim.alive = false
	victim.death_cause = "demon"
	w.public_event("demon_death", [victim.id], "")
	Mind.recompute_beliefs(w, listener, "")
	_check(alive_honesty < 1.0 and listener.honesty.get(victim.id, 1.0) == 1.0, "evidence against someone discounts their word (%.2f) until the Demon kills them (%.2f)" % [alive_honesty, listener.honesty.get(victim.id, 1.0)])

## A gift reading against an alibi offers both explanations: the alibi is false (as
## linked) or the report is (a suspected lie). One person's own report against their own
## "I was home" links the same way (54875).
func _alibi_against_report() -> void:
	var g = _game(692)
	var goods: Array = g.w.living_good()
	var watcher = goods[1]
	var seen = goods[2]
	var block: String = seen.home_block
	g.w.day = 2
	g.add_card({"kind": "alibi", "subject": [seen.id], "home": true, "day": 1, "phase": C.NIGHT, "source": seen.id, "block": seen.home_block, "text": "%s says they were home on night 1." % seen.name})
	g.add_card({"kind": "info", "source": watcher.id, "role": "nightwatch", "day": 1, "phase": 3, "data": {"block": block, "seen": [seen.id]}, "text": "%s's watch on night 1 saw %s" % [watcher.name, seen.name]})
	g.add_card({"kind": "alibi", "subject": [watcher.id], "home": true, "day": 1, "phase": C.NIGHT, "source": watcher.id, "block": watcher.home_block, "text": "%s says they were home on night 1." % watcher.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var alibi = _node(model, view, func(c): return c.kind == "alibi" and c.subject == seen.id)
	var own_alibi = _node(model, view, func(c): return c.kind == "alibi" and c.subject == watcher.id)
	var report = _node(model, view, func(c): return c.kind == "report" and c.source == watcher.id)
	_check(model.connect_cards(report, alibi) == "" and model.nodes[model.selected].kind == "contradiction", "a watch report against an alibi links as a contradiction")
	var contradiction: String = model.selected
	_check(model.report_doubtable(contradiction), "and, the report being someone's word, it can be doubted instead")
	_check(model.doubt_report(contradiction) == "" and model.nodes[model.selected].kind == "modifier" and model.nodes[model.selected].mode == "lying", "doubting it puts a suspected lie on the report")
	_check(not model.nodes[alibi].has("merged") and not model.nodes[report].has("merged"), "and restores the two cards")
	_check(model.connect_cards(report, own_alibi) == "" and model.nodes[model.selected].kind == "contradiction", "one person's own watch report against their own 'home' links as a contradiction too")

func _node(model, view, pick: Callable) -> String:
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and pick.call(Solver.card_by_id(view, nd.card)):
			return id
	return ""

## The test juror leads with "your explanation doesn't fit" and names the clashing cards;
## it also says who a case would mostly raise suspicion of, if not its subject.
func _test_juror_feedback() -> void:
	var g = _game(692)
	var goods: Array = g.w.living_good()
	var source = goods[0]
	g.w.day = 2
	g.add_card({"kind": "info", "source": source.id, "role": "surveyor", "day": 0, "phase": 3,
		"data": {"count": 0}, "text": "%s surveyed the town: no block has an evil resident" % source.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var reading = _node(model, view, func(c): return c.kind == "report" and c.source == source.id)
	var premise = model.add_premise(goods[1].id, "evil", Vector2(0, 0))
	model.connect_cards(reading, premise)
	var value = model.compile(premise)
	var card_id: String = model.nodes[reading].card
	value.answers[card_id] = {"positive": [], "blocks": []}
	var other: String = goods[2].id
	var result = {}
	Live.feedback(view, value, {"impossible": true, "people": {goods[1].id: {"prior": 0.3, "posterior": 0.32}, other: {"prior": 0.3, "posterior": 0.5}}}, result)
	_check(result.get("headline", "").begins_with("Your chosen explanation doesn't fit"), "a clash under your own choices is the headline (%s)" % result.get("headline", ""))
	_check(card_id in result.get("clashing", []), "and the card you answered is outlined")
	_check(result.get("raises", "") == other, "a case that mostly raises someone else says so (%s)" % result.get("raises_text", ""))
	var plain = {}
	Live.feedback(view, value, {"impossible": false, "people": {goods[1].id: {"prior": 0.3, "posterior": 0.6}, other: {"prior": 0.3, "posterior": 0.4}}}, plain)
	_check(not plain.has("headline") and not plain.has("raises"), "a case that holds and mostly moves its subject has no such notes")


## Connections: board cards that bear on a premise, ranked by how far they'd move it.
func _connections() -> void:
	var g = _game(692)
	var goods: Array = g.w.living_good()
	var watcher = goods[1]
	var seen = goods[2]
	g.w.day = 2
	g.add_card({"kind": "info", "source": watcher.id, "role": "nightwatch", "day": 1, "phase": 3, "data": {"block": seen.home_block, "seen": [seen.id]}, "text": "%s's watch on night 1 saw %s" % [watcher.name, seen.name]})
	var alibi_n: int = g.add_card({"kind": "alibi", "subject": [seen.id], "home": true, "day": 1, "phase": C.NIGHT, "source": seen.id, "block": seen.home_block, "text": "%s says they were home on night 1." % seen.name})
	var view = Live.view(g)
	var model = CanvasModel.new(view)
	var report = _node(model, view, func(c): return c.kind == "report" and c.source == watcher.id)
	var premise = model.add_premise(seen.id, "evil", Vector2(0, 0))
	model.connect_cards(report, premise)
	var found: Array = Live.connections(g, model.compile(premise))
	_check(found.any(func(c): return c.number == alibi_n), "Connections finds the alibi that bears on the premise (%s)" % str(found.map(func(c): return [c.number, snappedf(c.move, 0.01)])))
	var sorted = true
	for i in range(1, found.size()):
		if absf(found[i].move) > absf(found[i - 1].move):
			sorted = false
	_check(sorted and found.size() <= 5, "ranked by how far each moves it, at most five")
