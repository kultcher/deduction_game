## BACKLOG "Lie severity", the vote side (Michael, Nov 17; Quill's judge side is #210). Since
## #210 a caught "I was home" is evidence, not proof, so a listener can believe the lie and
## still vote no. Checked here:
##   - `MindMeeting.catches_home_lie`: a case's own "home" for a night plus something that puts
##     them out that night, by the judge's own dispute rule;
##   - a voter who accepted such a case and voted no says they believe the lie but won't hang
##     for it, ahead of the generic "not enough" line, and even when the miss wasn't close.
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Presentation = preload("res://game/workshop_presentation.gd")
const Evidence = preload("res://workshop/live_evidence.gd")
const LiveCanvas = preload("res://game/workshop_canvas.gd")
const Canvas = preload("res://workshop/canvas_model.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_catches_home_lie()
	_voter_says_lie_not_rope()
	_presented_case_records_the_lie()
	print("Lie severity votes: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _card(id: String, kind: String, extra: Dictionary) -> Dictionary:
	var c: Dictionary = {"id": id, "fact_id": id, "kind": kind, "source": "player", "subject": "a", "subjects": ["a"], "night": 1,
		"block": "docks", "data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	return c.merged(extra, true)


func _catches_home_lie() -> void:
	var own: Dictionary = _card("own", "alibi", {"source": "a", "block": "hill"})
	var seen: Dictionary = _card("s1", "sighting", {})
	var seen_n2: Dictionary = _card("s2", "sighting", {"night": 2, "observed_at": {"day": 2, "phase": "night"}})
	var other: Dictionary = _card("s3", "sighting", {"subject": "b", "subjects": ["b"]})
	var walk: Dictionary = _card("r1", "report", {"source": "a", "role": "lamplighter", "data": {"count": 1}})
	var view: Dictionary = {"cards": [own, seen, seen_n2, other, walk]}
	check(MindMeeting.catches_home_lie(view, ["own", "s1"], "a"), "'home' and a sighting of them out that night: a caught home lie")
	check(not MindMeeting.catches_home_lie(view, ["own", "s2"], "a"), "a sighting on another night doesn't catch it")
	check(not MindMeeting.catches_home_lie(view, ["own", "s3"], "a"), "a sighting of someone else doesn't catch it")
	check(not MindMeeting.catches_home_lie(view, ["s1"], "a"), "a sighting with no 'home' on record isn't a lie")
	check(MindMeeting.catches_home_lie(view, ["own", "r1"], "a"), "'home' and their own walking gift's reading that night: caught")
	check(not MindMeeting.catches_home_lie(view, ["own", "s1"], "b"), "only the case's target counts")


## A synthetic tally, as test_meeting_m2d builds it: v accepted the player's case against t
## today and voted no.
func _res(g, v, t, vp: Dictionary, home_lie: bool, block: String = "") -> Dictionary:
	v.dialogue_memory["accepted_cases"] = {t.id: {"day": g.w.day, "key": "test"}}
	v.dialogue_memory["granted_lies"] = {t.id: {"day": g.w.day}} if home_lie else {}
	return {"nominee": t.id, "by": "player", "yes": [], "no": [v.id], "count": 1, "threshold": 4, "outcome": "fails",
		"prev_block": block, "prev_block_count": 4 if block != "" else 0, "voter_parts": {v.id: vp}}


func _said(lines: Array) -> String:
	return " ".join(PackedStringArray(lines.map(func(l): return str(l.get("statement", l.get("text", ""))))))


func _voter_says_lie_not_rope() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 7)
	if g.state == "approach":
		g.command("decline")
	g.w.day = 2
	g.w.phase = C.EVENING
	g.stream_meeting = false
	g._start_meeting()
	var good: Array = g.w.living().filter(func(n): return not n.is_evil())
	var v = good[0]
	var t = good[1]
	var blk = good[2]
	var near: Dictionary = {"parts": {}, "margin": -0.1, "yes": false}
	var far: Dictionary = {"parts": {}, "margin": -1.5, "yes": false}
	var lines: Array = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, near, true))
	check(lines.size() == 1 and "lied about where they were" in _said(lines) and t.name in _said(lines),
		"accepted a case that caught a home lie, voted no: says they believe the lie but won't hang (%s)" % _said(lines))
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, far, true))
	check(lines.size() == 1 and "lied about where they were" in _said(lines), "said even when the miss wasn't close")
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, near, false))
	check(lines.size() == 1 and not ("lied about" in _said(lines)), "a case with no caught lie keeps the usual line (%s)" % _said(lines))
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, far, false))
	check(lines.is_empty(), "no caught lie and no close miss: still unexplained")
	lines = MindMeeting.vote_resistance_lines(g.w, _res(g, v, t, {"parts": {"prefers_block": -0.4}, "margin": -0.2, "yes": false}, true, blk.id))
	check(lines.size() == 1 and blk.name in _said(lines), "preferring the one on the block still comes first")
	# Granted the lie (took the case partly) but didn't accept the case: still says so.
	v.dialogue_memory["accepted_cases"] = {}
	v.dialogue_memory["granted_lies"] = {t.id: {"day": g.w.day}}
	var only_lie: Dictionary = {"nominee": t.id, "by": "player", "yes": [], "no": [v.id], "count": 1, "threshold": 4,
		"outcome": "fails", "prev_block": "", "prev_block_count": 0, "voter_parts": {v.id: far}}
	lines = MindMeeting.vote_resistance_lines(g.w, only_lie)
	check(lines.size() == 1 and "lied about where they were" in _said(lines), "granted the lie without accepting the case: still says it")
	v.dialogue_memory["granted_lies"] = {t.id: {"day": g.w.day - 1}}
	check(MindMeeting.vote_resistance_lines(g.w, only_lie).is_empty(), "a lie granted on an earlier day doesn't count")


