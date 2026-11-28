## A silenced NPC shares nothing, in private too (Michael, Nov 27, playtest 52102): no NPC
## conversation, and no evil whisper in the crowded tavern. The player's own questions, "Call
## on" and approaches have their own checks (test_call_on, test_silence_pressure).
##   godot --headless --path . --script res://tools/test_silenced_shares_nothing.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Social = preload("res://sim/social.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _world(sd: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(sd, 10)
	g.w.day = 2
	return g.w

func _shares(w) -> int:
	return w.dlog.entries.filter(func(x): return x["type"] in ["npc_share", "evil_share"]).size()

func _init() -> void:
	# A conversation with a silenced NPC passes nothing either way.
	var w = _world(4100)
	var a = w.living_good()[0]
	var b = w.living_good()[1]
	a.silenced = true
	var before: int = _shares(w)
	for k in range(5):
		Social.converse(w, a, b, "post")
		Social.converse(w, b, a, "post")
	_check(_shares(w) == before, "a conversation with a silenced NPC passes nothing")
	# Evil in the crowded tavern: whispers happen between the speaking, never with a silenced one.
	var spoke := 0
	var silent := 0
	var pairs := 0
	for sd in range(4200, 4230):
		for silence in [false, true]:
			var w2 = _world(sd)
			var team: Array = w2.evil_team().filter(func(m): return m.alive).slice(0, 2)
			if team.size() < 2:
				continue
			# Two of the team in a crowded tavern, the rest at home: silence one and no one is left
			# to whisper with.
			for m in w2.living():
				m.loc = "tavern" if (not m.is_evil() or m in team) else "home"
				m.busy_with = ""
			team[0].intel["probe"] = {"kind": "threat", "about": w2.living_good()[0].id, "score": 0.5}
			for m in team.slice(1):
				m.intel.erase("probe")
			for m in team:
				m.silenced = false
			if silence:
				team[0].silenced = true
			var b2: int = _shares(w2)
			Social.tavern_whispers(w2)
			var n: int = _shares(w2) - b2
			if silence:
				silent += n
				pairs += 1
			else:
				spoke += n
	print("tavern whispers over %d evil pairs: %d when both could speak, %d with one silenced" % [pairs, spoke, silent])
	_check(pairs >= 5 and spoke > 0, "an evil pair whispers in a crowded tavern when both can speak")
	_check(silent == 0, "with one of the pair silenced, no whisper at all")
	var w3 = _world(4300)
	var team3: Array = w3.evil_team().filter(func(m): return m.alive)
	if team3.size() >= 2:
		for m in w3.living():
			m.loc = "tavern"
			m.busy_with = ""
		for m in team3:
			m.silenced = true
			m.intel["probe_%s" % m.id] = {"kind": "threat", "about": w3.living_good()[0].id, "score": 0.5}
		var b3: int = _shares(w3)
		for k in range(10):
			Social.tavern_whispers(w3)
		_check(_shares(w3) == b3, "a silenced evil member never whispers in the tavern")
	print("Silenced shares nothing: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
