## Trait disclosure/geometry and town-list ownership of map highlighting.
## godot --headless --path . --script res://tools/test_town_ui.gd
extends SceneTree

const C = preload("res://sim/content.gd")
const TraitBars = preload("res://ui/trait_bars.gd")
var fails = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	scene.show_script_at_start = false
	scene.seed_box.value = 4242
	scene._new_case()
	scene.roles_win.hide()
	await _settle()
	var g = scene.g
	var n = g.w.npcs[0]
	var other = g.w.npcs[1]
	n.revealed_traits.clear()
	_check(g.profile_data(n.id)["traits"].is_empty(), "undiscovered trait scores stay out of the profile")
	n.traits["privacy"] = 0.83
	n.revealed_traits["privacy"] = "high"
	var known: Dictionary = g.profile_data(n.id)["traits"]
	_check(known.size() == 1 and is_equal_approx(known["privacy"], 0.83), "a learned trait exposes its exact score without exposing the others")
	scene._select_person(n.id)
	_check(scene.profile.bars.revealed == known and scene.case_view.profile.bars.revealed == known, "both profile panels receive continuous learned scores")
	var track = Rect2(10, 4, 200, 12)
	_check(TraitBars.fill_rect(track, 0) == Rect2(10, 4, 100, 12), "zero fills from the left endpoint to the midpoint")
	_check(TraitBars.fill_rect(track, 1) == Rect2(110, 4, 100, 12), "one fills from the midpoint to the right endpoint")
	_check(TraitBars.fill_rect(track, 0.5) == Rect2(109, 4, 2, 12), "one-half leaves a thin centered marker")
	_check(TraitBars.fill_rect(track, 0.25) == Rect2(60, 4, 50, 12) and TraitBars.fill_rect(track, 0.75) == Rect2(110, 4, 50, 12), "quarter scores fill halfway along the appropriate half")
	_check(TraitBars.fill_rect(track, 0.61) != TraitBars.fill_rect(track, 0.75) and TraitBars.fill_rect(track, 0.83) != TraitBars.fill_rect(track, 1), "different scores inside the former bands have different lengths")
	_check(TraitBars.ROWS[0][2] == "Open Book" and TraitBars.ROWS[0][3] == "Secretive", "privacy labels follow the actual zero-to-one score direction")
	var cl = scene.cast_list
	g.state = "day"
	g.moved = false
	n.loc = "home_" + n.id
	n.working = false
	n.busy_with = ""
	_check(cl._sub_line(n) == "at Unknown", "an unseen living townsperson shows at Unknown")
	n.loc = n.work
	n.working = true
	_check(cl._sub_line(n).begins_with("at ") and not "Unknown" in cl._sub_line(n), "a visible townsperson shows their location")
	_check(cl._fit_text("Bartholomew at the Drowned Lamb tavern", 80, 17).ends_with("…") and cl._font.get_string_size(cl._fit_text("Bartholomew at the Drowned Lamb tavern", 80, 17), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= 80, "long row text is elided inside its available width")
	n.loc = "home_" + n.id
	n.working = false
	other.loc = other.work
	other.working = true
	other.busy_with = ""
	g.known_haunts[n.id] = ["well"]
	scene._refresh_all()
	await _settle()
	await _click_person(cl, n.id)
	_check(scene.map.selected_npc == n.id and cl.selected == n.id, "a townsfolk-row mouse click selects that map highlight")
	_check(scene.profile.current() == n.id, "the row click also shows that person's profile")
	_check(not scene.map._hits.any(func(h): return h["kind"] == "npc" and h["id"] == n.id), "selecting someone unseen does not reveal a map icon")
	_check(g.known_haunts[n.id] == ["well"], "selection does not discover additional haunts")
	var visible: Array = scene.map._hits.filter(func(h): return h["kind"] == "npc" and h["id"] == other.id)
	_check(not visible.is_empty(), "another visible map icon is available")
	if not visible.is_empty():
		var motion = InputEventMouseMotion.new()
		motion.position = visible[0]["rect"].get_center()
		scene.map._gui_input(motion)
		_check(scene.map.selected_npc == n.id and cl.selected == n.id, "hovering another map icon does not change the highlight")
		g.state = "talk"
		var click = InputEventMouseButton.new()
		click.position = motion.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		scene.map._gui_input(click)
		_check(scene.map.selected_npc == n.id and cl.selected == n.id and scene.profile.current() == other.id, "map clicks may show a profile without taking over highlighting")
	for i in range(scene.profile.person_opt.item_count):
		if scene.profile.person_opt.get_item_metadata(i) == other.id:
			scene.profile.person_opt.select(i)
			scene.profile.person_opt.item_selected.emit(i)
	_check(scene.map.selected_npc == n.id and cl.selected == n.id, "profile selection does not change the panel's highlight")
	await _click_person(cl, n.id)
	_check(scene.map.selected_npc == "" and cl.selected == "", "clicking the same townsfolk row again clears highlighting")
	await _click_person(cl, n.id)
	await _click_person(cl, other.id)
	_check(scene.map.selected_npc == other.id and cl.selected == other.id, "clicking a different townsfolk row switches highlighting")
	g.state = "night"
	scene._on_map_clicked("npc", n.id)
	_check(scene._ward_target == n.id and scene.map.selected_npc == other.id, "night ward targeting stays separate from map highlighting")
	_check(cl._sub_line(n) == "at Unknown", "the night list does not substitute an occupation for an unknown location")
	scene._new_case()
	scene.roles_win.hide()
	await _settle()
	_check(scene.map.selected_npc == "" and cl.selected == "", "a new case clears town highlighting")
	root.remove_child(scene)
	scene.free()
	print("FAILURES: %d" % fails)
	quit(1 if fails > 0 else 0)

func _settle() -> void:
	for i in range(4):
		await process_frame

func _click_person(list, id: String) -> void:
	var rows: Array = list._rows.filter(func(r): return r["id"] == id)
	if rows.is_empty():
		_check(false, "the requested townsfolk row exists")
		return
	var at: Vector2 = list.global_position + rows[0]["rect"].get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	var click = InputEventMouseButton.new()
	click.position = at
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	click.pressed = false
	root.push_input(click, true)
	await _settle()

func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1
