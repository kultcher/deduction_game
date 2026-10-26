## Presentation-only column layout; native menu indices, IDs and callbacks survive.
extends RefCounted
const C = preload("res://sim/content.gd")
const LIMIT = 8

static func watch(node: Node) -> void:
	var tree = node.get_tree()
	if tree.has_meta("column_menus_installed"):
		return
	tree.set_meta("column_menus_installed", true)
	tree.node_added.connect(func(added):
		if added is PopupMenu: bind(added))
	for menu in tree.root.find_children("*", "PopupMenu", true, false):
		bind(menu)

static func bind(menu: PopupMenu) -> void:
	if menu.has_meta("column_menu_bound"):
		return
	menu.set_meta("column_menu_bound", true)
	menu.about_to_popup.connect(func():
		var count = 0
		for i in range(menu.item_count):
			if not menu.is_item_separator(i): count += 1
		if count > LIMIT:
			show_columns.call_deferred(menu))

static func groups(menu: PopupMenu) -> Array:
	var titles: Array = []
	var indices = {}
	var section = ""
	for i in range(menu.item_count):
		if menu.is_item_separator(i):
			section = menu.get_item_text(i)
			continue
		var category: String = section
		if category == "":
			var role = menu.get_item_metadata(i)
			if not role is String or role not in C.ROLES:
				for key in C.ROLES:
					if menu.get_item_text(i) == C.role_name(key):
						role = key
						break
			if role is String and role in C.ROLES:
				category = "Gifts of the town" if C.ROLES[role].align == "good" else "The demon's side"
		if not indices.has(category):
			titles.append(category)
			indices[category] = []
		indices[category].append(i)
	var result: Array = []
	for title in titles:
		var items: Array = indices[title]
		var columns = ceili(items.size() / float(LIMIT))
		var offset = 0
		for col in range(columns):
			var count = ceili((items.size() - offset) / float(columns - col))
			result.append({"title": title, "indices": items.slice(offset, offset + count)})
			offset += count
	return result

static func show_columns(menu: PopupMenu) -> void:
	if not is_instance_valid(menu) or not menu.is_inside_tree(): return
	var at = menu.position
	var focused = menu.get_focused_item()
	menu.hide()
	var old = menu.get_meta("column_popup") if menu.has_meta("column_popup") else null
	if is_instance_valid(old): old.queue_free()
	var owner = menu.get_parent().get_window()
	var popup = PopupPanel.new()
	popup.name = "ColumnMenu"
	owner.add_child(popup)
	menu.set_meta("column_popup", popup)
	popup.popup_hide.connect(popup.queue_free, CONNECT_ONE_SHOT)
	var weak_popup = weakref(popup)
	menu.tree_exiting.connect(func():
		var window = weak_popup.get_ref()
		if window != null: window.queue_free(), CONNECT_ONE_SHOT)
	var scroll = ScrollContainer.new()
	scroll.follow_focus = true
	popup.add_child(scroll)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)
	var columns: Array = []
	var all: Array = []
	for group in groups(menu):
		var column = VBoxContainer.new()
		column.name = "Options"
		row.add_child(column)
		if group.title != "":
			var label = Label.new()
			label.text = group.title
			column.add_child(label)
		var buttons: Array = []
		for index in group.indices:
			var button = Button.new()
			button.text = menu.get_item_text(index)
			button.icon = menu.get_item_icon(index)
			button.clip_text = true
			button.custom_minimum_size.x = 200
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.tooltip_text = menu.get_item_tooltip(index) + "\n" + menu.get_item_text(index)
			button.disabled = menu.is_item_disabled(index)
			button.set_meta("menu_index", index)
			if menu.is_item_checkable(index) or menu.is_item_radio_checkable(index):
				button.text = ("✓ " if menu.is_item_checked(index) else "  ") + button.text
			button.pressed.connect(func(): activate(menu, index, popup, button))
			column.add_child(button)
			if not button.disabled:
				buttons.append(button)
				all.append(button)
		columns.append(buttons)
	# Explicit neighbours keep arrows and tab useful across separate VBoxes.
	for ci in range(columns.size()):
		var column: Array = columns[ci]
		for ri in range(column.size()):
			var button: Button = column[ri]
			button.focus_neighbor_top = button.get_path_to(column[posmod(ri - 1, column.size())])
			button.focus_neighbor_bottom = button.get_path_to(column[(ri + 1) % column.size()])
			for pair in [[SIDE_LEFT, -1], [SIDE_RIGHT, 1]]:
				for step in range(1, columns.size() + 1):
					var other: Array = columns[posmod(ci + pair[1] * step, columns.size())]
					if not other.is_empty():
						button.set_focus_neighbor(pair[0], button.get_path_to(other[mini(ri, other.size() - 1)]))
						break
	for i in range(all.size()):
		all[i].focus_next = all[i].get_path_to(all[(i + 1) % all.size()])
		all[i].focus_previous = all[i].get_path_to(all[posmod(i - 1, all.size())])
	popup.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			popup.hide())
	var bounds = Rect2i(Vector2i.ZERO if owner.gui_embed_subwindows else owner.position, owner.size)
	var wanted = row.get_combined_minimum_size() + Vector2(20, 20)
	var extent = Vector2i(mini(int(wanted.x), maxi(40, bounds.size.x - 24)), mini(int(wanted.y), maxi(40, bounds.size.y - 24)))
	scroll.custom_minimum_size = Vector2(extent - Vector2i(12, 12))
	at.x = clampi(at.x, bounds.position.x, maxi(bounds.position.x, bounds.end.x - extent.x))
	at.y = clampi(at.y, bounds.position.y, maxi(bounds.position.y, bounds.end.y - extent.y))
	popup.popup(Rect2i(at, extent))
	for button in all:
		if button.get_meta("menu_index") == focused:
			button.grab_focus()
			return
	if not all.is_empty(): all[0].grab_focus()

