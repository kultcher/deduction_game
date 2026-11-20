## Playtest 89077 (Coroner, Nov 17): the end-of-case "evidence that was reachable" listed a
## dead townsperson's Night Watch reading with no Medium alive to hear it. A dead
## townsperson's evidence counts only while a living good Medium could reach it.
extends SceneTree
const Game = preload("res://game/game.gd")
const CaseMetrics = preload("res://game/case_metrics.gd")
var checks = 0
var fails = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(89077, 10)
	var w = g.w
	var demon = w.by_id[w.demon_id]
	var good: Array = w.npcs.filter(func(n): return not n.is_evil())
	var witness = good[0]
	witness.beliefs.append({"kind": "saw", "who": demon.id, "phase": 3, "day": 2, "block": demon.home_block})
	var line: String = "%s saw %s out on night 2" % [witness.name, demon.name]
	check(line in CaseMetrics.demon_evidence(w, []).reachable, "a living witness's sighting of the Demon is reachable")
	witness.alive = false
	for m in w.npcs:
		if m.role == "medium" and m != witness:
			m.alive = false
	check(not (line in CaseMetrics.demon_evidence(w, []).reachable), "a dead witness's sighting isn't, with no Medium alive")
	# Told before dying: a living good listener still holds it (Codex, #202).
	var heard = good.filter(func(n): return n.alive and n != witness)[0]  # (good[2] may be the Medium killed above)
	heard.hearsay.append({"kind": "sighting", "from": witness.id, "about": demon.id, "day": 2, "block": demon.home_block})
	check(line in CaseMetrics.demon_evidence(w, []).reachable, "a dead witness's sighting a living townsperson heard stays reachable")
	heard.hearsay.pop_back()
	var medium = good[1]
	var old_role: String = medium.role
	medium.role = "medium"
	medium.alive = true
	check(line in CaseMetrics.demon_evidence(w, []).reachable, "a living good Medium could still reach it")
	medium.role = old_role
	print("case metrics dead: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
