## Playtest marks (debug only): skew dynamic scripts toward the roles being tested.
## Each role is Normal, Favoured (picked ScriptBuilder.FAVOURED_WEIGHT times as often),
## On script (always listed) or In play (always listed and always dealt). Saved to
## user://playtest_marks.json so they survive restarts.
extends PanelContainer

signal finished

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const ScriptDef = preload("res://sim/script_def.gd")

const PATH = "user://playtest_marks.json"
const MODES = ["normal", "favoured", "include", "forced"]
const MODE_NAMES = {"normal": "Normal", "favoured": "Favoured", "include": "On script", "forced": "In play"}

var marks: Dictionary = {}   # id -> mode (normal ones are left out)
var list: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UITheme.flat(UITheme.color("paper"), UITheme.color("border"), 2, 8, 16))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(_label("Playtest marks", 24, UITheme.color("red")))
	var hint = _label("Debug only. Favoured roles turn up more often in dynamic scripts; On script always lists them; In play also deals them every case. Marks can break the script's limits (the warnings will say).", 14, UITheme.color("ink"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var foot = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	var clear = Button.new()
	clear.text = "Clear all"
	clear.pressed.connect(func():
		marks.clear()
		_save()
		_rebuild())
	foot.add_child(clear)
	var done = Button.new()
	done.text = "Done"
	done.pressed.connect(func(): finished.emit())
	foot.add_child(done)
	load_marks()


func load_marks() -> void:
	marks = {}
	var f = FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				if str(d[k]) in MODES and str(d[k]) != "normal":
					marks[str(k)] = str(d[k])


func ids(mode: String) -> Array:
	return marks.keys().filter(func(k): return marks[k] == mode)


func summary() -> String:
	var parts: Array = []
	for mode in ["forced", "include", "favoured"]:
		var these: Array = ids(mode)
		if not these.is_empty():
			parts.append("%s: %s" % [MODE_NAMES[mode], ", ".join(PackedStringArray(these.map(func(r): return ScriptDef.display(r))))])
	return " · ".join(PackedStringArray(parts))


func open() -> void:
	_rebuild()
	show()


func _rebuild() -> void:
	for ch in list.get_children():
		ch.queue_free()
	var roster: Dictionary = ScriptDef.roster()
	for side in [["town", "Town gifts"], ["minions", "Minions"], ["demons", "Demons"], ["secrets", "Secrets"]]:
		list.add_child(_label(side[1], 17, UITheme.color("red")))
		for id in roster[side[0]]:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			list.add_child(row)
			var nm = _label(ScriptDef.display(id), 15, UITheme.color("ink"))
			nm.custom_minimum_size.x = 200
			row.add_child(nm)
			var opt = OptionButton.new()
			for m in MODES:
				opt.add_item(MODE_NAMES[m])
			opt.select(MODES.find(marks.get(id, "normal")))
			opt.item_selected.connect(func(i):
				if MODES[i] == "normal":
					marks.erase(id)
				else:
					marks[id] = MODES[i]
				_save())
			row.add_child(opt)


func _save() -> void:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(marks, "\t"))


func _label(t: String, size: int, col: Color) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_override("font", UITheme.serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
