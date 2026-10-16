## Minimal in-engine text UI. Builds its widgets in code and forwards typed commands
## to the same game.gd interpreter the terminal CLI uses.
extends Control

const Game = preload("res://game/game.gd")

var g
var out: RichTextLabel
var input: LineEdit
var seed_box: SpinBox
var history: Array = []
var hist_i := 0

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	var lbl := Label.new()
	lbl.text = "Case seed"
	top.add_child(lbl)
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 999999
	seed_box.value = randi() % 100000
	top.add_child(seed_box)
	_button(top, "New case", _new_case)
	_button(top, "Cast", func(): _run("cast"))
	_button(top, "Map", func(): _run("map"))
	_button(top, "Board", func(): _run("board"))
	_button(top, "Roles", func(): _run("roles"))
	_button(top, "Help", func(): _run("help"))
	_button(top, "Write dev log", func(): _run("log"))

	out = RichTextLabel.new()
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.scroll_following = true
	out.selection_enabled = true
	out.add_theme_font_override("normal_font", mono)
	out.add_theme_font_size_override("normal_font_size", 15)
	vb.add_child(out)

	var bottom := HBoxContainer.new()
	vb.add_child(bottom)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "Type a command (e.g. go tavern, talk agnes, ask gift) and press Enter"
	input.add_theme_font_override("font", mono)
	input.text_submitted.connect(_on_submit)
	input.gui_input.connect(_on_input_key)
	bottom.add_child(input)
	_button(bottom, "Send", func(): _on_submit(input.text))

	_new_case()

func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)

func _new_case() -> void:
	g = Game.new()
	out.clear()
	_print(g.new_case(int(seed_box.value)))
	input.grab_focus()

func _on_submit(text: String) -> void:
	var t := text.strip_edges()
	input.clear()
	if t == "":
		return
	history.append(t)
	hist_i = history.size()
	_run(t)

func _run(cmd: String) -> void:
	_print("\n> " + cmd)
	_print(g.command(cmd))
	input.grab_focus()

func _print(s: String) -> void:
	out.add_text(s + "\n")

func _on_input_key(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not history.is_empty():
		if ev.keycode == KEY_UP:
			hist_i = max(0, hist_i - 1)
			input.text = history[hist_i]
			input.caret_column = input.text.length()
		elif ev.keycode == KEY_DOWN:
			hist_i = min(history.size(), hist_i + 1)
			input.text = history[hist_i] if hist_i < history.size() else ""
			input.caret_column = input.text.length()
