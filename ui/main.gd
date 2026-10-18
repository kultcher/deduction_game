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
const MeetingView = preload("res://ui/meeting_view.gd")
const CaseState = preload("res://ui/case_state.gd")
const UITheme = preload("res://ui/theme.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const CastList = preload("res://ui/cast_list.gd")

var g
var out: RichTextLabel
var input: LineEdit
var seed_box: SpinBox
var side: VBoxContainer
var side_filter: LineEdit
var side_list
var profile                  # ui/profile_panel.gd: the same profile as on the case board
var side_profile: RichTextLabel:
	get: return profile.body
var case_view
var case_state = CaseState.new()   # view, filters and selection shared by every panel
var map
var meeting_view
var actions: VBoxContainer
var action_title: Label
var popup: PopupPanel
var mono: SystemFont
var history: Array = []
var hist_i = 0
var theory_label: Label
var debug_check: CheckBox
var day_icon: TextureRect
var day_label: Label
var cast_list                # ui/cast_list.gd
var notes_win: Window
var notes_edit: TextEdit
var roles_win: Window
var roles_box: VBoxContainer
var _name_re: RegEx
var _speech_re: RegEx

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = UITheme.color("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])
	theme = UITheme.make(mono)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(root)

	# Title bar: the day, the screens, and case controls.
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	day_icon = TextureRect.new()
	day_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	day_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	day_icon.custom_minimum_size = Vector2(30, 30)
	top.add_child(day_icon)
	var title = Label.new()
	title.text = "DEMONOLOGIST"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.color("accent"))
	top.add_child(title)
	day_label = Label.new()
	day_label.add_theme_font_size_override("font_size", 18)
	day_label.custom_minimum_size = Vector2(170, 0)
	top.add_child(day_label)
	var town_tab = _button(top, "Town", func(): pass)
	town_tab.toggle_mode = true
	town_tab.button_pressed = true
	_button(top, "Case board", _open_case_view)
	_button(top, "Notes", _open_notes)
	_button(top, "Roles", _open_roles)
	_button(top, "Help", func(): _run("help"))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var lbl = Label.new()
	lbl.text = "Case"
	lbl.add_theme_color_override("font_color", UITheme.color("muted"))
	top.add_child(lbl)
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 999999
	seed_box.value = randi() % 100000
	top.add_child(seed_box)
	_button(top, "New case", _new_case)
	var more = MenuButton.new()
	more.text = "More ▾"
	more.flat = false
	var mp: PopupMenu = more.get_popup()
	for it in ["Cast (text)", "Timeline (text)", "Card list sidebar", "Write dev log"]:
		mp.add_item(it)
	mp.id_pressed.connect(_on_more)
	top.add_child(more)
	debug_check = CheckBox.new()
	debug_check.text = "Debug"
	debug_check.tooltip_text = "Show what NPCs privately make of each card and person (influence, credibility, suspicion). Turning it on mid-case leaves your identification unscored."
	debug_check.toggled.connect(func(on):
		g.set_debug_overlay(on)
		_refresh_all())
	top.add_child(debug_check)
	theory_label = Label.new()
	theory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	theory_label.add_theme_color_override("font_color", UITheme.color("muted"))
	root.add_child(theory_label)

	# Top: the map, the townsfolk, the profile. Bottom: what you can do, beside the log.
	var body = VSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var upper = HBoxContainer.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.size_flags_stretch_ratio = 1.25
	upper.add_theme_constant_override("separation", 10)
	body.add_child(upper)
	map = MapView.new()
	map.custom_minimum_size = Vector2(500, 300)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.clicked.connect(_on_map_clicked)
	upper.add_child(map)
	# While the town meets, the meeting circle takes the map's place.
	meeting_view = MeetingView.new()
	meeting_view.custom_minimum_size = Vector2(500, 300)
	meeting_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meeting_view.visible = false
	meeting_view.person_clicked.connect(func(id): _select_person(id))
	upper.add_child(meeting_view)
	var castbox = VBoxContainer.new()
	castbox.custom_minimum_size = Vector2(270, 0)
	upper.add_child(castbox)
	var ch = Label.new()
	ch.text = "Townsfolk"
	ch.add_theme_font_size_override("font_size", 18)
	ch.add_theme_color_override("font_color", UITheme.color("accent"))
	castbox.add_child(ch)
	var csc = ScrollContainer.new()
	csc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	castbox.add_child(csc)
	cast_list = CastList.new()
	cast_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cast_list.person_clicked.connect(func(id): _select_person(id))
	csc.add_child(cast_list)
	profile = ProfilePanel.new(true)
	profile.build()
	profile.custom_minimum_size = Vector2(400, 0)
	profile.person_changed.connect(func(id):
		map.selected_npc = id
		cast_list.selected = id
		cast_list.refresh())
	profile.changed.connect(func():
		theory_label.text = g.theory_status()
		cast_list.refresh())
	profile.card_clicked.connect(func(n):
		_open_case_view()
		case_state.select_card(n)
		case_view.board.fit_selection())
	upper.add_child(profile)

	var lower = HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 10)
	body.add_child(lower)
	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 6)
	lower.add_child(right)
	action_title = Label.new()
	action_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_title.add_theme_font_size_override("font_size", 19)
	action_title.add_theme_color_override("font_color", UITheme.color("accent"))
	right.add_child(action_title)
	var asc = ScrollContainer.new()
	asc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(asc)
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc.add_child(actions)
	var logbox = VBoxContainer.new()
	logbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(logbox)
	var logpanel = PanelContainer.new()
	logpanel.add_theme_stylebox_override("panel", UITheme.panel("inset"))
	logpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logbox.add_child(logpanel)
	out = RichTextLabel.new()
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.custom_minimum_size = Vector2(0, 160)
	out.scroll_following = true
	out.selection_enabled = true
	out.bbcode_enabled = true
	out.add_theme_font_override("normal_font", mono)
	out.add_theme_font_size_override("normal_font_size", 16)
	logpanel.add_child(out)
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

	# Optional card-list sidebar (More ▾).
	side = VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.visible = false
	lower.add_child(side)
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
	side_list.add_theme_font_size_override("font_size", 14)
	side_list.card_activated.connect(_on_side_activated)
	side.add_child(side_list)
	var hint = Label.new()
	hint.text = "Double-click a card to add its number to your command."
	hint.add_theme_font_size_override("font_size", 14)
	side.add_child(hint)
	_button(side, "Open case board", _open_case_view)

	# Case notes and the roles list: movable windows, reachable from both screens.
	var nwin = _make_window("Case notes", Vector2i(560, 480))
	notes_win = nwin[0]
	var nv: VBoxContainer = nwin[1]
	var nh = Label.new()
	nh.text = "Your notes on the case (saved as you type)"
	nh.add_theme_color_override("font_color", UITheme.color("ink"))
	nv.add_child(nh)
	notes_edit = TextEdit.new()
	notes_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notes_edit.text_changed.connect(func():
		if g != null:
			g.case_notes = notes_edit.text)
	nv.add_child(notes_edit)
	var rwin = _make_window("Gifts that may be in play", Vector2i(620, 640))
	roles_win = rwin[0]
	var rsc = ScrollContainer.new()
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rwin[1].add_child(rsc)
	roles_box = VBoxContainer.new()
	roles_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roles_box.add_theme_constant_override("separation", 8)
	rsc.add_child(roles_box)

	popup = PopupPanel.new()
	popup.add_theme_stylebox_override("panel", UITheme.panel("popup"))
	add_child(popup)

	case_view = CaseView.new()
	case_view.state = case_state
	case_state.selection_changed.connect(func():
		if case_state.selected_person != "" and _side_person_id() != case_state.selected_person:
			_select_person(case_state.selected_person))
	case_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	case_view.visible = false
	add_child(case_view)
	case_view.build(mono)
	case_view.changed.connect(_refresh_side)
	case_view.notes_requested.connect(_open_notes)
	case_view.roles_requested.connect(_open_roles)

	_new_case()

