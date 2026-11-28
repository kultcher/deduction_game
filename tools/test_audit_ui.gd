## The release audit's UI fixes (docs/maintenance/codebase_and_release_audit_2026-11-27.md;
## Michael OK'd fix-as-you-go, Nov 27): inline icons found the exported way, popups placed in
## viewport units, Esc stepping back one level, and a new case leaving nothing behind.
##   godot --headless --path . --script res://tools/test_audit_ui.gd
extends SceneTree

const ColumnMenus = preload("res://ui/column_menus.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	return e

func _run() -> void:
	# 1. Inline icons: found through the resource loader, as an exported build sees them.
	var terms = preload("res://ui/text_terms.gd").new()
	var src: String = FileAccess.get_file_as_string("res://ui/text_terms.gd")
	check(not "FileAccess.file_exists" in src, "text_terms no longer asks the file system for icons")
	var seer: Array = terms.find_matches("The Seer spoke.").filter(func(r): return str(r.get("id", "")) == "role:seer")
	check(not seer.is_empty() and str(seer[0].get("icon_path", "")) != "", "and a role with art still gets its inline icon")

	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	scene.pacing_enabled = false
	root.add_child(scene)
	await process_frame
	await process_frame

	# 2. Popups: viewport units when embedded, like main_pickers' anchor.
	var ctrl: Control = scene.cast_list
	var p: Vector2i = ColumnMenus.popup_point(ctrl, Vector2(5, 7))
	check(ctrl.get_window().gui_embed_subwindows and p == Vector2i(ctrl.get_global_transform_with_canvas() * Vector2(5, 7)), "a popup point is in the viewport's own units (%s)" % p)
	for f in ["ui/daily_guess.gd", "ui/board_view.gd", "ui/card_list.gd", "ui/deduction_tray.gd", "ui/profile_panel.gd", "ui/trait_bars.gd"]:
		var text: String = FileAccess.get_file_as_string("res://" + f)
		check(not "get_screen_transform()" in text and not "get_screen_position()" in text, "%s no longer places popups in screen pixels" % f)

	# 3. Esc: the Workshop's fullscreen shrinks first, then the board closes; the canvas keeps
	# an Esc that cancels something.
	scene._open_case_view()
	await process_frame
	var cv = scene.case_view
	if cv.workshop != null:
		cv.workshop.set_fullscreen(true)
		cv._unhandled_key_input(_esc())
		check(cv.visible and not cv.workshop.fullscreen, "Esc in a fullscreen Workshop leaves fullscreen, and the board stays")
	cv._unhandled_key_input(_esc())
	check(not cv.visible, "the next Esc closes the board")
	var canvas_src: String = FileAccess.get_file_as_string("res://ui/workshop_canvas_view.gd")
	check("accept_event()" in canvas_src and not "func _input(" in FileAccess.get_file_as_string("res://ui/case_view.gd"), "the board no longer takes Esc before the canvas can cancel with it")
	scene.input.release_focus()
	scene.pacing_open = true
	scene._input(_esc())
	check(not scene.input.has_focus(), "Esc doesn't pull focus to the command line under the night or hanging sequence")
	scene.pacing_open = false

	# 4. A new case starts clean, and nothing runs under the guess window.
	scene.daily_guess_open = true
	var before: int = scene.g.last_events.size()
	var g_before = scene.g
	scene._run("wait")
	check(scene.g == g_before and scene._presenting(), "with the guess window up, commands wait and the screen counts as presenting")
	var stray = Control.new()
	stray.name = "Pacing"
	scene.add_child(stray)
	scene.meeting_show_map = true
	scene.approach_stage = "something"
	scene._reveal_after_pacing = true
	scene._new_case()
	await process_frame
	check(not scene.daily_guess_open and not scene.meeting_show_map and scene.approach_stage == "" and not scene._reveal_after_pacing, "a new case resets the guess window, the meeting's map peek, the approach and the deferred reveal")
	check(scene.get_node_or_null("Pacing") == null, "and frees an overlay left over from the last case")
	# 5. The texture caches stay bounded through a zoom, and a fractional height reuses its
	# whole-pixel box.
	var UITheme = preload("res://ui/theme.gd")
	for i in range(400):
		var h: float = 20.0 + i * 0.37
		UITheme.nine("ui/plaque_cream", h, [h * 0.3, h * 0.25, h * 0.3, h * 0.25])
	check(UITheme._nine_cache.size() <= UITheme.NINE_CACHE_MAX and UITheme._cache.size() <= UITheme.TEX_CACHE_MAX, "a long zoom leaves both texture caches bounded (%d, %d)" % [UITheme._nine_cache.size(), UITheme._cache.size()])
	var a = UITheme.nine("ui/plaque_cream", 34.2, [10.26, 8.55, 10.26, 8.55])
	check(a != null and a == UITheme.nine("ui/plaque_cream", 33.8, [10.14, 8.6, 10.14, 8.6]), "heights (and margins) that round to the same pixels share one box")
	scene.queue_free()
	print("Audit UI: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
