## In-engine UI. The town map (click places and people), a coloured log, a context-sensitive
## action panel (every command as buttons and menus), a profile panel, an optional case-board
## sidebar and the full-screen case view. Every click becomes the same text command the CLI
## uses, so the typed prompt still works as a fallback.
extends Control

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const CaseView = preload("res://ui/case_view.gd")
const CardList = preload("res://ui/card_list.gd")
const MapView = preload("res://ui/map_view.gd")

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
var map
var actions: VBoxContainer
var action_title: Label
var popup: PopupPanel
var mono: SystemFont
var history: Array = []
var hist_i = 0
var theory_label: Label
var debug_check: CheckBox
var _name_re: RegEx
var _speech_re: RegEx

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(root)

	var top = HFlowContainer.new()
	root.add_child(top)
	var lbl = Label.new()
	lbl.text = "Case seed"
	top.add_child(lbl)
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 999999
	seed_box.value = randi() % 100000
	top.add_child(seed_box)
	_button(top, "New case", _new_case)
	_button(top, "Case view", _open_case_view)
	_button(top, "Record theory", _open_theory)
	_button(top, "Board", func(): side.visible = not side.visible)
	_button(top, "Cast", func(): _run("cast"))
	_button(top, "Timeline", func(): _run("timeline"))
	_button(top, "Roles", func(): _run("roles"))
	_button(top, "Help", func(): _run("help"))
	_button(top, "Write dev log", func(): _run("log"))
	debug_check = CheckBox.new()
	debug_check.text = "Debug"
	debug_check.tooltip_text = "Show what NPCs privately make of each card and person (influence, credibility, suspicion). Turning it on mid-case leaves your identification unscored."
	debug_check.toggled.connect(func(on):
		g.set_debug_overlay(on)
		_refresh_all())
	top.add_child(debug_check)
	theory_label = Label.new()
	theory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(theory_label)

	var body = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# Left: map over log, with the typed prompt as a fallback.
	var left = VSplitContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	map = MapView.new()
	map.custom_minimum_size = Vector2(500, 300)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_stretch_ratio = 1.1
	map.clicked.connect(_on_map_clicked)
	left.add_child(map)
	var logbox = VBoxContainer.new()
	logbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(logbox)
	out = RichTextLabel.new()
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.custom_minimum_size = Vector2(0, 160)
	out.scroll_following = true
	out.selection_enabled = true
	out.bbcode_enabled = true
	out.add_theme_font_override("normal_font", mono)
	out.add_theme_font_size_override("normal_font_size", 14)
	logbox.add_child(out)
	var bottom = HBoxContainer.new()
	logbox.add_child(bottom)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "Or type a command (help lists them) and press Enter"
	input.add_theme_font_override("font", mono)
	input.text_submitted.connect(_on_submit)
	input.gui_input.connect(_on_input_key)
	bottom.add_child(input)
	_button(bottom, "Send", func(): _on_submit(input.text))

	# Right: what you can do now, then the selected person; the optional board beside it.
	var rightbox = HBoxContainer.new()
	body.add_child(rightbox)
	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.add_theme_constant_override("separation", 6)
	rightbox.add_child(right)
	action_title = Label.new()
	action_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_title.add_theme_font_size_override("font_size", 16)
	action_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	right.add_child(action_title)
	var asc = ScrollContainer.new()
	asc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(asc)
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc.add_child(actions)
	right.add_child(HSeparator.new())
	side_person = OptionButton.new()
	side_person.clip_text = true
	side_person.item_selected.connect(func(_i): _refresh_profile())
	right.add_child(side_person)
	side_profile = RichTextLabel.new()
	side_profile.bbcode_enabled = true
	side_profile.custom_minimum_size = Vector2(0, 220)
	side_profile.add_theme_font_size_override("normal_font_size", 12)
	right.add_child(side_profile)

	# Optional case-board sidebar.
	side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.visible = false
	rightbox.add_child(side)
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
	_button(side, "Open case view", _open_case_view)

	popup = PopupPanel.new()
	var psb = StyleBoxFlat.new()
	psb.bg_color = Color(0.1, 0.1, 0.13)
	psb.border_color = Color(0.45, 0.42, 0.35)
	psb.set_border_width_all(1)
	psb.set_content_margin_all(10)
	popup.add_theme_stylebox_override("panel", psb)
	add_child(popup)

	case_view = CaseView.new()
	case_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	case_view.visible = false
	add_child(case_view)
	case_view.build(mono)
	case_view.changed.connect(_refresh_side)

	_new_case()

