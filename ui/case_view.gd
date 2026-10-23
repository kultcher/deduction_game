## Full-screen case board: filters, card library, the board (ui/board_view.gd), profiles,
## and the Link / Conclude builder. Reads the game's structured data directly.
extends PanelContainer

signal changed
signal notes_requested
signal roles_requested
signal workshop_requested(number: int)

const C = preload("res://sim/content.gd")
const Argue = preload("res://sim/argue.gd")
const CardList = preload("res://ui/card_list.gd")
const Metrics = preload("res://game/case_metrics.gd")
const CaseState = preload("res://ui/case_state.gd")
const UITheme = preload("res://ui/theme.gd")
const CardModel = preload("res://game/card_model.gd")
const BoardView = preload("res://ui/board_view.gd")
const DeductionTray = preload("res://ui/deduction_tray.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const BoardPanel = preload("res://ui/board_panel.gd")

var g
var mono: Font
var filter_edit: LineEdit
var kind_menu: MenuButton
var person_menu: MenuButton
var place_menu: MenuButton
var match_opt: OptionButton
## Shared view/filter/selection state (owned by the main screen; see ui/case_state.gd).
var state = CaseState.new()
var sel_kinds: Dictionary:
	get: return state.kinds
var sel_people: Dictionary:
	get: return state.people
var sel_places: Dictionary:
	get: return state.places
var status_label: Label
var chip_row: HFlowContainer
var card_list
var board                     # ui/board_view.gd
var tray                      # ui/deduction_tray.gd
var view_tabs: Array = []
var rows_btn: Button
var day_label: Label
var profile                   # ui/profile_panel.gd
var prof_opt: OptionButton:
	get: return profile.person_opt
var guess_opt: OptionButton:
	get: return profile.guess_opt
var theory_label: Label
var conf_opt: OptionButton:
	get: return profile.conf_opt
var result_text: RichTextLabel
var result_box: VBoxContainer
var hidden_check: CheckBox
var work_list
var staged: Array = []        # the working set: card numbers, kept across filters
var b_who: OptionButton
var b_verb: OptionButton
var b_status: OptionButton
var b_night: OptionButton
var b_because: Label
var b_preview: Label
var b_error: Label
var pending: Dictionary = {}  # explanation picked from a link: {conclusion, match, id}
var _setting = false
var canvas: Control
var panels: Dictionary = {}
var panel_buttons: Dictionary = {}
var _panels_placed = false
var _panel_layout_pending = false
var dock: HFlowContainer
var filter_bar: HBoxContainer
var clear_btn: Button
var card_menu: PopupMenu
var _context_card = 0
enum CardAction { ADD, HIDE, LINKS, HINTS, DELETE, UNPIN }


func _init() -> void:
	add_theme_stylebox_override("panel", UITheme.panel("panel"))

func build(font: Font) -> void:
	mono = font
	var bg = ColorRect.new()
	bg.color = UITheme.color("bg")
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	theory_label = Label.new()
	theory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	theory_label.add_theme_color_override("font_color", UITheme.color("muted"))

	# Three header rows: title, centered views, then shared filters and navigation.
	var heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	root.add_child(heading)
	var back_slot = HBoxContainer.new()
	back_slot.custom_minimum_size.x = 220
	back_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(back_slot)
	_btn(back_slot, "◀ Back to town", func(): visible = false)
	var title = Label.new()
	title.text = "Case Board"
	title.add_theme_color_override("font_color", UITheme.color("accent"))
	title.add_theme_font_size_override("font_size", 34)
	title.custom_minimum_size.y = 54
	heading.add_child(title)
	var balance = Control.new()
	balance.custom_minimum_size.x = 220
	balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(balance)
	var view_center = CenterContainer.new()
	root.add_child(view_center)
	var views = HBoxContainer.new()
	views.add_theme_constant_override("separation", 12)
	view_center.add_child(views)
	for v in CardModel.VIEWS:
		var vv: String = v
		var b = _btn(views, CardModel.VIEW_NAMES[v], func(): state.set_view(vv))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 20)
		b.set_meta("view", v)
		view_tabs.append(b)
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 18)
	root.add_child(controls)
	var filters = HFlowContainer.new()
	filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_theme_constant_override("h_separation", 6)
	controls.add_child(filters)
	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = "Search text, d2, n1, a+b ..."
	filter_edit.custom_minimum_size = Vector2(230, 0)
	filter_edit.text_changed.connect(func(t):
		state.text = t
		state.edited())
	filters.add_child(filter_edit)
	kind_menu = _multi(filters, "Kinds", sel_kinds)
	person_menu = _multi(filters, "People", sel_people)
	place_menu = _multi(filters, "Places", sel_places)
	match_opt = _option(filters, ["match any", "match all"], func(i):
		state.match_all = i == 1
		state.edited())
	match_opt.tooltip_text = "Any: match any selected filter. All: match each selected filter group. Applies to both cards and the grid."
	hidden_check = CheckBox.new()
	hidden_check.text = "Show hidden"
	hidden_check.toggled.connect(func(on):
		g.show_hidden = on
		_refresh_cards()
		changed.emit())
	rows_btn = _btn(filters, "Rows: places", func():
		state.rows_by = "person" if state.rows_by == "place" else "place"
		state.changed.emit())
	rows_btn.tooltip_text = "Places & sightings: arrange by place or person."
	clear_btn = _btn(filters, "Clear filters", _clear_filters)
	clear_btn.add_theme_stylebox_override("normal", UITheme.flat(UITheme.color("paper"), UITheme.color("border"), 2, 4, 6))
	clear_btn.add_theme_stylebox_override("hover", UITheme.flat(UITheme.color("paper").lightened(0.1), UITheme.color("border"), 2, 4, 6))
	for style in ["pressed", "hover_pressed"]:
		clear_btn.add_theme_stylebox_override(style, UITheme.flat(UITheme.color("red"), UITheme.color("border"), 2, 4, 6))
	filters.add_child(hidden_check)
	var navigation = HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_END
	controls.add_child(navigation)
	_btn(navigation, "◀", func(): _goto_day(board.day_in_view() - 1))
	day_label = Label.new()
	day_label.custom_minimum_size.x = 82
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_color_override("font_color", UITheme.color("accent"))
	navigation.add_child(day_label)
	_btn(navigation, "▶", func(): _goto_day(board.day_in_view() + 1))
	_btn(navigation, "Fit day", func(): _goto_day(board.day_in_view()))
	_btn(navigation, "Fit selection", func(): board.fit_selection())
	_btn(navigation, "Whole case", func(): board.fit_all())
	canvas = Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(420, 260)
	canvas.clip_contents = true
	root.add_child(canvas)
	canvas.resized.connect(_queue_panel_layout)
	# Independent bottom rows: removable filters, tool buttons, then deductions.
	filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 8)
	root.add_child(filter_bar)
	chip_row = HFlowContainer.new()
	chip_row.custom_minimum_size.y = 44
	chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_row.add_theme_constant_override("v_separation", 4)
	filter_bar.add_child(chip_row)
	status_label = Label.new()
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.custom_minimum_size.x = 270
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", UITheme.color("muted"))
	filter_bar.add_child(status_label)
	dock = HFlowContainer.new()
	dock.add_theme_constant_override("h_separation", 8)
	dock.add_theme_constant_override("v_separation", 4)
	root.add_child(dock)
	for entry in [["cards", "Card List"], ["work", "Build case"], ["profile", "Profile"]]:
		var key: String = entry[0]
		var toggle = _btn(dock, entry[1], func(): set_panel_open(key, not panels[key].visible))
		toggle.toggle_mode = true
		panel_buttons[key] = toggle
	_btn(dock, "Notes", func(): notes_requested.emit())
	_btn(dock, "Roles", func(): roles_requested.emit())
	card_menu = PopupMenu.new()
	card_menu.id_pressed.connect(_on_card_action)
	add_child(card_menu)
	state.changed.connect(func():
		_sync_menus()
		_refresh_cards())
	var cards_panel = _make_panel("cards", "Card List", Vector2(340, 700))

	# Library and builder have separate, initially minimized panels.
	var lib = VBoxContainer.new()
	lib.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_panel.content.add_child(lib)
	card_list = CardList.new()
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_list.custom_minimum_size = Vector2(0, 260)
	card_list.card_activated.connect(func(num): _stage([num]))
	card_list.card_context_requested.connect(show_card_menu)
	card_list.selection_changed.connect(func():
		var sel: Array = card_list.selected_metas()
		if not sel.is_empty():
			state.select_card(sel[0]))
	card_list.readable(15)
	lib.add_child(card_list)

	var work_panel = _make_panel("work", "Build case", Vector2(600, 760))
	var ws: VBoxContainer = work_panel.content
	ws.add_child(_heading("Working set"))
	var wl = Label.new()
	wl.text = "Drag cards here (or double-click them). They're what you link, and the 'because' of a conclusion."
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.add_theme_font_size_override("font_size", 14)
	wl.add_theme_color_override("font_color", UITheme.color("muted"))
	ws.add_child(wl)
	work_list = CardList.new()
	work_list.custom_minimum_size = Vector2(0, 110)
	work_list.accept_drops = true
	work_list.cards_dropped.connect(func(nums): _stage(nums))
	work_list.card_activated.connect(func(num): _unstage([num]))
	work_list.card_context_requested.connect(show_card_menu)
	work_list.add_theme_font_override("font", mono)
	work_list.add_theme_font_size_override("font_size", 14)
	ws.add_child(work_list)
	var wb = HFlowContainer.new()
	ws.add_child(wb)
	_btn(wb, "Remove", func(): _unstage(work_list.selected_metas()))
	_btn(wb, "Clear", func(): _unstage(staged.duplicate()))
	# What the working set suggests (updates as cards come and go).
	ws.add_child(_heading("What these cards suggest"))
	result_box = VBoxContainer.new()
	result_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ws.add_child(result_box)
	result_text = RichTextLabel.new()
	result_text.fit_content = true
	result_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_text.text = "Put one to three cards in the working set to see what they suggest: a contradiction, a corroboration or an inference."
	result_box.add_child(result_text)
	ws.add_child(_heading("Conclusion builder"))
	var brow = HFlowContainer.new()
	ws.add_child(brow)
	b_who = OptionButton.new()
	b_who.item_selected.connect(func(_i):
		_fill_status()
		_builder_changed())
	brow.add_child(b_who)
	b_verb = _option(brow, ["is", "is not", "should be"], func(_i):
		_fill_status()
		_builder_changed())
	b_status = OptionButton.new()
	b_status.item_selected.connect(func(_i): _builder_changed())
	brow.add_child(b_status)
	b_night = OptionButton.new()
	b_night.item_selected.connect(func(_i): _builder_changed())
	brow.add_child(b_night)
	b_because = Label.new()
	b_because.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ws.add_child(b_because)
	b_preview = Label.new()
	b_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_preview.add_theme_color_override("font_color", UITheme.color("deduction"))
	ws.add_child(b_preview)
	var frow = HBoxContainer.new()
	ws.add_child(frow)
	_btn(frow, "File deduction", _on_file)
	b_error = Label.new()
	b_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_error.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
	frow.add_child(b_error)

	board = BoardView.new()
	canvas.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.move_child(board, 0)
	board.view_changed.connect(_update_day_label)
	board.card_activated.connect(func(num): _stage([num]))
	board.card_context_requested.connect(show_card_menu)
	board.row_clicked.connect(func(kind, id):
		state.toggle(state.people if kind == "person" else state.places, id)
		if kind == "person" and board.board_view() != "statements":
			state.select_person(id)
			show_profile(id, true))
	board.person_context_requested.connect(_toggle_profile)
	tray = DeductionTray.new()
	tray.card_activated.connect(func(num): _stage([num]))
	tray.card_context_requested.connect(show_card_menu)
	root.add_child(tray)
	board.tooltip_text = "Drag the background to pan; wheel to zoom. Double-click a card to build a case. Open tools from the bottom dock; drag panel titles to move and bottom-right corners to resize."
	state.selection_changed.connect(func():
		board.queue_redraw()
		tray.queue_redraw())

	# The profile stays synchronized even while its panel is minimized.
	var profile_panel = _make_panel("profile", "Profile", Vector2(540, 800))
	profile_panel.content.add_child(theory_label)
	profile = ProfilePanel.new()
	profile.custom_minimum_size = Vector2(300, 0)
	profile.build()
	profile.card_context_requested.connect(show_card_menu)
	profile.changed.connect(func():
		theory_label.text = _theory_text()
		changed.emit())
	profile.card_clicked.connect(func(n):
		reveal(n)
		state.select_card(n)
		board.fit_selection())
	profile_panel.content.add_child(profile)
	_queue_panel_layout()

