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
	_check(e.shadow != null and e.shadow.ledger.keys().any(func(k): return k.begins_with("tell:")), "the good self heard the player's private case")
	_check(e.ledger.is_empty(), "the real evil mind still takes nothing from it")

## Fake Medium readings fit the dead's public record (plan step 4).
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
	dd.claim_public = true
	dd.claimed_role = "nightwatch"
	w.evil_plan["medium_frames"] = 0
	var r = Evil._fake_medium_item(w, n, dd, sg.id)
	_check(r["item"]["type"] == "reading" and r["item"]["entry"]["role"] == "nightwatch", "a dead public Night Watch 'tells' a watch report, not a stray sighting")
	_check(r["item"]["entry"]["data"]["block"] == dd.home_block and sg.id in r["item"]["entry"]["data"]["seen"], "framing the scapegoat near the death")
	var same = goods.filter(func(x): return x != dd and x.home_block == dd.home_block)
	if not same.is_empty():
		dd.claim_public = false
		var r2 = Evil._fake_medium_item(w, n, dd, same[0].id)
		_check(r2["item"]["type"] != "sighting", "no frame when the scapegoat lives on that block (seen on your own block says nothing)")
	var framed = 0
	for i in range(40):
		w.evil_plan["medium_frames"] = 1
		if Evil._fake_medium_item(w, n, dd, sg.id)["item"].get("lie", false):
			framed += 1
	_check(framed > 8 and framed < 32, "after the first frame, not every night (%d/40)" % framed)
