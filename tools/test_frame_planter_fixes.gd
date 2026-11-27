## The day's frame planter (Evil.plan_daily_frame) after playtest 52102 (Coroner, Nov 27):
##   - choosing the planter rewrites only the chosen member's untold Night Watch report, and
##     logs the rewrite as a lie; a candidate that wasn't chosen keeps its report;
##   - a Monitor bluffer is never given a window sighting to tell;
##   - a planted sighting is logged as a lie when first told, once.
##   godot --headless --path . --script res://tools/test_frame_planter_fixes.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Evil = preload("res://sim/evil.gd")
const C = preload("res://sim/content.gd")

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

## A scene on night 1 on `block`, and the scapegoat fixed.
func _scene(w, block: String, sg) -> void:
	w.scenes["probe"] = {"day": 1, "block": block}
	w.evil_plan["scapegoat"] = sg.id

func _watch(m, block: String) -> Dictionary:
	var e: Dictionary = {"role": "nightwatch", "day": 1, "fake": true, "shared": false, "data": {"block": block, "seen": []}, "text": "I watched %s: no one passed" % C.block_name(block)}
	m.info_log.append(e)
	return e

func _init() -> void:
	var rewrites_ok := 0
	var cases := 0
	var monitor_cases := 0
	var monitor_window := 0
	var planted_once := 0
	var planted_cases := 0
	for sd in range(5000, 5060):
		var w = _world(sd)
		var team: Array = w.evil_team().filter(func(m): return m.alive)
		if team.size() < 2:
			continue
		var goods: Array = w.living_good()
		var sg = goods[0]
		# A death block that's no evil member's home and not the scapegoat's.
		var death: String = ""
		for b in C.BLOCKS.keys():
			if b != sg.home_block and not team.any(func(m): return m.home_block == b):
				death = b
				break
		if death == "":
			continue
		_scene(w, death, sg)
		# Two Night Watch bluffers with untold reports elsewhere: one is chosen, the other kept.
		var a = team[0]
		var b2 = team[1]
		for m in team:
			w.evil_plan["bluffs"][m.id] = "clerk"
		w.evil_plan["bluffs"][a.id] = "nightwatch"
		w.evil_plan["bluffs"][b2.id] = "nightwatch"
		var other: String = a.home_block if a.home_block != death else b2.home_block
		var wa: Dictionary = _watch(a, other)
		var wb: Dictionary = _watch(b2, other)
		var ta: String = wa["text"]
		var tb: String = wb["text"]
		Evil.plan_daily_frame(w)
		var chosen: String = str(w.evil_plan.get("daily_planter", ""))
		if w.evil_plan.get("scapegoat", "") != sg.id or not (chosen in [a.id, b2.id]):
			continue
		cases += 1
		var loser: Dictionary = wb if chosen == a.id else wa
		var winner: Dictionary = wa if chosen == a.id else wb
		var loser_text: String = tb if chosen == a.id else ta
		var logged: bool = w.dlog.entries.any(func(x): return x["type"] == "think" and x["actor"] == chosen and x.get("data", {}).get("rewrite", false))
		var winner_rewritten: bool = sg.id in winner.get("data", {}).get("seen", [])
		if str(loser["text"]) == loser_text and loser["data"]["seen"].is_empty() and (not winner_rewritten or logged):
			rewrites_ok += 1
		# A planted sighting told: logged as a lie once.
		var ps: Dictionary = w.evil_plan.get("planter_sighting", {})
		if not ps.is_empty():
			var planter = w.by_id[chosen]
			Evil.fake_night_sighting(w, planter, 1)
			Evil.fake_night_sighting(w, planter, 1)
			var n_planted: int = w.dlog.entries.filter(func(x): return x["type"] == "think" and x["actor"] == chosen and (x.get("data", {}).get("planted", false) or x.get("data", {}).get("rewrite", false) or str(x.get("reason", "")).begins_with("Told of seeing") or str(x.get("reason", "")).begins_with("Made up"))).size()
			planted_cases += 1
			planted_once += int(n_planted >= 1 and w.dlog.entries.filter(func(x): return x["type"] == "think" and x["actor"] == chosen and x.get("data", {}).get("planted", false)).size() <= 1)
	for sd in range(5100, 5160):
		# A Monitor bluffer living on the death block: no window sighting.
		var w = _world(sd)
		var team: Array = w.evil_team().filter(func(m): return m.alive)
		var goods: Array = w.living_good()
		var sg = goods[0]
		var mon = team[0]
		if mon.home_block == sg.home_block:
			continue
		_scene(w, mon.home_block, sg)
		for m in team:
			w.evil_plan["bluffs"][m.id] = "clerk"
		w.evil_plan["bluffs"][mon.id] = "monitor"
		for m in team.slice(1):
			m.alive = false  # only the Monitor bluffer can plant
		Evil.plan_daily_frame(w)
		if w.evil_plan.get("scapegoat", "") != sg.id:
			continue
		monitor_cases += 1
		var ps: Dictionary = w.evil_plan.get("planter_sighting", {})
		if str(w.evil_plan.get("daily_planter", "")) == mon.id and str(ps.get("how", "")) == "window":
			monitor_window += 1
	print("rewrite cases %d (ok %d); planted told %d (logged once %d); Monitor cases %d (window %d)" % [cases, rewrites_ok, planted_cases, planted_once, monitor_cases, monitor_window])
	_check(cases >= 5 and rewrites_ok == cases, "only the chosen planter's untold watch report is rewritten, and the rewrite is logged as a lie")
	_check(planted_cases >= 3 and planted_once == planted_cases, "a planted sighting is logged as a lie when told, and only once")
	_check(monitor_cases >= 5 and monitor_window == 0, "a Monitor bluffer is never given a window sighting")
	print("Frame planter fixes: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
