## In-engine UI. The town map (click places and people), a coloured log, a context-sensitive
## action panel (every command as buttons and menus), a profile panel, an optional case-board
## sidebar and the full-screen case view. Every click becomes the same text command the CLI
## uses, so the typed prompt still works as a fallback.
extends Control

const Game = preload("res://game/game.gd")
const C = preload("res://sim/content.gd")
const Mind = preload("res://sim/mind.gd")
const CaseView = preload("res://ui/case_view.gd")
const CardList = preload("res://ui/card_list.gd")
const EvidenceContext = preload("res://ui/evidence_context.gd")
const MapView = preload("res://ui/map_view.gd")
const MeetingView = preload("res://ui/meeting_view.gd")
const CaseState = preload("res://ui/case_state.gd")
const UITheme = preload("res://ui/theme.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const CastList = preload("res://ui/cast_list.gd")
const LogText = preload("res://ui/log_text.gd")
const FormattedTextLabel = preload("res://ui/formatted_text_label.gd")

var g
var out: RichTextLabel
var input: LineEdit
var seed_box: SpinBox
var size_opt: OptionButton
var side: VBoxContainer
var side_filter: LineEdit
var side_list
var profile                  # ui/profile_panel.gd: the same profile as on the case board
var side_profile: RichTextLabel:
	get: return profile.body
var case_view
var case_state = CaseState.new()   # view, filters and selection shared by every panel
var map
var map_stage: Control
var conversation_view
var conversation_show_map = false
var conversation_finished = false
var meeting_view
var actions: Container
var action_title: Label
var popup: PopupPanel
var mono: SystemFont
var history: Array = []
var hist_i = 0
var theory_label: Label
var roll_window
var roll_button: Button
var debug_check: CheckBox
var day_icon: TextureRect
var day_label: Label
var cast_list                # ui/cast_list.gd
var cast_header: Label
var meeting_show_map = false # during a meeting, peek at the map instead of the circle
var _popup_anchor = null
var _case_seed = -1
var show_script_at_start = true   # the script opens when a case begins
var _last_state = ""
var _ward_target = ""       # choosing a night action does not own map highlighting
var notes_win: Window
var notes_edit: TextEdit
var roles_win: Window
var roles_box: VBoxContainer
var roles_pinned = false # Session preference; never saved with game/settings.
var roles_showing = false
var _roles_signature = ""
var roles_dock: PanelContainer
var roles_content: VBoxContainer
var roles_window_box: VBoxContainer
var roles_pin: CheckBox
var log_text = LogText.new()
var new_case_confirm: ConfirmationDialog

var headlines

func _consume_headlines() -> void:
	for event in g.last_events:
		if event.k == "headline":
			headlines.enqueue(event)

func _ready() -> void:
	preload("res://ui/column_menus.gd").watch(self)
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
	size_opt = OptionButton.new()
	size_opt.add_item("7 townsfolk")
	size_opt.set_item_metadata(0, 7)
	size_opt.add_item("10 townsfolk")
	size_opt.set_item_metadata(1, 10)
	size_opt.tooltip_text = "Town size for the next case: 7 (one minion) or 10 (two minions)."
	top.add_child(size_opt)
	var more = MenuButton.new()
	more.text = "More ▾"
	more.flat = false
	var mp: PopupMenu = more.get_popup()
	# Ids are fixed per entry so reordering the menu never changes what an id does.
	for it in [["New case…", MoreItem.NEW_CASE], ["Cast (text)", MoreItem.CAST], ["Timeline (text)", MoreItem.TIMELINE],
			["Card list sidebar", MoreItem.SIDEBAR], ["Write dev log", MoreItem.LOG], ["Case Workshop", MoreItem.WORKSHOP]]:
		mp.add_item(it[0], it[1])
	new_case_confirm = ConfirmationDialog.new()
	new_case_confirm.title = "New case"
	new_case_confirm.dialog_text = "Start a new case? The current case and its board will be lost."
	new_case_confirm.ok_button_text = "Start new case"
	new_case_confirm.confirmed.connect(_new_case_button)
	add_child(new_case_confirm)
	mp.id_pressed.connect(_on_more)
	top.add_child(more)
	debug_check = CheckBox.new()
	debug_check.text = "Debug"
	debug_check.tooltip_text = "Show what NPCs privately make of each card and person (influence, credibility, suspicion). Turning it on mid-case leaves your identification unscored."
	debug_check.toggled.connect(func(on):
		g.set_debug_overlay(on)
		roll_button.visible = on
		if not on: roll_window.hide()
		_refresh_all())
	top.add_child(debug_check)
	roll_window = preload("res://ui/decision_window.gd").new()
	roll_window.theme = theme
	add_child(roll_window)
	roll_button = Button.new()
	roll_button.text = "Rolls"
	roll_button.tooltip_text = "Live NPC decisions: stats, sampled draws, thresholds and chance estimates"
	roll_button.visible = false
	roll_button.pressed.connect(func():
		if g.debug_overlay:
			roll_window._refresh()
			roll_window.popup_centered())
	top.add_child(roll_button)
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
	map_stage = Control.new()
	map_stage.custom_minimum_size = Vector2(500, 300)
	map_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_stage.clip_contents = true
	upper.add_child(map_stage)
	map = MapView.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.clicked.connect(_on_map_clicked)
	map_stage.add_child(map)
	conversation_view = preload("res://ui/day_conversation_view.gd").new()
	conversation_view.visible = false
	map_stage.add_child(conversation_view)
	# While the town meets, the meeting circle takes the map's place.
	meeting_view = MeetingView.new()
	meeting_view.custom_minimum_size = Vector2(500, 300)
	meeting_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meeting_view.visible = false
	meeting_view.person_clicked.connect(func(id): _select_person(id))
	upper.add_child(meeting_view)
	var castbox = VBoxContainer.new()
	castbox.custom_minimum_size = Vector2(330, 0)
	upper.add_child(castbox)
	var ch = Label.new()
	cast_header = ch
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
	cast_list.person_clicked.connect(_on_town_person_clicked)
	csc.add_child(cast_list)
	profile = ProfilePanel.new(true)
	profile.build()
	profile.custom_minimum_size = Vector2(360, 0)
	profile.person_changed.connect(func(id): case_view.show_profile(id))
	profile.changed.connect(func():
		theory_label.text = g.theory_status()
		cast_list.refresh())
	profile.card_clicked.connect(func(n):
		_open_case_view()
		case_view.reveal(n)
		case_state.select_card(n)
		case_view.board.fit_selection())
	profile.card_context_requested.connect(func(n, at): case_view.show_card_menu(n, at))
	upper.add_child(profile)
	roles_dock = PanelContainer.new()
	roles_dock.custom_minimum_size.x = 360
	roles_dock.add_theme_stylebox_override("panel", UITheme.panel("paper"))
	roles_dock.hide()
	upper.add_child(roles_dock)

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
	out = FormattedTextLabel.new()
	out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	out.custom_minimum_size = Vector2(0, 160)
	out.scroll_following = true
	out.selection_enabled = true
	out.bbcode_enabled = true
	UITheme.rich_text_fonts(out, mono)
	out.hint_underlined = false
	out.add_theme_font_size_override("normal_font_size", 16)
	out.meta_clicked.connect(func(meta):
		var m = str(meta)
		if m.begins_with("card:"):
			_open_case_view()
			case_view.reveal(int(m.substr(5)))
			case_state.select_card(int(m.substr(5)))
			case_view.board.fit_selection())
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
	side.custom_minimum_size = Vector2(320, 0)
	side.visible = true
	lower.add_child(side)
	var st = Label.new()
	st.text = "Case board (newest first)"
	side.add_child(st)
	side_filter = LineEdit.new()
	side_filter.placeholder_text = "filter: person, place, kind, d2, n1, text; join with + (greta+night)"
	side_filter.text_changed.connect(func(_t): _refresh_side())
	side.add_child(side_filter)
	side_list = CardList.new()
	side_list.select_mode = Tree.SELECT_ROW
	side_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_list.readable(15)
	side_list.card_activated.connect(_on_side_activated)
	side_list.card_context_requested.connect(func(n, at): case_view.show_card_menu(n, at))
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
	var rwin = _make_window("The script: what may be in play", Vector2i(1120, 960))
	roles_win = rwin[0]
	roles_window_box = rwin[1]
	roles_content = VBoxContainer.new()
	roles_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roles_window_box.add_child(roles_content)
	var role_controls = HBoxContainer.new()
	roles_content.add_child(role_controls)
	roles_pin = CheckBox.new()
	roles_pin.text = "Pin as side panel"
	for colour in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		roles_pin.add_theme_color_override(colour, UITheme.color("ink"))
	roles_pin.tooltip_text = "Keep Roles beside the town profile for this session. From the case board, Roles still opens as a window."
	roles_pin.toggled.connect(_set_roles_pinned)
	role_controls.add_child(roles_pin)
	_button(role_controls, "Hide", _hide_roles)
	roles_win.close_requested.connect(_hide_roles)
	var rsc = ScrollContainer.new()
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roles_content.add_child(rsc)
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
	case_view.workshop_execute = _run_workshop
	case_view.build(mono)
	case_view.changed.connect(_refresh_side)
	case_view.notes_requested.connect(_open_notes)
	case_view.roles_requested.connect(_open_roles)
	case_view.visibility_changed.connect(func():
		if not case_view.visible and roles_pinned and roles_showing:
			_open_roles())
	case_view.workshop_requested.connect(_open_live_workshop)

	var headline_layer = CanvasLayer.new()
	headline_layer.layer = 30
	add_child(headline_layer)
	headlines = preload("res://ui/headline_overlay.gd").new()
	headline_layer.add_child(headlines)
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

## New case from the button: a fresh seed, unless you've typed one in since this case began.
func _new_case_button() -> void:
	if int(seed_box.value) == _case_seed:
		seed_box.value = randi() % 100000
	_new_case()

func _new_case() -> void:
	if g != null and (g.workshop_presenting or g.meeting_streaming()):
		return
	conversation_finished = false
	conversation_show_map = false
	_case_seed = int(seed_box.value)
	case_state.select_card(0)
	g = Game.new()
	g.debug_overlay = debug_check.button_pressed
	g.decision_feed.console = roll_window.mirror.button_pressed
	headlines.clear()
	g.stream_meeting = true
	out.clear()
	_print(g.new_case(int(seed_box.value), int(size_opt.get_item_metadata(size_opt.selected))))
	_consume_headlines()
	case_view.set_game(g)
	profile.setup(g, case_state)
	cast_list.setup(g)
	notes_edit.text = g.case_notes
	map.set_game(g)
	_ward_target = ""
	meeting_view.set_game(g)
	if debug_check.button_pressed:
		g.set_debug_overlay(true)
	roll_window.set_feed(g.decision_feed)
	roll_button.visible = debug_check.button_pressed
	_refresh_all()
	if is_inside_tree() and show_script_at_start:
		_open_roles()

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

## The roles list (the script, as in Clocktower): the town's gifts on the left; the demon's
## side and the secrets on the right. Each with its icon, what it does, and who has claimed it.
static func setup_summary(count: int) -> String:
	# Setup rules count secrets, not holders; a pair of Lovers is one secret.
	var rules: Dictionary = C.SETUPS.get(count, {"town": count - 2, "minions": 1, "secrets": 1})
	return "Good: %d gifted townsfolk / %d secret%s · Evil: %d minion%s / 1 demon" % [rules.town, rules.secrets, "" if rules.secrets == 1 else "s", rules.minions, "" if rules.minions == 1 else "s"]

func _set_roles_pinned(on: bool) -> void:
	roles_pinned = on
	roles_pin.set_pressed_no_signal(on)
	_open_roles()

func _hide_roles() -> void:
	roles_showing = false
	roles_win.hide()
	if roles_pinned and roles_content.get_parent() != roles_dock:
		roles_content.reparent(roles_dock)
		_build_roles(true)
	roles_dock.hide()

func _open_roles() -> void:
	roles_showing = true
	var embedded: bool = roles_pinned and not case_view.visible
	var host = roles_dock if embedded else roles_window_box
	if roles_content.get_parent() != host: roles_content.reparent(host)
	_build_roles(embedded)
	roles_dock.visible = embedded
	if embedded:
		roles_win.hide()
	elif not roles_win.visible:
		roles_win.popup_centered()

func _roles_state_key() -> String:
	return JSON.stringify([g.w.n_npcs, g.w.minion_ids.size(), g.w.npcs.map(func(n): return [n.id, n.claimed_role, n.max_tier >= 3, n.claim_public])])

func _build_roles(embedded: bool) -> void:
	_roles_signature = _roles_state_key()
	for ch in roles_box.get_children():
		roles_box.remove_child(ch)
		ch.queue_free()
	var cols: BoxContainer = VBoxContainer.new() if embedded else HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roles_box.add_child(cols)
	var left = VBoxContainer.new()
	var right = VBoxContainer.new()
	for c in [left, right]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 6)
		cols.add_child(c)
	_roles_group(left, "Gifts of the town", C.GOOD_ROLES)
	_roles_group(right, "The demon's side: the demon and %d minion%s" % [g.w.minion_ids.size(), "" if g.w.minion_ids.size() == 1 else "s"], C.EVIL_ROLES)
	var night_rule = Label.new()
	night_rule.name = "DemonNightRule"
	night_rule.text = C.DEMON_NIGHT_RULE
	night_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	night_rule.add_theme_color_override("font_color", UITheme.color("ink"))
	right.add_child(night_rule)
	_roles_group(right, "Secrets: one in play, on top of a gift", C.SECRET_MOD_LIST)
	var summary = Label.new()
	summary.name = "SetupSummary"
	summary.text = setup_summary(g.w.n_npcs)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", UITheme.color("ink"))
	roles_box.add_child(summary)
	var bottom_pad = Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 12)
	roles_box.add_child(bottom_pad)