func _button(parent: Node, text: String, cb: Callable, color = null) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if color != null:
		# Character colours are tuned for the dark board; on a paper button, use their ink.
		b.add_theme_color_override("font_color", UITheme.ink_of(color))
		b.add_theme_color_override("font_hover_color", UITheme.ink_of(color).darkened(0.2))
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
	case_view.set_game(g)
	profile.setup(g, case_state)
	cast_list.setup(g)
	notes_edit.text = g.case_notes
	map.set_game(g)
	meeting_view.set_game(g)
	if debug_check.button_pressed:
		g.set_debug_overlay(true)
	_refresh_all()

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and not case_view.visible:
		input.grab_focus()

func _open_case_view() -> void:
	case_view.refresh()
	case_view.visible = true

## A movable window on framed paper. Returns [window, content vbox].
func _make_window(title: String, sz: Vector2i) -> Array:
	var win = Window.new()
	win.title = title
	win.size = sz
	win.visible = false
	win.close_requested.connect(func(): win.hide())
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UITheme.panel("paper"))
	win.add_child(panel)
	var v = VBoxContainer.new()
	panel.add_child(v)
	add_child(win)
	return [win, v]

## The roles list: every gift with its icon and what it does, and who has claimed it.
func _open_roles() -> void:
	for ch in roles_box.get_children():
		ch.queue_free()
	var ink = UITheme.color("ink")
	for group in [["Gifts of the town", C.GOOD_ROLES], ["The demon's side", ["demon", "poisoner"]]]:
		var h = Label.new()
		h.text = group[0]
		h.add_theme_font_size_override("font_size", 19)
		h.add_theme_color_override("font_color", UITheme.color("red"))
		roles_box.add_child(h)
		for r in group[1]:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			roles_box.add_child(row)
			var ic = TextureRect.new()
			ic.texture = UITheme.tex("ui/roles/" + r, 0.12)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.custom_minimum_size = Vector2(40, 40)
			row.add_child(ic)
			var col = VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col)
			var nm = Label.new()
			nm.text = C.role_name(r)
			nm.add_theme_font_size_override("font_size", 17)
			nm.add_theme_color_override("font_color", ink)
			col.add_child(nm)
			var d = Label.new()
			d.text = C.ROLES[r]["desc"]
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.add_theme_font_size_override("font_size", 15)
			d.add_theme_color_override("font_color", UITheme.color("ink_soft"))
			col.add_child(d)
			var who: Array = []
			for n in g.w.npcs:
				if n.claimed_role == r and (n.claim_public or n.max_tier >= 3):
					who.append("%s (%s)" % [n.name, "to the town" if n.claim_public else "told you"])
			if not who.is_empty():
				var c2 = Label.new()
				c2.text = "Claimed by: " + ", ".join(PackedStringArray(who))
				c2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				c2.add_theme_font_size_override("font_size", 14)
				c2.add_theme_color_override("font_color", UITheme.color("red").darkened(0.2))
				col.add_child(c2)
	if not roles_win.visible:
		roles_win.popup_centered()

