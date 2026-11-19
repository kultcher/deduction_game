## Every hint family has a card form, and a hint card reads it (Michael's names, Nov 18):
## "Lian hints: the gallows", and "Rumour: Lian, the gallows" for tavern gossip.
##   godot --headless --path . --script res://tools/test_hint_cards.gd
extends SceneTree
const C = preload("res://sim/content.gd")
const CardModel = preload("res://game/card_model.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL " + label)

func _init() -> void:
	var names = {"lian": "Lian"}
	for pkg in C.HINT_PACKAGES:
		var card: String = str(C.HINT_PACKAGES[pkg].get("card", ""))
		check(card != "", "%s has a card form" % pkg)
		var own: String = CardModel.short_text({"kind": "hint", "package": pkg, "subject": ["lian"], "source": "lian", "text": "x"}, names)
		check(own == "Lian hints: %s" % card, "%s: the person's own hint (got %s)" % [pkg, own])
		var heard: String = CardModel.short_text({"kind": "hint", "package": pkg, "subject": ["lian"], "source": "rumour", "tavern_gossip": true, "text": "x"}, names)
		check(heard == "Rumour: Lian, %s" % card, "%s: tavern gossip keeps its Rumour (got %s)" % [pkg, heard])
	print("Hint cards: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