func _roles_group(box: VBoxContainer, title: String, roles: Array) -> void:
	var ink = UITheme.color("ink")
	var h = Label.new()
	h.text = title
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_size_override("font_size", 18)
	h.add_theme_color_override("font_color", UITheme.color("red"))
	box.add_child(h)
	for r in roles:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var ic = TextureRect.new()
		var rt = UITheme.tex("ui/roles/" + r, 0.1)
		ic.texture = rt if rt != null else UITheme.tex("ui/roles/unknown", 0.1)  # icons for new gifts still to come
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(34, 34)
		row.add_child(ic)
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var nm = Label.new()
		nm.text = C.role_name(r)
		nm.add_theme_font_size_override("font_size", 16)
		nm.add_theme_color_override("font_color", ink)
		col.add_child(nm)
		var d = Label.new()
		d.text = C.ROLES[r]["desc"] if C.ROLES.has(r) else C.SECRET_MODS[r]["desc"]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_size_override("font_size", 14)
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
			c2.add_theme_font_size_override("font_size", 13)
			c2.add_theme_color_override("font_color", UITheme.color("red").darkened(0.2))
			col.add_child(c2)

enum MoreItem { CAST, TIMELINE, SIDEBAR, LOG, WORKSHOP, NEW_CASE }

func _on_more(i: int) -> void:
	match i:
		MoreItem.CAST:
			_run("cast")
		MoreItem.TIMELINE:
			_run("timeline")
		MoreItem.SIDEBAR:
			side.visible = not side.visible
		MoreItem.LOG:
			_run("log")
		MoreItem.WORKSHOP:
			_open_live_workshop()
		MoreItem.NEW_CASE:
			if g == null or g.w.game_over:
				_new_case_button()
			else:
				new_case_confirm.popup_centered()

