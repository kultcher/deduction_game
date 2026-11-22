## Small UI fixes from Michael's playtest (Nov 22): Exit Game in the More menu; the Workshop's
## "Add readings from/about" lists open in the workshop's viewport, sized to the whole cast;
## the roster tints a card by your guess (blue good, red evil) with no "good" stamp; and
## "Present a case about them" at a nomination opens the Workshop when no case is filed.
##   godot --headless --path . --script res://tools/test_playtest_ui_nov22.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const Game = preload("res://game/game.gd")
const GameMeeting = preload("res://game/game_meeting.gd")
const MainActions = preload("res://ui/main_actions.gd")
const CastList = preload("res://ui/cast_list.gd")

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
	await process_frame

	# 1. Exit Game, last in the More menu.
	var more: MenuButton = scene.find_children("*", "MenuButton", true, false).filter(func(b): return b.text == "More ▾")[0]
	var mp: PopupMenu = more.get_popup()
	check(mp.get_item_text(mp.item_count - 1) == scene.EXIT_GAME and mp.get_item_id(mp.item_count - 1) == scene.MoreItem.EXIT, "the More menu ends with Exit Game")

	# 2. The readings lists open in the workshop's viewport, sized for everyone.
	scene.case_view.open_workshop()
	for _i in range(4):
		await process_frame
	var ed = scene.case_view.workshop.editor
	ed._background_menu(Vector2.ZERO)
	await process_frame
	check(ed.bg_about.get_parent() != ed.bg_menu and ed.bg_from.get_parent() != ed.bg_menu, "the name lists aren't embedded in the small menu (they were clipped to it)")
	ed.bg_menu.hide()
	ed._open_bg_list(ed.bg_about)
	await process_frame
	var need: Vector2 = ed.bg_about.get_contents_minimum_size()
	check(ed.bg_about.item_count == scene.g.w.npcs.size() and ed.bg_about.size.y >= mini(int(need.y), ed.bg_about.max_size.y), "the list is tall enough for the whole cast, or scrolls (%s vs %s)" % [ed.bg_about.size, need])
	ed.bg_about.hide()

	# 3. The roster's guess tint.
	check(CastList.guess_lean("good") == "good" and CastList.guess_lean("evil") == "evil" and CastList.guess_lean("?") == "", "a good or evil guess leans its way; no guess, no tint")
	var gift: String = C.GOOD_ROLES[0]
	check(CastList.guess_lean(gift) == "good" and CastList.guess_lean("demon") == "evil", "a gift guess counts as good, a Demon guess as evil")

	# 4. Present a case about them, with none filed: the button is live and opens the Workshop.
	var g = scene.g
	if g.state == "approach":
		g.command("decline")
	g.w.day = 2
	g.w.phase = C.EVENING
	g.stream_meeting = false
	GameMeeting._start_meeting(g)
	var t = g.w.living_good()[0]
	g.command("nominate %s raw" % t.name.to_lower())
	if g.state == "nomination":
		g.w.meeting["pending"]["supporters_done"] = true
		MainActions.refresh(scene)
		await process_frame
		var put: Button = null
		for b in scene.actions.find_children("*", "Button", true, false):
			if b.text == "Present a case about them…":
				put = b
		check(put != null and not put.disabled, "with no case filed, Present a case about them is live (it was greyed out)")
		if put != null:
			scene.case_view.visible = false
			put.pressed.emit()
			await process_frame
			check(scene.case_view.visible, "and it opens the Workshop to build one")
	else:
		check(false, "the nomination opens (state %s)" % g.state)

	print("Playtest UI (Nov 22): %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
