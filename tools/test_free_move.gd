## Moving within a block is free (Michael, Nov 28): once the phase's place is chosen, the
## Demonologist can go to any place on the same block as often as they like, and 'talk' walks
## them over to someone on the block every time. A move to another block still waits for the
## next phase.
##   godot --headless --path . --script res://tools/test_free_move.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")

var checks = 0
var fails = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		fails += 1
		push_error(label)

func _init() -> void:
	var moved_ok := 0
	var cases := 0
	var cross_refused := true
	var talk_walks := 0
	var talk_cases := 0
	for sd in range(900, 960):
		var g = Game.new()
		g.detailed_logging = false
		g.new_case(sd, 10)
		if g.state == "approach":
			g.command("decline")
		if g.state != "day":
			continue
		# A block with two public places (each block has two).
		var blk: String = ""
		for b in C.BLOCKS.keys():
			if g.w.locations_on(b).filter(func(l): return not str(l).begins_with("home_")).size() >= 2:
				blk = b
				break
		if blk == "":
			continue
		var locs: Array = g.w.locations_on(blk).filter(func(l): return not str(l).begins_with("home_"))
		g.command("go " + str(locs[0]))
		if g.loc != locs[0]:
			continue
		cases += 1
		var ok: bool = true
		for l in [locs[1], locs[0], locs[1]]:
			g.command("go " + str(l))
			ok = ok and g.loc == l and g.state == "day"
		moved_ok += int(ok)
		# Another block: still refused this phase.
		for b in C.BLOCKS.keys():
			if b != blk and not g.w.locations_on(b).is_empty():
				var there: String = str(g.w.locations_on(b)[0])
				g.command("go " + there)
				cross_refused = cross_refused and g.loc != there
				break
		# 'talk' walks over to someone elsewhere on the block, after the moves above.
		for m in g.w.living():
			if m.loc != g.loc and not m.at_home() and g.w.loc_block(m.loc) == blk and m.busy_with == "":
				talk_cases += 1
				var target_loc: String = m.loc
				g.command("talk " + m.name.to_lower())
				talk_walks += int(g.loc == target_loc and g.state == "talk")
				break
	print("cases %d, moved freely %d; talk cases %d, walked over %d" % [cases, moved_ok, talk_cases, talk_walks])
	_check(cases >= 10 and moved_ok == cases, "within a block, the Demonologist moves as often as they like")
	_check(cross_refused, "a move to another block still waits for the next phase")
	_check(talk_cases >= 3 and talk_walks == talk_cases, "'talk' walks over to someone on the block, even after several moves")
	print("Free move: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
