## An NPC's own "my gift may have been turned" focuses suspicion like an accepted Mistaken call
## (Michael, Nov 20): ReadingChallenges.self_doubt_floors, read by the jury's Poisoner floor.
## Everyone seen on the reader's block, by the destination rule (#445), on any night it read;
## agreement is the listener's belief in the reader; never for the listener's own words.
##   godot --headless --path . --script res://tools/test_self_doubt_poisoner.gd
extends SceneTree

const RC = preload("res://workshop/reading_challenges.gd")
const History = preload("res://workshop/live_history.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

## a reads (home docks, with b); c and d on the market, e on the hill, f on the square.
func _view(cards: Array, events: Array) -> Dictionary:
	var homes = {"a": "docks", "b": "docks", "c": "market", "d": "market", "e": "hill", "f": "square", "x": "square"}
	var people: Array = []
	for id in homes:
		people.append({"id": id, "name": id, "home": homes[id]})
	return {"people": people, "cards": cards, "evil_count": 2, "script_minions": ["poisoner"], "timeline": History.from_events(events)}

func _seen(who: String, block: String, night: int) -> Dictionary:
	return {"id": "s-%s-%s-%d" % [who, block, night], "kind": "sighting", "source": "f", "subject": who, "subjects": [who], "block": block, "night": night}

func _report(src: String, night: int) -> Dictionary:
	return {"id": "r-%s-%d" % [src, night], "kind": "report", "source": src, "role": "seer", "night": night}

func _listener(id: String = "x", susp: Dictionary = {}) -> Dictionary:
	return {"id": id, "knowledge": {"self": id, "good": []}, "suspicion": susp}

func _init() -> void:
	var doubt: Array = [{"kind": "self_doubt", "subjects": ["a"], "by": "a", "data": {"role": "seer"}}]
	var cards: Array = [_report("a", 1), _report("a", 2), _seen("c", "docks", 1), _seen("e", "docks", 2), _seen("d", "market", 1), _seen("f", "hill", 1)]
	var none: Array = RC.self_doubt_floors(_view(cards, []), {}, _listener(), cards)
	check(none.is_empty(), "no self-doubt said: no nudge")
	var floors: Array = RC.self_doubt_floors(_view(cards, doubt), {}, _listener(), cards)
	check(floors.size() == 1 and str(floors[0].source) == "a", "one reader said it: one nudge (%s)" % str(floors))
	var cands: Dictionary = floors[0].candidates if not floors.is_empty() else {}
	check(cands.has("c") and cands.has("e"), "everyone seen on the reader's block on any night it read: c (night 1) and e (night 2) (%s)" % str(cands.keys()))
	check(not cands.has("d") and not cands.has("f"), "not someone seen only setting out from their own block, nor seen elsewhere")
	check(is_equal_approx(float(floors[0].agreement), 1.0), "a trusted reader: full agreement")
	var suspected: Array = RC.self_doubt_floors(_view(cards, doubt), {}, _listener("x", {"a": 0.75}), cards)
	check(is_equal_approx(float(suspected[0].agreement), 0.25), "a suspected reader is believed less (%.2f)" % float(suspected[0].agreement))
	check(RC.self_doubt_floors(_view(cards, doubt), {}, _listener("a"), cards).is_empty(), "the reader's own words don't nudge itself")
	var no_readings: Array = [_seen("c", "docks", 1)]
	check(RC.self_doubt_floors(_view(no_readings, doubt), {}, _listener(), no_readings).is_empty(), "no reading of theirs held: nothing to read the nights from")
	var night3: Array = [_report("a", 3), _seen("c", "docks", 1)]
	check(RC.self_doubt_floors(_view(night3, doubt), {}, _listener(), night3).is_empty(), "seen on a night the reader didn't read: not a candidate")
	print("Self-doubt Poisoner: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
