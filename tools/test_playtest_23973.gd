## Playtest 23973 (docs/playtests/23973.md, Claude-Coroner), note 2: Merrin's defence gave a
## home alibi, then "Then Kiran speaks with the serpent's own tongue!", a "Then" that
## followed nothing. The "lying" defence now says "Then X is lying" only after the hinge line
## "...and that reading is wrong" (test_meeting_m2c covers that path); otherwise it uses a
## line that stands alone, and the past tense for a source who has died (`defence_lying_alone`,
## `defence_lied`: Herald's keys, approved by Michael Nov 17). Setup as test_defence_repeats.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(label)
		print("FAIL: " + label)

func _init() -> void:
	for size in [7, 10]:
		_lying_stands_alone(size)
	print("Playtest 23973: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(size: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7350, size)
	g.w.day = 4
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.ledger = {}
			listener.beliefs = []
			listener.known_claims = {}
			listener.cleared = {}
			listener.traits.confidence = 0.5
			for id in listener.suspicion:
				listener.suspicion[id] = 0.1
			Mind.refresh_beliefs(g.w, listener, " (clean)")
	return g

func _said(r: Dictionary) -> Array:
	return r.get("lines", []).map(func(l): return str(l.get("statement", l.get("text", ""))) if l is Dictionary else str(l))

## A Seer's "one of these two" names the defender, who suspects the Seer more than the
## other one, so they call the Seer a liar. With no filed case there's no hinge line.
func _defence(size: int, source_dead: bool) -> Dictionary:
	var g = _game(size)
	var w = g.w
	var source = w.living_good()[0]
	var d = w.living_good()[1]
	var other = w.living_good()[3]
	d.role = "surveyor"
	d.secret = {}
	d.traits.confidence = 0.9
	source.role = "seer"
	source.claimed_role = "seer"
	source.claim_public = true
	var reading = {"day": 0, "role": "seer", "data": {"pair": [d.id, other.id], "yes": true}, "text": "One reads as the Demon", "shared": true}
	source.info_log = [reading]
	Mind.apply_info(w, source, source, reading, 1.0)
	d.suspicion[other.id] = 0.1
	d.suspicion[source.id] = 0.6
	if source_dead:
		source.alive = false
	var r: Dictionary = Mind.defend_self(w, d, source.id)
	return {"r": r, "source": source.name}

func _lying_stands_alone(size: int) -> void:
	var live: Dictionary = _defence(size, false)
	var said: Array = _said(live.r)
	_check("lying" in live.r.get("moves", []), "%d NPCs: suspecting the Seer more, the defender calls them a liar (%s)" % [size, str(said)])
	_check(said.any(func(s): return s == "%s is lying, and you should ask yourselves why." % live.source), "%d NPCs: with nothing before it, the line stands alone (%s)" % [size, str(said)])
	_check(not said.any(func(s): return s.begins_with("Then ")), "%d NPCs: no 'Then' that follows nothing (%s)" % [size, str(said)])
	var dead: Dictionary = _defence(size, true)
	var said_d: Array = _said(dead.r)
	if "lying" in dead.r.get("moves", []):
		_check(said_d.any(func(s): return s == "%s lied, and you should ask yourselves why." % dead.source), "%d NPCs: a dead source is spoken of in the past tense (%s)" % [size, str(said_d)])
		_check(not said_d.any(func(s): return " is lying" in s), "%d NPCs: never 'is lying' about the dead (%s)" % [size, str(said_d)])
	else:
		_check(false, "%d NPCs: the defender still calls the dead Seer a liar (%s)" % [size, str(said_d)])
