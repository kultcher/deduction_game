## Evil meetings out of sight (BACKLOG "Evil meetings are over-weighted and always visible",
## Michael: confer after the player commits):
## - before the player picks a place (the pairing the player sees), two evil members get no
##   bonus for their unshared word: they pair only as any two neighbours would;
## - after the player has gone, teammates with word for each other confer unseen, and the
##   word passes; each NPC still talks at most once a day.
extends SceneTree
const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")
const Evil = preload("res://sim/evil.gd")
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
	_bonus()
	_conference()
	print("Evil conference: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

## A case with two idle evil members, one holding word the other lacks.
func _setup(seed: int) -> Dictionary:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed, 10)
	var w = g.w
	w.day = 1
	var team: Array = w.evil_team()
	if team.size() < 2:
		return {}
	var a = team[0]
	var b = team[1]
	for m in team:
		m.working = false
		m.pair_day = -1
		m.busy_with = ""
	for m in team.slice(2):
		m.pair_day = w.day  # only a and b are free to meet
	var good = w.living_good()[0]
	Evil.add_intel(w, a, "walker", good.id, 0.5, "saw them out on night 0")
	return {"w": w, "a": a, "b": b}

func _bonus() -> void:
	var s: Dictionary = _setup(9901)
	var w = s.w
	var before: float = Social.news_bonus(w, s.a, s.b, true)
	var after: float = Social.news_bonus(w, s.a, s.b, false)
	_check(is_zero_approx(before), "before the player chooses, two evil members get no news bonus (%.2f)" % before)
	_check(after >= Tuning.Social.NEWS_BONUS_EVIL - 1e-6, "after it, they do (%.2f)" % after)

func _conference() -> void:
	var met: int = 0
	var shared_ok: int = 0
	var seen: int = 0
	var ran: int = 0
	for sd in range(40):
		var s: Dictionary = _setup(9900 + sd)
		if s.is_empty():
			continue
		ran += 1
		var w = s.w
		var n_before: int = w.dlog.entries.size()
		w._evil_conference("")
		var convs: Array = w.dlog.entries.slice(n_before).filter(func(e): return e["type"] == "npc_conversation")
		if convs.is_empty():
			continue
		met += 1
		var c: Dictionary = convs[0]
		if bool(c["data"].get("visible", true)):
			seen += 1
		if Evil.unshared_intel(s.a, s.b) == 0 and int(s.a.pair_day) == w.day and int(s.b.pair_day) == w.day:
			shared_ok += 1
	print("  %d cases: %d conferred (%d seen), word passed and both talked out for the day in %d" % [ran, met, seen, shared_ok])
	_check(ran >= 30, "enough cases (%d)" % ran)
	_check(met >= ran / 4, "teammates with word for each other often confer once the player has gone (%d of %d)" % [met, ran])
	_check(seen == 0, "never where the player can see")
	_check(shared_ok == met, "the word passes, and each has talked for the day")
	# Nobody free, nobody meets.
	var s2: Dictionary = _setup(9950)
	s2.b.pair_day = s2.w.day
	var n0: int = s2.w.dlog.entries.size()
	s2.w._evil_conference("")
	_check(not s2.w.dlog.entries.slice(n0).any(func(e): return e["type"] == "npc_conversation"), "a teammate who has already talked today doesn't confer again")