static func activate(menu: PopupMenu, index: int, popup: PopupPanel, button: Button) -> void:
	if menu.is_item_disabled(index): return
	var submenu = menu.get_item_submenu(index)
	if submenu != "":
		var child = menu.get_node_or_null(NodePath(submenu))
		if child is PopupMenu:
			child.position = popup.position + Vector2i(button.position + Vector2(button.size.x, 0))
			child.popup()
		return
	var keep = not menu.hide_on_checkable_item_selection and (menu.is_item_checkable(index) or menu.is_item_radio_checkable(index))
	menu.id_pressed.emit(menu.get_item_id(index))
	menu.index_pressed.emit(index)
	if keep:
		button.text = ("✓ " if menu.is_item_checked(index) else "  ") + menu.get_item_text(index)
	else:
		popup.hide()

## The game's handcrafted Button pickers use the same balanced eight-item rule.
static func balance(content: Control) -> Control:
	for child in content.get_children():
		if child is Control:
			var balanced = balance(child)
			if balanced != child:
				var at = child.get_index()
				content.remove_child(child)
				content.add_child(balanced)
				content.move_child(balanced, at)
				child.queue_free()
	if not content is VBoxContainer: return content
	var buttons: Array = content.get_children().filter(func(n): return n is Button)
	var others: Array = content.get_children().filter(func(n): return not n is Button)
	if buttons.size() <= LIMIT or others.size() > 1 or (others.size() == 1 and not others[0] is Label): return content
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var count = ceili(buttons.size() / float(LIMIT))
	var offset = 0
	for col in range(count):
		var box = VBoxContainer.new()
		row.add_child(box)
		if not others.is_empty(): box.add_child(others[0].duplicate())
		var size = ceili((buttons.size() - offset) / float(count - col))
		for button in buttons.slice(offset, offset + size):
			content.remove_child(button)
			box.add_child(button)
		offset += size
	return row

static func fit_picker(popup: PopupPanel, content: Control, at: Vector2i) -> void:
	var owner = popup.get_parent().get_window()
	var bounds = Rect2i(Vector2i.ZERO if owner.gui_embed_subwindows else owner.position, owner.size)
	var scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.add_child(content)
	var wanted = content.get_combined_minimum_size() + Vector2(20, 20)
	var extent = Vector2i(mini(int(wanted.x), maxi(40, bounds.size.x - 24)), mini(int(wanted.y), maxi(40, bounds.size.y - 24)))
	scroll.custom_minimum_size = Vector2(extent - Vector2i(12, 12))
	popup.add_child(scroll)
	at.x = clampi(at.x, bounds.position.x, maxi(bounds.position.x, bounds.end.x - extent.x))
	at.y = clampi(at.y, bounds.position.y, maxi(bounds.position.y, bounds.end.y - extent.y))
	popup.popup(Rect2i(at, extent))
