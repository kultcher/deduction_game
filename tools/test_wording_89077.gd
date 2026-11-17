## Wording fixes from playtest 89077 (Coroner's review, docs/playtests/89077.md):
## - the Warden and the Medium speak nights as ordinals ("the first night"), not the card's
##   "Night 1" / "night 2";
## - the Registrar's reading reads after a night phrase ("The night before you arrived, my
##   register listed..."), with no stray capital;
## - pressed with a sighting, someone who never gave an account of that night doesn't say
##   "I stand by that account".
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const C = preload("res://sim/content.gd")
var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _text(r: Dictionary) -> String:
	return " ".join(PackedStringArray(r.get("lines", []).filter(func(l): return l is Dictionary).map(func(l): return str(l.get("text", "")))))

func _game(seed_value: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_value, 7)
	return g

func _init() -> void:
	_warden()
	_medium()
	_registrar()
	_pressed_first()
	print("Wording 89077: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _warden() -> void:
	var g = _game(7105)
	var w = g.w
	var wd = w.npcs.filter(func(x): return not x.is_evil())[0]
	wd.role = "warden"
	wd.claimed_role = "warden"
	wd.claim_public = true
	var others: Array = w.npcs.filter(func(x): return x != wd)
	wd.warden_log = {"1": others[0].id, "2": others[1].id}
	w.day = 3
	var t: String = _text(Mind.answer_gift(w, wd, 3))
	check(not ("Night 1" in t or "night 1" in t or "night 2" in t), "the Warden never says 'night 1' or 'night 2': " + t)
	check("the first night" in t.to_lower() and "last night" in t, "...but 'the first night' and 'last night': " + t)

func _medium() -> void:
	var g = _game(7105)
	var w = g.w
	var dead = w.npcs[0]
	var who = w.npcs[1]
	var medium = C.role_def("medium")
	var seen: String = medium.medium_text(w, dead, {"type": "sighting", "who": who.id, "block": who.home_block, "night": 2})
	var guard: String = medium.medium_text(w, dead, {"type": "guard", "who": who.id, "night": 1})
	check("the second night" in seen and not "night 2" in seen, "a Medium's relayed sighting names the night as an ordinal: " + seen)
	check("the first night" in guard and not "night 1" in guard, "a Medium's relayed guard names the night as an ordinal: " + guard)

func _registrar() -> void:
	# The reading text is built in one place; check its form there.
	var src: String = FileAccess.get_file_as_string("res://sim/roles/registrar.gd")
	check(not src.contains("\"My register lists"), "the Registrar's reading text has no stray capital (it follows a night phrase)")
	check(src.contains("my register listed three roles"), "...and reads in the past, like the other readings")

func _pressed_first() -> void:
	var g = _game(7350)
	var w = g.w
	w.day = 2
	var n = w.living_good()[0]
	n.secret = {}
	n.secret_mod = ""
	n.claimed_role = ""
	n.max_tier = 0
	n.history[w.time_key(1, C.NIGHT)] = "home:" + n.home_block
	n.dialogue_memory = {}
	var first: String = _text(MindDialogue._answer_pressed_night(w, n, 1))
	check("at home" in first and not "stand by" in first and not "unchanged" in first and not "isn't changing" in first,
		"pressed for the first time, a home alibi doesn't claim an earlier account: " + first)
	var g2 = _game(7350)
	var w2 = g2.w
	w2.day = 2
	var m = w2.living_good()[0]
	m.secret = {}
	m.secret_mod = ""
	m.claimed_role = ""
	m.max_tier = 0
	m.history[w2.time_key(1, C.NIGHT)] = "home:" + m.home_block
	m.dialogue_memory = {"night_accounts": {"1": {"kind": "alibi", "home": true}}}
	var again: String = _text(MindDialogue._answer_pressed_night(w2, m, 1))
	check("at home" in again, "with an earlier account, the home alibi still stands: " + again)
