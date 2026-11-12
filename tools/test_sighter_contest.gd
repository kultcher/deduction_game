## A sighter's word is weighed by the sighter's alignment in each world (Project doc
## belief-model-direction, Nov 11; LiveActivity._sighting_contests). The frame: c says they
## saw a out on the night of the kill, and a says they stayed home.
##   - Before: a good a can't be both home and seen out, so every world with a good a scored
##     0 and the clash convicted a alone, however likely c was to be the liar.
##   - Now: in worlds where c is evil the sighting may be invented, so a good a who stayed
##     home fits (scored at 1 - EVIL_SIGHTER_TRUTH of an invented sighting); worlds where c
##     is good are unchanged.
##   - The listener's own sightings, and sightings by people who can't be evil, never move.
extends SceneTree

const Activity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")
const Caches = preload("res://workshop/caches.gd")
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
	var view: Dictionary = _view()
	var ids: Array = view.people.map(func(p): return p.id)
	var own: Dictionary = {"id": "own", "fact_id": "own", "kind": "alibi", "source": "a", "subject": "a", "subjects": ["a"], "night": 1, "block": "hill",
		"data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	var seen: Dictionary = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "c", "subject": "a", "subjects": ["a"], "night": 1, "block": "square",
		"data": {}, "role": "", "hearing_weight": 1.0, "observed_at": {"day": 1, "phase": "night"}}
	var cards: Array = [own, seen]
	var ia: int = ids.find("a")
	var ic: int = ids.find("c")
	var ie: int = ids.find("e")
	# Worlds: who is the Demon, with one Minion.
	var w_a_demon: Dictionary = {"evil": (1 << ia) | (1 << ie), "demon": ia}
	var w_c_demon: Dictionary = {"evil": (1 << ic) | (1 << ie), "demon": ic}
	var w_e_demon_c_minion: Dictionary = {"evil": (1 << ic) | (1 << ie), "demon": ie}
	var w_neither: Dictionary = {"evil": (1 << ids.find("b")) | (1 << ie), "demon": ie}

	var S: Callable = func(world: Dictionary, on: bool) -> float:
		Activity.sighter_contests_enabled = on
		Caches.clear_all()
		Activity.cache.clear()
		var f: Array = Activity.factors(view, cards, {})
		var s: float = Activity.score(world, f[0]) if not f.is_empty() else -1.0
		Activity.sighter_contests_enabled = true
		return s

	var f_on: Array = Activity.factors(view, cards, {})
	check(not f_on.is_empty() and f_on[0].has("contests"), "the factor carries a contest for a sighting by someone who could be evil")
	if not f_on.is_empty() and f_on[0].has("contests"):
		var ct: Dictionary = f_on[0].contests[0]
		check(int(ct.person) == ia and ct.sighters == [ic], "the contest is a's, over c's sighting (%s)" % [ct])
		check(float(ct.subsets[0].c) > 0.0, "C, the honest sighting's mean likelihood ratio, is positive (%.3f)" % float(ct.subsets[0].c))

	# Scores are relative to everyone good, so compare worlds against the one where the
	# subject is the Demon.
	var a_on: float = S.call(w_a_demon, true)
	var a_off: float = S.call(w_a_demon, false)
	var r_off: float = S.call(w_c_demon, false) / a_off
	var r_on: float = S.call(w_c_demon, true) / a_on
	var r_cm: float = S.call(w_e_demon_c_minion, true) / a_on
	check(r_off < 1e-6, "without contests, the sighter being the Demon can't explain the clash (%.8f of the subject-Demon world)" % r_off)
	check(r_on > 0.01, "with contests, the sighter c being the Demon explains the clash (%.4f of the subject-Demon world)" % r_on)
	check(r_cm > 0.01, "the same when c is a Minion (%.4f)" % r_cm)
	check(r_on < 1.0, "the subject stays the stronger suspect than the sighter (%.4f)" % r_on)
	check(is_equal_approx(a_on, a_off), "worlds where the sighter is good are unchanged (%.6f, %.6f)" % [a_on, a_off])
	var r_neither: float = S.call(w_neither, true) / a_on
	check(r_neither < 1e-6, "a good a and a good c: the clash still rules the world out (%.8f)" % r_neither)

	# The listener's own sighting is never contested: they know they're good.
	var mine: Dictionary = seen.duplicate()
	mine.source = "player"
	var f_mine: Array = Activity.factors(view, [own, mine], {})
	check(f_mine.is_empty() or not f_mine[0].has("contests"), "a sighting with no in-town sighter (the player's) is never contested")
	print("Sighter contest: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": {"a": "hill", "g": "square"}.get(id, "market")})
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": History.from_events([{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}]),
		"world_options": {"roles": true, "identities": true, "modifiers": []}}
