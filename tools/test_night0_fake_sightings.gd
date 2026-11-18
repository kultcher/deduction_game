## Michael, Nov 18: evil never tells a night-0 sighting. The Demon doesn't walk on night 0,
## so a liar's night-0 sighting would only make honest night-0 sighters look like liars.
## Checked here, on the two routes that still could:
##   - Evil.fake_night_sighting repeating a made-up night-0 Night Watch report;
##   - Evil.fake_gossip's "was out last night" on day 1.
## Each is checked against the same route a day later, which still works.
extends SceneTree

const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error("FAIL: " + label)


func _init() -> void:
	_watch_report()
	_gossip()
	print("Night-0 fake sightings: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _setup():
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(9503, 10)
	var w = g.w
	Evil.ensure_scapegoat(w)
	return g


func _watch_report() -> void:
	for nd in [0, 1]:
		var g = _setup()
		var w = g.w
		w.day = nd + 1
		var n = w.evil_team()[0]
		var sg: String = str(w.evil_plan["scapegoat"])
		if sg == n.id:
			n = w.evil_team()[1] if w.evil_team().size() > 1 else n
		w.evil_plan["daily_planter"] = ""
		n.info_log.append({"role": "nightwatch", "day": nd, "fake": true, "shared": false, "text": "watch",
			"data": {"block": n.home_block, "seen": [sg]}})
		var r = Evil.fake_night_sighting(w, n, nd)
		if nd == 0:
			check(r == null, "a made-up night-0 watch report isn't repeated as a sighting")
		else:
			check(r is Dictionary and str(r.get("who", "")) == sg, "on night 1 it still is (%s)" % str(r))


func _gossip() -> void:
	var g = _setup()
	var w = g.w
	var n = w.evil_team()[0]
	w.day = 1
	var tries: int = 0
	var told: int = 0
	for i in range(40):
		tries += 1
		if Evil.fake_gossip(w, n) != null:
			told += 1
	check(told == 0, "no 'was out last night' gossip on day 1 (%d of %d)" % [told, tries])
	w.day = 2
	told = 0
	for i in range(40):
		var f = Evil.fake_gossip(w, n)
		if f != null:
			told += 1
			check(int(f["facts"][0].get("day", -1)) == 1, "day-2 gossip names night 1")
			break
	check(told > 0, "on day 2 the gossip still comes")
