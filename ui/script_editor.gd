## Script editor: a working set. It starts from a script (Default, or the one already
## chosen) and the player adds and removes roles. Removing a role drops it off the script,
## so it can't be in play and claiming it is a giveaway. Coverage is only advised: the
## warnings say what the script is short of, and the player may use it anyway (errors,
## like too few town roles to deal a 10-person town, do block).
extends PanelContainer

signal finished(script_def)   # the edited script; null when cancelled

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")

const SIDES = [["town", "Town gifts", ScriptDef.TOWN_SIZE], ["minions", "Minions", ScriptDef.MINION_SIZE],
	["demons", "Demons", ScriptDef.MAX_DEMONS], ["secrets", "Secrets", ScriptDef.SECRET_SIZE]]

var working = ScriptDef.default_script()
var tag_filter: String = ""
var name_edit: LineEdit
var on_box: VBoxContainer
var off_box: VBoxContainer
var notes: Label
var use_btn: Button
var save_dialog: FileDialog
var load_dialog: FileDialog


func _init() -> void:
	add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("paper"), UITheme.color("border"), 2, 8, 16))
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	head.add_child(_label("Script", 24, UITheme.color("red")))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Script name"
	name_edit.custom_minimum_size.x = 260
	name_edit.text_changed.connect(func(t): working.name = t)
	head.add_child(name_edit)
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_label("Show:", 14, UITheme.color("ink")))
	var filter = OptionButton.new()
	filter.add_item("All roles")
	filter.set_item_metadata(0, "")
	for tag in ScriptDef.TAG_NAMES:
		filter.add_item(ScriptDef.TAG_NAMES[tag])
		filter.set_item_metadata(filter.item_count - 1, tag)
	filter.item_selected.connect(func(i):
		tag_filter = str(filter.get_item_metadata(i))
		_rebuild())
	head.add_child(filter)

	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	on_box = _column(cols, "On the script")
	off_box = _column(cols, "Available to add")

	notes = _label("", 14, UITheme.color("ink"))
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(notes)

	var foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	root.add_child(foot)
	_button(foot, "Reset to Default", func(): edit(ScriptDef.default_script()))
	_button(foot, "Fill to size", func():
		working = ScriptBuilder.fill(working)
		_rebuild()).tooltip_text = "Top the script up to 15 / 4 / 4 from roles not on it, favouring tags it is short of."
	_button(foot, "Load…", func(): load_dialog.popup_centered_ratio(0.6))
	_button(foot, "Save…", func():
		save_dialog.current_file = (working.name if working.name != "" else "script").validate_filename() + ".json"
		save_dialog.popup_centered_ratio(0.6))
	var sp2 = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	_button(foot, "Cancel", func(): finished.emit(null))
	use_btn = _button(foot, "Use this script", func():
		var out = working.duplicate_script()
		if out.name.strip_edges() == "" or (out.name == ScriptDef.DEFAULT_NAME and not out.is_default()):
			out.name = "Custom"
		finished.emit(out))

	save_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	save_dialog.file_selected.connect(func(path): working.save(path))
	load_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	load_dialog.file_selected.connect(func(path):
		var s = ScriptDef.load_file(path)
		if s != null:
			edit(s))


func edit(s) -> void:
	working = s.duplicate_script()
	name_edit.text = working.name
	_rebuild()


func _rebuild() -> void:
	for box in [on_box, off_box]:
		for ch in box.get_children():
			ch.queue_free()
	var roster: Dictionary = ScriptDef.roster()
	for side in SIDES:
		var key: String = side[0]
		var have: Array = working.get(key)
		_heading(on_box, "%s  %d/%d" % [side[1], have.size(), side[2]])
		for id in have:
			if _shown(id):
				_role_row(on_box, key, id, true)
		var spare: Array = roster[key].filter(func(r): return not r in have and _shown(r))
		if not spare.is_empty():
			_heading(off_box, side[1])
			for id in spare:
				_role_row(off_box, key, id, false)
	var res: Dictionary = working.check()
	var lines: Array = []
	for e in res.errors:
		lines.append("✕ " + e)
	for w in res.warnings:
		lines.append("! " + w)
	notes.text = "\n".join(PackedStringArray(lines)) if not lines.is_empty() else "✓ Covers every suggested tag."
	notes.add_theme_color_override("font_color", UITheme.color("red") if not res.errors.is_empty() else UITheme.color("ink"))
	use_btn.disabled = not res.errors.is_empty()
	use_btn.tooltip_text = "Fix the errors above first." if use_btn.disabled else ""


func _shown(id: String) -> bool:
	return tag_filter == "" or tag_filter in ScriptDef.tags_of(id)


func _role_row(box: VBoxContainer, key: String, id: String, on: bool) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var ic = TextureRect.new()
	var rt = UITheme.tex("ui/roles/" + id, 0.1)
	ic.texture = rt if rt != null else UITheme.tex("ui/roles/unknown", 0.1)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(28, 28)
	row.add_child(ic)
	var text = ScriptDef.display(id)
	var tags: Array = ScriptDef.tags_of(id).map(func(t): return ScriptDef.TAG_NAMES.get(t, t))
	var nm = _label(text + ("   · " + ", ".join(PackedStringArray(tags)) if not tags.is_empty() else ""), 15, UITheme.color("ink"))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.tooltip_text = C.SECRET_MODS[id]["desc"] if C.SECRET_MODS.has(id) else C.ROLES.get(id, {}).get("desc", "")
	nm.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(nm)
	if on:
		var force = CheckBox.new()
		force.text = "In play"
		force.tooltip_text = "Custom game: always deal this one."
		force.button_pressed = id in working.forced
		for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			force.add_theme_color_override(k, UITheme.color("ink"))
		force.toggled.connect(func(p):
			if p and not id in working.forced:
				working.forced.append(id)
			elif not p:
				working.forced.erase(id)
			_rebuild())
		row.add_child(force)
		_button(row, "Remove", func():
			working.get(key).erase(id)
			working.forced.erase(id)
			_rebuild())
	else:
		_button(row, "Add", func():
			working.get(key).append(id)
			_rebuild())


func _column(parent: Control, title: String) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	v.add_child(_label(title, 18, UITheme.color("red")))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("paper_dim"), UITheme.color("border"), 1, 4, 8))
	v.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	return box


func _heading(box: VBoxContainer, t: String) -> void:
	box.add_child(_label(t, 16, UITheme.color("red")))


func _label(t: String, size: int, col: Color) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_override("font", UITheme.serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(parent: Control, t: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = t
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _file_dialog(mode: int) -> FileDialog:
	var d = FileDialog.new()
	d.file_mode = mode
	d.access = FileDialog.ACCESS_USERDATA
	DirAccess.make_dir_recursive_absolute(ScriptDef.USER_DIR)
	d.current_dir = ScriptDef.USER_DIR
	d.filters = PackedStringArray(["*.json ; Demonologist scripts"])
	add_child(d)
	return d
