## "Are you the <gift>?" (playtest 52102 finding 6, Michael, Nov 27):
##   - a right guess short of owning up gets the same deflection as a wrong one, not a hint;
##   - a willing NPC still owns up to a right guess;
##   - either may show the press's nervous tell, likelier on a right guess
##     (Tuning.Dialogue.PRESS_NERVES_HIDING / _HONEST x (1 - Composure) x GUESS_NERVES_STRENGTH),
##     never with full composure.
##   godot --headless --path . --script res://tools/test_guess_tell.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

const CUES = ["looks away a moment too quickly.", "shifts uneasily.", "goes a little pale.", "fumbles for an answer."]

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _world(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 10)
	g.w.day = 2
	return g.w

## A good NPC that has named nothing, its gift, and a gift it doesn't hold.
func _subject(w):
	for m in w.living_good():
		if not m.claim_public and m.max_tier < 3 and m.claimed_role == "":
			var wrong: String = ""
			for r in w.case_script.town:
				if r != m.role:
					wrong = r
					break
			return [m, m.role, wrong]
	return []

func _closed(n) -> void:
	n.traits["privacy"] = 1.0
	n.trust = 0.0
	n.pressure = 0.0
	n.role_guesses = 0
	n.pressed_today = 0

func _statement(r: Dictionary) -> String:
	for l in r.get("lines", []):
		if l is Dictionary:
			return str(l.get("statement", l.get("text", "")))
	return ""

func _tell(r: Dictionary) -> bool:
	return r.get("lines", []).any(func(l): return l is String and CUES.any(func(c): return l.ends_with(c)))

func _init() -> void:
	# Closed: a right guess reads as a wrong one does, with no hint.
	var same := 0
	var cases := 0
	var hinted := false
	for sd in range(6000, 6030):
		var w = _world(sd)
		var s: Array = _subject(w)
		if s.is_empty() or s[2] == "":
			continue
		var n = s[0]
		_closed(n)
		n.traits["composure"] = 1.0
		var right: Dictionary = Social.answer_is_role(w, n, s[1])
		var w2 = _world(sd)
		var n2 = w2.by_id[n.id]
		_closed(n2)
		n2.traits["composure"] = 1.0
		var wrong: Dictionary = Social.answer_is_role(w2, n2, s[2])
		cases += 1
		same += int(_statement(right) == _statement(wrong))
		hinted = hinted or right.get("facts", []).any(func(f): return str(f.get("kind", "")) in ["hint", "claim"])
	print("closed NPCs: a right guess read as a wrong one in %d of %d" % [same, cases])
	_check(cases >= 10 and same == cases, "closed, a right guess gets the same deflection as a wrong one")
	_check(not hinted, "and no hint or claim comes out of it")
	# Willing: a right guess owns up.
	var owned := 0
	var willing := 0
	for sd in range(6100, 6120):
		var w = _world(sd)
		var s: Array = _subject(w)
		if s.is_empty():
			continue
		var n = s[0]
		n.traits["privacy"] = 0.0
		n.trust = 1.0
		n.pressure = 1.0
		n.role_guesses = 0
		willing += 1
		var r: Dictionary = Social.answer_is_role(w, n, s[1])
		owned += int(n.max_tier >= 3 or r.get("facts", []).any(func(f): return str(f.get("kind", "")) == "claim"))
	print("willing NPCs owned up to a right guess in %d of %d" % [owned, willing])
	_check(willing >= 10 and owned * 10 >= willing * 8, "a willing NPC still owns up to a right guess")
	# The tell: rattled, likelier on a right guess; full composure, never.
	var tells := {"right": 0, "wrong": 0, "calm": 0}
	var tries := {"right": 0, "wrong": 0, "calm": 0}
	for sd in range(6200, 6260):
		for kind in ["right", "wrong", "calm"]:
			var w = _world(sd)
			var s: Array = _subject(w)
			if s.is_empty() or s[2] == "":
				continue
			var n = s[0]
			_closed(n)
			n.traits["composure"] = 1.0 if kind == "calm" else 0.0
			var r: Dictionary = Social.answer_is_role(w, n, s[2] if kind == "wrong" else s[1])
			tries[kind] += 1
			tells[kind] += int(_tell(r))
	var pr: float = float(tells["right"]) / maxf(1, tries["right"])
	var pw: float = float(tells["wrong"]) / maxf(1, tries["wrong"])
	print("tells: right %d/%d (%.2f), wrong %d/%d (%.2f), full composure %d/%d" % [tells["right"], tries["right"], pr, tells["wrong"], tries["wrong"], pw, tells["calm"], tries["calm"]])
	var want_r: float = Tuning.Dialogue.PRESS_NERVES_HIDING * Tuning.Dialogue.GUESS_NERVES_STRENGTH
	_check(tries["right"] >= 30 and pr > pw, "a tell is likelier on a right guess than a wrong one")
	_check(absf(pr - want_r) < 0.2, "about the approved rate on a right guess, at no composure (%.2f against %.2f)" % [pr, want_r])
	_check(tells["calm"] == 0, "never with full composure")
	print("Guess tell: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
