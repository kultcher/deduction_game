## The Workshop canvas's evidence cards show the board's short form, and keep the full
## sentence for the hover (Michael, Nov 18: the fewest words on a card).
##   godot --headless --path . --script res://tools/test_canvas_card_text.gd
extends SceneTree
const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CardModel = preload("res://game/card_model.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL " + label)

func _init() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(692, 7)
	var a = g.w.npcs[0]
	var b = g.w.npcs[1]
	var n: int = g.add_card({"kind": "accusation", "source": a.id, "subject": [b.id], "day": 1, "phase": 1,
		"text": "%s publicly accused %s at the meeting on the first day." % [a.name, b.name]})
	var view: Dictionary = Live.view(g)
	var full: String = g.board[n - 1].text
	var shown: Array = view.cards.filter(func(c): return c.text == full)
	check(shown.size() == 1, "the accusation reaches the canvas")
	if shown.size() == 1:
		var names := {}
		for p in g.w.npcs:
			names[p.id] = p.name
		check(shown[0].short == CardModel.short_text(g.board[n - 1], names), "the canvas card carries the board's short form (got %s)" % shown[0].short)
		check(shown[0].short.length() < full.length() and shown[0].text == full, "shorter than the sentence, which stays for the hover")
	check(view.cards.all(func(c): return str(c.get("short", "")) != ""), "every canvas card has something to show")
	print("Canvas card text: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