## The Case Workshop lives on the case board as a pull-out sheet.
func _open_live_workshop(number: int = 0) -> void:
	case_view.refresh()
	case_view.open_workshop(number)

func _run_workshop(cmd: String, progress: Callable) -> void:
	if conversation_finished:
		return
	var previous_state = g.state
	_print("\n> " + cmd)
	_print(await g.workshop_command(cmd, progress))
	_capture_conversation(previous_state, cmd)
	if not conversation_finished:
		_consume_headlines()
	if g.state == "talk" and g.talk_with != null:
		_select_person(g.talk_with.id)
	_refresh_all()

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
	if conversation_finished:
		return
	var previous_state = g.state
	_print("\n> " + cmd)
	_print(g.command(cmd))
	_capture_conversation(previous_state, cmd)
	if not conversation_finished:
		_consume_headlines()
	if g.meeting_streaming() and not conversation_finished:
		_stream_meeting()
		return
	if g.state == "talk" and g.talk_with != null:
		_select_person(g.talk_with.id)
	_refresh_all()
	if case_view.visible and case_view.workshop != null:
		case_view.workshop.refresh()

func _capture_conversation(previous_state: String, cmd: String) -> void:
	if g.state == "talk" and g.talk_with != null:
		if previous_state != "talk" or conversation_view.person_id != g.talk_with.id:
			conversation_show_map = false
			conversation_view.begin(g.talk_with.id, g.talk_with.name)
		conversation_view.consume(g.last_events)
	elif previous_state == "talk":
		conversation_view.consume(g.last_events)
		var verb = cmd.strip_edges().get_slice(" ", 0).to_lower()
		if not verb in ["bye", "leave", "done"]:
			conversation_finished = true
			conversation_show_map = false

