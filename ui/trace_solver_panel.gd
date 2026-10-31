## Interactive 2-row x N-night Trace Solver panel for cross-referencing crime-scene traces.
## Lives in a Case Board `BoardPanel` (accessible from both the Case Board dock and the
## Case Workshop toolbar) and commits bundled `trace_chain` nodes to the Workshop canvas.
extends VBoxContainer

signal commit_requested(selected_by_night: Dictionary)
signal person_clicked(person_id: String)

const UITheme = preload("res://ui/theme.gd")
const PortraitBadge = preload("res://ui/portrait_badge.gd")
const TraceSolver = preload("res://workshop/trace_solver.gd")
const WorkshopCanvas = preload("res://game/workshop_canvas.gd")


class SuspectTile extends Control:
	signal clicked(person_id: String)

	const TILE_W = 84.0
	const TILE_H = 102.0
	const BADGE_SIZE = 54.0

	var entry: Dictionary = {}
	var portrait: Control
	var _hover: bool = false
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(TILE_W, TILE_H)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = " "
		_font = UITheme.serif()
		portrait = PortraitBadge.new()
		add_child(portrait)
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func setup_entry(data: Dictionary) -> void:
		entry = data
		var pid: String = str(entry.get("id", ""))
		portrait.position = Vector2((TILE_W - BADGE_SIZE) * 0.5, 6.0)
		portrait.size = Vector2(BADGE_SIZE, BADGE_SIZE)
		# Always pass alive=true to PortraitBadge so grayscale strictly encodes missing haunts,
		# while executed townsfolk receive an explicit "Hung D#" tag below their name.
		portrait.show_person(pid, true)
		portrait.set_grayscale(0.92 if entry.get("grayscale", false) else 0.0)
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var pid: String = str(entry.get("id", ""))
			if pid != "":
				clicked.emit(pid)
			accept_event()

	func _draw() -> void:
		if entry.is_empty():
			return
		var fit: String = str(entry.get("fit", "idle"))
		var border_col: Color = UITheme.color("border")
		var bg_col: Color = Color(0.14, 0.13, 0.12, 0.45)
		if fit == "matches":
			border_col = Color("4e9a62")
			bg_col = Color(0.16, 0.25, 0.19, 0.55)
		elif fit == "contradicts":
			border_col = Color("a8463c")
			bg_col = Color(0.24, 0.14, 0.14, 0.45)
		elif fit == "unknown":
			border_col = Color("b88435")
			bg_col = Color(0.23, 0.19, 0.13, 0.48)
		if _hover:
			border_col = UITheme.color("accent")
		draw_style_box(UITheme.flat(bg_col, border_col, 2 if (fit == "matches" or _hover) else 1, 6, 0), Rect2(Vector2.ZERO, size))

		# Location-knowledge pips (3 dots: filled = known work/haunt, hollow = unknown haunt)
		var kcount: int = int(entry.get("known_count", 0))
		var pip_y: float = 66.0
		var pip_x0: float = TILE_W * 0.5 - 10.0
		for i in range(3):
			var pc = Vector2(pip_x0 + i * 10.0, pip_y)
			if i < kcount:
				draw_circle(pc, 3.0, Color("d9be7a") if entry.get("full_profile", false) else Color("b0b5ba"))
			else:
				draw_arc(pc, 3.0, 0.0, TAU, 16, Color("6e7378"), 1.2)

		# Name + optional Executed tag
		var nm: String = str(entry.get("name", ""))
		var name_col: Color = UITheme.color("text") if fit != "contradicts" else UITheme.color("muted")
		draw_string(_font, Vector2(4.0, 82.0), nm, HORIZONTAL_ALIGNMENT_CENTER, TILE_W - 8.0, 13, name_col)
		if entry.get("executed", false):
			var ex_txt: String = "Hung D%d" % int(entry.get("exec_day", 0))
			draw_string(_font, Vector2(4.0, 96.0), ex_txt, HORIZONTAL_ALIGNMENT_CENTER, TILE_W - 8.0, 11, Color("c78d75"))
		else:
			var info_txt: String = "3/3 spots" if entry.get("full_profile", false) else ("%d/3 known" % kcount)
			draw_string(_font, Vector2(4.0, 96.0), info_txt, HORIZONTAL_ALIGNMENT_CENTER, TILE_W - 8.0, 11, UITheme.color("muted"))

		# Corner overlay signifier (`✓`, `?`, or `✕`) drawn on top of portrait corner
		if fit in ["matches", "unknown", "contradicts"]:
			var bc = Vector2((TILE_W + BADGE_SIZE) * 0.5 - 6.0, 15.0)
			var bcol: Color = Color("2e8548") if fit == "matches" else (Color("b87d2b") if fit == "unknown" else Color("b53d35"))
			var glyph: String = "✓" if fit == "matches" else ("?" if fit == "unknown" else "✕")
			draw_circle(bc, 10.5, Color(0.08, 0.08, 0.09, 0.92))
			draw_circle(bc, 9.0, bcol)
			draw_string(_font, bc + Vector2(-5.0, 5.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, 10.0, 13, Color("fbf6ea"))

	func _get_tooltip(_at: Vector2) -> String:
		if entry.is_empty():
			return ""
		var lines: Array = []
		var status_tag: String = " (Executed Day %d)" % int(entry.get("exec_day", 0)) if entry.get("executed", false) else ""
		lines.append("%s%s" % [entry.get("name", ""), status_tag])
		var wloc: String = str(entry.get("work_loc", ""))
		var haunts: Array = entry.get("known_haunts", [])
		lines.append("Workplace: " + (TraceSolver._short_loc_name(wloc) if wloc != "" else "Unknown"))
		if haunts.is_empty():
			lines.append("Known haunts: none yet (2 unknown)")
		else:
			var hnames: Array = haunts.map(func(h): return TraceSolver._short_loc_name(str(h)))
			lines.append("Known haunts (%d/2): %s" % [haunts.size(), ", ".join(PackedStringArray(hnames))])
		for pn in entry.get("per_night", []):
			lines.append("• " + str(pn))
		if str(entry.get("reason", "")) != "":
			lines.append(str(entry.reason))
		lines.append("Click to open %s's Profile." % entry.get("name", "their"))
		return "
".join(PackedStringArray(lines))


var g
var selected_by_night: Dictionary = {} # night_int -> trace_card_id
var last_evaluation: Dictionary = {}
var _case_world = null

var intro_label: Label
var matrix_scroll: ScrollContainer
var matrix_row: HBoxContainer
var empty_label: Label
var legend_label: Label
var suspects_flow: HFlowContainer
var victims_label: Label
var summary_label: Label
var clear_btn: Button
var commit_btn: Button
var _tiles_by_id: Dictionary = {}


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

	intro_label = Label.new()
	intro_label.text = "Choose up to one trace per night to check who fits your selection as one killer. A trace may belong to a passer. Click a selected trace again to leave that night empty; after a suspected Scion handoff, select nights on either side separately."
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_label.add_theme_font_size_override("font_size", 14)
	intro_label.add_theme_color_override("font_color", UITheme.color("muted"))
	add_child(intro_label)

	empty_label = Label.new()
	empty_label.text = "No crime-scene location traces collected yet. Search a murder scene during the day to populate night columns."
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.add_theme_font_size_override("font_size", 15)
	empty_label.add_theme_color_override("font_color", UITheme.color("muted"))
	add_child(empty_label)

	matrix_scroll = ScrollContainer.new()
	matrix_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	matrix_scroll.custom_minimum_size = Vector2(0, 148)
	matrix_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(matrix_scroll)

	matrix_row = HBoxContainer.new()
	matrix_row.add_theme_constant_override("separation", 10)
	matrix_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	matrix_scroll.add_child(matrix_row)

	legend_label = Label.new()
	legend_label.text = "Color = all 3 spots known  ·  Grayscale = missing haunt(s)  ·  ✓ fits selection  ·  ? could fit  ·  ✕ does not fit selection"
	legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend_label.add_theme_font_size_override("font_size", 13)
	legend_label.add_theme_color_override("font_color", UITheme.color("muted"))
	add_child(legend_label)

	suspects_flow = HFlowContainer.new()
	suspects_flow.add_theme_constant_override("h_separation", 8)
	suspects_flow.add_theme_constant_override("v_separation", 8)
	suspects_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(suspects_flow)

	victims_label = Label.new()
	victims_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	victims_label.add_theme_font_size_override("font_size", 13)
	victims_label.add_theme_color_override("font_color", UITheme.color("muted"))
	add_child(victims_label)

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	add_child(footer)

	summary_label = Label.new()
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 14)
	summary_label.add_theme_color_override("font_color", UITheme.color("accent"))
	footer.add_child(summary_label)

	clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.tooltip_text = "Untoggle all selected traces."
	clear_btn.pressed.connect(clear_selection)
	footer.add_child(clear_btn)

	commit_btn = Button.new()
	commit_btn.name = "CommitTraceChain"
	commit_btn.text = "Commit to Workshop"
	commit_btn.tooltip_text = "Creates or updates a bundled Trace Chain node on the Case Workshop canvas with these traces and your discovered location receipts."
	commit_btn.pressed.connect(_on_commit)
	footer.add_child(commit_btn)