func _make_panel(key: String, title: String, initial_size: Vector2):
	var panel = BoardPanel.new()
	canvas.add_child(panel)
	panel.build(title)
	panel.size = initial_size
	panel.set_meta("initial_size", initial_size)
	panels[key] = panel
	panel.visibility_changed.connect(func(): panel_buttons[key].set_pressed_no_signal(panel.visible))
	return panel

func set_panel_open(key: String, on: bool) -> void:
	var panel = panels[key]
	if on:
		if not _panels_placed:
			_layout_panels()
			_panels_placed = true
		panel.fit_inside()
		panel.move_to_front()
	panel.visible = on

func _queue_panel_layout() -> void:
	if _panel_layout_pending:
		return
	_panel_layout_pending = true
	_layout_after_frame.call_deferred()

func _layout_after_frame() -> void:
	# Container sorting may briefly report only the canvas minimum height.
	await get_tree().process_frame
	await get_tree().process_frame
	_panel_layout_pending = false
	_layout_panels()

func _toggle_profile(id: String) -> void:
	if panels["profile"].visible and profile.current() == id:
		set_panel_open("profile", false)
	else:
		state.select_person(id)
		show_profile(id, true)

## All card surfaces share this menu. Actions target the clicked card, independently
## of older selections in the library or working set.
func show_card_menu(num: int, at: Vector2i) -> void:
	if g == null or num < 1 or num > g.board.size() or g.board[num - 1].get("deleted", false):
		return
	_context_card = num
	state.select_card(num)
	var card: Dictionary = g.board[num - 1]
	card_menu.clear()
	card_menu.add_item("Add to Deduction", CardAction.ADD)
	if card.kind != "deduction":
		card_menu.add_item("Add to Case Workshop", 100)
	card_menu.add_item("Unhide" if card.get("hidden", false) else "Hide", CardAction.HIDE)
	card_menu.add_item("Find Links", CardAction.LINKS)
	card_menu.add_item("Hints", CardAction.HINTS)
	if card.get("kind", "") == "deduction":
		if card.get("pins", {}).has(board.board_view()):
			card_menu.add_item("Unpin from board", CardAction.UNPIN)
		card_menu.add_separator()
		card_menu.add_item("Delete deduction", CardAction.DELETE)
	card_menu.popup(Rect2i(at, Vector2i.ZERO))