func _leave_finished_conversation() -> void:
	conversation_finished = false
	_consume_headlines()
	if g.meeting_streaming():
		_stream_meeting()
	else:
		_refresh_all()

## Several commands from one click (e.g. walk to someone, then talk to them).
func _run_seq(cmds: Array) -> void:
	for c in cmds:
		var before = g.state
		_run(c)
		if g.meeting_streaming():
			break
		if g.state == "over" or (before == g.state and g.last_events.any(func(e): return e.get("k", "") == "error")):
			break

## The meeting's testimony, one speaker at a time: each speaker's lines show while the next
## is worked out. Actions wait until the town has spoken.
const STREAM_GAP = 0.15   # seconds between speakers, at least (the work itself takes longer)

func _stream_meeting() -> void:
	_refresh_all()
	while g.meeting_streaming():
		await get_tree().process_frame
		var started: int = Time.get_ticks_msec()
		var text: String = g.testimony_step()
		if text != "":
			_print(text)
		_consume_headlines()
		meeting_view.refresh()
		var left: float = STREAM_GAP - (Time.get_ticks_msec() - started) / 1000.0
		if left > 0.0:
			await get_tree().create_timer(left).timeout
	_refresh_all()
	if case_view.visible and case_view.workshop != null:
		case_view.workshop.refresh()

## Finish a streamed meeting at once (tests and scripted clicks that can't wait).
func finish_streaming() -> void:
	while g != null and g.meeting_streaming():
		var text: String = g.testimony_step()
		if text != "":
			_print(text)
		_consume_headlines()
	_refresh_all()

var _last_phase_key = ""

