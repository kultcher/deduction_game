## The Seer's target choice (reading_interpretation.md §2.1, Michael, Nov 21).
## - It looks for the Demon, not just for evil: someone its own "no" cleared of being the
##   Demon isn't its first pick, however evil it thinks them.
## - After a "yes" not yet narrowed down, a focused Seer re-checks one of the two beside
##   someone fresh or someone it trusts as good (one it has cleared, else its least
##   suspected), on a coin flip (Michael, Nov 21).
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _seer(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 10)
	var w = g.w
	var sr = w.living_good()[0]
	var holder = w.npc_with_role("seer")
	if holder != null and holder != sr:
		holder.role = sr.role
	sr.role = "seer"
	sr.traits["insight"] = 0.95
	sr.info_log = []
	sr.cleared = {}
	w.day = 2
	return [w, sr]

func _reading(sr, day: int, pair: Array, yes: bool) -> void:
	sr.info_log.append({"role": "seer", "day": day, "data": {"pair": pair, "yes": yes}, "text": "x", "shared": false})
	if not yes:
		for i in pair:
			sr.cleared[i] = true

func _init() -> void:
	# Demon, not just evil: the most suspected person, cleared by its own "no", isn't re-checked.
	var top_cleared: int = 0
	var top_open: int = 0
	for sd in range(9600, 9630):
		var ws = _seer(sd)
		var w = ws[0]
		var sr = ws[1]
		var others: Array = w.living().filter(func(m): return m != sr)
		for i in range(others.size()):
			sr.suspicion[others[i].id] = 0.9 - 0.05 * i
		_reading(sr, 0, [others[0].id, others[5].id], false)
		var picks: Array = Mind.seer_picks(w, sr)
		top_cleared += int(others[0].id in picks)
		top_open += int(others[1].id in picks)
	print("cleared top suspect picked %d/30; next suspect picked %d/30" % [top_cleared, top_open])
	_check(top_cleared == 0, "a Seer never re-checks someone its own \"no\" cleared as its top Demon suspect")
	_check(top_open >= 15, "it looks at its likeliest Demon instead")
	# Narrowing a "yes": one of the two again, beside someone it has cleared.
	var narrowed: int = 0
	var beside_cleared: int = 0
	var beside_fresh: int = 0
	for sd in range(9630, 9660):
		var ws = _seer(sd)
		var w = ws[0]
		var sr = ws[1]
		var others: Array = w.living().filter(func(m): return m != sr)
		for i in range(others.size()):
			sr.suspicion[others[i].id] = 0.5
		var a = others[0]
		var b = others[1]
		var c = others[2]
		var d = others[3]
		_reading(sr, 0, [c.id, d.id], false)
		_reading(sr, 1, [a.id, b.id], true)
		var picks: Array = Mind.seer_picks(w, sr)
		var last: Array = w.dlog.entries.filter(func(x): return x["type"] == "think" and x["actor"] == sr.id and x.get("data", {}).get("topic", "") == "seer_pick")
		var narrowing: bool = not last.is_empty() and "narrows" in str(last[-1].get("reason", ""))
		var has_one: bool = (a.id in picks) != (b.id in picks)
		narrowed += int(narrowing and has_one)
		beside_cleared += int(narrowing and has_one and (c.id in picks or d.id in picks))
		beside_fresh += int(narrowing and has_one and not (c.id in picks or d.id in picks))
	print("after a yes: one of the two re-checked %d/30, beside someone cleared %d, someone fresh %d" % [narrowed, beside_cleared, beside_fresh])
	_check(narrowed >= 15, "after a \"yes\", a sharp Seer usually re-checks one of the two")
	_check(beside_cleared + beside_fresh == narrowed and beside_cleared >= 5 and beside_fresh >= 5, "narrowing, beside someone it has cleared or someone fresh, about half each")
	# Once narrowed (the partner cleared since), the "yes" is settled and no longer narrowed.
	var ws2 = _seer(9660)
	var w2 = ws2[0]
	var sr2 = ws2[1]
	var o2: Array = w2.living().filter(func(m): return m != sr2)
	_reading(sr2, 0, [o2[0].id, o2[1].id], true)
	_reading(sr2, 1, [o2[1].id, o2[2].id], false)
	_check(C.role_def("seer")._narrowing_pick(w2, sr2, o2, {}, {o2[0].id: 1}).is_empty(), "once one of the two is cleared, the \"yes\" is narrowed down")
	print("Seer targets: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
