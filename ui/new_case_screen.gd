## The New Case screen, at launch and from More ▸ New case: Town Population (7 / 10) →
## Script (Default / Load… / Custom…) → Start. Remembers the last choice while the game runs.
extends Control

signal start_requested(count: int, script_def)
signal cancelled

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const CaseScriptEditor = preload("res://ui/script_editor.gd")

enum Pick { DEFAULT, LOAD, CUSTOM }

var count: int = 7
var chosen = ScriptDef.default_script()
var sheet: PanelContainer
var size_opt: OptionButton
var script_opt: OptionButton
var script_label: Label
var notes: Label
var warn_label: Label
var start_btn: Button
var cancel_btn: Button
var editor
var load_dialog: FileDialog


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	sheet = PanelContainer.new()
	sheet.custom_minimum_size = Vector2(620, 0)
	sheet.add_theme_stylebox_override("panel", UITheme.panel("paper"))
	center.add_child(sheet)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	sheet.add_child(v)
	v.add_child(_label("A New Case", 30, UITheme.color("red")))

	v.add_child(_label("Town population", 18, UITheme.color("ink")))
	size_opt = OptionButton.new()
	for n in [7, 10]:
		var cfg: Dictionary = C.SETUPS[n]
		size_opt.add_item("%d townsfolk  (%d gifts · %d minion%s · 1 demon)" % [n, cfg.town, cfg.minions, "" if cfg.minions == 1 else "s"])
		size_opt.set_item_metadata(size_opt.item_count - 1, n)
	size_opt.item_selected.connect(func(i):
		count = int(size_opt.get_item_metadata(i))
		_refresh())
	v.add_child(size_opt)

	v.add_child(_label("Script", 18, UITheme.color("ink")))
	script_opt = OptionButton.new()
	script_opt.add_item("Default", Pick.DEFAULT)
	script_opt.add_item("Load from file…", Pick.LOAD)
	script_opt.add_item("Custom…", Pick.CUSTOM)
	script_opt.item_selected.connect(_on_script_pick)
	v.add_child(script_opt)
	script_label = _label("", 15, UITheme.color("ink"))
	script_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(script_label)
	notes = _label("", 13, UITheme.color("ink"))
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(notes)

	warn_label = _label("Starting a new case ends the current one; its board will be lost.", 13, UITheme.color("red"))
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(warn_label)
	var foot = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	cancel_btn = Button.new()
	cancel_btn.text = "Back to the case"
	cancel_btn.pressed.connect(func():
		hide()
		cancelled.emit())
	foot.add_child(cancel_btn)
	start_btn = Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size.x = 120
	start_btn.pressed.connect(func():
		hide()
		start_requested.emit(count, chosen.duplicate_script()))
	foot.add_child(start_btn)

	editor = CaseScriptEditor.new()
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.offset_left = 60
	editor.offset_top = 40
	editor.offset_right = -60
	editor.offset_bottom = -40
	editor.hide()
	editor.finished.connect(_on_editor_done)
	add_child(editor)

	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_USERDATA
	load_dialog.filters = PackedStringArray(["*.json ; Demonologist scripts"])
	load_dialog.file_selected.connect(func(path):
		var s = ScriptDef.load_file(path)
		if s != null:
			chosen = s
		_refresh())
	load_dialog.canceled.connect(_refresh)
	add_child(load_dialog)


## can_cancel: false at launch (there is no case to go back to).
func open(can_cancel: bool) -> void:
	cancel_btn.visible = can_cancel
	warn_label.visible = can_cancel
	editor.hide()
	sheet.show()
	show()
	_refresh()


func _on_script_pick(i: int) -> void:
	match script_opt.get_item_id(i):
		Pick.DEFAULT:
			chosen = ScriptDef.default_script()
			_refresh()
		Pick.LOAD:
			DirAccess.make_dir_recursive_absolute(ScriptDef.USER_DIR)
			load_dialog.current_dir = ScriptDef.USER_DIR
			load_dialog.popup_centered_ratio(0.6)
		Pick.CUSTOM:
			sheet.hide()
			editor.edit(chosen)
			editor.show()


func _on_editor_done(s) -> void:
	editor.hide()
	sheet.show()
	if s != null:
		chosen = s
	_refresh()


func _refresh() -> void:
	for i in range(size_opt.item_count):
		if int(size_opt.get_item_metadata(i)) == count:
			size_opt.select(i)
	var pick: int = Pick.DEFAULT if chosen.is_default() else Pick.CUSTOM
	script_opt.select(script_opt.get_item_index(pick))
	script_label.text = "%s — %s" % [chosen.name, chosen.summary()]
	var res: Dictionary = chosen.check(count)
	var lines: Array = []
	for e in res.errors:
		lines.append("✕ " + e)
	for w in res.warnings:
		lines.append("! " + w)
	notes.text = "\n".join(PackedStringArray(lines))
	notes.add_theme_color_override("font_color", UITheme.color("red") if not res.errors.is_empty() else UITheme.color("ink"))
	start_btn.disabled = not res.errors.is_empty()


func _label(t: String, size: int, col: Color) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_override("font", UITheme.serif())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