func _refresh_all() -> void:
	if roles_pinned and roles_showing and _roles_signature != _roles_state_key():
		_build_roles(roles_content.get_parent() == roles_dock)
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
	if not meeting or (g.state == "nomination" and _last_state != "nomination") or (g.state == "meeting" and _last_state == "nomination"):
		meeting_show_map = false  # a vote starting (or being counted) brings the circle back
	_last_state = g.state
	map_stage.visible = conversation_finished or not meeting or meeting_show_map
	conversation_view.visible = conversation_finished or (g.state == "talk" and not conversation_show_map)
	meeting_view.visible = meeting and not meeting_show_map and not conversation_finished
	input.editable = not conversation_finished
	if meeting:
		meeting_view.refresh()
	else:
		meeting_view.finish()
	map.refresh()
	cast_list.refresh()
	cast_header.text = "Townsfolk · %d alive" % g.w.living().size()
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
	case_view.show_profile(id)
	_refresh_profile()

func _on_town_person_clicked(id: String) -> void:
	var selected: String = "" if cast_list.selected == id else id
	cast_list.selected = selected
	map.selected_npc = selected
	if selected != "":
		_select_person(selected)
	cast_list.refresh()
	map.refresh()
	if g.state == "night":
		_ward_target = selected
	if g.state in ["day", "night"]: _refresh_actions()

# ---------------------------------------------------------------- coloured log

func _print(s: String) -> void:
	log_text.append_to(out, s)

func _swatch(c: Color) -> ImageTexture:
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- map clicks

func _on_map_clicked(kind: String, id: String) -> void:
	if kind == "npc":
		_select_person(id)
		if g.state == "day": _refresh_actions()
		if g.state == "night":
			_ward_target = id
	match g.state:
		"day":
			var w = g.w
			match kind:
				"block", "back":
					_refresh_actions()
				"location", "scene":
					if not g.moved:
						_run("go " + id)
					elif id != g.loc and w.loc_block(id) == w.loc_block(g.loc) and not g.free_move_used:
						_run("go " + id)
					elif id != g.loc:
						_print("(You've already chosen where to spend this phase.)")
				"home":
					var hn = w.by_id[id]
					if not (hn.alive and hn.at_home()):
						_print("(Nobody's home at %s's just now. You can only call on someone who's in.)" % hn.name)
					elif not g.moved or (not g.free_move_used and w.loc_block("home_" + id) == w.loc_block(g.loc)):
						_run("go " + id)
					else:
						_print("(%s is in, but you've already chosen where to spend this phase.)" % hn.name)

		"night":
			_refresh_actions()
	map.refresh()

# ---------------------------------------------------------------- action panel

