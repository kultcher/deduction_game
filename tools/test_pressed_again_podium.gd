## Caught out and pressed again, at the podium (Michael, Nov 20 plan: the same ladder, private
## first, then the podium). The player pressing a nominee with a card about a night:
##   - counts as a press of that night, shared with the private ladder;
##   - each earlier press makes owning up to the reason likelier (a known burden's walk here);
##   - the truly home, pressed again, trust the Demonologist less;
##   - evil that owned the night with nothing to tell may back into a spare walking gift, and
##     claims it before the town.
##   godot --headless --path . --script res://tools/test_pressed_again_podium.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Podium = preload("res://sim/mind_podium.gd")
const Press = preload("res://sim/mind_press.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _world(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 10)
	g.w.day = 3
	return g.w

func _card(w, d, night: int, block: String) -> Dictionary:
	var src = w.living().filter(func(m): return m != d)[0]
	return {"kind": "sighting", "day": night, "phase": C.NIGHT, "block": block, "source": src.id, "subject": [d.id], "text": "seen"}

func _init() -> void:
	# A press at the podium counts, and the private ladder sees it.
	var w0 = _world(7000)
	var d0 = w0.living_good()[0]
	d0.history[w0.time_key(1, C.NIGHT)] = "home:" + d0.home_block
	Podium.press_card(w0, d0, _card(w0, d0, 1, d0.home_block), true)
	_check(Press.press_count(d0, 1) == 1, "a card press at the podium counts as a press of that night, shared with the private ladder")
	# Truly home, pressed again before the town: trust drops; the first press, not.
	var w1 = _world(7001)
	var d1 = w1.living_good()[0]
	d1.history[w1.time_key(1, C.NIGHT)] = "home:" + d1.home_block
	d1.trust = 0.6
	Podium.press_card(w1, d1, _card(w1, d1, 1, d1.home_block), true)
	var after_first: float = d1.trust
	Podium.press_card(w1, d1, _card(w1, d1, 1, d1.home_block), true)
	_check(after_first >= 0.6 - 0.0001 and d1.trust < after_first, "truly home, the first press costs nothing extra; pressed again, it trusts the Demonologist less")
	# One count across venues (Codex on #580): pressed in private first, then at the podium; and
	# the other way round.
	var w2 = _world(7002)
	var d2 = w2.living_good()[0]
	d2.history[w2.time_key(1, C.NIGHT)] = "home:" + d2.home_block
	d2.trust = 0.6
	d2.pressed_today = 0
	Press._answer_pressed_night(w2, d2, 1)
	var before_podium: float = d2.trust
	Podium.press_card(w2, d2, _card(w2, d2, 1, d2.home_block), true)
	_check(d2.trust < before_podium, "pressed in private, then at the podium about the same night: the podium press is a repeat")
	var w3 = _world(7003)
	var d3 = w3.living_good()[0]
	d3.history[w3.time_key(1, C.NIGHT)] = "home:" + d3.home_block
	d3.trust = 0.6
	Podium.press_card(w3, d3, _card(w3, d3, 1, d3.home_block), true)
	var before_private: float = d3.trust
	d3.pressed_today = 0
	Press._answer_pressed_night(w3, d3, 1)
	_check(d3.trust < before_private, "pressed at the podium, then in private: the private press is a repeat")
	# A known burden's walk (an Unrequited's) is confessed more often after earlier presses.
	var told := {0: 0, 3: 0}
	var tries := {0: 0, 3: 0}
	for sd in range(7100, 7160):
		for earlier in [0, 3]:
			var w = _world(sd)
			var d = null
			for m in w.living_good():
				if not C.ROLES[m.role].get("night_walk", false):
					d = m
					break
			if d == null:
				continue
			var bl = w.living().filter(func(m): return m != d and m.home_block != d.home_block)[0]
			d.history[w.time_key(1, C.NIGHT)] = "night:" + bl.home_block
			d.secret = {"kind": "unrequited", "burden": true, "beloved": bl.id, "dest": bl.home_block,
				"text": "has an unrequited love for %s" % bl.name, "me": "went to %s's door" % bl.name}
			d.traits["privacy"] = 0.7
			for k in range(earlier):
				Press.note_press(d, 1)
			var r: Dictionary = Podium.press_card(w, d, _card(w, d, 1, bl.home_block), true)
			tries[earlier] += 1
			told[earlier] += int(r.get("outcome", "") == "confess")
	var p0: float = float(told[0]) / maxf(1, tries[0])
	var p3: float = float(told[3]) / maxf(1, tries[3])
	print("confessed before the town: no earlier presses %d/%d (%.2f), three earlier %d/%d (%.2f)" % [told[0], tries[0], p0, told[3], tries[3], p3])
	_check(tries[0] >= 30 and p3 > p0, "after earlier presses about the night, the walk is confessed more often")
	# Evil that owned the night, pressed again: may back into a spare walking gift, claimed publicly.
	var backed := 0
	var cases := 0
	var bad := false
	for sd in range(7200, 7260):
		var w = _world(sd)
		var e = null
		for m in w.evil_team():
			if C.is_minion(m.role) and m.role != "scion" and not m.turned:
				e = m
				break
		if e == null:
			continue
		w.evil_plan["bluffs"][e.id] = "clerk"
		e.claimed_role = ""
		e.claim_public = false
		e.max_tier = 1
		var far = w.living().filter(func(m): return m != e and m.home_block != e.home_block)[0]
		e.history[w.time_key(1, C.NIGHT)] = "night:" + far.home_block
		if Press.spare_walking_gifts(w, e, 1).is_empty():
			continue
		# It owned the night earlier, keeping the reason.
		var acc: Dictionary = e.dialogue_memory.get("night_accounts", {})
		acc["1"] = {"kind": "alibi", "subject": [e.id], "home": false, "day": 1, "phase": C.NIGHT, "source": e.id, "block": far.home_block}
		e.dialogue_memory["night_accounts"] = acc
		Press.note_press(e, 1)
		cases += 1
		var r: Dictionary = Podium.press_card(w, e, _card(w, e, 1, far.home_block), true)
		if r.get("outcome", "") == "gift_outing":
			backed += 1
			bad = bad or not e.claim_public or not C.ROLES.get(e.claimed_role, {}).get("night_walk", false)
	print("evil pressed again at the podium backed into a walking gift in %d of %d" % [backed, cases])
	_check(cases >= 8 and backed > 0, "evil pressed again before the town sometimes backs into a spare walking gift")
	_check(not bad, "and claims it before the town, a walking gift")
	print("Pressed again at the podium: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
