## Blending in versus disruption in the teammate bluffs (Michael, Nov 18, on #264):
## - Rumormonger: now and then implies two good townsfolk may be Delusional; otherwise it
##   covers a teammate.
## - Clerk: a Scion or Demon may blend in by "confirming" an early good claimer, changing its
##   still-untold reading; a reading already told stays the cover.
## - Martyr: chooses a good soul under heat, never a teammate; when that soul hangs, it says
##   they must have been evil.
## - Gravedigger: a Minion leans toward disruption (covering a hanged teammate's claim), a
##   Demon or Scion toward blending in on its first reading (naming the teammate's true role).
## - Confessor: a Minion vouches for its Demon; a Demon or Scion mostly vouches for a trusted
##   good soul; nobody twice.
extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Evil = preload("res://sim/evil.gd")
const Registry = preload("res://sim/role_registry.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_rumormonger()
	_clerk()
	_martyr()
	_gravedigger()
	_confessor()
	print("Bluff blend: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _world(seed: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed, 10)
	return g.w

func _minion(w):
	for m in w.evil_team():
		if m.id != w.demon_id and m.role != "scion":
			return m
	return null

func _rumormonger() -> void:
	var two_good: int = 0
	var cover: int = 0
	var ran: int = 0
	for sd in range(80):
		var w = _world(9800 + sd)
		if not ("delusional" in w.case_script.secrets):
			continue
		w.day = 0
		var n = w.evil_team()[0]
		var mate = Evil.mate(w, n)
		if mate == null:
			continue
		var s: String = str(w.evil_plan.get("scapegoat", ""))
		var gen: Dictionary = Registry.get_def("rumormonger").generate_bluff_reading(w, n, w.evil_plan, s, mate, [])
		if gen.is_empty():
			continue
		ran += 1
		var pair: Array = gen["entry"]["data"]["pair"]
		if pair.all(func(x): return not w.by_id[x].is_evil()) and gen["entry"]["data"]["secret"] == "delusional":
			two_good += 1
		elif mate.id in pair:
			cover += 1
	print("  Rumormonger: %d cases; two good souls as Delusional %d, a teammate covered %d" % [ran, two_good, cover])
	_check(ran >= 40, "enough cases (%d)" % ran)
	_check(two_good + cover == ran, "every made-up Rumormonger reading is one or the other")
	_check(two_good >= ran / 6 and two_good <= ran / 2, "two good souls as Delusional about a third of the time (%d of %d)" % [two_good, ran])

func _clerk() -> void:
	# A Demon bluffing Clerk that chose to blend: its untold reading confirms an early good
	# claimer next morning; told already, it stays the cover.
	for told in [false, true]:
		var w = _world(9901)
		w.day = 0
		var d = w.by_id[w.demon_id]
		var mate = Evil.mate(w, d)
		w.evil_plan["bluffs"][d.id] = "clerk"
		var entry: Dictionary = {"role": "clerk", "day": 0, "fake": true, "shared": told, "true": false,
			"data": {"pair": [mate.id if mate != null else d.id, w.living_good()[0].id], "role": "seer"}, "text": "cover", "why": "evil fabrication: cover"}
		d.info_log = [entry]
		w.evil_plan["clerk_blend_" + d.id] = true
		var g = w.living_good()[1]
		g.claimed_role = g.role
		g.claim_public = true
		w.public_claims.append({"day": 1, "who": g.id, "role": g.role})
		w.day = 2
		Evil.blend_clerk_readings(w)
		var now: Dictionary = d.info_log[0]
		if told:
			_check(now["text"] == "cover", "a Clerk reading already told stays the cover it was")
		else:
			_check(g.id in now["data"]["pair"] and now["data"]["role"] == g.role, "an untold one now confirms %s's claim to be the %s (%s)" % [g.name, g.role, now["text"]])
	# Only a Scion or Demon blends.
	var blenders: int = 0
	var minion_blends: int = 0
	for sd in range(60):
		var w = _world(9900 + sd)
		w.day = 0
		var m = _minion(w)
		var d = w.by_id[w.demon_id]
		for who in [m, d]:
			if who == null:
				continue
			var mate = Evil.mate(w, who)
			Registry.get_def("clerk").generate_bluff_reading(w, who, w.evil_plan, "", mate if mate != null else who, [])
		if m != null and w.evil_plan.get("clerk_blend_" + m.id, false):
			minion_blends += 1
		if w.evil_plan.get("clerk_blend_" + d.id, false):
			blenders += 1
	print("  Clerk: in 60 deals the Demon chose to blend %d times, a Minion %d" % [blenders, minion_blends])
	_check(minion_blends == 0, "a Minion bluffing Clerk always covers a teammate")
	_check(blenders >= 10 and blenders <= 32, "a Demon bluffing Clerk blends about a third of the time (%d of 60)" % blenders)

func _martyr() -> void:
	var w = _world(9902)
	w.day = 1
	var n = _minion(w)
	var mate = Evil.mate(w, n)
	var hot = w.living_good()[2]
	w.public_event("accusation", [hot.id], w.living_good()[0].id)
	w.public_event("nomination", [hot.id], w.living_good()[1].id)
	var gen: Dictionary = Registry.get_def("martyr").generate_bluff_reading(w, n, w.evil_plan, "", mate, [])
	var tgt: String = str(gen.get("entry", {}).get("data", {}).get("target", ""))
	_check(tgt == hot.id, "a bluffing Martyr chooses the good soul under the most heat (%s, wanted %s)" % [tgt, hot.id])
	_check(not w.by_id[tgt].is_evil(), "never a teammate")
	var e: Dictionary = gen["entry"]
	e["role"] = "martyr"
	e["fake"] = true
	e["shared"] = true
	n.info_log.append(e)
	w.day = 2
	w.execute(hot.id, {})
	var after: Array = n.info_log.filter(func(x): return x.get("role", "") == "martyr" and x.get("data", {}).get("evil", false))
	_check(after.size() == 1 and str(after[0]["data"]["target"]) == hot.id, "when the chosen hangs, it says they must have been evil (%d readings)" % after.size())

## How often a hanged-teammate Gravedigger reading names the teammate's true role.
func _gd_true_role(blender: bool) -> Array:
	var named_true: int = 0
	var ran: int = 0
	for sd in range(60):
		var w = _world(9950 + sd)
		var m = _minion(w)
		if m == null:
			continue
		var n = w.by_id[w.demon_id] if blender else m
		var dead = m if blender else w.by_id[w.demon_id]
		if dead == n:
			continue
		w.day = 2
		w.executed_today = dead.id
		w.evil_plan["bluffs"][dead.id] = w.evil_plan["bluffs"].get(dead.id, "clerk")
		n.info_log = []
		var gen: Dictionary = Registry.get_def("gravedigger").generate_bluff_reading(w, n, w.evil_plan, "", dead, [])
		if gen.is_empty():
			continue
		ran += 1
		if str(gen["entry"]["data"]["role"]) == dead.role:
			named_true += 1
	return [named_true, ran]

func _gravedigger() -> void:
	var minion: Array = _gd_true_role(false)
	var demon: Array = _gd_true_role(true)
	print("  Gravedigger, a hanged teammate: a Minion named its true role %d of %d; the Demon %d of %d" % [minion[0], minion[1], demon[0], demon[1]])
	_check(minion[1] >= 40 and demon[1] >= 40, "enough cases")
	_check(minion[0] < demon[0], "a Demon blends in more often than a Minion on its first reading")
	_check(minion[0] <= minion[1] / 2, "a Minion mostly covers the teammate (%d of %d named the true role)" % minion)
	_check(demon[0] >= demon[1] / 2, "a Demon mostly names the teammate's true role (%d of %d)" % demon)

func _confessor() -> void:
	var w = _world(9903)
	w.day = 2
	var m = _minion(w)
	var d = w.by_id[w.demon_id]
	var first: Dictionary = Registry.get_def("confessor").generate_bluff_reading(w, m, w.evil_plan, "", Evil.mate(w, m), [])
	_check(str(first["entry"]["data"].get("target", "")) == d.id, "a Minion bluffing Confessor vouches for its Demon")
	var e: Dictionary = first["entry"]
	e["role"] = "confessor"
	e["fake"] = true
	m.info_log.append(e)
	var second: Dictionary = Registry.get_def("confessor").generate_bluff_reading(w, m, w.evil_plan, "", Evil.mate(w, m), [])
	_check(str(second["entry"]["data"].get("target", "")) != d.id, "but not night after night")
	var trusted: int = 0
	var ran: int = 0
	for sd in range(40):
		var w2 = _world(9700 + sd)
		w2.day = 2
		var d2 = w2.by_id[w2.demon_id]
		var gen: Dictionary = Registry.get_def("confessor").generate_bluff_reading(w2, d2, w2.evil_plan, "", Evil.mate(w2, d2), [])
		if gen.is_empty():
			continue
		ran += 1
		var t: String = str(gen["entry"]["data"].get("target", ""))
		if t != "" and not w2.by_id[t].is_evil():
			trusted += 1
	print("  Confessor: the Demon vouched for a good soul %d of %d times" % [trusted, ran])
	_check(trusted >= ran / 2, "a Demon bluffing Confessor mostly vouches for a good soul (%d of %d)" % [trusted, ran])