func _on_card_action(action: int) -> void:
	var num = _context_card
	card_menu.hide()
	if g == null or num < 1 or num > g.board.size() or g.board[num - 1].get("deleted", false):
		return
	if action == 100:
		workshop_requested.emit(num)
		return
	if action in [CardAction.ADD, CardAction.LINKS, CardAction.HINTS]:
		visible = true
	match action:
		CardAction.ADD:
			_stage([num])
		CardAction.HIDE:
			_hide_selected(not g.board[num - 1].get("hidden", false), [num])
		CardAction.LINKS:
			_find_links(num)
		CardAction.HINTS:
			_hint_selected(num)
		CardAction.DELETE:
			_delete_selected([num])
		CardAction.UNPIN:
			board.unpin(num)

func _layout_panels() -> void:
	if panels.size() < 3 or canvas.size.x <= 0 or canvas.size.y <= 0:
		return
	for panel in panels.values():
		# Hidden controls are sized before their containers finish the first layout.
		# Keep the intended defaults until a panel is actually opened by the player.
		if not _panels_placed:
			panel.size = panel.get_meta("initial_size")
		panel.fit_inside()
	if not _panels_placed:
		panels["cards"].move_to(Vector2(8, 8))
		panels["work"].move_to((canvas.size - panels["work"].size) / 2)
		panels["profile"].move_to(Vector2(canvas.size.x - panels["profile"].size.x - 8, 8))

