## Playtest 26532 (Nov 16), two findings:
## 1. "ask night" to a night-walking gift (Confessor, Lamplighter, Medium) told where they
##    went but not what the gift showed, so "it showed nothing" and "I won't say" sounded
##    the same. Now a result already told is said again; one not yet told is told only by
##    someone already sharing readings who'd still tell them to "ask gift" today (Michael,
##    Nov 16 and 17: the night question never opens readings), else held back in so many
##    words; a night that showed nothing is said plainly. The Night Watch tells its result
##    through its sightings, behind the same rule.
## 2. Isolde, on a case about day-1 whereabouts, opened "Your case rests on where I was
##    last night". A sighting by day the case cites is not a night outing.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const MindMeeting = preload("res://sim/mind_meeting.gd")
const C = preload("res://sim/content.gd")
var checks = 0
var fails = 0

const WITHHELD = "I'll keep to myself for now"
const NOTHING = "showed me nothing that night"

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _init() -> void:
	for size in [7, 10]:
		_ask_night(size, "confessor")
		_ask_night(size, "lamplighter")
		_ask_night_nightwatch(size)
		_ask_night_evil(size)
		_defence_day_sighting(size)
	print("Ask night results and day-sighting defence: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func _game(size: int):
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(7350, size)
	g.w.day = 2
	g.w.phase = 0
	for n in g.w.npcs:
		for listener in [n, n.shadow]:
			if listener == null:
				continue
			listener.info_log = []
			listener.ledger = {}
			listener.beliefs = []
			listener.known_claims = {}
			listener.cleared = {}
			listener.told_readings = 0
			for id in listener.suspicion:
				listener.suspicion[id] = 0.1
	return g

func _text(r: Dictionary) -> String:
	return " ".join(PackedStringArray(r.get("lines", []).map(func(l): return str(l.get("text", "")) if l is Dictionary else str(l))))

func _holder(w, role: String):
	var d = w.living_good()[0]
	d.role = role
	d.claimed_role = role
	d.claim_public = false
	d.max_tier = 3
	d.secret = {}
	d.secret_mod = ""
	d.poisoned = false
	d.history[w.time_key(1, C.NIGHT)] = "night:" + d.home_block
	_shut(d)
	return d

## Closed: as private and distrustful as can be, so today's gate keeps readings back.
func _shut(d) -> void:
	d.traits["privacy"] = 1.0
	d.trust = 0.0
	d.pressure = 0.0

## Open: no privacy, full trust, so the gate tells readings.
func _open(d) -> void:
	d.traits["privacy"] = 0.0
	d.trust = 1.0

func _reading(w, d, role: String) -> Dictionary:
	var other = w.living_good()[1]
	if role == "confessor":
		return {"role": role, "day": 1, "data": {"target": other.id, "good": true}, "true": true, "shared": false,
			"text": "I heard %s's confession: their heart was pure and their spirit good" % other.name}
	return {"role": role, "day": 1, "data": {"count": 2}, "true": true, "shared": false,
		"text": "walking the lamps, I counted 2 others out"}

func _ask_night(size: int, role: String) -> void:
	var label: String = "%d NPCs, %s:" % [size, role]
	# Not yet told: held back in so many words, and no new reading disclosed.
	var g = _game(size)
	var d = _holder(g.w, role)
	d.info_log = [_reading(g.w, d, role)]
	var r: Dictionary = Mind.answer_night(g.w, d)
	var t: String = _text(r)
	check(WITHHELD in t, label + " an untold result is held back in words: " + t)
	check(not r.facts.any(func(f): return f.get("kind", "") == "info"), label + " ...and not disclosed")
	check(d.told_readings == 0, label + " ...and not marked as told")
	# They'd tell their readings today, but haven't yet shared any (tier 3): the night
	# question doesn't open them (Michael, Nov 17).
	g = _game(size)
	d = _holder(g.w, role)
	_open(d)
	check(Mind.MindDialogue.disclosure_gate(g.w, d)["readings_open"], label + " (fixture: the open gate is open)")
	d.info_log = [_reading(g.w, d, role)]
	r = Mind.answer_night(g.w, d)
	t = _text(r)
	check(WITHHELD in t and not r.facts.any(func(f): return f.get("kind", "") == "info") and d.told_readings == 0 and d.max_tier == 3,
		label + " not yet sharing readings: an untold result stays held back, even on an open day: " + t)
	# Already sharing readings (tier 4) and open today: a new one is told, card and all.
	g = _game(size)
	d = _holder(g.w, role)
	_open(d)
	d.max_tier = 4
	d.info_log = [_reading(g.w, d, role)]
	r = Mind.answer_night(g.w, d)
	t = _text(r)
	var told_marker: String = g.w.living_good()[1].name if role == "confessor" else "2"
	check(told_marker in t and not WITHHELD in t, label + " sharing readings and open today: an untold result is told: " + t)
	check(r.facts.any(func(f): return f.get("kind", "") == "info" and f.get("role", "") == role), label + " ...with its card")
	check(d.told_readings == 1, label + " ...and marked as told")
	# Already told: said again.
	g = _game(size)
	d = _holder(g.w, role)
	d.info_log = [_reading(g.w, d, role)]
	d.told_readings = 1
	t = _text(Mind.answer_night(g.w, d))
	var marker: String = g.w.living_good()[1].name if role == "confessor" else "2"
	check(marker in t and not WITHHELD in t, label + " a told result is said again: " + t)
	# Nothing that night: said plainly.
	g = _game(size)
	d = _holder(g.w, role)
	t = _text(Mind.answer_night(g.w, d))
	check(NOTHING in t, label + " no result is said plainly: " + t)
	# Gift not named yet: no duty told, so nothing about a result either.
	g = _game(size)
	d = _holder(g.w, role)
	d.max_tier = 0
	d.claimed_role = ""
	d.info_log = [_reading(g.w, d, role)]
	t = _text(Mind.answer_night(g.w, d))
	check(not WITHHELD in t and not NOTHING in t, label + " a hidden gift says nothing of a result: " + t)

func _ask_night_nightwatch(size: int) -> void:
	for open in [false, true]:
		var g = _game(size)
		var d = _holder(g.w, "nightwatch")
		if open:
			_open(d)
			d.max_tier = 4
		d.info_log = [{"role": "nightwatch", "day": 1, "data": {"block": d.home_block, "seen": []}, "true": true, "shared": false, "text": "I watched the Docks: nobody stirred"}]
		var r: Dictionary = Mind.answer_night(g.w, d)
		var t: String = _text(r)
		var label: String = "%d NPCs, Night Watch, gate %s:" % [size, "open" if open else "closed"]
		check(not WITHHELD in t and not NOTHING in t, label + " answers through its sightings, not the reading lines: " + t)
		check(r.facts.any(func(f): return f.get("kind", "") == "info") == open and d.told_readings == (1 if open else 0), label + " its reading is told only when the gate is open")
		if open:
			# Codex, #178: a quiet watch (nobody seen) must still say its result in words.
			check(r.lines.size() >= 2, label + " the watch result is spoken, not only carded: " + t)
			check(not "not ready" in t and not "in reserve" in t, label + " ...and not then refused: " + t)

func _ask_night_evil(size: int) -> void:
	var g = _game(size)
	var w = g.w
	var e = w.npcs.filter(func(n): return n.is_evil())[0]
	w.evil_plan["bluffs"][e.id] = "confessor"
	e.claimed_role = "confessor"
	e.max_tier = 3
	e.info_log = []
	var t: String = _text(Mind.answer_night(w, e))
	check(not NOTHING in t, "%d NPCs, evil Confessor bluff with no story: never says \"nothing\" (a real one always learns): %s" % [size, t])

func _defence_day_sighting(size: int) -> void:
	var label: String = "%d NPCs, defence:" % size
	for phase in [2, C.NIGHT]:
		var g = _game(size)
		var w = g.w
		var goods: Array = w.living_good()
		var d = goods[0]
		var accuser = goods[1]
		d.role = "clerk"
		d.claimed_role = "clerk"
		d.claim_public = true
		d.secret = {}
		d.secret_mod = ""
		d.history[w.time_key(1, C.NIGHT)] = "home:" + d.home_block
		w.meeting["pending"] = {"case_card": 1}
		var spoken: Array = [{"kind": "sighting", "source": accuser.id, "subject": [d.id], "block": "hill", "day": 1, "phase": phase}]
		var res: Dictionary = Mind.defend_self(w, d, "player", spoken)
		var t: String = _text(res)
		if phase == C.NIGHT:
			check("dispute_night" in res.moves, label + " a night sighting still gets the night account (control): " + t)
		else:
			check(not "dispute_night" in res.moves and not "where I was" in t, label + " a sighting by day isn't answered as last night: " + t)
			var items: Array = MindMeeting._disclosed_items_against(w, d, accuser, spoken)
			check(items.all(func(x): return x.get("channel", "") != "movement_out"), label + " a sighting by day isn't a night outing")
