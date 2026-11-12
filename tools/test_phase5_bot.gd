## Phase 5 of the belief-model plan (Project doc belief-model-direction): the bot reads the
## demon type from what it accepts, and the Workshop's compile cache keys on the town's mix.
##   - CaseEval's compile cache keys on the demon-type declaration: before the fix a second
##     evaluation under the other kind reused the first kind's movement scores, so every
##     Hexer:walker Bayes factor came out exactly 1 (and in-game declarations could keep
##     stale movement scores).
##   - Analyst.demon_type_odds reads a real Bayes factor on two-kind games.
extends SceneTree

const T = preload("res://tools/test_demon_declaration.gd")
const Analyst = preload("res://tools/analyst.gd")
const Declaration = preload("res://game/demon_declaration.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var t = T.new()
	var read := 0
	var games := 0
	var leaning_right := 0
	for force in ["demon", "daykiller"]:
		for s in [30, 31, 32, 33]:
			var g = t._to_meeting(s, force)
			if g.state != "meeting":
				continue
			var st: Dictionary = Analyst.new_state(1.0)
			Analyst.belief(g, st, RandomNumberGenerator.new())
			if st.accepted.is_empty():
				continue
			games += 1
			var bf: float = Analyst.demon_type_odds(g, st)
			var again: float = Analyst.demon_type_odds(g, st)
			var truth: String = Declaration.type_of(g.w.by_id[g.w.demon_id].role)
			print("  %s seed %d: Hexer:walker %.3f" % [truth, s, bf])
			if not is_equal_approx(bf, 1.0):
				read += 1
			if (bf > 1.0) == (truth == "hexer"):
				leaning_right += 1
			check(is_equal_approx(bf, again), "%s seed %d: the odds are repeatable (cache hits agree)" % [truth, s])
	check(games >= 4, "enough two-kind games reach a meeting with accepted cards (%d)" % games)
	check(read == games, "every game gives a real Bayes factor, never the stale-cache 1.0 (%d of %d)" % [read, games])
	print("  odds lean the true way in %d of %d games" % [leaning_right, games])
	print("Phase 5 bot: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
