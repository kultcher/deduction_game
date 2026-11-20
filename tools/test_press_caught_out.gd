## BACKLOG "A whereabouts contradiction gets an irrelevant gift refusal" (78148, Kiran;
## [decided]): Beadle's half. A pressed case whose cards place its subject out that night
## (`contradiction`, from GameConversation.press_contradiction) is answered by who they are:
##   - a good NPC out on its own business says "Fine, I was out" and, open enough, why;
##     closed, only that, and never "I was at home";
##   - the truly home stand by being home;
##   - an unaware Sleepwalker doesn't own the night;
##   - evil with nothing to claim owns the night too, and says only that being out isn't
##     wicked (the caught-out ladder, Michael, Nov 19);
##   - without the context, the usual night answer.
##   godot --headless --path . --script res://tools/test_press_caught_out.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Conv = preload("res://game/game_conversation.gd")
const Mind = preload("res://sim/mind.gd")

const TRAPPED = "Fine, I was out. Doesn't mean I was doing anything wrong."

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _setup(evil: bool = false) -> Array:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_logs"
	g.new_case(13910, 10)
	g.w.day = 3
	var goods: Array = g.w.living_good()
	var n = null
	if evil:
		n = g.w.evil_team()[0]
	else:
		for x in goods:
			if not C.ROLES[x.role].get("night_walk", false) and x.secret_mod != "sleepwalker":
				n = x
				break
	return [g, n, goods.filter(func(x): return x != n)[0]]


## `n` out on `block` the first night on a private errand, with an open or closed mood.
func _out(g, n, block: String, open: bool) -> void:
	n.history[g.w.time_key(1, C.NIGHT)] = "night:" + block
	n.secret = {"kind": "errand", "text": "was fetching medicine", "me": "was fetching medicine for my mother"}
	n.trust = 1.0 if open else 0.0
	n.pressure = 1.0 if open else 0.0
	n.traits["privacy"] = 0.0 if open else 1.0


## Presses `n` with a case citing their home alibi and a vigil that saw them leave.
func _press(g, n, with_context: bool = true) -> Dictionary:
	var alibi: Dictionary = {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: at home the first night." % n.name}
	var seen: Dictionary = {"kind": "sighting", "subject": [n.id], "block": n.home_block, "source": "player", "day": 1, "phase": C.NIGHT, "vigil": true, "text": "Night 1 vigil: you saw %s go out." % n.name}
	var nums: Array = [alibi, seen].map(func(c): return g.add_card(c))
	var pc: Dictionary = {"kind": "deduction", "conclusion": {"type": "suspicious", "a": n.id}, "subject": [n.id], "supports": nums, "text": "A case"}
	pc["support_cards"] = g.all_receipts().filter(func(x): return x["n"] in nums)
	if with_context:
		var contra: Dictionary = Conv.press_contradiction(g, n, pc)
		if not contra.is_empty():
			pc["contradiction"] = contra
	return Mind.press(g.w, n, pc, g.known_haunts)


func _statements(r: Dictionary) -> Array:
	return r.get("lines", []).filter(func(l): return l is Dictionary).map(func(l): return str(l.get("statement", l.get("text", ""))))


func _home(r: Dictionary, n) -> bool:
	return r.get("facts", []).any(func(f): return f.get("kind", "") == "alibi" and f.get("source", "") == n.id and f.get("home", false)) \
		or _statements(r).any(func(t): return "at home" in t)


func _init() -> void:
	# Open: owns the night and says why.
	var s: Array = _setup()
	var g = s[0]
	var n = s[1]
	_out(g, n, n.home_block, true)
	var r: Dictionary = _press(g, n)
	print("open: %s" % str(_statements(r)))
	check(_statements(r).size() >= 1 and _statements(r)[0] == TRAPPED, "a good NPC out on its own business says 'Fine, I was out'")
	check(r.get("facts", []).any(func(f): return f.get("kind", "") == "secret" and f.get("owner", "") == n.id and int(f.get("day", -1)) == 1), "open enough, it says why: its errand that night")
	check(not _home(r, n), "and it doesn't claim to have been home")
	# Closed: only that it was out.
	s = _setup()
	g = s[0]
	n = s[1]
	_out(g, n, n.home_block, false)
	r = _press(g, n)
	print("closed: %s" % str(_statements(r)))
	check(_statements(r) == [TRAPPED] and not _home(r, n), "closed, it says only that it was out, and not that it was home")
	check(r.get("facts", []).any(func(f): return f.get("kind", "") == "alibi" and f.get("source", "") == n.id and not f.get("home", true) and int(f.get("day", -1)) == 1), "and the player's card says it admits being out that night")
	# The admission sticks: asked about that night again, it doesn't go back to "at home" (Codex on #330).
	var again: Dictionary = Mind.MindAnswers.answer_night(g.w, n, 1)
	var again_said: Array = again.get("lines", []).filter(func(l): return l is Dictionary).map(func(l): return str(l.get("statement", l.get("text", ""))))
	check(not again_said.any(func(t): return "at home" in t) and not again.get("facts", []).any(func(f): return f.get("kind", "") == "alibi" and f.get("home", false)), "asked about that night again, it doesn't say it was home (%s)" % str(again_said))
	# Without the context: the usual night answer (not the caught-out line).
	s = _setup()
	g = s[0]
	n = s[1]
	_out(g, n, n.home_block, false)
	r = _press(g, n, false)
	check(not (TRAPPED in _statements(r)), "without the context, the usual night answer (%s)" % str(_statements(r)))
	# Truly home: stands by it.
	s = _setup()
	g = s[0]
	n = s[1]
	n.history[g.w.time_key(1, C.NIGHT)] = "home:" + n.home_block
	r = _press(g, n)
	check(not (TRAPPED in _statements(r)) and _home(r, n), "the truly home stand by being home (%s)" % str(_statements(r)))
	# An unaware Sleepwalker remembers being home.
	s = _setup()
	g = s[0]
	n = s[1]
	_out(g, n, n.home_block, true)
	n.secret = {}
	n.secret_mod = "sleepwalker"
	r = _press(g, n)
	check(not (TRAPPED in _statements(r)), "an unaware Sleepwalker doesn't own the night (%s)" % str(_statements(r)))
	# Evil keeps its cover.
	s = _setup(true)
	g = s[0]
	n = s[1]
	n.history[g.w.time_key(1, C.NIGHT)] = "night:" + n.home_block
	r = _press(g, n)
	check(TRAPPED in _statements(r) and not _home(r, n) and r.facts.any(func(f): return f.get("kind", "") == "alibi" and not f.get("home", true) and f.get("excuse", "") == "not_wicked"),
		"evil with nothing to claim owns the night: being out isn't wicked (%s)" % str(_statements(r)))
	print("Press caught out: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
