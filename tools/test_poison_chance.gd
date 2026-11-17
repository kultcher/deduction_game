## ReadingChallenges.poison_chance: the chance, as a listener can tell it, that its own gift
## was poisoned on a night (the poison self-doubt's prior; BACKLOG "A listener's doubt that
## its own reading was poisoned", Michael, Nov 17).
##   godot --headless --path . --script res://tools/test_poison_chance.gd
extends SceneTree

const RC = preload("res://workshop/reading_challenges.gd")
const History = preload("res://workshop/live_history.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _view(minions: Array, evil: int, events: Array = [], cards: Array = []) -> Dictionary:
	var people: Array = []
	for id in ["a", "b", "c", "d", "e", "f", "g"]:
		people.append({"id": id, "name": id})
	return {"people": people, "cards": cards, "evil_count": evil, "script_minions": minions, "timeline": History.from_events(events)}

func _listener(knowledge: Dictionary = {}) -> Dictionary:
	var k: Dictionary = {"self": "a"}
	k.merge(knowledge, true)
	return {"id": "a", "knowledge": k}

func _init() -> void:
	# Seven alive, two evil: the Poisoner picks one of five good people.
	var p: float = RC.poison_chance(_view(["poisoner"], 2), _listener(), 1)
	check(is_equal_approx(p, 0.2), "a Poisoner certainly in play, seven alive, two evil: one in five (%.3f)" % p)
	check(RC.poison_chance(_view(["scout", "brute"], 2), _listener(), 1) == 0.0, "no Poisoner on the script: none")
	var half: float = RC.poison_chance(_view(["poisoner", "brute"], 2), _listener(), 1)
	check(is_equal_approx(half, 0.1), "one minion place, two script minions: half as likely (%.3f)" % half)
	check(RC.poison_chance(_view(["poisoner"], 1), _listener(), 1) == 0.0, "no minion places: none")
	var unknown: float = RC.poison_chance(_view([], 2), _listener(), 1)
	check(is_equal_approx(unknown, 0.2), "an unknown script allows it, as poisoner_possible does (%.3f)" % unknown)
	# Deaths: two killed before night 3 leave three good people to choose from.
	var deaths: Array = [{"kind": "demon_death", "subjects": ["b"], "at": {"day": 1, "phase": "night"}},
		{"kind": "execution", "subjects": ["c"], "at": {"day": 2, "phase": "evening"}}]
	var later: float = RC.poison_chance(_view(["poisoner"], 2, deaths), _listener(), 3)
	check(is_equal_approx(later, 1.0 / 3.0), "fewer alive, a likelier target (%.3f on night 3)" % later)
	var early: float = RC.poison_chance(_view(["poisoner"], 2, deaths), _listener(), 1)
	check(is_equal_approx(early, 0.2), "the same deaths don't count before they happen (%.3f on night 1)" % early)
	# A Poisoner known dead: from a public role, or the listener's own Gravedigger reading.
	# Hanged at day 2's meeting: alive for night 1 (which follows day 1), dead from night 2.
	var hanged: Array = [{"kind": "execution", "subjects": ["g"], "at": {"day": 2, "phase": "evening"}}]
	var pub: Dictionary = {"public_roles": {"g": "poisoner"}}
	check(RC.poison_chance(_view(["poisoner"], 2, hanged), _listener(pub), 2) == 0.0, "a Poisoner publicly known hanged: none after")
	check(RC.poison_chance(_view(["poisoner"], 2, hanged), _listener(pub), 1) > 0.0, "but it could still act the night before it hanged")
	var gd: Dictionary = {"id": "gd", "kind": "report", "role": "gravedigger", "source": "a", "data": {"executed": "g", "role": "poisoner"}}
	var own: Dictionary = {"own_reports": ["gd"]}
	check(RC.poison_chance(_view(["poisoner"], 2, hanged, [gd]), _listener(own), 2) == 0.0, "the listener's own Gravedigger reading of a hanged Poisoner: none after")
	check(RC.poison_chance(_view(["poisoner"], 2), _listener(), -1) == 0.0, "no night: none")
	print("Poison chance: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