func _on_more(i: int) -> void:
	if i == 0:
		_run("cast")
	elif i == 1:
		_run("timeline")
	elif i == 2:
		side.visible = not side.visible
	elif i == 3:
		_run("log")

func _open_notes() -> void:
	notes_edit.text = g.case_notes
	notes_win.popup_centered()

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
	var meeting = g.state in ["meeting", "nomination"]
	map.visible = not meeting
	meeting_view.visible = meeting
	if meeting:
		meeting_view.refresh()
	else:
		meeting_view.finish()
	map.refresh()
	cast_list.refresh()
	var night = g.state == "night"
	day_icon.texture = UITheme.tex("ui/moon" if night else "ui/sun", 0.15)
	day_label.text = ("Night %d" % g.w.day) if night else ("Day %d · %s" % [g.w.day, "Town meeting" if g.state in ["meeting", "nomination"] else C.PHASES[g.w.phase]])
	if case_view.visible:
		case_view.refresh()

## Show this person's profile in the sidebar and the case view.
func _side_person_id() -> String:
	return profile.current()

func _select_person(id: String) -> void:
	case_state.select_person(id)
	profile.show_person(id)
	cast_list.selected = id
	cast_list.refresh()
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

func _id_for(name: String) -> String:
	for n in C.CAST:
		if n["name"] == name:
			return n["id"]
	return ""

## An inline icon for the log, if the art is there.
func _icon(rel: String, h: int) -> String:
	var path = "res://assets/" + rel + ".png"
	return ("[img height=%d]%s[/img] " % [h, path]) if ResourceLoader.exists(path) else ""

var _tag_re: RegEx

## Plain text from the game -> BBCode: speech lines in the speaker's colour with their
## portrait, names coloured wherever they appear, icons for day headers, deaths and new
## case-board cards.
func _colourize(s: String) -> String:
	if _tag_re == null:
		_tag_re = RegEx.new()
		_tag_re.compile("\\[lb\\]case board: ([^\\]]*)\\]")
	var lines = PackedStringArray()
	for line in s.split("\n"):
		var esc = line.replace("[", "[lb]")
		esc = _tag_re.sub(esc, "[color=#8a8f99]%s$1[/color]" % _icon("ui/cards/card_04", 14), true)
		var m = _speech_re.search(esc)
		if m != null:
			var hex = _hex_for(m.get_string(2))
			lines.append("%s%s[color=#%s][b]%s[/b]: %s[/color]" % [m.get_string(1), _icon("art/portraits/" + _id_for(m.get_string(2)), 24), hex, m.get_string(2), m.get_string(3)])
			continue
		if line.begins_with("=== "):
			var ic = "ui/moon" if "Night" in line else ("ui/wax_seal" if "meeting" in line else "ui/sun")
			lines.append("%s[color=#%s][b]%s[/b][/color]" % [_icon(ic, 20), UITheme.color("accent").to_html(false), esc.trim_prefix("=== ").trim_suffix(" ===")])
			continue
		if "was killed" in line:
			esc = _icon("ui/raven", 20) + esc
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
	action_title.text = "Talking with %s · %d question%s left" % [n.name, g.questions_left, "" if g.questions_left == 1 else "s"]
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
	l.add_theme_font_size_override("font_size", 15)
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
		# Whom to speak for or against only matters once you pick one of those.
		who.visible = false
		mode.item_selected.connect(func(i): who.visible = i > 0)
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
	if g != null:
		profile.refresh()

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
