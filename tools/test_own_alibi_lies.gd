## Belief model Phase 1 fix 3 (Project doc claude/belief-model-direction-2026-11-10.md):
## a person's own word on their night is lie-aware when they are evil. Before, an
## unquoted "I was home" from its own subject was a hard constraint in every alignment,
## so an evil subject's false alibi ruled out every night-out route: it cleared the
## Demon, and a same-night sighting plus the alibi cancelled each other.
##   - good subject: still hard (the good tell the truth about their own night);
##   - evil subject: priced like a relayed alibi (0.7 if out, 0.9 if home);
##   - someone else's alibi for the subject (a witness): unchanged, still hard.
## Both kernels (GDScript fallback and C#) are checked.
extends SceneTree

const Activity = preload("res://workshop/live_activity.gd")
const History = preload("res://workshop/live_history.gd")

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
	var a: Dictionary = view.people[0]
	var own: Dictionary = _alibi("own", "a", "a")
	var witness: Dictionary = _alibi("wit", "b", "a")
	var seen: Dictionary = {"id": "s1", "fact_id": "s1", "kind": "sighting", "source": "c", "subject": "a", "subjects": ["a"], "night": 1, "block": "square",
		"data": {}, "role": "", "hearing_weight": 1.0, "observed_at": {"day": 1, "phase": "night"}}
	for backend in ["cs", "gd"]:
		var L: Callable = func(cards: Array, al: String) -> float:
			return Activity._likelihood(view, cards, a, al) if backend == "cs" else Activity._likelihood_gd(view, cards, a, al)
		var demon_bare: float = L.call([], "demon")
		var demon_own: float = L.call([own], "demon")
		var good_own: float = L.call([own], "good")
		check(demon_own > 0.5 * demon_bare, "%s: a Demon's own home alibi doesn't rule out the kill (x%.2f of bare)" % [backend, demon_own / maxf(demon_bare, 1e-12)])
		check(good_own > 0.0 and good_own <= L.call([], "good") + 1e-9, "%s: a good subject's own alibi still holds them home" % backend)
		var good_sw: float = L.call([own, seen], "good")
		var demon_sw: float = L.call([own, seen], "demon")
		check(is_zero_approx(good_sw) and demon_sw > 0.0, "%s: own alibi + a certain sighting out: only evil fits (good %.4f, demon %.4f)" % [backend, good_sw, demon_sw])
		check(is_zero_approx(L.call([witness, seen], "demon")), "%s: a witness's alibi for someone else is unchanged (still hard)" % backend)
	print("Own alibi lies: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _view() -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id, "home": {"a": "hill", "g": "square"}.get(id, "market")})
	return {"people": people, "cards": [], "evil_count": 2, "alignment_epoch": "Original alignment", "live_activity": true,
		"timeline": History.from_events([{"kind": "demon_death", "subjects": ["g"], "at": {"day": 1}}]),
		"world_options": {"roles": true, "identities": true, "modifiers": []}}


func _alibi(id: String, source: String, subject: String) -> Dictionary:
	return {"id": id, "fact_id": id, "kind": "alibi", "source": source, "subject": subject, "subjects": [subject], "night": 1, "block": "hill",
		"data": {}, "role": "", "observed_at": {"day": 1, "phase": "night"}}