func _button(parent: Node, text: String, cb: Callable, color = null) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if color != null:
		b.add_theme_color_override("font_color", color)
		b.add_theme_color_override("font_hover_color", color.lightened(0.3))
	parent.add_child(b)
	return b

func _on_side_activated(num) -> void:
	input.text += " " + str(num)
	input.grab_focus()
	input.caret_column = input.text.length()

func _new_case() -> void:
	g = Game.new()
	out.clear()
	_build_colour_rules()
	_print(g.new_case(int(seed_box.value)))
	side_person.clear()
	for n in g.w.npcs:
		side_person.add_item(n.name)
		side_person.set_item_metadata(side_person.item_count - 1, n.id)
		side_person.set_item_icon(side_person.item_count - 1, _swatch(C.npc_color(n.id)))
	case_view.set_game(g)
	map.set_game(g)
	if debug_check.button_pressed:
		g.set_debug_overlay(true)
	_refresh_all()

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
	_refresh_all()

## Several commands from one click (e.g. walk to someone, then talk to them).
func _run_seq(cmds: Array) -> void:
	for c in cmds:
		var before = g.state
		_run(c)
		if g.state == "over" or (before == g.state and g.last_events.any(func(e): return e.get("k", "") == "error")):
			break

var _last_phase_key = ""

func _refresh_all() -> void:
	# The map follows you: zoom to your block once you've moved; back out for a new phase.
	var key = "%d:%d:%s" % [g.w.day, g.w.phase, g.state if g.state in ["night", "meeting", "nomination", "over"] else "day"]
	if key != _last_phase_key:
		_last_phase_key = key
		map.zoom_block = ""
		map.selected_block = ""
	if g.state in ["day", "talk", "approach"] and g.moved:
		map.zoom_block = g.w.loc_block(g.loc)
	_refresh_side()
	_refresh_actions()
	map.refresh()
	if case_view.visible:
		case_view.refresh()

## Show this person's profile in the sidebar and the case view.
func _select_person(id: String) -> void:
	for i in range(side_person.item_count):
		if side_person.get_item_metadata(i) == id:
			side_person.select(i)
	case_view.show_profile(id)
	map.selected_npc = id
	_refresh_profile()

# ---------------------------------------------------------------- coloured log

func _build_colour_rules() -> void:
	_name_re = RegEx.new()
	_speech_re = RegEx.new()
	var names: Array = []
	for n in C.CAST:
		names.append(n["name"])
	_name_re.compile("\\b(" + "|".join(PackedStringArray(names)) + ")\\b")
	_speech_re.compile("^(\\s*)(" + "|".join(PackedStringArray(names)) + "): (\".*)$")

func _hex_for(name: String) -> String:
	for n in C.CAST:
		if n["name"] == name:
			return C.npc_color(n["id"]).to_html(false)
	return "dddddd"

## Plain text from the game -> BBCode: speech lines in the speaker's colour, names coloured
## wherever they appear.
func _colourize(s: String) -> String:
	var lines = PackedStringArray()
	for line in s.split("\n"):
		var esc = line.replace("[", "[lb]")
		var m = _speech_re.search(esc)
		if m != null:
			var hex = _hex_for(m.get_string(2))
			lines.append("%s[color=#%s][b]%s[/b]: %s[/color]" % [m.get_string(1), hex, m.get_string(2), m.get_string(3)])
			continue
		var outl = ""
		var pos = 0
		for mm in _name_re.search_all(esc):
			outl += esc.substr(pos, mm.get_start() - pos) + "[color=#%s]%s[/color]" % [_hex_for(mm.get_string()), mm.get_string()]
			pos = mm.get_end()
		outl += esc.substr(pos)
		if line.begins_with("> "):
			outl = "[color=#8a8f99]" + outl + "[/color]"
		lines.append(outl)
	return "\n".join(lines)

func _print(s: String) -> void:
	out.append_text(_colourize(s) + "\n")

func _swatch(c: Color) -> ImageTexture:
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- map clicks

