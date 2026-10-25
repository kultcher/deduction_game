## Checks for the shadow good self, step 1 (docs/shadow_self_plan.md): each evil NPC has
## a good mind beside its own, kept out of the town's lists, fed only what a good self
## could know, and holding its fake readings as its own.
##   godot --headless --path . --script res://tools/test_shadow.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")

var fails = 0

func _init() -> void:
	if not C.SHADOW_SELF:
		print("SHADOW_SELF is off; nothing to test.")
		quit(0)
		return
	for sd in [96773, 55774, 4242]:
		_case(sd)
	_scapegoat_review()
	_private_case_reaches_shadow()
	_fake_medium()
	_revenant_round_trip()
	print("SHADOW FAILURES: %d" % fails)
	quit(1 if fails else 0)

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## Play a case to day 3 with the player idle, then look at the shadows.
func _case(sd: int) -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 10)
	for i in range(80):
		if g.w.day >= 3 and g.state == "day":
			break
		match g.state:
			"night":
				g.command("sleep")
			"meeting", "nomination":
				g.command("done" if g.state == "meeting" else "vote no")
				g.command("wait")
			"approach":
				g.command("decline")
			_:
				g.command("wait")
	var w = g.w
	var tag = "case %d:" % sd
	var evil: Array = w.evil_team().filter(func(n): return n.alive)
	_check(not evil.is_empty(), tag + " some evil still alive at day 3")
	for n in evil:
		var s = n.shadow
		var who = "%s %s (%s)" % [tag, n.name, n.role]
		_check(s != null, who + " has a shadow")
		if s == null:
			continue
		_check(not (s in w.npcs) and w.by_id[n.id] == n, who + ": shadow is not in the town's lists")
		_check(s.alignment == "good" and not s.is_evil(), who + ": shadow is good")
		_check(s.role == w.evil_plan["bluffs"].get(n.id, ""), who + ": shadow's gift is the bluff (%s)" % s.role)
		_check(not s.suspicion.has(n.id), who + ": shadow never suspects itself")
		_check(s.intel.is_empty(), who + ": shadow holds no evil intel")
		_check(s.suspicion is Dictionary and not is_same(s.suspicion, n.suspicion) and not is_same(s.ledger, n.ledger)
			and not is_same(s.beliefs, n.beliefs), who + ": shadow shares no lists with the real NPC")
		# Night sightings made while out on evil work stay out of the shadow.
		var leaked = 0
		for b in s.beliefs:
			if b.get("phase", -1) == C.NIGHT and not str(n.history.get(w.time_key(b.get("day", 0), C.NIGHT), "home")).begins_with("home"):
				leaked += 1
		_check(leaked == 0, who + ": no night sightings from nights spent out")
		# It has heard things: its ledger isn't empty by day 3.
		_check(s.ledger.size() > 0, who + ": shadow has heard something (%d ledger entries)" % s.ledger.size())
		# Its fake readings are its own.
		var fakes: Array = n.info_log.filter(func(e): return e.get("fake", false))
		var owned = s.info_log.filter(func(e): return e.get("fake", false)).size()
		_check(owned == fakes.size(), who + ": shadow owns its %d fake readings" % fakes.size())
	# The real evil minds still take nothing from the ledger.
	_check(evil.all(func(n): return n.ledger.is_empty()), tag + " real evil ledgers stay empty")
	# Snapshots carry the shadow view under its own key.
	var snaps: Array = w.dlog.entries.filter(func(e): return e["type"] == "snapshot" and e["data"].has("shadow"))
	_check(not snaps.is_empty(), tag + " snapshots carry a shadow view")
	# Shadow reasoning goes to its own log, not the case log.
	_check(w.shadow_log.entries.size() > 0, tag + " shadow reasoning lands in the shadow log (%d entries)" % w.shadow_log.entries.size())

## The scapegoat follows the town: a good person the town turns hot on overtakes a cold
## scapegoat (switching cost and all).
func _scapegoat_review() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(96773, 10)
	var w = g.w
	w.day = 3
	var Evil = load("res://sim/evil.gd")
	Evil.ensure_scapegoat(w)
	var cur: String = w.evil_plan["scapegoat"]
	var other = w.living_good().filter(func(x): return x.id != cur)[0]
	for i in range(4):
		w.public_event("accusation", [other.id], w.living_good().filter(func(x): return x != other)[i].id)
	w.public_event("nomination", [other.id], w.living_good()[0].id)
	Evil.review_scapegoat(w)
	_check(w.evil_plan["scapegoat"] == other.id, "the scapegoat switches to the town's hot suspect (%s -> %s)" % [cur, w.evil_plan["scapegoat"]])

## A private case the player makes to an evil NPC reaches its good self.
func _private_case_reaches_shadow() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(55774, 10)
	var w = g.w
	var e = w.evil_team()[0]
	var t = w.living_good()[0]
	var card = {"kind": "sighting", "subject": [t.id], "source": "player", "day": 0, "phase": C.NIGHT, "block": t.home_block,
		"text": "You saw %s out at night." % t.name, "n": 1}
	Mind.hear_accusation(w, e, t, card)
	_check(e.shadow != null and e.shadow.ledger.keys().any(func(k): return k.begins_with("tell:") or k.begins_with("workshop:tell:")), "the good self heard the player's private case")
	_check(e.ledger.is_empty(), "the real evil mind still takes nothing from it")

