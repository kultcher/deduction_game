## One way around the screens (Michael, Nov 28, item 5): the breadcrumb row.
##   By day: Town ▸ <block> ▸ <person>;  at a meeting: Town ▸ Meeting ▸ <speaker>.
## The crumb you're on is red; the others take you there.
##   godot --headless --path . --script res://tools/test_nav_crumbs.gd
extends SceneTree

const Crumbs = preload("res://ui/nav_crumbs.gd")

var checks = 0
var fails = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _initialize() -> void:
	call_deferred("_run")

func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame

func _shape(m) -> Array:
	return Crumbs.crumbs(m).map(func(c): return [c.label, c.current])

func _press(m, label: String) -> void:
	for c in Crumbs.crumbs(m):
		if c.label == label and c.go.is_valid():
			c.go.call()
			return

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	scene.pacing_enabled = false
	root.add_child(scene)
	await _frames()
	var g = scene.g
	if g.state == "approach":
		scene._run("decline")
	scene._refresh_all()
	await _frames()
	check(_shape(scene) == [["Town", true]] and not scene.nav_crumbs.visible, "the whole town before you've moved: nowhere to step back to, no row (%s)" % str(_shape(scene)))
	scene.map.zoom_to("docks")
	await _frames()
	check(_shape(scene) == [["Town", false], ["Docks", true]] and scene.nav_crumbs.visible, "a close-up: Town ▸ Docks (%s)" % str(_shape(scene)))
	check(not scene.map.show_back_sign, "the map's own '◀ Whole town' sign gives way to the Town crumb")
	_press(scene, "Town")
	await _frames()
	check(scene.map.zoom_block == "", "Town goes back to the whole town")
	var n = g.w.living().filter(func(x): return g.can_see(x) and str(x.busy_with) == "")[0]
	scene._run("go " + n.id)
	scene._run("talk " + n.id)
	await _frames()
	var blk: String = Crumbs._block_label(g.w.loc_block(g.loc))
	check(_shape(scene) == [["Town", false], [blk, false], [n.name, true]], "talking: Town ▸ %s ▸ %s (%s)" % [blk, n.name, str(_shape(scene))])
	_press(scene, blk)
	await _frames()
	check(scene.conversation_show_map and not scene.conversation_view.visible and scene.map.zoom_block == g.w.loc_block(g.loc), "the block crumb shows the block, the conversation waiting")
	check(_shape(scene) == [["Town", false], [blk, true], [n.name, false]], "and marks it (%s)" % str(_shape(scene)))
	_press(scene, n.name)
	await _frames()
	check(not scene.conversation_show_map and scene.conversation_view.visible, "the person's crumb brings the conversation back")
	_press(scene, "Town")
	await _frames()
	check(scene.conversation_show_map and scene.map.zoom_block == "", "Town shows the whole town from a conversation")
	_press(scene, n.name)
	await _frames()
	var buttons: Array = scene.nav_crumbs.get_children().filter(func(b): return b is Button)
	check(buttons.size() == 3 and buttons[2].button_pressed and not buttons[0].button_pressed, "the row's buttons: the current one pressed (red)")

	# An approach covers the map: no crumbs until it's answered (Codex on #591).
	g.state = "approach"
	scene.approach_stage = "intro"
	check(Crumbs.crumbs(scene).is_empty(), "an approach shows no crumbs")
	scene.approach_stage = ""
	# At night the map still zooms; Town is the way back out (Codex on #591).
	g.state = "night"
	scene.map.zoom_to("docks")
	check(_shape(scene) == [["Town", false], ["Docks", true]], "a night close-up: Town ▸ Docks (%s)" % str(_shape(scene)))
	_press(scene, "Town")
	check(scene.map.zoom_block == "", "and Town zooms back out at night")
	check(_shape(scene) == [["Town", true]], "the whole town at night: just Town, so no row")
	# At a meeting (state set directly; the circle's own flow is tested elsewhere).
	g.state = "meeting"
	scene.meeting_show_map = false
	check(_shape(scene) == [["Town", false], ["Meeting", true]], "a meeting: Town ▸ Meeting (%s)" % str(_shape(scene)))
	_press(scene, "Town")
	scene.meeting_show_map = true
	scene.map_stage.visible = true
	check(_shape(scene) == [["Town", true], ["Meeting", false]], "the map peek marks Town (%s)" % str(_shape(scene)))
	# Someone on the courtroom stage: their crumb, current; Meeting clears the stage.
	scene.meeting_show_map = false
	var stage = scene.meeting_view.stage
	if stage != null and "current" in stage:
		stage.current = {"speaker": n.id, "name": n.name, "text": "…"}
		stage.queue = [stage.current]
		if scene.meeting_view.presenting():
			check(_shape(scene) == [["Town", false], ["Meeting", false], [n.name, true]], "someone speaking: Town ▸ Meeting ▸ %s (%s)" % [n.name, str(_shape(scene))])
			check(not Crumbs.crumbs(scene)[0].go.is_valid() and Crumbs.crumbs(scene)[1].go.is_valid(), "while they speak, Town can't be taken (the map won't open) but Meeting can")
			scene.nav_crumbs.refresh(scene)
			var town_btn: Array = scene.nav_crumbs.get_children().filter(func(b): return b is Button and b.text == "Town")
			check(not town_btn.is_empty() and town_btn[0].disabled, "so its button is greyed out (Codex)")
		else:
			print("(the stage stub didn't count as presenting; speaker crumb not checked)")
	g.state = "talk"
	scene.queue_free()
	print("Nav crumbs: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
