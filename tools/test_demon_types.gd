## Demon types, step 1 (docs/demon_types_plan.md): the is_demon helper, the script's demon
## types in the solver's view, and the demon's movement likelihood mixed over them.
##   godot --headless --path . --script res://tools/test_demon_types.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const Game = preload("res://game/game.gd")
const WorkshopBridge = preload("res://game/workshop_bridge.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _view(demons: Array) -> Dictionary:
	var people: Array = []
	var homes = {"a": "hill", "b": "market", "c": "square", "d": "square", "e": "square", "f": "market", "g": "docks"}
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id.to_upper(), "home": homes[id], "alive": true})
	var events: Array = [
		{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1, "phase": "night"}, "by": ""},
		{"kind": "demon_death", "subjects": ["f"], "at": {"day": 2, "phase": "night"}, "by": ""},
	]
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment",
		"live_activity": true, "timeline": History.from_events(events), "script_demons": demons,
		"world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}


func _sighting(id: String, subject: String, night: int, block: String) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "sighting", "source": "player", "subject": subject, "subjects": [subject],
		"night": night, "block": block, "data": {}, "role": "", "observed_at": {"day": night, "phase": "night"}}


func _close(x: float, y: float) -> bool:
	return absf(x - y) <= 1e-12 * maxf(1.0, maxf(absf(x), absf(y)))


func _run() -> void:
	# The helper.
	_check(C.is_demon("demon") and C.is_demon("daykiller"), "is_demon covers the Demon and the reserved day-killer")
	_check(not C.is_demon("scion") and not C.is_demon("seer"), "is_demon doesn't cover a Scion before it rises, or a town role")
	_check(C.is_day_demon("daykiller") and not C.is_day_demon("demon"), "only the day-killer is a day demon")
	_check(not C.ROLES.has("daykiller"), "the day-killer isn't a dealable role yet")

	# The share comes from the script's demons.
	_check(LiveActivity.day_demon_share(_view(["demon"])) == 0.0, "a script with only the Demon has no day-killer share")
	_check(LiveActivity.day_demon_share({}) == 0.0, "a view without script demons has no day-killer share")
	_check(LiveActivity.day_demon_share(_view(["demon", "daykiller"])) == 0.5, "two possible demons: half and half")

	# A seen on both victims' blocks on both kill nights: walker evidence.
	var cards: Array = [_sighting("s1", "a", 1, "docks"), _sighting("s2", "a", 2, "market")]
	var a: Dictionary = _view(["demon"]).people[0]
	var walk: float = LiveActivity._likelihood(_view(["demon"]), cards, a, "demon")
	var still: float = LiveActivity._likelihood(_view(["demon"]), cards, a, "minion")
	var half: float = LiveActivity._likelihood(_view(["demon", "daykiller"]), cards, a, "demon")
	var day_only: float = LiveActivity._likelihood(_view(["daykiller"]), cards, a, "demon")
	_check(walk > 0.0 and still > 0.0, "both likelihoods are positive (walk %.5f, still %.5f)" % [walk, still])
	_check(_close(half, 0.5 * walk + 0.5 * still), "the demon likelihood is the whole-case mixture of walking and staying (%.5f)" % half)
	_check(_close(day_only, still), "with only the day-killer possible, the demon moves like a minion")
	_check(walk > half and half > still, "being seen on the victims' blocks counts for less once the demon might not walk")
	_check(LiveActivity._likelihood(_view(["demon", "daykiller"]), cards, a, "minion") == still, "other alignments don't change")
	_check(LiveActivity._likelihood(_view(["demon", "daykiller"]), cards, a, "good") == LiveActivity._likelihood(_view(["demon"]), cards, a, "good"), "good likelihoods don't change")

	# The joint factor carries the same mixture in its per-person profiles.
	var f0: Array = LiveActivity.factors(_view(["demon"]), cards, {})
	var f_half: Array = LiveActivity.factors(_view(["demon", "daykiller"]), cards, {})
	_check(not f0.is_empty() and not f_half.is_empty(), "both views produce a movement factor")
	if not f0.is_empty() and not f_half.is_empty():
		var ok: bool = true
		for i in range(f0[0].profiles.size()):
			var p0: Dictionary = f0[0].profiles[i]
			var ph: Dictionary = f_half[0].profiles[i]
			ok = ok and ph.good == p0.good and ph.minion == p0.minion and _close(ph.demon, 0.5 * p0.demon + 0.5 * p0.minion)
		_check(ok, "factor profiles: the demon entry is mixed, good and minion are untouched")
		_check(f0[0].scene_tables == f_half[0].scene_tables, "trace and scene tables don't change: either demon is at the victim's house")
	var again: Array = LiveActivity.factors(_view(["demon"]), cards, {})
	_check(not again.is_empty() and again[0].profiles == f0[0].profiles, "the factor cache keeps the two views apart")

	# The bridge hands the script's demons to the solver.
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	var snap: Dictionary = WorkshopBridge.capture(g, [])
	_check(snap.rules.get("demons", []) == ["demon"], "a dealt case's snapshot lists its script's demons")

	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
