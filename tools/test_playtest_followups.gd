## Playtests 78148/77388 and PR #25 follow-ups.
extends SceneTree
const Game = preload("res://game/game.gd")
const Mind = preload("res://sim/mind.gd")
const C = preload("res://sim/content.gd")
const Columns = preload("res://ui/column_menus.gd")
const UITheme = preload("res://ui/theme.gd")
var checks = 0
var fails = 0
func _init():
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", message)
func fresh():
	var g = Game.new()
	g.detailed_logging = false
	g.log_dir = "user://followup_tests"
	g.new_case(4242, 10)
	return g
func settle():
	for i in range(5): await process_frame
func run():
	await menus()
	print("Playtest follow-ups: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
func picker(title: String, count: int):
	var box = VBoxContainer.new()
	var label = Label.new()
	label.text = title
	box.add_child(label)
	for i in range(count):
		var button = Button.new()
		button.text = "Long option %d with a complete name" % i
		box.add_child(button)
	return box
func labels(node: Node) -> Array:
	var out: Array = []
	if node is Label: out.append(node.text)
	for child in node.get_children(): out.append_array(labels(child))
	return out
func menus():
	var host = Control.new()
	host.theme = UITheme.make(UITheme.serif())
	root.add_child(host)
	var popup = PopupPanel.new()
	host.add_child(popup)
	for extent in [Vector2i(1280, 720), Vector2i(640, 480)]:
		root.size = extent
		root.content_scale_size = extent
		await settle()
		for child in popup.get_children():
			popup.remove_child(child)
			child.queue_free()
		var original = picker("Heard of a…", 19)
		var balanced = Columns.balance(original)
		original.free()
		Columns.fit_picker(popup, balanced, extent - Vector2i(25, 30))
		await settle()
		check(labels(balanced) == ["Heard of a…"], "one heading spans all columns")
		check(Rect2i(Vector2i.ZERO, extent).encloses(Rect2i(popup.position, popup.size)), "popup remains inside owner after opening and shrinking")
		var scroll: ScrollContainer = popup.get_child(0)
		var buttons = balanced.find_children("*", "Button", true, false)
		check(buttons.size() == 19, "every long option survives layout")
		var last: Button = buttons.back()
		last.grab_focus()
		await settle()
		check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "keyboard focus scrolls the last option fully into view")
		popup.hide()
	root.gui_embed_subwindows = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1600, 1200)
	root.content_scale_size = Vector2i(800, 600)
	await settle()
	for child in popup.get_children():
		popup.remove_child(child)
		child.queue_free()
	var scaled_original = picker("Scaled viewport", 19)
	var scaled = Columns.balance(scaled_original)
	scaled_original.free()
	Columns.fit_picker(popup, scaled, Vector2i(770, 570))
	await settle()
	var logical = Rect2i(Vector2i.ZERO, Vector2i(root.get_visible_rect().size))
	check(logical.encloses(Rect2i(popup.position, popup.size)), "embedded picker bounds use the logical viewport when the physical window is larger")
	popup.hide()
	root.size = Vector2i(640, 480)
	root.content_scale_size = root.size
	await settle()
	var menu = PopupMenu.new()
	host.add_child(menu)
	menu.add_separator("One category")
	for i in range(19): menu.add_item("Option %d" % i)
	Columns.show_columns(menu)
	await settle()
	var native: PopupPanel = menu.get_meta("column_popup")
	check(labels(native).count("One category") == 1, "native menu section title is also displayed once")
	native.hide()
	await settle()
	host.free()
