## A good NPC's sighting of themselves on a night they know they spent at home is evidence
## about whoever told it (docs/belief_model.md, Nov 12; Reasoner.direct_checks).
##   - A plain sighting or a Medium's relay is kept in the weighing, not rejected; a Night
##     Watch list is still set aside (Reasoner.direct_checks says why).
##   - In real games: the framed NPC holds it against an evil sighter; a Sleepwalker seen by an
##     honest sighter stays well short of certain (Tuning.Workshop.SLEEPWALK_SELF_DOUBT); an
##     evil Medium's invented relay counts against them (test_relay_bluff).
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")

const Game = preload("res://game/game.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const Mind = preload("res://sim/mind.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	# direct_checks on a constructed case.
	var view: Dictionary = {"cards": [
		{"id": "seen", "kind": "sighting", "source": "c", "subject": "a", "subjects": ["a"], "night": 1, "block": "hill"},
		{"id": "relayed", "kind": "sighting", "source": "d", "subject": "a", "subjects": ["a"], "night": 1, "block": "hill",
			"relay_source": "m", "relay_observed_at": {"day": 2, "phase": "night"}},
		{"id": "nw", "kind": "report", "role": "nightwatch", "source": "e", "night": 1, "data": {"block": "hill", "seen": ["a"]}}]}
	var case_data: Dictionary = {"cards": ["seen", "relayed", "nw"], "conclusion": {"type": "evil", "target": "c", "at": "Original alignment"},
		"positions": {}, "answers": {}, "temporal_positions": []}
	var knowledge: Dictionary = {"self": "a", "good": ["a"], "own_outings": {"1": false}, "own_reports": []}
	var res: Dictionary = Reasoner.direct_checks(view, case_data, knowledge)
	check(not "seen" in res.rejected, "a sighting of me on a night I was home is kept")
	check("nw" in res.rejected, "a Night Watch's list naming me on a night I was home is still set aside (SourceDoubt voids it)")
	check(not "relayed" in res.rejected, "a Medium's relay naming me on that night is kept (its relayer may be the liar)")
	check(res.objections.size() == 3, "all three still raise an objection for dialogue (%d)" % res.objections.size())
	knowledge.own_outings["1"] = true
	check(Reasoner.direct_checks(view, case_data, knowledge).objections.is_empty(), "no objection when I really was out")

	# Real games (passive play to a meeting), each a kind of case found in the Nov 12 survey
	# (then seeds 100034, 100031 and 100020); searched for, so play changes don't break them
	# (tools/fixture_seeds.gd).
	_found_case(Seeds.framed_sighting(2, false, "street"), "subject", "sighter", func(p): return p >= 0.6, "a framed person holds the planter's fake sighting against them")
	_found_case(Seeds.sleepwalker_sighting(2), "subject", "sighter", func(p): return p < 0.7, "a Sleepwalker, seen by an honest sighter, is far from sure they lied")  # (a plain liar caught this way reads near 0.9)
	_found_case(Seeds.relay(3, func(t): return t.is_evil(), true), "listener", "teller", func(p): return p >= 0.8, "an evil relayer's invented relay of the listener doesn't clear them")
	print("Self-sighting: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


func _found_case(found: Dictionary, listener_key: String, teller_key: String, ok: Callable, label: String) -> void:
	if found.is_empty():
		check(false, "%s (no seed in %d..%d has the case)" % [label, Seeds.SEEDS_FROM, Seeds.SEEDS_FROM + Seeds.SEEDS_COUNT - 1])
		return
	var g = found.g
	var listener: String = str(found[listener_key])
	var teller: String = str(found[teller_key])
	label += " (seed %d: %s on %s)" % [int(found.seed), listener, teller]
	var n = g.w.by_id.get(listener)
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	var p: float = float(g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {}).get(teller, {}).get("posterior", -1.0))
	check(ok.call(p), "%s (%.2f)" % [label, p])
