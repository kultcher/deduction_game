## Honest forgetting (Michael, Nov 19): when memory, not discretion, drops people from a
## daytime "who did you see?" answer, the speaker says there were others, naming no one.
## Never when Gossip held anyone back; an evil speaker's teammates never count as forgotten.
##   godot --headless --path . --script res://tools/test_honest_forgetting.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const Evil = preload("res://sim/evil.gd")
const Dialogue = preload("res://sim/dialogue.gd")

const CANON = "There were others, but I can't place them."

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL " + label)

func _init() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(7300, 10)
	var w = g.w
	w.player_loc = "tavern"
	w.phase = 2
	var good = w.living_good()
	var n = good[0]
	var others: Array = good.slice(1, 5)
	var forgot: String = Dialogue.voice_line(n.id, "day_forgot_others", CANON)
	_check(forgot != "", "%s has a forgetting line (%s)" % [n.name, forgot])

	# Memory 2 (no Insight), Gossip high: four people seen, two told, two forgotten.
	_ready(n, 0.0, 1.0)
	n.beliefs = _sightings(w, others)
	var text: String = _answer(w, n)
	_check(forgot in text, "memory dropped two: they say there were others (%s)" % text)
	_check(not (others[0].name in text) and not (others[1].name in text), "the forgotten aren't named (%s)" % text)
	_check(others[2].name in text and others[3].name in text, "the two most recent are told (%s)" % text)

	# Exactly as many as they remember: nothing forgotten, no line.
	_ready(n, 0.0, 1.0)
	n.beliefs = _sightings(w, others.slice(2, 4))
	text = _answer(w, n)
	_check(not (forgot in text), "nothing forgotten, no line (%s)" % text)

	# Gossip holds one back: the line would pass discretion off as forgetting, so it's left out.
	_ready(n, 0.0, 0.0)
	n.beliefs = _sightings(w, others)
	text = _answer(w, n)
	_check(not (forgot in text), "Gossip held someone back: no forgetting line (%s)" % text)

	# Evil: a teammate beyond memory isn't forgotten, it's skipped; a good speaker who saw the
	# same people would say there were others.
	var evil: Array = w.living().filter(func(x): return x.is_evil())
	var e = evil[0]
	var mate = null
	for x in evil:
		if x.id != e.id and Evil.is_teammate(w, e, x.id):
			mate = x
	_check(mate != null, "the deal has two evil teammates")
	if mate != null:
		var pair: Array = good.slice(1, 3)
		var e_forgot: String = Dialogue.voice_line(e.id, "day_forgot_others", CANON)
		_ready(e, 0.0, 1.0)
		e.beliefs = _sightings(w, [mate] + pair)
		text = _answer(w, e)
		_check(not (e_forgot in text) and not (mate.name in text), "an evil speaker's teammate isn't counted as forgotten (%s)" % text)
		_ready(n, 0.0, 1.0)
		n.beliefs = _sightings(w, [mate] + pair)
		text = _answer(w, n)
		_check(forgot in text, "a good speaker who saw the same three says there were others (%s)" % text)
	print("Honest forgetting: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _ready(n, insight: float, gossip: float) -> void:
	n.traits["insight"] = insight
	n.traits["gossip"] = gossip
	n.pressure = 0.0
	n.dialogue_memory = {}

## Each person seen once earlier today, oldest first, away from the player.
func _sightings(w, people: Array) -> Array:
	var out: Array = []
	var i = 0
	for p in people:
		out.append({"kind": "saw", "who": p.id, "loc": "smithy", "block": "market", "day": w.day, "phase": 0 if i < 2 else 1, "with": ""})
		i += 1
	return out

func _answer(w, n) -> String:
	var r = Mind.answer_today(w, n, "", "tavern")
	return " ".join(PackedStringArray(r["lines"].map(func(l): return str(l.get("text", "")))))
