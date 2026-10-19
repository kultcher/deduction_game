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
