## Caught out and pressed again (Michael, Nov 20 plan; values Nov 27):
##   - a good NPC that owned a night but kept the reason is likelier to give it with each
##     press about that night (Tuning.Dialogue.PRESSED_AGAIN_OPENNESS), until it comes out;
##   - a truly-home NPC pressed again about that night stands by its account and trusts the
##     asker less;
##   - evil with no walking bluff to tell, pressed again, may back into a spare walking gift
##     (a Minion more readily than the Demon), never once it has named a gift, and only one
##     whose night work explains the night.
##   godot --headless --path . --script res://tools/test_pressed_again.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Press = preload("res://sim/mind_press.gd")
const Tuning = preload("res://sim/tuning.gd")

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

func _contra(night: int) -> Dictionary:
	return {"ruled_out_home_by": ["x"], "night": night}

func _said(r: Dictionary) -> String:
	return " ".join(PackedStringArray(r.get("lines", []).map(func(x): return str(x.get("statement", x.get("text", "")) if x is Dictionary else x))))

func _init() -> void:
	_good_gives_way()
	_truly_home_irritated()
	_evil_backs_into_a_walker()
	print("Pressed again: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## A good NPC out on a known burden's walk (an Unrequited's), closed enough to keep the reason
## at the first press: pressed again, it gives way sooner or later, and the press is in the
## openness parts.
func _good_gives_way() -> void:
	var kept_first := 0
	var gave_later := 0
	var part_seen := false
	for sd in range(3000, 3030):
		var w = _world(sd)
		var n = null
		for m in w.living_good():
			if not C.ROLES[m.role].get("night_walk", false):
				n = m
				break
		if n == null:
			continue
		var bl = w.living().filter(func(m): return m != n and m.home_block != n.home_block)[0]
		n.history[w.time_key(1, C.NIGHT)] = "night:" + bl.home_block
		n.secret = {"kind": "unrequited", "burden": true, "beloved": bl.id, "dest": bl.home_block,
			"text": "has an unrequited love for %s" % bl.name, "me": "went to %s's door" % bl.name}
		n.traits["privacy"] = 0.85
		n.trust = 0.25
		n.pressure = 0.0
		var r0: Dictionary = Press._pressed_caught_out(w, n, 1, _contra(1))
		if r0.get("facts", []).any(func(f): return f.get("kind", "") == "secret"):
			continue
		kept_first += 1
		for k in range(6):
			var r: Dictionary = Press._pressed_caught_out(w, n, 1, _contra(1))
			if r.get("facts", []).any(func(f): return f.get("kind", "") == "secret"):
				gave_later += 1
				break
		part_seen = part_seen or w.dlog.entries.any(func(x): return x["type"] == "think" and x["actor"] == n.id and int(x.get("data", {}).get("presses", 0)) > 0)
	print("kept the reason at the first press %d; gave it within six more presses %d" % [kept_first, gave_later])
	_check(kept_first >= 5, "some closed NPCs keep the reason at the first press")
	_check(gave_later * 10 >= kept_first * 8, "pressed again, most of them give the reason within six presses")
	_check(part_seen, "the press count is logged with the answer")
	var w2 = _world(3000)
	var n2 = w2.living_good()[0]
	_check(Press.press_count(n2, 1) == 0, "an unpressed night counts no presses")

## Truly home, pressed again about that night: trust in the asker drops, the first time not.
func _truly_home_irritated() -> void:
	var w = _world(3100)
	var n = w.living_good()[0]
	n.history[w.time_key(1, C.NIGHT)] = "home:" + n.home_block
	n.trust = 0.6
	n.pressed_today = 0
	Press._answer_pressed_night(w, n, 1)
	var after_first: float = n.trust
	n.pressed_today = 0
	Press._answer_pressed_night(w, n, 1)
	_check(after_first >= 0.6 - 0.0001, "the first press about a night at home costs nothing extra")
	_check(n.trust < after_first, "pressed again about it, it trusts the asker less")
	var w3 = _world(3101)
	var o = w3.living_good()[0]
	o.history[w3.time_key(1, C.NIGHT)] = "night:" + o.home_block
	o.trust = 0.6
	o.pressed_today = 0
	Press._answer_pressed_night(w3, o, 1)
	o.pressed_today = 0
	var before: float = o.trust
	Press._answer_pressed_night(w3, o, 1)
	_check(is_equal_approx(o.trust, before) or not o.history[w3.time_key(1, C.NIGHT)].begins_with("home:"), "the irritation is only for a night truly spent at home")

## Evil caught out with no walking bluff, pressed again: backs into a spare walking gift that
## explains the night, a Minion more often than the Demon; never once it has named a gift.
func _evil_backs_into_a_walker() -> void:
	var tried := {"minion": 0, "demon": 0}
	var backed := {"minion": 0, "demon": 0}
	var bad := false
	var claimed_backed := false
	for sd in range(3200, 3260):
		for who in ["minion", "demon"]:
			var w = _world(sd)
			var e = w.by_id[w.demon_id] if who == "demon" else null
			if who == "minion":
				for m in w.evil_team():
					if C.is_minion(m.role) and m.role != "scion" and not m.turned:
						e = m
						break
			if e == null:
				continue
			# A non-walking bluff, so nothing covers the night.
			var plain: String = ""
			for r in ["clerk", "archivist", "rumormonger", "surveyor"]:
				if w.case_script.town.has(r):
					plain = r
					break
			if plain == "":
				continue
			w.evil_plan["bluffs"][e.id] = plain
			e.claimed_role = ""
			e.claim_public = false
			e.max_tier = 1
			var far = w.living().filter(func(m): return m != e and m.home_block != e.home_block)[0]
			e.history[w.time_key(1, C.NIGHT)] = "night:" + far.home_block
			if Press.spare_walking_gifts(w, e, 1).is_empty():
				continue
			tried[who] += 1
			var r0: Dictionary = Press._pressed_caught_out(w, e, 1, _contra(1))
			bad = bad or w.evil_plan["bluffs"][e.id] != plain  # the first press never backs into one
			var r1: Dictionary = Press._pressed_caught_out(w, e, 1, _contra(1))
			var now: String = str(w.evil_plan["bluffs"][e.id])
			if now != plain:
				backed[who] += 1
				bad = bad or not C.ROLES.get(now, {}).get("night_walk", false) or not Press.bluff_duty_covers(w, e, now, 1)
	# Once it has named a gift, never.
	for sd in range(3200, 3220):
		var w = _world(sd)
		var e = null
		for m in w.evil_team():
			if C.is_minion(m.role) and m.role != "scion" and not m.turned:
				e = m
				break
		if e == null:
			continue
		w.evil_plan["bluffs"][e.id] = "clerk"
		e.claimed_role = "clerk"
		e.max_tier = 3
		e.history[w.time_key(1, C.NIGHT)] = "night:" + w.living().filter(func(m): return m != e and m.home_block != e.home_block)[0].home_block
		Press._pressed_caught_out(w, e, 1, _contra(1))
		Press._pressed_caught_out(w, e, 1, _contra(1))
		claimed_backed = claimed_backed or str(w.evil_plan["bluffs"][e.id]) != "clerk"
	# Nor a Revenant-turned townsperson (its real gift is its cover), and one re-press counts as
	# one question (Codex on #560).
	var turned_backed := false
	var double_count := false
	var turned_cases := 0
	var backup_cases := 0
	for sd in range(3200, 3240):
		var w = _world(sd)
		var e = null
		for m in w.evil_team():
			if C.is_minion(m.role) and m.role != "scion" and not m.turned:
				e = m
				break
		if e == null:
			continue
		var plain: String = "clerk"
		w.evil_plan["bluffs"][e.id] = plain
		e.claimed_role = ""
		e.claim_public = false
		e.max_tier = 1
		e.history[w.time_key(1, C.NIGHT)] = "night:" + w.living().filter(func(m): return m != e and m.home_block != e.home_block)[0].home_block
		if Press.spare_walking_gifts(w, e, 1).is_empty():
			continue
		Press._pressed_caught_out(w, e, 1, _contra(1))
		var before_q: int = e.pressed_today
		Press._pressed_caught_out(w, e, 1, _contra(1))
		if str(w.evil_plan["bluffs"][e.id]) != plain:
			backup_cases += 1
			double_count = double_count or e.pressed_today - before_q != 1
		var w2 = _world(sd)
		var t = w2.living_good().filter(func(m): return not C.ROLES[m.role].get("night_walk", false))[0]
		w2.turn_evil(t, "test")
		t.history[w2.time_key(1, C.NIGHT)] = "night:" + w2.living().filter(func(m): return m != t and m.home_block != t.home_block)[0].home_block
		if t.is_evil():
			turned_cases += 1
			Press._pressed_caught_out(w2, t, 1, _contra(1))
			Press._pressed_caught_out(w2, t, 1, _contra(1))
			turned_backed = turned_backed or str(w2.evil_plan["bluffs"][t.id]) != t.role
	print("turned cases %d; backups checked for question count %d" % [turned_cases, backup_cases])
	_check(turned_cases >= 5 and not turned_backed, "a Revenant-turned townsperson never backs into another gift")
	# Nor once it has named its bluff to another NPC in private (Codex on #560).
	var told_cases := 0
	var told_backed := false
	for sd in range(3200, 3240):
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
		e.history[w.time_key(1, C.NIGHT)] = "night:" + w.living().filter(func(m): return m != e and m.home_block != e.home_block)[0].home_block
		if Press.spare_walking_gifts(w, e, 1).is_empty():
			continue
		var heard = w.living_good()[0]
		heard.known_claims[e.id] = {"role": "clerk"}
		told_cases += 1
		Press._pressed_caught_out(w, e, 1, _contra(1))
		Press._pressed_caught_out(w, e, 1, _contra(1))
		told_backed = told_backed or str(w.evil_plan["bluffs"][e.id]) != "clerk"
	_check(told_cases >= 5 and not told_backed, "never once it has named its bluff to another NPC in private")
	_check(backup_cases >= 3 and not double_count, "backing into a gift counts the re-press as one question")
	print("backed into a walking gift on the second press: Minion %d/%d, Demon %d/%d" % [backed["minion"], tried["minion"], backed["demon"], tried["demon"]])
	_check(tried["minion"] >= 8 and tried["demon"] >= 8, "enough cases with a spare walking gift were found")
	_check(backed["minion"] > 0 and backed["demon"] > 0, "pressed again, evil sometimes backs into a spare walking gift")
	_check(float(backed["minion"]) / maxf(1, tried["minion"]) > float(backed["demon"]) / maxf(1, tried["demon"]), "a Minion does so more readily than the Demon")
	_check(not bad, "only on a re-press, and only into a walking gift that explains the night")
	_check(not claimed_backed, "never once it has named a gift")
