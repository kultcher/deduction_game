## The New Case screen, at launch and from More ▸ New case: Town Population (7 / 10) →
## Script (Default / Dynamic / Load… / Custom…) → Start. Remembers the last town size and
## script between runs (user://settings.cfg, [new_case]): Default, Dynamic (the mode: each
## case number deals its own), or the custom or loaded script itself.
extends Control

signal start_requested(count: int, script_def, case_seed: int)
signal cancelled

const C = preload("res://sim/content.gd")
const UITheme = preload("res://ui/theme.gd")
const ScriptDef = preload("res://sim/script_def.gd")
const ScriptBuilder = preload("res://sim/script_builder.gd")
const PlaytestMarks = preload("res://ui/playtest_marks.gd")
const CaseScriptEditor = preload("res://ui/script_editor.gd")

enum Pick { DEFAULT, LOAD, CUSTOM, DYNAMIC }

var count: int = 7
var chosen = ScriptDef.default_script()
## Dynamic is a mode, not a fixed script: each time the screen opens it deals a fresh one.
var dynamic_mode: bool = false
## The seed the case will start with. The caller sets it before `open`. A dynamic script is
## built from this same seed (as `autoplay.gd --dynamic` does), so one case number
## reproduces the whole case. Reroll picks a new seed.
var case_seed: int = 1
var seed_spin: SpinBox
var reroll_btn: Button
## Debug only: playtest marks skew dynamic scripts (ui/playtest_marks.gd).
var debug: bool = false
var marks_panel
var marks_btn: Button
var marks_label: Label
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
## Where the last choice is kept between runs. Headless runs (tests, tools) neither read nor
## write it unless a test turns `remember` on, so a run never depends on an earlier one.
var settings_path: String = "user://settings.cfg"
var remember: bool = DisplayServer.get_name() != "headless"


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

	var seed_row = HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	seed_row.add_child(_label("Case number", 18, UITheme.color("ink")))
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.tooltip_text = "The same number, town size and script choice deal the same case."
	seed_spin.value_changed.connect(func(val):
		case_seed = int(val)
		if dynamic_mode:
			_roll_dynamic()
		_refresh())
	seed_row.add_child(seed_spin)
	v.add_child(seed_row)

	v.add_child(_label("Script", 18, UITheme.color("ink")))
	script_opt = OptionButton.new()
	script_opt.add_item("Default", Pick.DEFAULT)
	script_opt.add_item("Dynamic (built from every role)", Pick.DYNAMIC)
	script_opt.add_item("Load from file…", Pick.LOAD)
	script_opt.add_item("Custom…", Pick.CUSTOM)
	script_opt.item_selected.connect(_on_script_pick)
	var pick_row = HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	script_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_row.add_child(script_opt)
	reroll_btn = Button.new()
	reroll_btn.text = "Reroll"
	reroll_btn.tooltip_text = "Deal another case: a new case number, and the dynamic script built from it."
	reroll_btn.pressed.connect(func():
		case_seed = fresh_seed()
		_roll_dynamic()
		_refresh())
	pick_row.add_child(reroll_btn)
	var edit_btn = Button.new()
	edit_btn.text = "Edit…"
	edit_btn.tooltip_text = "Open this script in the editor (it becomes a custom script)."
	edit_btn.pressed.connect(func():
		sheet.hide()
		editor.edit(chosen)
		editor.show())
	pick_row.add_child(edit_btn)
	v.add_child(pick_row)
	var marks_row = HBoxContainer.new()
	marks_row.add_theme_constant_override("separation", 8)
	marks_btn = Button.new()
	marks_btn.text = "Playtest marks…"
	marks_btn.tooltip_text = "Debug: favour, list or deal specific roles in dynamic scripts."
	marks_btn.pressed.connect(func():
		sheet.hide()
		marks_panel.open())
	marks_row.add_child(marks_btn)
	marks_label = _label("", 13, UITheme.color("ink"))
	marks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	marks_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marks_row.add_child(marks_label)
	v.add_child(marks_row)
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
		save_last()
		start_requested.emit(count, chosen.duplicate_script(), case_seed))
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

	marks_panel = PlaytestMarks.new()
	marks_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks_panel.offset_left = 360
	marks_panel.offset_top = 60
	marks_panel.offset_right = -360
	marks_panel.offset_bottom = -60
	marks_panel.hide()
	marks_panel.finished.connect(func():
		marks_panel.hide()
		sheet.show()
		if dynamic_mode:
			_roll_dynamic()
		_refresh())
	add_child(marks_panel)

	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_USERDATA
	load_dialog.filters = PackedStringArray(["*.json ; Demonologist scripts"])
	load_dialog.file_selected.connect(func(path):
		var s = ScriptDef.load_file(path)
		if s != null:
			chosen = s
			dynamic_mode = false
		_refresh())
	load_dialog.canceled.connect(_refresh)
	add_child(load_dialog)
	load_last()


