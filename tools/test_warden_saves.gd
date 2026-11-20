## Warden saves (Michael, Nov 20; BACKLOG "Rapport and Warden-credit leftovers" (b) and (c)):
##   (b) an evil Warden bluff takes a quiet night as a save at the door it says it guarded,
##       tells of it with the real Warden's line, and logs it as a lie; a night someone died
##       is no save, and a living Veteran claim halves its belief as for a real Warden;
##   (c) a good Warden with a save it believes in has a small extra reason to claim.
extends SceneTree
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Tuning = preload("res://sim/tuning.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	_evil_fakes_quiet_night()
	_no_save_on_a_death_night()
	_good_save_reason_to_claim()
	print("Warden saves: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	g.w.day = 3
	return g

func _evil_warden(g):
	var e = g.w.npcs.filter(func(m): return m.is_evil() and m.alive)[0]
	e.claimed_role = "warden"
	e.claim_public = true
	e.warden_log = {"1": g.w.living_good()[0].id, "2": g.w.living_good()[1].id}
	return e

func _quiet(g, nd: int) -> void:
	g.w.dlog.add("quiet_night", "world", "", {"night": nd}, "Nobody died on night %d." % nd)

func _evil_fakes_quiet_night() -> void:
	var g = _game()
	var e = _evil_warden(g)
	_quiet(g, 2)
	var wd = C.role_def("warden")
	var saves: Dictionary = wd.told_saves(g.w, e)
	_check(saves.has("2") and saves["2"]["target"] == e.warden_log["2"] and not saves.has("1"), "an evil Warden bluff takes the quiet night as a save at its claimed door, and only that night")
	var before: int = g.w.dlog.entries.size()
	var res: Dictionary = wd.answer_gift_custom(g.w, e, true, 3, [], [], load("res://sim/mind.gd"), C.spoken_night, C.block_name)
	var said: String = " ".join(PackedStringArray(res.get("lines", []).map(func(l): return str(l.get("text", l)) if l is Dictionary else str(l))))
	var lied: bool = g.w.dlog.entries.slice(before).any(func(x): return x["type"] == "think" and x["data"].get("lie", false) and x["actor"] == e.id)
	_check(g.w.by_id[e.warden_log["2"]].name in said and lied, "it tells of the save in the Warden's words, and the lie is logged")
	var fact_save: bool = res.get("facts", []).any(func(f): return f.get("save_claim", false))
	_check(fact_save, "its card for that night carries the save claim, as a real Warden's does")
	# A living Veteran claim halves the belief, below the bar: no save told.
	var vet = g.w.living_good()[2]
	g.w.public_claims.append({"who": vet.id, "role": "veteran"})
	var halved: bool = not wd.told_saves(g.w, e).has("2")
	_check(halved == (0.5 < Tuning.Roles.WARDEN_SAVE_BELIEF_MIN), "a Veteran's claim discounts it exactly as for a real Warden")

func _no_save_on_a_death_night() -> void:
	var g = _game()
	var e = _evil_warden(g)
	_check(C.role_def("warden").told_saves(g.w, e).is_empty(), "with no quiet night, an evil Warden bluff claims no save")

func _good_save_reason_to_claim() -> void:
	var g = _game()
	var n = g.w.living_good()[0]
	n.role = "warden"
	n.claim_public = false
	var parts: Dictionary = {}
	C.role_def("warden").score_public_claim(g.w, n, parts)
	_check(not parts.has("save_to_tell"), "a good Warden with no save has no extra reason to claim")
	n.warden_saves = {"2": {"target": g.w.living_good()[1].id, "belief": 1.0}}
	parts = {}
	C.role_def("warden").score_public_claim(g.w, n, parts)
	_check(is_equal_approx(float(parts.get("save_to_tell", 0.0)), Tuning.Roles.WARDEN.save_claim_bonus), "a save it believes in is a reason to come out")
