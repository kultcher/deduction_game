## Hint families (Michael, Nov 18): eleven families of about four, overlaps by design, and
## the script-aware pick for a gift in several families.
##   godot --headless --path . --script res://tools/test_hint_families.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

class FakeScript:
	var town: Array = []
	var minions: Array = []
	var demons: Array = []

class FakeWorld:
	var case_script = null
	var seed_value: int = 0

func _world(town: Array, sd: int = 1) -> FakeWorld:
	var w := FakeWorld.new()
	var s := FakeScript.new()
	s.town = town
	w.case_script = s
	w.seed_value = sd
	return w

func _init() -> void:
	check(C.HINT_PACKAGES.size() == 11, "eleven families")
	var live: Array = C.GOOD_ROLES.filter(func(r): return r != "hearthwitch")
	var missing: Array = live.filter(func(r): return C.package_of(r) == "")
	check(missing.is_empty(), "every live good gift is in at least one family (%s)" % str(missing))
	for p in C.HINT_PACKAGES:
		var n: int = C.HINT_PACKAGES[p].roles.filter(func(r): return r != "hearthwitch").size()
		check(n >= 3 and n <= 5, "%s holds 3 to 5 live gifts (%d)" % [p, n])
	# The fullest family on the script wins. Gravedigger: the dead, justice, true callings.
	var w = _world(["gravedigger", "medium", "executor", "martyr", "magistrate", "monitor"])
	check(C.hint_package(w, "gravedigger") == "the_dead", "a gift hints from its family with the most gifts on the script (%s)" % C.hint_package(w, "gravedigger"))
	w = _world(["gravedigger", "magistrate", "executor", "martyr", "monitor"])
	check(C.hint_package(w, "gravedigger") == "justice", "change the script and the pick follows (%s)" % C.hint_package(w, "gravedigger"))
	# Ties are broken by the seed, the same way every time.
	var tied: Array = ["registrar", "archivist", "monitor", "seer"]
	var picks: Dictionary = {}
	for sd in range(1, 40):
		var p: String = C.hint_package(_world(tied, sd), "registrar")
		picks[p] = true
		check(p == C.hint_package(_world(tied, sd), "registrar"), "seed %d: the tie-break is fixed for the game" % sd) if sd <= 3 else null
	check(picks.size() >= 2 and not picks.has(""), "across seeds, a tie goes either way (%s)" % str(picks.keys()))
	# Only one gift on the script in every family: no hint.
	check(C.hint_package(_world(["veteran", "seer"]), "veteran") == "", "a family with only this gift on the script gives no hint")
	check(C.hint_package(_world(["veteran", "warden"]), "veteran") == "shelter", "with a second shelter gift on the script, the hint is back")
	check(C.hint_package(_world(["registrar"], 1), "registrar") == "", "a gift in three families, alone in each, gives no hint")
	# In play: a holder's hint names the family hint_package chose.
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.detailed_logging = false
	g.new_case(692, 10)
	var any: bool = false
	for n in g.w.living_good():
		var pk: String = C.hint_package(g.w, n.role)
		if pk == "":
			continue
		n.claimed_role = ""
		n.claim_public = false
		n.max_tier = 0
		var res: Dictionary = preload("res://sim/mind.gd").answer_gift(g.w, n, 2, false)
		var hint: Array = res.facts.filter(func(f): return f.get("kind", "") == "hint")
		if not hint.is_empty():
			any = true
			check(hint[0].package == pk and n.role in hint[0].roles, "%s (%s) hints from %s" % [n.name, n.role, pk])
	check(any, "at least one holder gives a family hint in a real deal")
	print("Hint families: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
