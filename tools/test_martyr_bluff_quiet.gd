## An evil Martyr bluff frames a good scapegoat (Michael, Nov 20): it "gives its life over"
## for a good soul under heat, and when they hang, says they must have been evil. It must not
## be loud about pushing that hanging, so it never accuses, nominates or speaks against its
## own chosen. Others may; its frame comes after.
extends SceneTree
const Game = preload("res://game/game.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const MindSupport = preload("res://sim/mind_support.gd")
const Evil = preload("res://sim/evil.gd")

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