func _refresh_actions() -> void:
	for ch in actions.get_children():
		actions.remove_child(ch)
		ch.queue_free()
	for ch in conversation_view.controls.get_children():
		conversation_view.controls.remove_child(ch)
		ch.queue_free()
	if g == null:
		return
	var w = g.w
	if conversation_finished:
		action_title.text = "Conversation finished"
		_button(conversation_view.controls, "Leave conversation", _leave_finished_conversation)
		return
	if g.meeting_streaming():
		action_title.text = "Day %d: the town meeting" % w.day
		_hint("The town is speaking…")
		return
	match g.state:
		"day":
			_actions_day(w)
		"approach":
			action_title.text = ("%s wants a word." % g.approach["npc"].name) if g.approach.has("npc") else "Someone wants a word."
			match g.approach.get("agenda", ""):
				"protect":
					var pk: String = Mind.protection_kind(w, g.approach["npc"])
					_button(actions, "Promise it: %s (free)" % ("your ward on their door (%s; promise does not spend it)" % _ward_remaining() if pk == "ward" else "a vigil tonight"), func(): _run("yes"))
					_button(actions, "Say no", func(): _run("no"))
				"divulge":
					_button(actions, "Keep talking (uses this phase)", func(): _run("accept"))
					_button(actions, "Go on your way", func(): _run("decline"))
				_:
					_button(actions, "Hear them out (uses this phase)", func(): _run("accept"))
					_button(actions, "Wave them off", func(): _run("decline"))
		"talk":
			_button(actions, "Look at conversation" if conversation_show_map else "Look at the map", func():
				conversation_show_map = not conversation_show_map
				_refresh_all())
			if conversation_show_map:
				_actions_talk(w)
			else:
				var lower_actions = actions
				actions = conversation_view.controls
				_actions_talk(w)
				actions = lower_actions
		"meeting":
			action_title.text = "Day %d: the town meeting" % w.day
			if not g.presented_today and g.board.any(func(c): return c.kind in ["ward", "scorched_sigil"] and not c.get("deleted", false)):
				_button(actions, "Show your ward or scorched sigil…", func(): _card_picker("Show the town a protection receipt", func(c): return c.kind in ["ward", "scorched_sigil"], func(num, _x): _run("present %d" % num), false))
			_map_toggle()
			_button(actions, "Let the town speak (wait)", func(): _run("wait"))
			if not g.presented_today:
				_button(actions, "Present a deduction to everyone…", func(): _card_picker("Present a deduction to the meeting",
					func(c): return c["kind"] == "deduction", func(num, _x): _run("present %d" % num), false))
			var nom = _button(actions, "Nominate…", func(): pass)
			nom.disabled = "player" in w.meeting.get("nominators", [])
			if nom.disabled:
				nom.tooltip_text = "No nominations remaining"
			nom.pressed.connect(func(): _people_picker(nom, "Nominate whom?", func(id): _run("nominate " + id), func(n): return w.can_nominate("player", n.id) == ""))
			var done = _button(actions, "Close the meeting", func(): _run("done"))
			done.disabled = not g.town_quiet
			if not g.town_quiet:
				done.tooltip_text = "Let the town speak first (wait) until nobody else rises."
		"nomination":
			var nm: Dictionary = w.meeting["pending"]
			action_title.text = "Vote on %s" % w.by_id[nm["nominee"]].name
			_map_toggle()
			_button(actions, "Vote to execute", func(): _run("vote yes"))
			_button(actions, "Vote to spare", func(): _run("vote no"))
			if not g.statement_used:
				_button(actions, "Speak against them…", func(): _card_picker("Accuse, citing a card (optional)",
					func(c): return true, func(num, _x): _run("accuse %d" % num if num > 0 else "accuse"), true))
				_button(actions, "Speak in their defence…", func(): _card_picker("Defend, citing a card (optional)",
					func(c): return true, func(num, _x): _run("defend %d" % num if num > 0 else "defend"), true))
			if w.tools["clemency"] > 0 and nm["by"] != "player":
				_button(actions, "Invoke Clemency (once per case)", func(): _run("clemency"))
		"night":
			action_title.text = "Night %d: your night work" % w.day
			# Tonight's promises first, so keeping your word is one click.
			if g.offer.has("ward") and w.tools["ward"] > 0:
				var wid: String = g.offer["ward"]
				_button(actions, "Keep your word: ward %s's door (%s)" % [w.by_id[wid].name, _ward_remaining()], func(): _confirm_ward(wid), C.npc_color(wid))
			var vblocks = {}
			for id in g.offer.get("vigil", {}):
				vblocks[g.offer["vigil"][id]] = true
			for vb in vblocks:
				_button(actions, "Keep your word: vigil on %s" % C.block_name(vb), func(): _run("vigil " + vb))
			if not g.offer.is_empty():
				_hint("You promised %s." % g.offer_text())
			if map.selected_block != "":
				_button(actions, "Keep vigil on %s" % C.block_name(map.selected_block), func(): _run("vigil " + map.selected_block))
			if _ward_target != "" and w.tools["ward"] > 0 and w.by_id[_ward_target].alive:
				_button(actions, "Ward %s's door (%s)" % [w.by_id[_ward_target].name, _ward_remaining()], func(): _confirm_ward(_ward_target), C.npc_color(_ward_target))
			var vig = _button(actions, "Keep vigil on…", func(): pass)
			vig.pressed.connect(func(): _list_picker(vig, "Watch which block?", C.BLOCKS.keys().map(func(b): return [C.block_name(b), "vigil " + b, null])))
			if w.tools["ward"] > 0:
				var wd = _button(actions, "Ward someone… (%s)" % _ward_remaining(), func(): pass)
				wd.pressed.connect(func(): _people_picker(wd, "Ward whom?", func(id): _confirm_ward(id), func(n): return n.alive))
			_button(actions, "Sleep", func(): _run("sleep"))
			_hint("Tip: click a block or a person on the map to pick them.")
		"over":
			action_title.text = "The case is closed."
			_button(actions, "Show the grimoire", func(): _run("grimoire"))
			_button(actions, "Show every lie", func(): _run("grimoire lies"))
			_button(actions, "Show who told whom what", func(): _run("grimoire talk"))
			_button(actions, "New case", _new_case_button)

## Portraits inspect; this explicit action owns the existing go/talk sequence.
func _talk_to_person(id: String) -> void:
	if g.state != "day": return
	var n = g.w.by_id.get(id)
	if n == null or not g.can_see_ui(n): return
	var cmds: Array = []
	if not g.moved:
		# An approach discloses a destination even before ordinary block visibility.
		var destination: String = id if g.can_see(n) else g.approached_loc
		cmds.append("go " + destination)
	cmds.append("talk " + id)
	_run_seq(cmds)

