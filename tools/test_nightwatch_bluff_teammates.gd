## Does a Night Watch bluff report a teammate? (BACKLOG section 1, "The Night Watch bluff
## doesn't hide teammates", confirm then fix.) Its log says "hiding teammates"; the rule
## reports the walkers in the bluffer's `intel`. This suite checks where that intel comes
## from (its own sightings and what it's told) and what the bluff then reports.
extends SceneTree
const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")
const FixtureSeeds = preload("res://tools/fixture_seeds.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	_own_sightings()
	_told_sightings()
	_played_games()
	print("Night Watch bluff teammates: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(seed_v: int = 4242, size: int = 10):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, size)
	return g

func _reading(w, n) -> Dictionary:
	var gen: Dictionary = C.role_def("nightwatch").generate_bluff_reading(w, n, w.evil_plan, w.evil_plan["scapegoat"], null, [])
	return gen.get("entry", {}).get("data", {})

## The bluffer saw both a good walker and its own teammate out on the scapegoat's block.
func _own_sightings() -> void:
	var g = _game()
	var w = g.w
	w.day = 1
	var n = w.minion()
	var mate = w.demon()
	var s: String = w.evil_plan["scapegoat"]
	var block: String = w.by_id[s].home_block
	var good = w.living_good().filter(func(x): return x.id != s)[0]
	n.intel = {}
	n.beliefs = [
		{"kind": "saw", "who": mate.id, "block": block, "day": 1, "phase": C.NIGHT, "how": "street"},
		{"kind": "saw", "who": good.id, "block": block, "day": 1, "phase": C.NIGHT, "how": "street"},
	]
	Evil.gather_night_intel(w)
	_check(n.intel.values().any(func(it): return it.kind == "walker" and it.about == good.id), "a good walker it saw is noted as a walker")
	_check(not n.intel.values().any(func(it): return it.kind == "walker" and it.about == mate.id), "a teammate it saw is not noted as a walker")
	var data: Dictionary = _reading(w, n)
	_check(good.id in data.get("seen", []), "the bluff reports the good walker (%s)" % str(data))
	_check(not (mate.id in data.get("seen", [])), "the bluff leaves the teammate out (%s)" % str(data))

## Told by a good NPC that a teammate was out: that becomes a threat, never walker intel.
func _told_sightings() -> void:
	var g = _game()
	var w = g.w
	w.day = 1
	var n = w.minion()
	var mate = w.demon()
	var teller = w.living_good()[0]
	n.intel = {}
	Evil.intel_from_share(w, n, teller, {"kind": "sighting", "about": mate.id, "block": mate.home_block, "day": 1})
	_check(not n.intel.values().any(func(it): return it.kind == "walker" and it.about == mate.id), "a told sighting of a teammate is not walker intel")
	_check(n.intel.values().any(func(it): return it.kind == "threat" and it.about == teller.id), "the teller becomes a threat instead")

## Real passive games: every Night Watch fabrication on record, checked against the team.
func _played_games() -> void:
	var looked: int = 0
	var readings: int = 0
	for seed_v in range(FixtureSeeds.SEEDS_FROM, FixtureSeeds.SEEDS_FROM + 20):
		var g = FixtureSeeds.play_to_meeting(seed_v, 3, 7)
		if g == null:
			continue
		looked += 1
		for m in g.w.evil_team():
			for e in m.info_log:
				if not e.get("fake", false) or e.get("role", "") != "nightwatch":
					continue
				readings += 1
				for who in e.get("data", {}).get("seen", []):
					_check(not g.w.by_id[who].is_evil(), "seed %d: %s's night-%d watch names teammate %s" % [seed_v, m.id, int(e.day), who])
	print("  played %d games to day 3, %d Night Watch fabrications checked" % [looked, readings])
	_check(looked > 0, "some games reached day 3")
	_check(readings > 0, "and some evil Night Watch fabrications were checked (%d; Steward Nov 19 silent skip)" % readings)
