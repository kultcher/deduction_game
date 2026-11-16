## BACKLOG "Remember the last script": the New Case screen keeps the last town size and
## script between runs (user://settings.cfg, [new_case]). Dynamic is remembered as the
## mode, so each case number still deals its own; a custom script is remembered whole.
extends SceneTree
const NewCaseScreen = preload("res://ui/new_case_screen.gd")
const ScriptDef = preload("res://sim/script_def.gd")
var checks = 0
var fails = 0
const PATH = "user://test_new_case_memory.cfg"

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		fails += 1

func _screen():
	var s = NewCaseScreen.new()
	s.remember = true
	s.settings_path = PATH
	s.load_last()
	return s

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	# Headless screens never touch the real settings file.
	var plain = NewCaseScreen.new()
	check(not plain.remember, "headless: the screen doesn't remember by default")
	plain.free()

	var a = _screen()
	check(a.count == 7 and not a.dynamic_mode and a.chosen.is_default(), "no settings yet: the usual defaults")
	a.count = 10
	a.dynamic_mode = true
	a.case_seed = 4242
	a._roll_dynamic()
	a.save_last()
	a.free()
	var b = _screen()
	check(b.count == 10, "town size remembered")
	check(b.dynamic_mode, "Dynamic remembered as the mode")
	b.case_seed = 777
	b.open(false)
	check(b.chosen.name == "Dynamic #777", "...and still dealt from this run's case number: " + b.chosen.name)

	# A custom script is kept whole.
	# (A built script stands in for one loaded from a file or made in the editor.)
	var custom = preload("res://sim/script_builder.gd").dynamic({"seed": 31, "name": "Herald test"})
	b.chosen = custom
	b.dynamic_mode = false
	b.save_last()
	b.free()
	var c = _screen()
	check(not c.dynamic_mode and c.chosen.name == "Herald test" and c.chosen.to_dict() == custom.to_dict(), "a custom script is remembered whole")

	# Back to Default clears the kept custom script.
	c.chosen = ScriptDef.default_script()
	c.save_last()
	c.free()
	var d = _screen()
	check(d.chosen.is_default() and not d.dynamic_mode, "Default remembered")
	var cfg = ConfigFile.new()
	cfg.load(PATH)
	check(not cfg.has_section_key("new_case", "custom"), "...and the old custom script dropped")

	# A saved script that no longer reads falls back to Default.
	cfg.set_value("new_case", "script", "custom")
	cfg.set_value("new_case", "custom", {"name": "Stale", "town": ["no_such_role"], "minions": [], "demons": [], "secrets": [], "forced": []})
	cfg.save(PATH)
	d.free()
	var e = _screen()
	check(e.chosen.is_default(), "an unreadable saved script falls back to Default")
	e.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("New case memory: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
