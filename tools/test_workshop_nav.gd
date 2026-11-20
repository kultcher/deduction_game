## Finding your way on the Workshop canvas (Michael, Nov 19): an added card is centred and
## glows until moved; cards off-screen get one marker per direction; a right-click on empty
## canvas adds a person's readings, given by them or naming them.
##   godot --headless --path . --script res://tools/test_workshop_nav.gd
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
	var g = scene.g
	# Play on until a reading that names someone reaches the board.
	var reading: Dictionary = {}
	for i in range(80):
		for c in g.board:
			if c.get("kind", "") == "info" and not c.get("subject", []).is_empty() and c.get("workshop_usable", true):
				reading = c
				break
		if not reading.is_empty():
			break
		match g.state:
			"approach": scene._run("decline")
			"talk": scene._run("bye")
			"meeting", "nomination": scene._run("done" if g.town_quiet else "wait")
			"night": scene._run("sleep")
			_: scene._run("wait")
		scene.finish_streaming()
		scene.meeting_view.stage.clear()
		if scene.conversation_finished:
			scene._leave_finished_conversation()
			scene.finish_streaming()
			scene.meeting_view.stage.clear()
	check(not reading.is_empty(), "a reading reaches the board (day %d, state %s, %d cards)" % [g.w.day, g.state, g.board.size()])
	if reading.is_empty():
		_done(scene)
		return
	scene.case_view.open_workshop()
	await process_frame
	await process_frame
	var ed = scene.case_view.workshop.editor
	var canvas = ed.canvas
	var reader: String = str(reading.source)
	var named: String = str(reading.subject[0])
	check(int(reading.n) in ed.readings_for(reader, true), "FROM the reader includes their reading")
	check(int(reading.n) in ed.readings_for(named, false), "ABOUT a person it names includes it")
	check(not (int(reading.n) in ed.readings_for(named, true)) or named == reader, "FROM someone it only names doesn't")
	var rid: String = ed.Live.Evidence.normalize_card(reading).id
	var rcs: Array = ed.board.view.cards.filter(func(c): return c.id == rid)
	if not rcs.is_empty() and str(reading.get("role", "")) != "medium" and not rcs[0].get("fallback", false):
		check(rcs[0].get("support_note", "x") == "", "a weighable reading carries no note (%s)" % rcs[0].get("support_note", ""))

	# Adding a card centres it and marks it fresh.
	canvas.pan = Vector2(-5000, -5000)
	var id: String = ed.add_evidence(int(reading.n))
	check(id != "" and canvas.fresh.has(id), "the added card glows")
	var at: Vector2 = canvas._screen(canvas.world_rect(id)).get_center()
	check(at.distance_to(canvas.size / 2.0) < 2.0, "and the view centres on it (%s vs %s)" % [str(at), str(canvas.size / 2.0)])
	# Moving it ends the glow.
	canvas.drag = id
	var mv = InputEventMouseMotion.new()
	mv.position = canvas.last_mouse + Vector2(30, 0)
	canvas._gui_input(mv)
	canvas.drag = ""
	check(not canvas.fresh.has(id), "moving the card ends its glow")

	# Off-screen cards: one marker per direction, with the cards it covers.
	canvas.pan = canvas.size / 2.0 - canvas.world_rect(id).get_center() * canvas.zoom + Vector2(canvas.size.x * 3.0, 0)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	check(canvas.edge_marks.size() == 1 and id in canvas.edge_marks[0].ids, "cards all off to one side get one marker between them (%d)" % canvas.edge_marks.size())
	if canvas.edge_marks.size() == 1:
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = canvas.edge_marks[0].rect.get_center()
		canvas._gui_input(click)
		check(Rect2(Vector2.ZERO, canvas.size).intersects(canvas._screen(canvas.world_rect(id))), "clicking the marker brings those cards back into view")

	# The right-click menu on empty canvas.
	ed._background_menu(Vector2.ZERO)
	check(ed.bg_from.item_count == g.w.npcs.size() and ed.bg_about.item_count == g.w.npcs.size(), "both submenus list everyone")
	var ri: int = ed._bg_people.find(named)
	var before: int = ed.board.nodes.size()
	var want: Array = ed.readings_for(named, false)
	ed._bg_add(ri, false)
	var have: int = want.filter(func(n): return ed.board.nodes.has("e:" + ed.Live.Evidence.normalize_card(g.board[n - 1]).id)).size()
	check(have == want.size() and ed.board.nodes.size() >= before, "\"Add all readings about\" puts each of them on the canvas (%d of %d)" % [have, want.size()])
	ed.bg_menu.hide()
	# Several cards dropped at once come into view together (Codex, #323).
	var several: Array = g.board.filter(func(c): return ed._usable(int(c.n))).map(func(c): return int(c.n)).slice(0, 4)
	canvas.pan = Vector2(-9000, -9000)
	scene.case_view.workshop._drop_cards(several)
	var in_view: int = 0
	for nb in several:
		var nid: String = "e:" + ed.Live.Evidence.normalize_card(g.board[nb - 1]).id
		if ed.board.nodes.has(nid) and Rect2(Vector2.ZERO, canvas.size).intersects(canvas._screen(canvas.world_rect(nid))):
			in_view += 1
	check(several.size() >= 2 and in_view == several.size(), "a drop of several cards brings them all into view (%d of %d)" % [in_view, several.size()])
	# A card that leaves the board stays on the canvas, marked unweighable in plain words (Michael, Nov 19).
	var gone_n: int = int(reading.n)
	g.board[gone_n - 1].deleted = true
	ed.refresh()
	var gone: Dictionary = canvas._evidence_card(id) if ed.board.nodes.has(id) else {}
	check(gone.get("off_board", false) and canvas._unsupported(gone), "a card no longer on the board is marked unsupported")
	check(gone.get("support_note", "") == "This card has changed or is no longer on your board.", "and its note says so plainly (%s)" % gone.get("support_note", ""))
	g.board[gone_n - 1].deleted = false
	await _nomination_prefill(scene)
	_done(scene)

