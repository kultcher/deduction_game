## A held Medium relay doesn't prove its relayer is a good Medium (see
## docs/belief_model.md, Nov 12; RoleConstraints, bluffs). In play an evil relayer may have
## invented the relay, so a world with them evil stays possible and the relay is their bluff.
## Before this, a relay cleared an evil Medium bluffer outright (43 of 47 listener readings
## under 2% in a 60-game survey).
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")

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
	# A genuine Medium's true relay doesn't count against it, in a town built by hand rather
	# than found by a seed search (Seneschal, Nov 18: the search tripped on unrelated changes
	# three times that day, landing on a poisoned Medium's invented relay, a frame that placed
	# the Medium elsewhere, and a Medium communing on the street of that night's killing).
	# Measured on the relays alone: the Medium's chance with every held card against the same
	# refresh with its relays left out (Seeds.relay_effect). A genuine relay that sits a little
	# awkwardly with the listener's own view may cost the Medium a few points; one that makes it
	# look evil is the bug.
	var shifts: Array = []
	for seed in [692, 900, 42]:
		for subject_evil in [false, true]:
			var eff: Dictionary = _genuine_relay(seed, subject_evil)
			var shift: float = float(eff.get("with", 1.0)) - float(eff.get("without", 0.0))
			print("genuine Medium relay, seed %d, sighting of %s: %.2f with its relay, %.2f without" % [seed, "an evil" if subject_evil else "a good", float(eff.get("with", -1.0)), float(eff.get("without", -1.0))])
			if eff.get("relayed", 0) != 1 or shift >= 0.1:
				shifts.append("%d/%s %+.2f" % [seed, "evil" if subject_evil else "good", shift])
	check(shifts.is_empty(), "a genuine Medium's true relay doesn't count against it (six built towns; failing: %s)" % ", ".join(PackedStringArray(shifts)))
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


## A town built by hand on `seed`'s deal (no play): a good Medium (the town's own if it
## has one, else a good made one, with the Medium on the script) whose neighbour the Demon killed
## on the first night relays, on the second night, what the dead saw on the first: a good person, or an
## evil one, out on their own street. A living good listener hears it. The relay's effect on
## the listener's chance of the Medium being evil (Seeds.relay_effect).
func _genuine_relay(seed: int, subject_evil: bool) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(seed, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var mediums: Array = goods.filter(func(n): return n.role == "medium")
	var medium = mediums[0] if not mediums.is_empty() else goods[0]
	if medium.role != "medium":
		medium.role = "medium"
		if "medium" not in w.case_script.town:
			w.case_script.town.append("medium")
	var others: Array = goods.filter(func(n): return n != medium)
	var dead = others[0]
	var listener = others[1]
	var subject = w.evil_team()[0] if subject_evil else others[2]
	# The neighbour is the Demon's victim of the first night (a Medium communes only with
	# those, sim/roles/medium.gd), announced at the second dawn as the game does.
	w.day = 1
	w._kill(dead)
	w.day = 2
	g._facts([{"kind": "death", "subject": [dead.id], "block": dead.home_block, "source": "player", "night": 1, "text": "%s was killed by the demon on night 1." % dead.name}])
	var entry: Dictionary = {"day": 2, "phase": 3, "role": "medium", "shared": true, "true": true,
		"data": {"dead": dead.id, "item": {"type": "sighting", "who": subject.id, "block": subject.home_block, "night": 0}},
		"text": "communing with the dead at %s's hearth, I learned they saw %s out the night before you arrived" % [dead.name, subject.name]}
	medium.info_log.append(entry)
	Mind.apply_info(w, listener, medium, entry, 0.8)
	return Seeds.relay_effect(g, listener.id, medium.id)


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
