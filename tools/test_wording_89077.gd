## Wording fixes from playtest 89077 (Coroner's review, docs/playtests/89077.md):
## - the Warden and the Medium speak nights as ordinals ("the first night"), not the card's
##   "Night 1" / "night 2";
## - the Registrar's reading reads after a night phrase ("The night before you arrived, my
##   register listed..."), with no stray capital;
## - pressed with a sighting, someone who never gave an account of that night doesn't say
##   "I stand by that account";
## - a Lamplighter's count names nobody, so the reason it gives isn't that it "leaves them
##   among the likeliest": "my count of folk abroad that night doesn't square with what
##   we've been told" (Michael, Nov 17);
## - a home alibi for an earlier night says "all the second night", not "all on night 2".
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindDialogue = preload("res://sim/mind_dialogue.gd")
const C = preload("res://sim/content.gd")
const ScriptDef = preload("res://sim/script_def.gd")
## Playtest 89077's script (as test_joint_reasons uses it).
const SCRIPT: Dictionary = {"demons": ["demon"], "forced": [], "minions": ["breathstealer", "poisoner", "revenant", "scion"], "name": "Dynamic #89077",
	"secrets": ["delusional", "marked", "muddler", "sleepwalker"], "town": ["archivist", "clerk", "gravedigger", "lamplighter", "magistrate", "medium",
	"nightwatch", "psychologist", "registrar", "rumormonger", "seer", "sexton", "surveyor", "veteran", "warden"]}
const COUNT_LINE: String = "count of folk abroad that night doesn't square with what we've been told"
const COUNT_SEEDS: int = 30
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
	_home_alibi_ordinal()
	_count_line()
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

func _home_alibi_ordinal() -> void:
	var g = _game(7350)
	var w = g.w
	w.day = 4
	var bad: Array = []
	for n in w.npcs:
		var t: String = str(Mind.home_alibi(w, n, 2).get("text", ""))
		if "night 2" in t or not "the second night" in t:
			bad.append(t)
	check(bad.is_empty(), "a home alibi for an earlier night names it as an ordinal, in every voice here: " + str(bad))

## Games on 89077's script to the third day's meeting: every "taken together" reason from a
## Lamplighter's count uses the count line, never "among the likeliest".
func _count_line() -> void:
	var found: int = 0
	var wrong: Array = []
	for seed_v in range(1, COUNT_SEEDS + 1):
		var g = _play(seed_v, 3)
		if g == null or not g.w.workshop_reasons.is_valid():
			continue
		for p in g.w.living():
			var m = p.shadow if p.is_evil() and p.shadow != null else p
			m.workshop_state["reasons_pending"] = true
			g.w.workshop_reasons.call(m)
			for pid in m.workshop_state.get("reasons", {}):
				for r in m.workshop_state.reasons[pid]:
					if str(r.get("channel", "")) != "joint_contradiction" or str(r.get("role", "")) != "lamplighter":
						continue
					for k in ["why_own", "why_public"]:
						var why: String = str(r.get(k, ""))
						if COUNT_LINE in why:
							found += 1
						elif "among the likeliest" in why:
							wrong.append(why)
		if found >= 3:
			break
	check(found > 0, "a Lamplighter's count is given as a reason in the count line (%d found)" % found)
	check(wrong.is_empty(), "...and never as leaving them 'among the likeliest': " + str(wrong))

func _play(seed_v: int, day: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, 7, ScriptDef.from_dict(SCRIPT))
	var guard := 0
	while g.state != "over" and guard < 600 and not (g.state == "meeting" and g.w.day >= day):
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	return g if g.state == "meeting" and g.w.day >= day else null
