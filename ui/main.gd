## In-engine UI: the text console (actions), a summary case-board sidebar, and a
## full-screen case view. Commands go to the same game.gd interpreter the CLI uses; the
## board panels read the game's structured data directly.
extends Control

const Game = preload("res://game/game.gd")
const CaseView = preload("res://ui/case_view.gd")
const CardList = preload("res://ui/card_list.gd")

var g
var out: RichTextLabel
var input: LineEdit
var seed_box: SpinBox
var side: VBoxContainer
var side_filter: LineEdit
var side_list
var side_person: OptionButton
var side_profile: RichTextLabel
var case_view
var mono: SystemFont
var history: Array = []
var hist_i = 0
var theory_label: Label

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])

	var split = HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(split)

	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	split.add_child(vb)

	var top = HFlowContainer.new()
	vb.add_child(top)
	var lbl = Label.new()
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
	_button(top, "Timeline", func(): _run("timeline"))
	_button(top, "Roles", func(): _run("roles"))
	_button(top, "Help", func(): _run("help"))
	_button(top, "Write dev log", func(): _run("log"))
	_button(top, "Board panel", func(): side.visible = not side.visible)
	_button(top, "Case view", _open_case_view)
	_button(top, "Record theory", _open_theory)
	theory_label = Label.new()
	theory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(theory_label)

	out = RichTextLabel.new()
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.scroll_following = true
	out.selection_enabled = true
	out.add_theme_font_override("normal_font", mono)
	out.add_theme_font_size_override("normal_font_size", 15)
	vb.add_child(out)

	var bottom = HBoxContainer.new()
	vb.add_child(bottom)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "Type a command (e.g. go tavern, talk agnes, ask gift) and press Enter"
	input.add_theme_font_override("font", mono)
	input.text_submitted.connect(_on_submit)
	input.gui_input.connect(_on_input_key)
	bottom.add_child(input)
	_button(bottom, "Send", func(): _on_submit(input.text))

	# Summary sidebar.
	side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(320, 0)
	split.add_child(side)
	var st = Label.new()
	st.text = "Case board (newest first)"
	side.add_child(st)
	side_filter = LineEdit.new()
	side_filter.placeholder_text = "filter: person, place, kind, d2, n1, text"
	side_filter.text_changed.connect(func(_t): _refresh_side())
	side.add_child(side_filter)
	side_list = CardList.new()
	side_list.select_mode = Tree.SELECT_ROW
	side_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_list.add_theme_font_override("font", mono)
	side_list.add_theme_font_size_override("font_size", 12)
	side_list.card_activated.connect(_on_side_activated)
	side.add_child(side_list)
	var hint = Label.new()
	hint.text = "Double-click a card to add its number to your command."
	hint.add_theme_font_size_override("font_size", 11)
	side.add_child(hint)
	side_person = OptionButton.new()
	side_person.clip_text = true
	side_person.item_selected.connect(func(_i): _refresh_side())
	side.add_child(side_person)
	side_profile = RichTextLabel.new()
	side_profile.custom_minimum_size = Vector2(0, 170)
	side_profile.add_theme_font_size_override("normal_font_size", 12)
	side.add_child(side_profile)
	_button(side, "Open case view", _open_case_view)

	case_view = CaseView.new()
	case_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	case_view.visible = false
	add_child(case_view)
	case_view.build(mono)
	case_view.changed.connect(_refresh_side)

	_new_case()

func _button(parent: Node, text: String, cb: Callable) -> void:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)

func _on_side_activated(num) -> void:
	input.text += " " + str(num)
	input.grab_focus()
	input.caret_column = input.text.length()

func _new_case() -> void:
	g = Game.new()
	out.clear()
	_print(g.new_case(int(seed_box.value)))
	side_person.clear()
	for n in g.w.npcs:
		side_person.add_item(n.name)
		side_person.set_item_metadata(side_person.item_count - 1, n.id)
	case_view.set_game(g)
	_refresh_side()
	input.grab_focus()

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and not case_view.visible:
		input.grab_focus()

func _open_case_view() -> void:
	case_view.refresh()
	case_view.visible = true

func _open_theory() -> void:
	_open_case_view()
	case_view.open_theory()

func _on_submit(text: String) -> void:
	var t = text.strip_edges()
	input.clear()
	if t == "":
		return
	history.append(t)
	hist_i = history.size()
	_run(t)

func _run(cmd: String) -> void:
	_print("\n> " + cmd)
	_print(g.command(cmd))
	if g.state == "talk" and g.talk_with != null:
		_select_person(g.talk_with.id)
	_refresh_side()
	if case_view.visible:
		case_view.refresh()
	input.grab_focus()

## Show this person's profile in the sidebar and the case view.
func _select_person(id: String) -> void:
	for i in range(side_person.item_count):
		if side_person.get_item_metadata(i) == id:
			side_person.select(i)
	case_view.show_profile(id)

func _print(s: String) -> void:
	out.add_text(s + "\n")

func _refresh_side() -> void:
	if g == null or side_list == null:
		return
	theory_label.text = g.theory_status()
	if not g.w.game_over:
		theory_label.text += " — Record your demon guess before voting; it costs no time."
	side_list.reset()
	var cards: Array = g.filter_cards(side_filter.text)
	cards.reverse()
	for c in cards.slice(0, 60):
		var col = null
		if c.get("hidden", false):
			col = Color(0.45, 0.45, 0.5)
		elif c["kind"] == "deduction":
			col = Color(0.95, 0.8, 0.45)
		elif c.get("source", "") != "player" and c.get("source", "") != "evidence":
			col = Color(0.72, 0.72, 0.78)
		side_list.add("#%-3d %s" % [c["n"], c["text"]], c["n"], c["text"], col)
	if side_person.selected >= 0:
		var p: Dictionary = g.profile_data(side_person.get_item_metadata(side_person.selected))
		var tl = PackedStringArray()
		for t in ["privacy", "gossip", "confidence", "insight", "composure"]:
			tl.append("%s %s" % [t.substr(0, 4), p["traits"].get(t, "?")])
		var gs: Dictionary = p["guess"]
		var named = ""
		for x in p["named"]:
			named += "Readings say: %s\n" % x
		side_profile.text = "%s the %s (%s)\nWorks %s; lives on %s.\n%s\n%sTraits: %s\nYour guess: %s%s\n%s" % [p["name"], p["occupation"],
			p["status"], p["work"], p["home"], p["claim"], named, ", ".join(tl),
			gs.get("guess", "?"), (" (%d/3)" % gs["confidence"]) if gs.has("confidence") else "", p["note"]]

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
