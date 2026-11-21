## A sighter's word is weighed by the sighter's alignment in each world (see
## docs/belief_model.md, Nov 11; LiveActivity._sighting_contests). The frame: c says they
## saw a out on the night of the kill, and a says they stayed home.
##   - Before: a good a can't be both home and seen out, so every world with a good a scored
##     0 and the clash convicted a alone, however likely c was to be the liar.
##   - Now: in worlds where c is evil the sighting may be invented, so a good a who stayed
##     home fits (scored at 1 - EVIL_SIGHTER_TRUTH of an invented sighting); worlds where c
##     is good are unchanged.
##   - The listener's own sightings, and sightings by people who can't be evil, never move.
##   - Since Nov 17 a good a's own "home" may itself be false (GOOD_OWN_ALIBI_OUT), so a
##     good a and a good c no longer score 0: they score that floor. The checks compare
##     against it.
##   - These checks isolate the contest: the sighting placing its teller (Michael, Nov 20;
##     LiveActivity.teller_place) is held off for them, and checked on its own at the end
##     (_teller_place_check).
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
	Activity.teller_place = false
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
	# The floor: a good a and a good c, explained only by a good a's false "home".
	var r_floor: float = S.call(w_neither, true) / a_on
	check(is_equal_approx(r_off, r_floor), "without contests, the sighter being the Demon explains nothing beyond a good a's false 'home' (%.6f, floor %.6f)" % [r_off, r_floor])
	check(r_on > 2.0 * r_floor, "with contests, the sighter c being the Demon explains the clash (%.4f of the subject-Demon world, floor %.4f)" % [r_on, r_floor])
	check(r_cm > 2.0 * r_floor, "the same when c is a Minion (%.4f)" % r_cm)
	check(r_on < 1.0, "the subject stays the stronger suspect than the sighter (%.4f)" % r_on)
	check(is_equal_approx(a_on, a_off), "worlds where the sighter is good are unchanged (%.6f, %.6f)" % [a_on, a_off])
	check(r_floor > 0.0 and r_floor < Tuning.Workshop.GOOD_OWN_ALIBI_OUT, "a good a and a good c: only a good a's false 'home' explains the clash, a small share (%.6f)" % r_floor)

	# The listener's own sighting is never contested: they know they're good.
	var mine: Dictionary = seen.duplicate()
	mine.source = "player"
	var f_mine: Array = Activity.factors(view, [own, mine], {})
	check(f_mine.is_empty() or not f_mine[0].has("contests"), "a sighting with no in-town sighter (the player's) is never contested")
	_converted_checks()
	Activity.teller_place = true
	_teller_place_check(view, cards, w_a_demon, w_c_demon, w_neither, r_on)
	_teller_place_converted()
	print("Sighter contest: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": {"a": "hill", "g": "square"}.get(id, "market")})
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": History.from_events([{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}]),
		"world_options": {"roles": true, "identities": true, "modifiers": []}}


## With the sighting placing its teller (Michael, Nov 20): c's street sighting on the Square
## says c was out there that night, which a good c with no reason to walk rarely is, so c
## bears more of the clash than the contest alone gives it.
func _teller_place_check(view: Dictionary, cards: Array, w_a_demon: Dictionary, w_c_demon: Dictionary, w_neither: Dictionary, r_contest: float) -> void:
	Caches.clear_all()
	Activity.cache.clear()
	var f: Array = Activity.factors(view, cards, {})
	var r_tp: float = Activity.score(w_c_demon, f[0]) / Activity.score(w_a_demon, f[0]) if not f.is_empty() else -1.0
	check(r_tp > r_contest, "a sighting places its teller: c, out on the Square by its own word, bears more of the clash (%.4f of the subject-Demon world, against %.4f by the contest alone)" % [r_tp, r_contest])
	# From c's window (c lives on the Market) the sighting puts c at home, which a good c
	# fits unless it walked elsewhere: it weighs on c far less than the street sighting does.
	# Against the both-good world, with the rule on and off.
	var lift = func(cs: Array) -> float:
		var out: Array = []
		for on in [true, false]:
			Activity.teller_place = on
			Caches.clear_all()
			Activity.cache.clear()
			var ff: Array = Activity.factors(view, cs, {})
			out.append(Activity.score(w_c_demon, ff[0]) / Activity.score(w_neither, ff[0]) if not ff.is_empty() else -1.0)
		Activity.teller_place = true
		return out[0] / out[1] if out[1] > 0.0 else -1.0
	var window: Array = cards.map(func(c): return c.duplicate(true))
	window[1].block = "market"
	var lift_street: float = lift.call(cards)
	var lift_window: float = lift.call(window)
	check(lift_window >= 1.0 and lift_window < lift_street, "from the teller's own window it weighs on c far less than a street sighting does (x%.2f, against x%.2f)" % [lift_window, lift_street])
	Caches.clear_all()
	Activity.cache.clear()