func _actions_day(w) -> void:
	if not g.moved:
		action_title.text = "Day %d, %s: where will you go?" % [w.day, C.PHASES[w.phase].to_lower()]
		_hint("Click a block to look closer or a person to inspect their profile. Choose Talk to start a conversation.")
		var selected = w.by_id.get(_side_person_id())
		if selected != null and selected.alive and g.can_see_ui(selected):
			var talk = _button(actions, "Talk to %s" % selected.name, func(): _talk_to_person(selected.id), C.npc_color(selected.id))
			talk.disabled = selected.busy_with != ""
		if map.zoom_block != "" and C.BLOCKS.has(map.zoom_block):
			for l in C.LOCATIONS:
				if C.LOCATIONS[l]["block"] != map.zoom_block:
					continue
				var loc_id: String = l
				_button(actions, "Go to %s" % w.loc_name(loc_id), func(): _run("go " + loc_id))
			for sid in w.scenes:
				if w.scenes[sid].get("block", "") == map.zoom_block:
					var scene_id: String = sid
					_button(actions, "Go to %s (crime scene)" % w.scenes[scene_id]["name"], func(): _run("go " + scene_id))
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
	if not g.pending_request.is_empty():
		var rq: Dictionary = g.pending_request
		var ask: String = "Promise to keep it quiet" if rq["kind"] == "confidence" else (
			"Promise your ward on their door (%s; promise does not spend it)" % _ward_remaining() if rq.get("what", "") == "ward" else "Promise a vigil on %s tonight" % C.block_name(n.home_block))
		_button(actions, ask + " (free)", func(): _run("yes"), C.npc_color(n.id))
		_button(actions, "Say no (free)", func(): _run("no"))
		_hint("Anything else you do counts as no.")
	var gb = _button(actions, "Ask about their readings…  ▸" if n.max_tier >= 3 or n.claim_public else "Ask about %s's gift…  ▸" % n.name, func(): pass)
	gb.pressed.connect(func(): _ask_gift_picker(gb))
	var ob = _button(actions, "Offer…  ▸", func(): pass)
	ob.pressed.connect(func(): _offer_picker(ob))
	var wb = _button(actions, "Ask where they were and who they saw…  ▸", func(): pass)
	wb.pressed.connect(func(): _ask_when_picker(wb))
	var ab = _button(actions, "Ask about others…  ▸", func(): pass)
	ab.pressed.connect(func(): _ask_about_picker(ab))
	var asks: Dictionary = {"seer": "check", "warden": "guard", "nightwatch": "watch"}
	if (n.max_tier >= 3 or n.claim_public) and asks.has(n.claimed_role) and w.phase != C.NIGHT:
		var rb = _button(actions, "Ask them to use their gift tonight…  ▸", func(): pass)
		rb.pressed.connect(func(): _gift_request_picker(rb, n.claimed_role, asks[n.claimed_role]))
	for k in n.hints:
		if w.by_id[k].alive:
			# They hinted at a private reason at the meeting: ask them for it.
			_button(actions, "Ask why they suspect %s" % w.by_id[k].name, func(): _run("ask why"), C.npc_color(k))
			break
	_button(actions, "Present a card…", func(): _card_picker("Present a card to %s" % n.name, func(c): return true,
		func(num, extra): _run(("present %d" % num) + extra), false, true))
	_button(actions, "Leave", func(): _run("bye"))

## During the meeting: switch the top-left view between the meeting circle and the map.
func _map_toggle() -> void:
	_button(actions, "Back to the meeting" if meeting_show_map else "Look at the map", func():
		meeting_show_map = not meeting_show_map
		_refresh_all())

func _hint(t: String) -> void:
	var l = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	actions.add_child(l)

# ---------------------------------------------------------------- pickers

func _show_popup(content: Control, anchor: Control) -> void:
	# Clicking the same button again closes its menu.
	if popup.visible and anchor != null and anchor == _popup_anchor:
		popup.hide()
		_popup_anchor = null
		content.queue_free()
		return
	_popup_anchor = anchor
	var original_content = content
	content = preload("res://ui/column_menus.gd").balance(content)
	if content != original_content:
		original_content.queue_free()
	for ch in popup.get_children():
		popup.remove_child(ch)
		ch.queue_free()
	# Every menu gets its own close button (Esc works too).
	var wrap = VBoxContainer.new()
	var bar = HBoxContainer.new()
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var x = Button.new()
	x.text = "✕ Close"
	x.pressed.connect(func():
		popup.hide()
		_popup_anchor = null)
	bar.add_child(x)
	wrap.add_child(bar)
	wrap.add_child(content)
	content = wrap
	var pos = Vector2i(get_viewport_rect().size / 2.0)
	if anchor != null:
		# Embedded popup positions are in logical viewport units, not screen pixels.
		var origin = anchor.global_position if anchor.get_window().gui_embed_subwindows else anchor.get_screen_position()
		pos = Vector2i(origin) + Vector2i(0, int(anchor.size.y))
	preload("res://ui/column_menus.gd").fit_picker(popup, content, pos)

func _column(title: String) -> VBoxContainer:
	var v = VBoxContainer.new()
	var l = Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	v.add_child(l)
	return v

## "Ask about <them>'s gift…": what their gift is, or whether they hold a particular one.
func _ask_gift_picker(anchor: Control) -> void:
	var n = g.talk_with
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var qs = _column("Ask %s…" % n.name)
	_button(qs, "about their readings" if n.max_tier >= 3 or n.claim_public else "about their gift", func():
		popup.hide()
		_run("ask gift"))
	h.add_child(qs)
	var gifts = _column("…if they are the")
	for r in C.GOOD_ROLES:
		_button(gifts, C.role_name(r), func():
			popup.hide()
			_run("ask are " + C.role_name(r).to_lower()))
	h.add_child(gifts)
	_show_popup(h, anchor)

