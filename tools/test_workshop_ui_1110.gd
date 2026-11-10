## Nov 10 Workshop UI: box selection (move together, remove in one undo), Unlink all, the
## fullscreen toggle; and conversations as a bridging node on the board.
##   godot --headless --path . --script res://tools/test_workshop_ui_1110.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const CaseView = preload("res://ui/case_view.gd")
const UITheme = preload("res://ui/theme.gd")
const CardModel = preload("res://game/card_model.gd")

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var convo = {"kind": "conversation", "subject": ["a", "b"], "block": "square", "loc": "tavern", "day": 1, "phase": C.MORNING, "source": "player", "text": "c"}
	var cm: Array = CardModel.place_markers(convo)
	_check(cm.size() == 2 and cm.all(func(m): return m.mark == "convo"), "a conversation's markers are bridging nodes, not full dots")

	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 7)
	g.command("go smithy")
	var cv = CaseView.new()
	cv.workshop_execute = func(_cmd, _prog): pass
	root.add_child(cv)
	cv.build(UITheme.serif())
	await process_frame
	cv.set_game(g)
	cv.size = Vector2(1600, 900)
	for i in range(3):
		await process_frame
	var drawer = cv.workshop
	drawer.open(0.6)
	await process_frame
	var editor = drawer.editor
	var nums: Array = g.board.filter(func(c): return c.kind in ["sighting", "location"] or c.get("source", "") == "player").map(func(c): return c.n).slice(0, 3)
	for num in nums:
		editor.add_evidence(num)
	var ev_ids: Array = editor.board.nodes.keys().filter(func(k): return editor.board.nodes[k].kind == "evidence")
	_check(ev_ids.size() >= 2, "cards on the canvas (%d)" % ev_ids.size())
	if ev_ids.size() >= 2:
		var canvas = editor.canvas
		canvas.group = ev_ids.slice(0, 2)
		var before: Array = canvas.group.map(func(k): return editor.board.nodes[k].at.duplicate())
		canvas.drag = canvas.group[0]
		canvas.last_mouse = Vector2(100, 100)
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(160, 130)
		canvas._gui_input(mv)
		canvas.drag = ""
		var moved: bool = true
		for i in range(2):
			var now = editor.board.nodes[canvas.group[i]].at
			moved = moved and absf(now[0] - before[i][0]) > 1.0
		_check(moved, "dragging one card of a box selection moves the whole group")
		# Unlink all: link the first card to two others, then unlink all from it.
		var prem: Array = editor.board.nodes.keys().filter(func(k): return editor.board.nodes[k].kind == "premise")
		editor.board.connect_cards(ev_ids[0], prem[0])
		if ev_ids.size() >= 3:
			editor.board.connect_cards(ev_ids[2], ev_ids[0])
		editor.context_id = ev_ids[0]
		editor._context_action(4)
		_check(not editor.board.links.any(func(e): return e.from == ev_ids[0] or e.to == ev_ids[0]), "Unlink all leaves the card with no links")
		# Remove the group in one step, then undo.
		var gids: Array = ev_ids.slice(0, 2)
		editor.remove_nodes(gids)
		_check(gids.all(func(k): return not editor.board.nodes.has(k)), "Delete removes the whole box selection")
		editor._undo_remove()
		_check(gids.all(func(k): return editor.board.nodes.has(k)), "and one undo brings them all back")
	# Fullscreen.
	drawer.set_fullscreen(true)
	await process_frame
	_check(drawer.fullscreen and drawer.top_level and drawer.size.y >= root.get_visible_rect().size.y - 1.0, "fullscreen takes the window's full height")
	_check(editor.fullscreen_btn.text == "Exit fullscreen", "the toggle says how to get back")
	drawer.set_fullscreen(false)
	await process_frame
	_check(not drawer.fullscreen and not drawer.top_level, "and back to the board")
	cv.queue_free()
	await process_frame
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