func _heading(t: String) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_color_override("font_color", UITheme.color("accent"))
	l.add_theme_font_size_override("font_size", 15)
	return l

func _goto_day(d: int) -> void:
	board.fit_day(clampi(d, 0, g.w.day))
	_update_day_label()

func _update_day_label() -> void:
	if board != null and g != null:
		var d: int = clampi(board.day_in_view(), 0, g.w.day)
		day_label.text = "  Day %d  " % d if d > 0 else "  Night 0  "

func _option(parent: Node, items: Array, cb: Callable) -> OptionButton:
	var o = OptionButton.new()
	for x in items:
		o.add_item(x)
	o.item_selected.connect(cb)
	parent.add_child(o)
	return o

func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func set_game(game) -> void:
	card_menu.hide()
	_context_card = 0
	g = game
	for key in panels:
		set_panel_open(key, false)
	tray.set_open(false)
	board.setup(g, state)
	tray.setup(g, state)
	var pp: PopupMenu = person_menu.get_popup()
	pp.clear()
	state.people.clear()
	state.places.clear()
	state.kinds.clear()
	state.cell = {}
	b_who.clear()
	hidden_check.set_pressed_no_signal(g.show_hidden)
	for n in g.w.npcs:
		b_who.add_item(n.name)
		b_who.set_item_metadata(b_who.item_count - 1, n.id)
		pp.add_check_item(n.name)
		pp.set_item_metadata(pp.item_count - 1, n.id)
	b_who.add_item("One of these people")
	b_who.set_item_metadata(b_who.item_count - 1, "*group")
	var lp: PopupMenu = place_menu.get_popup()
	lp.clear()
	for b in C.BLOCKS:
		lp.add_check_item(C.block_name(b))
		lp.set_item_metadata(lp.item_count - 1, b)
	for l in C.LOCATIONS:
		lp.add_check_item("    " + C.loc_name(l))
		lp.set_item_metadata(lp.item_count - 1, l)
	profile.setup(g, state)
	_fill_kinds()
	_sync_menus()
	refresh()

func _theory_text() -> String:
	var t: String = g.theory_status()
	if not g.w.game_over:
		t += " — Set your guess in a profile before voting. No correctness feedback until the case ends."
	return t