func set_game(game) -> void:
	if _case_world != (game.w if game != null else null):
		_case_world = game.w if game != null else null
		selected_by_night.clear()
		for t in _tiles_by_id.values():
			t.queue_free()
		_tiles_by_id.clear()
	g = game
	refresh()


func toggle_trace(night: int, card_id: String) -> void:
	if selected_by_night.get(night, "") == card_id:
		selected_by_night.erase(night)
	else:
		selected_by_night[night] = card_id
	refresh()


func set_selection(selection_map: Dictionary) -> void:
	selected_by_night.clear()
	for k in selection_map:
		selected_by_night[int(k)] = str(selection_map[k])
	refresh()


func clear_selection() -> void:
	selected_by_night.clear()
	refresh()


func _on_commit() -> void:
	if selected_by_night.is_empty():
		return
	commit_requested.emit(selected_by_night.duplicate(true))


func refresh() -> void:
	if g == null:
		return
	var view: Dictionary = WorkshopCanvas.view(g)
	last_evaluation = TraceSolver.evaluate_selection(view, selected_by_night)
	selected_by_night = last_evaluation.selected_by_night.duplicate(true)
	var matrix: Dictionary = last_evaluation.matrix
	var cols: Array = matrix.columns

	empty_label.visible = cols.is_empty()
	matrix_scroll.visible = not cols.is_empty()
	if not cols.is_empty():
		matrix_scroll.custom_minimum_size.y = 224.0 if int(matrix.max_rows) >= 2 else 140.0
	_rebuild_matrix(matrix)
	_rebuild_suspects(last_evaluation)
	_update_footer(last_evaluation)


