## An evil Gravedigger's report on a hanged good person follows what the town believed
## (Project doc belief-model-direction, Nov 11; playtest 30987: the evil Hollis vouched for
## the hanged Dorian, whom the town thought evil, and was hanged next).
##   - a near-unanimous hanging: usually "they were a Minion" (keeps the frame);
##   - a bare majority: usually confirm their claim, sometimes gamble on a frame;
##   - a bolder (more confident) evil NPC frames more often;
##   - a hanged teammate is still covered with their bluff.
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Gravedigger = preload("res://sim/roles/gravedigger.gd")

var checks: int = 0
var fails: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1


func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(5150, 7)
	var w = g.w
	var evil: Array = w.npcs.filter(func(n): return n.is_evil())
	var good: Array = w.npcs.filter(func(n): return not n.is_evil())
	var digger = evil[0]
	var hanged = good[0]
	hanged.claimed_role = "medium"
	w.executed_today = hanged.id
	var voters: Array = good.slice(1).map(func(n): return n.id) + evil.map(func(n): return n.id)
	var role_def = C.role_def("gravedigger")
	var minions: Array = w.case_script.minions

	var run: Callable = func(yes_n: int, no_n: int, conf: float, player_yes: bool = false) -> Dictionary:
		w.executions = [{"day": w.day, "id": hanged.id, "nominator": evil[0].id, "yes": voters.slice(0, yes_n), "no": voters.slice(yes_n, yes_n + no_n), "player_yes": player_yes}]
		digger.traits["confidence"] = conf
		var framed := 0
		var confirmed := 0
		for i in range(400):
			var r: Dictionary = role_def.generate_bluff_reading(w, digger, {"bluffs": {}}, "", null, [])
			var role: String = str(r.entry.data.role)
			if role in minions:
				framed += 1
			elif role == "medium":
				confirmed += 1
		return {"framed": framed / 400.0, "confirmed": confirmed / 400.0}

	var n_votes: int = voters.size()
	var half: int = int(n_votes / 2)
	check(is_equal_approx(Gravedigger.town_certainty(w, "nobody"), 0.5), "no hanging vote on record: certainty 0.5")
	var sure: Dictionary = run.call(n_votes, 0, 0.5)
	# A bare majority: half the NPC voters plus the player yes, the other half no.
	var split: Dictionary = run.call(half, n_votes - half, 0.5, true)
	print("  unanimous: framed %.2f, confirmed %.2f; bare majority (%d-%d): framed %.2f, confirmed %.2f" % [sure.framed, sure.confirmed, half + 1, n_votes - half, split.framed, split.confirmed])
	check(sure.framed > 0.7, "a unanimous hanging: the Gravedigger usually calls them a Minion (%.2f)" % sure.framed)
	check(split.framed < 0.4 and split.confirmed > 0.6, "a bare-majority hanging: usually confirms their claim (%.2f confirmed)" % split.confirmed)
	check(split.framed > 0.05, "a bare-majority hanging: sometimes gambles on a frame (%.2f)" % split.framed)
	var bold: Dictionary = run.call(half, n_votes - half, 1.0, true)
	var timid: Dictionary = run.call(half, n_votes - half, 0.0, true)
	check(bold.framed > timid.framed, "a bolder evil NPC frames more often (%.2f against %.2f)" % [bold.framed, timid.framed])
	check(sure.framed + sure.confirmed > 0.999, "every report is a Minion or their own claim")

	# A hanged teammate is still covered with their bluff.
	var mate = evil[1] if evil.size() > 1 else evil[0]
	w.executed_today = mate.id
	var r2: Dictionary = role_def.generate_bluff_reading(w, digger, {"bluffs": {mate.id: "clerk"}}, "", null, [])
	check(str(r2.entry.data.role) == "clerk", "a hanged teammate is covered with their bluff")
	print("Gravedigger bluff: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
