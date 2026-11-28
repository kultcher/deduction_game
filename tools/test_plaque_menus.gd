## Menus as plaque buttons (Michael, Nov 28, item 4): "More ▾" and the case board's filters
## open as a themed panel of buttons like the dialogue options, not bare text on a grey box.
##   godot --headless --path . --script res://tools/test_plaque_menus.gd
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

func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame

func _buttons(menu: PopupMenu) -> Array:
	var panel = menu.get_meta("column_popup") if menu.has_meta("column_popup") else null
	if not is_instance_valid(panel):
		return []
	return panel.find_children("*", "Button", true, false)

func _run() -> void:
	var scene = load("res://ui/main.tscn").instantiate()
	scene.show_script_at_start = false
	scene.pacing_enabled = false
	root.add_child(scene)
	await _frames()
	var more: MenuButton = scene.find_children("*", "MenuButton", true, false).filter(func(b): return b.text.begins_with("More"))[0]
	var mp: PopupMenu = more.get_popup()
	more.show_popup()
	await _frames()
	var panel = mp.get_meta("column_popup") if mp.has_meta("column_popup") else null
	check(ColumnMenus.is_open(mp) and not mp.visible, "More opens as a panel of buttons, not the bare menu")
	check(is_instance_valid(panel) and panel.theme == scene.theme, "and the panel wears the screen's theme (plaques, not the engine's grey)")
	var entries: int = 0
	for i in range(mp.item_count):
		if not mp.is_item_separator(i):
			entries += 1
	check(_buttons(mp).size() == entries, "one button per entry (%d of %d)" % [_buttons(mp).size(), entries])
	var reduced: Array = _buttons(mp).filter(func(b): return "Reduced motion" in b.text)
	check(not reduced.is_empty() and reduced[0].toggle_mode and reduced[0].button_pressed == scene.reduced_motion, "a tick entry shows its state as a pressed plaque")
	if is_instance_valid(panel):
		panel.hide()
	await _frames()

	scene._open_case_view()
	await _frames()
	var cv = scene.case_view
	var pm: PopupMenu = cv.person_menu.get_popup()
	cv.person_menu.show_popup()
	await _frames()
	var people: Array = _buttons(pm)
	check(ColumnMenus.is_open(pm) and people.size() == pm.item_count, "the board's People filter opens as buttons too (%d)" % people.size())
	if not people.is_empty():
		people[0].pressed.emit()
		await _frames(2)
		check(pm.is_item_checked(0) and people[0].button_pressed and people[0].text.begins_with("☑"), "pressing one ticks it, and it turns red")
		check(people.size() < 2 or people[1].text.begins_with("☐"), "an unticked one shows an empty box, so it reads as a setting")
	scene.queue_free()
	print("Plaque menus: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
