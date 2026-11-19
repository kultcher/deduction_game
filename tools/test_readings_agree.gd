## "Their readings agree with what I know" (Michael, Nov 19), from the record of confirming
## readings (tools/test_reading_trust.gd):
## - asked about someone, a speaker holding a moderate or known confirmation of their readings
##   gives it as the reason for clearing them, and the player gets a "speaks up for" card;
## - a small confirmation isn't enough, and nobody says it without a record;
## - after a vote, a no-voter with such a record says it, ahead of the generic reasons;
## - an evil speaker says it only from its good self's record.
extends SceneTree
const Game = preload("res://game/game.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_opinion()
	_vote()
	print("Readings agree: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _world():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9861, 10)
	g.w.day = 2
	return g.w

func _rec(tier: String) -> Dictionary:
	return {"tier": tier, "card": "card:test", "day": 1, "source": "belief", "agreement": 0.9}

func _said(r: Dictionary) -> String:
	return " ".join(PackedStringArray(r.lines.map(func(x): return str(x.get("statement", x.get("text", ""))))))

func _cards(r: Dictionary) -> Array:
	return r.facts.filter(func(f): return f.get("reason", "") == "readings_agree")

func _opinion() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var n = goods[0]
	var t = goods[1]
	n.suspicion[t.id] = 0.05
	n.friends = []
	n.rivals = []
	n.npc_trust[t.id] = 0.5
	n.dialogue_memory["confirmed_readings"] = {t.id: _rec("moderate")}
	var r: Dictionary = MindDialogue.answer_opinion(w, n, t)
	_check("readings agree with what I know" in _said(r), "asked about someone whose readings it confirms, it says so (%s)" % _said(r))
	_check(_cards(r).size() == 1 and _cards(r)[0].stance == "for" and _cards(r)[0].subject == [t.id], "and the player gets a card: it speaks up for them")
	n.dialogue_memory["confirmed_readings"] = {t.id: _rec("small")}
	var r2: Dictionary = MindDialogue.answer_opinion(w, n, t)
	_check(not ("readings agree" in _said(r2)) and _cards(r2).is_empty(), "a small confirmation isn't enough")
	n.dialogue_memory["confirmed_readings"] = {}
	var r3: Dictionary = MindDialogue.answer_opinion(w, n, t)
	_check(not ("readings agree" in _said(r3)), "no record, no such reason")
	# Evil: only its good self's record counts.
	var e = w.evil_team()[0]
	var tgt = goods[2]
	e.dialogue_memory["confirmed_readings"] = {tgt.id: _rec("known")}
	if e.shadow != null:
		e.shadow.dialogue_memory["confirmed_readings"] = {}
		e.shadow.suspicion[tgt.id] = 0.05
	var r4: Dictionary = MindDialogue.answer_opinion(w, e, tgt)
	_check(not ("readings agree" in _said(r4)), "an evil speaker can't say it from a record its good self doesn't hold")
	if e.shadow != null:
		e.shadow.dialogue_memory["confirmed_readings"] = {tgt.id: _rec("known")}
		var r5: Dictionary = MindDialogue.answer_opinion(w, e, tgt)
		_check("readings agree with what I know" in _said(r5) or not ("I don't take" in _said(r5)), "and says it when its good self's record does hold it, if it clears them (%s)" % _said(r5))

func _vote() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var v = goods[0]
	var t = goods[1]
	v.dialogue_memory["confirmed_readings"] = {t.id: _rec("known")}
	var res: Dictionary = {"nominee": t.id, "no": [v.id], "yes": [], "voter_parts": {}, "threshold": 6, "count": 0, "by": goods[2].id}
	var lines: Array = MindMeeting.vote_resistance_lines(w, res)
	var said: String = " ".join(PackedStringArray(lines.map(func(x): return str(x.get("statement", x.get("text", ""))))))
	_check("readings agree with what I know" in said, "after a vote, a no-voter whose record confirms the nominee says so (%s)" % said)
	_check(res.get("resistance_facts", []).size() == 1, "with a card for the player")
	var v2 = goods[3]
	var res2: Dictionary = {"nominee": t.id, "no": [v2.id], "yes": [], "voter_parts": {}, "threshold": 6, "count": 0, "by": goods[2].id}
	v2.dialogue_memory["confirmed_readings"] = {}
	_check(MindMeeting.vote_resistance_lines(w, res2).filter(func(x): return "readings agree" in str(x.get("statement", ""))).is_empty(), "no record, nothing said")