func refresh() -> void:
	if g == null:
		return
	theory_label.text = _theory_text()
	_refresh_cards()
	_refresh_profile()
	_fill_nights()
	_refresh_work()
	if b_status.item_count == 0:
		_fill_status()
	_update_preview()

func open_theory() -> void:
	# Select the existing candidate or leave the ordinary first profile selected.
	var ids = Metrics.named_guesses(g.guesses, "demon")
	if not ids.is_empty():
		for i in range(prof_opt.item_count):
			if prof_opt.get_item_metadata(i) == ids[0]:
				prof_opt.select(i)
	_refresh_profile()
	set_panel_open("profile", true)
	guess_opt.grab_focus()

func _input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()

func _meta(o: OptionButton) -> String:
	if o.selected < 0:
		return ""
	var m = o.get_item_metadata(o.selected)
	return m if m != null else ""

## A checkable drop-down list feeding one of the filter sets.
func _multi(parent: Node, title: String, store: Dictionary) -> MenuButton:
	var mb = MenuButton.new()
	mb.text = title + " ▾"
	mb.flat = false
	var pm: PopupMenu = mb.get_popup()
	pm.hide_on_checkable_item_selection = false
	pm.id_pressed.connect(func(id):
		var i = pm.get_item_index(id)
		state.toggle(_store(title), pm.get_item_metadata(i)))
	parent.add_child(mb)
	return mb

func _store(title: String) -> Dictionary:
	return state.kinds if title == "Kinds" else state.people if title == "People" else state.places

## The kinds menu offers only what exists in the active view.
func _fill_kinds() -> void:
	var kp: PopupMenu = kind_menu.get_popup()
	kp.clear()
	for k in CardModel.VIEW_KINDS[state.view]:
		kp.add_check_item(k)
		kp.set_item_metadata(kp.item_count - 1, k)
	_fill_kinds_view = state.view

var _fill_kinds_view = ""

## Make sure card n can be seen: switch to the view it lives in, and drop the filters if
## they'd still hide it (used when a card is clicked from the town log).
func reveal(n: int) -> void:
	if n < 1 or n > g.board.size():
		return
	var card: Dictionary = g.board[n - 1]
	if card.get("kind", "") != "deduction" and not state.in_view(card):
		state.set_view(card.get("view", CardModel.view_of(card)))
	if card.get("hidden", false) and not g.show_hidden:
		g.show_hidden = true
	var shown: Array = state.apply(g).map(func(c): return c["n"])
	if card.get("kind", "") != "deduction" and not (n in shown):
		_clear_filters()
	refresh()

func _clear_filters() -> void:
	filter_edit.set_block_signals(true)
	filter_edit.text = ""
	filter_edit.set_block_signals(false)
	state.clear()

func _sync_menus() -> void:
	if _fill_kinds_view != state.view:
		_fill_kinds()
	if filter_edit.text != state.text:
		filter_edit.set_block_signals(true)
		filter_edit.text = state.text
		filter_edit.set_block_signals(false)
	match_opt.select(1 if state.match_all else 0)
	for pair in [[kind_menu, sel_kinds, "Kinds"], [person_menu, sel_people, "People"], [place_menu, sel_places, "Places"]]:
		var mb: MenuButton = pair[0]
		var store: Dictionary = pair[1]
		var pm: PopupMenu = mb.get_popup()
		for i in range(pm.item_count):
			pm.set_item_checked(i, store.has(pm.get_item_metadata(i)))
		mb.text = "%s%s ▾" % [pair[2], (" (%d)" % store.size()) if not store.is_empty() else ""]

func _visible_cards() -> Array:
	state.text = filter_edit.text
	state.match_all = match_opt.selected == 1
	return state.apply(g)

func _refresh_cards() -> void:
	var keep: Array = card_list.selected_metas()
	card_list.reset()
	var vis: Array = _visible_cards()
	_refresh_chips(vis.size())
	# Newest first, like the other card lists (the start-of-case home cards end up last).
	vis.reverse()
	# Your deductions head the list in every view ("My theories"), then the evidence.
	if state.view != "all":
		var theories: Array = g.filter_cards(state.text).filter(func(c): return c["kind"] == "deduction")
		theories.reverse()
		if not theories.is_empty():
			card_list.add_header("── My theories (%d) ──" % theories.size(), UITheme.color("deduction"))
			vis = theories + vis
	var first_evidence = true
	for c in vis:
		if state.view != "all" and c["kind"] != "deduction" and first_evidence:
			first_evidence = false
			card_list.add_header("── %s ──" % CardModel.VIEW_NAMES[state.view], UITheme.color("muted"))
		var line = ("[hidden] " if c.get("hidden", false) else "") + CardList.line_for(c)
		if g.debug_overlay:
			var dbg: String = g.debug_card_text(c)
			if dbg != "":
				line += "\n      ⟨" + dbg + "⟩"
		var col = null
		if c.get("hidden", false):
			col = Color(0.45, 0.45, 0.5)
		elif c["kind"] == "deduction":
			col = Color(0.95, 0.8, 0.45)
		else:
			col = CardList.tint_for(c)
		card_list.add(line, c["n"], "%s\n[%s, %s%s]" % [c["text"], c["kind"], c.get("class", "?"),
			"" if c.get("source", "") == "player" else ", heard"], CardList.color_for(c, col))
		if c["n"] in keep:
			card_list.select_meta(c["n"])
	_refresh_board()