## Fake Medium readings fit the dead's public record and vary (plan step 4, Oct 19 menu).
func _fake_medium() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(4242, 10)
	var w = g.w
	var Evil = load("res://sim/evil.gd")
	var n = w.evil_team()[0]
	var goods: Array = w.living_good()
	var dd = goods[0]
	var sg = goods.filter(func(x): return x.home_block != dd.home_block)[0]
	dd.alive = false
	dd.death_day = 2
	dd.death_cause = "demon"
	dd.claim_public = true
	dd.claimed_role = "nightwatch"
	var kinds = {}
	for i in range(80):
		w.evil_plan["medium_frames"] = 0
		var it: Dictionary = Evil._fake_medium_item(w, n, dd, sg.id)["item"]
		var k: String = it["type"] + (":" + it["entry"]["role"] if it["type"] == "reading" else "") + (":idle" if it.get("idle", false) else "")
		kinds[k] = kinds.get(k, 0) + 1
	_check(kinds.get("reading:nightwatch", 0) > 30, "a dead public Night Watch mostly 'tells' a watch report (%s)" % str(kinds))
	var empty = kinds.get("home", 0) + kinds.get("sighting:idle", 0)
	_check(empty >= 4 and empty <= 30, "sometimes only something empty (%d/80)" % empty)
	# A dead Seer, with the demon publicly named: sometimes the fake 'clears' the demon.
	dd.claimed_role = "seer"
	w.public_event("reading", [w.demon_id, sg.id], goods[1].id)
	var cleared = 0
	var pinged = 0
	for i in range(80):
		w.evil_plan["medium_frames"] = 0
		var it2: Dictionary = Evil._fake_medium_item(w, n, dd, sg.id)["item"]
		if it2["type"] == "reading" and it2["entry"]["role"] == "seer":
			if not it2["entry"]["data"]["yes"] and w.demon_id in it2["entry"]["data"]["pair"]:
				cleared += 1
			elif it2["entry"]["data"]["yes"]:
				pinged += 1
	_check(cleared > 5 and pinged > 5, "a dead Seer's fake reading both clears the demon and pings the good (%d / %d)" % [cleared, pinged])
	# A dead Gravedigger 'learns' a hanged good soul was a minion; never a Breathstealer
	# unless one is in play.
	dd.claimed_role = "gravedigger"
	var hanged = goods[2]
	hanged.alive = false
	hanged.death_cause = "executed"
	var bs_named = false
	var minion = 0
	for i in range(60):
		var r = Evil._fake_dead_reading(w, n, dd, "gravedigger", sg.id, 1)
		if r.is_empty():
			continue
		if r["entry"]["data"]["role"] in C.MINION_ROLES:
			minion += 1
		if r["entry"]["data"]["role"] == "breathstealer":
			bs_named = true
	_check(minion > 50, "the hanged good soul 'was a minion' (%d/60)" % minion)
	_check(w.living_with_role("breathstealer") != null or not bs_named, "no fake Breathstealer unless one is in play")
	# The real Medium: a dead soul who shared everything has nothing new.
	var real_dead = goods[3]
	real_dead.alive = false
	real_dead.death_day = 2
	real_dead.beliefs = []
	real_dead.suspicion = {}
	real_dead.warden_log = {}
	real_dead.info_log = [{"day": 0, "role": "dowser", "data": {}, "text": "x", "shared": true}]
	var nothing = 0
	for i in range(40):
		if w._medium_item(goods[4], real_dead, false)["type"] == "nothing":
			nothing += 1
	_check(nothing >= 28, "the real Medium at a hearth with nothing unshared: 'nothing new' (%d/40)" % nothing)

## The Revenant's curse: turning keeps the good mind as the shadow; freeing gives it back,
## minus anything taken from their own fake readings, and with no evil knowledge.
func _revenant_round_trip() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(55774, 10)
	var w = g.w
	var v = w.living_good()[0]
	var t = w.living_good()[1]
	Mind.ledger_hear(w, v, "test:before", [[t.id, 0.3, false, "before the curse", "before"]], 1.0)
	var before = v.suspicion[t.id]
	w.turn_evil(v, "test")
	w.curse = {"victim": v.id}
	_check(v.is_evil() and v.shadow == null, "turned: evil, shadow to be rebuilt")
	Mind.ledger_hear(w, v, "test:during", [[t.id, 0.25, false, "heard while turned", "during"]], 1.0)
	_check(v.shadow != null and v.shadow.ledger.has("test:before") and v.shadow.ledger.has("test:during"), "the shadow carries the good mind from before and keeps hearing")
	_check(not v.ledger.has("test:during"), "the real (evil) mind takes nothing while turned")
	v.info_log.append({"day": w.day, "role": v.role, "data": {}, "text": "fake", "fake": true, "shared": false})
	Mind.update_from_own_info(w)
	w.free_turned()
	_check(not v.is_evil() and v.shadow == null and v.intel.is_empty(), "freed: good again, no shadow, no evil intel")
	_check(v.ledger.has("test:during"), "what they heard while turned is theirs again")
	_check(not v.ledger.has(Mind.info_eid(v.id, v.info_log[-1])), "nothing from their own fake readings")
	_check(v.suspicion[t.id] >= before - 0.3, "beliefs re-derived, not lost (%.2f -> %.2f)" % [before, v.suspicion[t.id]])
