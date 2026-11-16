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
	_retired_and_challenged()
	_profile_and_upgrade()
	_deleted_and_faded()
	_conflict_quotes()
	_conflict_draft()
	_supersets()
	_spent_pressure()
	Connections.enabled = false


## Codex on #154: a case you've revised in public no longer stands as an argument (the town
## retracted it), and a reading challenge isn't in the stored-case arithmetic.
func _retired_and_challenged() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	g.public_citations[seer] = true
	g.public_citations[dowser] = true
	var both: Dictionary = _value(g, "evil", p[3].id, [seer, dowser])
	var one: Dictionary = _value(g, "evil", p[3].id, [seer])
	var first: int = Live.file(g, both)
	g.public_presentations[first] = int(g.w.day)
	check(_kind(g, both) == "repeat", "(fixture) the case once presented is a repeat")
	var revised: int = Live.file(g, one)
	g.board[revised - 1]["revises"] = first
	g.public_presentations[revised] = int(g.w.day)
	check(_kind(g, both) != "repeat", "after a public revision to fewer cards, the old version is no argument of yours: no repeat (%s)" % _kind(g, both))
	check(_kind(g, one) == "repeat", "the revision itself still counts")
	var fresh = _game()
	var q: Array = fresh.w.npcs
	var s2: int = _read(fresh, q[2], "seer", 1, {"pair": [q[3].id, q[4].id], "yes": true})
	fresh.public_citations[s2] = true
	var plain: Dictionary = _value(fresh, "evil", q[3].id, [s2])
	check(not Live.town_note(fresh, plain).is_empty(), "(fixture) one public card alone gets a note")
	var challenged: Dictionary = plain.duplicate(true)
	challenged["reading_challenges"] = {str(plain.cards[0]): {"mode": "misled", "supports": []}}
	check(Live.town_note(fresh, challenged).is_empty(), "a case that challenges a reading gets no note")


## Codex on #154 (second pass): a case citing a Townsfolk Profile node (its receipts have
## negative numbers) can still be a repeat; and a firm premise on cards you've only argued
## as "suspicious" counts for more, so it isn't a repeat.
func _profile_and_upgrade() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	g.public_citations[seer] = true
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var premise: String = model.add_premise(p[3].id, "evil", Vector2(400, 40))
	model.connect_cards(_node(model, view, seer), premise)
	var prof: String = model.add_profile_info(p[3].id, ["home_work"])
	model.connect_cards(prof, premise)
	var with_profile: Dictionary = model.compile(premise)
	var roots: Dictionary = Live.supports(g, with_profile)
	check(roots.numbers.any(func(x): return int(x) < 0), "(fixture) the case cites a profile receipt (%s)" % str(roots.numbers))
	var filed: int = Live.file(g, with_profile)
	g.public_presentations[filed] = int(g.w.day)
	check(_kind(g, with_profile) == "repeat", "a case with a Townsfolk Profile node, presented again the same day: a repeat (%s)" % _kind(g, with_profile))
	var h = _game()
	var q: Array = h.w.npcs
	var s2: int = _read(h, q[2], "seer", 1, {"pair": [q[3].id, q[4].id], "yes": true})
	var d2: int = _read(h, q[5], "dowser", 1, {"group": [q[4].id], "count": 0})
	h.public_citations[s2] = true
	h.public_citations[d2] = true
	var sus: Dictionary = _value(h, "suspicious", q[3].id, [s2, d2])
	var firm: Dictionary = _value(h, "evil", q[3].id, [s2, d2])
	var first: int = Live.file(h, sus)
	h.public_presentations[first] = int(h.w.day)
	# (Its joint effect here is small, so at the default bar the doubling is still "little";
	# with a bar below what the doubling adds, it isn't a repeat.)
	var upgrade: Dictionary = Live.town_note(h, firm, 0.0001)
	check(str(upgrade.get("kind", "")) not in ["repeat", "presses"], "a firm premise on cards argued only as \"suspicious\" today counts for more: not a repeat (%s)" % str(upgrade.get("kind", "")))
	check(_kind(h, sus) in ["repeat", "presses"], "the same \"suspicious\" case again still is")


## Codex on #154 (third pass): a case deleted from your board still stands with the town;
## an argument that has faded out entirely is refreshed by the same cards, not repeated.
func _deleted_and_faded() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	g.public_citations[seer] = true
	g.public_citations[dowser] = true
	var both: Dictionary = _value(g, "evil", p[3].id, [seer, dowser])
	var filed: int = Live.file(g, both)
	g.public_presentations[filed] = int(g.w.day)
	g.delete_deduction(filed)
	check(g.board[filed - 1].get("deleted", false), "(fixture) the case is deleted from the board")
	check(_kind(g, both) == "repeat", "a deleted case you presented still makes the same draft a repeat (%s)" % _kind(g, both))
	g.w.day += 8
	var other: Dictionary = _value(g, "good", p[4].id, [seer, dowser])
	check(_kind(g, other) == "refresh", "long after, when the argument has faded out, the same cards under another premise refresh it (%s)" % _kind(g, other))


