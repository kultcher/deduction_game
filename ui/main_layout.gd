## The main screen's layout (ui/main.gd): the title bar, the map and its views, the townsfolk,
## the profile, the action pane and log, the card sidebar, and the notes and script windows.
## Built once by main's _ready; `m` is the main control, which keeps every widget and the state.
extends RefCounted

const CaseView = preload("res://ui/case_view.gd")
const CardList = preload("res://ui/card_list.gd")
const MapView = preload("res://ui/map_view.gd")
const MeetingView = preload("res://ui/meeting_view.gd")
const UITheme = preload("res://ui/theme.gd")
const NewCaseScreen = preload("res://ui/new_case_screen.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const CastList = preload("res://ui/cast_list.gd")
const FormattedTextLabel = preload("res://ui/formatted_text_label.gd")
const Roles = preload("res://ui/main_roles.gd")

static func build(m) -> void:
	preload("res://ui/column_menus.gd").watch(m)
	var bg = ColorRect.new()
	bg.color = UITheme.color("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_child(bg)

	m.mono = SystemFont.new()
	m.mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])
	m.theme = UITheme.make(m.mono)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	m.add_child(root)

	# Title bar: the day, the screens, and case controls.
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	m.day_icon = TextureRect.new()
	m.day_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m.day_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m.day_icon.custom_minimum_size = Vector2(30, 30)
	top.add_child(m.day_icon)
	var title = Label.new()
	title.text = "DEMONOLOGIST"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.color("accent"))
	top.add_child(title)
	m.day_label = Label.new()
	m.day_label.add_theme_font_size_override("font_size", 18)
	m.day_label.custom_minimum_size = Vector2(170, 0)
	top.add_child(m.day_label)
	var town_tab = m._button(top, "Town", func(): pass)
	town_tab.toggle_mode = true
	town_tab.button_pressed = true
	m._button(top, "Case board", m._open_case_view)
	m._button(top, "Notes", m._open_notes)
	m._button(top, "Roles", func(): Roles.open(m))
	m._button(top, "Help", func(): m._run("help"))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var lbl = Label.new()
	lbl.text = "Case"
	lbl.add_theme_color_override("font_color", UITheme.color("muted"))
	top.add_child(lbl)
	m.seed_box = SpinBox.new()
	m.seed_box.min_value = 1
	m.seed_box.max_value = 999999
	m.seed_box.value = NewCaseScreen.fresh_seed()
	top.add_child(m.seed_box)
	m.size_opt = OptionButton.new()
	m.size_opt.add_item("7 townsfolk")
	m.size_opt.set_item_metadata(0, 7)
	m.size_opt.add_item("10 townsfolk")
	m.size_opt.set_item_metadata(1, 10)
	m.size_opt.tooltip_text = "Town size for the next case: 7 (one minion) or 10 (two minions)."
	m.size_opt.visible = false
	top.add_child(m.size_opt)
	var more = MenuButton.new()
	more.text = "More ▾"
	more.flat = false
	var mp: PopupMenu = more.get_popup()
	# Ids are fixed per entry so reordering the menu never changes what an id does.
	for it in [["New case…", m.MoreItem.NEW_CASE], ["Cast (text)", m.MoreItem.CAST], ["Timeline (text)", m.MoreItem.TIMELINE],
			["Card list sidebar", m.MoreItem.SIDEBAR], ["Write dev log", m.MoreItem.LOG], ["Case Workshop", m.MoreItem.WORKSHOP], [m.DailyGuess.MENU_ENTRY, m.MoreItem.SUSPICIONS]]:
		mp.add_item(it[0], it[1])
	mp.id_pressed.connect(m._on_more)
	top.add_child(more)
	m.debug_check = CheckBox.new()
	m.debug_check.text = "Debug"
	m.debug_check.tooltip_text = "Show what NPCs privately make of each card and person (influence, credibility, suspicion). Turning it on mid-case leaves your identification unscored."
	m.debug_check.toggled.connect(func(on):
		m.g.set_debug_overlay(on)
		m.roll_button.visible = on
		if not on: m.roll_window.hide()
		m._refresh_all())
	top.add_child(m.debug_check)
	m.roll_window = preload("res://ui/decision_window.gd").new()
	m.roll_window.theme = m.theme
	m.add_child(m.roll_window)
	m.roll_button = Button.new()
	m.roll_button.text = "Rolls"
	m.roll_button.tooltip_text = "Live NPC decisions: stats, sampled draws, thresholds and chance estimates"
	m.roll_button.visible = false
	m.roll_button.pressed.connect(func():
		if m.g.debug_overlay:
			m.roll_window._refresh()
			m.roll_window.popup_centered())
	top.add_child(m.roll_button)
	m.theory_label = Label.new()
	m.theory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.theory_label.add_theme_color_override("font_color", UITheme.color("muted"))
	root.add_child(m.theory_label)

	# Top: the map, the townsfolk, the profile. Bottom: what you can do, beside the log.
	var body = VSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var upper = HBoxContainer.new()
	upper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upper.size_flags_stretch_ratio = 1.25
	upper.add_theme_constant_override("separation", 10)
	body.add_child(upper)
	m.map_stage = Control.new()
	m.map_stage.custom_minimum_size = Vector2(500, 300)
	m.map_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.map_stage.clip_contents = true
	upper.add_child(m.map_stage)
	m.map = MapView.new()
	m.map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.map.clicked.connect(m._on_map_clicked)
	m.map_stage.add_child(m.map)
	m.conversation_view = preload("res://ui/day_conversation_view.gd").new()
	m.conversation_view.visible = false
	m.map_stage.add_child(m.conversation_view)
	m.map_return = Button.new()
	m.map_return.name = "MapReturn"
	m.map_return.visible = false
	m.map_return.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	m.map_return.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	m.map_return.offset_left = -10
	m.map_return.offset_right = -10
	m.map_return.offset_top = 10
	m.map_return.offset_bottom = 10
	m.map_return.pressed.connect(m._on_map_return)
	m.map_stage.add_child(m.map_return)
	# While the town meets, the meeting circle takes the map's place.
	m.meeting_view = MeetingView.new()
	m.meeting_view.custom_minimum_size = Vector2(500, 300)
	m.meeting_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.meeting_view.visible = false
	m.meeting_view.person_clicked.connect(func(id): m._select_person(id))
	# The log follows the stage, speaker by speaker; once nothing is left to show (last words
	# included), the actions come back.
	m.meeting_view.stage.logged.connect(m._log_events)
	m.meeting_view.settled.connect(func(): if m.g != null: m._refresh_all())
	upper.add_child(m.meeting_view)
	var castbox = VBoxContainer.new()
	castbox.custom_minimum_size = Vector2(330, 0)
	upper.add_child(castbox)
	var ch = Label.new()
	m.cast_header = ch
	ch.text = "Townsfolk"
	ch.add_theme_font_size_override("font_size", 18)
	ch.add_theme_color_override("font_color", UITheme.color("accent"))
	castbox.add_child(ch)
	var csc = ScrollContainer.new()
	csc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	castbox.add_child(csc)
	m.cast_list = CastList.new()
	m.cast_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.cast_list.person_clicked.connect(m._on_town_person_clicked)
	csc.add_child(m.cast_list)
	m.profile = ProfilePanel.new(true)
	m.profile.build()
	m.profile.custom_minimum_size = Vector2(360, 0)
	m.profile.person_changed.connect(func(id): m.case_view.show_profile(id))
	m.profile.changed.connect(func():
		m.theory_label.text = m.g.theory_status()
		m.cast_list.refresh())
	m.profile.card_clicked.connect(func(n):
		m._open_case_view()
		m.case_view.reveal(n)
		m.case_state.select_card(n)
		m.case_view.board.fit_selection())
	m.profile.card_context_requested.connect(func(n, at): m.case_view.show_card_menu(n, at))
	m.profile.profile_workshop_requested.connect(func(pid: String, facet: String):
		m._open_case_view()
		m.case_view.open_workshop_profile(pid, facet))
	upper.add_child(m.profile)
	m.roles_dock = PanelContainer.new()
	m.roles_dock.custom_minimum_size.x = 360
	m.roles_dock.add_theme_stylebox_override("panel", UITheme.panel("paper"))
	m.roles_dock.hide()
	upper.add_child(m.roles_dock)

	var lower = HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 10)
	body.add_child(lower)
	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 6)
	lower.add_child(right)
	m.action_title = Label.new()
	m.action_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.action_title.add_theme_font_size_override("font_size", 19)
	m.action_title.add_theme_color_override("font_color", UITheme.color("accent"))
	right.add_child(m.action_title)
	var asc = ScrollContainer.new()
	asc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(asc)
	m.actions = VBoxContainer.new()
	m.actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asc.add_child(m.actions)
	var logbox = VBoxContainer.new()
	logbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(logbox)
	var logpanel = PanelContainer.new()
	logpanel.add_theme_stylebox_override("panel", UITheme.panel("inset"))
	logpanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logbox.add_child(logpanel)
	m.out = FormattedTextLabel.new()
	m.out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.out.custom_minimum_size = Vector2(0, 160)
	m.out.scroll_following = true
	m.out.selection_enabled = true
	m.out.bbcode_enabled = true
	UITheme.rich_text_fonts(m.out, m.mono)
	m.out.hint_underlined = false
	m.out.add_theme_font_size_override("normal_font_size", 16)
	m.out.meta_clicked.connect(func(meta):
		var link = str(meta)
		if link.begins_with("card:"):
			m._open_case_view()
			m.case_view.reveal(int(link.substr(5)))
			m.case_state.select_card(int(link.substr(5)))
			m.case_view.board.fit_selection())
	logpanel.add_child(m.out)
	var bottom = HBoxContainer.new()
	logbox.add_child(bottom)
	m.input = LineEdit.new()
	m.input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.input.placeholder_text = "Or type a command (help lists them) and press Enter"
	m.input.add_theme_font_override("font", m.mono)
	m.input.text_submitted.connect(m._on_submit)
	m.input.gui_input.connect(m._on_input_key)
	bottom.add_child(m.input)
	m._button(bottom, "Send", func(): m._on_submit(m.input.text))

	# Optional card-list sidebar (More ▾).
	m.side = VBoxContainer.new()
	m.side.custom_minimum_size = Vector2(320, 0)
	m.side.visible = true
	lower.add_child(m.side)
	var st = Label.new()
	st.text = "Case board (newest first)"
	m.side.add_child(st)
	m.side_filter = LineEdit.new()
	m.side_filter.placeholder_text = "filter: person, place, kind, d2, n1, text; join with + (greta+night)"
	m.side_filter.text_changed.connect(func(_t): m._refresh_side())
	m.side.add_child(m.side_filter)
	m.side_sightings_check = m._day_sightings_check(func(): m._refresh_side())
	m.side.add_child(m.side_sightings_check)
	m.side_list = CardList.new()
	m.side_list.select_mode = Tree.SELECT_ROW
	m.side_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.side_list.readable(15)
	m.side_list.card_activated.connect(m._on_side_activated)
	m.side_list.card_context_requested.connect(func(n, at): m.case_view.show_card_menu(n, at))
	m.side.add_child(m.side_list)
	var hint = Label.new()
	hint.text = "Double-click a card to add its number to your command."
	hint.add_theme_font_size_override("font_size", 14)
	m.side.add_child(hint)
	m._button(m.side, "Open case board", m._open_case_view)

	# Case notes and the roles list: movable windows, reachable from both screens.
	var nwin = make_window(m, "Case notes", Vector2i(560, 480))
	m.notes_win = nwin[0]
	var nv: VBoxContainer = nwin[1]
	var nh = Label.new()
	nh.text = "Your notes on the case (saved as you type)"
	nh.add_theme_color_override("font_color", UITheme.color("ink"))
	nv.add_child(nh)
	m.notes_edit = TextEdit.new()
	m.notes_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	m.notes_edit.text_changed.connect(func():
		if m.g != null:
			m.g.case_notes = m.notes_edit.text)
	nv.add_child(m.notes_edit)
	var rwin = make_window(m, "The script: what may be in play", Vector2i(1160, 960), [22, 4, 18, 12])
	m.roles_win = rwin[0]
	m.roles_window_box = rwin[1]
	m.roles_content = VBoxContainer.new()
	m.roles_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.roles_window_box.add_child(m.roles_content)
	var role_controls = HBoxContainer.new()
	m.roles_content.add_child(role_controls)
	m.roles_pin = CheckBox.new()
	m.roles_pin.text = "Pin as side panel"
	for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		m.roles_pin.add_theme_color_override(colour, UITheme.color("ink"))
	m.roles_pin.tooltip_text = "Keep Roles beside the town profile for this session. From the case board, Roles still opens as a window."
	m.roles_pin.toggled.connect(func(on): Roles.set_pinned(m, on))
	role_controls.add_child(m.roles_pin)
	m._button(role_controls, "Hide", func(): Roles.hide(m))
	m.roles_win.close_requested.connect(func(): Roles.hide(m))
	var rsc = ScrollContainer.new()
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.roles_content.add_child(rsc)
	m.roles_box = VBoxContainer.new()
	m.roles_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.roles_box.add_theme_constant_override("separation", 8)
	rsc.add_child(m.roles_box)

	m.popup = PopupPanel.new()
	m.popup.add_theme_stylebox_override("panel", UITheme.panel("popup"))
	m.add_child(m.popup)

	m.case_view = CaseView.new()
	m.case_view.state = m.case_state
	m.case_state.selection_changed.connect(func():
		if m.case_state.selected_person != "" and m._side_person_id() != m.case_state.selected_person:
			m._select_person(m.case_state.selected_person))
	m.case_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.case_view.visible = false
	m.add_child(m.case_view)
	m.case_view.workshop_execute = m._run_workshop
	m.case_view.build(m.mono)
	m.case_view.changed.connect(m._refresh_side)
	m.case_view.notes_requested.connect(m._open_notes)
	m.case_view.roles_requested.connect(func(): Roles.open(m))
	m.case_view.visibility_changed.connect(func():
		if not m.case_view.visible and m.roles_pinned and m.roles_showing:
			Roles.open(m))
	m.case_view.workshop_requested.connect(m._open_live_workshop)

	var headline_layer = CanvasLayer.new()
	headline_layer.layer = 30
	m.add_child(headline_layer)
	m.headlines = preload("res://ui/headline_overlay.gd").new()
	headline_layer.add_child(m.headlines)
	m.new_case_screen = NewCaseScreen.new()
	m.new_case_screen.hide()
	m.new_case_screen.start_requested.connect(m._on_new_case_start)
	m.add_child(m.new_case_screen)
	# Headless runs (tests, tools) and --quick-start skip the screen and deal a Default case.
	if DisplayServer.get_name() == "headless" or "--quick-start" in OS.get_cmdline_user_args():
		m._new_case()
	else:
		m.new_case_screen.case_seed = int(m.seed_box.value)
		m.new_case_screen.open(false, m.debug_check.button_pressed)

## A movable window on framed paper. Returns [window, content vbox].
## `inset` pads the content further in from the frame's corner leaves (left, top, right,
## bottom), for content that runs to the edges (the script's icons; Michael, Nov 19).
static func make_window(m, title: String, sz: Vector2i, inset: Array = []) -> Array:
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
	if inset.size() == 4:
		var pad = MarginContainer.new()
		for i in 4:
			pad.add_theme_constant_override(["margin_left", "margin_top", "margin_right", "margin_bottom"][i], int(inset[i]))
		panel.add_child(pad)
		pad.add_child(v)
	else:
		panel.add_child(v)
	m.add_child(win)
	return [win, v]