func _refresh_board() -> void:
	if board == null or g == null:
		return
	for b in view_tabs:
		b.set_pressed_no_signal(b.get_meta("view") == board.board_view())
	rows_btn.text = "Rows: " + ("places" if state.rows_by == "place" else "people")
	rows_btn.visible = board.board_view() == "places"
	board.rebuild()
	tray.queue_redraw()
	_update_day_label()

func _refresh_chips(shown: int) -> void:
	status_label.text = state.status_text(g, shown)
	status_label.tooltip_text = status_label.text
	for ch in chip_row.get_children():
		ch.queue_free()
	var chips: Array = state.chips(g)
	for c in chips:
		var kind: String = c["kind"]
		var key = c["key"]
		var b = _btn(chip_row, c["label"] + "  ×", func():
			if kind == "text":
				filter_edit.set_block_signals(true)
				filter_edit.text = ""
				filter_edit.set_block_signals(false)
			state.remove_chip(kind, key))
		b.custom_minimum_size.x = minf(b.get_combined_minimum_size().x, 320)
		b.clip_text = true
		b.tooltip_text = c["label"] + "\nRemove this filter"
	if not chips.is_empty():
		_btn(chip_row, "Clear all", _clear_filters)

## The working set (what Link and the builder use).
func selected_cards() -> Array:
	return staged.duplicate()

func _stage(nums: Array) -> void:
	for x in nums:
		if not (x in staged):
			staged.append(x)
	card_list.deselect_all()
	_refresh_work()
	if not nums.is_empty():
		set_panel_open("work", true)

func _unstage(nums: Array) -> void:
	staged = staged.filter(func(x): return not (x in nums))
	_refresh_work()

func _refresh_work() -> void:
	if work_list == null or g == null:
		return
	staged = staged.filter(func(x): return x >= 1 and x <= g.board.size() and not g.board[x - 1].get("deleted", false))
	work_list.reset()
	for x in staged:
		var c: Dictionary = g.board[x - 1]
		work_list.add("#%-3d %-10s %s" % [x, c["kind"], c["text"]], x, c["text"],
			CardList.color_for(c, Color(0.95, 0.8, 0.45) if c["kind"] == "deduction" else null))
	_update_preview()
	# Live: what the working set suggests, as cards come and go.
	if result_text != null:
		if staged.size() >= 1 and staged.size() <= 3:
			_on_link()
		else:
			_clear_results()
			result_text.text = "Put one to three cards in the working set to see what they suggest." if staged.is_empty() else \
				"%d cards in the working set: suggestions look at up to three at a time (you can still file a conclusion from all of them)." % staged.size()
	if board != null:
		board.queue_redraw()

func _refresh_profile() -> void:
	profile.refresh()

func show_profile(id: String, open: bool = false) -> void:
	profile.show_person(id)
	if open:
		set_panel_open("profile", true)

func _on_save_profile() -> void:
	profile.save()
	refresh()
	changed.emit()

func _clear_results() -> void:
	for ch in result_box.get_children():
		if ch != result_text:
			ch.queue_free()

func _on_link() -> void:
	_clear_results()
	var sel: Array = selected_cards()
	if sel.size() < 1 or sel.size() > 3:
		result_text.text = "Put 1 to 3 cards in your working set to link them."
		return
	var lk: Dictionary = g.link_cards(sel)
	var res: Dictionary = lk["result"]
	if res["matches"].is_empty():
		var t = "Nothing links cards %s: no conflict, corroboration or inference." % _nums(sel)
		for r in res["near"].slice(0, 2):
			t += "\nClose, but " + r
		t += "\nYou can still build a conclusion from them above: your own inference if they bear on that person, unfounded if not."
		result_text.text = t
		return
	var t2 = ""
	for m in res["matches"]:
		t2 += "%s %s\n" % [Argue.RELATION_LEAD[m.get("relation", "contradiction")], m["text"]]
	result_text.text = t2 + "Possible conclusions (this doesn't say which is true). Pick one to put it in the builder:"
	var k = 0
	for o in lk["options"]:
		k += 1
		var idx = k
		var b = _btn(result_box, "%d. %s" % [k, o["expl"]["label"]], func():
			_use_option(o)
			g.w.dlog.add("ui_use_option", "player", "", {"option": idx}))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = o["expl"]["label"]

