## Nov 5 evidence honesty fixes (docs/handoff_log.md, "Evidence honesty fixes"):
##   - chance_content is the share of worlds where a report's content holds, so a reading
##     the worlds can't check (a Lamplighter's count) earns its source no credit;
##   - a player vigil that should have seen a claimed walker is strong, not certain,
##     evidence against the claim (Tuning.Workshop.VIGIL_MISS, WALKER_CLAIM_*);
##   - a Medium's movement is modelled to earlier Demon victims' hearths only.
extends SceneTree

const Activity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const CaseEval = preload("res://workshop/case_eval.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_chance_content()
	_vigil_against_walker()
	_medium_hearths()
	print("Evidence honesty: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _view(homes: Dictionary, events: Array) -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": homes.get(id, "square")})
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": History.from_events(events), "world_options": {"roles": true, "identities": true, "modifiers": ["marked"]}}


func _report(id: String, source: String, role: String, night: int, data: Dictionary) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "report", "source": source, "subject": source, "subjects": [source], "role": role, "night": night,
		"data": data, "observed_at": {"day": night, "phase": "night"}}


func _chance_content() -> void:
	var view: Dictionary = _view({"a": "hill"}, [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}])
	var lamp: Dictionary = _report("lamp", "a", "lamplighter", 1, {"count": 2})
	var q_lamp: float = CaseEval.chance_content(view, lamp)
	check(q_lamp > 0.95, "a Lamplighter's count can't be checked in the worlds, so a bluff matches it for free (q=%.3f)" % q_lamp)
	var arch: Dictionary = _report("arch", "a", "archivist", 0, {"pair": ["b", "c"], "role": "poisoner"})
	check(is_equal_approx(CaseEval.chance_content(view, arch), CaseEval._chance_content_fixed(view, arch)),
		"readings about roles keep the fixed chance (their content is checked by the role constraints, not the report table)")


func _vigil_against_walker() -> void:
	var view: Dictionary = _view({"a": "hill"}, [{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}])
	var a: Dictionary = view.people[0]
	var claim: Dictionary = {"id": "claim", "fact_id": "claim", "kind": "claim", "source": "a", "subject": "a", "role": "lamplighter", "data": {}}
	var duty: Dictionary = _report("duty", "a", "lamplighter", 1, {"count": 1})
	duty["duty_only"] = true
	var empty: Dictionary = {"id": "empty", "fact_id": "empty", "kind": "coverage", "source": "player", "night": 1, "block": "market", "excluded": ["g"],
		"observed_at": {"day": 1, "phase": "night"}}
	var base: float = Activity._likelihood(view, [claim, duty], a, "good")
	var missed: float = Activity._likelihood(view, [claim, duty, empty], a, "good")
	var ratio: float = missed / maxf(base, 1e-12)
	check(base > 0.0 and missed > 0.0, "a vigil that missed a claimed Lamplighter doesn't rule the claim out (the town allows a miss)")
	check(ratio < 0.3, "but it counts strongly against it: good-world movement likelihood x%.3f (before Nov 5: about x0.37)" % ratio)
	var evil_base: float = Activity._likelihood(view, [claim, duty], a, "demon")
	var evil_missed: float = Activity._likelihood(view, [claim, duty, empty], a, "demon")
	check(evil_base <= 0.0 or evil_missed / evil_base > ratio, "a Demon bluffing the Lamplighter loses less to the same vigil than an honest one would")


func _medium_hearths() -> void:
	# g: Demon victim on night 1 (home: the Square); e: hanged on day 1 (home: the Docks).
	var view: Dictionary = _view({"a": "hill", "e": "docks", "g": "square"}, [
		{"kind": "execution", "subjects": ["e"], "at": {"day": 1}},
		{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}])
	var a: Dictionary = view.people[0]
	var claim: Dictionary = {"id": "claim", "fact_id": "claim", "kind": "claim", "source": "a", "subject": "a", "role": "medium", "data": {}}
	var seen_docks: Dictionary = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "b", "subject": "a", "subjects": ["a"], "night": 2, "block": "docks",
		"data": {}, "role": "", "observed_at": {"day": 2, "phase": "night"}}
	var seen_square: Dictionary = seen_docks.duplicate(true)
	seen_square.id = "s2"
	seen_square.fact_id = "s2"
	seen_square.block = "square"
	var at_victim: float = Activity._likelihood(view, [claim, seen_square], a, "good")
	var at_hanged: float = Activity._likelihood(view, [claim, seen_docks], a, "good")
	check(at_victim > 0.0, "a Medium seen on a Demon victim's block fits the gift")
	check(at_hanged < 0.5 * at_victim, "a Medium seen only where a hanged person lived doesn't fit the gift as well (%.4f vs %.4f)" % [at_hanged, at_victim])
