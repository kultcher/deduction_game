## "My gift may have been turned", the good side (BACKLOG, Michael, Nov 17-18): a good public
## claimant whose own doubt about a night of its readings reaches Meeting.GIFT_DOUBT_SAY (25%)
## tells the town so, once a game, with the approved line; below it, or in private, it doesn't;
## an evil NPC never takes this route (its own is the boxed-in bluff).
extends SceneTree
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
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
	print("Good gift doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## A good NPC with a reading gift, out in public, holding the given doubt about night 1.
func _claimant(doubt: float, public: bool = true):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9701, 10)
	var w = g.w
	w.day = 2
	var n = null
	for m in w.living_good():
		if C.has_readings(m.role):
			n = m
			break
	if n == null:
		return null
	n.claimed_role = n.role
	n.claim_public = public
	n.gift_doubt = {}
	n.workshop_state["self_doubt"] = {1: doubt}
	return {"w": w, "n": n}

func _said(lines: Array) -> bool:
	return lines.any(func(x): return "gift" in str(x.get("text", "")).to_lower() or "reading" in str(x.get("text", "")).to_lower())

func _cases() -> void:
	var at: float = Tuning.Meeting.GIFT_DOUBT_SAY
	var s = _claimant(at + 0.01)
	_check(s != null, "a good reader to test")
	if s == null:
		return
	var lines: Array = []
	MindMeeting._say_gift_doubt(s.w, s.n, lines, [])
	_check(lines.size() == 1 and _said(lines), "at %d%% doubt, it tells the town its gift may have been turned (%s)" % [int(round((at + 0.01) * 100)), str(lines)])
	_check(s.n.gift_doubt.has("said") and int(s.n.gift_doubt.get("night", -9)) == 1, "logged with the night it doubts")
	_check(s.w.public_log.any(func(e): return e.kind == "self_doubt" and e.by == s.n.id), "and it reaches the public record, where listeners weigh it")
	var again: Array = []
	s.n.workshop_state["self_doubt"] = {1: 0.9}
	MindMeeting._say_gift_doubt(s.w, s.n, again, [])
	_check(again.is_empty(), "once a game")
	var low = _claimant(at - 0.01)
	var low_lines: Array = []
	MindMeeting._say_gift_doubt(low.w, low.n, low_lines, [])
	_check(low_lines.is_empty() and low.n.gift_doubt.is_empty(), "below %d%%, nothing" % int(round(at * 100)))
	var priv = _claimant(0.6, false)
	var priv_lines: Array = []
	MindMeeting._say_gift_doubt(priv.w, priv.n, priv_lines, [])
	_check(priv_lines.is_empty() and priv.n.gift_doubt.is_empty(), "not for a gift it hasn't claimed in public")
	var whole = _claimant(0.0)
	whole.n.workshop_state["self_doubt"] = {-1: 0.4}
	var whole_lines: Array = []
	MindMeeting._say_gift_doubt(whole.w, whole.n, whole_lines, [])
	_check(whole_lines.size() == 1 and "all its readings" in str(whole.n.gift_doubt.get("why", "")), "a doubt about all its readings (the Delusional one) counts too")
	# An evil NPC doesn't take the good route, however much doubt is recorded for it.
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9701, 10)
	var e = g.w.evil_team()[0]
	e.claim_public = true
	e.claimed_role = e.role
	e.gift_doubt = {}
	e.workshop_state["self_doubt"] = {1: 0.9}
	MindMeeting._good_gift_doubt(g.w, e)
	_check(e.gift_doubt.is_empty(), "an evil NPC never takes the good route")
