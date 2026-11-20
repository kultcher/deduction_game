## BACKLOG "A whereabouts contradiction gets an irrelevant gift refusal" (78148, Kiran;
## [decided]). A pressed case whose cited cards place its subject out on a night carries
## that to the press as `contradiction` (GameConversation.press_contradiction; Quill).
## Beadle chooses the answer from it (MindDialogue.press). Pinned here: a case like
## Kiran's carries it, with the night the cards use, the block, the cards and the alibi it
## breaks; a reading-only case, an empty vigil, or cards on two nights don't.
##   godot --headless --path . --script res://tools/test_press_contradiction.gd
extends SceneTree

const GameBoard = preload("res://game/game_board.gd")
const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Conv = preload("res://game/game_conversation.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1


func _setup() -> Array:
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://test_logs"
	g.new_case(13910, 10)
	g.w.day = 3
	var goods: Array = g.w.living_good()
	return [g, goods[0], goods[1], goods[2]]


## A pressed "suspicious" case on `n` citing the given board cards.
func _case(g, n, cards: Array) -> Dictionary:
	var nums: Array = cards.map(func(c): return GameBoard.add_card(g, c))
	var pc: Dictionary = {"kind": "deduction", "conclusion": {"type": "suspicious", "a": n.id}, "subject": [n.id], "supports": nums, "text": "A case"}
	pc["support_cards"] = GameBoard.all_receipts(g).filter(func(x): return x["n"] in nums)
	return {"pc": pc, "nums": nums}


func _init() -> void:
	var s: Array = _setup()
	var g = s[0]
	var n = s[1]
	var watcher = s[2]
	# Kiran's case: their own home alibi for the first night, and the player's vigil that saw them leave.
	var alibi: Dictionary = {"kind": "alibi", "subject": [n.id], "source": n.id, "day": 1, "phase": C.NIGHT, "home": true, "block": n.home_block, "text": "%s: at home the first night." % n.name}
	var seen: Dictionary = {"kind": "sighting", "subject": [n.id], "block": n.home_block, "source": "player", "day": 1, "phase": C.NIGHT, "vigil": true, "text": "Night 1 vigil: you saw %s go out." % n.name}
	var made: Dictionary = _case(g, n, [alibi, seen])
	var ctx: Dictionary = Conv.press_contradiction(g, n, made.pc)
	print("context: %s" % ctx)
	check(not ctx.is_empty() and int(ctx.night) == 1 and str(ctx.block) == n.home_block, "a vigil that saw them leave places them out that night, on that block")
	check(ctx.get("ruled_out_home_by", []) == [made.nums[1]], "it names the card that placed them out, not the alibi it breaks")
	check(ctx.get("against_alibi", false), "it notes they had given their own home alibi for that night")
	# A Night Watch report naming them places them out too.
	var s2: Array = _setup()
	var nw: Dictionary = {"kind": "info", "role": "nightwatch", "subject": [s2[1].id], "source": s2[2].id, "day": 2, "phase": C.NIGHT, "data": {"block": "docks", "seen": [s2[1].id]}, "text": "Night Watch on the Docks"}
	var m2: Dictionary = _case(s2[0], s2[1], [nw])
	var c2: Dictionary = Conv.press_contradiction(s2[0], s2[1], m2.pc)
	check(not c2.is_empty() and int(c2.night) == 2 and str(c2.block) == "docks" and not c2.against_alibi, "a Night Watch report naming them places them out, with no alibi to break")
	# Nothing places them out: a reading, or an empty vigil.
	var s3: Array = _setup()
	var reading: Dictionary = {"kind": "info", "role": "seer", "subject": [s3[1].id], "source": s3[2].id, "day": 1, "phase": C.NIGHT, "data": {"pair": [s3[1].id, s3[3].id], "yes": true}, "text": "One of them"}
	var empty: Dictionary = {"kind": "vigil", "subject": [], "block": s3[1].home_block, "source": "player", "day": 1, "phase": C.NIGHT, "text": "Night 1 vigil: nobody stirred."}
	var m3: Dictionary = _case(s3[0], s3[1], [reading, empty])
	check(Conv.press_contradiction(s3[0], s3[1], m3.pc).is_empty(), "a reading or an empty vigil places no one out: no context")
	# Their own sighting of themselves doesn't count against them.
	var s4: Array = _setup()
	var own: Dictionary = {"kind": "sighting", "subject": [s4[1].id], "block": "market", "source": s4[1].id, "day": 1, "phase": C.NIGHT, "text": "I was out"}
	check(Conv.press_contradiction(s4[0], s4[1], _case(s4[0], s4[1], [own]).pc).is_empty(), "their own word about their night isn't a contradiction")
	# Two nights: never merged.
	var s5: Array = _setup()
	var a1: Dictionary = {"kind": "sighting", "subject": [s5[1].id], "block": "square", "source": s5[2].id, "day": 1, "phase": C.NIGHT, "text": "out night 1"}
	var a2: Dictionary = {"kind": "sighting", "subject": [s5[1].id], "block": "hill", "source": s5[2].id, "day": 2, "phase": C.NIGHT, "text": "out night 2"}
	check(Conv.press_contradiction(s5[0], s5[1], _case(s5[0], s5[1], [a1, a2]).pc).is_empty(), "cards placing them out on two different nights give no context (never merged)")
	print("Press contradiction: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)