func _rebuild_matrix(matrix: Dictionary) -> void:
	for ch in matrix_row.get_children():
		ch.queue_free()
	var cols: Array = matrix.columns
	var dividers_after: Dictionary = {}
	for div in matrix.get("scion_dividers", []):
		dividers_after[int(div.after_night)] = div

	var max_rows: int = int(matrix.max_rows)
	for idx in range(cols.size()):
		var col: Dictionary = cols[idx]
		var night: int = int(col.night)
		var col_box = VBoxContainer.new()
		col_box.custom_minimum_size = Vector2(188, 0)
		col_box.add_theme_constant_override("separation", 6)
		matrix_row.add_child(col_box)

		var head = Label.new()
		head.text = "Night %d · %s" % [night, col.victim_name if col.victim_name != "" else "Scene"]
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_theme_font_size_override("font_size", 14)
		head.add_theme_color_override("font_color", UITheme.color("accent"))
		col_box.add_child(head)

		for r_idx in range(max_rows):
			if r_idx < col.rows.size():
				var cell: Dictionary = col.rows[r_idx]
				var cid: String = str(cell.id)
				var active: bool = selected_by_night.get(night, "") == cid
				var btn = Button.new()
				btn.toggle_mode = true
				btn.button_pressed = active
				btn.custom_minimum_size = Vector2(186, 82)
				btn.clip_text = true
				var kind_tag: String = "Token (2)" if cell.subtype == "token" else "Scent (3)"
				var item_short: String = str(cell.item_label).trim_prefix("a ").trim_prefix("an ")
				if item_short.length() > 26:
					item_short = item_short.left(25) + "…"
				btn.text = "%s
%s
%s" % [kind_tag, item_short, " · ".join(PackedStringArray(cell.short_locs))]
				btn.tooltip_text = "%s
