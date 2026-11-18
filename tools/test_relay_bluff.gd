## A held Medium relay doesn't prove its relayer is a good Medium (see
## docs/belief_model.md, Nov 12; RoleConstraints, bluffs). In play an evil relayer may have
## invented the relay, so a world with them evil stays possible and the relay is their bluff.
## Before this, a relay cleared an evil Medium bluffer outright (43 of 47 listener readings
## under 2% in a 60-game survey).
##
## Every case is a town built by hand on a fixed 7-NPC deal (seeds 692, 900 and 42), with no
## play, so changes to play can't move them (BACKLOG "Build test_relay_bluff's evil-relayer
## and invented-relay checks by hand", Michael, Nov 18; the seed searches tripped three
## times on Nov 18). Each measures the relays alone: the relayer's chance with every held card
## against the same refresh with its relays left out (Seeds.relay_effect).
##   godot --headless --path . --script res://tools/test_relay_bluff.gd
extends SceneTree

const Seeds = preload("res://tools/fixture_seeds.gd")

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")

const DEALS: Array = [692, 900, 42]

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	# 1. A genuine Medium's true relay doesn't count against it. A genuine relay that sits a
	#    little awkwardly with the listener's own view may cost the Medium a few points; one
	#    that makes it look evil is the bug.
	var failing: Array = []
	for seed in DEALS:
		for subject in ["good", "evil"]:
			var eff: Dictionary = _built_relay(seed, false, subject)
			var shift: float = float(eff.get("with", 1.0)) - float(eff.get("without", 0.0))
			print("genuine Medium relay, seed %d, sighting of %s: %.2f with its relay, %.2f without" % [seed, "an evil" if subject == "evil" else "a good", float(eff.get("with", -1.0)), float(eff.get("without", -1.0))])
			if eff.get("relayed", 0) != 1 or shift >= 0.1:
				failing.append("%d/%s %+.2f" % [seed, subject, shift])
	check(failing.is_empty(), "a genuine Medium's true relay doesn't count against it (six built towns; failing: %s)" % ", ".join(PackedStringArray(failing)))

	# 2. An evil relayer's relays don't clear them: the relayer's chance isn't more than 5
	#    points below the same refresh with its relays left out. Before Nov 12 a relay cleared
	#    its evil relayer outright.
	failing = []
	for seed in DEALS:
		for subject in ["good", "evil"]:
			var eff: Dictionary = _built_relay(seed, true, subject)
			var with_r: float = float(eff.get("with", -1.0))
			var without: float = float(eff.get("without", -1.0))
			print("evil relayer, seed %d, sighting of %s: %.2f with its relay, %.2f without" % [seed, "an evil" if subject == "evil" else "a good", with_r, without])
			if eff.get("relayed", 0) != 1 or with_r < without - 0.05:
				failing.append("%d/%s %.2f -> %.2f" % [seed, subject, without, with_r])
	check(failing.is_empty(), "an evil relayer's relays don't clear them (six built towns; failing: %s)" % ", ".join(PackedStringArray(failing)))

	# 3. An invented relay of the listener, "seen out" on a night they know they were home,
	#    counts against its relayer: with it, the listener holds the relayer at least 0.8.
	failing = []
	for seed in DEALS:
		var eff: Dictionary = _built_relay(seed, true, "listener")
		var with_r: float = float(eff.get("with", -1.0))
		print("invented relay of the listener, seed %d: %.2f with it, %.2f without" % [seed, with_r, float(eff.get("without", -1.0))])
		if eff.get("relayed", 0) != 1 or with_r < 0.8:
			failing.append("%d %.2f" % [seed, with_r])
	check(failing.is_empty(), "an invented relay of the listener, seen out while they were home, counts against its relayer (three built towns; failing: %s)" % ", ".join(PackedStringArray(failing)))

	print("Relay bluff: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)


## A town built by hand on `seed`'s deal (no play). The Demon killed a good neighbour on the
## first night (a Medium communes only with the Demon's victims, sim/roles/medium.gd),
## announced at the second dawn as the game does. On the second night a Medium relays what
## the dead saw on the night before the town arrived; a living good listener hears it.
## - `evil_teller` false: a good Medium (the town's own if it has one, else a good person made
##   one), relaying truly. True: the first of the evil team, bluffing Medium; any good Medium in
##   the deal becomes a Clerk, so the bluff isn't caught by a double claim.
## - `subject`: "good" (a good person seen out), "evil" (an evil one; for an evil teller,
##   another of the team if there is one), or "listener" (the listener "seen out" on a night
##   they were home: an invention).
## The Medium is put on the script either way. Returns Seeds.relay_effect.
func _built_relay(seed: int, evil_teller: bool, subject: String) -> Dictionary:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(seed, 7)
	var w = g.w
	var goods: Array = w.living_good()
	var medium
	if evil_teller:
		for n in goods:
			if n.role == "medium":
				n.role = "clerk"
		medium = w.evil_team()[0]
	else:
		var mediums: Array = goods.filter(func(n): return n.role == "medium")
		medium = mediums[0] if not mediums.is_empty() else goods[0]
		medium.role = "medium"
	if "medium" not in w.case_script.town:
		w.case_script.town.append("medium")
	var others: Array = goods.filter(func(n): return n != medium)
	var dead = others[0]
	var listener = others[1]
	var who
	if subject == "listener":
		who = listener
		listener.history[w.time_key(0, 3)] = "home:" + listener.home_block
	elif subject == "evil":
		var team: Array = w.evil_team().filter(func(n): return n != medium)
		who = team[0] if not team.is_empty() else others[2]
	else:
		who = others[2]
	w.day = 1
	w._kill(dead)
	w.day = 2
	g._facts([{"kind": "death", "subject": [dead.id], "block": dead.home_block, "source": "player", "night": 1, "text": "%s was killed by the demon on night 1." % dead.name}])
	var entry: Dictionary = {"day": 2, "phase": 3, "role": "medium", "shared": true, "true": not evil_teller,
		"data": {"dead": dead.id, "item": {"type": "sighting", "who": who.id, "block": who.home_block, "night": 0}},
		"text": "communing with the dead at %s's hearth, I learned they saw %s out the night before you arrived" % [dead.name, who.name]}
	medium.info_log.append(entry)
	Mind.apply_info(w, listener, medium, entry, 0.8)
	return Seeds.relay_effect(g, listener.id, medium.id)
