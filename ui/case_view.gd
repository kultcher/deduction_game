## Full-screen case board: filters, card library, the board (ui/board_view.gd), profiles,
## and the Case Workshop as a pull-out sheet (ui/workshop_drawer.gd). Reads the game's
## structured data directly.
extends PanelContainer

signal changed
signal notes_requested
signal roles_requested
signal workshop_requested(number: int)

const C = preload("res://sim/content.gd")
const Argue = preload("res://sim/argue.gd")
const CardList = preload("res://ui/card_list.gd")
const EvidenceContext = preload("res://ui/evidence_context.gd")
const Metrics = preload("res://game/case_metrics.gd")
const CaseState = preload("res://ui/case_state.gd")
const UITheme = preload("res://ui/theme.gd")
const CardModel = preload("res://game/card_model.gd")
const BoardView = preload("res://ui/board_view.gd")
const DeductionTray = preload("res://ui/deduction_tray.gd")
const ProfilePanel = preload("res://ui/profile_panel.gd")
const BoardPanel = preload("res://ui/board_panel.gd")
const WorkshopDrawer = preload("res://ui/workshop_drawer.gd")

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
var hide_unselected: CheckBox
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
var hidden_check: CheckBox
var staged: Array = []        # board cards currently in the Case Workshop (marked on the board)
var workshop                  # ui/workshop_drawer.gd
var workshop_execute: Callable  # runs a workshop command through the main screen
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
enum CardAction { HIDE, DELETE, UNPIN, WORKSHOP }


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
	hide_unselected = CheckBox.new()
	hide_unselected.text = "Hide Unselected"
	hide_unselected.toggled.connect(func(on):
		state.hide_unselected = on
		_refresh_board())
	filters.add_child(hide_unselected)
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
	for entry in [["cards", "Card List"], ["profile", "Profile"]]:
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
	card_list.card_activated.connect(add_to_workshop)
	card_list.card_context_requested.connect(show_card_menu)
	card_list.selection_changed.connect(func():
		var sel: Array = card_list.selected_metas()
		if not sel.is_empty():
			state.select_card(sel[0]))
	card_list.readable(15)
	lib.add_child(card_list)

	board = BoardView.new()
	canvas.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.move_child(board, 0)
	board.view_changed.connect(_update_day_label)
	board.card_activated.connect(add_to_workshop)
	board.card_context_requested.connect(show_card_menu)
	board.row_clicked.connect(func(kind, id):
		state.toggle(state.people if kind == "person" else state.places, id)
		if kind == "person" and board.board_view() != "statements":
			state.select_person(id)
			show_profile(id, true))
	board.person_context_requested.connect(_toggle_profile)
	tray = DeductionTray.new()
	tray.card_context_requested.connect(show_card_menu)
	root.add_child(tray)
	board.tooltip_text = "Drag the background to pan; wheel to zoom. Double-click a card, or drag it onto the Case Workshop on the right, to add it to your case."
	# The Workshop sheet sits over the board, under the floating panels.
	workshop = WorkshopDrawer.new()
	workshop.execute = workshop_execute
	canvas.add_child(workshop)
	canvas.move_child(workshop, 1)
	workshop.filed.connect(func():
		refresh()
		changed.emit())
	workshop.changed.connect(_refresh_staged)
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
	profile.profile_workshop_requested.connect(func(pid: String, facet: String): open_workshop_profile(pid, facet))
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
	if card.kind != "deduction":
		card_menu.add_item("Add to Case Workshop", CardAction.WORKSHOP)
	card_menu.add_item("Unhide" if card.get("hidden", false) else "Hide", CardAction.HIDE)
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
	match action:
		CardAction.WORKSHOP:
			if not visible:
				workshop_requested.emit(num)
			else:
				add_to_workshop(num)
		CardAction.HIDE:
			_hide_selected(not g.board[num - 1].get("hidden", false), [num])
		CardAction.DELETE:
			_delete_selected([num])
		CardAction.UNPIN:
			board.unpin(num)

