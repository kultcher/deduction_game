## Michael's small UI items of Nov 28 (Seneschal relay).
##   1. With the Workshop sheet out, the case board pans far enough to show its latest
##      columns: the pan clamp, the fits and the day in view go by the uncovered part.
##   godot --headless --path . --script res://tools/test_nov28_ui.gd
extends SceneTree

const Game = preload("res://game/game.gd")
const CaseView = preload("res://ui/case_view.gd")
const UITheme = preload("res://ui/theme.gd")

var _checks: int = 0
var _fails: int = 0
var _tag: String = ""

func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + ("%s: " % _tag if _tag != "" else "") + label)
	if not ok:
		_fails += 1

func _pan_checks(g, screen: Vector2) -> void:
	_tag = "%dx%d" % [int(screen.x), int(screen.y)]
	var cv = CaseView.new()
	cv.workshop_execute = func(_cmd, _prog): pass
	root.add_child(cv)
	cv.build(UITheme.serif())
	await process_frame
	cv.set_game(g)
	cv.size = screen
	for i in range(3):
		await process_frame
	var board = cv.board
	var drawer = cv.workshop
	drawer.set_fraction(0.6)
	await process_frame
	_check(absf(board.right_cover - drawer.covered_width()) < 1.0 and board.right_cover > 0.0, "the board knows how much the sheet covers (%d px)" % int(board.right_cover))
	board.pan.x = 1.0e9
	board._clamp_pan()
	var cols: Array = board.lay.get("cols", [])
	var last: Dictionary = cols[cols.size() - 1]
	var right_x: float = board.col_x[last["key"]] + board.COL_W
	var vis: Rect2 = board._visible_rect()
	# What the old clamp allowed: as if the whole board were visible.
	var cover: float = board.right_cover
	board.right_cover = 0.0
	board.pan.x = 1.0e9
	board._clamp_pan()
	var old_edge: float = board.to_screen(Vector2(right_x, 0)).x
	board.right_cover = cover
	board.pan.x = 1.0e9
	board._clamp_pan()
	_check(old_edge > vis.end.x, "(the old clamp left that column partly under the sheet: %d > %d)" % [int(old_edge), int(vis.end.x)])
	var left_edge: float = board.to_screen(Vector2(right_x, 0)).x
	_check(left_edge <= vis.end.x, "panned fully right, the latest column (day %d) clears the sheet (%d < %d)" % [int(last["day"]), int(left_edge), int(vis.end.x)])
	board.fit_day(g.w.day)
	var keys: Array = cols.filter(func(c): return c["day"] == g.w.day).map(func(c): return c["key"])
	var right_of_day: float = board.to_screen(Vector2(board.col_x[keys[keys.size() - 1]] + board.COL_W, 0)).x
	_check(right_of_day <= vis.end.x + 1.0, "fitting today keeps its evening clear of the sheet (%d <= %d)" % [int(right_of_day), int(vis.end.x)])
	_check(board.day_in_view() == g.w.day, "and the day plaque reads the day the player can see")
	drawer.collapse()
	await process_frame
	_check(board.right_cover < screen.x * 0.1 and is_equal_approx(board.right_cover, drawer.covered_width()), "a collapsed sheet hands the board back its width (%d px left covered)" % int(board.right_cover))
	drawer.set_fullscreen(true)
	await process_frame
	_check(board.right_cover == 0.0, "a fullscreen Workshop doesn't shrink the hidden board")
	drawer.set_fullscreen(false)
	cv.queue_free()
	_tag = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var g = Game.new()
	g.detailed_logging = false
	g.new_case(54875, 10)
	var guard: int = 0
	while g.state != "over" and g.w.day < 3 and guard < 300:
		guard += 1
		match g.state:
			"approach": g.command("decline")
			"day": g.command("wait")
			"meeting": g.command("done" if g.town_quiet else "wait")
			"talk": g.command("bye")
			"nomination": g.command("vote no")
			"night": g.command("sleep")
			_: break
	_check(g.w.day >= 2, "the game reaches a later day (day %d, %s)" % [g.w.day, g.state])
	await _pan_checks(g, Vector2(1280, 800))
	await _pan_checks(g, Vector2(1920, 1080))
	print("Nov 28 UI: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails else 0)
