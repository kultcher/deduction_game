## "It's another of us" (BACKLOG, 89077 Coroner finding 1; Michael, Nov 17): the pair
## defence ("it's the other one") for a reading over a group. A nominee named by a count
## over a group, a role found within one, a Chronicler's three or a Surveyor's mixed block
## says it's one of the others, naming them when there are one or two, never shielding a
## teammate by name. Setup as test_playtest_23973.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_named_small_group()
	_unnamed_large_group()
	_surveyor_block()
	_evil_shields_no_teammate()
	_trusts_the_others()
	print("Group defence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7350, 10)
	g.w.day = 4
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.ledger = {}
			listener.beliefs = []
			listener.known_claims = {}
			listener.cleared = {}
			listener.traits.confidence = 0.5
			for id in listener.suspicion:
				listener.suspicion[id] = 0.1
			Mind.refresh_beliefs(g.w, listener, " (clean)")
	return g

## Only `people` live on `blk`.
func _reside(g, people: Array, blk: String, src) -> void:
	for x in g.w.npcs:
		if x.home_block == blk and not (x in people):
			x.home_block = "docks" if blk != "docks" else "market"
	for x in people:
		x.home_block = blk
	if src.home_block == blk:
		src.home_block = "market"

func _said(r: Dictionary) -> Array:
	return r.get("lines", []).map(func(l): return str(l.get("statement", l.get("text", ""))) if l is Dictionary else str(l))

## `source` tells a reading of `role` with `data`; `d` defends. Others in the group are
## suspected 0.5 by d, the source 0.3, unless `susp_others` says otherwise.
func _defend(g, source, d, role: String, data: Dictionary, susp_others: float = 0.5) -> Dictionary:
	var w = g.w
	d.secret = {}
	source.role = role
	source.claimed_role = role
	source.claim_public = true
	var reading = {"day": 1, "role": role, "data": data, "text": "A reading", "shared": true}
	source.info_log = [reading]
	Mind.apply_info(w, source, source, reading, 1.0)
	for x in w.npcs:
		if x != d and x != source:
			d.suspicion[x.id] = susp_others
	d.suspicion[source.id] = 0.3
	# The nomination's case cites the reading, as a told card does in play.
	return Mind.defend_self(w, d, source.id, [MindMeeting.info_fact(w, source, reading)])

func _named_small_group() -> void:
	var g = _game()
	var goods: Array = g.w.living_good()
	var src = goods[0]
	var d = goods[1]
	var a = goods[2]
	var b = goods[3]
	_reside(g, [d, a, b], "chapel", src)
	var r: Dictionary = _defend(g, src, d, "dowser", {"group": [d.id, a.id, b.id], "count": 1, "block": "chapel"})
	var said: Array = _said(r)
	_check("group_other" in r.get("moves", []), "a Dowser count over three: 'it's another of us' (%s)" % str(said))
	_check(said.any(func(s): return a.name in s and b.name in s and "isn't me" in s), "naming the two others (%s)" % str(said))
	_check(not ("lying" in r.get("moves", [])) and not ("misled" in r.get("moves", [])), "and not also calling the reading wrong")

func _unnamed_large_group() -> void:
	var g = _game()
	var goods: Array = g.w.living_good()
	var src = goods[0]
	var d = goods[1]
	_reside(g, [d, goods[2], goods[3], goods[4]], "chapel", src)
	var grp: Array = [d.id, goods[2].id, goods[3].id, goods[4].id]
	var r: Dictionary = _defend(g, src, d, "dowser", {"group": grp, "count": 1, "block": "chapel"})
	var said: Array = _said(r)
	_check("group_other" in r.get("moves", []), "a count over four: still another of us (%s)" % str(said))
	_check(said.any(func(s): return "among the others" in s) and not said.any(func(s): return goods[2].name in s), "without naming three people (%s)" % str(said))

func _surveyor_block() -> void:
	var g = _game()
	var w = g.w
	var goods: Array = w.living_good()
	var src = goods[0]
	var d = goods[1]
	var mate = goods[2]
	for x in w.npcs:
		if x != d and x != mate and x.home_block == "chapel":
			x.home_block = "docks" if src.home_block != "docks" else "market"
	d.home_block = "chapel"
	mate.home_block = "chapel"
	var r: Dictionary = _defend(g, src, d, "surveyor", {"block": "chapel", "same": false})
	var said: Array = _said(r)
	_check("group_other" in r.get("moves", []), "a Surveyor's mixed block of two: another of us (89077) (%s)" % str(said))
	_check(said.any(func(s): return mate.name in s), "naming the other resident (%s)" % str(said))

func _evil_shields_no_teammate() -> void:
	var g = _game()
	var w = g.w
	var evil: Array = w.evil_team()
	if evil.size() < 2:
		_check(false, "the deal has two evil")
		return
	var d = evil[0]
	var mate = evil[1]
	var goods: Array = w.living_good()
	var src = goods[0]
	var good_one = goods[1]
	_reside(g, [d, mate, good_one], "chapel", src)
	var r: Dictionary = _defend(g, src, d, "dowser", {"group": [d.id, mate.id, good_one.id], "count": 1, "block": "chapel"})
	var said: Array = _said(r)
	_check("group_other" in r.get("moves", []), "an evil nominee also says another of us (%s)" % str(said))
	_check(not said.any(func(s): return mate.name in s), "but never names its teammate (%s)" % str(said))

func _trusts_the_others() -> void:
	var g = _game()
	var goods: Array = g.w.living_good()
	var src = goods[0]
	var d = goods[1]
	_reside(g, [d, goods[2], goods[3]], "chapel", src)
	var r: Dictionary = _defend(g, src, d, "dowser", {"group": [d.id, goods[2].id, goods[3].id], "count": 1, "block": "chapel"}, 0.05)
	_check(not ("group_other" in r.get("moves", [])), "suspecting the source more than anyone in the group: no 'another of us' (%s)" % str(_said(r)))