## From the nomination menu, "File a case against X in the Workshop" starts the case as
## "X is evil" (Michael, Nov 19); doing it again doesn't add a second one.
func _nomination_prefill(scene) -> void:
	var g = scene.g
	var who = g.w.living()[1]
	if not g.on_deck_case(who.id).is_empty():
		check(false, "%s has no case on deck (the menu offers filing one)" % who.name)
		return
	scene._nomination_menu(scene.actions, who.id)
	var file_btn: Button = _find_button(scene.popup, "File a case against %s in the Workshop" % who.name)
	check(file_btn != null, "the nomination menu offers filing a case against %s" % who.name)
	if file_btn == null:
		return
	file_btn.pressed.emit()
	await process_frame
	var ed = scene.case_view.workshop.editor
	var node: Dictionary = ed.board.nodes.get(ed.board.selected, {})
	check(node.get("kind", "") == "premise" and not node.get("draft", false) and node.conclusion.get("type", "") == "evil" and node.conclusion.get("target", "") == who.id, "the Workshop opens on \"%s is evil\"" % who.name)
	var count: int = ed.board.nodes.values().filter(func(n): return n.kind == "premise" and n.get("conclusion", {}).get("target", "") == who.id and n.get("conclusion", {}).get("type", "") == "evil").size()
	ed.prefill_premise(who.id, "evil")
	var again: int = ed.board.nodes.values().filter(func(n): return n.kind == "premise" and n.get("conclusion", {}).get("target", "") == who.id and n.get("conclusion", {}).get("type", "") == "evil").size()
	check(count == 1 and again == 1, "opening it again selects that premise, not a second one (%d, %d)" % [count, again])
	# A premise about another alignment epoch (before a curse) isn't reused (Codex, #370).
	var mine: String = ed.board.selected
	ed.board.nodes[mine].conclusion.at = "Original alignment" if str(ed.board.view.alignment_epoch) != "Original alignment" else "Current alignment"
	var fresh: String = ed.prefill_premise(who.id, "evil")
	check(fresh != mine and str(ed.board.nodes[fresh].conclusion.get("at", "")) == str(ed.board.view.alignment_epoch), "a premise about another alignment epoch isn't reused")

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var b = _find_button(c, text)
		if b != null:
			return b
	return null

func _done(scene) -> void:
	print("Workshop navigation: %d checks, %d failures" % [checks, fails])
	scene.queue_free()
	quit(1 if fails else 0)