## The real path: the player files "home, and seen out that night" against t and presents it
## at the meeting; a listener who accepts it records that the case caught a home lie. The
## same case without the "home" card records none. Setup as test_workshop_presentation's
## _trapped_group_response.
func _presented_case_records_the_lie() -> void:
	var counts: Dictionary = {}
	for with_alibi in [true, false]:
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(692, 7)
		for p in g.w.npcs:
			p.workshop_state = {"reasoning_mode": "full", "confidence_mode": "scale"}
			p.info_log = []
			p.known_claims = {}
			p.beliefs = []
			p.ledger = {}
			p.trust = 0.7
			p.trust_at_reconsider = 0.7
			for id in p.suspicion:
				p.suspicion[id] = 0.3
				p.npc_trust[id] = 1.0
		var t = g.w.living_good()[0]
		var block = "market" if t.home_block != "market" else "docks"
		t.history[g.w.time_key(1, 3)] = "night:" + block
		var canvas = Canvas.new(LiveCanvas.view(g))
		var root: String = canvas.add_premise(t.id, "evil", Vector2.ZERO)
		var sight = g.add_card({"kind": "sighting", "subject": [t.id], "source": "player", "day": 1, "phase": 3, "block": block, "text": "Seen away from home."})
		var b: String = "e:" + Evidence.normalize_card(g.board[sight - 1]).id
		if with_alibi:
			var alibi = g.add_card({"kind": "alibi", "subject": [t.id], "source": t.id, "day": 1, "phase": 3, "home": true, "text": "I stayed home."})
			canvas = Canvas.new(LiveCanvas.view(g))
			root = canvas.add_premise(t.id, "evil", Vector2.ZERO)
			var a: String = "e:" + Evidence.normalize_card(g.board[alibi - 1]).id
			canvas.connect_cards(a, b)
			canvas.connect_cards(canvas.selected, root)
		else:
			canvas = Canvas.new(LiveCanvas.view(g))
			root = canvas.add_premise(t.id, "evil", Vector2.ZERO)
			canvas.connect_cards(b, root)
		var number: int = LiveCanvas.file(g, canvas.compile(root))
		check(number > 0, "the case can be filed (home alibi: %s)" % str(with_alibi))
		if number <= 0:
			continue
		var granted: int = 0
		var flagged: int = 0
		for l in g.w.living().filter(func(p): return p != t):
			var r: Dictionary = Presentation.present(g, l, g.board[number - 1], [t.id], "accuse", "meeting", false)
			if str(r.get("dialogue", {}).get("stance", "")) in ["accept", "partial"]:
				granted += 1
			if not l.dialogue_memory.get("granted_lies", {}).get(t.id, {}).is_empty():
				flagged += 1
		counts[with_alibi] = [granted, flagged]
	print("  granted (accept or partial) / recorded a lie: with home alibi %s; sighting only %s" % [str(counts.get(true)), str(counts.get(false))])
	check(counts.has(true) and counts[true][0] > 0, "some listener grants the caught-lie case")
	check(counts.has(true) and counts[true][1] == counts[true][0], "every listener who grants it records the home lie")
	check(counts.has(false) and counts[false][1] == 0, "a sighting with no 'home' records no lie")
