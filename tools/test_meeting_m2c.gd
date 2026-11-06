## Meeting plan M2c (docs/meeting_flow_plan.md section 3, Step 4): supporters.
##   - The weighing reproduces the plan's examples: an unclaimed Clerk reveals to keep a
##     Seer off the block; a Seer holding a "no" on a spent Clerk usually keeps quiet; once
##     a trusted voice has cleared the nominee, the next holder keeps their cover.
##   - At most MAX_SUPPORTERS_SHOWN speak; never the nominee, the nominator or the silenced.
##   - Supporters speak once per nomination, before the player's statement or vote.
##   - Voices raised for someone take a little of the town's pressure back.
##   - Evil supporters never come out with their real role.
extends SceneTree

const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")
const Game = preload("res://game/game.gd")
const MindSupport = preload("res://sim/mind_support.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_test_weighing()
	_test_flow()
	_test_sample()
	_test_consensus()
	print("Meeting M2c: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _meeting_game(sd: int, day: int = 2):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 7)
	if g.state == "approach":
		g.command("decline")
	g.w.day = day
	g.w.phase = C.EVENING
	g.stream_meeting = false
	g._start_meeting()
	return g


func _total(parts: Dictionary) -> float:
	var t: float = 0.0
	for k in parts:
		t += float(parts[k])
	return t


## Two good townsfolk: s weighing whether to clear d.
func _pair(g, s_role: String, d_role: String):
	var good: Array = g.w.living().filter(func(n): return not n.is_evil())
	var s = good[0]
	var d = good[1]
	s.role = s_role
	s.claim_public = false
	s.claimed_role = ""
	d.role = d_role
	d.claim_public = true
	d.claimed_role = d_role
	s.suspicion[d.id] = -0.3
	s.npc_trust[d.id] = 0.65
	s.traits["privacy"] = 0.5
	return [s, d]


func _test_weighing() -> void:
	var g = _meeting_game(9101)
	var ctx: Dictionary = {"for_ids": [], "accused": 0, "spoken": [], "case_facts": []}
	var p = _pair(g, "clerk", "seer")
	var s = p[0]
	var d = p[1]
	var dang: float = MindSupport.danger(g.w, s, d, ctx)
	_check(dang > 0.9, "with nobody else on the block, the nominee is in full danger (%.2f)" % dang)
	var clerk_for_seer: float = _total(MindSupport.exonerate_parts(g.w, s, d, true, dang))
	var g2 = _meeting_game(9101)
	var p2 = _pair(g2, "seer", "clerk")
	var seer_for_clerk: float = _total(MindSupport.exonerate_parts(g2.w, p2[0], p2[1], true, MindSupport.danger(g2.w, p2[0], p2[1], ctx)))
	_check(clerk_for_seer > 0.0, "an unclaimed Clerk who read a Seer as good leans to reveal (%.2f)" % clerk_for_seer)
	_check(seer_for_clerk < 0.0 and seer_for_clerk < clerk_for_seer, "a Seer with a 'no' on a spent Clerk usually keeps quiet (%.2f, the Clerk for a Seer %.2f)" % [seer_for_clerk, clerk_for_seer])
	# A trusted voice has already cleared them: the danger drops, and with it the urge to burn cover.
	var friend = g.w.living().filter(func(n): return n != s and n != d)[0]
	s.npc_trust[friend.id] = 0.9
	var ctx2: Dictionary = {"for_ids": [friend.id], "accused": 0, "spoken": [friend.id], "case_facts": []}
	var dang2: float = MindSupport.danger(g.w, s, d, ctx2)
	var after: float = _total(MindSupport.exonerate_parts(g.w, s, d, true, dang2))
	_check(dang2 < dang and after < clerk_for_seer, "after a trusted bystander clears the nominee, the next holder has less reason to reveal (danger %.2f -> %.2f)" % [dang, dang2])
	# What the nominee's role is worth, as the bystander believes it.
	var pv_seer: Dictionary = MindSupport.protect_value(g.w, s, d)
	d.claimed_role = "clerk"
	var pv_clerk: Dictionary = MindSupport.protect_value(g.w, s, d)
	_check(_total(pv_seer) > _total(pv_clerk), "an ongoing gift is worth more to protect than a spent one-shot gift")
	d.claim_public = false
	d.claimed_role = ""
	_check(MindSupport.protect_value(g.w, s, d).has("unknown_role"), "an unknown role gets the unknown-role value")


func _unclaimed(g) -> Array:
	return g.w.living().filter(func(n): return not n.silenced and g.w.can_nominate("player", n.id) == "")


func _test_flow() -> void:
	var g = _meeting_game(9201)
	var t = _unclaimed(g)[0]
	g.command("nominate %s raw" % t.name.to_lower())
	_check(not g.w.meeting.pending.get("supporters_done", false), "supporters wait until the press is settled")
	g.command("press skip")
	_check(g.w.meeting.pending.get("supporters_done", false), "skipping the press hands the floor to the supporters")
	var g2 = _meeting_game(9202)
	var t2 = _unclaimed(g2)[0]
	g2.command("nominate %s raw" % t2.name.to_lower())
	g2.command("accuse")
	_check(g2.w.meeting.pending.get("supporters_done", false) and g2.w.meeting.pending.get("statement", "") == "accuse",
		"a statement made straight away comes after the supporters have had their say")
	var before: int = g2.w.dlog.entries.filter(func(e): return e.get("type", "") == "support_offer").size()
	g2.command("vote no")
	var after: int = g2.w.dlog.entries.filter(func(e): return e.get("type", "") == "support_offer").size()
	_check(after == before, "supporters speak once per nomination")


func _test_sample() -> void:
	var speakers_total: int = 0
	var over_cap: bool = false
	var bad_speaker: bool = false
	var evil_true_role: bool = false
	var nominations: int = 0
	for sd in range(9300, 9330):
		var g = _meeting_game(sd, 2 + sd % 2)
		var cands: Array = _unclaimed(g)
		if cands.is_empty():
			continue
		var t = cands[sd % cands.size()]
		var silenced = g.w.living().filter(func(n): return n != t)[0]
		silenced.silenced = true
		g.command("nominate %s raw" % t.name.to_lower())
		g.command("press skip")
		nominations += 1
		var sp: Array = g.w.meeting.pending.get("supporters", [])
		speakers_total += sp.size()
		if sp.size() > Tuning.Meeting.MAX_SUPPORTERS_SHOWN:
			over_cap = true
		for x in sp:
			if x.id == t.id or x.id == silenced.id or x.id == "player":
				bad_speaker = true
			var n = g.w.by_id[x.id]
			if n.is_evil() and n.claim_public and n.claimed_role == n.role:
				evil_true_role = true
	_check(nominations >= 20, "the sample ran (%d nominations)" % nominations)
	_check(not over_cap, "never more than %d supporters" % Tuning.Meeting.MAX_SUPPORTERS_SHOWN)
	_check(not bad_speaker, "the nominee, the nominator and the silenced never speak as supporters")
	_check(not evil_true_role, "an evil supporter never comes out with its real role")
	_check(speakers_total > 0, "bystanders do speak (%d over %d nominations)" % [speakers_total, nominations])


func _test_consensus() -> void:
	var g = _meeting_game(9401)
	var people: Array = g.w.living().filter(func(n): return not n.is_evil())
	var l = people[0]
	var d = people[1]
	var a = people[2]
	var b = people[3]
	l.suspicion[d.id] = 0.2
	g.w.stances[a.id] = {"target": d.id, "day": g.w.day, "hint": false}
	MindMeeting.refresh_consensus(g.w, l, d.id)
	var against: float = float(l.consensus_pressure.get(d.id, 0.0))
	g.w.defences[b.id] = {"target": d.id, "day": g.w.day}
	MindMeeting.refresh_consensus(g.w, l, d.id)
	var with_defence: float = float(l.consensus_pressure.get(d.id, 0.0))
	_check(against > 0.0 and with_defence < against and with_defence >= 0.0,
		"a voice raised for them takes a little of the town's pressure back (%.3f -> %.3f)" % [against, with_defence])
