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
const MindVote = preload("res://sim/mind_vote.gd")
const Tuning = preload("res://sim/tuning.gd")
const MindPodium = preload("res://sim/mind_podium.gd")
const Gifts = preload("res://sim/gifts.gd")

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
	_playtest_51795()
	_doubtful_friend()
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
	n.workshop_state["confirmed_readings"] = {t.id: _rec("moderate")}
	var r: Dictionary = MindDialogue.answer_opinion(w, n, t)
	_check("readings agree with what I know" in _said(r), "asked about someone whose readings it confirms, it says so (%s)" % _said(r))
	_check(_cards(r).size() == 1 and _cards(r)[0].stance == "for" and _cards(r)[0].subject == [t.id], "and the player gets a card: it speaks up for them")
	n.workshop_state["confirmed_readings"] = {t.id: _rec("small")}
	var r2: Dictionary = MindDialogue.answer_opinion(w, n, t)
	_check(not ("readings agree" in _said(r2)) and _cards(r2).is_empty(), "a small confirmation isn't enough")
	n.workshop_state["confirmed_readings"] = {}
	var r3: Dictionary = MindDialogue.answer_opinion(w, n, t)
	_check(not ("readings agree" in _said(r3)), "no record, no such reason")
	# Evil: only its good self's record counts.
	var e = w.evil_team()[0]
	var tgt = goods[2]
	e.workshop_state["confirmed_readings"] = {tgt.id: _rec("known")}
	if e.shadow != null:
		e.shadow.workshop_state["confirmed_readings"] = {}
		e.shadow.suspicion[tgt.id] = 0.05
	var r4: Dictionary = MindDialogue.answer_opinion(w, e, tgt)
	_check(not ("readings agree" in _said(r4)), "an evil speaker can't say it from a record its good self doesn't hold")
	if e.shadow != null:
		e.shadow.workshop_state["confirmed_readings"] = {tgt.id: _rec("known")}
		var r5: Dictionary = MindDialogue.answer_opinion(w, e, tgt)
		_check("readings agree with what I know" in _said(r5) or not ("I don't take" in _said(r5)), "and says it when its good self's record does hold it, if it clears them (%s)" % _said(r5))

func _vote() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var v = goods[0]
	var t = goods[1]
	v.workshop_state["confirmed_readings"] = {t.id: _rec("known")}
	var res: Dictionary = {"nominee": t.id, "no": [v.id], "yes": [], "voter_parts": {}, "threshold": 6, "count": 0, "by": goods[2].id}
	var lines: Array = MindVote.vote_resistance_lines(w, res)
	var said: String = " ".join(PackedStringArray(lines.map(func(x): return str(x.get("statement", x.get("text", ""))))))
	_check("readings agree with what I know" in said, "after a vote, a no-voter whose record confirms the nominee says so (%s)" % said)
	_check(res.get("resistance_facts", []).size() == 1, "with a card for the player")
	var v2 = goods[3]
	var res2: Dictionary = {"nominee": t.id, "no": [v2.id], "yes": [], "voter_parts": {}, "threshold": 6, "count": 0, "by": goods[2].id}
	v2.workshop_state["confirmed_readings"] = {}
	_check(MindVote.vote_resistance_lines(w, res2).filter(func(x): return "readings agree" in str(x.get("statement", ""))).is_empty(), "no record, nothing said")

