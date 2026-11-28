## Playtest 52102, finding 5 (Michael, Nov 27): a Surveyor's parity reading ("all the folk
## living on the Market share the same alignment") names no one, but it's about each of the
## block's residents. Presenting it to one of them, the about-me check, and CardModel.about
## (the board's links, the profile's "said of them") all count it as about them, and as about
## no one living elsewhere. A Surveyor count, which names no block, stays about no one.
##   godot --headless --path . --script res://tools/test_block_reading_subjects.gd
extends SceneTree
const Game = preload("res://game/game.gd")
const GameBoard = preload("res://game/game_board.gd")
const GamePresentation = preload("res://game/game_presentation.gd")
const CardModel = preload("res://game/card_model.gd")
const MindPress = preload("res://sim/mind_press.gd")
var checks := 0
var fails := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: " + label)

const NOT_ABOUT_ME = "What has that to do with me?"

func _not_about_me(result: Dictionary) -> bool:
	return result.get("lines", []).any(func(l): return l is Dictionary and str(l.get("statement", "")) == NOT_ABOUT_ME)

func _init() -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(1, 10)
	# A block with at least two living residents, and someone living elsewhere.
	var block: String = ""
	var residents: Array = []
	for b in ["market", "square", "docks", "hill"]:
		var here: Array = g.w.npcs.filter(func(m): return m.alive and m.home_block == b)
		if here.size() >= 2:
			block = b
			residents = here
			break
	check(block != "", "(fixture) a block with two living residents")
	if block == "":
		_done()
		return
	var outsider = g.w.npcs.filter(func(m): return m.alive and m.home_block != block)[0]
	var teller = g.w.npcs.filter(func(m): return m.alive and m.home_block != block and m != outsider)[0]
	var parity: int = GameBoard.add_card(g, {"kind": "info", "source": teller.id, "role": "surveyor", "day": 0, "phase": 3,
		"data": {"block": block, "same": true}, "text": "%s's Surveyor: all the folk living on the %s share the same alignment" % [teller.name, block]})
	var count: int = GameBoard.add_card(g, {"kind": "info", "source": teller.id, "role": "surveyor", "day": 0, "phase": 3,
		"data": {"count": 2}, "text": "%s's Surveyor: evil lives on 2 blocks" % teller.name})
	var card: Dictionary = g.board[parity - 1]
	var about: Array = CardModel.about(card)
	check(residents.all(func(r): return r.id in about), "CardModel.about names every resident of the block (%s)" % str(about))
	check(not (outsider.id in about), "and no one living elsewhere")
	check(CardModel.about(g.board[count - 1]).is_empty(), "a Surveyor count names no block, so no one")
	# The about-me check: a resident pressed with it answers it; someone elsewhere doesn't.
	var r_press: Dictionary = MindPress.press(g.w, residents[0], card)
	check(not _not_about_me(r_press), "a resident pressed with it doesn't say it isn't about them (%s)" % str(r_press.get("lines", [])))
	var o_press: Dictionary = MindPress.press(g.w, outsider, card)
	check(_not_about_me(o_press), "someone living elsewhere does")
	# Presenting it to a resident puts it to them directly.
	var route: Dictionary = GamePresentation._route_present(g, residents[0], str(parity))
	check(str(route.get("verb", "")) == "press", "presenting it to a resident puts it to them directly (%s)" % str(route))
	_done()

func _done() -> void:
	print("Block reading subjects: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
