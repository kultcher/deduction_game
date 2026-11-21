## An evil Martyr bluff frames a good scapegoat (Michael, Nov 20): it "gives its life over"
## for a good soul under heat, and when they hang, says they must have been evil. It must not
## be loud about pushing that hanging, so it never accuses, nominates or speaks against its
## own chosen. Others may; its frame comes after. Its good self is as reluctant as a real
## Martyr to vote to hang its chosen (Michael, Nov 21).
extends SceneTree
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const MindSupport = preload("res://sim/mind_support.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_accusation()
	_support()
	_nomination()
	_vote()
	_vote_cast()
	print("Martyr bluff stays quiet: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _setup(chosen: bool):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 2
	var e = g.w.npcs.filter(func(m): return m.is_evil() and m.alive and m.id != g.w.demon_id)
	e = e[0] if not e.is_empty() else g.w.demon()
	var sg = g.w.living_good()[0]
	g.w.evil_plan["scapegoat"] = sg.id
	g.w.evil_plan["daily_planter"] = e.id
	g.w.evil_plan["bluffs"][e.id] = "martyr"
	e.claimed_role = "martyr"
	e.info_log = []
	if chosen:
		e.info_log.append({"day": 1, "role": "martyr", "fake": true, "shared": false, "true": false,
			"data": {"target": sg.id, "chosen": true}, "text": "I have given my life over for %s, should the town ever hang them" % sg.name})
	if not g.w.meeting is Dictionary or g.w.meeting.is_empty():
		g.w.meeting = {"nominated": [], "block": "", "block_count": 0, "accusations": []}
	if not g.w.meeting.has("accusations"):
		g.w.meeting["accusations"] = []
	return [g, e, sg]

func _accusation() -> void:
	var p = _setup(true)
	_check(Evil.martyr_bluff_chosen(p[1]) == p[2].id, "the bluff's chosen is read from its made-up Martyr reading")
	var said: int = 0
	for i in 8:
		if MindMeeting._public_accusation(p[0].w, p[1]) != null:
			said += 1
		p[0].w.meeting["accusations"] = []
	_check(said == 0, "a Martyr bluff never accuses its own chosen, even as the scapegoat")
	var q = _setup(false)
	var said_q: int = 0
	for i in 8:
		if MindMeeting._public_accusation(q[0].w, q[1]) != null:
			said_q += 1
		q[0].w.meeting["accusations"] = []
	_check(said_q > 0, "control: without a chosen, the same evil NPC accuses the scapegoat (%d of 8)" % said_q)

func _support() -> void:
	var p = _setup(true)
	var spoke_against: bool = false
	for i in 8:
		var choice: Dictionary = MindSupport.choose(p[0].w, p[1], p[2], {"for_ids": [], "accused": 0, "spoken": [], "case_facts": []})
		if choice.get("side", "") == "against":
			spoke_against = true
	_check(not spoke_against, "nor speaks against its chosen when it's nominated")

func _nomination() -> void:
	var p = _setup(true)
	var named: bool = false
	for i in 8:
		var nm = MindMeeting._evil_nomination(p[0].w, p[1], p[0].w.meeting, "")
		if nm != null and str(nm.get("nominee", "")) == p[2].id:
			named = true
	_check(not named, "and never nominates its chosen")

func _vote() -> void:
	var p = _setup(true)
	var w = p[0].w
	var sh = p[1].shadow
	_check(sh != null, "the bluff has a good self")
	if sh == null:
		return
	sh.role = "martyr"
	sh.pressure = 0.0
	var md = C.role_def("martyr")
	var parts: Dictionary = {}
	md.score_vote_reluctance(w, sh, p[2].id, 0.3, 0.0, parts)
	var real = w.living_good()[1]
	var real_role: String = real.role
	var real_target: String = real.martyr_target
	var real_pressure: float = real.pressure
	real.role = "martyr"
	real.martyr_target = p[2].id
	real.pressure = 0.0
	var real_parts: Dictionary = {}
	md.score_vote_reluctance(w, real, p[2].id, 0.3, 0.0, real_parts)
	real.role = real_role
	real.martyr_target = real_target
	real.pressure = real_pressure
	_check(float(parts.get("martyr_reluctance", 0.0)) < 0.0, "its good self is reluctant to vote to hang its chosen")
	_check(is_equal_approx(float(parts.get("martyr_reluctance", 0.0)), float(real_parts.get("martyr_reluctance", 1.0))), "exactly as reluctant as a real Martyr would be")
	var other: Dictionary = {}
	md.score_vote_reluctance(w, sh, w.living_good()[2].id, 0.3, 0.0, other)
	_check(not other.has("martyr_reluctance"), "and not on anyone else")
	var q = _setup(false)
	if q[1].shadow != null:
		q[1].shadow.role = "martyr"
		var none: Dictionary = {}
		md.score_vote_reluctance(q[0].w, q[1].shadow, q[2].id, 0.3, 0.0, none)
		_check(not none.has("martyr_reluctance"), "control: without a made-up chosen, no reluctance")

## The real vote: with the town and its plan for a hanging, the bluff still votes on its
## chosen as its good self does, and logs why when the two differ.
func _vote_cast() -> void:
	var p = _setup(true)
	var w = p[0].w
	var e = p[1]
	var sg = p[2]
	if e.shadow == null:
		return
	w.begin_meeting()
	e.shadow.role = "martyr"
	e.shadow.suspicion[sg.id] = 0.1
	var nominator: String = w.living_good()[1].id
	var differed: int = 0
	var agreed: int = 0
	for i in 6:
		var log_size: int = w.dlog.entries.size()
		var yes: bool = Mind.vote(w, e, sg.id, nominator, false, "", 0)
		var said: bool = false
		for k in range(log_size, w.dlog.entries.size()):
			if "Martyr bluff: votes on" in str(w.dlog.entries[k].get("reason", "")):
				said = true
		if said:
			differed += 1
			if not yes:
				agreed += 1
	_check(differed > 0, "with the evil side wanting the hanging, the bluff's good self says no (%d of 6)" % differed)
	_check(agreed == differed, "and the bluff votes no with it, every time")
