## The way back from a wrong lie call (Michael, Nov 19):
##   (a) a second case that calls Mistaken a reading an earlier case called a lie is refused
##       with a signpost to revising that case, not "conflicting reading challenges";
##   (b) "I was wrong: call it a mistake" on a lie call switches it to Mistaken, and the
##       Present button then says the revision replaces the case the town heard.
## Revising the case itself is never refused by its own old version.
##   godot --headless --path . --script res://tools/test_mistake_signpost.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const Live = preload("res://game/workshop_canvas.gd")
const CanvasModel = preload("res://workshop/canvas_model.gd")
const Solver = preload("res://workshop/solver.gd")
const RC = preload("res://workshop/reading_challenges.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

## The first seed from 1 whose 7-NPC case has a Poisoner on its script (so Mistaken is allowed).
func _seed() -> int:
	for sd in range(1, 200):
		var g = Game.new()
		g.log_dir = "user://test_logs"
		g.new_case(sd, 7)
		if "poisoner" in g.w.case_script.minions and g.w.living_good().size() >= 5:
			return sd
	return -1

func _reading(g, goods: Array) -> String:
	var text: String = "%s's Archivist reading: one of %s and %s is the Poisoner" % [goods[0].name, goods[2].name, goods[3].name]
	g.add_card({"kind": "info", "source": goods[0].id, "role": "archivist", "day": 0, "phase": 3, "data": {"pair": [goods[2].id, goods[3].id], "role": "poisoner"}, "text": text})
	return text

## A canvas case that `who` is good, citing the reading called `mode`.
func _case(g, text: String, who: String, mode: String) -> Dictionary:
	var view: Dictionary = Live.view(g)
	var model = CanvasModel.new(view)
	model.contradiction_links = true
	model.marked_answers = false
	var node: String = ""
	for id in model.nodes:
		if model.nodes[id].kind == "evidence" and Solver.card_by_id(view, model.nodes[id].card).get("text", "") == text:
			node = id
	var premise: String = model.add_premise(who, "good", Vector2(400, 40))
	model.add_modifier(node, mode)
	model.connect_cards(model.selected, premise)
	return {"model": model, "premise": premise, "value": model.compile(premise)}

func _run() -> void:
	var sd: int = _seed()
	check(sd > 0, "a seed with a Poisoner on the script (%d)" % sd)
	if sd < 0:
		return _done()
	_game_side(sd)
	await _workshop_side(sd)
	_done()

func _game_side(sd: int) -> void:
	var g = Game.new()
	g.log_dir = "user://test_logs"
	g.new_case(sd, 7)
	g.w.day = 2
	var goods: Array = g.w.living_good()
	var text: String = _reading(g, goods)
	var lie: Dictionary = _case(g, text, goods[2].id, "lying")
	var a: int = Live.file(g, lie.value)
	check(a > 0, "the lie-call case files (#%d)" % a)
	check(not Live.was_presented(g, a), "nobody has heard it yet")
	g._evaluate_deduction(goods[1], g.board[a - 1], 1.0)
	check(Live.was_presented(g, a), "once presented, it has been heard")
	# A case put in a private accusation or defence is held under a "direct:" key (Codex, #363).
	var direct: int = Live.file(g, _case(g, text, goods[3].id, "lying").value)
	check(not Live.was_presented(g, direct), "a second lie-call case nobody has heard (#%d)" % direct)
	goods[1].workshop_state.get("presentations", {})["direct:%d:accuse:%s" % [direct, goods[3].id]] = {}
	check(Live.was_presented(g, direct), "heard through a private accusation, it counts as heard")
	goods[1].workshop_state.presentations.erase("direct:%d:accuse:%s" % [direct, goods[3].id])
	g.board[direct - 1].deleted = true

	# (a) A second case calling the same reading Mistaken.
	var honest: Dictionary = _case(g, text, goods[3].id, RC.HONEST)
	var raw: Array = [Live.CONFLICTING_CALLS + "."]
	var shown: Array = Live.player_issues(g, honest.value, raw)
	var want: String = Live.SIGNPOST_PRESENTED % [goods[0].name, a, a]
	check(shown == [want], "the refusal becomes the signpost (%s)" % str(shown))
	check(Live.player_issues(g, honest.value, ["Some other issue."]) == ["Some other issue."], "other issues are untouched")
	# A newer case with the same lie call that nobody has heard isn't the one to revise (Codex, #363).
	var draft: int = Live.file(g, _case(g, text, goods[4].id, "lying").value)
	check(draft > a and not Live.was_presented(g, draft), "a newer, unheard case calls the same lie (#%d)" % draft)
	check(Live.player_issues(g, honest.value, raw) == [want], "the signpost still names the heard case #%d" % a)
	# Two heard cases making the call: revising one wouldn't clear the refusal, so no signpost.
	g._evaluate_deduction(goods[1], g.board[draft - 1], 1.0)
	check(Live.was_presented(g, draft) and Live.player_issues(g, honest.value, raw) == raw, "two heard cases calling the lie keep the plain refusal")
	g._workshop_retract(draft, goods[1].id)
	g.board[draft - 1].deleted = true
	# A call on the other side of a Medium's relay isn't settled by switching the mode: no signpost.
	var other_side: Dictionary = honest.value.duplicate(true)
	for rid in other_side.reading_challenges:
		other_side.reading_challenges[rid]["attribution"] = "original"
	check(Live.player_issues(g, other_side, raw) == raw, "calls on different sides of a relay keep the plain refusal")
	# On a Medium's relay, the original side's reading is the dead reader's, not the Medium's (Codex, #363).
	var medium = goods[1]
	var dead = goods[4]
	var entry = {"role": "seer", "day": 0, "data": {"pair": [goods[2].id, goods[3].id], "yes": true}, "text": "Original Seer reading"}
	var mn: int = g.add_card({"kind": "info", "source": medium.id, "subject": [], "role": "medium", "day": 2, "phase": 3,
		"data": {"dead": dead.id, "item": {"type": "reading", "entry": entry}}, "text": "Medium repeats dead Seer"})
	var mid: String = Live.Evidence.normalize_card(g.board[mn - 1]).id
	check(Live._challenged_teller(g, mid, "original") == dead.id and Live._challenged_teller(g, mid, "transmission") == medium.id, "a relay's original side names the dead reader, its passing-on the Medium")
	var b: int = Live.file(g, honest.value)
	check(b > 0, "the second case files (#%d)" % b)
	g.events = []
	var ok: bool = g._presentation_gate(g.board[b - 1], [goods[1]], [goods[3].id], "deduction", "private")
	var said: String = " ".join(PackedStringArray(g.events.map(func(e): return str(e.get("text", "")))))
	check(not ok and want in said, "presenting the second case to someone who heard the first gives the signpost (%s)" % said)
	check(not ("Remove the unsupported card" in said), "and not the advice to remove a card")

	# Revising the case itself: its old version never refuses it.
	var revised: Dictionary = lie.value.duplicate(true)
	for rid in revised.reading_challenges:
		revised.reading_challenges[rid].mode = RC.HONEST
	check(Live.lie_called_elsewhere(g, revised, a).is_empty(), "a revision isn't sent back to its own old version")
	var r: int = Live.file(g, revised, a)
	check(r > 0 and int(g.board[r - 1].get("revises", 0)) == a and Live.was_presented(g, r), "the revision files over case #%d and counts as heard through it" % a)
	# Filed but not yet heard: the listener still holds case #a's lie, so the second case is still
	# refused, and the signpost points at the revision to present (Codex, #363).
	var pending: Array = Live.player_issues(g, honest.value, raw)
	check(pending == [Live.SIGNPOST_PRESENTED % [goods[0].name, a, r]], "until the revision is heard, the signpost names case #%d and the revision #%d (%s)" % [a, r, str(pending)])
	g.events = []
	g._presentation_gate(g.board[r - 1], [goods[1]], [goods[2].id], "deduction", "private")
	var rsaid: String = " ".join(PackedStringArray(g.events.map(func(e): return str(e.get("text", "")))))
	check(not ("Conflicting reading" in rsaid) and not ("You called" in rsaid), "presenting the revision to someone who heard the lie isn't refused for it (%s)" % rsaid)

func _workshop_side(sd: int) -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = sd
	scene.size_opt.select(0)
	scene._new_case()
	scene.roles_win.hide()
	var g = scene.g
	g.w.day = 2
	var goods: Array = g.w.living_good()
	_reading(g, goods)
	scene.case_view.open_workshop()
	await process_frame
	await process_frame
	var ed = scene.case_view.workshop.editor
	ed.refresh()
	var ev: String = ed.add_evidence(g.board.size())
	var premise: String = ed.board.add_premise(goods[2].id, "good", Vector2(400, 40))
	ed.board.add_modifier(ev, "lying")
	var mod: String = ed.board.selected
	ed.board.connect_cards(mod, premise)
	ed.board.selected = premise
	var a: int = ed._file()
	check(a > 0 and ed.files.get(premise, 0) == a, "the Workshop files the lie-call case (#%d)" % a)

	# Before anyone hears it: the action is there and just switches the call.
	ed._context(mod)
	var at: int = ed.context_menu.get_item_index(ed.TAKE_BACK_LIE)
	check(at >= 0 and not ed.context_menu.is_item_disabled(at), "a lie call offers \"%s\"" % ed.TAKE_BACK_LIE_TEXT)
	check(ed.context_menu.get_item_text(at) == "I was wrong: call it a mistake", "worded as approved")
	check(ed.context_menu.get_item_tooltip(at) == "Take back the lie: the reading was wrong, but honestly told.", "an unheard case's tooltip names no case")
	ed.context_menu.hide()

	# Heard: the tooltip names the case, and after the switch Present says it replaces it.
	g._evaluate_deduction(goods[1], g.board[a - 1], 1.0)
	g.state = "meeting"
	ed._context(mod)
	at = ed.context_menu.get_item_index(ed.TAKE_BACK_LIE)
	check(ed.context_menu.get_item_tooltip(at) == "Take back the lie: the reading was wrong, but honestly told. Presenting the revision replaces case #%d for everyone who hears it." % a, "a heard case's tooltip says the revision replaces it")
	ed.context_menu.hide()
	ed._context_action(ed.TAKE_BACK_LIE)
	check(RC.canonical(ed.board.nodes[mod].mode) == RC.HONEST, "the call is now Mistaken")
	ed.board.selected = premise
	ed._edit()
	await process_frame
	check(ed.revision_of() == a and ed.present_button.text == "Present the revision (replaces case #%d)" % a, "Present reads \"%s\"" % ed.present_button.text)
	ed._context(mod)
	check(ed.context_menu.get_item_index(ed.TAKE_BACK_LIE) < 0, "a Mistaken call no longer offers it")
	ed.context_menu.hide()
	scene.queue_free()

func _done() -> void:
	print("Mistake signpost: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
