## "Call on" (docs/design/withheld_readings.md, Michael, Nov 22): how the one called on answers
## (MindCallOn.respond). Shares what it holds when the normal disclosure rules say yes, pushed a
## little; says it has nothing when that's so; otherwise a good NPC defers with its reason or
## deflects, and evil says it has told all it knows (a logged lie).
extends SceneTree
const Game = preload("res://game/game.gd")
const MindCallOn = preload("res://sim/mind_call_on.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _world(sd: int = 54875):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 10)
	g.w.day = 2
	g.w.begin_meeting()
	return g.w

## A good NPC with a reading it hasn't told the town.
func _holder(w):
	for m in w.living_good():
		if not m.claim_public and m.info_log.any(func(e): return not e.get("shared", false)):
			return m
	return null

func _said(r: Dictionary) -> String:
	return " ".join(PackedStringArray(r["lines"].map(func(x): return str(x.get("statement", x.get("text", ""))))))

func _hold_back(n) -> void:
	# Make the "say it before the town?" decision a near-certain no.
	n.traits["privacy"] = 1.0
	n.traits["composure"] = 1.0
	n.traits["gossip"] = 0.0
	n.traits["confidence"] = 0.0
	n.pressure = 0.0

func _init() -> void:
	# Nothing to tell.
	var w = _world()
	var q = w.living_good().filter(func(m): return m.info_log.is_empty() and m.beliefs.filter(func(b): return b.get("kind", "") == "saw").is_empty())
	if not q.is_empty():
		var r0: Dictionary = MindCallOn.respond(w, q[0])
		_check(r0["outcome"] == "nothing" and not r0["lie"], "with nothing unshared, it says it has told the town all it knows")
	# Already out with the gift: it shares what's new.
	var w1 = _world()
	var h1 = _holder(w1)
	_check(h1 != null, "a good NPC holds an unshared reading")
	if h1 != null:
		h1.claim_public = true
		h1.claimed_role = h1.role
		var r1: Dictionary = MindCallOn.respond(w1, h1)
		_check(r1["outcome"] == "shared" and not r1["facts"].is_empty(), "already out with its gift, called on, it shares what it hadn't (%s)" % _said(r1))
		_check(h1.info_log.all(func(e): return e.get("shared", false) or e.get("disowned", false)), "and those readings count as told")
	# Holding back: a reading naming a friend.
	var friend_seen := false
	var bad_reason := false
	for k in range(8):
		var w2 = _world(54875 + k)
		var h2 = _holder(w2)
		if h2 == null:
			continue
		_hold_back(h2)
		var e: Dictionary = h2.info_log.filter(func(x): return not x.get("shared", false))[0]
		var named: Array = load("res://sim/gifts.gd").implicated(e)
		if named.is_empty():
			continue
		h2.friends.append(named[0])
		var r2: Dictionary = MindCallOn.respond(w2, h2)
		if r2["outcome"] == "shared":
			continue
		friend_seen = friend_seen or (r2["outcome"] == "deferred" and r2["reason"] == "friend")
		bad_reason = bad_reason or not (r2["reason"] in ["friend", "burden"])
	_check(friend_seen and not bad_reason, "holding back a reading that names a friend, it defers for its friend")
	# Holding back, distrusting the Demonologist, nothing else at stake; and with no reason.
	var distrust_seen := false
	var deflect_seen := false
	var never_nothing := true
	for k in range(12):
		for trusting in [false, true]:
			var w3 = _world(55000 + k)
			var h3 = _holder(w3)
			if h3 == null:
				continue
			_hold_back(h3)
			h3.friends = []
			h3.known_claims = {}
			h3.trust = 0.9 if trusting else 0.1
			h3.info_log = h3.info_log.filter(func(x): return str(x.get("role", "")) != "rumormonger")
			var r3: Dictionary = MindCallOn.respond(w3, h3)
			if r3["outcome"] == "shared":
				continue
			never_nothing = never_nothing and r3["outcome"] != "nothing"
			if not trusting and r3["outcome"] == "deferred" and r3["reason"] == "distrust" and "Demonologist" in _said(r3):
				distrust_seen = true
			if trusting and r3["outcome"] == "deflected":
				deflect_seen = true
	_check(distrust_seen, "distrusting the Demonologist, it says it'll share when it chooses, naming them")
	_check(deflect_seen, "with no reason, it deflects, visibly a refusal")
	_check(never_nothing, "a good NPC holding back never pretends it has nothing")
	# Only an untold night sighting, kept back (Codex on #545): a refusal, never "nothing".
	var sight_tested := false
	for k in range(10):
		var w7 = _world(56000 + k)
		var cands: Array = w7.living_good().filter(func(m): return m.info_log.is_empty() and not m.claim_public)
		if cands.is_empty():
			continue
		var s7 = cands[0]
		_hold_back(s7)
		s7.known_claims = {}
		s7.beliefs = s7.beliefs.filter(func(x): return x.get("kind", "") != "saw")
		var seen = w7.living().filter(func(m): return m != s7)[0]
		s7.beliefs.append({"kind": "saw", "phase": C.NIGHT, "day": 1, "who": seen.id, "block": s7.home_block, "how": "window", "loc": "night:" + s7.home_block})
		if MindCallOn._untold_sightings(w7, s7).is_empty():
			continue
		var r7: Dictionary = MindCallOn.respond(w7, s7)
		if r7["outcome"] == "shared":
			continue
		sight_tested = true
		_check(r7["outcome"] in ["deferred", "deflected"], "holding back only a night sighting, it refuses visibly (%s)" % r7["outcome"])
		break
	_check(sight_tested, "a case with only an untold sighting was found and tested")
	# Evil, holding a fabricated reading back: says it has told all it knows, a logged lie.
	var w5 = _world()
	var ev = w5.npcs.filter(func(m): return m.alive and m.is_evil() and not C.is_demon(m.role))[0]
	_hold_back(ev)
	ev.claim_public = false
	ev.info_log.append({"role": "seer", "day": 1, "data": {"pair": [w5.living_good()[0].id, w5.living_good()[1].id], "yes": false}, "text": "x", "fake": true, "shared": false})
	var r5: Dictionary = MindCallOn.respond(w5, ev)
	_check(r5["outcome"] == "shared" or (r5["outcome"] == "nothing" and r5["lie"]), "evil holding a bluff back says it has nothing, and it's logged as a lie (%s)" % r5["outcome"])
	_check(r5["outcome"] != "nothing" or w5.dlog.entries.any(func(x): return x["type"] == "think" and x["actor"] == ev.id and x.get("data", {}).get("lie", false)), "with its reason")
	# The push is light: it appears in the claim decision as "called_on".
	var w6 = _world()
	var h6 = _holder(w6)
	if h6 != null:
		_hold_back(h6)
		MindCallOn.respond(w6, h6)
		_check(w6.dlog.entries.any(func(x): return x["type"] == "think" and x["actor"] == h6.id and x.get("data", {}).has("called_on")), "the claim decision carries the light 'called on' push")
	print("Call on respond: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