func _on_map_clicked(kind: String, id: String) -> void:
	if kind == "npc":
		_select_person(id)
	match g.state:
		"day":
			var w = g.w
			match kind:
				"location", "scene":
					if not g.moved:
						_run("go " + id)
					elif id != g.loc and w.loc_block(id) == w.loc_block(g.loc) and not g.free_move_used:
						_run("go " + id)
					elif id != g.loc:
						_print("(You've already chosen where to spend this phase.)")
				"home":
					var hn = w.by_id[id]
					if g.moved:
						_print("(You've already chosen where to spend this phase.)")
					elif hn.alive and hn.at_home():
						_run("go " + id)
					else:
						_print("(Nobody's home at %s's just now.)" % hn.name)
				"npc":
					var n = w.by_id[id]
					var cmds: Array = []
					if not g.moved:
						cmds.append("go " + id)
					if n.busy_with == "":
						cmds.append("talk " + id)
					_run_seq(cmds)
		"night":
			_refresh_actions()
	map.refresh()

# ---------------------------------------------------------------- action panel

func _refresh_actions() -> void:
	for ch in actions.get_children():
		ch.queue_free()
	if g == null:
		return
	var w = g.w
	match g.state:
		"day":
			_actions_day(w)
		"approach":
			action_title.text = ("%s wants a word." % g.approach["npc"].name) if g.approach.has("npc") else "Someone wants a word."
			_button(actions, "Hear them out (uses this phase)", func(): _run("accept"))
			_button(actions, "Wave them off", func(): _run("decline"))
		"talk":
			_actions_talk(w)
		"meeting":
			action_title.text = "Day %d: the town meeting" % w.day
			_button(actions, "Let the town speak (wait)", func(): _run("wait"))
			if not g.presented_today:
				_button(actions, "Present a deduction to everyone…", func(): _card_picker("Present a deduction to the meeting",
					func(c): return c["kind"] == "deduction", func(num, _x): _run("present %d" % num), false))
			var nom = _button(actions, "Nominate…", func(): pass)
			nom.pressed.connect(func(): _people_picker(nom, "Nominate whom?", func(id): _run("nominate " + id), func(n): return w.can_nominate("player", n.id) == ""))
			var done = _button(actions, "Close the meeting", func(): _run("done"))
			done.disabled = not g.town_quiet
			if not g.town_quiet:
				done.tooltip_text = "Let the town speak first (wait) until nobody else rises."
		"nomination":
			var nm: Dictionary = w.meeting["pending"]
			action_title.text = "Vote on %s" % w.by_id[nm["nominee"]].name
			_button(actions, "Vote to execute", func(): _run("vote yes"))
			_button(actions, "Vote against", func(): _run("vote no"))
			if not g.statement_used:
				_button(actions, "Speak against them…", func(): _card_picker("Accuse, citing a card (optional)",
					func(c): return true, func(num, _x): _run("accuse %d" % num if num > 0 else "accuse"), true))
				_button(actions, "Speak in their defence…", func(): _card_picker("Defend, citing a card (optional)",
					func(c): return true, func(num, _x): _run("defend %d" % num if num > 0 else "defend"), true))
			if w.tools["clemency"] > 0 and nm["by"] != "player":
				_button(actions, "Invoke Clemency (once per case)", func(): _run("clemency"))
		"night":
			action_title.text = "Night %d: your night work" % w.day
			if map.selected_block != "":
				_button(actions, "Keep vigil on %s" % C.block_name(map.selected_block), func(): _run("vigil " + map.selected_block))
			if map.selected_npc != "" and w.tools["ward"] > 0 and w.by_id[map.selected_npc].alive:
				_button(actions, "Ward %s's door (once per case)" % w.by_id[map.selected_npc].name, func(): _run("ward " + map.selected_npc), C.npc_color(map.selected_npc))
			var vig = _button(actions, "Keep vigil on…", func(): pass)
			vig.pressed.connect(func(): _list_picker(vig, "Watch which block?", C.BLOCKS.keys().map(func(b): return [C.block_name(b), "vigil " + b, null])))
			if w.tools["ward"] > 0:
				var wd = _button(actions, "Ward someone…", func(): pass)
				wd.pressed.connect(func(): _people_picker(wd, "Ward whom?", func(id): _run("ward " + id), func(n): return n.alive))
			_button(actions, "Sleep", func(): _run("sleep"))
			_hint("Tip: click a block or a person on the map to pick them.")
		"over":
			action_title.text = "The case is closed."
			_button(actions, "Show the grimoire", func(): _run("grimoire"))
			_button(actions, "Show every lie", func(): _run("grimoire lies"))
			_button(actions, "New case", _new_case)

