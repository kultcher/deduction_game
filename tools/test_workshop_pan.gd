## Workshop canvas (Michael, Nov 17): left-click and drag on empty space pans the view;
## shift+left-click and drag draws a selection box; a plain click on empty space clears the
## selection.
##   godot --headless --path . --script res://tools/test_workshop_pan.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const CaseView = preload("res://ui/case_view.gd")
const UITheme = preload("res://ui/theme.gd")

var _checks: int = 0
var _fails: int = 0

func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _button(canvas, at: Vector2, pressed: bool, shift: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.shift_pressed = shift
	canvas._gui_input(e)

func _motion(canvas, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	canvas._gui_input(e)

## A point on the canvas no card covers.
func _empty_point(canvas) -> Vector2:
	for x in range(20, 1500, 40):
		for y in range(20, 850, 40):
			var p := Vector2(x, y)
			if not canvas.hit.values().any(func(r): return r.has_point(p)):
				return p
	return Vector2(-1, -1)

func _run() -> void:
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
	for i in range(3):
		await process_frame
	var canvas = editor.canvas
	canvas.queue_redraw()
	await process_frame
	var ev_ids: Array = editor.board.nodes.keys().filter(func(k): return editor.board.nodes[k].kind == "evidence")
	_check(ev_ids.size() >= 2 and canvas.hit.size() >= 2, "cards on the canvas (%d, %d drawn)" % [ev_ids.size(), canvas.hit.size()])
	var p: Vector2 = _empty_point(canvas)
	_check(p.x >= 0, "an empty point on the canvas (%s)" % str(p))
	# Left-drag on empty space pans.
	canvas.group = ev_ids.slice(0, 2)
	var pan0: Vector2 = canvas.pan
	_button(canvas, p, true, false)
	_check(canvas.panning and canvas.box_from == null, "left-press on empty space starts a pan, not a box")
	_check(canvas.group.is_empty(), "...and clears the selection")
	_motion(canvas, p + Vector2(40, 25))
	_check(canvas.pan.distance_to(pan0 + Vector2(40, 25)) < 0.5, "left-drag on empty space moves the view (%s -> %s)" % [str(pan0), str(canvas.pan)])
	_button(canvas, p + Vector2(40, 25), false, false)
	_check(not canvas.panning, "releasing ends the pan")
	# Shift+left-drag draws a selection box around every card.
	await process_frame
	canvas.queue_redraw()
	await process_frame
	var all_rect := Rect2()
	var first := true
	for r in canvas.hit.values():
		all_rect = r if first else all_rect.merge(r)
		first = false
	var from: Vector2 = all_rect.position - Vector2(5, 5)
	var to: Vector2 = all_rect.end + Vector2(5, 5)
	_button(canvas, from, true, true)
	_check(canvas.box_from != null and not canvas.panning, "shift+left-press on empty space starts a selection box")
	var pan1: Vector2 = canvas.pan
	_motion(canvas, to)
	_check(canvas.pan == pan1, "...which doesn't move the view")
	_button(canvas, to, false, true)
	_check(canvas.group.size() >= 2 and canvas.box_from == null, "releasing selects the cards inside the box (%d)" % canvas.group.size())
	print("Workshop pan: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails else 0)
