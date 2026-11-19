## Meetings feed the gossip network (BACKLOG item 3, Michael, Nov 18):
## - those at the place where two people talked after the player had gone see it;
## - a witness passes it on in conversation ("X and Y were talking at Z"), but never to one of
##   the two, and evil never passes on its teammates' meetings;
## - asked about either person, a witness says so (first hand), and one who heard of it says
##   who told them (second hand); the player gets a location report for each of the two.
extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_witnesses()
	_relay()
	_asked()
	print("Meeting gossip: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _world():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9611, 10)
	g.w.day = 1
	g.w.phase = C.MORNING
	return g.w

func _meeting_belief(w, a, b) -> Dictionary:
	return {"kind": "saw", "who": a.id, "loc": "mill", "block": w.loc_block("mill"), "day": w.day, "phase": w.phase, "with": b.id}

func _witnesses() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var a = goods[0]
	var b = goods[1]
	var x = goods[2]
	var away = goods[3]
	for n in w.living():
		n.loc = "home"
		n.beliefs = []
	a.loc = "mill"
	b.loc = "mill"
	x.loc = "mill"
	away.loc = "tavern"
	w._witness_meeting(a, b)
	var seen: Array = x.beliefs.filter(func(e): return e.get("kind", "") == "saw" and str(e.get("with", "")) != "")
	_check(seen.size() == 2, "someone at the same place sees the two talking (%d entries)" % seen.size())
	_check(seen.any(func(e): return e.who == a.id and e.with == b.id) and seen.any(func(e): return e.who == b.id and e.with == a.id), "as each talking with the other")
	_check(away.beliefs.is_empty(), "someone elsewhere doesn't")
	_check(not a.beliefs.any(func(e): return str(e.get("with", "")) != ""), "nor do the two themselves")

func _relay() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var s = goods[0]
	var l = goods[1]
	var a = goods[2]
	var b = goods[3]
	var passed := 0
	var to_party := 0
	for k in range(40):
		s.beliefs = [_meeting_belief(w, a, b)]
		s.told_to = {}
		var it = Social._pick_item(w, s, l)
		if it != null and it.get("kind", "") == "meeting":
			passed += 1
		var it2 = Social._pick_item(w, s, a)
		if it2 != null and it2.get("kind", "") == "meeting":
			to_party += 1
	_check(passed > 0, "a witness passes the meeting on in conversation (%d of 40)" % passed)
	_check(to_party == 0, "never to one of the two who talked")
	# Evil keeps its teammates' meetings to itself.
	var team: Array = w.evil_team()
	if team.size() >= 2:
		var e = team[0]
		var evil_passed := 0
		for k in range(40):
			e.beliefs = [_meeting_belief(w, team[1], a)]
			e.told_to = {}
			var it3 = Social._pick_item(w, e, l)
			if it3 != null and it3.get("kind", "") == "meeting":
				evil_passed += 1
		_check(evil_passed == 0, "an evil witness never passes on a teammate's meeting")
	else:
		_check(false, "a deal with two evil to test the teammate case (Steward Nov 19 silent skip)")

func _asked() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var witness = goods[0]
	var hearer = goods[1]
	var a = goods[2]
	var b = goods[3]
	w.player_loc = "tavern"
	witness.beliefs = [_meeting_belief(w, a, b)]
	hearer.beliefs = []
	hearer.hearsay = [{"kind": "meeting", "about": a.id, "with": b.id, "loc": "mill", "block": w.loc_block("mill"), "day": w.day, "phase": w.phase,
		"from": witness.id, "witness": witness.id, "via": witness.id, "key": "meeting:x"}]
	var r1: Dictionary = MindDialogue.answer_opinion(w, witness, a)
	var conv1: Array = r1.facts.filter(func(f): return f.get("kind", "") == "conversation")
	_check(conv1.size() == 1 and str(conv1[0].source) == witness.id and not conv1[0].has("via"), "asked about one of them, a witness says it first hand")
	_check(conv1.size() == 1 and b.id in conv1[0].subject and a.id in conv1[0].subject, "naming both")
	var r1b: Dictionary = MindDialogue.answer_opinion(w, witness, b)
	_check(r1b.facts.filter(func(f): return f.get("kind", "") == "conversation").is_empty(), "once for each meeting, whichever of the two is asked about")
	var r2: Dictionary = MindDialogue.answer_opinion(w, hearer, b)
	var conv2: Array = r2.facts.filter(func(f): return f.get("kind", "") == "conversation")
	_check(conv2.size() == 1 and str(conv2[0].source) == witness.id and str(conv2[0].get("via", "")) == hearer.id, "one who heard of it passes it on second hand, naming the witness")
	var said: String = " ".join(PackedStringArray(r2.lines.map(func(x): return str(x.get("text", "")))))
	_check(witness.name in said, "and says who told them (%s)" % said)
	# Not a meeting the player is looking at.
	var w2 = _world()
	var g2: Array = w2.living_good()
	w2.player_loc = "mill"
	g2[0].beliefs = [_meeting_belief(w2, g2[2], g2[3])]
	var r3: Dictionary = MindDialogue.answer_opinion(w2, g2[0], g2[2])
	_check(r3.facts.filter(func(f): return f.get("kind", "") == "conversation").is_empty(), "not a meeting the player can see for themselves")
	# An older meeting seen first hand doesn't block newer word of another (Codex on #308).
	var w4 = _world()
	var g4: Array = w4.living_good()
	w4.player_loc = "tavern"
	w4.day = 2
	var old_b: Dictionary = _meeting_belief(w4, g4[2], g4[3])
	old_b.day = 1
	g4[0].beliefs = [old_b]
	g4[0].hearsay = [{"kind": "meeting", "about": g4[2].id, "with": g4[4].id, "loc": "wharf", "block": w4.loc_block("wharf"), "day": 2, "phase": C.MORNING,
		"from": g4[1].id, "witness": g4[1].id, "via": g4[1].id, "key": "meeting:y"}]
	var r4: Dictionary = MindDialogue.answer_opinion(w4, g4[0], g4[2])
	var c4: Array = r4.facts.filter(func(f): return f.get("kind", "") == "conversation")
	_check(c4.size() == 1 and g4[4].id in c4[0].subject, "the latest meeting is told first, even when an older one was seen first hand")
	var r5: Dictionary = MindDialogue.answer_opinion(w4, g4[0], g4[2])
	var c5: Array = r5.facts.filter(func(f): return f.get("kind", "") == "conversation")
	_check(c5.size() == 1 and g4[3].id in c5[0].subject, "and asked again, the older one, rather than nothing")