## The last town size and script started, from settings_path ([new_case]). A saved script
## that no longer reads (a role removed since) falls back to Default.
func load_last() -> void:
	if not remember:
		return
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	var n: int = int(cfg.get_value("new_case", "town_size", count))
	if C.SETUPS.has(n):
		count = n
	match str(cfg.get_value("new_case", "script", "default")):
		"dynamic":
			dynamic_mode = true
		"custom":
			var d = cfg.get_value("new_case", "custom", {})
			var s = ScriptDef.from_dict(d) if d is Dictionary and d.has("town") else null
			if s != null and s.check(count).errors.is_empty():
				chosen = s
				dynamic_mode = false


## Keep this choice for the next run (other sections of the settings file are left alone).
func save_last() -> void:
	if not remember:
		return
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("new_case", "town_size", count)
	var kind: String = "dynamic" if dynamic_mode else ("default" if chosen.is_default() else "custom")
	cfg.set_value("new_case", "script", kind)
	if kind == "custom":
		cfg.set_value("new_case", "custom", chosen.to_dict())
	elif cfg.has_section_key("new_case", "custom"):
		cfg.erase_section_key("new_case", "custom")
	cfg.save(settings_path)


## can_cancel: false at launch (there is no case to go back to). debug_on shows the
## playtest marks and applies them to dynamic scripts.
func open(can_cancel: bool, debug_on: bool = false) -> void:
	debug = debug_on
	cancel_btn.visible = can_cancel
	warn_label.visible = can_cancel
	editor.hide()
	marks_panel.hide()
	sheet.show()
	if dynamic_mode:
		_roll_dynamic()
	show()
	_refresh()


## A new case number. Never 0: ScriptBuilder reads seed 0 as "pick one at random".
static func fresh_seed() -> int:
	return randi() % 99999 + 1


func _roll_dynamic() -> void:
	var opts = {"seed": case_seed, "name": "Dynamic #%d" % case_seed}
	if debug:
		opts["favoured"] = marks_panel.ids("favoured")
		opts["include"] = marks_panel.ids("include")
		opts["forced"] = marks_panel.ids("forced")
	chosen = ScriptBuilder.dynamic(opts)


func _on_script_pick(i: int) -> void:
	match script_opt.get_item_id(i):
		Pick.DEFAULT:
			dynamic_mode = false
			chosen = ScriptDef.default_script()
			_refresh()
		Pick.DYNAMIC:
			dynamic_mode = true
			_roll_dynamic()
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
		dynamic_mode = false
	_refresh()


func _refresh() -> void:
	for i in range(size_opt.item_count):
		if int(size_opt.get_item_metadata(i)) == count:
			size_opt.select(i)
	var pick: int = Pick.DYNAMIC if dynamic_mode else (Pick.DEFAULT if chosen.is_default() else Pick.CUSTOM)
	script_opt.select(script_opt.get_item_index(pick))
	reroll_btn.visible = dynamic_mode
	seed_spin.set_value_no_signal(case_seed)
	marks_btn.get_parent().visible = debug
	var ms: String = marks_panel.summary()
	marks_label.text = ("Marks apply to dynamic scripts. " + ms) if ms != "" else "No playtest marks."
	script_label.text = "%s — %s" % [chosen.name, chosen.summary()]
	if not chosen.is_default():
		script_label.text += "\nTown: " + ", ".join(PackedStringArray(chosen.town.map(func(r): return ScriptDef.display(r))))
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
