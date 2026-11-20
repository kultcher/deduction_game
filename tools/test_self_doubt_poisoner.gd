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
	var v_none: Dictionary = _view(cards, doubt)
	v_none.script_minions = ["scion", "brute"]
	check(RC.self_doubt_floors(v_none, {}, _listener(), cards).is_empty(), "no Poisoner on the script: no one is pointed at, as for the Mistaken call")
	_in_play()
	print("Self-doubt Poisoner: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## In play (Lantern's pin): one listener holds R's reading and its own sighting of X on R's
## block that night, and hears R's self-doubt. With the nudge, X's suspicion rises; everyone
## else's, R's reading's pair included, is exactly what it is without it (R's readings are
## discounted once, by SourceDoubt, not again here).
func _in_play() -> void:
	# The refresh caches its result, so each side gets a fresh, identical game.
	var off: Dictionary = _played(false)
	var on: Dictionary = _played(true)
	if off.is_empty() or on.is_empty():
		return
	var x: String = str(on["x"])
	var s_off: Dictionary = off["suspicion"]
	var s_on: Dictionary = on["suspicion"]
	print("X %s: %.4f without, %.4f with" % [x, float(s_off.get(x, 0.0)), float(s_on.get(x, 0.0))])
	check(float(s_on.get(x, 0.0)) > float(s_off.get(x, 0.0)), "the person seen on the reader's block is suspected more (%.3f from %.3f)" % [float(s_on.get(x, 0.0)), float(s_off.get(x, 0.0))])
	var moved: Array = s_on.keys().filter(func(p): return p != x and absf(float(s_on[p]) - float(s_off.get(p, 0.0))) > 1e-9)
	check(moved.is_empty(), "nobody else moves, the reading's pair included: R's readings aren't discounted twice (%s)" % str(moved))

func _played(nudge: bool) -> Dictionary:
	var Game = load("res://game/game.gd")
	var Mind = load("res://sim/mind.gd")
	var C = load("res://sim/content.gd")
	RC.self_doubt_poisoner = nudge
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	var w = g.w
	if w.case_script != null and not ("poisoner" in w.case_script.minions):
		w.case_script.minions.append("poisoner")
	w.defer_beliefs = false
	var goods: Array = w.living_good()
	var r = goods[0]
	var l = goods[1]
	var others: Array = w.living().filter(func(n): return n != r and n != l)
	var xs: Array = others.filter(func(n): return n.home_block != r.home_block)
	if xs.is_empty():
		check(false, "the town has someone living off the reader's block")
		return {}
	var x = xs[0]
	var pair: Array = others.filter(func(n): return n != x).slice(0, 2).map(func(n): return n.id)
	r.role = "seer"
	r.claimed_role = "seer"
	r.claim_public = true
	Mind.apply_info(w, l, r, {"role": "seer", "day": 1, "night": 1, "data": {"pair": pair, "yes": true}, "true": true, "text": "I looked at them: one of them reads as the Demon"}, 1.0)
	l.beliefs.append({"kind": "saw", "who": x.id, "loc": "", "block": r.home_block, "day": 1, "phase": C.NIGHT, "how": "street", "detail": "street"})
	w.public_event("self_doubt", [r.id], r.id, {"role": "seer"})
	l.suspicion[r.id] = 0.0
	Mind.refresh_beliefs(w, l, "test: the reader's self-doubt heard")
	RC.self_doubt_poisoner = true
	return {"x": x.id, "suspicion": l.suspicion.duplicate()}