func _actions_day(w) -> void:
	if not g.moved:
		action_title.text = "Day %d, %s: where will you go?" % [w.day, C.PHASES[w.phase].to_lower()]
		_hint("Click a block to look closer, then a place or a person. Clicking a person walks you to them and starts a conversation.")
		_button(actions, "Wait (let the %s pass)" % C.PHASES[w.phase].to_lower(), func(): _run("wait"))
		return
	action_title.text = "%s, %s" % [w.loc_name(g.loc).capitalize(), C.PHASES[w.phase].to_lower()]
	var here: Array = g._present(g.loc)
	for n in here:
		if n.busy_with == "":
			_button(actions, "Talk to %s" % n.name, func(): _run("talk " + n.id), C.npc_color(n.id))
		else:
			var b = _button(actions, "%s is deep in conversation" % n.name, func(): pass, C.npc_color(n.id))
			b.disabled = true
	if not g.free_move_used:
		for l in w.locations_on(w.loc_block(g.loc)):
			if l == g.loc or l.begins_with("home_"):
				continue
			var who: Array = g._present(l).filter(func(x): return x.busy_with == "")
			if not who.is_empty():
				for n in who:
					_button(actions, "Talk to %s (at %s)" % [n.name, w.loc_name(l)], func(): _run("talk " + n.id), C.npc_color(n.id))
	if not g.loc.begins_with("home_"):
		_button(actions, "Search here", func(): _run("search"))
	if g.loc == "tavern":
		_button(actions, "Listen to the gossip", func(): _run("gossip"))
	_button(actions, "Wait", func(): _run("wait"))
	if not g.free_move_used:
		_hint("You can still step to the other spot on this block (click it on the map).")

func _actions_talk(w) -> void:
	var n = g.talk_with
	action_title.text = "Talking with %s (%d question%s left)" % [n.name, g.questions_left, "" if g.questions_left == 1 else "s"]
	var sb = _button(actions, "Ask about %s…  ▸" % n.name, func(): pass)
	sb.pressed.connect(func(): _ask_self_picker(sb))
	var ab = _button(actions, "Ask about others…  ▸", func(): pass)
	ab.pressed.connect(func(): _ask_about_picker(ab))
	_button(actions, "Present a card…", func(): _card_picker("Present a card to %s" % n.name, func(c): return true,
		func(num, extra): _run(("present %d" % num) + extra), false, true))
	_button(actions, "Leave", func(): _run("bye"))

func _hint(t: String) -> void:
	var l = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	actions.add_child(l)

# ---------------------------------------------------------------- pickers

func _show_popup(content: Control, anchor: Control) -> void:
	for ch in popup.get_children():
		ch.queue_free()
	popup.add_child(content)
	var pos = Vector2i(anchor.get_screen_position()) + Vector2i(0, int(anchor.size.y)) if anchor != null else Vector2i(get_viewport_rect().size / 2.0)
	popup.popup(Rect2i(pos, Vector2i(10, 10)))
	popup.reset_size()

func _column(title: String) -> VBoxContainer:
	var v = VBoxContainer.new()
	var l = Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	v.add_child(l)
	return v

## "Ask about <them>…": questions about the listener themselves, and a column of gifts to
## ask if they hold one.
func _ask_self_picker(anchor: Control) -> void:
	var n = g.talk_with
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var qs = _column("Ask %s…" % n.name)
	for it in [["about their gift", "ask gift"], ["who they've seen around today", "ask today"], ["if they saw anything last night", "ask night"]]:
		var cmd: String = it[1]
		_button(qs, it[0], func():
			popup.hide()
			_run(cmd))
	h.add_child(qs)
	var gifts = _column("…if they are the")
	for r in C.GOOD_ROLES:
		_button(gifts, C.role_name(r), func():
			popup.hide()
			_run("ask are " + C.role_name(r).to_lower()))
	h.add_child(gifts)
	_show_popup(h, anchor)

## "Ask about others…": opinion on a person, or whether they've heard of anyone holding a gift.
func _ask_about_picker(anchor: Control) -> void:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var people = _column("Opinion on…")
	for n in g.w.npcs:
		if n == g.talk_with:
			continue
		_button(people, n.name + ("" if n.alive else " †"), func():
			popup.hide()
			_run("ask about " + n.id), C.npc_color(n.id))
	h.add_child(people)
	var gifts = _column("Heard of a…")
	for r in C.GOOD_ROLES:
		_button(gifts, C.role_name(r), func():
			popup.hide()
			_run("ask about " + C.role_name(r).to_lower()))
	h.add_child(gifts)
	_show_popup(h, anchor)