func _layout_panels() -> void:
	if panels.size() < 2 or canvas.size.x <= 0 or canvas.size.y <= 0:
		return
	for panel in panels.values():
		# Hidden controls are sized before their containers finish the first layout.
		# Keep the intended defaults until a panel is actually opened by the player.
		if not _panels_placed:
			panel.size = panel.get_meta("initial_size")
		panel.fit_inside()
	if not _panels_placed:
		panels["cards"].move_to(Vector2(8, 8))
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
	hidden_check.set_pressed_no_signal(g.show_hidden)
	for n in g.w.npcs:
		pp.add_check_item(n.name)
		pp.set_item_metadata(pp.item_count - 1, n.id)
	var lp: PopupMenu = place_menu.get_popup()
	lp.clear()
	for b in C.BLOCKS:
		lp.add_check_item(C.block_name(b))
		lp.set_item_metadata(lp.item_count - 1, b)
	for l in C.LOCATIONS:
		lp.add_check_item("    " + C.loc_name(l))
		lp.set_item_metadata(lp.item_count - 1, l)
	profile.setup(g, state)
	workshop.collapse()
	workshop.set_game(g)
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
	if visible:
		workshop.refresh()
	_refresh_staged()

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
	card_list.context_numbers = EvidenceContext.numbers(g)
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
	var people_rows = board.board_view() != "places" or state.rows_by == "person"
	var selected: Dictionary = state.people if people_rows else state.places
	hide_unselected.disabled = selected.is_empty()
	hide_unselected.set_pressed_no_signal(state.hide_unselected)
	hide_unselected.tooltip_text = ("Select people filters first." if people_rows else "Select place filters first.") if selected.is_empty() else "Show rows matching any selected filter. Pinned cards remain visible."
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

## Cards in the Case Workshop, as board numbers (the board marks them).
func selected_cards() -> Array:
	return staged.duplicate()

## Double-click, drag or the card menu: put a board card into the Case Workshop.
func add_to_workshop(num: int) -> void:
	if g == null or num < 1 or num > g.board.size() or g.board[num - 1].kind == "deduction":
		return
	workshop.add_card(num)
	_refresh_staged()
	status_label.text = "Card #%d is in the Case Workshop." % num

## Open the Workshop sheet (at least half width), optionally adding a card.
func open_workshop(num: int = 0) -> void:
	visible = true
	workshop.open(0.5)
	if num > 0:
		add_to_workshop(num)

func open_workshop_profile(person_id: String, facet: String = "home_work") -> void:
	visible = true
	workshop.open(0.5)
	workshop.add_profile_info(person_id, facet)
	_refresh_staged()
	if g != null and g.w.by_id.has(person_id):
		status_label.text = "%s's Profile is in the Case Workshop." % g.w.by_id[person_id].name

func _refresh_staged() -> void:
	if workshop == null or workshop.editor == null or g == null:
		staged = []
	else:
		staged = workshop.editor.board_numbers()
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

func _hide_selected(on: bool, nums: Array = []) -> void:
	var sel = card_list.selected_metas() if nums.is_empty() else nums
	if sel.is_empty():
		status_label.text = "Select cards to %s." % ("hide" if on else "unhide")
		return
	for x in sel:
		g.hide_card(x, on)
	status_label.text = "%s %s.%s" % ["Hid" if on else "Unhid", _nums(sel), " Tick 'Show hidden' to see hidden cards." if on and not g.show_hidden else ""]
	card_list.deselect_all()
	refresh()
	changed.emit()

func _delete_selected(nums: Array = []) -> void:
	var candidates: Array = card_list.selected_metas() if nums.is_empty() else nums
	var sel = candidates.filter(func(x): return g.board[x - 1]["kind"] == "deduction")
	if sel.is_empty():
		status_label.text = "Select one of your deductions to delete. (Other cards can only be hidden.)"
		return
	for x in sel:
		g.delete_deduction(x)
	status_label.text = "Deleted deduction %s." % _nums(sel)
	card_list.deselect_all()
	refresh()
	changed.emit()

func _nums(a: Array) -> String:
	return ", ".join(PackedStringArray(a.map(func(x): return "#%d" % x)))
