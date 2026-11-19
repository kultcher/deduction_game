## "I've been known to sleepwalk" excuses a false "I was home" only as far as the listener
## thinks its claimant is good (Michael, Nov 19). The listener saw X out on a night X says it
## was home: a caught lie, which doubts X's word (SourceDoubt.derive). Before, a Sleepwalker
## claim cancelled that doubt outright, so an evil X caught lying could claim it and keep its
## other sightings and readings counting in full. Now the doubt stands in proportion to the
## listener's chance that X is evil.
##   godot --headless --path . --script res://tools/test_sleepwalk_bluff.gd
extends SceneTree

const SourceDoubt = preload("res://workshop/source_doubt.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var general: float = Tuning.Workshop.DOUBT_CAUGHT_ALIBI_GENERAL
	var night: float = Tuning.Workshop.DOUBT_CAUGHT_ALIBI_NIGHT
	var caught: Dictionary = _doubt(false, 0.3)
	check(is_equal_approx(float(caught.get("x:*", 0.0)), general) and is_equal_approx(float(caught.get("x:1", 0.0)), night),
		"caught lying about home, with no excuse: X's word is doubted in full (%.2f in general, %.2f that night)" % [float(caught.get("x:*", 0.0)), float(caught.get("x:1", 0.0))])
	for susp in [0.0, 0.3, 0.8]:
		var excused: Dictionary = _doubt(true, susp)
		check(is_equal_approx(float(excused.get("x:*", 0.0)), general * susp) and is_equal_approx(float(excused.get("x:1", 0.0)), night * susp),
			"with a Sleepwalker claim, the doubt stands as far as X may be evil (suspicion %.1f: %.3f in general, %.3f that night)" % [susp, float(excused.get("x:*", 0.0)), float(excused.get("x:1", 0.0))])
	var trusted: Dictionary = _doubt(true, 0.0)
	check(float(trusted.get("x:*", 0.0)) <= 1e-9, "a claimant the listener is sure is good is excused entirely, as before")
	print("Sleepwalk bluff: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


## The listener's doubt of x after seeing x out on night 1 against x's "home" that night,
## with or without x's Sleepwalker claim, at the listener's suspicion `susp` of x.
func _doubt(claim: bool, susp: float) -> Dictionary:
	var people: Array = []
	for id in ["l", "x", "a", "b", "c", "d", "e"]:
		people.append({"id": id, "name": id, "home": "square"})
	var cards: Array = [
		{"id": "seen", "kind": "sighting", "source": "l", "subject": "x", "subjects": ["x"], "night": 1, "block": "docks", "observed_at": {"day": 1, "phase": "night"}},
		{"id": "home", "kind": "alibi", "source": "x", "subject": "x", "subjects": ["x"], "night": 1, "block": "square", "observed_at": {"day": 1, "phase": "night"}, "data": {}},
	]
	if claim:
		cards.append({"id": "walk", "kind": "secret_claim", "source": "x", "subject": "x", "subjects": ["x"], "data": {"secret_kind": "sleepwalker"}})
	var plan: Dictionary = {"ready": true, "input": {"public_events": []}, "owned": {}, "owners": {},
		"prepared": {"view": {"people": people, "cards": cards, "evil_count": 2},
			"listener": {"id": "l", "knowledge": {"self": "l"}, "suspicion": {"x": susp}, "npc_trust": {}}}}
	return SourceDoubt.derive(plan).get("pre_eval", {})
