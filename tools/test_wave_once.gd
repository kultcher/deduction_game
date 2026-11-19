## An NPC never waves the player down twice with the same news (Michael, Nov 19): every reading
## an approach was about is marked, so a reading held back from the answer (told_readings didn't
## move) can't bring them back with the same information; a new reading can.
extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9881, 10)
	var w = g.w
	w.day = 2
	var n = w.living_good()[0]
	for x in w.living():
		if x != n:
			x.silenced = true  # only n can approach
	n.silenced = false
	n.working = false
	n.busy_with = ""
	n.trust = 0.9
	n.traits["privacy"] = 0.0
	n.traits["gossip"] = 0.0
	n.info_log = [{"day": 1, "role": n.role, "data": {}, "text": "a reading", "shared": false}]
	n.told_readings = 0
	var before: int = _approaches(w, n)
	_check(before > 0, "with a reading the player hasn't heard, they come with news (%d of 40 phases)" % before)
	Social.approach_open(w, n, "news")
	n.told_readings = 0  # as if the answer held the reading back
	_check(_approaches(w, n) == 0, "after approaching about it, never again for the same reading, even if they held it back")
	n.info_log.append({"day": 2, "role": n.role, "data": {}, "text": "a new reading", "shared": false})
	_check(_approaches(w, n) > 0, "a new reading brings them back")
	print("Wave once: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _approaches(w, n) -> int:
	var c := 0
	for k in range(40):
		var r = Social.approach_candidate(w)
		if r != null and r.npc == n and r.agenda == "news":
			c += 1
	return c