## Playtest 51795 (Coroner): whoever is on the block doesn't voice resistance to the
## counter-nomination, a reading naming only me isn't cited for its reader, and a claimant who
## never told a reading of the claimed gift can still be pressed for one.
func _playtest_51795() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var blk = goods[0]
	var t = goods[1]
	blk.workshop_state["confirmed_readings"] = {t.id: _rec("known")}
	var res: Dictionary = {"nominee": t.id, "no": [blk.id], "yes": [], "voter_parts": {}, "threshold": 6, "count": 0, "by": goods[2].id, "prev_block": blk.id}
	var said: Array = MindVote.vote_resistance_lines(w, res)
	res.erase("prev_block")
	var control: Array = MindVote.vote_resistance_lines(w, res)
	_check(said.is_empty() and not control.is_empty(), "the one on the block doesn't speak against the counter-nomination (it would otherwise)")
	# A reading about only the listener confirms what it knows of itself, but isn't kept to cite.
	var l = goods[3]
	var reader = goods[4]
	var card: Dictionary = {"id": "c1", "kind": "report", "source": reader.id, "role": "martyr", "night": 1, "data": {"target": l.id}}
	_check(Gifts.subjects({"role": card["role"], "data": card["data"]}) == [l.id], "a Martyr reading naming only the listener is seen as about it alone, so it isn't cited")
	# The podium: an Archivist claim with no reading behind it can be pressed.
	var c = goods[5]
	c.claim_public = true
	c.claimed_role = "archivist"
	c.info_log = []
	_check(MindPodium.options(w, c)["gift"] == "readings", "a claimant who never told a reading of its gift can be pressed for one")

## A friend of the nominee whose vote sits close to the yes line defends them with doubt, in
## the support turn (Michael, Nov 22: support_doubt_for, Herald's key).
func _doubtful_friend() -> void:
	var w = _world()
	var goods: Array = w.living_good()
	var f = goods[0]
	var t = goods[1]
	if not (t.id in f.friends):
		f.friends.append(t.id)
	var nominator: String = goods[2].id
	w.begin_meeting()
	w.meeting["pending"] = {"nominee": t.id, "by": nominator}
	var MindSupport = load("res://sim/mind_support.gd")
	var rng_before = w.rng.state
	var m0: float = MindVote.dry_margin(w, f, t.id, nominator)
	_check(w.rng.state == rng_before, "the dry run leaves the world's random stream as it was")
	# Find a suspicion that puts it near the line, and one far below.
	var near: float = -1.0
	var far: float = -1.0
	for k in range(0, 101, 2):
		f.suspicion[t.id] = k / 100.0
		var m: float = MindVote.dry_margin(w, f, t.id, nominator)
		if near < 0.0 and absf(m) < Tuning.Meeting.VOTE_RESISTANCE_CLOSE_MARGIN:
			near = k / 100.0
		if far < 0.0 and m < -Tuning.Meeting.VOTE_RESISTANCE_CLOSE_MARGIN:
			far = k / 100.0
	var speak := func(susp: float) -> String:
		f.suspicion[t.id] = susp
		var out: Dictionary = {"lines": [], "facts": [], "speakers": []}
		var ctx: Dictionary = {"for_ids": [], "accused": 0, "spoken": [], "nominator": nominator, "case_facts": []}
		MindSupport._speak(w, f, t, {"move": "vibes", "side": "for"}, ctx, out)
		return " ".join(PackedStringArray(out["lines"].map(func(x): return str(x.get("statement", x.get("text", ""))))))
	_check(near >= 0.0 and "would they?" in speak.call(near), "a friend near the yes line speaks up with doubt (suspicion %.2f, dry margin %.2f)" % [near, m0])
	_check(far >= 0.0 and not ("would they?" in speak.call(far)), "a friend far from it speaks up plainly")
	var unvoiced: Array = []
	for vid in load("res://sim/dialogue_voices.gd").VOICES.keys():
		var said: String = load("res://sim/dialogue.gd").voice_line(vid, "support_doubt_for", "", {"target": t.name})
		if said == "" or not (t.name in said) or "{" in said:
			unvoiced.append(vid)
	_check(unvoiced.is_empty(), "every voice says the doubting defence in its own words, naming the nominee (Herald, Michael's set) %s" % [unvoiced])
	f.friends.erase(t.id)
	_check(near < 0.0 or not ("would they?" in speak.call(near)), "someone who isn't their friend speaks up plainly")
