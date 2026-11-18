## BACKLOG "Saying 'my gift may have been turned'", part (b) (Michael, Nov 17-18): a liar
## boxed in on a publicly claimed gift (a reading held back twice running) drops the reading
## and tells the town its gift may have been turned. Checked here:
##   - Evil._boxed_in_gift_doubt: only for the gift it claimed in public, only where a
##     Poisoner or Delusional could be in play, at most once a game, logged with a reason;
##   - MindMeeting._say_gift_doubt: the line is said once, with a public self_doubt event,
##     and the reveal lists it as a lie;
##   - SourceDoubt.derive: a listener who hears it doubts all of that teller's readings
##     (honest doubt, "teller:*"), less the more it suspects the teller; not its own line.
extends SceneTree

const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const Shared = preload("res://workshop/shared_ledger.gd")
const Bridge = preload("res://game/workshop_bridge.gd")
const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Tuning = preload("res://sim/tuning.gd")

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
	_listener()
	_retracted_gravedigger()
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
	check(facts.is_empty(), "no new card: listeners hear it through the public record (Lantern)")
	check(w.public_log.size() == events_before + 1 and w.public_log[-1].get("kind", "") == "self_doubt" and w.public_log[-1].get("by", "") == m.id, "a public self_doubt event by the teller")
	var lied: Array = w.dlog.entries.filter(func(e): return e["type"] == "think" and e["data"].get("topic", "") == "lie" and e["actor"] == m.id and "have been turned" in str(e["reason"]))
	check(lied.size() == 1, "the reveal lists it as a lie, with its reason")
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


func _doubt(g, l) -> Dictionary:
	var input: Dictionary = Bridge.capture(g, [], l.id, "private", l)
	var plan: Dictionary = Shared.prepare(input, {}, l.ledger, {}, [])
	check(plan.get("ready", false), "the listener's plan prepares (%s)" % str(plan.get("issues", [])))
	return SourceDoubt.derive(plan, l.ledger)


func _listener() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	var w = g.w
	var m = _liar(g)
	var l = w.living().filter(func(n): return not n.is_evil())[0]
	var key: String = m.id + ":*"
	var before: Dictionary = _doubt(g, l)
	check(float(before.honest.get(key, 0.0)) == 0.0, "before the line: no honest doubt about the teller")
	w.public_event("self_doubt", [m.id], m.id, {"role": "seer"})
	l.suspicion[m.id] = 0.0
	var after: Dictionary = _doubt(g, l)
	var full: float = float(after.honest.get(key, 0.0))
	check(is_equal_approx(full, Tuning.Workshop.DOUBT_ARG_UNRELIABLE_SCALE), "a trusted teller's line: all its readings doubted at an unreliable argument's scale (%.2f)" % full)
	check(is_equal_approx(float(after.pre_eval.get(key, 0.0)), full), "in pre_eval too")
	check(SourceDoubt.lookup(after.honest, m.id, 2) == full, "it reaches every night's reading")
	l.suspicion[m.id] = 0.8
	var half: float = float(_doubt(g, l).honest.get(key, 0.0))
	check(half < full and is_equal_approx(half, full * 0.2), "a suspected teller is believed less (%.2f)" % half)
	var own: Dictionary = _doubt(g, m)
	check(float(own.honest.get(key, 0.0)) == 0.0, "the teller's own line doesn't count for itself")


## Codex on #245: a trusted Gravedigger's report that the hanged one was good settles them
## as sincere; once the Gravedigger says its gift may have been turned, that report proves
## only as much as is still credited, below the bar.
func _retracted_gravedigger() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	var w = g.w
	# The listener isn't a Gravedigger itself, or every Gravedigger report would be a caught lie.
	var goods: Array = w.living().filter(func(n): return not n.is_evil() and n.role != "gravedigger")
	var l = goods[0]
	var settled := func(gd, ex, with_line: bool) -> bool:
		var input: Dictionary = Bridge.capture(g, [], l.id, "private", l)
		var plan: Dictionary = Shared.prepare(input, {}, l.ledger, {}, [])
		if not plan.get("ready", false):
			return false
		# No real hanging stands behind this made-up report: without the timeline, pass 1
		# doesn't check it, so this isolates pass 2's proof.
		plan.prepared.view.erase("timeline")
		plan.prepared.view.cards.append({"id": "gdtest", "kind": "report", "role": "gravedigger", "source": gd.id, "night": 1,
			"data": {"executed": ex.id, "role": ex.role}, "subjects": [ex.id]})
		plan.prepared.listener["npc_trust"] = {gd.id: 0.8}
		plan.prepared.listener["suspicion"] = {gd.id: 0.0}
		if with_line:
			plan.input.public_events = plan.input.get("public_events", []) + [{"kind": "self_doubt", "subjects": [gd.id], "by": gd.id}]
		return SourceDoubt.derive(plan, l.ledger).settled_sincere.has(ex.id)
	# A teller and a hanged one this listener has no other doubt about.
	var pair: Array = []
	for gd in goods.slice(1):
		for ex in goods.slice(1):
			if ex != gd and pair.is_empty() and settled.call(gd, ex, false):
				pair = [gd, ex]
	check(not pair.is_empty(), "a trusted Gravedigger's 'they were good' settles the hanged one as sincere")
	if not pair.is_empty():
		check(not settled.call(pair[0], pair[1], true), "after it says its gift may have been turned, the same report doesn't (Codex on #245)")
