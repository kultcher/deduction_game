## A held Medium relay doesn't prove its relayer is a good Medium (see
## docs/belief_model.md, Nov 12; RoleConstraints, bluffs). In play an evil relayer may have
## invented the relay, so a world with them evil stays possible and the relay is their bluff.
## Before this, a relay cleared an evil Medium bluffer outright (43 of 47 listener readings
## under 2% in a 60-game survey).
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	# Real games, each a kind of case found in the Nov 12 survey (then seeds 100059, 100019,
	# 100042 and 100020); searched for, so play changes don't break them (fixture_seeds.gd).
	var evil_relayer = func(t): return t.is_evil()
	# What the relays do, not where the relayer ends up: the earlier check (their chance at least
	# 0.5) broke whenever other evidence moved them, as #216 and #232 each did on these games.
	var first: Dictionary = Seeds.relay(4, evil_relayer)
	_relay_case(first, "an evil relayer's relays don't clear them")
	if not first.is_empty():
		# Another game, from the next seed on, at the same day: with the Delusional self-doubt
		# (#216) few games reach day 5 holding such a relay (none in 120 seeds), and the case is
		# "another game", not "a later day".
		_relay_case(Seeds.relay(4, evil_relayer, false, int(first.seed) + 1), "nor in another game")
	# The genuine Medium over three games: its relays don't count against it. A listener can
	# have other cards against a Medium (seed 100008's Kiran reads 0.58 under connections, 0.11
	# on the earlier model), so this measures the relays alone: the Medium's chance with every
	# held card against the same refresh with its relays left out (Seeds.relay_effect). A
	# genuine relay that sits a little awkwardly with the listener's own view may cost the
	# Medium a few points (seed 100075, Nov 17: +5); one that makes it look evil is the bug.
	var genuine = func(t): return not t.is_evil() and t.role == "medium"
	var fair := 0
	var seen := 0
	var from := Seeds.SEEDS_FROM
	for i in range(3):
		var f: Dictionary = Seeds.relay(3, genuine, false, from)
		if f.is_empty():
			break
		var eff: Dictionary = Seeds.relay_effect(f.g, str(f.listener), str(f.teller))
		var shift: float = float(eff.get("with", 1.0)) - float(eff.get("without", 0.0))
		print("genuine Medium relay, seed %d: %s on %s %.2f with its relays, %.2f without" % [int(f.seed), f.listener, f.teller, float(eff.get("with", -1.0)), float(eff.get("without", -1.0))])
		seen += 1
		fair += 1 if not eff.is_empty() and shift < 0.1 else 0
		from = int(f.seed) + 1
	check(seen == 3 and fair == 3, "a genuine Medium's relays don't count against it (%d of %d games raise it under 0.1)" % [fair, seen])
	_found_case(Seeds.relay(3, evil_relayer, true), func(p): return p >= 0.8, "an invented relay of the listener, seen out while they were home, counts against its relayer")
	print("Relay bluff: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## An evil relayer's relays don't clear them: with every held card, the relayer's chance of being
## evil isn't more than 5 points below the same refresh with its relays left out
## (Seeds.relay_effect). Before Nov 12 a relay cleared its evil relayer outright.
func _relay_case(found: Dictionary, label: String) -> void:
	if found.is_empty():
		check(false, "%s (no seed searched has the case)" % label)
		return
	var eff: Dictionary = Seeds.relay_effect(found.g, str(found.listener), str(found.teller))
	var with_r: float = float(eff.get("with", -1.0))
	var without: float = float(eff.get("without", -1.0))
	check(not eff.is_empty() and with_r >= without - 0.05, "%s (seed %d: %s on %s, %.2f with the relays, %.2f without)" % [label, int(found.seed), found.listener, found.teller, with_r, without])


func _found_case(found: Dictionary, ok: Callable, label: String) -> void:
	if found.is_empty():
		check(false, "%s (no seed searched has the case)" % label)
		return
	var g = found.g
	var listener: String = str(found.listener)
	var teller: String = str(found.teller)
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


## The listener's posterior on the teller, from a fresh refresh.
func _posterior(found: Dictionary) -> float:
	var g = found.g
	var n = g.w.by_id.get(str(found.listener))
	var key: String = n.id + ":good"
	g._workshop_evaluations.erase(key)
	var was_defer: bool = g.w.defer_beliefs
	g.w.defer_beliefs = false
	Mind.refresh_beliefs(g.w, n, " (test)")
	g.w.defer_beliefs = was_defer
	return float(g._workshop_evaluations.get(key, {}).get("proposal", {}).get("effects", {}).get(str(found.teller), {}).get("posterior", -1.0))
