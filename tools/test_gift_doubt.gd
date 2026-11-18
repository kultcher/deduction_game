## BACKLOG "Saying 'my gift may have been turned'", part (b) (Michael, Nov 17-18): a liar
## boxed in on a publicly claimed gift (a reading held back twice running) drops the reading
## and tells the town its gift may have been turned. Checked here:
##   - Evil._boxed_in_gift_doubt: only for the gift it claimed in public, only where a
##     Poisoner or Delusional could be in play, at most once a game, logged with a reason;
##   - MindMeeting._say_gift_doubt: the line is said once, with a self_doubt card and a
##     public event, and the reveal lists it as a lie.
extends SceneTree

const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_trigger()
	_gate()
	print("Gift doubt: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


class FakeScript:
	var minions: Array = []
	var secrets: Array = []


func _liar(g):
	var m = g.w.evil_team().filter(func(n): return g.w.evil_plan.get("bluffs", {}).has(n.id))[0]
	return m


func _trigger() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	var w = g.w
	var fs := FakeScript.new()
	fs.minions = ["poisoner"]
	w.case_script = fs
	var m = _liar(g)
	var role: String = w.evil_plan["bluffs"][m.id]
	var entry: Dictionary = {"role": role, "day": w.day, "text": "x", "data": {}}
	check(not Evil._boxed_in_gift_doubt(w, m, entry), "not claimed in public: keeps holding instead")
	m.claimed_role = role
	m.claim_public = true
	check(not Evil._boxed_in_gift_doubt(w, m, {"role": "other_gift", "day": w.day}), "a reading of a gift it didn't claim: no")
	check(Evil._boxed_in_gift_doubt(w, m, entry), "claimed in public and boxed in: drops it for the excuse")
	check(str(m.gift_doubt.get("role", "")) == role and str(m.gift_doubt.get("why", "")) != "", "the excuse waits with its gift and a reason")
	check(not Evil._boxed_in_gift_doubt(w, m, entry), "at most once a game")
	var lines: Array = []
	var facts: Array = []
	var events_before: int = w.public_log.size()
	MindMeeting._say_gift_doubt(w, m, lines, facts)
	check(lines.size() == 1, "says the line once (%s)" % str(lines.map(func(l): return l.get("text", ""))))
	check(facts.size() == 1 and facts[0].get("kind", "") == "self_doubt" and facts[0].get("source", "") == m.id and facts[0].get("role", "") == role,
		"leaves a self_doubt card from the teller about its gift")
	check(w.public_log.size() == events_before + 1 and w.public_log[-1].get("kind", "") == "self_doubt", "and a public event")
	var lied: Array = w.dlog.entries.filter(func(e): return e["type"] == "think" and e["data"].get("topic", "") == "lie" and e["actor"] == m.id and "may have been turned" in str(e["reason"]))
	check(lied.size() == 1, "the reveal lists it as a lie, with its reason")
	# The card reaches the case board and the Workshop's evidence without trouble.
	var before: int = g.board.size()
	g._facts(facts)
	check(g.board.size() == before + 1, "the card goes on the case board")
	var Evidence = load("res://workshop/live_evidence.gd")
	var norm: Dictionary = Evidence.normalize_card(g.board[-1])
	check(not norm.is_empty() and str(norm.get("source", "")) == m.id, "and normalizes as the teller's card (%s)" % str(norm.get("kind", "")))
	lines.clear()
	facts.clear()
	MindMeeting._say_gift_doubt(w, m, lines, facts)
	check(lines.is_empty() and facts.is_empty(), "said once only")


func _gate() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	var w = g.w
	var fs := FakeScript.new()
	w.case_script = fs
	fs.minions = ["spy"]
	fs.secrets = ["marked"]
	check(not Evil.gift_turn_possible(w), "no Poisoner and no Delusional: no turned gift to blame")
	var m = _liar(g)
	var role: String = w.evil_plan["bluffs"][m.id]
	m.claimed_role = role
	m.claim_public = true
	check(not Evil._boxed_in_gift_doubt(w, m, {"role": role, "day": w.day}), "so the liar keeps holding instead")
	fs.secrets = ["delusional"]
	check(Evil.gift_turn_possible(w), "Delusional on the script is enough")
	fs.secrets = []
	fs.minions = ["poisoner"]
	check(Evil.gift_turn_possible(w), "and so is a Poisoner")
