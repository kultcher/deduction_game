## A defence's answer to a daytime-whereabouts case (BACKLOG, Michael, Nov 16; plan approved
## Nov 19, no evil lie): a nominee whose heaviest case item is a daytime sighting says where
## they were and who else was there, from the public whereabouts:
## - with others there, it names two or three of them;
## - with someone it suspects there, it points at them;
## - with nobody else there, it says so;
## - the player gets a sighting card for each person named, and the defender's own;
## - an evil defender tells it the same, truthfully, leaving out its teammates (Steward A5);
## - the dead are never named as witnesses (Steward A6).
extends SceneTree
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const MindDefence = preload("res://sim/mind_defence.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_cases()
	print("Day defence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _world():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9811, 10)
	g.w.day = 2
	g.w.phase = C.EVENING
	return g.w

## Puts `d` and `with` at the mill on day 1's afternoon, everyone else at home, and returns the
## case item a daytime sighting of `d` there makes.
func _place(w, d, with: Array) -> Array:
	var key: String = w.time_key(1, C.AFTERNOON)
	for n in w.npcs:
		n.history[key] = "home:" + n.home_block
	d.history[key] = "mill"
	for x in with:
		x.history[key] = "mill"
	return [{"eid": "sighting_day:%s:%s:%d:%d:%s" % ["someone", d.id, 1, C.AFTERNOON, w.loc_block("mill")], "why": "where I was by day",
		"contrib": 0.5, "kind": "public", "strength": 0.5, "entry": {}, "channel": "whereabouts_day"}]

func _text(r: Dictionary) -> String:
	return str(r.get("line", {}).get("statement", r.get("line", {}).get("text", "")))

func _cases() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var d = goods[0]
	var a = goods[1]
	var b = goods[2]
	for x in [a, b]:
		d.suspicion[x.id] = 0.1
	var r: Dictionary = MindDefence._day_whereabouts_defence(w, d, _place(w, d, [a, b]), false)
	_check(not r.is_empty(), "a case resting on a daytime sighting gets an answer")
	var t: String = _text(r)
	_check(a.name in t and b.name in t and "yesterday afternoon" in t, "it names who else was there, and when (%s)" % t)
	var cards: Array = r.get("facts", [])
	_check(cards.size() == 3 and cards.all(func(f): return f.kind == "sighting" and int(f.day) == 1 and int(f.phase) == C.AFTERNOON), "a sighting card for the defender and each person named (%d)" % cards.size())
	# Someone it suspects was there: it points at them.
	d.suspicion[b.id] = Tuning.Meeting.NOMINATION_FLOOR + 0.1
	var r2: Dictionary = MindDefence._day_whereabouts_defence(w, d, _place(w, d, [a, b]), false)
	_check(b.name in _text(r2) and not (a.name in _text(r2)), "with a suspect there, it points at them (%s)" % _text(r2))
	var c2: Array = r2.facts.filter(func(f): return not f.get("self_report", false)).map(func(f): return f.subject[0])
	_check(c2 == [b.id], "and the player's cards are for the person named, the suspect, not the others there (%s)" % str(c2))
	# A suspect beyond the first three present still gets the card (Codex on #318).
	var crowd: Array = [a, goods[3], goods[4], goods[5], b]
	for x in crowd:
		if x != b:
			d.suspicion[x.id] = 0.1
	var r5: Dictionary = MindDefence._day_whereabouts_defence(w, d, _place(w, d, crowd), false)
	var c5: Array = r5.facts.filter(func(f): return not f.get("self_report", false)).map(func(f): return f.subject[0])
	_check(c5 == [b.id] and b.name in _text(r5), "a suspect fifth among those present is named and carded (%s)" % str(c5))
	# One companion: the singular line, not a plural one ("so was", not "were there").
	d.suspicion[b.id] = 0.1
	var r6: Dictionary = MindDefence._day_whereabouts_defence(w, d, _place(w, d, [a]), false)
	_check(("so was " + a.name) in _text(r6), "with one other there, the singular line (%s)" % _text(r6))
	# Nobody else there.
	var r3: Dictionary = MindDefence._day_whereabouts_defence(w, d, _place(w, d, []), false)
	_check(not r3.is_empty() and r3.facts.size() == 1, "with nobody else there, it says so (%s)" % _text(r3))
	# Not when the heaviest item is something else.
	var items: Array = _place(w, d, [a])
	items.append({"eid": "info:x:1", "why": "their reading pointed at me", "contrib": 0.9, "channel": "report"})
	_check(MindDefence._day_whereabouts_defence(w, d, items, false).is_empty(), "not when a heavier item isn't a daytime sighting")
	# An evil defender tells the same, truthfully: the names are who was really there.
	var e = w.evil_team()[0]
	var r4: Dictionary = MindDefence._day_whereabouts_defence(w, e, _place(w, e, [a]), false)
	var named: Array = r4.get("facts", []).filter(func(f): return not f.get("self_report", false)).map(func(f): return f.subject[0])
	_check(named == [a.id], "an evil defender names only who was really there (%s)" % str(named))
	# An evil defender never points at, or calls as witness, its own teammate (Steward Nov 19 A5).
	var team: Array = w.evil_team()
	if team.size() >= 2:
		var mate = team[1]
		var r7: Dictionary = MindDefence._day_whereabouts_defence(w, e, _place(w, e, [mate, a]), false)
		var c7: Array = r7.get("facts", []).filter(func(f): return not f.get("self_report", false)).map(func(f): return f.subject[0])
		_check(not (mate.id in c7) and not (mate.name in _text(r7)) and c7 == [a.id], "an evil defender leaves its teammate out (%s)" % _text(r7))
		var r8: Dictionary = MindDefence._day_whereabouts_defence(w, e, _place(w, e, [mate]), false)
		_check(r8.get("facts", []).size() == 1 and not (mate.name in _text(r8)), "with only its teammate there, it names nobody (%s)" % _text(r8))
	else:
		_check(false, "a deal with two evil to test the teammate case")
	# The dead aren't named as witnesses (Steward Nov 19 A6).
	d.suspicion[b.id] = 0.1
	a.alive = false
	var r9: Dictionary = MindDefence._day_whereabouts_defence(w, d, _place(w, d, [a, b]), false)
	var c9: Array = r9.get("facts", []).filter(func(f): return not f.get("self_report", false)).map(func(f): return f.subject[0])
	_check(c9 == [b.id] and not (a.name in _text(r9)), "the dead aren't named as witnesses (%s)" % _text(r9))
	a.alive = true
	# Sentence-start slots raise only the first letter (Steward Nov 19 A6).
	_check(MindDefence._first_upper("yesterday afternoon") == "Yesterday afternoon" and MindDefence._first_upper("") == "", "a slot at the start of a sentence raises only its first letter")