## "Offer…": your ward on their door tonight, or a vigil on their block.
func _ward_remaining() -> String:
	return "%d left, once per case" % g.w.tools["ward"]

func _confirm_ward(id: String) -> ConfirmationDialog:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "This spends your only ward. Ward %s?" % g.w.by_id[id].name
	add_child(dialog)
	dialog.confirmed.connect(func():
		_run("ward " + id)
		dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.popup_centered()
	return dialog

func _offer_picker(anchor: Control) -> void:
	var n = g.talk_with
	var v = _column("Offer %s…" % n.name)
	var wb = _button(v, "my ward on your door tonight (%s; promise only)" % _ward_remaining(), func():
		popup.hide()
		_run("offer ward"))
	wb.tooltip_text = "Promising does not spend your ward; keeping the promise does."
	wb.disabled = g.w.tools["ward"] <= 0 or g.offer.has("ward")
	if g.w.tools["ward"] <= 0:
		wb.tooltip_text = "Your ward is spent (once per case)."
	var vb = _button(v, "a vigil on %s tonight" % C.block_name(n.home_block), func():
		popup.hide()
		_run("offer vigil"))
	vb.disabled = g.offer.has("vigil")
	if not g.offer.is_empty():
		_hint_into(v, "You've promised tonight: %s." % g.offer_text())
	var open: Array = Mind.open_grievances(n)
	if not open.is_empty():
		var col = _column("Apologise for… (uses a question)")
		for i in range(open.size()):
			var idx: int = i + 1
			_button(col, Game.grievance_text(open[i]), func():
				popup.hide()
				_run("apologise %d" % idx))
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		h.add_child(v)
		h.add_child(col)
		_show_popup(h, anchor)
		return
	_show_popup(v, anchor)

## "Ask them to use their gift tonight…": whom a Seer looks at (one or two), whom a Warden
## guards, which block a Night Watch watches. Costs a question.
func _gift_request_picker(anchor: Control, role: String, verb: String) -> void:
	var n = g.talk_with
	var items: Array = []
	if role == "nightwatch":
		for b in C.BLOCKS.keys():
			items.append([C.block_name(b), "ask watch " + b, null])
	else:
		for m in g.w.living():
			if m != n:
				items.append([m.name, "ask %s %s" % [verb, m.id], C.npc_color(m.id)])
	var title = {"seer": "Ask %s to look at… (a question; for a pair, type 'ask check A, B')", "warden": "Ask %s to guard…", "nightwatch": "Ask %s to watch…"}[role] % n.name
	_list_picker(anchor, title, items)

## "Ask where they were and who they saw…": a time to ask about.
func _ask_when_picker(anchor: Control) -> void:
	var items: Array = [["…today", "ask seen today", null], ["…last night", "ask night", null]]
	if g.w.day > 1:
		for ph in [2, 1, 0]:
			items.append(["…yesterday %s" % C.PHASES[ph].to_lower(), "ask seen yesterday " + C.PHASES[ph].to_lower(), null])
	_list_picker(anchor, "Ask where they were and who they saw…", items)

func _hint_into(box: Control, t: String) -> void:
	var l = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(l)

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
	f.placeholder_text = "filter: person, place, kind, d2, n1, text; join with + (greta+night)"
	v.add_child(f)
	var lst = CardList.new()
	lst.card_context_requested.connect(func(n, at):
		popup.hide()
		case_view.show_card_menu(n, at))
	lst.select_mode = Tree.SELECT_ROW
	lst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lst.readable(14)
	v.add_child(lst)
	var fill = func():
		lst.reset()
		lst.context_numbers = EvidenceContext.numbers(g)
		var cs: Array = g.filter_cards(f.text)
		cs.reverse()  # newest first
		for c in cs:
			if keep.call(c):
				lst.add(CardList.line_for(c), c["n"], c["text"], CardList.color_for(c, Color(0.95, 0.8, 0.45) if c["kind"] == "deduction" else CardList.tint_for(c)))
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
	side_list.context_numbers = EvidenceContext.numbers(g)
	var cards: Array = g.filter_cards(side_filter.text)
	cards.reverse()
	for c in cards.slice(0, 60):
		var col = null
		if c.get("hidden", false):
			col = Color(0.45, 0.45, 0.5)
		elif c["kind"] == "deduction":
			col = Color(0.95, 0.8, 0.45)
		else:
			col = CardList.tint_for(c)
		var dbg = g.debug_card_text(c) if g.debug_overlay else ""
		side_list.add("%s%s" % [CardList.line_for(c), ("\n      ⟨" + dbg + "⟩") if dbg != "" else ""], c["n"], c["text"], CardList.color_for(c, col))
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