func _people_picker(anchor: Control, title: String, cb: Callable, allowed: Callable) -> void:
	var v = _column(title)
	for n in g.w.living():
		var b = _button(v, n.name, func():
			popup.hide()
			cb.call(n.id), C.npc_color(n.id))
		b.disabled = not allowed.call(n)
	_show_popup(v, anchor)

func _list_picker(anchor: Control, title: String, items: Array) -> void:
	var v = _column(title)
	for it in items:
		_button(v, it[0], func():
			popup.hide()
			_run(it[1]), it[2])
	_show_popup(v, anchor)

## Pick a card from the board. allow_none: offer "without a card". with_target: offer the
## optional for/against override for 'present'.
func _card_picker(title: String, keep: Callable, cb: Callable, allow_none: bool, with_target: bool = false) -> void:
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 420)
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	v.add_child(t)
	var f = LineEdit.new()
	f.placeholder_text = "filter: person, place, kind, d2, n1, text"
	v.add_child(f)
	var lst = CardList.new()
	lst.select_mode = Tree.SELECT_ROW
	lst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lst.add_theme_font_size_override("font_size", 12)
	v.add_child(lst)
	var fill = func():
		lst.reset()
		for c in g.filter_cards(f.text):
			if keep.call(c):
				lst.add("#%-3d %s" % [c["n"], c["text"]], c["n"], c["text"], Color(0.95, 0.8, 0.45) if c["kind"] == "deduction" else null)
	fill.call()
	f.text_changed.connect(func(_x): fill.call())
	var mode: OptionButton = null
	var who: OptionButton = null
	if with_target:
		var row = HBoxContainer.new()
		v.add_child(row)
		mode = OptionButton.new()
		for m in ["Let them read it", "Speak for…", "Speak against…"]:
			mode.add_item(m)
		row.add_child(mode)
		who = OptionButton.new()
		for n in g.w.living():
			if n != g.talk_with:
				who.add_item(n.name)
				who.set_item_metadata(who.item_count - 1, n.id)
		row.add_child(who)
	var extra = func() -> String:
		if mode == null or mode.selected == 0 or who.selected < 0:
			return ""
		return (" for " if mode.selected == 1 else " against ") + str(who.get_item_metadata(who.selected))
	var go = func():
		var sel: Array = lst.selected_metas()
		if sel.is_empty():
			return
		popup.hide()
		cb.call(sel[0], extra.call())
	lst.card_activated.connect(func(_n): go.call())
	var row2 = HBoxContainer.new()
	v.add_child(row2)
	_button(row2, "Use this card", func(): go.call())
	if allow_none:
		_button(row2, "Without a card", func():
			popup.hide()
			cb.call(0, ""))
	_button(row2, "Cancel", func(): popup.hide())
	_show_popup(v, null)

# ---------------------------------------------------------------- side panels

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
		var dbg = g.debug_card_text(c) if g.debug_overlay else ""
		side_list.add("#%-3d %s%s" % [c["n"], c["text"], ("\n      ⟨" + dbg + "⟩") if dbg != "" else ""], c["n"], c["text"], col)
	_refresh_profile()

func _refresh_profile() -> void:
	if g == null or side_person.selected < 0:
		return
	var id: String = side_person.get_item_metadata(side_person.selected)
	var p: Dictionary = g.profile_data(id)
	var hex = C.npc_color(id).to_html(false)
	var tl = PackedStringArray()
	for t in ["privacy", "gossip", "confidence", "insight", "composure"]:
		tl.append("%s %s" % [t.substr(0, 4), p["traits"].get(t, "?")])
	var gs: Dictionary = p["guess"]
	var lines = PackedStringArray()
	lines.append("[color=#%s][b]%s[/b][/color] the %s (%s)" % [hex, p["name"], p["occupation"], p["status"]])
	lines.append("Works %s; lives on %s." % [p["work"], p["home"]])
	if p["claim"] != "":
		lines.append(p["claim"])
	for x in p["named"]:
		lines.append("Readings say: " + x)
	lines.append("Traits: " + ", ".join(tl))
	lines.append("Your guess: %s%s" % [gs.get("guess", "?"), (" (%d/3)" % gs["confidence"]) if gs.has("confidence") else ""])
	if p["note"] != "":
		lines.append("Note: " + p["note"])
	if g.debug_overlay:
		lines.append("[color=#9fd3a8]" + g.debug_npc_text(id) + "[/color]")
	side_profile.text = "\n".join(lines).replace("[lb]", "[")

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
