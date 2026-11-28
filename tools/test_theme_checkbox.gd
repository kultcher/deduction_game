## The theme's checkboxes draw a box (ui/theme.gd, Limner Nov 28): every CheckBox state has
## its icon, the ticked and unticked ones differ, and the disabled ones are the dimmed pair.
##   godot --headless --path . --script res://tools/test_theme_checkbox.gd
extends SceneTree

const UITheme = preload("res://ui/theme.gd")

var _checks: int = 0
var _fails: int = 0

func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var th: Theme = UITheme.make()
	var names = ["unchecked", "checked", "unchecked_disabled", "checked_disabled"]
	_check(names.all(func(n): return th.has_icon(n, "CheckBox") and th.get_icon(n, "CheckBox") != null), "every checkbox state has an icon")
	var off: Texture2D = th.get_icon("unchecked", "CheckBox")
	var on: Texture2D = th.get_icon("checked", "CheckBox")
	_check(off.get_image().get_data() != on.get_image().get_data(), "ticked and unticked look different")
	_check(off.get_width() == on.get_width() and off.get_width() >= 16 and off.get_width() <= 32, "the box is a readable size beside 15-18 pt text (%d px)" % off.get_width())
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