func _nums(a: Array) -> String:
	return " ".join(PackedStringArray(a.map(func(x): return "#%d" % x)))

# ---------------------------------------------------------------- builder

func _fill_status() -> void:
	var verb: String = b_verb.get_item_text(max(0, b_verb.selected))
	b_status.clear()
	if b_who.selected >= 0 and b_who.get_item_metadata(b_who.selected) == "*group":
		# "Something doesn't add up": the people your working set rests on.
		b_verb.select(0)
		b_status.add_item("misled or lying (something doesn't add up)")
		b_status.set_item_metadata(0, "conflict")
		return
	var add = func(label: String, meta: String):
		b_status.add_item(label)
		b_status.set_item_metadata(b_status.item_count - 1, meta)
	for pair in Argue.BUILDER[verb]:
		add.call(pair[0], pair[1])
	if verb == "is":
		b_status.add_separator("Misread")
		for pair in Argue.MISREAD:
			add.call(pair[0], pair[1])
	if verb != "should be":
		b_status.add_separator("Good roles")
		for r in C.GOOD_ROLES:
			add.call("the " + C.role_name(r), r)
		b_status.add_separator("Evil roles")
		for r in C.MINION_ROLES:
			add.call("the " + C.role_name(r), r)
	if verb == "is":
		b_status.add_separator("Secrets")
		for pair in Argue.SECRET_CONCLUSIONS:
			add.call(pair[0], pair[1])

func _fill_nights() -> void:
	var keep = _meta_int(b_night)
	b_night.clear()
	b_night.add_item("(any night)")
	b_night.set_item_metadata(0, -1)
	for nt in range(0, g.w.day + 1):
		b_night.add_item("on the night before you arrived" if nt == 0 else "on night %d" % nt)
		b_night.set_item_metadata(b_night.item_count - 1, nt)
	for i in range(b_night.item_count):
		if b_night.get_item_metadata(i) == keep:
			b_night.select(i)

func _meta_int(o: OptionButton) -> int:
	if o == null or o.selected < 0 or o.item_count == 0:
		return -1
	return int(o.get_item_metadata(o.selected))

func _builder_changed() -> void:
	if not _setting:
		pending = {}
	_update_preview()

## The conclusion the builder currently describes (empty if incomplete).
func _built() -> Dictionary:
	if not pending.is_empty():
		return pending["conclusion"]
	if b_who.selected < 0 or b_status.selected < 0:
		return {}
	var who: String = b_who.get_item_metadata(b_who.selected)
	if who == "*group":
		return Argue.conflict_of(g.w, g.board.filter(func(x): return x["n"] in staged))
	var verb: String = b_verb.get_item_text(b_verb.selected)
	var status: String = b_status.get_item_metadata(b_status.selected)
	var c: Dictionary = Argue.from_builder(who, verb, status, _meta_int(b_night), -1, true)
	if c.is_empty():
		return c
	if c["type"] in ["lied", "unreliable", "truthful"]:
		for x in selected_cards():
			if g.board[x - 1].get("source", "") == who:
				c["card"] = x
				break
	return c

func _update_preview() -> void:
	if b_preview == null or g == null:
		return
	var st: String = b_status.get_item_metadata(b_status.selected) if b_status.selected >= 0 else ""
	b_night.disabled = not pending.is_empty() or not (st in ["misled", "unreliable"])
	var sel: Array = pending["match"]["cards"] if not pending.is_empty() else selected_cards()
	b_because.text = "because: " + (_nums(sel) if not sel.is_empty() else "(add the supporting cards to your working set)")
	var c = _built()
	if c.is_empty():
		b_preview.text = ""
		return
	var backing = ""
	if not pending.is_empty():
		var how = {"contradiction": "a contradiction", "corroboration": "corroboration", "inference": "an inference"}.get(pending["match"].get("relation", "contradiction"), "a contradiction")
		backing = "  [backed by %s: %s]" % [how, pending["match"]["text"]]
	b_preview.text = Argue.conclusion_text(g.w, Argue.normalize(c.duplicate())) + backing
	b_error.text = ""