Places: %s
%s" % [
					cell.text,
					", ".join(PackedStringArray(cell.loc_names)),
					"Two traces at this cottage (1 Demon, 1 passing walker)." if int(cell.scene_trace_count) >= 2 else "Single trace found at this cottage."
				]
				var style_bg: Color = Color("5e4728") if active else Color("24211e")
				var style_bd: Color = Color("f0cf82") if active else UITheme.color("border")
				btn.add_theme_stylebox_override("normal", UITheme.flat(style_bg, style_bd, 2 if active else 1, 6, 6))
				btn.add_theme_stylebox_override("pressed", UITheme.flat(Color("5e4728"), Color("f0cf82"), 2, 6, 6))
				btn.add_theme_stylebox_override("hover", UITheme.flat(style_bg.lightened(0.08), Color("f0cf82"), 2, 6, 6))
				btn.add_theme_font_size_override("font_size", 13)
				var n_capture: int = night
				var c_capture: String = cid
				btn.pressed.connect(func(): toggle_trace(n_capture, c_capture))
				col_box.add_child(btn)
			else:
				var spacer = PanelContainer.new()
				spacer.custom_minimum_size = Vector2(186, 82)
				spacer.add_theme_stylebox_override("panel", UITheme.flat(Color(0.12, 0.12, 0.12, 0.3), Color(0.3, 0.28, 0.25, 0.35), 1, 6, 6))
				var slbl = Label.new()
				slbl.text = "Single trace
at scene"
				slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				slbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				slbl.add_theme_font_size_override("font_size", 12)
				slbl.add_theme_color_override("font_color", UITheme.color("muted"))
				spacer.add_child(slbl)
				col_box.add_child(spacer)

		if dividers_after.has(night):
			var div: Dictionary = dividers_after[night]
			var div_panel = PanelContainer.new()
			div_panel.custom_minimum_size = Vector2(78, 0)
			div_panel.add_theme_stylebox_override("panel", UITheme.flat(Color(0.28, 0.18, 0.13, 0.55), Color("c98a3d"), 1, 6, 6))
			var dlbl = Label.new()
			dlbl.text = "Day %d
Hung:
%s

Scion
handoff?" % [int(div.exec_day), str(div.executed_name)]
			dlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dlbl.add_theme_font_size_override("font_size", 11)
			dlbl.add_theme_color_override("font_color", Color("f2ca85"))
			div_panel.tooltip_text = "%s was executed on Day %d with 5+ townsfolk alive. If %s was the original Demon, a living Scion took over starting on Night %d, so earlier and later traces can belong to two different killers." % [
				str(div.executed_name), int(div.exec_day), str(div.executed_name), int(div.exec_day)
			]
			div_panel.add_child(dlbl)
			matrix_row.add_child(div_panel)


func _rebuild_suspects(ev: Dictionary) -> void:
	var ordered: Array = ev.get("all_entries", [])
	var keep_ids: Dictionary = {}
	for entry in ordered:
		var pid: String = str(entry.id)
		keep_ids[pid] = true
		if not _tiles_by_id.has(pid):
			var tile = SuspectTile.new()
			tile.clicked.connect(func(who): person_clicked.emit(who))
			suspects_flow.add_child(tile)
			_tiles_by_id[pid] = tile
		_tiles_by_id[pid].setup_entry(entry)
	for old_id in _tiles_by_id.keys():
		if not keep_ids.has(old_id):
			_tiles_by_id[old_id].queue_free()
			_tiles_by_id.erase(old_id)
	for i in range(ordered.size()):
		var pid2: String = str(ordered[i].id)
		if _tiles_by_id.has(pid2):
			suspects_flow.move_child(_tiles_by_id[pid2], i)

	var victims: Array = ev.get("excluded_victims", [])
	if victims.is_empty():
		victims_label.visible = false
	else:
		victims_label.visible = true
		var vnames: Array = victims.map(func(v): return "%s (N%d)" % [v.name, int(v.death_night)])
		victims_label.text = "Omitted night victims: " + ", ".join(PackedStringArray(vnames))


func _update_footer(ev: Dictionary) -> void:
	var sel_count: int = ev.get("selected_traces", []).size()
	clear_btn.disabled = sel_count == 0
	commit_btn.disabled = sel_count == 0
	if sel_count == 0:
		var full_n: int = ev.get("suspects", []).filter(func(e): return e.full_profile).size()
		summary_label.text = "Select 1+ trace(s) above  ·  %d/%d living profiles complete" % [full_n, ev.get("suspects", []).size()]
	else:
		summary_label.text = "%d night%s selected  ·  %d ✓ fit  ·  %d ? unresolved  ·  %d ✕ don't fit selection" % [
			sel_count,
			"" if sel_count == 1 else "s",
			ev.get("matches_ids", []).size(),
			ev.get("unknown_ids", []).size(),
			ev.get("contradicts_ids", []).size(),
		]
