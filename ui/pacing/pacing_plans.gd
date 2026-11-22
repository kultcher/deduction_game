## The beats of the execution and the night's reveal (Michael, Nov 22; ui/pacing/pacing_overlay.gd
## plays them). Reads the finished day or night from the world; changes nothing, and draws
## the fakeout's landing from its own generator, never the world's.
##
## A beat is a dictionary with a "type":
##   fade      {"to": alpha}                       the shade goes towards black
##   portrait  {"id"}                              the condemned's portrait, centred
##   headline  {"text", "pos": "above"|"below", "colour"}   BBCode allowed (a name in colour)
##   beat      {"secs"}                            a pause
##   mark      {"id"}                              grey the portrait, smash a blue X (Limner's ExecutionMark)
##   wheel     {"people", "victim", "kill"}        Limner's KillWheel, then the screen shakes on the strike
##   panel     {"text"}                            the night's result, in a VN-style panel
##   continue  {}                                  wait for the player
##   clear     {}                                  empty the stage for the next part
extends RefCounted

const C = preload("res://sim/content.gd")

## Wording (Michael, Nov 22: approved as written).
const EXEC_ABOVE = "%s was condemned and hanged at dusk..."
const EXEC_BELOW = "... but evil still lurks in Hollowmere."
const MARTYR_ABOVE = "%s died at the gallows in %s's place..."
const NIGHT_HEAD = "A Demon stalks Hollowmere in the night..."
const KILL_BELOW = "... and %s met a grim end at the hand of the fiend."
const QUIET_BELOW = "... but by mettle or miracle, no one died at the hand of the fiend."
const AGAIN = "...and the fiend was not finished."

const RED = Color("ec5a5a")
const BLUE = Color("8dbaf1")
const WHITE = Color("efe6d2")

const BEAT = 0.9

## The execution after a meeting, or [] when nobody hanged. `martyr` is the meeting's martyr
## record ({martyr, saved}) when one died in another's place.
static func execution(w, executed: String, martyr: Dictionary = {}) -> Array:
	if executed == "" or not w.by_id.has(executed):
		return []
	var dead: String = executed
	var above: String = EXEC_ABOVE % _named(w, executed)
	if not martyr.is_empty() and w.by_id.has(str(martyr.get("martyr", ""))):
		dead = str(martyr.martyr)
		above = MARTYR_ABOVE % [_named(w, dead), _named(w, str(martyr.get("saved", executed)))]
	return [
		{"type": "fade", "to": 1.0},
		{"type": "portrait", "id": dead},
		{"type": "headline", "text": above, "pos": "above", "colour": WHITE},
		{"type": "beat", "secs": BEAT},
		{"type": "mark", "id": dead},
		{"type": "beat", "secs": BEAT},
		{"type": "headline", "text": EXEC_BELOW, "pos": "below", "colour": WHITE},
		{"type": "continue"},
	]

## The night's reveal at dawn: the night's own result (`result`, already said in the log),
## then one wheel per Demon kill, or the fakeout when the Demon killed nobody.
## `living_before` is everyone alive when the night began, in cast order.
static func night(w, result: String, living_before: Array, ward_target: String = "") -> Array:
	var out: Array = []
	out.append({"type": "fade", "to": 1.0})
	if result.strip_edges() != "":
		out.append({"type": "panel", "text": result})
		out.append({"type": "continue"})
		out.append({"type": "clear"})
	out.append({"type": "headline", "text": NIGHT_HEAD, "pos": "above", "colour": RED})
	var kills: Array = w.deaths_last_night.filter(func(id): return w.by_id.has(id) and str(w.by_id[id].death_cause) == "demon")
	var alive: Array = living_before.duplicate()
	if kills.is_empty():
		var landing: String = ward_target if ward_target in alive else _fakeout(w, alive)
		out.append({"type": "wheel", "people": _people(w, alive), "victim": landing, "kill": false})
		out.append({"type": "headline", "text": QUIET_BELOW, "pos": "below", "colour": BLUE})
		out.append({"type": "continue"})
		return out
	for i in range(kills.size()):
		var v: String = kills[i]
		if i > 0:
			out.append({"type": "clear"})
			out.append({"type": "headline", "text": AGAIN, "pos": "above", "colour": RED})
		out.append({"type": "wheel", "people": _people(w, alive), "victim": v, "kill": true})
		out.append({"type": "headline", "text": KILL_BELOW % _named(w, v), "pos": "below", "colour": WHITE})
		out.append({"type": "continue"})
		alive.erase(v)
	return out

## The wheel's people: id, name, colour, and the portrait art.
static func _people(w, ids: Array) -> Array:
	return ids.filter(func(id): return w.by_id.has(id)).map(func(id): return {"id": id, "name": w.by_id[id].name, "color": C.npc_color(id)})

## A name in its own colour, as BBCode.
static func _named(w, id: String) -> String:
	return "[color=#%s]%s[/color]" % [C.npc_color(id).to_html(false), w.by_id[id].name]

## Where a harmless spin lands: drawn from the case and the night, on its own generator.
static func _fakeout(w, alive: Array) -> String:
	if alive.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("night_fakeout:%d:%d" % [int(w.seed_value), int(w.day)])
	return alive[rng.randi() % alive.size()]