## Codex on #474: a sighting c told while the curse had converted them, about a night before
## it, is an evil teller's word in the world where c is the converted person, so it doesn't
## place c that night (Chronology.statement_time, as the contests read it).
func _teller_place_converted() -> void:
	var view: Dictionary = _view()
	view.timeline = History.from_events([{"kind": "demon_death", "subjects": ["g"], "at": {"day": 3}}])
	view["chronology"] = {"epochs": {"Original alignment": 0}, "curse": {"from": 10, "until": 1000, "executed": "f",
		"yes_voters": ["c"], "alive": ["a", "b", "c", "d", "e", "g"]}}
	var ids: Array = view.people.map(func(p): return p.id)
	var own: Dictionary = {"id": "own", "fact_id": "own", "kind": "alibi", "source": "a", "subject": "a", "subjects": ["a"], "night": 1, "block": "hill",
		"data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
	var seen: Dictionary = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "c", "subject": "a", "subjects": ["a"], "night": 1, "block": "square",
		"data": {}, "role": "", "hearing_weight": 1.0, "observed_at": {"day": 3, "phase": "night"}}
	var cards: Array = [own, seen]
	var w_conv: Dictionary = {"evil": (1 << ids.find("f")) | (1 << ids.find("e")), "demon": ids.find("e"), "converted": ids.find("c")}
	var scores: Array = []
	for on in [true, false]:
		Activity.teller_place = on
		Caches.clear_all()
		Activity.cache.clear()
		var f: Array = Activity.factors(view, cards, {})
		# Against a world where c is evil from the start, which no sighting of c's places either.
		var w_c_minion: Dictionary = {"evil": (1 << ids.find("c")) | (1 << ids.find("e")), "demon": ids.find("e")}
		scores.append(Activity.score(w_conv, f[0]) / Activity.score(w_c_minion, f[0]) if not f.is_empty() else -1.0)
	Activity.teller_place = true
	Caches.clear_all()
	Activity.cache.clear()
	check(scores[0] > 0.0 and is_equal_approx(scores[0], scores[1]), "a sighting told while converted, about a night before, doesn't place its teller where they're the converted one (%s of the c-evil world, as without the rule %s)" % [str(scores[0]), str(scores[1])])


## The Revenant's curse converts a good yes-voter (here c) from day 2's evening. In a world
## where c is the converted one, c is evil only for what they told while converted
## (Chronology.statement_time), so only those sightings may be invented.
func _converted_checks() -> void:
	for cursed_told in [true, false]:
		var view: Dictionary = _view()
		view.timeline = History.from_events([{"kind": "demon_death", "subjects": ["g"], "at": {"day": 3}}])
		view["chronology"] = {"epochs": {"Original alignment": 0}, "curse": {"from": 10, "until": 1000, "executed": "f",
			"yes_voters": ["c"], "alive": ["a", "b", "c", "d", "e", "g"]}}
		var ids: Array = view.people.map(func(p): return p.id)
		var told: Dictionary = {"day": 3, "phase": "night"} if cursed_told else {"day": 1, "phase": "night"}
		var night: int = 3 if cursed_told else 1
		var own: Dictionary = {"id": "own", "fact_id": "own", "kind": "alibi", "source": "a", "subject": "a", "subjects": ["a"], "night": night, "block": "hill",
			"data": {}, "role": "", "observed_at": {"day": night, "phase": "night"}}
		var seen: Dictionary = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "c", "subject": "a", "subjects": ["a"], "night": night, "block": "square",
			"data": {}, "role": "", "hearing_weight": 1.0, "observed_at": told}
		var cards: Array = [own, seen]
		var f: Array = Activity.factors(view, cards, {})
		var label: String = "told while converted" if cursed_told else "told before the curse"
		check(not f.is_empty() and f[0].has("contests"), "curse, %s: a contest exists" % label)
		if f.is_empty() or not f[0].has("contests"):
			continue
		var conv: Array = f[0].contests[0].get("converted", [])
		check((conv.size() == 1 and not conv[0].is_empty()) == cursed_told, "curse, %s: a converted-sighter alternative exists only for cursed testimony" % label)
		var ia: int = ids.find("a")
		var ic: int = ids.find("c")
		var ie: int = ids.find("e")
		var i_f: int = ids.find("f")
		var w_conv: Dictionary = {"evil": (1 << i_f) | (1 << ie), "demon": ie, "converted": ic}
		var w_a: Dictionary = {"evil": (1 << ia) | (1 << i_f), "demon": ia}
		var r: float = Activity.score(w_conv, f[0]) / Activity.score(w_a, f[0])
		# The same world with c never turned: a good a's false "home" is all that's left.
		var r_base: float = Activity.score({"evil": (1 << i_f) | (1 << ie), "demon": ie}, f[0]) / Activity.score(w_a, f[0])
		if cursed_told:
			check(r > 0.01, "curse, %s: the converted sighter can explain the clash (%.4f of the subject-Demon world)" % [label, r])
		else:
			check(is_equal_approx(r, r_base), "curse, %s: testimony from their good days stays honest (%.6f, as with c never turned %.6f)" % [label, r, r_base])
