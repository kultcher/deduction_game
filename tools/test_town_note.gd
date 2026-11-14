## The Workshop's "No new info" note (WorkshopCanvas.town_note; triage 5.2, Michael's
## rulings of Nov 14). With the connections switch on, beside the Test juror's strength:
##
## - nothing with the switch off;
## - a case that brings any card the town hasn't heard never gets a note;
## - public cards that add little together: "No new info";
## - cards you put to the town today already: "No new info"; under a "suspicious"
##   premise, "Adds no new belief, but still presses" its subject;
## - cards you put to the town on an earlier day: a refresh, not the warning;
## - the player's watch record doesn't enter it.
extends SceneTree

const Game = preload("res://game/game.gd")
const Connections = preload("res://workshop/connections.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const Caches = preload("res://workshop/caches.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks: int = 0
var fails: int = 0
var _texts: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	_notes()
	Connections.enabled = Tuning.Workshop.CONNECTIONS
	print("Town note: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _game():
	LiveActivity.cache.clear()
	Caches.clear_all()
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	for p in g.w.npcs:
		p.info_log = []
		p.known_claims = {}
		p.beliefs = []
		p.ledger = {}
	g.w.day = 2
	return g


func _read(g, source, role: String, day: int, data: Dictionary) -> int:
	var number: int = g.add_card({"kind": "info", "source": source.id, "role": role, "day": day,
		"phase": 3 if role == "seer" else 0, "data": data, "text": "%s %s day %d: %s" % [source.id, role, day, JSON.stringify(data)]})
	_texts[number] = g.board[number - 1].text
	return number


func _node(model, view, number: int) -> String:
	var card_id: String = ""
	for c in view.cards:
		if c.get("number", -1) == number or c.get("n", -1) == number:
			card_id = c.id
	for id in model.nodes:
		var nd = model.nodes[id]
		if nd.kind == "evidence" and (nd.card == card_id or Solver.card_by_id(view, nd.card).get("text", "") == str(_texts.get(number, ""))):
			return id
	return ""


## A draft case as the Workshop compiles it: premise (type, target) on `support` cards.
func _value(g, type: String, target: String, support: Array) -> Dictionary:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(target, type, Vector2(400, 40))
	for number in support:
		model.connect_cards(_node(model, view, number), premise)
	return model.compile(premise)


func _kind(g, value: Dictionary) -> String:
	return str(Live.town_note(g, value).get("kind", ""))


func _notes() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	# A Seer "one of p3 and p4 is evil" and a Dowser "p4 is clean": together they point at p3.
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	var other: int = _read(g, p[6], "dowser", 1, {"group": [p[1].id], "count": 0})
	var both: Dictionary = _value(g, "evil", p[3].id, [seer, dowser])
	var one: Dictionary = _value(g, "evil", p[3].id, [seer])
	check(both.cards.size() == 2 and one.cards.size() == 1, "the fixture compiles its two drafts")

	Connections.enabled = false
	g.public_citations[seer] = true
	check(Live.town_note(g, one).is_empty(), "with the switch off there is no note")
	Connections.enabled = true
	g.public_citations.clear()

	# Cards the town hasn't heard are news.
	check(Live.town_note(g, one).is_empty() and Live.town_note(g, both).is_empty(), "a case of cards the town hasn't heard gets no note")
	g.public_citations[seer] = true
	var alone: Dictionary = Live.town_note(g, one)
	check(alone.get("kind", "") == "none" and str(alone.get("text", "")).begins_with("No new info"), "one card the town already has: \"No new info\" (%s)" % str(alone.get("text", "")))
	check(Live.town_note(g, both).is_empty(), "the same card with one the town hasn't heard: no note")
	g.public_citations[dowser] = true
	var weak: Dictionary = Live.town_note(g, both)
	check(weak.get("kind", "") == "none" and float(weak.adds) > 0.0 and float(weak.adds) < Live.NOTE_ADDS_LITTLE, "two public cards that say little more together: \"No new info\" (they add %.3f)" % float(weak.get("adds", -1.0)))
	var together: Dictionary = Live.town_note(g, both, float(weak.get("adds", 1.0)) * 0.5)
	check(together.is_empty(), "public cards that add more than the threshold together are worth presenting: no note")

	# The watch record stays out of it.
	g.watched.append({"day": 1, "phase": "night", "block": p[3].home_block, "at": p[3].home_block})
	check(Live.town_note(g, one) == alone and Live.town_note(g, both) == weak, "the player's watch record changes nothing")
	g.watched.clear()

	# Put to the town today.
	var filed: int = Live.file(g, both)
	g.public_presentations[filed] = int(g.w.day)
	var repeat: Dictionary = Live.town_note(g, both)
	check(repeat.get("kind", "") == "repeat" and ("#%d" % filed) in str(repeat.get("text", "")), "the same case again the same day: \"No new info\", naming the case (%s)" % str(repeat.get("text", "")))
	check(_kind(g, _value(g, "good", p[4].id, [seer, dowser])) == "repeat", "the same cards under another premise the same day: the same")
	# "Suspicious" presses whoever the cards, together, point at; nobody else.
	var kinds: Dictionary = {}
	var pressed: Dictionary = {}
	for q in p:
		var note: Dictionary = Live.town_note(g, _value(g, "suspicious", q.id, [seer, dowser]))
		kinds[str(note.get("kind", ""))] = true
		if note.get("kind", "") == "presses":
			pressed = note
	check(pressed.get("kind", "") == "presses" and "still presses" in str(pressed.get("text", "")), "under \"suspicious\": no new belief, but it still presses them (%s)" % str(pressed.get("text", "")))
	check(kinds.has("repeat") and kinds.keys().all(func(k): return k in ["presses", "repeat"]), "someone the cards don't point at isn't pressed: plain \"No new info\" (%s)" % str(kinds.keys()))
	check(_kind(g, one) == "repeat", "a part of what you already argued: \"No new info\"")
	g.public_citations[other] = true
	check(_kind(g, _value(g, "evil", p[3].id, [seer, dowser, other])) != "repeat", "the same cards with another: not a repeat")

	# A later day: a refresh, not the warning.
	g.w.day += 1
	var refresh: Dictionary = Live.town_note(g, both)
	check(refresh.get("kind", "") == "refresh" and "day-2" in str(refresh.get("text", "")), "the same case on a later day refreshes the argument (%s)" % str(refresh.get("text", "")))
	check(_kind(g, _value(g, "good", p[4].id, [seer, dowser])) == "refresh", "so do the same cards under another firm premise")
	check(p.any(func(q): return _kind(g, _value(g, "suspicious", q.id, [seer, dowser])) == "presses"), "a \"suspicious\" premise on them counts for less than what stands, so it only presses")
	check(_kind(g, _value(g, "evil", p[3].id, [seer, dowser, other])) not in ["refresh", "repeat"], "a bigger case on a later day is neither a refresh nor a repeat")
	Connections.enabled = false