func _use_option(o: Dictionary) -> void:
	var c: Dictionary = Argue.normalize(o["expl"]["conclusion"].duplicate())
	_setting = true
	for i in range(b_who.item_count):
		if b_who.get_item_metadata(i) == (c.get("a", "") if c["type"] != "conflict" else "*group"):
			b_who.select(i)
	if c["type"] == "conflict":
		_fill_status()
		_setting = false
		pending = {"conclusion": c, "match": o["match"], "id": 0}
		_update_preview()
		return
	var verb = "is"
	var status: String = c["type"]
	match c["type"]:
		"role":
			status = c["role"]
		"secret_mod":
			status = c.get("mod", "")
		"notrole":
			verb = "is not"
			status = c["role"]
		"notdemon":
			verb = "is not"
		"truthful":
			verb = "is not"
		"protect", "spare":
			verb = "should be"
	for i in range(b_verb.item_count):
		if b_verb.get_item_text(i) == verb:
			b_verb.select(i)
	_fill_status()
	for i in range(b_status.item_count):
		if b_status.get_item_metadata(i) == status:
			b_status.select(i)
	for i in range(b_night.item_count):
		if b_night.get_item_metadata(i) == c.get("night", -1):
			b_night.select(i)
	_setting = false
	pending = {"conclusion": c, "match": o["match"], "id": o["expl"]["id"]}
	_update_preview()

func _on_file() -> void:
	var n = -1
	if not pending.is_empty():
		n = g.file_deduction(pending["conclusion"], pending["match"]["cards"], pending["match"], pending["id"])
	else:
		var c = _built()
		if c.is_empty():
			b_error.text = "That isn't a complete conclusion."
			return
		n = g.file_deduction(c, selected_cards())
	if n < 0:
		b_error.text = g.last_error
		return
	pending = {}
	b_error.text = ""
	_clear_results()
	result_text.text = "Filed card #%d: %s" % [n, g.board[n - 1]["text"]]
	staged = []
	card_list.deselect_all()
	refresh()
	changed.emit()

## Teaching helper: what the selected card could be linked with, and what that would show.
func _hint_selected(num: int = 0) -> void:
	set_panel_open("work", true)
	_clear_results()
	var sel: Array = [num] if num > 0 else card_list.selected_metas().filter(func(x): return x is int and x > 0)
	if sel.is_empty():
		result_text.text = "Select a card to see what it could be linked with."
		return
	var c: Dictionary = g.board[sel[0] - 1]
	var hs: Array = Argue.hints_for(c)
	if hs.is_empty():
		result_text.text = "Card #%d doesn't take part in any pattern the town recognises (yet)." % sel[0]
		return
	var lines = PackedStringArray(["Card #%d could be linked with:" % sel[0]])
	for h in hs:
		lines.append("  • %s → %s" % [h[0], h[1]])
	result_text.text = "\n".join(lines)

## Board hint: cards already on your board that a pattern would connect.
func _find_links(num: int = 0) -> void:
	set_panel_open("work", true)
	_clear_results()
	var found: Array = g.find_links() if num == 0 else _links_for_card(num)
	if found.is_empty():
		result_text.text = "No cards link with card #%d yet." % num if num > 0 else "Nothing among your recent cards links up yet."
		return
	var lines = PackedStringArray(["Links for card #%d (put them in the working set to see how):" % num if num > 0 else "These cards connect (put them in the working set to see how):"])
	for f in found.slice(0, 8):
		lines.append("  • #%s" % ", #".join(PackedStringArray(f["cards"].map(func(x): return str(x)))))
	if found.size() > 8:
		lines.append("  …and %d more." % (found.size() - 8))
	result_text.text = "\n".join(lines)

func _links_for_card(num: int) -> Array:
	var found: Array = []
	var seen = {}
	for other in g.board:
		if other["n"] == num or other.get("deleted", false):
			continue
		var result: Dictionary = Argue.check(g.w, [g.board[num - 1], other])
		for m in result["matches"]:
			var key = str(m["cards"])
			if not seen.has(key):
				seen[key] = true
				found.append({"cards": m["cards"]})
	return found

func _hide_selected(on: bool, nums: Array = []) -> void:
	var sel = card_list.selected_metas() if nums.is_empty() else nums
	if sel.is_empty():
		result_text.text = "Select cards to %s." % ("hide" if on else "unhide")
		return
	for x in sel:
		g.hide_card(x, on)
	_clear_results()
	result_text.text = "%s %s.%s" % ["Hid" if on else "Unhid", _nums(sel), " Tick 'Show hidden' to see hidden cards." if on and not g.show_hidden else ""]
	card_list.deselect_all()
	refresh()
	changed.emit()

func _delete_selected(nums: Array = []) -> void:
	var candidates: Array = card_list.selected_metas() + work_list.selected_metas() if nums.is_empty() else nums
	var sel = candidates.filter(func(x): return g.board[x - 1]["kind"] == "deduction")
	_clear_results()
	if sel.is_empty():
		result_text.text = "Select one of your deductions to delete. (Other cards can only be hidden.)"
		return
	for x in sel:
		g.delete_deduction(x)
	result_text.text = "Deleted deduction %s." % _nums(sel)
	card_list.deselect_all()
	refresh()
	changed.emit()
