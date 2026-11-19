## Where NPC-to-NPC trust ends up (Michael, Nov 19: the whole trust system's measurement).
## Plays passive games and records every living pair's `npc_trust` (a's trust in b, both ways)
## at the end of each day and at game end: the spread, and how many pairs are near full trust.
##   godot --headless --path . --script res://tools/measure_npc_trust.gd -- --seed 3000 --games 15 --npcs 10
## Soft goal (Michael): some NPCs near full trust with some others by about day 4. A guide,
## not a gate; this is a measurement, not a suite.
extends SceneTree
const Game = preload("res://game/game.gd")

const NEAR_FULL := 0.85   # "near full trust" for the count; a reporting line, not a tuning value

var by_day: Dictionary = {}   # day -> Array of trust values (all ordered pairs of living NPCs)
var at_end: Array = []
var near_by_day: Dictionary = {}  # day -> [games with a near-full pair, pairs near full]

func _init() -> void:
	var args: Dictionary = {"seed": 3000, "games": 15, "npcs": 10}
	var a: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(a.size() - 1):
		if a[i].begins_with("--") and args.has(a[i].substr(2)):
			args[a[i].substr(2)] = int(a[i + 1])
	for k in range(int(args.games)):
		_play(int(args.seed) + k, int(args.npcs))
	_report(int(args.games))
	quit(0)

func _pairs(w) -> Array:
	var out: Array = []
	for x in w.living():
		for y in w.living():
			if x != y:
				out.append(float(x.npc_trust.get(y.id, 0.5)))
	return out

func _record(day: int, w) -> void:
	var vals: Array = _pairs(w)
	if not by_day.has(day):
		by_day[day] = []
		near_by_day[day] = [0, 0]
	by_day[day].append_array(vals)
	var near: int = vals.filter(func(v): return v >= NEAR_FULL).size()
	near_by_day[day][1] += near
	if near > 0:
		near_by_day[day][0] += 1

func _play(seed_v: int, npcs: int) -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(seed_v, npcs)
	var last_day: int = g.w.day
	var guard := 0
	while g.state != "over" and guard < 400:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
		if g.w.day != last_day:
			_record(last_day, g.w)  # the end of the day just finished
			last_day = g.w.day
	at_end.append_array(_pairs(g.w))

func _pct(vals: Array, q: float) -> float:
	if vals.is_empty():
		return 0.0
	var s: Array = vals.duplicate()
	s.sort()
	return float(s[clampi(int(q * (s.size() - 1)), 0, s.size() - 1)])

func _line(label: String, vals: Array) -> String:
	var near: int = vals.filter(func(v): return v >= NEAR_FULL).size()
	return "%-10s pairs %5d  p10 %.2f  median %.2f  p90 %.2f  max %.2f  near full (>= %.2f) %d (%.1f%%)" % [
		label, vals.size(), _pct(vals, 0.1), _pct(vals, 0.5), _pct(vals, 0.9), _pct(vals, 1.0), NEAR_FULL, near, 100.0 * near / maxf(1.0, vals.size())]

func _report(games: int) -> void:
	print("NPC-to-NPC trust over %d passive games" % games)
	var days: Array = by_day.keys()
	days.sort()
	for d in days:
		print(_line("end day %d" % d, by_day[d]) + "  games with one %d" % near_by_day[d][0])
	print(_line("game end", at_end))
