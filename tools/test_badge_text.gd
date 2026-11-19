## The case-strength badge's words (Michael, Nov 19): Negligible / Weak / Moderate / Strong, and
## a top tier that reads "Damning" on an accusation and "Conclusive" on any other premise, each
## with its reason line; a lie call weighed as a draw is marked "Stand-off".
##   godot --headless --path . --script res://tools/test_badge_text.gd
extends SceneTree

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 692
	scene.size_opt.select(1)
	scene._new_case()
	scene.roles_win.hide()
	scene.case_view.open_workshop()
	await process_frame
	await process_frame
	var ed = scene.case_view.workshop.editor
	var canvas = ed.canvas
	var g = scene.g
	var who = g.w.npcs[0]
	check(canvas.STRENGTH_TEXT.none == "Negligible", "the bottom tier reads Negligible")

	var accuse: String = ed.board.add_premise(who.id, "evil", Vector2(0, 0))
	var top: Dictionary = canvas.top_tier(accuse)
	check(top.label == "Damning" and top.line == "This case is damning: an ordinary townsperson would vote for %s over anyone else." % who.name, "an accusation's top tier is Damning (%s)" % top.line)
	var clears: String = ed.board.add_premise(who.id, "good", Vector2(400, 0))
	top = canvas.top_tier(clears)
	check(top.label == "Conclusive" and top.line == "This case is conclusive: an ordinary townsperson would take it as settled that %s is good." % who.name, "any other premise's is Conclusive (%s)" % top.line)

	# Being good doesn't settle every clearing premise: those stop at Strong (Codex, #358).
	var gift: String = ed.board.add_premise(who.id, "role", Vector2(800, 0))
	check(canvas.top_tier(gift).is_empty(), "\"holds their claimed gift\" can't be called settled by their being good")
	check(canvas.top_tier(ed.board.add_premise(who.id, "notdemon", Vector2(1200, 0))).get("label", "") == "Conclusive", "\"is not the Demon\" can")
	canvas.badges = {gift: {"ready": true, "category": "damning", "text": "placeholder", "reason": "", "lr": 5.0}}
	canvas.queue_redraw()
	await process_frame
	await process_frame
	var gift_tip: String = ""
	for t in canvas.tips:
		if "Test juror:" in str(t.text):
			gift_tip = t.text
	check("strongly supports" in gift_tip and not ("conclusive" in gift_tip), "its chip reads the tier its evidence earns, here Strong (%s)" % gift_tip.get_slice("\n", 0))
	canvas.badges[gift].lr = 1.6
	canvas.queue_redraw()
	await process_frame
	await process_frame
	for t in canvas.tips:
		if "Test juror:" in str(t.text):
			gift_tip = t.text
	check("weakly supports" in gift_tip, "and Weak when that's all the evidence earns (%s)" % gift_tip.get_slice("\n", 0))

	# Drawn: the chip and its tooltip carry the words.
	var challenge: Dictionary = {"reading": "card-x", "teller": who.id, "kind": "draw", "witnesses": []}
	canvas.badges = {accuse: {"ready": true, "category": "damning", "text": "placeholder", "reason": "", "listener": {"challenges": [challenge]}}}
	canvas.queue_redraw()
	await process_frame
	await process_frame
	var tip: String = ""
	for t in canvas.tips:
		if "Test juror:" in str(t.text) and who.name in str(t.text):
			tip = t.text
	check("would vote for %s over anyone else" % who.name in tip and not ("placeholder" in tip), "the drawn chip's tooltip gives the Damning line, not the placeholder")
	check("Your word against %s's." % who.name in tip, "and the lie call's line (%s)" % tip.replace("\n", " | "))
	check(canvas.lie_call("card-x").get("kind", "") == "draw" and canvas.lie_call("other").is_empty(), "a lie call is found by its card")
	print("Badge text: %d checks, %d failures" % [checks, fails])
	scene.queue_free()
	quit(1 if fails else 0)