## Codex on #154 (fourth pass): a public "these reports conflict" case quotes its cards but
## argues for none of them, so a firm case on those cards isn't a repeat.
func _conflict_quotes() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	g.public_citations[seer] = true
	g.public_citations[dowser] = true
	var conflict: Dictionary = _value(g, "conflict", p[3].id, [seer, dowser])
	var firm: Dictionary = _value(g, "evil", p[3].id, [seer, dowser])
	check(str(conflict.get("conclusion", {}).get("type", "")) == "conflict" and conflict.cards.size() == 2, "(fixture) a conflict case on the two cards (%s)" % str(conflict.get("conclusion", {})))
	var filed: int = Live.file(g, conflict)
	g.public_presentations[filed] = int(g.w.day)
	check(_kind(g, firm) not in ["repeat", "presses"], "a firm case on cards a public conflict case only quoted isn't a repeat (%s)" % _kind(g, firm))


## Codex on #154 (fifth pass): a "conflict" draft argues for none of its cards, so it can't
## refresh (or repeat) a firm case on them.
func _conflict_draft() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	g.public_citations[seer] = true
	g.public_citations[dowser] = true
	var firm: Dictionary = _value(g, "evil", p[3].id, [seer, dowser])
	var filed: int = Live.file(g, firm)
	g.public_presentations[filed] = int(g.w.day)
	g.w.day += 1
	var conflict: Dictionary = _value(g, "conflict", p[3].id, [seer, dowser])
	check(Live.town_note(g, conflict).is_empty(), "a conflict draft on a firm case's cards gets no note, not a refresh (%s)" % _kind(g, conflict))


## Codex on #154 (sixth pass), now that the note follows the arithmetic: a larger case that
## still counts leaves a smaller one nothing to refresh; a larger one that has faded out
## doesn't make a smaller one a repeat.
func _supersets() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	var other: int = _read(g, p[6], "dowser", 1, {"group": [p[1].id], "count": 0})
	for c in [seer, dowser, other]:
		g.public_citations[c] = true
	var two: Dictionary = _value(g, "evil", p[3].id, [seer, dowser])
	var three: Dictionary = _value(g, "evil", p[3].id, [seer, dowser, other])
	var a: int = Live.file(g, two)
	g.public_presentations[a] = int(g.w.day)
	var b: int = Live.file(g, three)
	g.public_presentations[b] = int(g.w.day)
	g.w.day += 1
	check(_kind(g, two) != "refresh", "the smaller case again the next day, while the larger one still counts: no refresh (%s)" % _kind(g, two))
	var h = _game()
	var q: Array = h.w.npcs
	var s2: int = _read(h, q[2], "seer", 1, {"pair": [q[3].id, q[4].id], "yes": true})
	var d2: int = _read(h, q[5], "dowser", 1, {"group": [q[4].id], "count": 0})
	var o2: int = _read(h, q[6], "dowser", 1, {"group": [q[1].id], "count": 0})
	for c in [s2, d2, o2]:
		h.public_citations[c] = true
	var big: int = Live.file(h, _value(h, "evil", q[3].id, [s2, d2, o2]))
	h.public_presentations[big] = int(h.w.day)
	h.w.day += 40  # (a case the town bought fades slowly: 8 days on it still counts)
	check(_kind(h, _value(h, "evil", q[3].id, [s2, d2])) != "repeat", "a smaller case long after the larger one faded out isn't a repeat (%s)" % _kind(h, _value(h, "evil", q[3].id, [s2, d2])))


## Codex on #155: a "suspicious" filing presses once, from its first hearing; after a meeting
## heard it, the same case again presses no one, so it's a plain repeat.
func _spent_pressure() -> void:
	var g = _game()
	var p: Array = g.w.npcs
	var seer: int = _read(g, p[2], "seer", 1, {"pair": [p[3].id, p[4].id], "yes": true})
	var dowser: int = _read(g, p[5], "dowser", 1, {"group": [p[4].id], "count": 0})
	g.public_citations[seer] = true
	g.public_citations[dowser] = true
	var target: String = ""
	var value: Dictionary = {}
	for q in p:
		var v: Dictionary = _value(g, "suspicious", q.id, [seer, dowser])
		var filed: int = Live.file(g, v)
		g.public_presentations[filed] = int(g.w.day)
		if _kind(g, v) == "presses":
			target = q.id
			value = v
			break
		g.public_presentations.erase(filed)
	check(target != "", "(fixture) a suspicious repeat that still presses someone")
	if target == "":
		return
	var roots: Dictionary = Live.supports(g, value)
	var ids: Array = roots.numbers.duplicate()
	ids.sort()
	g.w.suspicious_pressure[target + "|" + ",".join(PackedStringArray(ids))] = {"sum": 0.1, "count": 3, "applied": 0.3, "venue": "meeting", "heard": []}
	check(_kind(g, value) == "repeat", "once a meeting has heard the filing, it presses no one again: a plain repeat (%s)" % _kind(g, value))
