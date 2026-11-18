## A bluffer's frame memory (BACKLOG, Michael, Nov 17): a fresh made-up reading that would
## clear someone its earlier ones implicated, under the same scapegoat, is swapped for one
## of the rule's readings that doesn't, more often the sharper and surer the liar. The
## memory drops when the team switches scapegoat. Checked on Evil._keep_frame with Dowser
## counts: an earlier "one evil among A and B", a fresh "none among A and C".
extends SceneTree
const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_keeps_by_traits()
	_memory_drops_on_switch()
	_no_drift_no_change()
	print("Frame memory: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## How many of 60 draws swap the drifting reading, for a liar with these traits.
func _swaps(trait_value: float, switch_scapegoat: bool = false, drifting: bool = true) -> int:
	var swaps: int = 0
	for sd in range(60):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(9503, 10)
		var w = g.w
		w.rng.seed = 1000 + sd
		var n = w.evil_team()[0]
		n.traits.insight = trait_value
		n.traits.confidence = trait_value
		var goods: Array = w.living_good()
		var a: String = goods[0].id
		var b: String = goods[1].id
		var c: String = goods[2].id
		var s: String = goods[3].id
		n.info_log = [{"role": "dowser", "day": 1, "fake": true, "frame_sg": s, "data": {"group": [a, b], "count": 1}, "text": "x"}]
		var fresh: Dictionary = {"role": "dowser", "day": 2, "data": {"group": [a, c], "count": 0 if drifting else 1}, "text": "y"}
		var alt: Dictionary = {"role": "dowser", "day": 2, "data": {"group": [a, c], "count": 1}, "text": "z"}
		var alternatives := func() -> Array: return [{"entry": alt.duplicate(true), "why": "kept the story"}]
		var kept: Dictionary = Evil._keep_frame(w, n, fresh, alternatives, (goods[4].id if switch_scapegoat else s))
		if not kept.is_empty():
			swaps += 1
	return swaps

func _keeps_by_traits() -> void:
	var sharp: int = _swaps(1.0)
	var dull: int = _swaps(0.0)
	print("  swaps in 60: sharp and sure %d, dull and unsure %d" % [sharp, dull])
	_check(sharp > dull, "a sharp, sure liar keeps its story more often than a dull, unsure one")
	_check(sharp >= 45, "the sharp one nearly always does (about 90%%: %d of 60)" % sharp)
	_check(dull >= 4 and dull <= 24, "the dull one sometimes does (about 20%%: %d of 60)" % dull)

func _memory_drops_on_switch() -> void:
	_check(_swaps(1.0, true) == 0, "after the team switches scapegoat, the old readings don't bind")

func _no_drift_no_change() -> void:
	_check(_swaps(1.0, false, false) == 0, "a fresh reading that clears no one implicated before is told as it is")
